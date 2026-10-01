import Foundation

struct PageSnapshot {
    let platform: Platform
    let url: URL?
    let html: String
    let userAgent: String
    let stats: FilterStats
}

struct PageSnapshotWriter {
    let directory: URL

    init(directory: URL = URL.documentsDirectory.appending(path: "snapshots")) {
        self.directory = directory
    }

    @discardableResult
    func write(_ snapshot: PageSnapshot) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = directory.appending(path: snapshot.platform.rawValue)
        let htmlFile = base.appendingPathExtension("html")
        try snapshot.html.write(to: htmlFile, atomically: true, encoding: .utf8)
        try JSONSerialization.data(withJSONObject: report(for: snapshot), options: [.prettyPrinted, .sortedKeys])
            .write(to: base.appendingPathExtension("json"))
        return htmlFile
    }

    private func report(for snapshot: PageSnapshot) -> [String: Any] {
        [
            "url": snapshot.url?.absoluteString ?? "",
            "userAgent": snapshot.userAgent,
            "hidden": snapshot.stats.hidden,
            "leaks": snapshot.stats.leaks,
        ]
    }
}
