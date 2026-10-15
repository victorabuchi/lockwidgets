import AppKit
import ImageIO
import Photos

/// Picks a photo to show, from the Photos library or a folder, and swaps it on a timer.
final class PhotosStore: ObservableObject {
    static let shared = PhotosStore()
    static let sourceKey = "photosSource"
    static let intervalKey = "photosInterval"
    private static let folderKey = "photosFolderBookmark"

    enum Source: String, CaseIterable, Identifiable {
        case favorites, recents, folder

        var id: String { rawValue }

        var title: String {
            switch self {
            case .favorites: "Favourites"
            case .recents: "Recent photos"
            case .folder: "A folder"
            }
        }
    }

    @Published private(set) var image: NSImage?
    @Published private(set) var date: Date?
    @Published private(set) var problem: String?
    @Published private(set) var folderName: String?
    @Published private(set) var libraryAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized

    private var timer: Timer?

    private var source: Source {
        Source(rawValue: UserDefaults.standard.string(forKey: Self.sourceKey) ?? "") ?? .favorites
    }

    private init() {
        folderName = resolveFolder()?.lastPathComponent
        next()
        restartTimer()
    }

    func restartTimer() {
        let minutes = UserDefaults.standard.object(forKey: Self.intervalKey) as? Int ?? 15
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            self?.next()
        }
    }

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.libraryAccess = status == .authorized
                self?.next()
            }
        }
    }

    func next() {
        switch source {
        case .folder: nextFromFolder()
        case .favorites, .recents: nextFromLibrary()
        }
    }

    // MARK: Library

    private func nextFromLibrary() {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            publish(problem: "Allow Photos access in LockWidgets settings.")
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 300
        if source == .favorites {
            options.predicate = NSPredicate(format: "favorite == YES")
        }
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        guard assets.count > 0 else {
            publish(problem: source == .favorites ? "No favourite photos yet." : "No photos found.")
            return
        }
        let asset = assets.object(at: Int.random(in: 0 ..< assets.count))
        let request = PHImageRequestOptions()
        request.deliveryMode = .highQualityFormat
        request.isNetworkAccessAllowed = true
        request.resizeMode = .fast
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 900, height: 900), contentMode: .aspectFill, options: request) { [weak self] image, _ in
            guard let image else { return }
            DispatchQueue.main.async {
                self?.image = image
                self?.date = asset.creationDate
                self?.problem = nil
            }
        }
    }

    // MARK: Folder

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Folder"
        panel.message = "Choose a folder of photos to show on the lock screen."
        guard panel.runModal() == .OK, let url = panel.url,
              let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        UserDefaults.standard.set(bookmark, forKey: Self.folderKey)
        folderName = url.lastPathComponent
        next()
    }

    private func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.folderKey) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private func nextFromFolder() {
        guard let folder = resolveFolder() else {
            publish(problem: "Choose a folder in LockWidgets settings.")
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            let extensions: Set = ["jpg", "jpeg", "png", "heic", "tiff", "webp"]
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]))?
                .filter { extensions.contains($0.pathExtension.lowercased()) } ?? []
            guard let file = files.randomElement(),
                  let source = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: 900,
                  ] as CFDictionary)
            else {
                self?.publish(problem: "No photos found in that folder.")
                return
            }
            let created = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate
            let image = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
            DispatchQueue.main.async {
                self?.image = image
                self?.date = created
                self?.problem = nil
            }
        }
    }

    private func publish(problem: String) {
        DispatchQueue.main.async { self.problem = problem }
    }
}
