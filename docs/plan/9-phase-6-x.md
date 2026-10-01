# FocusFeed Implementation Plan — 9. Phase 6: X

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first.

**Goal of this phase:** X shows the Following timeline, profiles, search, lists, DMs and notifications; "For you", trends, "Who to follow", promoted posts and recommended posts under replies are gone.

**Done when:** `make test` passes with 45 tests and the acceptance checklist passes, or every failing line is under "Known gaps" in the changelog.

## What we know about X's mobile site

From the source of the open-source extension "Control Panel for Twitter" (version 4.24.3, 2026-09-27), which supports mobile. Not checked with a login while planning.

| Fact | Consequence |
| --- | --- |
| Home tabs are in `div[data-testid="TopNavBar"]`, inside `div[role="tablist"]`; first child is "For you", second is "Following" | An action clicks Following when For you is selected; a mark rule hides the For you tab on `/home` only |
| There is no URL or setting that opens Following directly | The click is the only way; it reruns whenever X re-renders the tabs |
| Timeline items are `[data-testid="cellInnerDiv"]`; posts are `article[data-testid="tweet"]`; time is `time[datetime]` | Used for hide rules and the 48 h cutoff |
| A promoted post is a tweet inside `[data-testid="placementTracking"]`. A video player inside a normal tweet also uses `placementTracking`, the other way round | The selector requires the tweet to be *inside* the tracking element |
| "Discover more" under replies is a heading cell whose `h2[role="heading"]` is followed by a `div` with a `dir` attribute; everything after it is recommended | Mark rule hides that cell and all cells after it |
| The search box is on `/explore`; results are at `/search` | `/explore` stays allowed; its timeline is hidden by script |
| Tapping a video opens `/<user>/status/<id>/mediaviewer`, a vertical pager of more videos; items are `[data-testid^="immersive-tweet-ui-content-container"]` | Mark rule hides every item after the first. Least certain rule in this file |
| Messages are at `/messages` and, newer, `/i/chat` | Both allowed |
| Route changes do not always fire events | The engine does not rely on events; it re-evaluates on every DOM mutation |

---

### Task 1: Fixtures and tests first

**Files:**
- Create: `FocusFeedTests/Fixtures/x-home.html`, `x-status.html`, `x-explore.html`
- Create: `FocusFeedTests/XFilterTests.swift`

- [ ] **Step 1: Home fixture**

Note the two `placementTracking` cases: `#video-tweet-cell` must stay, `#promoted-cell` must go.

`FocusFeedTests/Fixtures/x-home.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<div data-testid="TopNavBar">
  <nav>
    <div role="tablist">
      <div id="for-you-tab" data-expect="hidden"><a role="tab" aria-selected="true" href="/home">For you</a></div>
      <div id="following-tab" data-expect="visible"><a role="tab" aria-selected="false" href="/home">Following</a></div>
    </div>
  </nav>
</div>
<div data-testid="primaryColumn">
  <section>
    <h1>Your Home Timeline</h1>
    <div aria-label="Timeline: Your Home Timeline">
      <div>
        <div id="tweet-cell" data-testid="cellInnerDiv" data-expect="visible">
          <article data-testid="tweet"><a href="/friend/status/1"><time datetime="2020-01-01T10:00:00.000Z">1h</time></a></article>
        </div>
        <div id="video-tweet-cell" data-testid="cellInnerDiv" data-expect="visible">
          <article data-testid="tweet"><div data-testid="placementTracking"><div data-testid="videoPlayer">video</div></div></article>
        </div>
        <div id="promoted-cell" data-testid="cellInnerDiv" data-expect="hidden">
          <div data-testid="placementTracking"><article data-testid="tweet">Ad</article></div>
        </div>
        <div id="who-to-follow-cell" data-testid="cellInnerDiv" data-expect="hidden">
          <button data-testid="UserCell">Someone</button>
        </div>
        <div id="show-more-cell" data-testid="cellInnerDiv" data-expect="hidden">
          <a href="/i/connect_people?user_id=1">Show more</a>
        </div>
        <div id="trend-cell" data-testid="cellInnerDiv" data-expect="hidden">
          <div data-testid="trend">Trending</div>
        </div>
      </div>
    </div>
  </section>
</div>
<div id="layers">
  <nav>
    <a id="nav-home" data-testid="AppTabBar_Home_Link" href="/home" data-expect="visible">Home</a>
    <a id="nav-explore" href="/explore" data-expect="visible">Search</a>
    <a id="nav-grok" href="/i/grok" data-expect="hidden">Grok</a>
    <a id="nav-communities" href="/me/communities" data-expect="hidden">Communities</a>
    <a id="nav-notifications" href="/notifications" data-expect="visible">Notifications</a>
    <a id="nav-chat" href="/i/chat" data-expect="visible">Chat</a>
  </nav>
</div>
</body>
</html>
```

- [ ] **Step 2: Post detail fixture**

