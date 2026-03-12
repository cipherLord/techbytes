import SwiftUI
import ImageIO

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let session: URLSession

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        memoryCache.countLimit = 15
        memoryCache.totalCostLimit = 10 * 1024 * 1024

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func image(for url: URL, maxPixelSize: CGFloat = 400) async -> UIImage? {
        let key = cacheKey(for: url)

        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        if let diskImage = loadFromDisk(key: key, maxPixelSize: maxPixelSize) {
            let cost = imageCost(diskImage)
            memoryCache.setObject(diskImage, forKey: key as NSString, cost: cost)
            return diskImage
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            saveToDisk(data: data, key: key)
            guard let image = downsample(data: data, maxPixelSize: maxPixelSize) else { return nil }
            memoryCache.setObject(image, forKey: key as NSString, cost: imageCost(image))
            return image
        } catch {
            return nil
        }
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func trimMemory() {
        memoryCache.removeAllObjects()
    }

    private nonisolated func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated func imageCost(_ image: UIImage) -> Int {
        let bytesPerPixel = 4
        return Int(image.size.width * image.scale * image.size.height * image.scale) * bytesPerPixel
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString.data(using: .utf8)!
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private nonisolated func loadFromDisk(key: String, maxPixelSize: CGFloat) -> UIImage? {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated func saveToDisk(data: Data, key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode
    let height: CGFloat?
    let maxPixelSize: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadFailed = false

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        height: CGFloat? = nil,
        maxPixelSize: CGFloat = 400,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { StaticImagePlaceholder() }
    ) {
        self.url = url
        self.contentMode = contentMode
        self.height = height
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    } else if loadFailed {
                        failurePlaceholder
                    } else {
                        placeholder()
                    }
                }
            }
            .clipped()
            .task(id: url) {
                await loadImage()
            }
            .onDisappear {
                image = nil
            }
    }

    private func loadImage() async {
        guard let url else {
            loadFailed = true
            return
        }
        if let cached = await ImageCache.shared.image(for: url, maxPixelSize: maxPixelSize) {
            withAnimation(.easeIn(duration: 0.2)) {
                image = cached
            }
        } else {
            loadFailed = true
        }
    }

    private var failurePlaceholder: some View {
        Color.slateGrey
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.dustyGrey)
            )
    }
}

struct StaticImagePlaceholder: View {
    var body: some View {
        Color.slateGrey
            .overlay(
                ProgressView()
                    .tint(.dustyGrey)
            )
    }
}
