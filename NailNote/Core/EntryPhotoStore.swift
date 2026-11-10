import Foundation
import UIKit
import CoreData
import CryptoKit

enum EntryPhotoStore {
    private static let folderName = "entry_photos"

    static func thumbnailURL(photoId: UUID) -> URL {
        photosFolderURL()
            .appendingPathComponent("thumb_\(photoId.uuidString).jpg")
    }

    static func fullURL(photoId: UUID) -> URL {
        photosFolderURL()
            .appendingPathComponent("full_\(photoId.uuidString).jpg")
    }

    /// 閲覧専用。保存ディレクトリの作成や既存ファイルの変更を行わない。
    static func readOnlyFullURL(photoId: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("full_\(photoId.uuidString).jpg")
    }

    static func loadThumbnail(photoId: UUID) -> UIImage? {
        let url = thumbnailURL(photoId: photoId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func loadFull(photoId: UUID) -> UIImage? {
        let url = fullURL(photoId: photoId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func save(image: UIImage, photoId: UUID) {
        // フルサイズ保存
        if let fullData = image.jpegData(compressionQuality: 0.85) {
            try? fullData.write(to: fullURL(photoId: photoId), options: [.atomic])
        }

        // サムネ保存（軽量）
        let thumb = makeThumbnail(from: image, maxPixel: 240)
        if let thumbData = thumb.jpegData(compressionQuality: 0.7) {
            try? thumbData.write(to: thumbnailURL(photoId: photoId), options: [.atomic])
        }
    }

    static func delete(photoId: UUID) {
        let fm = FileManager.default
        _ = try? fm.removeItem(at: thumbnailURL(photoId: photoId))
        _ = try? fm.removeItem(at: fullURL(photoId: photoId))
    }

    // MARK: - Helpers

    private static func photosFolderURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static func makeThumbnail(from image: UIImage, maxPixel: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let scale = min(maxPixel / size.width, maxPixel / size.height, 1.0)
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// 保存前に準備した新規ファイルだけを所有する。既存ファイルの上書きや一括清掃はしない。
@MainActor final class PreparedPhotoFiles {
    enum Space { case entry, product }
    struct File { let url: URL; let id: UUID; let space: Space; let hash: String }
    private(set) var files: [File] = []
    let hooks: PhotoSaveTransaction.Hooks
    init(hooks: PhotoSaveTransaction.Hooks) { self.hooks = hooks }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func regularDirectory(_ url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
        guard try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeDirectory else {
            throw PhotoSaveTransaction.Failure.photo("保存フォルダ")
        }
    }
    func write(_ data: Data, to url: URL, id: UUID, space: Space, label: String) throws {
        do {
            try Self.regularDirectory(url.deletingLastPathComponent())
            try hooks.beforeWrite?(url)
            // 新UUIDの未公開ファイルだけを書く。途中失敗で既存ファイルを置き換えない。
            try data.write(to: url, options: .withoutOverwriting)
            let hash = Self.hash(data)
            files.append(File(url: url, id: id, space: space, hash: hash))
            let saved = try Data(contentsOf: url)
            guard Self.hash(saved) == hash, UIImage(data: saved) != nil,
                  try FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeRegular else {
                throw PhotoSaveTransaction.Failure.photo(label)
            }
        } catch { throw PhotoSaveTransaction.Failure.photo(label) }
    }
}

extension EntryPhotoStore {
    static func prepare(_ image: UIImage, files: PreparedPhotoFiles) throws -> UUID {
        let id = files.hooks.makeUUID()
        guard let full = image.jpegData(compressionQuality: 0.85),
              let thumb = makeThumbnail(from: image, maxPixel: 240).jpegData(compressionQuality: 0.7) else {
            throw PhotoSaveTransaction.Failure.photo("デザイン写真")
        }
        try files.write(full, to: fullURL(photoId: id), id: id, space: .entry, label: "デザイン写真のフル画像")
        try files.write(thumb, to: thumbnailURL(photoId: id), id: id, space: .entry, label: "デザイン写真のサムネイル")
        return id
    }
}

// 画面入力は値として受け取り、共有contextを変更する前に専用contextで確定する。
@MainActor enum PhotoSaveTransaction {
    enum Change { case keep, remove, replace(UIImage) }
    struct Version: Equatable { let hash: String }
    enum Target { case create(UUID), edit(NSManagedObjectID, Version) }
    struct EntryInput {
        let target: Target
        let title: String
        let date: Date
        let note: String
        let category: String?
        let color: String?
        let rating: Double
        let products: [UUID]
        let photo: Change
    }
    struct ProductInput {
        let target: Target
        let name: String
        let category: String
        let purchasedAt: Date
        let place: String
        let url: String?
        let price: Int32
        let main: Change
        let sample: Change
    }
    struct Result { let objectID: NSManagedObjectID; let cleanupWarning: String? }
    // 引数で依存性を注入する。起動引数や永続設定による診断分岐は作らない。
    struct Hooks {
        var makeUUID: () -> UUID = { UUID() }
        var beforeWrite: ((URL) throws -> Void)? = nil
        var beforeSave: ((NSManagedObjectContext) throws -> Void)? = nil
        var beforeCleanup: ((URL) throws -> Void)? = nil
    }
    nonisolated enum Failure: LocalizedError {
        case photo(String), database, conflict, configuration, pendingFiles(String)
        var errorDescription: String? {
            switch self {
            case .pendingFiles(let detail): return detail + " 未確定の新写真の整理も完了できなかったため、安全のため残しています。"
            case .photo(let part): return "\(part)を保存できませんでした。保存領域や空き容量を確認して再試行してください。元の写真と入力内容は保持しています。"
            case .database: return "データを保存できませんでした。元の写真と入力内容は保持しています。再試行するか、変更を破棄して戻れます。"
            case .conflict: return "編集中のデータが変更・削除されたか、未保存の変更があります。上書きせず入力を保持しました。一度戻って最新の内容を開き直してください。"
            case .configuration: return "安全な保存先を確認できませんでした。入力内容を保持しています。"
            }
        }
    }
    static func version(_ object: NSManagedObject) -> Version {
        func atom(_ value: Any?) -> String {
            guard let value, !(value is NSNull) else { return "null" }
            if let id = value as? UUID { return "uuid:" + id.uuidString }
            if let date = value as? Date { return "date:\(date.timeIntervalSinceReferenceDate.bitPattern)" }
            if let data = value as? Data { return "data:" + PreparedPhotoFiles.hash(data) }
            if let n = value as? NSNumber { return "\(String(cString: n.objCType)):\(n.stringValue)" }
            return "string:" + String(describing: value)
        }
        func attributes(_ value: NSManagedObject) -> [String: String] {
            Dictionary(uniqueKeysWithValues: value.entity.attributesByName.keys.map { ($0, atom(value.value(forKey: $0))) })
        }
        var values: [String: Any] = ["attributes": attributes(object)]
        for key in object.entity.relationshipsByName.keys {
            let value = object.value(forKey: key)
            let linked: [NSManagedObject]
            if let ordered = value as? NSOrderedSet { linked = ordered.array.compactMap { $0 as? NSManagedObject } }
            else if let set = value as? Set<NSManagedObject> { linked = set.sorted { $0.objectID.uriRepresentation().absoluteString < $1.objectID.uriRepresentation().absoluteString } }
            else { linked = (value as? NSManagedObject).map { [$0] } ?? [] }
            values[key] = linked.map { item -> [String: Any] in
                var row: [String: Any] = ["id": item.objectID.uriRepresentation().absoluteString, "attributes": attributes(item)]
                for (name, relation) in item.entity.relationshipsByName where !relation.isToMany {
                    row[name] = (item.value(forKey: name) as? NSManagedObject)?.objectID.uriRepresentation().absoluteString ?? "nil"
                }
                return row
            }
        }
        let data = (try? JSONSerialization.data(withJSONObject: values, options: .sortedKeys)) ?? Data()
        return Version(hash: PreparedPhotoFiles.hash(data))
    }
    private static func coordinator(_ view: NSManagedObjectContext) throws -> NSPersistentStoreCoordinator {
        guard let coordinator = view.persistentStoreCoordinator, !coordinator.persistentStores.isEmpty else { throw Failure.configuration }
        return coordinator
    }
    private static func validateShared(_ target: Target, view: NSManagedObjectContext) throws {
        guard case .edit(let id, _) = target else { return }
        guard !id.isTemporaryID, let object = try? view.existingObject(with: id), !object.isDeleted, !object.hasChanges else { throw Failure.conflict }
        for key in object.entity.relationshipsByName.keys {
            let value = object.value(forKey: key)
            let linked = (value as? NSOrderedSet)?.array.compactMap { $0 as? NSManagedObject }
                ?? (value as? Set<NSManagedObject>).map(Array.init)
                ?? (value as? NSManagedObject).map { [$0] } ?? []
            if linked.contains(where: { $0.hasChanges || $0.isDeleted }) { throw Failure.conflict }
        }
    }
    private static func object(_ target: Target, entity: String, in context: NSManagedObjectContext) throws -> NSManagedObject {
        switch target {
        case .create(let id):
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
            guard try context.count(for: request) == 0 else { throw Failure.conflict }
            let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
            object.setValue(id, forKey: "id"); object.setValue(Date(), forKey: "createdAt")
            return object
        case .edit(let id, let expected):
            guard let object = try? context.existingObject(with: id), !object.isDeleted,
                  object.entity.name == entity, version(object) == expected else { throw Failure.conflict }
            return object
        }
    }
    fileprivate struct Old { let space: PreparedPhotoFiles.Space; let id: UUID; let url: URL; let hash: String? }
    fileprivate static func oldFiles(_ space: PreparedPhotoFiles.Space, _ id: UUID?) -> [Old] {
        guard let id else { return [] }
        let urls = space == .entry ? [EntryPhotoStore.fullURL(photoId: id), EntryPhotoStore.thumbnailURL(photoId: id)] : [ProductPhotoStore.sourceURL(photoId: id)].compactMap { $0 }
        return urls.compactMap { url in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let regular = (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeRegular
            let hash = regular ? (try? Data(contentsOf: url)).map(PreparedPhotoFiles.hash) : nil
            return Old(space: space, id: id, url: url, hash: hash)
        }
    }

    private static func referenced(_ id: UUID, space: PreparedPhotoFiles.Space, coordinator: NSPersistentStoreCoordinator, view: NSManagedObjectContext) throws -> Bool {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let entity = space == .entry ? "NailEntry" : "NailProduct"
        let keys = space == .entry ? ["photoId"] : ["photoId", "samplePhotoId"]
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: keys.map { NSPredicate(format: "%K == %@", $0, id as NSUUID) })
        if try context.count(for: request) > 0 { return true }
        return view.registeredObjects.contains { object in
            object.entity.name == entity && !object.isDeleted && object.hasChanges && keys.contains { (object.value(forKey: $0) as? UUID) == id }
        }
    }
    fileprivate static func cleanup(_ files: [Old], coordinator: NSPersistentStoreCoordinator, view: NSManagedObjectContext, hooks: Hooks) -> Bool {
        var complete = true
        for file in files {
            do {
                guard !(try referenced(file.id, space: file.space, coordinator: coordinator, view: view)) else { continue }
                guard FileManager.default.fileExists(atPath: file.url.path) else { continue }
                try PreparedPhotoFiles.regularDirectory(file.url.deletingLastPathComponent())
                guard try FileManager.default.attributesOfItem(atPath: file.url.path)[.type] as? FileAttributeType == .typeRegular,
                      PreparedPhotoFiles.hash(try Data(contentsOf: file.url)) == file.hash else { complete = false; continue }
                try hooks.beforeCleanup?(file.url)
                try FileManager.default.removeItem(at: file.url)
            } catch { complete = false }
        }
        return complete
    }
    private static func perform(target: Target, entity: String, view: NSManagedObjectContext, hooks: Hooks,
                                change: (NSManagedObject, PreparedPhotoFiles) throws -> [Old]) throws -> Result {
        let coordinator = try coordinator(view)
        try validateShared(target, view: view)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
        let files = PreparedPhotoFiles(hooks: hooks)
        do {
            let targetObject = try object(target, entity: entity, in: context)
            let old = try change(targetObject, files)
            try hooks.beforeSave?(context)
            // 準備中に共有側へ未保存の変更が加わった場合も上書きしない。
            try validateShared(target, view: view)
            try context.obtainPermanentIDs(for: Array(context.insertedObjects))
            let inserted = Set(context.insertedObjects.map(\.objectID)), updated = Set(context.updatedObjects.map(\.objectID)), deleted = Set(context.deletedObjects.map(\.objectID))
            try context.save()
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSInsertedObjectsKey: inserted, NSUpdatedObjectsKey: updated, NSDeletedObjectsKey: deleted], into: [view])
            view.processPendingChanges()
            let clean = cleanup(old, coordinator: coordinator, view: view, hooks: hooks)
            return Result(objectID: targetObject.objectID, cleanupWarning: clean ? nil : "データの保存は完了しました。旧写真の整理を完了できなかったため、安全のため残しています。")
        } catch {
            // 破棄するのは保存専用contextと今回準備したファイルだけ。共有contextは巻き戻さない。
            context.reset()
            let own = files.files.map { Old(space: $0.space, id: $0.id, url: $0.url, hash: $0.hash) }
            let clean = cleanup(own, coordinator: coordinator, view: view, hooks: hooks)
            let ns = error as NSError
            let failure = (error as? Failure) ?? ((ns.code == NSManagedObjectMergeError || ns.code == NSPersistentStoreSaveConflictsError) ? .conflict : .database)
            if !clean { throw Failure.pendingFiles(failure.localizedDescription) }
            throw failure
        }
    }
    static func saveEntry(_ input: EntryInput, in view: NSManagedObjectContext, hooks: Hooks? = nil) throws -> Result {
        try perform(target: input.target, entity: "NailEntry", view: view, hooks: hooks ?? Hooks()) { object, files in
            guard let entry = object as? NailEntry, Set(input.products).count == input.products.count,
                  input.products.count <= Int(Int16.max) else { throw Failure.configuration }
            var old: [Old] = []
            switch input.photo {
            case .keep: break
            case .remove: old = oldFiles(.entry, entry.photoId); entry.photoId = nil
            case .replace(let image): old = oldFiles(.entry, entry.photoId); entry.photoId = try EntryPhotoStore.prepare(image, files: files)
            }
            entry.title = input.title; entry.date = input.date; entry.note = input.note
            entry.designCategory = input.category; entry.colorCategory = input.color; entry.rating = input.rating; entry.updatedAt = Date()
            let selected = try input.products.map { id -> NailProduct in
                let request = NailProduct.fetchRequest(); request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
                let matches = try object.managedObjectContext!.fetch(request)
                guard matches.count == 1 else { throw Failure.conflict }; return matches[0]
            }
            // 同じ関連順序なら作り直さず、既存リンクIDも保持する。
            let links = (entry.usedItems?.array as? [NailEntryUsedItem] ?? []).sorted { $0.orderIndex < $1.orderIndex }
            if links.map({ $0.product?.id }) != input.products.map(Optional.some) {
                for link in links { object.managedObjectContext!.delete(link) }
                for (index, product) in selected.enumerated() {
                    let link = NailEntryUsedItem(context: object.managedObjectContext!)
                    link.id = UUID(); link.orderIndex = Int16(index); link.entry = entry; link.product = product
                }
            }
            // 既存の写真変更時スコア無効化だけを保存トランザクション内で維持する。
            if case .keep = input.photo {} else if let score = entry.aiScore { object.managedObjectContext!.delete(score); entry.aiScore = nil }
            return old
        }
    }
    static func saveProduct(_ input: ProductInput, in view: NSManagedObjectContext, hooks: Hooks? = nil) throws -> Result {
        try perform(target: input.target, entity: "NailProduct", view: view, hooks: hooks ?? Hooks()) { object, files in
            guard let product = object as? NailProduct else { throw Failure.configuration }
            var old: [Old] = []
            switch input.main {
            case .keep: break
            case .remove: old += oldFiles(.product, product.photoId); product.photoId = nil
            case .replace(let image): old += oldFiles(.product, product.photoId); product.photoId = try ProductPhotoStore.prepare(image, files: files, label: "商品写真")
            }
            switch input.sample {
            case .keep: break
            case .remove: old += oldFiles(.product, product.samplePhotoId); product.samplePhotoId = nil
            case .replace(let image): old += oldFiles(.product, product.samplePhotoId); product.samplePhotoId = try ProductPhotoStore.prepare(image, files: files, label: "サンプル写真")
            }
            product.name = input.name; product.category = input.category; product.purchasedAt = input.purchasedAt
            product.purchasePlace = input.place; product.productUrl = input.url; product.priceYenTaxIn = input.price; product.updatedAt = Date()
            return old
        }
    }
}

// 確認時の値と関連を固定し、削除だけを独立contextで一括確定する。
@MainActor enum RecordDeletionTransaction {
    enum Kind { case items, entries
        var entity: String { self == .items ? "NailProduct" : "NailEntry" }
    }
    struct Record: Equatable {
        let id: NSManagedObjectID
        let version: PhotoSaveTransaction.Version
    }
    struct Plan {
        let kind: Kind
        let targets: [NSManagedObjectID]
        let records: [Record]
        let linkIDs: [NSManagedObjectID]
        let usedItemCount: Int
        let diaryCount: Int
        fileprivate let photos: [PhotoSaveTransaction.Old]
        var title: String {
            kind == .items ? (targets.count == 1 ? "アイテムを削除しますか？" : "選択した\(targets.count)件のアイテムを削除しますか？")
                           : "\(targets.count)件のデザインを削除しますか？"
        }
        var message: String {
            if kind == .entries { return "選択したデザインと使用アイテムの関連を削除します。アイテム本体と保存済みプレート作品は残ります。この操作は取り消せません。" }
            let usage = usedItemCount == 0 ? "デザインでは使用されていません。" : "\(targets.count)件中\(usedItemCount)件がデザインで使用されています。影響するデザインは合計\(diaryCount)件です。\n削除すると、該当デザインの使用アイテム一覧からも削除されます。"
            return usage + "\nデザインの記録・写真・保存済みプレート作品は残ります。この操作は取り消せません。"
        }
    }
    struct Hooks {
        var beforeSave: ((NSManagedObjectContext) throws -> Void)? = nil
        var beforeCleanup: ((URL) throws -> Void)? = nil
    }
    enum Failure: LocalizedError {
        case conflict, database, configuration
        var errorDescription: String? {
            switch self {
            case .conflict: return "削除対象または関連が変更・削除されたか、未保存の変更があります。削除していません。内容を確認し直してください。"
            case .database: return "削除を保存できませんでした。元のデータ・写真は保持しています。再試行するかキャンセルしてください。"
            case .configuration: return "安全な削除対象を確認できませんでした。データは削除していません。"
            }
        }
    }
    private static func coordinator(_ view: NSManagedObjectContext) throws -> NSPersistentStoreCoordinator {
        guard view.concurrencyType == .mainQueueConcurrencyType,
              let psc = view.persistentStoreCoordinator, !psc.persistentStores.isEmpty else { throw Failure.configuration }
        return psc
    }
    private static func context(_ psc: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        let c = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        c.persistentStoreCoordinator = psc
        c.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
        return c
    }
    private static func snapshot(_ kind: Kind, ids: [NSManagedObjectID], in c: NSManagedObjectContext) throws -> Plan {
        guard !ids.isEmpty, Set(ids).count == ids.count, ids.allSatisfy({ !$0.isTemporaryID }) else { throw Failure.configuration }
        let targets = try ids.map { id -> NSManagedObject in
            guard let o = try? c.existingObject(with: id), !o.isDeleted, o.entity.name == kind.entity else { throw Failure.conflict }
            return o
        }
        let request = NailEntryUsedItem.fetchRequest()
        request.predicate = NSPredicate(format: kind == .items ? "product IN %@" : "entry IN %@", targets)
        let links = try c.fetch(request)
        // 不完全な既存関連を無断で修復せず、削除を停止する。
        guard links.allSatisfy({ $0.entry != nil && $0.product != nil }) else { throw Failure.conflict }
        var watched = Dictionary(uniqueKeysWithValues: targets.map { ($0.objectID, $0) })
        for link in links {
            watched[link.objectID] = link
            if let e = link.entry { watched[e.objectID] = e }
            if let p = link.product { watched[p.objectID] = p }
        }
        if kind == .entries {
            for case let entry as NailEntry in targets {
                if let score = entry.aiScore { watched[score.objectID] = score }
            }
        }
        let records = watched.values.map { Record(id: $0.objectID, version: PhotoSaveTransaction.version($0)) }
            .sorted { $0.id.uriRepresentation().absoluteString < $1.id.uriRepresentation().absoluteString }
        let photos = targets.flatMap { object -> [PhotoSaveTransaction.Old] in
            if kind == .entries { return PhotoSaveTransaction.oldFiles(.entry, object.value(forKey: "photoId") as? UUID) }
            return ["photoId", "samplePhotoId"].flatMap { PhotoSaveTransaction.oldFiles(.product, object.value(forKey: $0) as? UUID) }
        }
        return Plan(kind: kind, targets: ids, records: records, linkIDs: links.map(\.objectID),
                    usedItemCount: Set(links.compactMap { $0.product?.objectID }).count,
                    diaryCount: Set(links.compactMap { $0.entry?.objectID }).count, photos: photos)
    }
    private static func validateShared(_ plan: Plan, view: NSManagedObjectContext) throws {
        let watched = Set(plan.records.map(\.id))
        let pending = view.insertedObjects.union(view.updatedObjects).union(view.deletedObjects)
        for object in pending {
            if watched.contains(object.objectID) { throw Failure.conflict }
            // 確認後に共有側へ挿入された中間レコードも検知する。
            if object.entity.name == "NailEntryUsedItem" {
                for key in ["entry", "product"] {
                    let current = object.value(forKey: key) as? NSManagedObject
                    let old = object.committedValues(forKeys: [key])[key] as? NSManagedObject
                    if [current, old].compactMap({ $0?.objectID }).contains(where: watched.contains) { throw Failure.conflict }
                }
            }
        }
    }
    static func prepare(_ kind: Kind, ids: [NSManagedObjectID], in view: NSManagedObjectContext) throws -> Plan {
        let c = context(try coordinator(view))
        let plan = try snapshot(kind, ids: ids, in: c)
        try validateShared(plan, view: view)
        return plan
    }
    private static func retireCommittedChanges(deleted: [NSManagedObjectID], updated: [NSManagedObjectID], in view: NSManagedObjectContext) {
        for id in deleted {
            if let local = view.registeredObject(for: id), local.isDeleted { view.refresh(local, mergeChanges: false) }
        }
        guard let psc = view.persistentStoreCoordinator else { return }
        let persisted = context(psc)
        for id in updated {
            guard let local = view.registeredObject(for: id), !local.isDeleted,
                  let stored = try? persisted.existingObject(with: id) else { continue }
            // 後から入ったユーザー入力や関連変更があれば、その値を捨てない。
            if PhotoSaveTransaction.version(local) == PhotoSaveTransaction.version(stored) { view.refresh(local, mergeChanges: false) }
        }
        view.processPendingChanges()
    }
    static func delete(_ plan: Plan, in view: NSManagedObjectContext, hooks suppliedHooks: Hooks? = nil) throws -> String? {
        let hooks = suppliedHooks ?? Hooks()
        let psc = try coordinator(view), work = context(psc)
        do {
            try validateShared(plan, view: view)
            let initial = try snapshot(plan.kind, ids: plan.targets, in: work)
            guard initial.records == plan.records else { throw Failure.conflict }
            for id in plan.linkIDs { work.delete(try work.existingObject(with: id)) }
            for id in plan.targets { work.delete(try work.existingObject(with: id)) }
            work.processPendingChanges()
            try hooks.beforeSave?(work)
            try validateShared(plan, view: view)
            // 独立した再読込で、確認後・保存直前の関連追加や外部更新も検知する。
            let latest = try snapshot(plan.kind, ids: plan.targets, in: context(psc))
            guard latest.records == plan.records else { throw Failure.conflict }
            // 保存成功の通知を同じキューで取り込み、削除待ち状態を共有側へ残さない。
            let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: work, queue: nil) { notification in
                let deleted = (notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []).map(\.objectID)
                let updated = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []).map(\.objectID)
                view.performAndWait {
                    view.mergeChanges(fromContextDidSave: notification)
                    MainActor.assumeIsolated { retireCommittedChanges(deleted: deleted, updated: updated, in: view) }
                }
                // 自動mergeが同じ通知をキューへ積んだ場合も、その直後に確定済み状態だけ整理する。
                view.perform { MainActor.assumeIsolated { retireCommittedChanges(deleted: deleted, updated: updated, in: view) } }
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            try work.save()
            view.processPendingChanges()
            var photoHooks = PhotoSaveTransaction.Hooks()
            photoHooks.beforeCleanup = hooks.beforeCleanup
            let clean = PhotoSaveTransaction.cleanup(plan.photos, coordinator: psc, view: view, hooks: photoHooks)
            return clean ? nil : "削除は完了しましたが、不要な写真の整理は完了しませんでした。安全のため写真を残しています。"
        } catch {
            // 共有contextと写真は触らず、この試行の未確定状態だけを破棄する。
            work.reset()
            if let failure = error as? Failure { throw failure }
            let e = error as NSError
            if e.code == NSManagedObjectMergeError || e.code == NSPersistentStoreSaveConflictsError { throw Failure.conflict }
            throw Failure.database
        }
    }
}
