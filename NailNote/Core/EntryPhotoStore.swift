import Foundation
import UIKit

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