`FocusFeedTests/Fixtures/x-status.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<div data-testid="primaryColumn">
  <section>
    <div>
      <div id="focused-tweet" data-testid="cellInnerDiv" data-expect="visible"><article data-testid="tweet">The post</article></div>
      <div id="reply" data-testid="cellInnerDiv" data-expect="visible"><article data-testid="tweet">A reply</article></div>
      <div id="discover-heading" data-testid="cellInnerDiv" data-expect="hidden">
        <div><h2 role="heading">Discover more</h2><div dir="ltr">Sourced from across X</div></div>
      </div>
      <div id="recommended-tweet" data-testid="cellInnerDiv" data-expect="hidden"><article data-testid="tweet">Recommended</article></div>
    </div>
  </section>
</div>
</body>
</html>
```

- [ ] **Step 3: Explore fixture**

`FocusFeedTests/Fixtures/x-explore.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<div data-testid="TopNavBar">
  <input id="search-input" data-testid="SearchBox_Search_Input" data-expect="visible">
</div>
<div data-testid="primaryColumn">
  <section id="explore-timeline" data-expect="hidden">
    <div data-testid="cellInnerDiv"><article data-testid="tweet">Trending post</article></div>
  </section>
</div>
</body>
</html>
```

- [ ] **Step 4: Tests**

`FocusFeedTests/XFilterTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class XFilterTests: FilterFixtureTestCase {
    func testHomeHidesRecommendationsAndForYouTab() async throws {
        try await assertFixture("x-home", profile: .x, path: "/home")
    }

    func testStatusPageCutsDiscoverMore() async throws {
        try await assertFixture("x-status", profile: .x, path: "/friend/status/123")
    }

    func testExploreKeepsSearchBoxOnly() async throws {
        try await assertFixture("x-explore", profile: .x, path: "/explore")
    }
}
```

- [ ] **Step 5: Run and confirm failure**

```bash
make test
```

Expected: `** TEST FAILED **`; all three X tests fail, for example on `#for-you-tab in x-home.html`.

---

### Task 2: The X filter script

**Files:**
- Replace: `FocusFeed/Resources/Filters/x.js`

- [ ] **Step 1: Replace the placeholder**

`FocusFeed/Resources/Filters/x.js`

```javascript
(function () {
  const CELL = '[data-testid="cellInnerDiv"]';
  const HOME_TABS = 'div[data-testid="TopNavBar"] div[role="tablist"]';

  function path() {
    return window.location.pathname;
  }

  function onHome() {
    return path() === "/home";
  }

  function onStatus() {
    return /^\/[^/]+\/status\/\d+$/.test(path());
  }

  function forYouTab() {
    return onHome() ? Array.from(document.querySelectorAll(`${HOME_TABS} > div:first-child`)) : [];
  }

  function followSuggestions() {
    if (!onHome() && !onStatus()) {
      return [];
    }
    return Array.from(document.querySelectorAll(`${CELL}:has([data-testid="UserCell"]), ${CELL}:has(a[href^="/i/connect_people"])`));
  }

  function isDiscoverHeading(cell) {
    const heading = cell.querySelector('h2[role="heading"]');
    const next = heading && heading.nextElementSibling;
    return Boolean(next && next.tagName === "DIV" && next.hasAttribute("dir"));
  }

  function discoverMore() {
    if (!onStatus()) {
      return [];
    }
    const cells = Array.from(document.querySelectorAll(CELL));
    const start = cells.findIndex(isDiscoverHeading);
    return start === -1 ? [] : cells.slice(start);
  }

  function exploreTimeline() {
    return path().startsWith("/explore") ? Array.from(document.querySelectorAll('[data-testid="primaryColumn"] section')) : [];
  }

  function extraViewerVideos() {
    if (!path().endsWith("/mediaviewer")) {
      return [];
    }
    return Array.from(document.querySelectorAll('[data-testid^="immersive-tweet-ui-content-container"]')).slice(1);
  }

  function selectFollowingTab() {
    if (!onHome()) {
      return;
    }
    const forYouSelected = document.querySelector(`${HOME_TABS} > div:first-child > [role="tab"][aria-selected="true"]`);
    const following = document.querySelector(`${HOME_TABS} > div:nth-child(2) > [role="tab"]`);
    if (forYouSelected && following) {
      following.click();
    }
  }

  FocusFeed.install({
    hide: [
      { name: "grok-nav-link", selector: 'a[href="/i/grok"]' },
      { name: "premium-upsell", selector: 'a[href^="/i/premium"], [data-testid$="_upsell"], [data-testid="inlinePrompt"]' },
      { name: "jobs-nav-link", selector: 'a[href="/jobs"]' },
      { name: "communities-nav-link", selector: 'a[href$="/communities"]' },
      { name: "trend", selector: `${CELL}:has([data-testid="trend"])` },
      { name: "event-hero", selector: '[data-testid="eventHero"]' },
      { name: "promoted-post", selector: `${CELL}:has([data-testid="placementTracking"] [data-testid="tweet"])` },
    ],
    mark: [
      { name: "for-you-tab", find: forYouTab },
      { name: "who-to-follow", find: followSuggestions },
      { name: "discover-more", find: discoverMore },
      { name: "explore-timeline", find: exploreTimeline },
      { name: "viewer-next-video", find: extraViewerVideos },
    ],
    actions: [{ name: "select-following", run: selectFollowingTab }],
    leaks: [
      { name: "trend", selector: '[data-testid="trend"]' },
      { name: "grok-link", selector: 'a[href="/i/grok"]' },
      { name: "promoted-post", selector: '[data-testid="placementTracking"] [data-testid="tweet"]' },
    ],
    cutoff: [
      { name: "following-timeline", applies: onHome, items: 'article[data-testid="tweet"]', maxAgeHours: 48 },
      {
        name: "search-results",
        applies: function (location) {
          return location.pathname === "/search";
        },
        maxDepth: 8000,
      },
    ],
  });
})();
```

