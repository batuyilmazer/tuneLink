import UIKit

enum AlbumArtCache {
    private static let containerURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName)

    static func localURL(for remoteURL: URL) -> URL? {
        containerURL?.appendingPathComponent("art_\(remoteURL.absoluteString.hashValue).jpg")
    }

    static func image(for remoteURL: URL?) -> UIImage? {
        guard let remoteURL, let local = localURL(for: remoteURL) else { return nil }
        guard let data = try? Data(contentsOf: local) else { return nil }
        return UIImage(data: data)
    }

    static func prefetch(_ remoteURL: URL) async {
        guard let local = localURL(for: remoteURL) else { return }
        guard !FileManager.default.fileExists(atPath: local.path) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: remoteURL) else { return }
        try? data.write(to: local)
    }

    // Eski art dosyalarını temizle — önbellek büyümesini engeller
    static func evictStale(keeping activeURLs: [URL]) {
        guard let container = containerURL else { return }
        let activeNames = Set(activeURLs.compactMap { localURL(for: $0)?.lastPathComponent })
        let files = (try? FileManager.default.contentsOfDirectory(atPath: container.path)) ?? []
        for file in files where file.hasPrefix("art_") && !activeNames.contains(file) {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(file))
        }
    }
}
