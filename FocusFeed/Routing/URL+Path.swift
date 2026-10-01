import Foundation

extension URL {
    var normalizedPath: String {
        let raw = path(percentEncoded: false)
        let trimmed = raw.count > 1 && raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        return trimmed.isEmpty ? "/" : trimmed
    }

    func hasPathPrefix(_ prefix: String) -> Bool {
        normalizedPath == prefix || normalizedPath.hasPrefix(prefix + "/")
    }

    func replacingPath(_ path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.path = path
        components.queryItems = queryItems
        return components.url
    }

    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }
}
