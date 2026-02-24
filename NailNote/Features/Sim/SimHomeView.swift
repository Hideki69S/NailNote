import SwiftUI
import CoreData
import CryptoKit
import UIKit

struct SimHomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NailEntry.date, ascending: false)],
        animation: .default
    )
    private var entries: FetchedResults<NailEntry>

    @State private var evaluatingEntryID: NSManagedObjectID?
    @State private var alertMessage: String?
    @State private var showingSample = false
    @State private var expandedEntries: Set<NSManagedObjectID> = []
    @State private var entryPendingConfirmation: NailEntry?

    var body: some View {
        NavigationStack {
            GlassBackgroundView {
                content
            }
        }
    }

    private var content: some View {
        let entriesSnapshot = Array(entries)
        let photoEntries = entriesSnapshot.filter { $0.photoId != nil }

        return VStack(spacing: 0) {
            AdPlaceholderBanner()
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        heroCard
                        Text("※AI評価にはデザイン写真の登録が必要です。")
                            .font(.caption)
                            .foregroundStyle(Color.red)
                        AISampleCardView(showingSample: $showingSample)
                        if photoEntries.isEmpty {
                            ContentUnavailableView("写真付きの記録がありません", systemImage: "camera")
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(photoEntries, id: \.objectID) { entry in
                                    AIScoreEntryCard(
                                        entry: entry,
                                        isEvaluating: evaluatingEntryID == entry.objectID,
                                        evaluateAction: {
                                            entryPendingConfirmation = entry
                                        },
                                        isExpanded: expandedEntries.contains(entry.objectID),
                                        toggleExpanded: {
                                            toggleExpansion(for: entry.objectID)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(16)
                }
        }
        .sheet(isPresented: $showingSample) {
            AIScoreSampleView()
        }
            .onAppear {
                syncExpandedEntries()
            }
            .onChange(of: entries.map { $0.aiScoreBridge?.evaluatedAt }) { _, _ in
                syncExpandedEntries()
            }
            .alert(
                "AIネイルスコア",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .confirmationDialog(
                "AIネイルスコア",
                isPresented: Binding(
                    get: { entryPendingConfirmation != nil },
                    set: { if !$0 { entryPendingConfirmation = nil } }
                ),
                presenting: entryPendingConfirmation
            ) { entry in
                Button("AI評価を実行") {
                    entryPendingConfirmation = nil
                    Task { await evaluate(entry: entry) }
                }
                Button("キャンセル", role: .cancel) {
                    entryPendingConfirmation = nil
                }
            } message: { entry in
                Text("写真をAIに送信し、\(displayTitle(for: entry))のスコアを生成します。実行してよろしいですか？")
            }
    }
    private func displayTitle(for entry: NailEntry) -> String {
        let name = (entry.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（タイトルなし）" : name
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.75, blue: 0.89),
                                        Color(red: 0.79, green: 0.68, blue: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .blur(radius: 0.5)
                        Image(systemName: "sparkles")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AIネイルスコア")
                            .font(.title2.bold())
                        Text("写真を送るだけで仕上がり・ライン・厚みなどを即スコア化。次に意識したいポイントも一目で分かります。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    badge(text: "写真から診断", icon: "photo.on.rectangle")
                    badge(text: "5項目スコア", icon: "chart.bar")
                    badge(text: "次の一手ヒント", icon: "lightbulb")
                }

                Text("記録一覧で選んだ写真を、この画面からワンタップで評価。結果はカードに保存され、何度でも見返せます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badge(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.25))
        )
    }

    @MainActor
    private func evaluate(entry: NailEntry) async {
        guard entry.photoId != nil else {
            alertMessage = "写真が登録されていない記録はAI評価できません。"
            return
        }
        guard evaluatingEntryID == nil else { return }
        evaluatingEntryID = entry.objectID
        do {
            _ = try await AINailScoreService.shared.evaluate(
                entry: entry,
                userGoal: nil,
                context: viewContext
            )
            expandedEntries.insert(entry.objectID)
        } catch {
            alertMessage = error.localizedDescription
        }
        evaluatingEntryID = nil
    }

    private func toggleExpansion(for id: NSManagedObjectID) {
        if expandedEntries.contains(id) {
            expandedEntries.remove(id)
        } else {
            expandedEntries.insert(id)
        }
    }

    private func syncExpandedEntries() {
        var updated = expandedEntries
        for entry in entries {
            if entry.aiScoreBridge != nil {
                updated.insert(entry.objectID)
            } else {
                updated.remove(entry.objectID)
            }
        }
        expandedEntries = updated
    }
}

private struct AIScoreEntryCard: View {
    @ObservedObject var entry: NailEntry
    let isEvaluating: Bool
    let evaluateAction: () -> Void
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    @State private var photoHashHasChanged = false
    @State private var hashCheckCompleted = false

    private var displayTitle: String {
        let name = (entry.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（タイトルなし）" : name
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: entry.date ?? entry.createdAt ?? Date())
    }

    private var canEvaluate: Bool {
        entry.photoId != nil
    }

    private var displayData: AIScoreDisplayData? {
        guard let bridge = entry.aiScoreBridge else { return nil }
        return AIScoreDisplayData(score: bridge)
    }

    private var shouldShowEvaluateButton: Bool {
        guard canEvaluate else { return false }
        guard displayData != nil else { return true }
        guard hashCheckCompleted else { return false }
        return photoHashHasChanged
    }

    private var hashCheckKey: String {
        let photoKey = entry.photoId?.uuidString ?? "no-photo"
        let storedHash = entry.aiScoreBridge?.photoHash ?? "no-hash"
        return "\(entry.objectID.uriRepresentation().absoluteString)--\(photoKey)--\(storedHash)"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    EntryThumbnailView(photoId: entry.photoId, aiScore: entry.aiScoreBridge?.totalScore)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let data = displayData?.evaluatedAt {
                            Text("最終評価: \(formatted(date: data))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("AI未評価")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                if let data = displayData {
                    if isExpanded {
                        EntryAIScoreSummaryView(data: data)
                    }
                    Button {
                        toggleExpanded()
                    } label: {
                        Label(isExpanded ? "評価結果を閉じる" : "評価結果を表示", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("まだAI評価がありません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if shouldShowEvaluateButton {
                    Button {
                        evaluateAction()
                    } label: {
                        if isEvaluating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        } else {
                            Label(displayData == nil ? "AIスコアを生成" : "再評価を実行", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canEvaluate || isEvaluating)
                } else if displayData != nil {
                    Text("写真が変わるまで再評価は実行できません。")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !canEvaluate {
                    Text("※評価には記録写真が必要です。")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
            }
        }
        .task(id: hashCheckKey) {
            await refreshPhotoHashState()
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    @MainActor
    private func refreshPhotoHashState() async {
        guard displayData != nil else {
            photoHashHasChanged = true
            hashCheckCompleted = true
            return
        }
        guard let expectedHash = entry.aiScoreBridge?.photoHash else {
            photoHashHasChanged = true
            hashCheckCompleted = true
            return
        }
        guard let photoId = entry.photoId else {
            photoHashHasChanged = false
            hashCheckCompleted = true
            return
        }

        hashCheckCompleted = false

        let hasChanged = await AIScoreEntryCard.isPhotoHashDifferent(photoId: photoId, expectedHash: expectedHash)
        if Task.isCancelled { return }
        photoHashHasChanged = hasChanged
        hashCheckCompleted = true
    }

    private static func isPhotoHashDifferent(photoId: UUID, expectedHash: String) async -> Bool {
        guard let imageData = await MainActor.run(body: { () -> Data? in
            guard let image = EntryPhotoStore.loadFull(photoId: photoId) ??
                              EntryPhotoStore.loadThumbnail(photoId: photoId) else {
                return nil
            }
            return image.resized(maxPixel: 1024).jpegData(compressionQuality: 0.7)
        }) else {
            return true
        }
        return await Task.detached(priority: .background) {
            imageData.sha256Hex() != expectedHash
        }.value
    }
}

// MARK: - Summary View

private struct AIScoreDisplayData: Identifiable {
    let id = UUID()

    let totalScore: Int
    let finishQuality: Int
    let edgeAndCuticle: Int
    let thicknessBalance: Int
    let designBalance: Int
    let durabilityPrediction: Int
    let highlights: [String]
    let improvements: [String]
    let nextSteps: [String]
    let caution: String?
    let confidence: Double
    let assumptions: [String]
    let evaluatedAt: Date?
}

private struct AIScoreMetricComment: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

private extension AIScoreDisplayData {
    init(score: EntryAIScoreBridge) {
        self.totalScore = Int(score.totalScore)
        self.finishQuality = Int(score.finishQuality)
        self.edgeAndCuticle = Int(score.edgeAndCuticle)
        self.thicknessBalance = Int(score.thicknessBalance)
        self.designBalance = Int(score.designBalance)
        self.durabilityPrediction = Int(score.durabilityPrediction)
        self.highlights = score.highlightsArray
        self.improvements = score.improvementsArray
        self.nextSteps = score.nextStepsArray
        self.caution = score.caution
        self.confidence = score.confidence
        self.assumptions = score.assumptionsArray
        self.evaluatedAt = score.evaluatedAt
    }

    static var sample: AIScoreDisplayData {
        AIScoreDisplayData(
            totalScore: 78,
            finishQuality: 80,
            edgeAndCuticle: 75,
            thicknessBalance: 72,
            designBalance: 85,
            durabilityPrediction: 70,
            highlights: [
                "仕上がり: 色ムラが少なく、光の反射も均一でツヤがきれいに出ています。",
                "甘皮ライン: ライン際は概ね整っていますが、薬指だけ境界にわずかな揺れが見えます。",
                "厚み: 全体の厚みは安定していますが、先端側が少しだけ重く見える箇所があります。",
                "デザイン: 配色の統一感が高く、視線誘導が自然で完成度の高いバランスです。",
                "持ち予測: 現状なら日常使用で十分持つ見込みですが、先端の摩耗には注意が必要です。"
            ],
            improvements: [
                "甘皮ライン付近をもう少し薄く塗り広げると境目が馴染みそうです",
                "薬指の先端に軽い凹凸があるため、トップの厚みを均一にしてみてください"
            ],
            nextSteps: [
                "トップコートを薄く2回重ねて艶と強度を伸ばす",
                "自然光で撮影して色味を記録すると比較しやすい",
                "次回はベース前にオイルを控えて密着感を高める"
            ],
            caution: "爪が薄い場合は頻繁なオフ・オンを避けてください",
            confidence: 0.82,
            assumptions: [
                "室内の自然光で撮影されたと想定しています",
                "ワンカラー寄りのニュアンスデザインとして解析しました"
            ],
            evaluatedAt: Date()
        )
    }

    var metricComments: [AIScoreMetricComment] {
        let orderedTitles = ["仕上がり", "甘皮ライン", "厚み", "デザイン", "持ち予測"]
        let parsed = parseMetricComments(from: highlights)

        if orderedTitles.allSatisfy({ parsed[$0] != nil }) {
            return orderedTitles.compactMap { title in
                guard let text = parsed[title], !text.isEmpty else { return nil }
                return AIScoreMetricComment(title: title, text: text)
            }
        }

        let fallbackScores: [(String, Int)] = [
            ("仕上がり", finishQuality),
            ("甘皮ライン", edgeAndCuticle),
            ("厚み", thicknessBalance),
            ("デザイン", designBalance),
            ("持ち予測", durabilityPrediction)
        ]
        return fallbackScores.map { title, score in
            AIScoreMetricComment(title: title, text: fallbackMetricComment(title: title, score: score))
        }
    }

    private func parseMetricComments(from items: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for item in items {
            let normalized = item.replacingOccurrences(of: "：", with: ":")
            guard let separatorIndex = normalized.firstIndex(of: ":") else { continue }
            let title = String(normalized[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let textStart = normalized.index(after: separatorIndex)
            let text = String(normalized[textStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !text.isEmpty else { continue }
            result[title] = text
        }
        return result
    }

    private func fallbackMetricComment(title: String, score: Int) -> String {
        switch score {
        case 85...100:
            return "\(title)は高水準です。現在の手順を維持すると再現性を保ちやすいです。"
        case 70..<85:
            return "\(title)は安定しています。細部を少し整えるとさらに完成度が上がります。"
        default:
            return "\(title)は改善余地があります。工程を分けて丁寧に確認すると向上しやすいです。"
        }
    }
}

private struct EntryAIScoreSummaryView: View {
    let data: AIScoreDisplayData

    private var radarMetrics: [AIScoreRadarChart.Metric] {
        [
            .init(title: "仕上がり", value: Double(data.finishQuality)),
            .init(title: "甘皮ライン", value: Double(data.edgeAndCuticle)),
            .init(title: "厚み", value: Double(data.thicknessBalance)),
            .init(title: "デザイン", value: Double(data.designBalance)),
            .init(title: "持ち予測", value: Double(data.durabilityPrediction))
        ]
    }

    private var formattedDate: String {
        guard let date = data.evaluatedAt else { return "未評価" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AIスコア")
                    .font(.headline)
                Spacer()
                Text("評価日時: \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            AIScoreRadarChart(metrics: radarMetrics, centerText: "\(data.totalScore)")
                .frame(height: 220)
                .padding(.top, 8)

            if !data.metricComments.isEmpty {
                MetricCommentListView(comments: data.metricComments)
            }
            if !data.nextSteps.isEmpty {
                TagListView(title: "Next", icon: "arrowshape.turn.up.forward.fill", tags: data.nextSteps)
            }
            if !data.assumptions.isEmpty {
                TagListView(title: "前提条件", icon: "info.circle", tags: data.assumptions)
            }

            if let caution = data.caution, !caution.isEmpty {
                Label {
                    Text(caution)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Text(String(format: "信頼度: %.0f%%", data.confidence * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AISampleCardView: View {
    @Binding var showingSample: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI出力サンプル")
                    .font(.headline)
                Text("評価を実行する前に、UI上でどのように結果が表示されるかを確認できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showingSample = true
                } label: {
                    Label("AI出力サンプルを確認", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct MetricCommentListView: View {
    let comments: [AIScoreMetricComment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("5項目コメント", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(comment.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct TagListView: View {
    let title: String
    let icon: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct AIScoreRadarChart: View {
    struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: Double
    }

    let metrics: [Metric]
    let centerText: String?
    private let gridLevel: Int = 4

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = (size / 2) * 0.86
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.78, green: 0.95, blue: 0.84).opacity(0.22),
                                Color(red: 0.65, green: 0.86, blue: 0.74).opacity(0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: radius * 1.25
                        )
                    )
                    .frame(width: radius * 2.35, height: radius * 2.35)
                    .position(center)

                ForEach(1...gridLevel, id: \.self) { level in
                    radarPath(scale: Double(level) / Double(gridLevel), center: center, radius: radius)
                        .stroke(
                            level == gridLevel
                            ? Color(red: 0.38, green: 0.64, blue: 0.49).opacity(0.60)
                            : Color(red: 0.50, green: 0.73, blue: 0.58).opacity(0.30),
                            lineWidth: level == gridLevel ? 1.1 : 0.9
                        )
                }

                radarPath(scale: 1.0, center: center, radius: radius)
                    .stroke(
                        Color(red: 0.44, green: 0.70, blue: 0.54).opacity(0.52),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, _ in
                    Path { path in
                        path.move(to: center)
                        path.addLine(
                            to: point(
                                for: index,
                                total: metrics.count,
                                value: 1.0,
                                center: center,
                                radius: radius
                            )
                        )
                    }
                    .stroke(Color(red: 0.52, green: 0.74, blue: 0.60).opacity(0.34), lineWidth: 0.8)
                }

                if !metrics.isEmpty {
                    let filledPath = dataPath(center: center, radius: radius)
                    filledPath
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.38, green: 0.78, blue: 0.58).opacity(0.42),
                                    Color(red: 0.36, green: 0.66, blue: 0.50).opacity(0.22),
                                    Color(red: 0.68, green: 0.90, blue: 0.78).opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottom
                            )
                        )
                    filledPath
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.66, blue: 0.45),
                                    Color(red: 0.27, green: 0.55, blue: 0.41)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.4
                        )
                        .shadow(color: Color(red: 0.24, green: 0.64, blue: 0.44).opacity(0.35), radius: 6, x: 0, y: 3)

                    ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                        let normalized = max(0, min(metric.value / 100, 1))
                        let dataPoint = point(
                            for: index,
                            total: metrics.count,
                            value: normalized,
                            center: center,
                            radius: radius
                        )
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.64, green: 0.90, blue: 0.74).opacity(0.36))
                                .frame(width: 14, height: 14)
                                .blur(radius: 2)
                            Circle()
                                .fill(Color(red: 0.95, green: 1.0, blue: 0.96).opacity(0.96))
                                .frame(width: 7, height: 7)
                            Circle()
                                .stroke(Color(red: 0.26, green: 0.68, blue: 0.46), lineWidth: 1.4)
                                .frame(width: 10, height: 10)
                        }
                        .position(dataPoint)
                    }
                }

                if let centerText {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.92, green: 0.99, blue: 0.94).opacity(0.96),
                                        Color(red: 0.84, green: 0.95, blue: 0.88).opacity(0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 66, height: 66)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.34, green: 0.78, blue: 0.56),
                                                Color(red: 0.30, green: 0.62, blue: 0.45)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.6
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)

                        VStack(spacing: 1) {
                            Text(centerText)
                                .font(.title3.weight(.black))
                                .foregroundStyle(Color(red: 0.14, green: 0.50, blue: 0.31))
                            Text("TOTAL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.27, green: 0.56, blue: 0.38))
                        }
                    }
                    .position(center)
                }

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    let labelPoint = point(for: index,
                                           total: metrics.count,
                                           value: 1.18,
                                           center: center,
                                           radius: radius)
                    VStack(spacing: 1) {
                        Text(metric.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(Int(metric.value))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.91, green: 0.98, blue: 0.93).opacity(0.84))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.53, green: 0.77, blue: 0.61).opacity(0.58), lineWidth: 0.9)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                    .position(labelPoint)
                }
            }
        }
    }

    private func radarPath(scale: Double, center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            guard !metrics.isEmpty else { return }
            let start = point(for: 0, total: metrics.count, value: scale, center: center, radius: radius)
            path.move(to: start)
            for index in 1..<metrics.count {
                path.addLine(to: point(for: index, total: metrics.count, value: scale, center: center, radius: radius))
            }
            path.closeSubpath()
        }
    }

    private func dataPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            guard !metrics.isEmpty else { return }
            let firstValue = metrics[0].value / 100
            let start = point(for: 0,
                              total: metrics.count,
                              value: firstValue,
                              center: center,
                              radius: radius)
            path.move(to: start)
            for index in 1..<metrics.count {
                let normalized = max(0, min(metrics[index].value / 100, 1))
                path.addLine(to: point(for: index,
                                       total: metrics.count,
                                       value: normalized,
                                       center: center,
                                       radius: radius))
            }
            path.closeSubpath()
        }
    }

    private func point(for index: Int,
                       total: Int,
                       value: Double,
                       center: CGPoint,
                       radius: CGFloat) -> CGPoint {
        let angle = (Double(index) / Double(total)) * (2 * Double.pi) - Double.pi / 2
        let length = radius * value
        let x = center.x + CGFloat(cos(angle)) * length
        let y = center.y + CGFloat(sin(angle)) * length
        return CGPoint(x: x, y: y)
    }
}

private struct AdPlaceholderBanner: View {
    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("広告枠（将来用）")
                        .font(.headline)
                    Text("AIコーチングやキャンペーン情報をここに掲載予定です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "megaphone.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - Sample Sheet

private struct AIScoreSampleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        EntryAIScoreSummaryView(data: .sample)
                    }
                    Text("実際のレスポンスはJSON形式ですが、このプレビューではUIに近い形で内容のみ確認できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .navigationTitle("AI出力サンプル")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - AI Score Models / Service

private struct AINailScoreRequest: Encodable {
    struct PhotoPayload: Encodable {
        let filename: String
        let base64Data: String
    }

    let photos: [PhotoPayload]
    let designTag: String?
    let productsUsed: [String]
    let userGoal: String?
}

private struct AINailScoreResponse: Decodable {
    struct Scores: Decodable {
        let finish_quality: Int
        let edge_and_cuticle: Int
        let thickness_balance: Int
        let design_balance: Int
        let durability_prediction: Int
    }

    let total_score: Int
    let scores: Scores
    let highlights: [String]
    let improvements: [String]
    let next_steps: [String]
    let caution: String?
    let confidence: Double
    let assumptions: [String]
}

private enum AINailScoreError: Error, LocalizedError {
    case missingPhoto
    case quotaExceeded
    case duplicateEvaluation
    case serviceUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingPhoto:
            return "評価できる写真が見つかりません。"
        case .quotaExceeded:
            return "今月のAIネイルスコア利用上限に達しました。"
        case .duplicateEvaluation:
            return "同じ写真は再評価を行いません。"
        case .serviceUnavailable:
            return "AI評価サービスに接続できませんでした。時間をおいて再度お試しください。"
        case .invalidResponse:
            return "AIの評価を解析できませんでした。"
        }
    }
}

final class AINailScoreService {
    static let shared = AINailScoreService()
    private init() {}

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    private lazy var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter
    }()

    func evaluate(entry: NailEntry,
                  userGoal: String?,
                  context: NSManagedObjectContext) async throws -> EntryAIScoreBridge {
        guard let photoId = entry.photoId,
              let originalImage = EntryPhotoStore.loadFull(photoId: photoId) ??
                                  EntryPhotoStore.loadThumbnail(photoId: photoId) else {
            throw AINailScoreError.missingPhoto
        }

        let resized = originalImage.resized(maxPixel: 1024)
        guard let imageData = resized.jpegData(compressionQuality: 0.7) else {
            throw AINailScoreError.missingPhoto
        }

        let photoHash = imageData.sha256Hex()

        if let currentHash = entry.aiScoreBridge?.photoHash, currentHash == photoHash {
            throw AINailScoreError.duplicateEvaluation
        }

        let quota = try self.fetchOrCreateQuota(in: context)
        let limit: Int16 = 3
        if quota.aiScoreUsageCount >= limit {
            throw AINailScoreError.quotaExceeded
        }

        let requestPayload = self.makeRequestPayload(entry: entry,
                                                     imageData: imageData,
                                                     photoHash: photoHash,
                                                     userGoal: userGoal)

        let apiKey = self.resolveAPIKey()
        let response: AINailScoreResponse
        if let apiKey {
            response = try await self.performRemoteEvaluation(request: requestPayload, apiKey: apiKey)
        } else {
            response = self.generateMockResponse(for: requestPayload)
        }

        var score = entry.ensureAIScoreBridge(in: context)
        score.totalScore = Int16(response.total_score)
        score.finishQuality = Int16(response.scores.finish_quality)
        score.edgeAndCuticle = Int16(response.scores.edge_and_cuticle)
        score.thicknessBalance = Int16(response.scores.thickness_balance)
        score.designBalance = Int16(response.scores.design_balance)
        score.durabilityPrediction = Int16(response.scores.durability_prediction)
        score.highlightsArray = response.highlights
        score.improvementsArray = response.improvements
        score.nextStepsArray = response.next_steps
        score.caution = response.caution
        score.confidence = response.confidence
        score.assumptionsArray = response.assumptions
        score.evaluatedAt = Date()
        score.photoHash = photoHash

        quota.aiScoreUsageCount += 1
        quota.updatedAt = Date()

        try context.save()
        return score
    }

    private func makeRequestPayload(entry: NailEntry,
                                    imageData: Data,
                                    photoHash: String,
                                    userGoal: String?) -> AINailScoreRequest {
        let base64 = imageData.base64EncodedString()
        let photoPayload = AINailScoreRequest.PhotoPayload(
            filename: "entry-\(entry.id?.uuidString ?? photoHash).jpg",
            base64Data: base64
        )

        let designName = NailDesignCategory(rawValue: entry.designCategory ?? "")?.displayName ?? entry.designCategory ?? "未設定"

        let products: [String] = (entry.usedItems?.array as? [NailEntryUsedItem])?
            .compactMap { $0.product?.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        return AINailScoreRequest(
            photos: [photoPayload],
            designTag: designName,
            productsUsed: products,
            userGoal: userGoal
        )
    }

    private func fetchOrCreateQuota(in context: NSManagedObjectContext) throws -> UsageQuota {
        let monthKey = monthFormatter.string(from: Date())
        let request = UsageQuota.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "monthKey == %@", monthKey)
        if let existing = try context.fetch(request).first {
            return existing
        }

        let quota = UsageQuota(context: context)
        quota.monthKey = monthKey
        quota.setValue(0, forKey: "freeSimRemaining")
        quota.aiScoreUsageCount = 0
        quota.updatedAt = Date()
        return quota
    }

    private func resolveAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty {
            return key
        }
        return nil
    }

    private func performRemoteEvaluation(request: AINailScoreRequest,
                                         apiKey: String) async throws -> AINailScoreResponse {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw AINailScoreError.serviceUnavailable
        }
        var components: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.2
        ]
        components["input"] = makePrompt(from: request)
        let bodyData = try JSONSerialization.data(withJSONObject: components, options: [])

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AINailScoreError.serviceUnavailable
        }

        do {
            return try jsonDecoder.decode(AINailScoreResponse.self, from: data)
        } catch {
            throw AINailScoreError.invalidResponse
        }
    }

    private func generateMockResponse(for request: AINailScoreRequest) -> AINailScoreResponse {
        func score() -> Int { Int.random(in: 65...90) }
        let total = score()
        let finish = score()
        let edge = score()
        let thickness = score()
        let design = score()
        let durability = score()
        return AINailScoreResponse(
            total_score: total,
            scores: .init(
                finish_quality: finish,
                edge_and_cuticle: edge,
                thickness_balance: thickness,
                design_balance: design,
                durability_prediction: durability
            ),
            highlights: [
                "仕上がり: ムラは少なく、ツヤの出方も比較的均一です（\(finish)点）。",
                "甘皮ライン: 境目は概ね整っていますが、指ごとの差を少し詰められそうです（\(edge)点）。",
                "厚み: 全体は安定していますが、先端側の厚みバランスに軽い改善余地があります（\(thickness)点）。",
                "デザイン: 配色と配置のまとまりが良く、視認性の高い仕上がりです（\(design)点）。",
                "持ち予測: 日常使用では十分持つ見込みですが、先端摩耗へのケアが有効です（\(durability)点）。"
            ],
            improvements: [
                "ライン周りを明るい環境で確認して微調整すると良いかもしれません",
                "フォルムをチェックするため別角度の写真も撮ってみてください"
            ],
            next_steps: [
                "トップコートを薄めに2回重ねて強度を底上げする",
                "撮影時に自然光を取り入れて色味を再確認する",
                "次回は甘皮処理を丁寧に行いカーブを整えてみる"
            ],
            caution: "爪が薄く感じる場合は頻繁なオフ・オンを控えてください",
            confidence: 0.75,
            assumptions: [
                "室内の自然光で撮影されたと仮定しています",
                "ワンカラー寄りのデザインとして評価しました"
            ]
        )
    }

    private func makePrompt(from request: AINailScoreRequest) -> String {
        var builder = """
        You are a helpful assistant that evaluates self-nail photos.
        Return JSON with scores and comments per the required structure (total_score, scores, highlights, improvements, next_steps, caution, confidence, assumptions).
        highlights must contain exactly 5 Japanese comments, one for each score item in this order:
        1) 仕上がり (finish_quality)
        2) 甘皮ライン (edge_and_cuticle)
        3) 厚み (thickness_balance)
        4) デザイン (design_balance)
        5) 持ち予測 (durability_prediction)
        Each highlight item must start with "項目名: " style text.
        Avoid definitive expressions and keep comments between 200 and 500 Japanese characters.

        Photos (Base64): \(request.photos.map { $0.filename }.joined(separator: ", "))
        Design tag: \(request.designTag ?? "unspecified")
        Products used: \(request.productsUsed.joined(separator: ", "))
        User goal: \(request.userGoal ?? "unspecified")
        """
        builder += "\nOutput JSON only."
        return builder
    }

}

private extension Data {
    nonisolated func sha256Hex() -> String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - UIImage helper

private extension UIImage {
    func resized(maxPixel: CGFloat = 1024) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxPixel else { return self }
        let scale = maxPixel / maxSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - UsageQuota helper

extension UsageQuota {
    var aiScoreUsageCount: Int16 {
        get { value(forKey: "aiScoreUsed") as? Int16 ?? 0 }
        set { setValue(newValue, forKey: "aiScoreUsed") }
    }
}
