import Foundation

struct LaunchOptions {
    let platform: Platform?
    let url: URL?
    let snapshotDelay: TimeInterval?

    init(defaults: UserDefaults = .standard) {
        platform = defaults.string(forKey: "FFPlatform").flatMap(Platform.init(rawValue:))
        url = defaults.string(forKey: "FFURL").flatMap(URL.init(string:))
        let delay = defaults.double(forKey: "FFSnapshotAfter")
        snapshotDelay = delay > 0 ? delay : nil
    }
}
