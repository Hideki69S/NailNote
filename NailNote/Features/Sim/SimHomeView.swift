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
        GlassBackgroundView {
            navigationContent
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AdPlaceholderBanner()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    contentStack
                        .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSample = true
                    } label: {
                        Label("出力サンプル", systemImage: "doc.richtext")
                    }
                }
            }
            .sheet(isPresented: $showingSample) {
                AIScoreSampleView()
            }
            .onAppear {
                syncExpandedEntries()
            }
            .onChange(of: evaluationSnapshots) { _, _ in
                syncExpandedEntries()
            }
            .alert("AIネイルスコア", isPresented: alertBinding) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .confirmationDialog(
                "AIネイルスコア",
                isPresented: confirmationDialogBinding,
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
    }

    private var contentStack: some View {
        VStack(spacing: 16) {
            heroCard
            sampleCard
            if entries.isEmpty {
                ContentUnavailableView("評価できる記録がありません", systemImage: "camera")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(entries, id: \.objectID) { entry in
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
    }

    private var evaluationSnapshots: [Date?] {
        entries.map { $0.aiScoreBridge?.evaluatedAt }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

    private var confirmationDialogBinding: Binding<Bool> {
        Binding(
            get: { entryPendingConfirmation != nil },
            set: { if !$0 { entryPendingConfirmation = nil } }
        )
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

    private var sampleCard: some View {
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
                    EntryThumbnailView(photoId: entry.photoId)
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
                    Text("まだAI評価がありません。写真付きの記録なら、下のボタンからすぐに採点できます。")
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
                "色ムラが少なくツヤがきれいに出ています",
                "パーツ配置が整っていて統一感があります",
                "手肌のトーンとも相性が良い色味に見えます"
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("AIスコア")
                        .font(.headline)
                    Text("評価日時: \(formattedDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    Text("\(data.totalScore)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }

            AIScoreRadarChart(metrics: radarMetrics)
                .frame(height: 200)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    scoreRow(title: "仕上がり", value: data.finishQuality)
                    scoreRow(title: "甘皮ライン", value: data.edgeAndCuticle)
                }
                GridRow {
                    scoreRow(title: "厚み", value: data.thicknessBalance)
                    scoreRow(title: "デザイン", value: data.designBalance)
                }
                GridRow {
                    scoreRow(title: "持ち予測", value: data.durabilityPrediction)
                    Spacer()
                }
            }

            if !data.highlights.isEmpty {
                TagListView(title: "Good", icon: "hand.thumbsup.fill", tags: data.highlights)
            }
            if !data.improvements.isEmpty {
                TagListView(title: "Improve", icon: "wrench.adjustable.fill", tags: data.improvements)
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

    private func scoreRow(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(value), total: 100)
                .tint(Color.accentColor)
            Text("\(value)")
                .font(.caption.bold())
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
    private let gridLevel: Int = 4

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size / 2
            ZStack {
                ForEach(1...gridLevel, id: \.self) { level in
                    radarPath(scale: Double(level) / Double(gridLevel), center: center, radius: radius)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }

                radarPath(scale: 1.0, center: center, radius: radius)
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if !metrics.isEmpty {
                    let filledPath = dataPath(center: center, radius: radius)
                    filledPath
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.35),
                                    Color.accentColor.opacity(0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    filledPath
                        .stroke(Color.accentColor, lineWidth: 2)
                }

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    let labelPoint = point(for: index,
                                           total: metrics.count,
                                           value: 1.1,
                                           center: center,
                                           radius: radius)
                    VStack(spacing: 2) {
                        Text("\(Int(metric.value))")
                            .font(.caption.bold())
                            .foregroundStyle(Color.primary)
                        Text(metric.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        return AINailScoreResponse(
            total_score: total,
            scores: .init(
                finish_quality: score(),
                edge_and_cuticle: score(),
                thickness_balance: score(),
                design_balance: score(),
                durability_prediction: score()
            ),
            highlights: [
                "写真からはムラの少ない仕上がりに見えます",
                "デザインの統一感が保たれているようです",
                "ツヤ感があり光の映り込みもきれいです"
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
