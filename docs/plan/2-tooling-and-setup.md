# FocusFeed Implementation Plan — 2. Tooling and setup

Everything here was checked on Michał's Mac on 2026-10-01.

## What is installed

| Tool | Found | Needed for | Status |
| --- | --- | --- | --- |
| macOS | 26.6.2, Apple silicon | — | OK |
| Xcode | 26.6 (17F113) at `/Applications/Xcode-26.6.0.app`, selected with `xcode-select` | Build, test, sign | OK |
| Swift | 6.3.3 | Compiler (project uses Swift 5 language mode) | OK |
| iOS SDK | 26.5 | Build | OK |
| iOS Simulator runtime | iOS 26.5, with "iPhone 17 Pro" and others | Tests, live probe | OK |
| iPhone | "iPhone (Michał)", iPhone 16 Pro, iOS 26.6.1, paired, Developer Mode enabled | Real use | OK. It was not connected for a debug session during the check, so the first build in phase 3 may spend a few minutes preparing the device |
| Signing identity | "Apple Development", team "Michał Ilski (Personal Team)", team ID `N5H5R9A2K2` | Install on the phone | OK, but it is a **free** team: see "Signing" below |
| Homebrew | `/opt/homebrew/bin/brew` | Installing XcodeGen | OK |
| XcodeGen | **missing** | Generates `FocusFeed.xcodeproj` from `project.yml` | Install in phase 1, task 1 |
| git, gh | present | Commits | OK |
| node 25, Python 3.12 | present | Not needed | — |
| SwiftLint, SwiftFormat, xcbeautify, fastlane, ios-deploy | missing | Not needed | Do not install |
| Disk | 544 GB free | — | OK |

The only thing to install is XcodeGen:

```bash
brew install xcodegen
xcodegen --version
```

Expected: `Version: 2.46.0` or newer.

## Signing: free Personal Team

The Apple ID in Xcode is a free Personal Team. What that means:

- An app installed from Xcode stops launching **7 days** after it was built. Reinstalling (`make device`) with the phone connected takes about a minute and keeps all data and logins, because the bundle ID stays the same.
- At most 3 free-signed apps on the phone at once, and 10 new app IDs per 7 days. Never change the bundle ID `com.michalilski.focusfeed`.
- The first install needs a one-time trust step on the phone: Settings → General → VPN & Device Management → the developer entry → Trust.
- No special entitlements are needed by this app, so the free team is enough.

Upgrade path, optional: the paid Apple Developer Program ($99/year) makes builds last one year. Nothing in the project changes except that the same `make device` is needed once a year instead of once a week.

## Connecting the phone (USER)

Needed for phase 3 task 9 onward.

1. Plug the iPhone into the Mac with a cable and unlock it. Tap "Trust" if asked.
2. Check it is visible:

```bash
xcrun devicectl list devices
```

Expected: a row `iPhone (Michał) … available (paired) … iPhone 16 Pro`. If the state is `unavailable`, unlock the phone and run it again.

3. After the first successful install, Wi-Fi works too as long as the phone and Mac are on the same network and the phone is unlocked. The cable is more reliable.

The device identifier used by the Makefile is `F6A87C3E-9C2B-503A-BD22-22008E54E524`. If the phone is ever replaced, pass another one: `make device DEVICE=<identifier from the list above>`.

## Commands

All commands run from the repository root.

| Command | What it does | Typical time |
| --- | --- | --- |
| `make gen` | Regenerates `FocusFeed.xcodeproj` from `project.yml`. Run after adding, renaming or deleting files | 1 s |
| `make build` | Builds for the simulator | 20–60 s |
| `make test` | Unit tests on the simulator. Prints one line per test class, any `error:` lines, and `** TEST SUCCEEDED **` or `** TEST FAILED **`. Full log in `build/test.log` | 40–90 s |
| `make uitest` | UI smoke tests on the simulator. Loads the real sites, so it needs internet | 60–120 s |
| `make audit` | Privacy audit script | 1 s |
| `make sim` | Builds, installs and launches in the simulator | 30–60 s |
| `./scripts/live_probe.sh <platform> <url> [seconds]` | Opens one URL in the simulator and writes `build/probe/<platform>.png`, `.html`, `.json` | 20–40 s |
| `make device` | Release build, signed, installed and launched on the iPhone | 1–3 min |
| `make pull-snapshots` | Copies DOM snapshots saved on the phone to `snapshots/` | 5 s |
| `make icon` | Redraws the app icon | 5 s |
| `make clean` | Deletes `build/` | — |

To run one test class or one test:

```bash
./scripts/test.sh -only-testing:FocusFeedTests/YouTubeRouterTests
./scripts/test.sh -only-testing:FocusFeedTests/YouTubeRouterTests/testShortIsRewrittenToWatchPage
```

To use another simulator: `make test SIMULATOR="iPhone 17"`.

## Debugging tools

- **Safari Web Inspector** (Debug builds only): in Safari on the Mac, enable Settings → Advanced → "Show features for web developers". Run the app with `make sim`; the page appears under Develop → Simulator. For the phone, also enable Settings → Apps → Safari → Advanced → Web Inspector on the iPhone and install a Debug build from Xcode (open `FocusFeed.xcodeproj`, pick the phone, Run). This is a tool for Michał; agents use the live probe instead.
- **Live probe**: screenshot + DOM + counters from the simulator, no human needed. See `3-testing-strategy.md`.
- **Filters sheet in the app**: menu → "Filters". Shows hidden and leaking counts for the current page and has "Save DOM snapshot".

## Things only Michał can do

| When | What |
| --- | --- |
| Phase 3, task 9 | Plug in and unlock the phone; trust the developer profile on first install |
| Phase 4 | Log in to YouTube/Google on the phone |
| Phase 5 | Log in to Instagram on the phone; send yourself a reel in a DM from another account, or use an existing one |
| Phase 6 | Log in to X on the phone |
| Phases 4–6 | Walk through each acceptance checklist on the phone and report what leaks; save DOM snapshots for anything that does |
| Phase 8 | Delete the official apps, set up Screen Time |
| Every 7 days | `make device` with the phone connected (free signing) |

Logging in inside the **simulator** is optional. It lets an agent probe logged-in pages by itself, but it is one more "new device" login per site, and the simulator's cookies sit on the Mac's disk. The default in this plan is: log in on the phone only, and fix leaks from snapshots saved on the phone.
