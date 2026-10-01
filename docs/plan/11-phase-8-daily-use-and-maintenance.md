# FocusFeed Implementation Plan — 11. Phase 8: daily use and maintenance

> **For agentic workers:** this phase is mostly Michał's. Agents help with the leak-fix loop and the weekly reinstall.

**Goal of this phase:** FocusFeed replaces the official apps, and there is a routine for keeping it working.

**Done when:** one week of daily use is complete and the leaks found in that week are fixed or recorded.

---

### Task 1: Make it the only way in (USER)

- [ ] **Step 1:** Confirm that everything you need works in FocusFeed (the three acceptance checklists).
- [ ] **Step 2:** Delete the official Instagram, YouTube and X apps from the phone.
- [ ] **Step 3:** Settings → Screen Time → Content & Privacy Restrictions → App Store, Media, Web & Games (the name varies by iOS version) → Web Content → "Limit Adult Websites" → under "Never Allow" add `instagram.com`, `youtube.com`, `x.com`, `twitter.com`.
- [ ] **Step 4:** Open FocusFeed and check all three platforms still load. Screen Time web limits can also apply to web views inside apps. If FocusFeed is blocked too, remove the four sites from "Never Allow" again and rely on step 5 instead; record this in the changelog.
- [ ] **Step 5:** Optional, for stickiness: Screen Time → iTunes & App Store Purchases → Installing Apps → Don't Allow, with a Screen Time passcode someone else holds.

---

### Task 2: One week of use (USER)

- [ ] Use only FocusFeed for seven days.
- [ ] Glance at the menu icon now and then. If it shows the warning symbol, open Filters and note which leak rule fired and on which page.
- [ ] Whenever something shows up that should not, save a DOM snapshot on that page straight away and jot down what it was. Snapshots overwrite each other per platform, so pull them (`make pull-snapshots`, phone connected) before saving the next one for the same platform, and rename the pulled file.
- [ ] At the end of the week, hand the notes to an agent session: one leak-fix loop per item.

---

### Weekly reinstall (free signing)

The app stops opening 7 days after it was built. With the phone connected and unlocked:

```bash
git status --short
make test && make audit && make device
```

Expected: tests pass, audit prints only `ok:`, the app launches on the phone. Logins and settings survive. Note the date in the changelog table "Installs".

If the phone says the app is no longer available before you got to it, nothing is lost: run the same command.

To stop doing this weekly, join the Apple Developer Program ($99/year); then it is once a year. Nothing in the project changes.

---

### Runbook

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Something that should be hidden is visible | The site changed its markup | Leak-fix loop in `3-testing-strategy.md` |
| Menu icon shows a warning | A leak rule matches | Open Filters, see which rule, same loop |
| A whole blocked section is reachable (new Reels URL, for example) | New URL shape | Router test line, then a rule in the platform's `…Profile.swift` |
| A page keeps reloading | Redirect loop that the guard only partly stops | Open Filters, note the URL; write a router test for that URL and fix the rewrite rule so it returns `nil` for its own target |
| A feed is blank or shows a spinner forever | A hide rule removed something the site's list needs | Change that rule to a `mark` rule with `collapse: true`; if it already is, remove the rule and record the gap |
| Tapping something does nothing | A JavaScript dialog, pop-up window or non-https link was dropped | Check which: pop-ups are unsupported by design; for a missing host see the next line |
| Login or a normal page opens in the Safari sheet | Host missing from `internalHosts` | Router test with `assertAllowed`, then add the host |
| Logged out unexpectedly | The site expired the session, or site data was cleared | Log in again. If it repeats daily, compare the user agent with Safari (phase 4, task 2) |
| Site says "unsupported browser" or pushes the app hard | User agent out of date after an iOS update | Phase 4, task 2 |
| App will not open | Signing expired | Weekly reinstall |
| `make device` cannot sign | Xcode account session expired, or the weekly limit of new app IDs was hit | Xcode → Settings → Accounts, sign in again. Never change the bundle ID |
| Want a clean slate for one platform | — | Delete the app from the phone and reinstall: this clears all three logins. There is no per-platform reset in the UI, by design (no settings screen) |

### After an iOS or Xcode update

```bash
make clean && make test && make uitest
```

If the simulator named "iPhone 17 Pro" no longer exists, list the available ones with `xcrun simctl list devices available` and pass another: `make test SIMULATOR="<name>"`. Then redo phase 4, task 2 (user agent) and reinstall.

---

### Not planned

Listed so nobody builds them by accident. Each needs a decision from Michał first.

- Settings screen, other platforms, sync, backend: excluded by the spec.
- Face ID lock for the app.
- Notifications. A web view app cannot receive the sites' push notifications.
- Passkey or "Sign in with Google/Apple" support.
- Auto-updating filter lists from the internet. It would mean running remote code next to logged-in sessions.
