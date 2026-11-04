import Foundation
import CryptoKit
import ImageIO
import Darwin

// 未知の設定を読み取り時に捨てず、非対応のまま保存を止めるための値。
nonisolated indirect enum PlateStyleValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: PlateStyleValue]), array([PlateStyleValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([String: PlateStyleValue].self) { self = .object(v) }
        else { self = .array(try c.decode([PlateStyleValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var string: String? { if case .string(let v) = self { return v }; return nil }
}

nonisolated struct PlateTextStyle: Codable, Equatable, Sendable {
    var values: [String: PlateStyleValue] = [:]
    init() {}
    init(from decoder: Decoder) throws { values = try [String: PlateStyleValue](from: decoder) }
    func encode(to encoder: Encoder) throws { try values.encode(to: encoder) }
    var fontID: String {
        get { values["fontID"]?.string ?? "standard" }
        set { values["fontID"] = .string(newValue) }
    }
    var weightID: String {
        get { values["weightID"]?.string ?? "auto" }
        set { values["weightID"] = .string(newValue) }
    }
    static let fontIDs = ["standard", "hiramin", "modern", "hiramaru", "zenmarugothic", "kosugimaru", "hachimarupop", "yomogi", "zenkurenaido", "yuseimagic", "kaiseidecol", "mochiypopone"]
    static func weights(_ font: String) -> [String] {
        switch font {
        case "standard", "modern": return ["auto", "light", "regular", "bold"]
        case "hiramin": return ["auto", "regular", "bold"]
        case "zenmarugothic", "kaiseidecol": return ["auto", "regular", "medium", "bold"]
        default: return ["auto", "regular"]
        }
    }
    var hexRGB: String? {
        guard case .object(let c) = values["color"], c["mode"]?.string == "custom" else { return nil }
        return c["hexRGB"]?.string
    }
    mutating func setColor(_ hex: String?) {
        if let hex { values["color"] = .object(["mode": .string("custom"), "colorSpace": .string("srgb"), "hexRGB": .string(hex)]) }
        else { values.removeValue(forKey: "color") }
    }
    private func defaultOrString(_ key: String) -> Bool {
        values[key] == nil || values[key] == .null || values[key]?.string != nil
    }
    var supported: Bool {
        guard Set(values.keys).isSubset(of: ["fontID", "weightID", "color"]), defaultOrString("fontID"), defaultOrString("weightID"),
              Self.fontIDs.contains(fontID), Self.weights(fontID).contains(weightID) else { return false }
        guard let color = values["color"], color != .null else { return true }
        guard case .object(let c) = color else { return false }
        if c["mode"]?.string == "template" { return Set(c.keys).isSubset(of: ["mode"]) }
        guard Set(c.keys) == ["mode", "colorSpace", "hexRGB"], c["mode"]?.string == "custom", c["colorSpace"]?.string == "srgb",
              let hex = c["hexRGB"]?.string, hex.count == 7, hex.first == "#" else { return false }
        return hex.dropFirst().allSatisfy { "0123456789abcdefABCDEF".contains($0) }
    }
    var isLegacy: Bool { supported && fontID == "standard" && weightID == "auto" && hexRGB == nil }
}

// 保存DTOはSwiftUI・CoreData・端末の絶対パスに依存しない。
nonisolated struct PlateSavedAdjustment: Codable, Equatable, Sendable {
    var zoom: Double
    var x: Double
    var y: Double
}

nonisolated struct PlateSavedProduct: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var category: String
    var inherited: Bool
}

nonisolated struct PlateFileReference: Codable, Equatable, Sendable {
    var path: String
    var sha256: String
}

nonisolated struct PlateDocument: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var rendererVersion = 1
    var plateID: UUID
    var revisionID: UUID
    var createdAt: Date
    var updatedAt: Date
    var sourceEntryID: UUID
    var templateID: String
    var canvasAspectRatio = "4:5"
    var title: String
    var dateText: String
    var comment: String
    var backgroundStyle: String
    var frameStyle: String
    var photoAdjustments: [String: PlateSavedAdjustment]
    var selectedProducts: [PlateSavedProduct]
    var productOrder: [UUID]
    var unavailableSourceProducts: Int
    var photoReference: PlateFileReference?
    var thumbnailReference: PlateFileReference
    var photoRotationQuarterTurns: Int? = nil
    var titleTextStyle: PlateTextStyle? = nil
    var commentTextStyle: PlateTextStyle? = nil
    var textStylesSupported: Bool { (titleTextStyle?.supported ?? true) && (commentTextStyle?.supported ?? true) }

    func validate() throws {
        guard schemaVersion == 1, [1, 2, 3].contains(rendererVersion) else { throw PlateStorageError.unsupported }
        guard rendererVersion >= 2 || ((titleTextStyle?.isLegacy ?? true) && (commentTextStyle?.isLegacy ?? true)) else { throw PlateStorageError.unsupported }
        if let turns = photoRotationQuarterTurns {
            guard (0...3).contains(turns), turns == 0 || rendererVersion == 3 else { throw PlateStorageError.unsupported }
        }
        guard canvasAspectRatio == "4:5", ["elegant", "noir", "sweet", "recipe"].contains(templateID),
              ["signature", "solid", "gradient"].contains(backgroundStyle),
              ["signature", "metal", "simple", "glass"].contains(frameStyle),
              createdAt.timeIntervalSince1970.isFinite, updatedAt.timeIntervalSince1970.isFinite,
              Set(productOrder).count == productOrder.count,
              productOrder == selectedProducts.map(\.id), unavailableSourceProducts >= 0,
              thumbnailReference.path == "thumbnail.jpg" else { throw PlateStorageError.invalid }
        for (key, value) in photoAdjustments {
            guard ["elegant", "noir", "sweet", "recipe"].contains(key), value.zoom.isFinite,
                  (1...3).contains(value.zoom), value.x.isFinite, (-1...1).contains(value.x),
                  value.y.isFinite, (-1...1).contains(value.y) else { throw PlateStorageError.invalid }
        }
        if let reference = photoReference {
            let parts = reference.path.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0] == "assets", reference.path.hasSuffix(".jpg"),
                  UUID(uuidString: String(parts[1].dropLast(4))) != nil else { throw PlateStorageError.invalid }
        }
    }
}

nonisolated enum PlateStorageError: LocalizedError, Sendable {
    case invalid, unsupported, conflict, damagedPhoto, unsafePath, missing, injected
    var errorDescription: String? {
        switch self {
        case .invalid: return "プレートの保存データが破損しているか、形式が正しくありません。"
        case .unsupported: return "このプレートの保存形式または描画形式には対応していません。上書きせず保護しています。"
        case .conflict: return "保存状態が変更されています。一覧から開き直してください。編集内容はこの画面に残っています。"
        case .damagedPhoto: return "保存済み写真が欠損または破損しています。写真なしでの上書きは停止しました。"
        case .unsafePath: return "安全な保存領域を確認できませんでした。"
        case .missing: return "プレートが見つかりません。"
        case .injected: return "検証用の保存失敗です。"
        }
    }
}

nonisolated struct PlateListItem: Identifiable, Sendable {
    let id: UUID
    let revisionID: UUID?
    let title: String
    let updatedAt: Date
    let issue: String?
}

nonisolated struct PlateLoadedDocument: Sendable {
    var document: PlateDocument
    var photoData: Data?
    var photoDamaged: Bool
}

// 非同期のファイル操作を直列化し、headの切替だけを保存の確定点にする。
actor PlateRepository {
    static let shared = PlateRepository()
    nonisolated let root: URL
    private let anchor: URL
    private let managedComponents: [String]
    private var physicalAnchor: URL?
    enum Checkpoint: Sendable { case staged, installed, beforeHead, afterHead, beforeDeleteHead, afterDeleteHead }
    private let checkpoint: (@Sendable (Checkpoint) throws -> Void)?
    private let fm = FileManager.default
    private let thumbnails = NSCache<NSString, NSData>()

    private struct Head: Codable {
        var schemaVersion = 1
        var plateID: UUID
        var revisionID: UUID
        var previousRevisionID: UUID?
        var title: String
        var updatedAt: Date
        var documentHash: String
        var deleted = false
    }

    init(root: URL? = nil, applicationSupport: URL? = nil, checkpoint: (@Sendable (Checkpoint) throws -> Void)? = nil) {
        // テストのApplication Supportも、本番と同じ準備・検証経路を通す。
        if let root {
            self.root = root
            anchor = URL(fileURLWithPath: (root.path as NSString).deletingLastPathComponent, isDirectory: true)
            managedComponents = [root.lastPathComponent]
        } else {
            anchor = applicationSupport ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.root = anchor.appendingPathComponent("NailNote/Plates", isDirectory: true)
            managedComponents = ["NailNote", "Plates"]
        }
        self.checkpoint = checkpoint
        thumbnails.countLimit = 40
        thumbnails.totalCostLimit = 16 * 1024 * 1024
    }

    nonisolated static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func validImage(_ bytes: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil), CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && Double(width) * Double(height) <= 100_000_000
    }

    private func validComponents(_ url: URL) -> Bool {
        url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost") &&
            !url.pathComponents.contains(".") && !url.pathComponents.contains("..") && !url.path.contains("\0")
    }

    private func attributes(_ url: URL) throws -> [FileAttributeKey: Any]? {
        do { return try fm.attributesOfItem(atPath: url.path) }
        catch {
            let error = error as NSError
            if (error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code)) ||
                (error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT)) { return nil }
            throw error
        }
    }

    private func requireDirectory(_ url: URL, create: Bool, intermediates: Bool = false) throws {
        if let existing = try attributes(url) {
            guard existing[.type] as? FileAttributeType == .typeDirectory else { throw PlateStorageError.unsafePath }
            return
        }
        guard create else { throw PlateStorageError.unsafePath }
        do { try fm.createDirectory(at: url, withIntermediateDirectories: intermediates) }
        catch {
            // 同時に作られた場合も、通常ディレクトリであることを確認してから使う。
            guard let existing = try attributes(url), existing[.type] as? FileAttributeType == .typeDirectory else { throw error }
        }
        guard let created = try attributes(url), created[.type] as? FileAttributeType == .typeDirectory else { throw PlateStorageError.unsafePath }
    }

    private func preparedRoot() throws -> URL {
        guard validComponents(root), validComponents(anchor),
              root.pathComponents == anchor.pathComponents + managedComponents else { throw PlateStorageError.unsafePath }
        if physicalAnchor == nil {
            // 信頼の起点より上のOS管理aliasは許可する。起点自体の不正リンク・同名ファイルは拒否する。
            try requireDirectory(anchor, create: true, intermediates: true)
            guard let resolved = Darwin.realpath(anchor.path, nil) else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            defer { free(resolved) }
            physicalAnchor = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
        }
        guard let physicalAnchor else { throw PlateStorageError.unsafePath }
        try requireDirectory(physicalAnchor, create: false)
        var directory = physicalAnchor
        for component in managedComponents {
            guard !component.isEmpty, component != ".", component != "..", !component.contains("/") else { throw PlateStorageError.unsafePath }
            directory.appendPathComponent(component, isDirectory: true)
            try requireDirectory(directory, create: true)
        }
        return directory
    }

    // 同じ資源のOS上位aliasではなく、信頼アンカー配下の要素と境界を検査する。
    private func safe(_ url: URL) throws -> URL {
        guard validComponents(url) else { throw PlateStorageError.unsafePath }
        let prepared = try preparedRoot()
        let components = url.pathComponents
        let prefix: [String]
        if components.starts(with: root.pathComponents) { prefix = root.pathComponents }
        else if components.starts(with: prepared.pathComponents) { prefix = prepared.pathComponents }
        else { throw PlateStorageError.unsafePath }
        let relative = components.dropFirst(prefix.count)
        var target = prepared
        for (index, component) in relative.enumerated() {
            guard !component.isEmpty, !component.contains("/") else { throw PlateStorageError.unsafePath }
            target.appendPathComponent(component)
            if let existing = try attributes(target) {
                let type = existing[.type] as? FileAttributeType
                guard type != .typeSymbolicLink,
                      index == relative.count - 1 ? (type == .typeDirectory || type == .typeRegular) : type == .typeDirectory else { throw PlateStorageError.unsafePath }
            }
        }
        return target
    }

    private func makeDirectory(_ url: URL, mustBeNew: Bool = false) throws {
        let target = try safe(url)
        let prepared = try preparedRoot()
        var directory = prepared
        let relative = target.pathComponents.dropFirst(prepared.pathComponents.count)
        for (index, component) in relative.enumerated() {
            directory.appendPathComponent(component, isDirectory: true)
            let existing = try attributes(directory)
            if mustBeNew && index == relative.count - 1 && existing != nil { throw PlateStorageError.conflict }
            try requireDirectory(directory, create: true)
        }
        _ = try safe(target)
    }

    private func parent(of url: URL) -> URL {
        URL(fileURLWithPath: (url.path as NSString).deletingLastPathComponent, isDirectory: true)
    }

    private func folder(_ id: UUID) throws -> URL { try safe(root.appendingPathComponent(id.uuidString, isDirectory: true)) }
    private func data(_ url: URL, limit: Int = 8 * 1024 * 1024) throws -> Data {
        let url = try safe(url)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= limit else { throw PlateStorageError.invalid }
        return try Data(contentsOf: url)
    }
    private func head(_ id: UUID) throws -> Head {
        let value = try JSONDecoder().decode(Head.self, from: data(folder(id).appendingPathComponent("head.json")))
        guard value.schemaVersion == 1 else { throw PlateStorageError.unsupported }
        guard value.plateID == id else { throw PlateStorageError.invalid }
        return value
    }
    private func document(_ h: Head) throws -> PlateDocument {
        guard !h.deleted else { throw PlateStorageError.missing }
        let url = try folder(h.plateID).appendingPathComponent("revisions/\(h.revisionID.uuidString)/document.json")
        let bytes = try data(url)
        guard Self.digest(bytes) == h.documentHash else { throw PlateStorageError.invalid }
        let value = try JSONDecoder().decode(PlateDocument.self, from: bytes)
        try value.validate()
        guard value.plateID == h.plateID, value.revisionID == h.revisionID else { throw PlateStorageError.invalid }
        return value
    }

    func list() throws -> [PlateListItem] {
        _ = try safe(root)
        guard fm.fileExists(atPath: root.path) else { return [] }
        let urls = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return urls.compactMap { url -> PlateListItem? in
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            do {
                let h = try head(id)
                if h.deleted { return nil }
                _ = try document(h)
                return PlateListItem(id: id, revisionID: h.revisionID, title: h.title, updatedAt: h.updatedAt, issue: nil)
            } catch {
                // 新規保存の未確定候補はheadを持たない。既存headの破損は0件と混同しない。
                guard fm.fileExists(atPath: url.appendingPathComponent("head.json").path) else { return nil }
                return PlateListItem(id: id, revisionID: nil, title: "読み込めないプレート", updatedAt: .distantPast, issue: error.localizedDescription)
            }
        }.sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
    }

    func load(_ id: UUID) throws -> PlateLoadedDocument {
        let doc = try document(head(id))
        guard let ref = doc.photoReference else { return PlateLoadedDocument(document: doc, photoData: nil, photoDamaged: false) }
        do {
            let bytes = try data(folder(id).appendingPathComponent(ref.path), limit: 100 * 1024 * 1024)
            guard Self.digest(bytes) == ref.sha256, Self.validImage(bytes) else { throw PlateStorageError.damagedPhoto }
            return PlateLoadedDocument(document: doc, photoData: bytes, photoDamaged: false)
        } catch { return PlateLoadedDocument(document: doc, photoData: nil, photoDamaged: true) }
    }

    func thumbnail(_ item: PlateListItem) throws -> Data {
        guard let revision = item.revisionID else { throw PlateStorageError.invalid }
        let key = "\(item.id)-\(revision)" as NSString
        if let bytes = thumbnails.object(forKey: key) { return bytes as Data }
        let h = try head(item.id)
        guard h.revisionID == revision else { throw PlateStorageError.conflict }
        let doc = try document(h)
        let bytes = try data(folder(item.id).appendingPathComponent("revisions/\(revision.uuidString)/thumbnail.jpg"))
        guard Self.digest(bytes) == doc.thumbnailReference.sha256 else { throw PlateStorageError.invalid }
        thumbnails.setObject(bytes as NSData, forKey: key, cost: bytes.count)
        return bytes
    }

    func save(_ input: PlateDocument, expectedRevision: UUID?, photo: Data?, thumbnail: Data, replacingPhoto: Bool = false) throws -> PlateDocument {
        guard input.textStylesSupported else { throw PlateStorageError.unsupported }
        try input.validate()
        var doc = input
        var damagedOldPhoto = false
        let dir = try folder(doc.plateID)
        let headURL = try safe(dir.appendingPathComponent("head.json"))
        let existing: Head?
        if fm.fileExists(atPath: headURL.path) {
            let h = try head(doc.plateID)
            guard !h.deleted, h.revisionID == expectedRevision else { throw PlateStorageError.conflict }
            if h.revisionID == doc.revisionID { return try document(h) }
            let old = try load(doc.plateID)
            guard !old.photoDamaged || (replacingPhoto && photo != nil && photo.map(Self.validImage) == true) else { throw PlateStorageError.damagedPhoto }
            guard old.document.textStylesSupported else { throw PlateStorageError.unsupported }
            damagedOldPhoto = old.photoDamaged
            doc.createdAt = old.document.createdAt
            existing = h
        } else {
            guard expectedRevision == nil else { throw PlateStorageError.conflict }
            existing = nil
        }
        guard Self.validImage(thumbnail), photo.map(Self.validImage) != false else { throw PlateStorageError.invalid }
        doc.updatedAt = Date()
        if existing == nil { doc.createdAt = doc.updatedAt }
        if let photo {
            let hash = Self.digest(photo)
            let old = try existing.map { try document($0).photoReference }
            let ref = old.flatMap { $0 }
            doc.photoReference = !damagedOldPhoto && ref?.sha256 == hash ? ref : PlateFileReference(path: "assets/\(UUID().uuidString).jpg", sha256: hash)
        } else { doc.photoReference = nil }
        doc.thumbnailReference = PlateFileReference(path: "thumbnail.jpg", sha256: Self.digest(thumbnail))
        try doc.validate()
        let stage = try safe(dir.appendingPathComponent("staging/\(doc.revisionID.uuidString)", isDirectory: true))
        guard !fm.fileExists(atPath: stage.path) else { throw PlateStorageError.conflict }
        try makeDirectory(stage)
        let bytes = try JSONEncoder().encode(doc)
        try bytes.write(to: stage.appendingPathComponent("document.json"), options: .atomic)
        try thumbnail.write(to: stage.appendingPathComponent("thumbnail.jpg"), options: .atomic)
        if let photo { try photo.write(to: stage.appendingPathComponent("source.jpg"), options: .atomic) }
        let decoded = try JSONDecoder().decode(PlateDocument.self, from: data(stage.appendingPathComponent("document.json")))
        guard decoded == doc, Self.digest(try data(stage.appendingPathComponent("thumbnail.jpg"))) == doc.thumbnailReference.sha256 else { throw PlateStorageError.invalid }
        if let ref = doc.photoReference {
            guard Self.digest(try data(stage.appendingPathComponent("source.jpg"), limit: 100 * 1024 * 1024)) == ref.sha256 else { throw PlateStorageError.invalid }
        }
        try checkpoint?(.staged)
        if let ref = doc.photoReference {
            let dest = try safe(dir.appendingPathComponent(ref.path))
            if !fm.fileExists(atPath: dest.path) {
                try makeDirectory(parent(of: dest))
                try fm.moveItem(at: stage.appendingPathComponent("source.jpg"), to: dest)
            }
        }
        let stagedPhoto = stage.appendingPathComponent("source.jpg")
        if fm.fileExists(atPath: stagedPhoto.path) { try fm.removeItem(at: stagedPhoto) }
        // 失敗時のstagingは保存データから所有元を特定できる。無差別清掃はしない。
        let revision = try safe(dir.appendingPathComponent("revisions/\(doc.revisionID.uuidString)", isDirectory: true))
        try makeDirectory(parent(of: revision))
        try makeDirectory(revision, mustBeNew: true)
        for name in ["document.json", "thumbnail.jpg"] { try fm.moveItem(at: stage.appendingPathComponent(name), to: revision.appendingPathComponent(name)) }
        try fm.removeItem(at: stage)
        try checkpoint?(.installed)
        if let existing { guard try head(doc.plateID).revisionID == existing.revisionID else { throw PlateStorageError.conflict } }
        try checkpoint?(.beforeHead)
        let newHead = Head(plateID: doc.plateID, revisionID: doc.revisionID, previousRevisionID: existing?.revisionID, title: doc.title, updatedAt: doc.updatedAt, documentHash: Self.digest(bytes))
        try JSONEncoder().encode(newHead).write(to: headURL, options: .atomic)
        // 確定後の診断・整理エラーで、確定済み保存を未保存と報告しない。
        try? checkpoint?(.afterHead)
        return doc
    }

    func duplicate(_ id: UUID, expectedRevision: UUID) throws -> PlateDocument {
        let value = try load(id)
        guard value.document.revisionID == expectedRevision else { throw PlateStorageError.conflict }
        guard !value.photoDamaged else { throw PlateStorageError.damagedPhoto }
        var copy = value.document
        let item = PlateListItem(id: id, revisionID: expectedRevision, title: copy.title, updatedAt: copy.updatedAt, issue: nil)
        let thumb = try thumbnail(item)
        copy.plateID = UUID(); copy.revisionID = UUID()
        return try save(copy, expectedRevision: nil, photo: value.photoData, thumbnail: thumb)
    }

    func delete(_ id: UUID, expectedRevision: UUID) throws -> String? {
        var h = try head(id)
        guard !h.deleted, h.revisionID == expectedRevision else { throw PlateStorageError.conflict }
        _ = try document(h)
        try checkpoint?(.beforeDeleteHead)
        h.deleted = true
        try JSONEncoder().encode(h).write(to: folder(id).appendingPathComponent("head.json"), options: .atomic)
        do {
            try checkpoint?(.afterDeleteHead)
            let dir = try folder(id)
            // 既知revisionのJSONで所有を検証したファイルだけを削除する。
            let revisions = dir.appendingPathComponent("revisions")
            for revision in try fm.contentsOfDirectory(at: safe(revisions), includingPropertiesForKeys: nil) {
                guard let rid = UUID(uuidString: revision.lastPathComponent) else { continue }
                let doc = try JSONDecoder().decode(PlateDocument.self, from: data(revision.appendingPathComponent("document.json")))
                try doc.validate()
                guard doc.plateID == id, doc.revisionID == rid else { throw PlateStorageError.invalid }
                if let ref = doc.photoReference {
                    let asset = try safe(dir.appendingPathComponent(ref.path))
                    if fm.fileExists(atPath: asset.path) {
                        guard Self.digest(try data(asset, limit: 100 * 1024 * 1024)) == ref.sha256 else { throw PlateStorageError.invalid }
                        try fm.removeItem(at: asset)
                    }
                }
                for name in ["thumbnail.jpg", "document.json"] {
                    let file = try safe(revision.appendingPathComponent(name))
                    if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
                }
            }
            let staging = try safe(dir.appendingPathComponent("staging"))
            if fm.fileExists(atPath: staging.path), !(try fm.contentsOfDirectory(atPath: staging.path)).isEmpty {
                return "一覧から削除しましたが、未確定版の専用ファイルが残っています。安全を確認できるまで保持しています。"
            }
            return nil
        } catch { return "一覧から削除しましたが、一部の専用ファイルの整理が完了していません。\n" + error.localizedDescription }
    }
}
