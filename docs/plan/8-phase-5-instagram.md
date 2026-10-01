# FocusFeed Implementation Plan — 8. Phase 5: Instagram

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first.

**Goal of this phase:** Instagram shows the Following feed, stories, profiles, search and DMs; Reels feed, Explore grid, suggestions and ads are gone. A reel that someone sent in a DM can be watched without sliding into the Reels feed.

**Done when:** `make test` passes with 42 tests and the acceptance checklist passes, or every failing line is under "Known gaps" in the changelog.

## What we know about Instagram's mobile site

From open-source projects read on 2026-10-01 (`instagram-noslop`, `insta-filter`, `InnerCircle`, `quietgram`, and two iOS DM-only wrappers). None of it was checked with a login while planning. Treat every selector below as a strong first guess.

| Fact | Consequence |
| --- | --- |
| `/?variant=following` is the chronological following-only feed; Instagram's own logo menu links to it | Routing forces it (done in phase 1) |
| The Home icon is `a[href="/"]` and switches to the algorithmic feed with `pushState` | The URL observer redirects it back; the redirect guard prevents a loop |
| After login Instagram lands on `/?deoia=1` or similar | Any `/` without `variant=following` is redirected |
| `/reels/` is the feed, `/reels/<code>/` opens the swipe pager, `/reel/<code>/` is a single-post page | Pager is rewritten to the single page (phase 1) |
| A reel opened from a DM does **not** change the URL; a full-screen pager opens on top of `/direct/t/<id>/` | URL rules cannot see it. See task 6 |
| The search box lives on `/explore/`; focusing it opens `/explore/search/` | `/explore/` redirects to `/explore/search/`; the grid is hidden by script |
| Posts are `<article>` elements; the feed is virtualised and reuses article nodes | Marks are re-evaluated every tick and removed when they stop matching (the engine does this) |
| `display: none` on feed articles made the feed go blank or load forever in two projects | Feed rules use `collapse: true` (zero height) instead |
| A suggested post has a "Follow" button inside the article; followed accounts do not | Text match, English and Polish |
| Ads link to `/ads/ig_redirect` or carry `a_mpk=` in a link | Language-independent selector |
| Repeated login attempts trigger HTTP 429; background API polling got accounts flagged | Log in once, calmly. Our scripts never call Instagram's API |

---

### Task 1: Fixtures and tests first

**Files:**
- Create: `FocusFeedTests/Fixtures/instagram-feed.html`, `instagram-explore.html`, `instagram-profile.html`, `cutoff-age.html`
- Create: `FocusFeedTests/InstagramFilterTests.swift`

- [ ] **Step 1: Feed fixture**

`FocusFeedTests/Fixtures/instagram-feed.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<main role="main">
  <div>
    <article id="followed-post" data-expect="visible">
      <a href="/friend/">friend</a>
      <a href="/p/Cpost1/"><time datetime="2020-01-01T10:00:00.000Z">1h</time></a>
      <div role="button">Like</div>
    </article>
    <article id="feed-reel" data-expect="hidden">
      <a href="/friend/reel/Creel1/"><time datetime="2020-01-01T09:00:00.000Z">2h</time></a>
    </article>
    <article id="sponsored-post" data-expect="hidden">
      <a href="https://www.facebook.com/ads/ig_redirect/?d=abc">Shop now</a>
    </article>
    <article id="suggested-post" data-expect="hidden">
      <a href="/stranger/">stranger</a>
      <div role="button">Follow</div>
      <a href="/p/Cpost2/">post</a>
    </article>
    <div id="suggested-accounts" data-expect="hidden">
      <div><a href="/explore/people/">See all</a></div>
      <div>carousel</div>
    </div>
  </div>
</main>
<div>
  <a id="nav-home" href="/" data-expect="visible">Home</a>
  <a id="nav-explore" href="/explore/" data-expect="visible">Search</a>
  <a id="nav-reels" href="/reels/" data-expect="hidden">Reels</a>
  <a id="nav-inbox" href="/direct/inbox/" data-expect="visible">Messages</a>
  <a id="open-app" href="instagram://user?username=friend" data-expect="hidden">Open app</a>
</div>
</body>
</html>
```

- [ ] **Step 2: Explore fixture**

`FocusFeedTests/Fixtures/instagram-explore.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<main role="main">
  <div>
    <div><input id="search-box" type="search" data-expect="visible"></div>
    <div>
      <a id="grid-post" href="/p/Cgrid1/" data-expect="hidden">grid post</a>
      <a id="grid-reel" href="/someone/reel/Cgrid2/" data-expect="hidden">grid reel</a>
    </div>
  </div>
</main>
</body>
</html>
```

