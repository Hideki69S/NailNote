import Foundation
import UIKit

/// 用品写真 / サンプルカラー写真 の保存先ストア
/// - NailProduct.photoId / NailProduct.samplePhotoId を想定
final class ProductPhotoStore {

    // MARK: - Singleton

    static let shared = ProductPhotoStore()
    private init() {}

    // MARK: - Config

    /// 画像を保存するフォルダ名（Documents配下）
    private let folderName = "ProductPhotos"

    /// 保存形式
    private let fileExtension = "jpg"

    /// JPEG圧縮率（0.0〜1.0）
    private let jpegQuality: CGFloat = 0.85

    // MARK: - New API（今後はこっち推奨）

    /// 画像を保存して UUID を返す（新規保存）
    @discardableResult
    func saveImage(_ image: UIImage) -> UUID? {
        let id = UUID()
        return saveImage(image, for: id) ? id : nil
    }

    /// 指定UUIDに上書き保存
    @discardableResult
    func saveImage(_ image: UIImage, for id: UUID) -> Bool {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else { return false }

        do {
            let url = try fileURL(for: id)
            try ensureFolderExists()
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            print("ProductPhotoStore save error: \(error)")
            return false
        }
    }

    /// 読み込み（存在しなければ nil）
    func loadImage(photoId id: UUID) -> UIImage? {
        do {
            let url = try fileURL(for: id)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    /// 削除（存在しない場合も true 扱い）
    @discardableResult
    func deleteImage(photoId id: UUID) -> Bool {
        do {
            let url = try fileURL(for: id)
            guard FileManager.default.fileExists(atPath: url.path) else { return true }
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("ProductPhotoStore delete error: \(error)")
            return false
        }
    }

    /// 画像が存在するか
    func exists(photoId id: UUID) -> Bool {
        do {
            let url = try fileURL(for: id)
            return FileManager.default.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }

    // MARK: - Compatibility API（既存コードを壊さないための互換ラッパー）
    // AddOrEditProductView が static で呼んでいるものに合わせる

    /// 旧: ProductPhotoStore.save(...)
    /// - kind は "main"/"sample" 等を想定（保存場所は同じなので無視してOK）
    static func save(_ image: UIImage, kind: String) -> UUID? {
        shared.saveImage(image)
    }

    /// 旧: ProductPhotoStore.save(image:..., kind:...)
    static func save(image: UIImage, kind: String) -> UUID? {
        shared.saveImage(image)
    }

    /// ✅ 旧: ProductPhotoStore.save(image:..., photoId:..., kind:...)
    /// - 既存UUIDに保存したい（上書き）ケース用
    @discardableResult
    static func save(image: UIImage, photoId: UUID, kind: String) -> Bool {
        shared.saveImage(image, for: photoId)
    }

    /// 旧: ProductPhotoStore.delete(photoId:..., kind:...)
    @discardableResult
    static func delete(photoId: UUID, kind: String) -> Bool {
        shared.deleteImage(photoId: photoId)
    }

    /// 旧: ProductPhotoStore.delete(photoId:...)
    @discardableResult
    static func delete(photoId: UUID) -> Bool {
        shared.deleteImage(photoId: photoId)
    }

    /// 旧: ProductPhotoStore.loadThumbnail(photoId:..., kind:...)
    /// - 一覧/プレビュー用途に小さめにして返す
    static func loadThumbnail(photoId: UUID, kind: String, maxPixel: CGFloat = 300) -> UIImage? {
        guard let img = shared.loadImage(photoId: photoId) else { return nil }
        return img.resized(maxPixel: maxPixel)
    }

    /// 旧: ProductPhotoStore.loadThumbnail(photoId:...)
    static func loadThumbnail(photoId: UUID, maxPixel: CGFloat = 300) -> UIImage? {
        guard let img = shared.loadImage(photoId: photoId) else { return nil }
        return img.resized(maxPixel: maxPixel)
    }

    // MARK: - Private

    private func ensureFolderExists() throws {
        let dir = try directoryURL()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func directoryURL() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(folderName, isDirectory: true)
    }

    private func fileURL(for id: UUID) throws -> URL {
        let dir = try directoryURL()
        let filename = "\(id.uuidString).\(fileExtension)"
        return dir.appendingPathComponent(filename, isDirectory: false)
    }
}

// MARK: - UIImage helper（軽量サムネ生成）

private extension UIImage {
    func resized(maxPixel: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxPixel else { return self }

        let scale = maxPixel / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
