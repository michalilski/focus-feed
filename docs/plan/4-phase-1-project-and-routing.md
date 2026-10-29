# FocusFeed Implementation Plan — 4. Phase 1: project and routing

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first.

**Goal of this phase:** a generated Xcode project that builds, with the complete URL routing layer for all three platforms, fully unit-tested. No web view yet.

**Done when:** `make test` prints `** TEST SUCCEEDED **` with 22 tests, `make uitest` passes, `make audit` prints only `ok:` lines, and everything is committed.

All paths are relative to the repository root `focus-feed`.

---

### Task 1: Tooling and scaffolding

**Files:**
- Create: `.gitignore`, `project.yml`, `Makefile`, `scripts/test.sh`, `scripts/privacy_audit.sh`, `scripts/make_icon.swift`
- Create: `FocusFeed/App/FocusFeedApp.swift`, `FocusFeed/App/RootView.swift`
- Create: `FocusFeed/Resources/Assets.xcassets/Contents.json`, `…/AppIcon.appiconset/Contents.json`, `…/AccentColor.colorset/Contents.json`
- Create: `FocusFeedUITests/SmokeUITests.swift`

- [ ] **Step 1: Install XcodeGen**

```bash
brew install xcodegen
xcodegen --version
```

Expected: `Version: 2.46.0` or newer.

- [ ] **Step 2: Check the starting point**

The spec and this plan are already committed on `main`.

```bash
git status --short
git log --oneline | head -3
```

Expected: no uncommitted changes, and a commit `docs: add FocusFeed spec and implementation plan`.

- [ ] **Step 3: Create the ignore file**

`.gitignore`

```text
build/
snapshots/
*.xcodeproj
xcuserdata/
.DS_Store
```

`FocusFeed.xcodeproj` is generated, so it is ignored. `snapshots/` holds private page dumps and must never be committed.

- [ ] **Step 4: Create the project definition**

`project.yml`

```yaml
name: FocusFeed
options:
  bundleIdPrefix: com.michalilski
  deploymentTarget:
    iOS: "26.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.0"
    DEVELOPMENT_TEAM: <TEAM_ID>
    CODE_SIGN_STYLE: Automatic
    TARGETED_DEVICE_FAMILY: "1"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  FocusFeed:
    type: application
    platform: iOS
    sources:
      - FocusFeed
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.michalilski.focusfeed
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: FocusFeed
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_NSCameraUsageDescription: "Used when you choose to take a photo or video for a post or message."
        INFOPLIST_KEY_NSMicrophoneUsageDescription: "Used when you choose to record video or audio for a post or message."
        INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription: "Used when you save an image from a page."
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
  FocusFeedTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - FocusFeedTests
    dependencies:
      - target: FocusFeed
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.michalilski.focusfeed.tests
  FocusFeedUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - FocusFeedUITests
    dependencies:
      - target: FocusFeed
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.michalilski.focusfeed.uitests
schemes:
  FocusFeed:
    build:
      targets:
        FocusFeed: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - FocusFeedTests
        - FocusFeedUITests
```

Notes: `DEVELOPMENT_TEAM` is Michał's Personal Team. There is deliberately no `packages:` key. The three usage descriptions are needed because the sites can open the camera, microphone and "save image" from inside the web view; without them the app crashes when a site asks.

- [ ] **Step 5: Create the Makefile**

Recipe lines must start with a tab character, not spaces.

`Makefile`