- [ ] **Step 3: Profile fixture**

This one guards against over-matching: on a profile, a "Follow" button and reel links are legitimate.

`FocusFeedTests/Fixtures/instagram-profile.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<main role="main">
  <div role="button" id="follow-button" data-expect="visible">Follow</div>
  <a id="profile-post" href="/p/Cprofile1/" data-expect="visible">post</a>
  <a id="profile-reel" href="/friend/reel/Cprofile2/" data-expect="visible">reel</a>
  <article id="profile-article" data-expect="visible">
    <div role="button">Follow</div>
    <a href="/friend/reel/Cprofile3/">reel</a>
  </article>
</main>
</body>
</html>
```

- [ ] **Step 4: Age cutoff fixture**

Seven 500 px articles: new, old, new, then four old. A single old post must not trigger the cutoff; the run of three starting at the fourth article (Y = 1500) must.

`FocusFeedTests/Fixtures/cutoff-age.html`

```html
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body { margin: 0; } article { display: block; height: 500px; }</style>
</head>
<body>
<main>
  <article><time datetime="2999-01-01T00:00:00.000Z">new</time></article>
  <article><time datetime="2000-01-01T00:00:00.000Z">old, but alone</time></article>
  <article><time datetime="2999-01-01T00:00:00.000Z">new</time></article>
  <article><time datetime="2000-01-01T00:00:00.000Z">old 1</time></article>
  <article><time datetime="2000-01-01T00:00:00.000Z">old 2</time></article>
  <article><time datetime="2000-01-01T00:00:00.000Z">old 3</time></article>
  <article><time datetime="2000-01-01T00:00:00.000Z">old 4</time></article>
</main>
</body>
</html>
```

- [ ] **Step 5: Tests**

`FocusFeedTests/InstagramFilterTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class InstagramFilterTests: FilterFixtureTestCase {
    func testFeedHidesReelsAdsAndSuggestions() async throws {
        try await assertFixture("instagram-feed", profile: .instagram, path: "/?variant=following")
    }

    func testExploreLandingHidesGridButKeepsSearchBox() async throws {
        try await assertFixture("instagram-explore", profile: .instagram, path: "/explore/search/")
    }

    func testProfileContentIsUntouched() async throws {
        try await assertFixture("instagram-profile", profile: .instagram, path: "/friend/")
    }

    func testFeedCutoffStartsAtFirstRunOfOldPosts() async throws {
        let webView = try await loadFixture("cutoff-age", profile: .instagram, path: "/?variant=following")
        let cutoff = try await cutoffY(in: webView)
        XCTAssertEqual(cutoff, 1500)
    }
}
```

- [ ] **Step 6: Run and confirm failure**

```bash
make test
```

Expected: `** TEST FAILED **`; the three fixture tests fail on elements such as `#feed-reel in instagram-feed.html`, and the cutoff test fails with `XCTAssertEqual failed: ("nil") is not equal to ("Optional(1500.0)")`. `testProfileContentIsUntouched` passes already.

---

### Task 2: The Instagram filter script

**Files:**
- Replace: `FocusFeed/Resources/Filters/instagram.js`

- [ ] **Step 1: Replace the placeholder**

The Explore link in the bottom bar is deliberately not hidden: it is the way to search.

`FocusFeed/Resources/Filters/instagram.js`

```javascript
(function () {
  const FOLLOW_LABEL = /^(Follow|Follow back|Obserwuj|Również obserwuj)$/;

  function onHomeFeed() {
    return window.location.pathname === "/";
  }

  function onExploreLanding() {
    return /^\/explore(\/search)?\/?$/.test(window.location.pathname);
  }

  function feedArticlesContaining(selector) {
    return onHomeFeed() ? FocusFeed.containersOf(`article ${selector}`, "article") : [];
  }

  function suggestedArticles() {
    if (!onHomeFeed()) {
      return [];
    }
    return FocusFeed.withText('article [role="button"]', FOLLOW_LABEL).map((button) => button.closest("article"));
  }

  function exploreGridLinks() {
    return onExploreLanding() ? Array.from(document.querySelectorAll('main a[href^="/p/"], main a[href*="/reel/"]')) : [];
  }

  FocusFeed.install({
    hide: [
      { name: "reels-nav-link", selector: 'a[href="/reels/"]' },
      { name: "open-app-link", selector: 'a[href^="instagram:"]' },
      { name: "suggested-accounts", selector: 'div:has(> div:first-child > a[href^="/explore/people"])' },
    ],
    mark: [
      {
        name: "feed-reel",
        collapse: true,
        find: function () {
          return feedArticlesContaining('a[href*="/reel/"]');
        },
      },
      {
        name: "sponsored-post",
        collapse: true,
        find: function () {
          return feedArticlesContaining('a[href*="/ads/ig_redirect"], a[href*="a_mpk="]');
        },
      },
      { name: "suggested-post", collapse: true, find: suggestedArticles },
      { name: "explore-grid", find: exploreGridLinks },
    ],
    leaks: [
      { name: "reels-link", selector: 'a[href="/reels/"]' },
      { name: "suggested-accounts-link", selector: 'a[href^="/explore/people"]' },
    ],
    cutoff: [
      { name: "following-feed", applies: onHomeFeed, items: "article", maxAgeHours: 48 },
      {
        name: "search-results",
        applies: function (location) {
          return /^\/explore\/(search\/keyword|tags|locations)\//.test(location.pathname);
        },
        maxDepth: 5000,
      },
    ],
  });
})();
```

