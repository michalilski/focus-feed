import WebKit

struct FilterScriptLibrary {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func source(for profile: PlatformProfile) -> String {
        [load("common"), load(profile.filterScriptName)].joined(separator: "\n")
    }

    func userScript(for profile: PlatformProfile) -> WKUserScript {
        WKUserScript(
            source: source(for: profile),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .defaultClient
        )
    }

    private func load(_ name: String) -> String {
        guard let url = bundle.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Missing filter script \(name).js")
        }
        return text
    }
}