```make
SIMULATOR ?= iPhone 17 Pro
DEVICE ?= <DEVICE_ID>
BUNDLE_ID = com.michalilski.focusfeed
XCODE = xcodebuild -project FocusFeed.xcodeproj -scheme FocusFeed -derivedDataPath build
SIM_DESTINATION = -destination 'platform=iOS Simulator,name=$(SIMULATOR)'
SIM_APP = build/Build/Products/Debug-iphonesimulator/FocusFeed.app
DEVICE_APP = build/Build/Products/Release-iphoneos/FocusFeed.app

.PHONY: gen build test uitest audit sim device pull-snapshots icon clean

gen:
	xcodegen generate --quiet

build: gen
	$(XCODE) build $(SIM_DESTINATION) -quiet

test: gen
	SIMULATOR='$(SIMULATOR)' ./scripts/test.sh -only-testing:FocusFeedTests

uitest: gen
	SIMULATOR='$(SIMULATOR)' ./scripts/test.sh -only-testing:FocusFeedUITests

audit:
	./scripts/privacy_audit.sh

sim: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	open -a Simulator
	xcrun simctl install '$(SIMULATOR)' $(SIM_APP)
	xcrun simctl launch '$(SIMULATOR)' $(BUNDLE_ID)

device: gen
	$(XCODE) build -destination 'generic/platform=iOS' -configuration Release -allowProvisioningUpdates -quiet
	xcrun devicectl device install app --device $(DEVICE) $(DEVICE_APP)
	xcrun devicectl device process launch --device $(DEVICE) $(BUNDLE_ID)

pull-snapshots:
	mkdir -p snapshots
	xcrun devicectl device copy from --device $(DEVICE) --domain-type appDataContainer \
		--domain-identifier $(BUNDLE_ID) --source Documents/snapshots --destination snapshots

icon:
	swift scripts/make_icon.swift FocusFeed/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

clean:
	rm -rf build
```

- [ ] **Step 6: Create the test runner script**

`scripts/test.sh`

```bash
#!/bin/zsh
set -uo pipefail

SIMULATOR=${SIMULATOR:-iPhone 17 Pro}
LOG=build/test.log

mkdir -p build
xcodebuild test -project FocusFeed.xcodeproj -scheme FocusFeed \
  -destination "platform=iOS Simulator,name=$SIMULATOR" -derivedDataPath build "$@" >"$LOG" 2>&1
STATUS=$?
grep -E ": error: |Executed [0-9]+ tests|\*\* TEST" "$LOG" | grep -v ProcessSuspension | sort -u
echo "Full log: $LOG"
exit $STATUS
```

- [ ] **Step 7: Create the privacy audit script**

`scripts/privacy_audit.sh`

```bash
#!/bin/zsh
set -uo pipefail

FAILED=0

forbid() {
  local description=$1 pattern=$2
  shift 2
  if grep -rnE "$pattern" "$@" 2>/dev/null; then
    echo "FAIL: $description"
    FAILED=1
  else
    echo "ok:   $description"
  fi
}

forbid "no app-made network calls in Swift" 'URLSession|NWConnection|import Network|CFSocket|CFStream' FocusFeed
forbid "no analytics or crash SDKs" 'Firebase|Crashlytics|Sentry|Amplitude|Mixpanel|Segment|AppCenter|Analytics' FocusFeed project.yml
forbid "no third-party packages" '^packages:|package:' project.yml
forbid "no network or storage access from injected scripts" 'fetch\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|document\.cookie|localStorage|sessionStorage|indexedDB|new Image' FocusFeed/Resources/Filters
forbid "no remote URLs in injected scripts" 'https?://' FocusFeed/Resources/Filters
forbid "no insecure transport exceptions" 'NSAllowsArbitraryLoads|NSExceptionDomains' FocusFeed project.yml
forbid "no reading of cookies or credentials in Swift" 'httpCookieStore|HTTPCookie|SecItem|Keychain' FocusFeed

if find . -name Package.resolved -not -path "./build/*" | grep -q .; then
  echo "FAIL: Package.resolved found"
  FAILED=1
else
  echo "ok:   no resolved packages"
fi

exit $FAILED
```

- [ ] **Step 8: Create the icon script**

`scripts/make_icon.swift`