- [ ] **Step 2: Run and confirm success**

```bash
make test
```

Expected: `Executed 42 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
make audit
git add FocusFeed/Resources/Filters/instagram.js FocusFeedTests
git commit -m "feat: Instagram filters with fixture tests"
```

---

### Task 3: Install and log in (USER)

- [ ] **Step 1:** `make device` with the phone connected.
- [ ] **Step 2 (USER):** Select Instagram. Decline optional cookies if asked. Log in with username and password, then the 2FA code. Not "Log in with Facebook" unless that is the only way the account can log in. Choose "Save login info" if asked.
- [ ] **Step 3 (USER):** If Instagram asks to confirm the login from another device or by e-mail, do that; it is a new browser from its point of view.
- [ ] **Step 4 (USER):** Force-quit and reopen. Still logged in.

If the login page shows an error or a blank page, wait ten minutes before trying again; do not retry in a loop. If "Log in with Facebook" is needed and it bounces to the Safari sheet, note the host and add it to `internalHosts` in `InstagramProfile.swift` with a router test first, as described in phase 4, task 1.

---

### Task 4: Check routing on the real site (USER)

Report the result of each line.

- [ ] After login the feed shows only accounts you follow, newest first. Menu → Filters footer shows a URL containing `variant=following`.
- [ ] Tap the Home icon in Instagram's bottom bar. The page may reload once; it must end on the following feed again, not flip endlessly.
- [ ] Tap the search (magnifier) icon. You land on a search page with a search box and **no** grid of posts. Typing a name shows accounts; opening one works.
- [ ] There is no Reels icon in the bottom bar.
- [ ] Open a friend's profile, tap one of their reels. It opens and plays as a single post or single reel. Swiping up does not bring a stranger's reel.

If the Home icon makes the page flip more than once, or the feed is the algorithmic one: save a snapshot on the feed, pull it, and report the URL in the Filters footer. The fix depends on what Instagram does to the URL; do not guess. Record it as a known gap and ask Michał.

---

### Task 5: Check the filters against the real DOM (USER + agent)

- [ ] **Step 1 (USER):** On the following feed, scroll a few screens, open Filters, report the numbers, save a snapshot. Do the same on the search page.
- [ ] **Step 2:** Pull and inspect. Print counts only, never post content:

```bash
make pull-snapshots
grep -c "<article" snapshots/instagram.html
grep -c "<time " snapshots/instagram.html
grep -oE 'time[^>]*datetime="[^"]*"' snapshots/instagram.html | head -3
grep -oE 'href="/(reels|explore)[^"]*"' snapshots/instagram.html | sort | uniq -c
grep -oE 'role="button"[^>]*>[^<]{1,20}<' snapshots/instagram.html | sort | uniq -c | sort -rn | head -15
```

What to conclude:

| Observation | Action |
| --- | --- |
| Articles exist and each has a `time` with `datetime` | Age cutoff works. Nothing to do |
| Articles exist but no `time[datetime]` | The 48 h cutoff cannot work. Change the `following-feed` policy in `instagram.js` to a depth cutoff: replace `items: "article", maxAgeHours: 48` with `maxDepth: 12000`. Change `testFeedCutoffStartsAtFirstRunOfOldPosts` in `InstagramFilterTests.swift` to load fixture `cutoff-depth` and expect `12000`. Record in the changelog |
| No `<article>` at all | Instagram changed its feed markup. Find the repeating post container in the snapshot and run the leak-fix loop for each feed rule |
| A link `href="/reels/"` exists and Filters shows `reels-link` leaking | The nav link is not hidden: check its exact `href` in the grep output and fix the `reels-nav-link` selector |
| The search page grid is visible | In the search-page snapshot, find what the grid links look like (`grep -oE 'href="/[^"]{1,40}"' … | sort | uniq -c`) and adjust `exploreGridLinks` in `instagram.js`, fixture first |
| Suggested posts or "Suggested for you" visible in the feed | Leak-fix loop. Check the button text in the last grep: the phone is in Polish, so the label may differ from `Obserwuj` |

