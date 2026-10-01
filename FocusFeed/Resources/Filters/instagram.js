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