```swift
import AppKit

struct IconRenderer {
    let size: CGFloat = 1024

    func render() -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.current = context
        drawBackground()
        drawRings()
        context.flushGraphics()
        return bitmap.representation(using: .png, properties: [:])
    }

    private func drawBackground() {
        let colors = [NSColor(red: 0.10, green: 0.33, blue: 0.29, alpha: 1), NSColor(red: 0.20, green: 0.55, blue: 0.47, alpha: 1)]
        NSGradient(colors: colors)?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 90)
    }

    private func drawRings() {
        let center = NSPoint(x: size / 2, y: size / 2)
        for (radius, alpha) in [(330.0, 0.35), (220.0, 0.6)] {
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            ring.lineWidth = 44
            NSColor.white.withAlphaComponent(alpha).setStroke()
            ring.stroke()
        }
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 96, y: center.y - 96, width: 192, height: 192)).fill()
    }
}

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
guard let data = IconRenderer().render() else { fatalError("Could not render icon") }
try data.write(to: URL(fileURLWithPath: output))
```

- [ ] **Step 9: Make the scripts executable**

```bash
chmod +x scripts/test.sh scripts/privacy_audit.sh
```

- [ ] **Step 10: Create the app entry point and a placeholder root view**

The app shows an empty view while unit tests run, so tests never load real websites.

`FocusFeed/App/FocusFeedApp.swift`

```swift
import SwiftUI

@main
struct FocusFeedApp: App {
    private let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    var body: some Scene {
        WindowGroup {
            if isUnitTesting {
                Color.clear
            } else {
                RootView()
            }
        }
    }
}
```

`FocusFeed/App/RootView.swift`

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        Text("FocusFeed")
    }
}
```

- [ ] **Step 11: Create the asset catalog**

`FocusFeed/Resources/Assets.xcassets/Contents.json`

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`FocusFeed/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