- [ ] **Step 3 (USER):** If hiding the Reels link left an empty slot in the bottom bar and it bothers you, say so. The fix is a `mark` rule that hides the link's parent cell; it needs the snapshot to see the nesting.

- [ ] **Step 4:** Commit any rule changes with their fixtures.

---

### Task 6: Reels sent in a DM (USER + agent)

Requirement from Michał: "I want to be able to see reels sent in DM. If this is not possible, skip. I just want to see what was sent to me, not scroll through."

- [ ] **Step 1 (USER):** Open a DM thread that contains a reel. Tap it. Report which of these happens:

| What happens | Meaning | Next |
| --- | --- | --- |
| A. The reel plays; swiping up or down does nothing or closes it | Requirement met | Done. Record "DM reels: OK" |
| B. The reel plays in a full-screen viewer and swiping up shows other reels | The DM pager is an endless feed | Step 2 |
| C. The "Reels are off" card appears | The tap navigated to `/reels/…` with something after the code | Step 3 |
| D. Nothing plays, or "open in app" appears | Instagram does not serve this on mobile web | Skip. Record "DM reels: not available on mobile web" |

- [ ] **Step 2 (case B): try once to lock the pager.** While the reel viewer is open, save a snapshot (menu → Filters → Save DOM snapshot), pull it, and look at what wraps the videos:

```bash
grep -o '<video' snapshots/instagram.html | wc -l
grep -oE '.{300}<video' snapshots/instagram.html | head -2
```

If there are two or more `<video>` elements, each sits in a repeated container. Find the nearest ancestor that repeats once per reel and has a stable hook (`role`, `aria-label`, a `data-` attribute, or a tag such as `section` or `article`). Then add a mark rule to `instagram.js` that hides every such container after the first while a DM thread is open, with a fixture and test first. The shape, with `SELECTOR` replaced by what the snapshot shows:

```javascript
function extraDirectReels() {
  if (!window.location.pathname.startsWith("/direct/")) {
    return [];
  }
  return Array.from(document.querySelectorAll("SELECTOR")).slice(1);
}
```

and in the `mark` list: `{ name: "dm-next-reel", find: extraDirectReels },`

Retest on the phone. If one attempt does not produce a stable, working rule, stop: revert the change, and record "DM reels play, but the viewer can swipe to other reels" under Known gaps. Michał's instruction is to skip rather than fight it.

- [ ] **Step 3 (case C):** Open Filters right after the card appears and report the URL in the footer. Add that URL shape to `InstagramRouterTests.testReelPagerIsRewrittenToSingleReel` as an `assertRedirect` to `/reel/<code>/`, see it fail, extend the regular expression in `reelPagerToSingleReel` in `InstagramProfile.swift`, see it pass, `make device`.

---

### Task 7: Acceptance checklist (USER)

Keep — each must work:

- [ ] Following feed, newest first
- [ ] Stories of followed accounts open and advance (if the following feed shows no stories row, open stories from a profile picture; record this as expected behaviour)
- [ ] Profiles: posts grid, a single post, followers list
- [ ] Search for an account and for a hashtag
- [ ] DMs: inbox, read a thread, send a message, send a photo
- [ ] Like, comment, save a post
- [ ] Create a post from the phone's photo library
- [ ] Notifications (heart icon) open
- [ ] A reel sent in a DM: result from task 6

Remove — each must be gone:

- [ ] No Reels button; typing or tapping a link to `/reels/` shows the "Reels are off" card
- [ ] No reels inside the following feed
- [ ] No Explore grid
- [ ] No "Suggested for you" posts or account carousels, no ads
- [ ] Videos do not start by themselves
- [ ] After posts older than 48 hours start, the "You're caught up" panel appears and scrolling stops
- [ ] Hashtag and keyword search results stop after one page
- [ ] Filters sheet shows 0 leaking on the feed, a profile and the search page

---

### Task 8: Close the phase

- [ ] Record results, date and known gaps in `docs/plan/changelog.md`; set phase 5 to "done".

```bash
make test && make audit
git add -A FocusFeed FocusFeedTests docs/plan/changelog.md
git commit -m "docs: phase 5 complete, Instagram verified on device"
```
