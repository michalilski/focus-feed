# FocusFeed changelog

Where the project is. Update this file after every task: change the status table, add a line to the log, and move anything unresolved to "Known gaps". Newest log entries at the top.

## Status

| Phase | File | Status |
| --- | --- | --- |
| Plan | `1-` to `3-` | done (2026-10-01) |
| 1. Project and routing | `4-phase-1-project-and-routing.md` | done (2026-10-01) |
| 2. Filter engine | `5-phase-2-filter-engine.md` | done (2026-10-01) |
| 3. Browser shell | `6-phase-3-browser-shell.md` | done (2026-10-01) |
| 4. YouTube on the phone | `7-phase-4-youtube.md` | done (2026-10-01) |
| 5. Instagram | `8-phase-5-instagram.md` | done (2026-10-01) |
| 6. X | `9-phase-6-x.md` | done (2026-10-01) |
| 7. Polish and privacy audit | `10-phase-7-polish-and-privacy-audit.md` | in progress |
| 8. Daily use and maintenance | `11-phase-8-daily-use-and-maintenance.md` | not started |

**Next step:** phase 7 USER: UX review list (task 1) and a day with App Privacy Report on (task 3); then phase 8.

## Installs

Free signing: each install expires 7 days after the build date.

| Build date | Expires | Notes |
| --- | --- | --- |
| 2026-10-01 | 2026-10-08 | First install, Release build, free Personal Team signing |
| 2026-10-05 | 2026-10-12 | Old filtered-browser view back after trying the unified UI (`feature/unified-news-ui`, shelved), plus the DM reel guard |

## Known gaps

Things that are known not to work or not yet checked. Each line: date, what, decision.

- 2026-10-01 — Instagram and X selectors are unverified against the logged-in sites. To be checked in phases 5 and 6.
- 2026-10-01 — Google login inside the web view is unverified. Checked first thing in phase 4.
- 2026-10-01 — Reels sent in Instagram DMs: behaviour unknown until phase 5, task 6. Agreed fallback: skip.
- 2026-10-01 — `make pull-snapshots` not run yet (needs a snapshot saved on the phone).

- 2026-10-01 — X header "floating" while scrolling (reported once on the phone, not reproducible logged out in the simulator). Not reported again after the X video fix; recheck during phase 6.

## Log

### 2026-10-05

- Michał's request: a reel opened from DMs must not scroll on to the next reel. `ReelChainGuard` (from `feature/unified-news-ui`) in `BrowserSession.handle`: a client-side move from one reel to a different one is blocked with "One reel at a time" and steps back. `make test` 55 tests, 0 failures; `make uitest` 2 tests, 0 failures; `make audit` all `ok:`. Not yet checked on the phone.

### 2026-10-01

