import Foundation
import UIKit
import SwiftUI
import ImageIO

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

    /// 元画像を全展開せずに読むための参照先。作成・更新は行わない。
    static func sourceURL(photoId: UUID) -> URL? {
        try? shared.fileURL(for: photoId)
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

extension ProductPhotoStore {
    static func prepare(_ image: UIImage, files: PreparedPhotoFiles, label: String) throws -> UUID {
        let id = files.hooks.makeUUID()
        guard let data = image.jpegData(compressionQuality: shared.jpegQuality) else {
            throw PhotoSaveTransaction.Failure.photo(label)
        }
        try files.write(data, to: shared.fileURL(for: id), id: id, space: .product, label: label)
        return id
    }
}

// MARK: - 共通の写真閲覧（保存・削除処理から独立）

struct NailPhotoPage: Identifiable {
    enum Source { case file(URL), memory(UIImage), unavailable }
    let id = UUID()
    let title: String
    let source: Source

    static func design(id: UUID?, image: UIImage? = nil, removed: Bool = false) -> NailPhotoPage? {
        guard !removed else { return nil }
        if let image { return .init(title: "デザイン写真", source: .memory(image)) }
        return id.map { .init(title: "デザイン写真", source: .file(EntryPhotoStore.readOnlyFullURL(photoId: $0))) }
    }

    static func product(id: UUID?, image: UIImage? = nil, sample: Bool, removed: Bool = false) -> NailPhotoPage? {
        guard !removed else { return nil }
        let title = sample ? "サンプル写真" : "商品写真"
        if let image { return .init(title: title, source: .memory(image)) }
        return id.map { .init(title: title, source: ProductPhotoStore.sourceURL(photoId: $0).map(Source.file) ?? .unavailable) }
    }
}

struct NailPhotoPresentation: Identifiable {
    let id = UUID()
    let pages: [NailPhotoPage]
    let initialIndex: Int
    init(pages: [NailPhotoPage], initialIndex: Int = 0) {
        self.pages = pages
        self.initialIndex = min(max(0, initialIndex), max(0, pages.count - 1))
    }
}

extension View {
    func nailPhotoViewer(_ presentation: Binding<NailPhotoPresentation?>) -> some View {
        fullScreenCover(item: presentation) { NailPhotoViewer(presentation: $0) }
    }
}

/// 作成済みの不変CGImageだけをバックグラウンド処理へ渡す。
struct NailPhotoBitmap: @unchecked Sendable {
    let image: CGImage
    let orientation: Int
}

enum NailPhotoReader {
    enum Failure: Error { case unavailable }

    nonisolated static func decode(url: URL, maxPixel: Int) throws -> NailPhotoBitmap {
        try Task.checkCancellation()
        guard url.isFileURL,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(4096, max(1, maxPixel)),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw Failure.unavailable }
        try Task.checkCancellation()
        return NailPhotoBitmap(image: image, orientation: UIImage.Orientation.up.rawValue)
    }

    nonisolated static func resize(_ source: NailPhotoBitmap, maxPixel: Int) throws -> NailPhotoBitmap {
        try Task.checkCancellation()
        let image = source.image
        let ratio = min(1, CGFloat(min(4096, max(1, maxPixel))) / CGFloat(max(image.width, image.height)))
        guard ratio < 1 else { return source }
        let width = max(1, Int(CGFloat(image.width) * ratio)), height = max(1, Int(CGFloat(image.height) * ratio))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw Failure.unavailable }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else { throw Failure.unavailable }
        try Task.checkCancellation()
        return NailPhotoBitmap(image: result, orientation: source.orientation)
    }
}

struct NailPhotoViewer: View {
    let presentation: NailPhotoPresentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var page: Int
    @State private var zoom: CGFloat = 1
    @State private var reset = 0
    @State private var image: UIImage?
    @State private var loadedPage: UUID?
    @State private var failed = false

    init(presentation: NailPhotoPresentation) {
        self.presentation = presentation
        _page = State(initialValue: presentation.initialIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            let pixels = min(4096, Int(max(geometry.size.width, geometry.size.height) * displayScale * (zoom > 1.3 ? 2 : 1)))
            VStack(spacing: 0) {
                HStack {
                    Text(presentation.pages.indices.contains(page) ? presentation.pages[page].title : "写真")
                        .font(.headline).accessibilityIdentifier("photoViewer.kind")
                    Spacer(minLength: 8)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold))
                            .frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
                    }.accessibilityLabel("写真を閉じる").accessibilityIdentifier("photoViewer.close")
                }.padding(.horizontal, 18).padding(.bottom, 8)

