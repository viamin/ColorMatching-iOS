import Foundation

enum OpenAPIDocumentError: Error {
    case notVendored
    case unparsableJSON
}

struct OpenAPIDocument {
    let url: URL
    let text: String

    func jsonObject() throws -> [String: Any] {
        let object = try? JSONSerialization.jsonObject(with: Data(text.utf8))
        guard let dictionary = object as? [String: Any] else {
            throw OpenAPIDocumentError.unparsableJSON
        }
        return dictionary
    }
}

enum OpenAPIDocumentLocator {
    static let candidatePaths = [
        "OpenAPI/color-matching-openapi.json",
        "OpenAPI/openapi.json"
    ]

    static let acceptedFileNames: Set<String> = [
        "openapi.json",
        "color-matching-openapi.json"
    ]

    static func vendoredDocument(packageRoot: URL) throws -> OpenAPIDocument {
        for relativePath in candidatePaths {
            if let document = document(at: packageRoot.appendingPathComponent(relativePath)) {
                return document
            }
        }
        if let document = firstMatchUnderSearchDirectories(of: packageRoot) {
            return document
        }
        throw OpenAPIDocumentError.notVendored
    }

    private static func document(at url: URL) -> OpenAPIDocument? {
        guard let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty else {
            return nil
        }
        return OpenAPIDocument(url: url, text: text)
    }

    private static func firstMatchUnderSearchDirectories(of packageRoot: URL) -> OpenAPIDocument? {
        for directoryName in ["OpenAPI", "Sources"] {
            let directory = packageRoot.appendingPathComponent(directoryName)
            guard let matches = matches(under: directory), let first = matches.first else {
                continue
            }
            if let document = document(at: first) {
                return document
            }
        }
        return nil
    }

    private static func matches(under directory: URL) -> [URL]? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        var matches: [URL] = []
        for case let url as URL in enumerator {
            if url.path.contains(".build") {
                continue
            }
            if acceptedFileNames.contains(url.lastPathComponent) {
                matches.append(url)
            }
        }
        return matches.sorted { $0.path < $1.path }
    }
}
