import Foundation

actor ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default

    private var imagesDirectory: URL {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesDir = documentsDir.appendingPathComponent("PSAImages", isDirectory: true)
        if !fileManager.fileExists(atPath: imagesDir.path) {
            try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
        return imagesDir
    }

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static func resolvePath(_ relativePath: String) -> String {
        if relativePath.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: relativePath) {
                return relativePath
            }
            let filename = (relativePath as NSString).lastPathComponent
            let newPath = documentsDirectory.appendingPathComponent("PSAImages/\(filename)").path
            if FileManager.default.fileExists(atPath: newPath) {
                return newPath
            }
            return relativePath
        }
        let fullPath = documentsDirectory.appendingPathComponent(relativePath).path
        return fullPath
    }

    func downloadAndSave(url urlString: String, certNumber: String, suffix: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ImageStorageError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ImageStorageError.downloadFailed
        }

        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let fileName = "PSA_\(certNumber)_\(suffix).\(ext)"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL)
        return "PSAImages/\(fileName)"
    }

    func deleteImage(path: String) {
        let resolvedPath = ImageStorageService.resolvePath(path)
        if fileManager.fileExists(atPath: resolvedPath) {
            try? fileManager.removeItem(atPath: resolvedPath)
        }
    }

    func imageExists(path: String) -> Bool {
        let resolvedPath = ImageStorageService.resolvePath(path)
        return fileManager.fileExists(atPath: resolvedPath)
    }
}

enum ImageStorageError: LocalizedError, Sendable {
    case invalidURL
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .downloadFailed:
            return "Failed to download image"
        }
    }
}