                NailPhotoPager(pages: presentation.pages, initialIndex: presentation.initialIndex,
                               loadedPage: loadedPage, image: image, failed: failed, reset: reset) { index, scale in
                    if page != index { page = index; image = nil; loadedPage = nil; failed = false }
                    zoom = scale
                }
                HStack {
                    Text("\(presentation.pages.isEmpty ? 0 : page + 1) / \(presentation.pages.count)")
                        .font(.subheadline.monospacedDigit()).accessibilityIdentifier("photoViewer.page")
                        .accessibilityLabel("写真、\(page + 1)枚目、全\(presentation.pages.count)枚")
                    Spacer()
                    Button("全体表示") { reset += 1 }.frame(minHeight: 44)
                        .disabled(zoom <= 1.01).accessibilityLabel("写真を全体表示に戻す")
                        .accessibilityIdentifier("photoViewer.reset")
                }.padding(.horizontal, 20).padding(.vertical, 4)
            }
            .task(id: "\(page):\(pixels)") { await load(pixels: pixels) }
        }
        .background(Color(white: 0.035).ignoresSafeArea())
        .foregroundStyle(.white).tint(.white).environment(\.colorScheme, .dark)
        .onDisappear { image = nil; loadedPage = nil }
    }

    private func load(pixels: Int) async {
        guard presentation.pages.indices.contains(page) else { return }
        let current = presentation.pages[page]
        do {
            let worker: Task<NailPhotoBitmap, Error>
            switch current.source {
            case .file(let url):
                worker = Task.detached(priority: .userInitiated) { try NailPhotoReader.decode(url: url, maxPixel: pixels) }
            case .memory(let image):
                guard let cgImage = image.cgImage else { throw NailPhotoReader.Failure.unavailable }
                let snapshot = NailPhotoBitmap(image: cgImage, orientation: image.imageOrientation.rawValue)
                worker = Task.detached(priority: .userInitiated) { try NailPhotoReader.resize(snapshot, maxPixel: pixels) }
            case .unavailable: throw NailPhotoReader.Failure.unavailable
            }
            let bitmap = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            try Task.checkCancellation()
            guard presentation.pages[page].id == current.id else { return }
            image = UIImage(cgImage: bitmap.image, scale: 1, orientation: UIImage.Orientation(rawValue: bitmap.orientation) ?? .up)
            loadedPage = current.id
            failed = false
        } catch is CancellationError { return }
        catch {
            guard !Task.isCancelled, presentation.pages[page].id == current.id else { return }
            image = nil; loadedPage = current.id; failed = true
        }
    }
}

private struct NailPhotoPager: UIViewControllerRepresentable {
    let pages: [NailPhotoPage]
    let initialIndex: Int
    let loadedPage: UUID?
    let image: UIImage?
    let failed: Bool
    let reset: Int
    let changed: (Int, CGFloat) -> Void
    func makeUIViewController(context: Context) -> NailPhotoPagerController {
        NailPhotoPagerController(pages: pages, initialIndex: initialIndex, changed: changed)
    }
    func updateUIViewController(_ controller: NailPhotoPagerController, context: Context) {
        controller.display(page: loadedPage, image: image, failed: failed)
        if controller.resetToken != reset { controller.resetToken = reset; controller.resetZoom() }
    }
}

private final class NailPhotoPagerController: UIViewController, UIScrollViewDelegate {
    let pages: [NailPhotoPage]
    let initialIndex: Int
    let changed: (Int, CGFloat) -> Void
    let pager = UIScrollView()
    var scrolls: [UIScrollView] = []
    var photos: [UIImageView] = []
    var messages: [UILabel] = []
    var spinners: [UIActivityIndicatorView] = []
    var resetToken = 0
    private var lastSize: CGSize = .zero
    private var layingOut = false
    private var previousIndex: Int

