# FocusFeed Implementation Plan — 7. Phase 4: YouTube on the phone

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first. Most of this phase is verification with Michał; code changes happen only through the leak-fix loop in `3-testing-strategy.md`.

**Goal of this phase:** YouTube is usable daily on the phone, logged in, and every row of the spec's YouTube keep/remove list holds.

**Done when:** the acceptance checklist at the end passes, or every failing line is recorded under "Known gaps" in the changelog with a decision.

The YouTube code already exists from phases 1–3 and was checked against the live site logged out. What is still unknown: Google login inside the web view, the subscriptions feed, the autoplay toggle, and the "You"/library pages.

---

### Task 1: Log in (USER)

- [ ] **Step 1:** Open FocusFeed on the phone, select YouTube. Accept or reject the cookie dialog. Tap "Sign in".
- [ ] **Step 2:** Enter the Google account e-mail and password, then the 2FA code. If Google offers a passkey, choose "Try another way" and use the password; passkeys do not work in this kind of app.
- [ ] **Step 3:** Confirm that you land back on YouTube, logged in, on the Subscriptions feed.
- [ ] **Step 4:** Force-quit FocusFeed, reopen it. You must still be logged in.

If Google shows "Couldn't sign you in — this browser or app may not be secure":

1. Do Task 2 first (the user agent may be off), reinstall, try once more.
2. If it still fails, stop. Record it in the changelog as a blocker and tell Michał. Do not try workarounds such as copying cookies from another browser; that is exactly the kind of credential handling this app exists to avoid. The app is still useful for YouTube logged out (search and watch, no subscriptions).

If login keeps bouncing to the Safari sheet instead of staying in the app, a Google host is missing from `internalHosts`: note the host shown in the sheet's address bar, add a router test line `assertAllowed("https://<that host>/…")` to `YouTubeRouterTests.testKeptPagesAreAllowed`, see it fail, add the host to `internalHosts` in `FocusFeed/Platforms/YouTubeProfile.swift`, see it pass, `make device`.

---

### Task 2: Match Safari's user agent exactly

**Files:**
- Modify: `FocusFeed/Web/WebViewFactory.swift` (the `safariUserAgentSuffix` constant)

- [ ] **Step 1 (USER):** On the phone, open Safari and visit any "what is my user agent" page. Note the part after `(KHTML, like Gecko) `, for example `Version/26.6 Mobile/15E148 Safari/604.1`.
- [ ] **Step 2:** If it differs from `Version/26.0 Mobile/15E148 Safari/604.1`, change the constant to the exact value from Safari:

```swift
static let safariUserAgentSuffix = "Version/26.6 Mobile/15E148 Safari/604.1"
```

- [ ] **Step 3:** `make test`, expect `** TEST SUCCEEDED **`. Commit:

```bash
git add FocusFeed/Web/WebViewFactory.swift
git commit -m "fix: match Safari user agent version"
```

Repeat this task after major iOS updates.

---

### Task 3: Logged-out probes (agent)

Run the four probes from phase 3, task 7, steps 2–4 again and add a channel page:

```bash
./scripts/live_probe.sh youtube "https://m.youtube.com/@NASA" 12
./scripts/live_probe.sh youtube "https://m.youtube.com/@NASA/shorts" 8
```

Expected: first probe, both leaks 0; if the channel home shows a Shorts shelf in the screenshot, one of the `shorts-*` hidden counters is above 0. Second probe: the screenshot shows the "Shorts are off" card.

If a leak counter is above 0, run the leak-fix loop using `build/probe/youtube.html` as the snapshot.

---

### Task 4: Subscriptions feed and library (USER + agent)

- [ ] **Step 1 (USER):** On the Subscriptions feed, open menu → Filters. Report the "Leaking" and "Hidden" numbers. Save a DOM snapshot.
- [ ] **Step 2:** `make pull-snapshots`, then check the structure:

```bash
grep -oE "<(ytm|yt|grid)[a-z0-9-]*" snapshots/youtube.html | sort | uniq -c | sort -rn | head -30
grep -c 'href="/shorts' snapshots/youtube.html
```

If the second number is above 0 while the Filters sheet showed `shorts-link` leaking above 0, run the leak-fix loop. If Shorts links exist but leaks are 0, they are already hidden; nothing to do.

- [ ] **Step 3 (USER):** Scroll the Subscriptions feed. The "That's one page" panel must appear after roughly ten screens. If that feels too long or too short, change `maxDepth: 9000` for `subscriptions` in `FocusFeed/Resources/Filters/youtube.js` (pixels; one phone screen is about 800). There is no test tied to that number.
- [ ] **Step 4 (USER):** Tap the bottom-bar items. Expected: no Shorts button; Home, Subscriptions and "You" work. Open History and a playlist from "You".

---

### Task 5: Autoplay (USER)

- [ ] **Step 1:** Open a short video (under a minute) from a subscription and let it play to the end.
- [ ] **Step 2:** Expected: nothing else starts. No end-screen grid, no countdown to a next video. Related videos under the player are fine, but none of them is a Short.

If a next video starts by itself:

1. Check whether the autoplay switch in the player controls is on (tap the video once to see the controls). Save a DOM snapshot while the controls are visible, pull it, and look for the toggle:

```bash
grep -o '.\{200\}autonav.\{300\}' snapshots/youtube.html | head -5
```

2. If the button exists with a different element or attribute than `button.ytm-autonav-toggle-button-container[aria-pressed="true"]`, update the selector in the `disable-autoplay` action in `youtube.js`, `make device`, retest.
3. If there is no reliable hook, fall back to the account setting, once (USER): in YouTube tap the profile picture → Settings → Playback (or "Autoplay") → turn "Autoplay next video" off. Record in the changelog which of the two is in effect.

---

### Task 6: Acceptance checklist (USER)

Keep — each must work:

- [ ] Subscriptions feed shows videos from subscribed channels
- [ ] Opening a video plays it; fullscreen and rotation work; quality and speed menus work
- [ ] Search returns results; opening a result works
- [ ] Channel page: Videos and Playlists tabs work; subscribing and unsubscribing work
- [ ] Like, comment, reply work
- [ ] Home tab shows recommended full videos and stops after one page with the "Show one more page" panel
- [ ] Related videos under a video are shown and none of them is a Short
- [ ] Playlists and Watch Later open and play
- [ ] A YouTube link tapped inside X or Instagram opens in the YouTube tab (retest after phases 5 and 6)

Remove — each must be gone:

- [ ] No Shorts shelf in Subscriptions, search, or channel pages
- [ ] No Shorts button in the bottom bar
- [ ] Typing `youtube.com/shorts` style links: a single short opens as a normal video; no swipe-to-next
- [ ] No Shorts in Home or in related videos
- [ ] No end-screen suggestions when a video ends
- [ ] No autoplay of a next video
- [ ] Search results stop after one page with the "Show one more page" panel
- [ ] Filters sheet shows 0 leaking on Home, Subscriptions, search and a watch page

---

### Task 7: Close the phase

- [ ] Record the checklist result, the date, and any known gaps in `docs/plan/changelog.md`; set phase 4 to "done".

```bash
make test && make audit
git add -A FocusFeed FocusFeedTests docs/plan/changelog.md
git commit -m "docs: phase 4 complete, YouTube verified on device"
```
