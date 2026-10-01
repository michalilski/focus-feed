# FocusFeed changelog

Where the project is. Update this file after every task: change the status table, add a line to the log, and move anything unresolved to "Known gaps". Newest log entries at the top.

## Status

| Phase | File | Status |
| --- | --- | --- |
| Plan | `1-` to `3-` | done (2026-10-01) |
| 1. Project and routing | `4-phase-1-project-and-routing.md` | not started |
| 2. Filter engine | `5-phase-2-filter-engine.md` | not started |
| 3. Browser shell | `6-phase-3-browser-shell.md` | not started |
| 4. YouTube on the phone | `7-phase-4-youtube.md` | not started |
| 5. Instagram | `8-phase-5-instagram.md` | not started |
| 6. X | `9-phase-6-x.md` | not started |
| 7. Polish and privacy audit | `10-phase-7-polish-and-privacy-audit.md` | not started |
| 8. Daily use and maintenance | `11-phase-8-daily-use-and-maintenance.md` | not started |

**Next step:** phase 1, task 1 (`brew install xcodegen`).

## Installs

Free signing: each install expires 7 days after the build date.

| Build date | Expires | Notes |
| --- | --- | --- |
| — | — | — |

## Known gaps

Things that are known not to work or not yet checked. Each line: date, what, decision.

- 2026-10-01 — Instagram and X selectors are unverified against the logged-in sites. To be checked in phases 5 and 6.
- 2026-10-01 — Google login inside the web view is unverified. Checked first thing in phase 4.
- 2026-10-01 — Reels sent in Instagram DMs: behaviour unknown until phase 5, task 6. Agreed fallback: skip.
- 2026-10-01 — Signing and installing on the phone, and `make pull-snapshots`, were not run while planning.

## Log

### 2026-10-01

- Plan written in `docs/plan/`.
- Tools checked: Xcode 26.6, iOS SDK 26.5, simulator runtime iOS 26.5, iPhone 16 Pro (iOS 26.6.1) paired with Developer Mode on, free Personal Team signing identity present. Missing: XcodeGen.
- A throwaway prototype of phases 1–3 plus the Instagram and X scripts was built outside the repository to verify the plan's code: 45 unit tests and 2 UI tests passed on the iPhone 17 Pro simulator; live YouTube probes (logged out) showed Shorts shelves and related videos hidden with 0 leaks, `/` redirected to subscriptions, and `/shorts/<id>` rewritten to `/watch`. The prototype was not kept; the plan files contain its code.
- Added requirement from Michał: reels sent in Instagram DMs should be viewable one at a time; skip if not feasible.
