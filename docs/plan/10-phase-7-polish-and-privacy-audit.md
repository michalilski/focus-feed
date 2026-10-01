# FocusFeed Implementation Plan — 10. Phase 7: polish and privacy audit

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first.

**Goal of this phase:** the app feels good in daily use, and the security properties from `1-overview-and-architecture.md` are checked rather than assumed.

**Done when:** the UX review list is worked through, the audit passes, and the App Privacy Report shows only expected domains.

---

### Task 1: UX review on the phone (USER)

Use the app for an evening, then go through this list. Each "no" becomes one small task for the agent; write them into the changelog first, then fix them one commit at a time.

- [ ] Top bar: is it comfortable to reach? Is the platform switcher readable in light and dark mode?
- [ ] Does any site's own header collide with the top bar or the Dynamic Island?
- [ ] Does the bottom of each site (its own navigation bar) sit correctly above the home indicator?
- [ ] Does switching platforms keep each one's place?
- [ ] Does audio stop when switching away from a playing video?
- [ ] Is the blocked card's wording right for you? (Texts are the `BlockReason` values in the three `…Profile.swift` files.)
- [ ] Is the caught-up panel's position right, or does old content peek out above it?
- [ ] Is 48 hours the right window? (`maxAgeHours` in `instagram.js` and `x.js`.)
- [ ] Are the search page lengths right? (`maxDepth` values in the three scripts.)
- [ ] Rotating to landscape for a YouTube video: does fullscreen work, and does the top bar get in the way?
- [ ] Keyboard: when typing a comment or DM, is the text field visible above the keyboard?
- [ ] Do camera and photo-library pickers open when posting or sending a photo?

Known adjustments, with where to make them:

| Wish | Change |
| --- | --- |
| Different platform order or default | `Platform` case order in `Platform.swift`; default in `SessionStore.init` |
| Icons instead of text in the switcher | In `TopBar.swift`, replace `Text(…title)` with `Image(systemName: PlatformProfile.profile(for: platform).symbolName)` and add `.accessibilityLabel(title)`. Update `SmokeUITests`, which finds the segments by their text |
| Different accent colour | `AccentColor.colorset/Contents.json` |
| Different icon | Edit `scripts/make_icon.swift`, run `make icon` |
| Old content visible above the panel | Raise `CutoffGeometry.panelHeight` and update `CutoffGeometryTests` |

Do not add a settings screen; the spec rules it out. Values are edited in code.

---

### Task 2: Privacy audit (agent)

- [ ] **Step 1: Run the script**

```bash
make audit
```

Expected: eight `ok:` lines. A `FAIL:` line prints the offending file and line; remove the cause. Never weaken the script to make it pass. The one accepted exception: if a legitimate identifier contains a forbidden word (for example a rule named "analytics-banner"), rename the identifier.

- [ ] **Step 2: Review what the app can do**

```bash
grep -rn "evaluateJavaScript\|postMessage\|addUserScript\|WKUserScript" FocusFeed
```

Expected, and nothing else: `FilterScriptLibrary` creates the one user script; `WebViewFactory` adds it; `BrowserSession` evaluates exactly three strings — `FocusFeed.extendCutoff()`, `document.documentElement.outerHTML` and `navigator.userAgent`; `common.js` posts only `stats` and `cutoff` messages.

- [ ] **Step 3: Review the injected scripts by eye**

Read the four files in `FocusFeed/Resources/Filters/`. They must only: query the DOM, read `location`, set or remove the two `data-focusfeed-*` attributes, add one `<style>` element, click the YouTube autoplay toggle and the X Following tab, and post counters. Anything else is a defect.

- [ ] **Step 4: Check the build configuration**

```bash
grep -n "isInspectable" -B2 -A2 FocusFeed/Web/WebViewFactory.swift
grep -n "packages" project.yml
```

Expected: `isInspectable` is inside `#if DEBUG`; no `packages` in `project.yml`.

---

### Task 3: Network activity (USER)

- [ ] **Step 1:** On the phone: Settings → Privacy & Security → App Privacy Report → turn on.
- [ ] **Step 2:** Use FocusFeed normally for a day.
- [ ] **Step 3:** Open the report → App Network Activity → FocusFeed. Expected domains only: `instagram.com`, `cdninstagram.com`, `fbcdn.net`, `facebook.com`; `youtube.com`, `googlevideo.com`, `ytimg.com`, `ggpht.com`, `google.com`, `gstatic.com`, `googleapis.com`, `doubleclick.net` (YouTube's own ad and measurement calls); `x.com`, `twitter.com`, `twimg.com`, `t.co`; plus sites you opened yourself through links.
- [ ] **Step 4:** Report anything else. An unknown domain is investigated before the app is used further: it is either a site's own third party (acceptable, note it) or something our code caused (a defect).

---

### Task 4: Close the phase

- [ ] Record the review outcome, the audit result and the network report in `docs/plan/changelog.md`; set phase 7 to "done".

```bash
make test && make uitest && make audit
git add -A FocusFeed FocusFeedTests FocusFeedUITests docs/plan/changelog.md
git commit -m "docs: phase 7 complete, UX reviewed and privacy audited"
```