- Phase 7, task 2, privacy audit passed: `make audit` 8 `ok:` lines; one user script (created in `FilterScriptLibrary`, added in `WebViewFactory`); `BrowserSession` evaluates only `FocusFeed.extendCutoff()`, `document.documentElement.outerHTML` and `navigator.userAgent`; `common.js` is the only `postMessage` caller. The filter scripts only add one `<style>`, set/remove the `data-focusfeed-*` attributes, click the YouTube autoplay toggle and the X Following tab. `isInspectable` is Debug-only; no packages in `project.yml`.
- Phases 4, 5 and 6 complete: Michał ran the YouTube, Instagram and X checklists on the phone, logged in, and reported that everything works. Not reported separately: Safari user agent comparison (phase 4 task 2), Filters numbers, the DM reel case (phase 5 task 6), the X floating header recheck; all covered by the overall "works" report.
- Phase 6, tasks 1–2 (no login needed): X fixtures (home, status, explore) and tests, seen failing on the expected elements, then `x.js`. `make test`: 49 tests, 0 failures (plan said 45; +4 from the YouTube change). `make uitest` passed, audit clean. Logged-out probe of x.com/SpaceX renders as before. Selectors still unverified against the logged-in site.
- Phase 5, tasks 1–2 (started while phase 4 waits for Michał's phone checks; no login needed): Instagram fixtures (feed, explore, profile, age cutoff) and tests, seen failing as predicted (profile test passing already), then `instagram.js`. `make test`: 46 tests, 0 failures (plan said 42; +4 from the YouTube recommendations change). Audit clean. Selectors still unverified against the logged-in site.
- Phase 4, task 1 done by Michał (logged in on the phone; confirmed working after the app-link fix). Task 3, logged-out probes: `/@NASA` first hit YouTube's full-page consent; rejected cookies once in the simulator with a throwaway UI test (not committed), then: `channel-shorts-tab` 1, `shorts-nav-tab` 1, 0 Shorts links, leaks 0, no Shorts tab in the screenshot. `/@NASA/shorts` shows the "Shorts are off" card.
- Phase 3 complete. Michał confirmed on the phone: Instagram loads fine, YouTube login no longer opens the YouTube app, YouTube Home and related videos show without Shorts, X videos play.
- Change requested by Michał: YouTube keeps Home recommendations and related videos, full videos only. Removed the `/` → subscriptions redirect (the app still opens on Subscriptions) and the `home-nav-tab`, `home-feed`, `related-videos` hide rules and `related-video` leak rule; added a 6000 px Home cutoff. New `youtube-home.html` fixture; the watch fixture now expects related videos visible and Shorts inside them hidden. Tests seen failing first; `make test` 42 passed. Live probe: `/` stays on Home with the Home tab visible and Shorts tab hidden, watch page keeps related items with 0 Shorts links. Logged-out Home has no recommendations, so the feed itself is checked on the phone. Spec, decisions and phase 4 checklist updated.
- Fix (found on the phone): X videos did not load. Evidence from a temporary diagnostic test on x.com/SpaceX (logged out, simulator): with `mediaTypesRequiringUserActionForPlayback = .all` X's videos had no source and `readyState 0`; without it they had a `blob:` source and `readyState 4` and still did not autoplay. X now has `mediaRequiresUserAction: false`; autoplay is to be turned off in X's own settings instead. Decision table in `1-overview-and-architecture.md` updated. Needs re-check on the phone.
- Fix (found on the phone): after Google login, YouTube opened the YouTube app. Cause: returning plain `.allow` from `decidePolicyFor` lets WebKit hand universal links (here the cross-domain hop accounts.google.com → m.youtube.com) to the app that claims them. Allowed main-frame navigations now return `.allowWithoutTryingAppLink` (WebKit's private policy value `allow + 2`, the same one Firefox for iOS uses). New `AppLinkPolicyTests`; `make test` 40 passed, `make uitest` passed, live YouTube probe unchanged. Needs re-check on the phone.
- Phase 3, task 9: first install on the iPhone. `make audit` clean; `make device` signed and installed, but the first launch was refused (profile not trusted). After Michał trusted the developer profile, `make device` launched the app.
- Phase 3, task 7: `scripts/live_probe.sh`. Live YouTube probes (logged out, simulator): search — leaks 0, `shorts-nav-tab` 1, `home-nav-tab` 1, `shorts-grid-shelf` 2, Safari-shaped user agent; watch — `related-videos` 1, leaks 0; `/shorts/aaaaaaaaaaa` → `/watch?v=aaaaaaaaaaa`; `/` → consent page continuing to `feed/subscriptions`; `/feed/trending` shows the "Recommendations are off" card.
- Phase 3, task 6: UI smoke tests for the shell. `make uitest`: 2 tests, 0 failures.
- Phase 3, tasks 4–5: `LaunchOptions`, `SessionStore`, UI (top bar, browser screen, blocked/error views, caught-up panel, filters sheet, Safari sheet), real `RootView`. `make test`: 38 tests, 0 failures.
- Phase 3, tasks 2–3: `ScrollLimiter`, `DialogPresenter`, `PageSnapshot`, `BrowserSession` (+ navigation delegate); `ScrollLimitTests` seen failing first. `make test`: 38 tests, 0 failures.
- Phase 3, task 1: `CutoffGeometry` with tests (seen failing first). `make test`: 37 tests, 0 failures.
- Phase 2 complete (task 5: cutoff script tests). `make test`: 31 tests, 0 failures; `make audit` all `ok:`.
- Phase 2, task 4: fixture harness and YouTube search/watch fixtures. `make test`: 28 tests, 0 failures. Removing the `related-videos` rule made the watch fixture fail (`#related` visible, `related-video` leak 1); restored.
- Phase 2, task 3: `FilterBridge`, `FilterScriptLibrary`, `WebViewFactory` (isolated content world, Safari user agent suffix, per-platform data store). `make build` succeeds.
- Phase 2, tasks 1–2: filter engine `common.js`, YouTube script, Instagram/X placeholders; `FilterMessage` parsing with tests (seen failing first). `make test`: 26 tests, 0 failures; audit clean.
- Phase 1 complete: `make test` 22 tests passed, `make uitest` 1 test passed, `make audit` 8 `ok:` lines.
- Phase 1, task 5: `RedirectGuard` with tests (seen failing first). `make test`: 22 tests, 0 failures.
- Phase 1, tasks 2–4: router tests written and seen failing (`cannot find type 'PlatformProfile'`), then routing core (`RouteDecision`, `RouteRule`, `Router`, URL helpers) and YouTube/Instagram/X profiles. `make test`: 18 tests, 0 failures.
- Phase 1, task 1: XcodeGen 2.46.0 installed; `.gitignore`, `project.yml`, `Makefile`, `scripts/` (test, privacy audit, icon), app entry point, asset catalog with icon, UI smoke test. `make build` succeeds, `make audit` prints only `ok:` lines.
- Plan written in `docs/plan/`.
- Tools checked: Xcode 26.6, iOS SDK 26.5, simulator runtime iOS 26.5, iPhone 16 Pro (iOS 26.6.1) paired with Developer Mode on, free Personal Team signing identity present. Missing: XcodeGen.
- A throwaway prototype of phases 1–3 plus the Instagram and X scripts was built outside the repository to verify the plan's code: 45 unit tests and 2 UI tests passed on the iPhone 17 Pro simulator; live YouTube probes (logged out) showed Shorts shelves and related videos hidden with 0 leaks, `/` redirected to subscriptions, and `/shorts/<id>` rewritten to `/watch`. The prototype was not kept; the plan files contain its code.
- Added requirement from Michał: reels sent in Instagram DMs should be viewable one at a time; skip if not feasible.
