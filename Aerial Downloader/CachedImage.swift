import SwiftUI
import AppKit

struct CachedImage: View {

    let url: String

    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {

        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {

        image = nil
        isLoading = true

        guard let imageURL = URL(string: url) else {
            isLoading = false
            return
        }

        // Find the macOS cache directory
        guard let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            isLoading = false
            return
        }

        let folder = cacheDirectory.appendingPathComponent(
            "AerialDownloader/Previews",
            isDirectory: true
        )

        // Create cache folder if necessary
        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
        } catch {
            print("Cache directory error:", error)
            isLoading = false
            return
        }

        // Use a stable filename derived from the URL
        let filename = imageURL.lastPathComponent

        let cachedFile = folder.appendingPathComponent(filename)

        // Check whether the image already exists locally
        if let cachedImage = NSImage(contentsOf: cachedFile) {
            image = cachedImage
            isLoading = false
            return
        }

        // Otherwise download the image
        do {
            let (data, _) = try await URLSession.shared.data(
                from: imageURL
            )

            guard let downloadedImage = NSImage(data: data) else {
                isLoading = false
                return
            }

            // Save the image to disk
            try data.write(to: cachedFile, options: .atomic)

            image = downloadedImage

        } catch {
            print("Image download error:", error)
        }

        isLoading = false
    }
}