- [ ] **Step 2: Run and confirm success**

```bash
make test
```

Expected: `Executed 45 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
make audit
git add FocusFeed/Resources/Filters/x.js FocusFeedTests
git commit -m "feat: X filters with fixture tests"
```

---

### Task 3: Install and log in (USER)

- [ ] **Step 1:** `make device` with the phone connected.
- [ ] **Step 2 (USER):** Select X. Log in with username and password, then the 2FA code. Do not use "Sign in with Google" or "Sign in with Apple": they open a pop-up window, which this app does not have. If the account only has those, set a password on x.com in Safari first.
- [ ] **Step 3 (USER):** Solve the puzzle captcha if one appears. Force-quit, reopen, still logged in.

---

### Task 4: Check against the real site (USER + agent)

- [ ] **Step 1 (USER):** Report each line.

  - Home opens on **Following**; the "For you" tab is not visible.
  - Scrolling Home shows no "Who to follow", no ads, no trends.
  - Tap the search icon: a search box, and no trending list under it. Type a query: suggestions appear, results open, the Top/Latest/People tabs are all there.
  - Open a post with replies and scroll to the end: replies end, no "Discover more".
  - Tap a video in a post: it plays. Swiping up does not bring another video.
  - No Grok, Communities, Jobs or Premium entries in the bottom bar or side menu (profile picture, top left). Blocked items that are still listed in the side menu show the "Not part of FocusFeed" card when tapped; that is acceptable.

- [ ] **Step 2 (USER):** For every line that fails, go to that page, open Filters, note the numbers, save a snapshot. One snapshot at a time: save, tell the agent, wait for `make pull-snapshots`, then the next.

- [ ] **Step 3:** For each failing line run the leak-fix loop. Starting points:

```bash
grep -oE 'data-testid="[^"]*"' snapshots/x.html | sort | uniq -c | sort -rn | head -50
grep -oE 'role="tab"[^>]*' snapshots/x.html | head
grep -oE 'href="/i/[^"]*"' snapshots/x.html | sort | uniq -c
```

| Failing line | Where to look |
| --- | --- |
| Home opens on For you, tab still visible | The `HOME_TABS` selector in `x.js`. Check with the second grep how tabs are nested; the fixture `x-home.html` must be changed to the real nesting first |
| Home flips between tabs or the Following tab cannot be left | The click action is firing on the wrong page: confirm `aria-selected` exists on the tab in the snapshot |
| Search suggestions or the search box are hidden on `/explore` | `exploreTimeline` hides too much. Narrow it to the element that holds the trends, fixture first |
| Trends still visible on `/explore` | Same function hides too little; look for `data-testid="trend"` and its section |
| "Who to follow" on profiles | Add a mark rule for profile paths using `aside[role="complementary"]`, fixture first |
| Video viewer swipes to other videos | Check the first grep for `immersive` test IDs. If the IDs differ, update `extraViewerVideos`. If there is no stable hook, record as known gap |
| A legitimate user list (followers, search → People) is empty | `followSuggestions` must only run on Home and post pages; check `onHome`/`onStatus` against the page's path |

- [ ] **Step 4:** Commit rule changes with their fixtures.

---

### Task 5: Acceptance checklist (USER)

Keep — each must work:

- [ ] Following timeline, newest first
- [ ] Profiles, a single post with its replies
- [ ] Search, including Latest and People
- [ ] Lists
- [ ] DMs: inbox, read, send
- [ ] Notifications
- [ ] Like, repost, reply, bookmark, write a post
- [ ] An external link in a post opens in the Safari sheet; a YouTube link opens in the YouTube tab with its filters

Remove — each must be gone:

- [ ] No "For you"
- [ ] No Explore/Trending content
- [ ] No "Who to follow"
- [ ] No recommended posts under replies
- [ ] No promoted posts
- [ ] Videos do not start by themselves
- [ ] After three posts in a row older than 48 hours, the "You're caught up" panel appears and scrolling stops
- [ ] Search results stop after one page
- [ ] Filters sheet shows 0 leaking on Home, a post page and a profile

---

### Task 6: Close the phase

- [ ] Record results, date and known gaps in `docs/plan/changelog.md`; set phase 6 to "done".

```bash
make test && make audit
git add -A FocusFeed FocusFeedTests docs/plan/changelog.md
git commit -m "docs: phase 6 complete, X verified on device"
```
