import Foundation

protocol RouteRule {
    func decision(for url: URL) -> RouteDecision?
}

struct BlockPathRule: RouteRule {
    let prefixes: [String]
    let reason: BlockReason

    func decision(for url: URL) -> RouteDecision? {
        prefixes.contains { url.hasPathPrefix($0) } ? .block(reason) : nil
    }
}

struct BlockPatternRule: RouteRule {
    let pattern: String
    let reason: BlockReason

    func decision(for url: URL) -> RouteDecision? {
        let matches = url.normalizedPath.range(of: "^" + pattern + "$", options: .regularExpression) != nil
        return matches ? .block(reason) : nil
    }
}

struct AllowPathRule: RouteRule {
    let prefixes: [String]

    func decision(for url: URL) -> RouteDecision? {
        prefixes.contains { url.hasPathPrefix($0) } ? .allow : nil
    }
}

struct RewriteRule: RouteRule {
    let rewrite: (URL) -> URL?

    func decision(for url: URL) -> RouteDecision? {
        guard let target = rewrite(url), target != url else { return nil }
        return .redirect(target)
    }
}
