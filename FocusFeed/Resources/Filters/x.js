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