```json
{
  "images" : [ { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`FocusFeed/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`

```json
{
  "colors" : [ { "idiom" : "universal", "color" : { "color-space" : "srgb", "components" : { "red" : "0.180", "green" : "0.490", "blue" : "0.420", "alpha" : "1.000" } } } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 12: Draw the icon**

```bash
make icon
ls -la FocusFeed/Resources/Assets.xcassets/AppIcon.appiconset/
```

Expected: `AppIcon.png`, roughly 300 KB.

- [ ] **Step 13: Create a first UI test so the UI test target has a source file**

`FocusFeedUITests/SmokeUITests.swift`

```swift
import XCTest

final class SmokeUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
```

Do not generate or build yet: the unit test target has no files until task 2.

---

### Task 2: Router tests first

**Files:**
- Create: `FocusFeedTests/RouterTestCase.swift`, `FocusFeedTests/YouTubeRouterTests.swift`, `FocusFeedTests/InstagramRouterTests.swift`, `FocusFeedTests/XRouterTests.swift`

These tests are the executable form of the spec's keep/remove table.

- [ ] **Step 1: Create the shared test base class**

`FocusFeedTests/RouterTestCase.swift`

```swift
import XCTest
@testable import FocusFeed

class RouterTestCase: XCTestCase {
    var profile: PlatformProfile { fatalError("Override in subclass") }

    func decide(_ string: String) -> RouteDecision {
        Router(profile: profile).decide(URL(string: string)!)
    }

    func assertAllowed(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decide(string), .allow, string, file: file, line: line)
    }

    func assertRedirect(_ string: String, to target: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decide(string), .redirect(URL(string: target)!), string, file: file, line: line)
    }

    func assertBlocked(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .block = decide(string) else {
            return XCTFail("Expected block for \(string), got \(decide(string))", file: file, line: line)
        }
    }

    func assertExternal(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decide(string), .external, string, file: file, line: line)
    }
}
```

- [ ] **Step 2: Create the YouTube router tests**

`FocusFeedTests/YouTubeRouterTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class YouTubeRouterTests: RouterTestCase {
    override var profile: PlatformProfile { .youtube }

    func testHomeRedirectsToSubscriptions() {
        assertRedirect("https://m.youtube.com/", to: "https://m.youtube.com/feed/subscriptions")
        assertRedirect("https://www.youtube.com", to: "https://www.youtube.com/feed/subscriptions")
    }

    func testShortIsRewrittenToWatchPage() {
        assertRedirect("https://m.youtube.com/shorts/abc_DEF-123", to: "https://m.youtube.com/watch?v=abc_DEF-123")
        assertRedirect("https://m.youtube.com/shorts/abc123?feature=share", to: "https://m.youtube.com/watch?v=abc123")
    }

    func testShortsFeedsAreBlocked() {
        assertBlocked("https://m.youtube.com/shorts")
        assertBlocked("https://m.youtube.com/shorts/")
        assertBlocked("https://m.youtube.com/feed/shorts")
        assertBlocked("https://m.youtube.com/@somechannel/shorts")
        assertBlocked("https://m.youtube.com/channel/UC123/shorts")
    }

    func testDiscoveryIsBlocked() {
        assertBlocked("https://m.youtube.com/feed/trending")
        assertBlocked("https://m.youtube.com/feed/explore")
    }

    func testKeptPagesAreAllowed() {
        assertAllowed("https://m.youtube.com/feed/subscriptions")
        assertAllowed("https://m.youtube.com/watch?v=abc123")
        assertAllowed("https://m.youtube.com/results?search_query=swift")
        assertAllowed("https://m.youtube.com/@somechannel/videos")
        assertAllowed("https://m.youtube.com/playlist?list=PL123")
        assertAllowed("https://m.youtube.com/feed/library")
        assertAllowed("https://accounts.google.com/ServiceLogin")
        assertAllowed("about:blank")
    }

    func testOtherSitesAreExternal() {
        assertExternal("https://example.com/article")
        assertExternal("https://www.google.com/search?q=x")
        assertExternal("https://notyoutube.com/")
    }

    func testNonWebSchemesAreCancelled() {
        XCTAssertEqual(decide("youtube://watch?v=abc"), .cancel)
        XCTAssertEqual(decide("itms-apps://apps.apple.com/app/id544007664"), .cancel)
        XCTAssertEqual(decide("http://m.youtube.com/"), .cancel)
    }
}
```

- [ ] **Step 3: Create the Instagram router tests**

`FocusFeedTests/InstagramRouterTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class InstagramRouterTests: RouterTestCase {
    override var profile: PlatformProfile { .instagram }

    func testHomeIsForcedToFollowing() {
        assertRedirect("https://www.instagram.com/", to: "https://www.instagram.com/?variant=following")
        assertRedirect("https://www.instagram.com/?variant=home", to: "https://www.instagram.com/?variant=following")
        assertAllowed("https://www.instagram.com/?variant=following")
    }

    func testPostLoginLandingIsForcedToFollowing() {
        assertRedirect("https://www.instagram.com/?deoia=1", to: "https://www.instagram.com/?variant=following")
    }

    func testReelPagerIsRewrittenToSingleReel() {
        assertRedirect("https://www.instagram.com/reels/Cabc_123-x/", to: "https://www.instagram.com/reel/Cabc_123-x/")
        assertAllowed("https://www.instagram.com/reel/Cabc_123-x/")
        assertAllowed("https://www.instagram.com/someuser/reel/Cabc123/")
    }

    func testReelsFeedsAreBlocked() {
        assertBlocked("https://www.instagram.com/reels/")
        assertBlocked("https://www.instagram.com/reels")
        assertBlocked("https://www.instagram.com/reels/audio/12345/")
    }

    func testExploreGridRedirectsToSearch() {
        assertRedirect("https://www.instagram.com/explore/", to: "https://www.instagram.com/explore/search/")
        assertAllowed("https://www.instagram.com/explore/search/")
        assertAllowed("https://www.instagram.com/explore/search/keyword/?q=cats")
        assertAllowed("https://www.instagram.com/explore/tags/cats/")
        assertAllowed("https://www.instagram.com/explore/locations/123/warsaw/")
        assertBlocked("https://www.instagram.com/explore/people/")
    }

    func testKeptPagesAreAllowed() {
        assertAllowed("https://www.instagram.com/someuser/")
        assertAllowed("https://www.instagram.com/p/Cabc123/")
        assertAllowed("https://www.instagram.com/direct/inbox/")
        assertAllowed("https://www.instagram.com/direct/t/123456/")
        assertAllowed("https://www.instagram.com/stories/someuser/123/")
        assertAllowed("https://www.instagram.com/accounts/login/")
    }

    func testOtherSitesAreExternal() {
        assertExternal("https://example.com/")
    }
}
```

- [ ] **Step 4: Create the X router tests**

`FocusFeedTests/XRouterTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class XRouterTests: RouterTestCase {
    override var profile: PlatformProfile { .x }

    func testDiscoveryIsBlocked() {
        assertBlocked("https://x.com/i/trends")
        assertBlocked("https://x.com/explore/tabs/for-you")
        assertBlocked("https://x.com/i/connect_people")
    }

    func testExtrasAreBlocked() {
        assertBlocked("https://x.com/i/grok")
        assertBlocked("https://x.com/jobs")
        assertBlocked("https://x.com/i/premium_sign_up")
    }

    func testKeptPagesAreAllowed() {
        assertAllowed("https://x.com/home")
        assertAllowed("https://x.com/explore")
        assertAllowed("https://x.com/search?q=swift&src=typed_query")
        assertAllowed("https://x.com/someuser")
        assertAllowed("https://x.com/someuser/status/123456")
        assertAllowed("https://x.com/notifications")
        assertAllowed("https://x.com/messages")
        assertAllowed("https://x.com/i/chat")
        assertAllowed("https://x.com/i/lists/123")
        assertAllowed("https://x.com/i/bookmarks")
        assertAllowed("https://x.com/i/flow/login")
        assertAllowed("https://twitter.com/someuser")
    }

    func testOtherSitesAreExternal() {
        assertExternal("https://t.co/abc123")
        assertExternal("https://example.com/")
    }
}
```

- [ ] **Step 5: Run the tests and confirm they cannot compile yet**

```bash
make test
```

Expected: `** TEST FAILED **` and compiler errors such as `error: cannot find type 'PlatformProfile' in scope`. This is the "red" step.

---

### Task 3: Routing core

**Files:**
- Create: `FocusFeed/Routing/RouteDecision.swift`, `FocusFeed/Routing/RouteRule.swift`, `FocusFeed/Routing/URL+Path.swift`, `FocusFeed/Routing/Router.swift`
- Create: `FocusFeed/Platforms/Platform.swift`, `FocusFeed/Platforms/PlatformProfile.swift`

- [ ] **Step 1: Create the decision types**

`FocusFeed/Routing/RouteDecision.swift`

```swift
import Foundation

struct BlockReason: Equatable {
    let title: String
    let message: String
}

enum RouteDecision: Equatable {
    case allow
    case redirect(URL)
    case block(BlockReason)
    case external
    case cancel
}
```

- [ ] **Step 2: Create the URL helpers**

`normalizedPath` removes a trailing slash so `/reels` and `/reels/` are the same path. `hasPathPrefix("/shorts")` matches `/shorts` and `/shorts/abc` but not `/shortsomething`.

`FocusFeed/Routing/URL+Path.swift`

```swift
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
```

- [ ] **Step 3: Create the rule types**

A rule returns `nil` when it has no opinion. `BlockPatternRule.pattern` is a regular expression that must match the whole normalised path.

`FocusFeed/Routing/RouteRule.swift`

```swift
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
```

- [ ] **Step 4: Create the platform identifier**

`FocusFeed/Platforms/Platform.swift`

```swift
import Foundation

enum Platform: String, CaseIterable, Identifiable {
    case instagram
    case youtube
    case x

    var id: String { rawValue }
}
```

- [ ] **Step 5: Create the platform profile type**

`owns(_:)` matches a host exactly or as a parent domain: `youtube.com` owns `m.youtube.com` but not `notyoutube.com`.

`FocusFeed/Platforms/PlatformProfile.swift`

```swift
import Foundation

struct PlatformProfile {
    let platform: Platform
    let title: String
    let symbolName: String
    let homeURL: URL
    let internalHosts: [String]
    let rules: [RouteRule]
    let filterScriptName: String
    let dataStoreID: UUID
    let mediaRequiresUserAction: Bool

    func owns(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return internalHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func profile(for platform: Platform) -> PlatformProfile {
        switch platform {
        case .instagram: return .instagram
        case .youtube: return .youtube
        case .x: return .x
        }
    }

    static func owner(of url: URL) -> PlatformProfile? {
        Platform.allCases.map(profile(for:)).first { $0.owns(url) }
    }
}
```

- [ ] **Step 6: Create the router**

`FocusFeed/Routing/Router.swift`

```swift
import Foundation

struct Router {
    let profile: PlatformProfile

    func decide(_ url: URL) -> RouteDecision {
        guard let scheme = url.scheme?.lowercased() else { return .cancel }
        if scheme == "about" { return .allow }
        guard scheme == "https" else { return .cancel }
        guard profile.owns(url) else { return .external }
        for rule in profile.rules {
            if let decision = rule.decision(for: url) { return decision }
        }
        return .allow
    }
}
```

---

### Task 4: The three platform profiles

**Files:**
- Create: `FocusFeed/Platforms/YouTubeProfile.swift`, `FocusFeed/Platforms/InstagramProfile.swift`, `FocusFeed/Platforms/XProfile.swift`

Rule order matters: the first rule with an opinion wins.

- [ ] **Step 1: Create the YouTube profile**

`/shorts/<id>` is rewritten before `/shorts` is blocked, so a single short plays as a normal video while the Shorts feed is blocked. Only the Google hosts needed for login are internal; the rest of google.com is external.

`FocusFeed/Platforms/YouTubeProfile.swift`

```swift
import Foundation

extension PlatformProfile {
    static let youtube = PlatformProfile(
        platform: .youtube,
        title: "YouTube",
        symbolName: "play.rectangle.fill",
        homeURL: URL(string: "https://m.youtube.com/feed/subscriptions")!,
        internalHosts: [
            "youtube.com", "youtu.be", "youtube-nocookie.com",
            "accounts.google.com", "accounts.google.pl", "accounts.youtube.com",
            "myaccount.google.com", "gds.google.com", "consent.google.com",
        ],
        rules: YouTubeRules.all,
        filterScriptName: "youtube",
        dataStoreID: UUID(uuidString: "7B6E0A51-0C7C-4B0E-9A53-6C1D5C0F0002")!,
        mediaRequiresUserAction: false
    )
}

enum YouTubeRules {
    static let shortsBlocked = BlockReason(
        title: "Shorts are off",
        message: "Shorts feeds are blocked. Pick a video from your subscriptions or search instead."
    )
    static let discoveryBlocked = BlockReason(
        title: "Recommendations are off",
        message: "Trending and Explore are blocked. Use search to find something specific."
    )

    static let all: [RouteRule] = [
        RewriteRule(rewrite: homeToSubscriptions),
        RewriteRule(rewrite: shortToWatch),
        BlockPathRule(prefixes: ["/shorts", "/feed/shorts"], reason: shortsBlocked),
        BlockPatternRule(pattern: "/(@[^/]+|(c|channel|user)/[^/]+)/shorts", reason: shortsBlocked),
        BlockPathRule(prefixes: ["/feed/trending", "/feed/explore"], reason: discoveryBlocked),
    ]

    private static let youtubeHosts = ["youtube.com", "www.youtube.com", "m.youtube.com"]

    private static func homeToSubscriptions(_ url: URL) -> URL? {
        guard let host = url.host(), youtubeHosts.contains(host), url.normalizedPath == "/" else { return nil }
        return url.replacingPath("/feed/subscriptions")
    }

    private static func shortToWatch(_ url: URL) -> URL? {
        guard let match = url.normalizedPath.wholeMatch(of: /\/shorts\/([A-Za-z0-9_-]+)/) else { return nil }
        return url.replacingPath("/watch", queryItems: [URLQueryItem(name: "v", value: String(match.1))])
    }
}
```

- [ ] **Step 2: Create the Instagram profile**

`/reels/<id>/` is the swipe pager and is rewritten to `/reel/<id>/`, the single-reel page, which stays allowed. `/explore/` redirects to the search page; tag and location pages stay because ordinary posts link to them.

`FocusFeed/Platforms/InstagramProfile.swift`

```swift
import Foundation

extension PlatformProfile {
    static let instagram = PlatformProfile(
        platform: .instagram,
        title: "Instagram",
        symbolName: "camera.fill",
        homeURL: URL(string: "https://www.instagram.com/?variant=following")!,
        internalHosts: ["instagram.com", "facebook.com", "meta.com"],
        rules: InstagramRules.all,
        filterScriptName: "instagram",
        dataStoreID: UUID(uuidString: "7B6E0A51-0C7C-4B0E-9A53-6C1D5C0F0001")!,
        mediaRequiresUserAction: true
    )
}

enum InstagramRules {
    static let reelsBlocked = BlockReason(
        title: "Reels are off",
        message: "The Reels feed is blocked. Posts from people you follow are in your Following feed."
    )
    static let exploreBlocked = BlockReason(
        title: "Explore is off",
        message: "The Explore grid is blocked. Use search to find a specific account or tag."
    )

    static let all: [RouteRule] = [
        RewriteRule(rewrite: homeToFollowing),
        RewriteRule(rewrite: reelPagerToSingleReel),
        BlockPathRule(prefixes: ["/reels"], reason: reelsBlocked),
        RewriteRule(rewrite: exploreToSearch),
        BlockPathRule(prefixes: ["/explore/people"], reason: exploreBlocked),
    ]

    private static func homeToFollowing(_ url: URL) -> URL? {
        guard url.normalizedPath == "/", url.queryValue("variant") != "following" else { return nil }
        return url.replacingPath("/", queryItems: [URLQueryItem(name: "variant", value: "following")])
    }

    private static func reelPagerToSingleReel(_ url: URL) -> URL? {
        guard let match = url.normalizedPath.wholeMatch(of: /\/reels\/([A-Za-z0-9_-]+)/) else { return nil }
        guard match.1 != "audio" else { return nil }
        return url.replacingPath("/reel/\(match.1)/")
    }

    private static func exploreToSearch(_ url: URL) -> URL? {
        guard url.normalizedPath == "/explore" else { return nil }
        return url.replacingPath("/explore/search/")
    }
}
```

- [ ] **Step 3: Create the X profile**

`/explore` stays allowed because the search box lives there; its trends are hidden by the filter script in phase 6.

`FocusFeed/Platforms/XProfile.swift`

```swift
import Foundation

extension PlatformProfile {
    static let x = PlatformProfile(
        platform: .x,
        title: "X",
        symbolName: "bubble.left.fill",
        homeURL: URL(string: "https://x.com/home")!,
        internalHosts: ["x.com", "twitter.com"],
        rules: XRules.all,
        filterScriptName: "x",
        dataStoreID: UUID(uuidString: "7B6E0A51-0C7C-4B0E-9A53-6C1D5C0F0003")!,
        mediaRequiresUserAction: true
    )
}

enum XRules {
    static let discoveryBlocked = BlockReason(
        title: "Trends are off",
        message: "Trending and recommendations are blocked. Use search to find something specific."
    )
    static let extrasBlocked = BlockReason(
        title: "Not part of FocusFeed",
        message: "Grok, Communities discovery, Jobs and Premium upsells are blocked."
    )

    static let all: [RouteRule] = [
        BlockPathRule(prefixes: ["/i/trends", "/explore/tabs", "/i/connect_people", "/i/follow_people"], reason: discoveryBlocked),
        BlockPathRule(prefixes: ["/i/grok", "/jobs", "/i/premium_sign_up", "/i/communities/suggested", "/i/lists/suggested"], reason: extrasBlocked),
    ]
}
```

- [ ] **Step 4: Run the tests**

```bash
make test
```

Expected:

```
	 Executed 18 tests, with 0 failures (0 unexpected) in …
** TEST SUCCEEDED **
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore project.yml Makefile scripts FocusFeed FocusFeedTests FocusFeedUITests
git commit -m "feat: project skeleton and URL routing for all platforms"
```

---

### Task 5: Redirect loop guard

**Files:**
- Create: `FocusFeedTests/RedirectGuardTests.swift`
- Create: `FocusFeed/Routing/RedirectGuard.swift`

Why: if a site rewrites the URL back after we redirect (for example Instagram dropping `?variant=following`), the app would reload forever. The guard refuses to redirect the same source URL twice within 3 seconds; the session then lets the page be.

- [ ] **Step 1: Write the failing tests**

`FocusFeedTests/RedirectGuardTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class RedirectGuardTests: XCTestCase {
    private let url = URL(string: "https://www.instagram.com/")!
    private let start = Date(timeIntervalSince1970: 1_000)

    func testFirstRedirectIsPermitted() {
        var redirectGuard = RedirectGuard(window: 3)
        XCTAssertTrue(redirectGuard.shouldRedirect(from: url, now: start))
    }

    func testRepeatedRedirectInsideWindowIsRefused() {
        var redirectGuard = RedirectGuard(window: 3)
        _ = redirectGuard.shouldRedirect(from: url, now: start)
        XCTAssertFalse(redirectGuard.shouldRedirect(from: url, now: start.addingTimeInterval(1)))
    }

    func testRepeatedRedirectAfterWindowIsPermitted() {
        var redirectGuard = RedirectGuard(window: 3)
        _ = redirectGuard.shouldRedirect(from: url, now: start)
        XCTAssertTrue(redirectGuard.shouldRedirect(from: url, now: start.addingTimeInterval(4)))
    }

    func testDifferentSourceIsPermitted() {
        var redirectGuard = RedirectGuard(window: 3)
        _ = redirectGuard.shouldRedirect(from: url, now: start)
        let other = URL(string: "https://www.instagram.com/reel/abc/")!
        XCTAssertTrue(redirectGuard.shouldRedirect(from: other, now: start.addingTimeInterval(1)))
    }
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
make test
```

Expected: `** TEST FAILED **`, `error: cannot find 'RedirectGuard' in scope`.

- [ ] **Step 3: Implement**

`FocusFeed/Routing/RedirectGuard.swift`

```swift
import Foundation

struct RedirectGuard {
    private var lastSource: URL?
    private var lastTime: Date?
    let window: TimeInterval

    init(window: TimeInterval = 3) {
        self.window = window
    }

    mutating func shouldRedirect(from url: URL, now: Date = Date()) -> Bool {
        defer {
            lastSource = url
            lastTime = now
        }
        guard let lastSource, let lastTime, lastSource == url else { return true }
        return now.timeIntervalSince(lastTime) > window
    }
}
```

- [ ] **Step 4: Run and confirm success**

```bash
make test
```

Expected: `Executed 22 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add FocusFeed/Routing/RedirectGuard.swift FocusFeedTests/RedirectGuardTests.swift
git commit -m "feat: guard against redirect loops"
```

---

### Task 6: Phase check

- [ ] **Step 1: UI smoke test**

```bash
make uitest
```

Expected: `Executed 1 test, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 2: Privacy audit**

```bash
make audit
```

Expected: eight lines, all starting with `ok:`.

- [ ] **Step 3: Update `docs/plan/changelog.md`**

Set phase 1 to "done" in the status table and add a log line with today's date.

```bash
git add docs/plan/changelog.md
git commit -m "docs: phase 1 complete"
```