    init(pages: [NailPhotoPage], initialIndex: Int, changed: @escaping (Int, CGFloat) -> Void) {
        self.pages = pages; self.initialIndex = initialIndex; previousIndex = initialIndex; self.changed = changed
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("コードから生成します") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(pager); pager.isPagingEnabled = true; pager.delegate = self
        pager.bounces = false; pager.showsHorizontalScrollIndicator = false
        pager.accessibilityIdentifier = "photoViewer.pages"
        for (index, page) in pages.enumerated() {
            let scroll = UIScrollView()
            scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 4; scroll.bouncesZoom = false
            scroll.showsHorizontalScrollIndicator = false; scroll.showsVerticalScrollIndicator = false
            scroll.delegate = self; scroll.tag = index; scroll.panGestureRecognizer.isEnabled = false
            scroll.accessibilityIdentifier = "photoViewer.zoom.\(index)"
            let photo = UIImageView(); photo.contentMode = .scaleAspectFit
            photo.isAccessibilityElement = true; photo.accessibilityLabel = page.title
            photo.accessibilityHint = "ピンチで拡大。拡大中はドラッグで移動できます。"
            photo.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "拡大", target: self, selector: #selector(enlarge)),
                UIAccessibilityCustomAction(name: "縮小", target: self, selector: #selector(reduce)),
                UIAccessibilityCustomAction(name: "次の写真", target: self, selector: #selector(nextPage)),
                UIAccessibilityCustomAction(name: "前の写真", target: self, selector: #selector(previousPage))
            ]
            let label = UILabel(); label.textColor = .white; label.numberOfLines = 0; label.textAlignment = .center
            label.font = .preferredFont(forTextStyle: .body); label.adjustsFontForContentSizeCategory = true
            label.accessibilityIdentifier = "photoViewer.error.\(index)"
            let spinner = UIActivityIndicatorView(style: .large); spinner.color = .white
            spinner.accessibilityLabel = "写真を読み込み中"; spinner.isAccessibilityElement = true
            scroll.addSubview(photo); pager.addSubview(scroll); pager.addSubview(label); pager.addSubview(spinner)
            scrolls.append(scroll); photos.append(photo); messages.append(label); spinners.append(spinner)
            spinner.startAnimating()
        }
        pager.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "次の写真", target: self, selector: #selector(nextPage)),
            UIAccessibilityCustomAction(name: "前の写真", target: self, selector: #selector(previousPage))
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.size != lastSize else { return }
        let first = lastSize == .zero, current = first ? initialIndex : index
        let scales = scrolls.map(\.zoomScale)
        let centers = scrolls.map { s in CGPoint(x: (s.contentOffset.x + s.bounds.width / 2) / max(1, s.contentSize.width),
                                                y: (s.contentOffset.y + s.bounds.height / 2) / max(1, s.contentSize.height)) }
        layingOut = true; lastSize = view.bounds.size; pager.frame = view.bounds
        pager.contentSize = CGSize(width: view.bounds.width * CGFloat(pages.count), height: view.bounds.height)
        for (i, scroll) in scrolls.enumerated() {
            scroll.setZoomScale(1, animated: false)
            scroll.frame = CGRect(x: CGFloat(i) * view.bounds.width, y: 0, width: view.bounds.width, height: view.bounds.height)
            fitImage(i, scale: scales[i], center: centers[i])
            scroll.panGestureRecognizer.isEnabled = scales[i] > 1.01
            messages[i].frame = scroll.frame.insetBy(dx: 24, dy: 16)
            spinners[i].center = CGPoint(x: scroll.frame.midX, y: scroll.frame.midY)
        }
        pager.contentOffset = CGPoint(x: CGFloat(current) * view.bounds.width, y: 0)
        pager.isScrollEnabled = (scales.indices.contains(current) ? scales[current] : 1) <= 1.01
        layingOut = false; publish()
    }

    func display(page: UUID?, image: UIImage?, failed: Bool) {
        loadViewIfNeeded()
        for (i, descriptor) in pages.enumerated() {
            let active = descriptor.id == page
            if photos[i].image !== (active ? image : nil) {
                let scroll = scrolls[i]
                let center = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / max(1, scroll.contentSize.width),
                                     y: (scroll.contentOffset.y + scroll.bounds.height / 2) / max(1, scroll.contentSize.height))
                photos[i].image = active ? image : nil
                layingOut = true
                fitImage(i, scale: scroll.zoomScale, center: center)
                layingOut = false
            }
            scrolls[i].pinchGestureRecognizer?.isEnabled = active && image != nil
            photos[i].isAccessibilityElement = active && image != nil
            messages[i].text = active && failed ? "写真を読み込めませんでした。\n元の写真が見つからないか、読み込めない状態です。" : nil
            if active && (image != nil || failed) { spinners[i].stopAnimating() } else { spinners[i].startAnimating() }
        }
    }

    var index: Int {
        guard pager.bounds.width > 0 else { return initialIndex }
        return max(0, min(pages.count - 1, Int((pager.contentOffset.x / pager.bounds.width).rounded())))
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { scrollView === pager ? nil : photos[scrollView.tag] }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard scrollView !== pager, !layingOut else { return }
        centerImage(scrollView)
        scrollView.panGestureRecognizer.isEnabled = scrollView.zoomScale > 1.01
        pager.isScrollEnabled = scrollView.zoomScale <= 1.01
        publish()
    }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) { publish() }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { finishPaging() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { finishPaging() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView === pager, !decelerate { finishPaging() }
    }
    private func finishPaging() {
        guard index != previousIndex else { return }
        layingOut = true
        for (i, scroll) in scrolls.enumerated() {
            fitImage(i, scale: 1, center: CGPoint(x: 0.5, y: 0.5))
            scroll.panGestureRecognizer.isEnabled = false
        }
        previousIndex = index; pager.isScrollEnabled = true; layingOut = false; publish()
    }
    func resetZoom() {
        guard scrolls.indices.contains(index) else { return }
        layingOut = true
        fitImage(index, scale: 1, center: CGPoint(x: 0.5, y: 0.5))
        layingOut = false
        scrolls[index].panGestureRecognizer.isEnabled = false; pager.isScrollEnabled = true; publish()
    }
    @objc private func nextPage() -> Bool { movePage(1) }
    @objc private func previousPage() -> Bool { movePage(-1) }
    @objc private func enlarge() -> Bool { changeZoom(1) }
    @objc private func reduce() -> Bool { changeZoom(-1) }
    private func changeZoom(_ step: CGFloat) -> Bool {
        guard scrolls.indices.contains(index), photos[index].image != nil else { return false }
        scrolls[index].setZoomScale(min(4, max(1, scrolls[index].zoomScale + step)), animated: true)
        return true
    }
    private func movePage(_ step: Int) -> Bool {
        let next = index + step
        guard pages.indices.contains(next), scrolls[index].zoomScale <= 1.01 else { return false }
        pager.setContentOffset(CGPoint(x: CGFloat(next) * pager.bounds.width, y: 0), animated: true)
        return true
    }
    private func fitImage(_ i: Int, scale: CGFloat, center: CGPoint) {
        let scroll = scrolls[i]
        guard scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        scroll.setZoomScale(1, animated: false)
        let original = photos[i].image?.size ?? scroll.bounds.size
        let ratio = min(scroll.bounds.width / max(1, original.width), scroll.bounds.height / max(1, original.height))
        let size = CGSize(width: original.width * ratio, height: original.height * ratio)
        photos[i].frame = CGRect(origin: .zero, size: size); scroll.contentSize = size
        scroll.setZoomScale(scale, animated: false)
        centerImage(scroll)
        let inset = scroll.contentInset
        let x = center.x * scroll.contentSize.width - scroll.bounds.width / 2
        let y = center.y * scroll.contentSize.height - scroll.bounds.height / 2
        scroll.contentOffset = CGPoint(x: max(-inset.left, min(x, max(-inset.left, scroll.contentSize.width - scroll.bounds.width + inset.right))),
                                       y: max(-inset.top, min(y, max(-inset.top, scroll.contentSize.height - scroll.bounds.height + inset.bottom))))
    }
    private func centerImage(_ scroll: UIScrollView) {
        let horizontal = max(0, (scroll.bounds.width - scroll.contentSize.width) / 2)
        let vertical = max(0, (scroll.bounds.height - scroll.contentSize.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
    private func publish() {
        guard !layingOut, scrolls.indices.contains(index) else { return }
        let page = index, scale = scrolls[page].zoomScale
        photos[page].accessibilityValue = String(format: "拡大率 %.1f倍", scale)
        DispatchQueue.main.async { [weak self] in self?.changed(page, scale) }
    }
}
