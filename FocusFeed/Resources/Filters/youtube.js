FocusFeed.install({
  hide: [
    { name: "shorts-nav-tab", selector: "ytm-pivot-bar-item-renderer:has(> div.pivot-shorts)" },
    { name: "shorts-shelf", selector: "ytm-reel-shelf-renderer" },
    { name: "shorts-section", selector: "ytm-rich-section-renderer:has(ytm-reel-shelf-renderer, ytm-shorts-lockup-view-model)" },
    { name: "shorts-grid-shelf", selector: "grid-shelf-view-model:has(ytm-shorts-lockup-view-model)" },
    { name: "shorts-list-item", selector: 'ytm-video-with-context-renderer:has(a[href^="/shorts"])' },
    { name: "shorts-grid-item", selector: 'ytm-rich-item-renderer:has(a[href^="/shorts"])' },
    { name: "channel-shorts-tab", selector: 'yt-tab-shape[tab-title="Shorts"]' },
    { name: "endscreen-cards", selector: "#movie_player .ytp-ce-element" },
    { name: "endscreen-grid", selector: "#movie_player .ytp-endscreen-content" },
    { name: "endscreen-wall", selector: "#movie_player .ytp-videowall-still" },
    { name: "autoplay-countdown", selector: ".ytm-autonav-bar, .ytm-upnext-autoplay-container" },
  ],
  actions: [
    {
      name: "disable-autoplay",
      run: function () {
        const toggle = document.querySelector('button.ytm-autonav-toggle-button-container[aria-pressed="true"]');
        if (toggle) {
          toggle.click();
        }
      },
    },
  ],
  leaks: [
    { name: "shorts-link", selector: 'a[href^="/shorts"]' },
  ],
  cutoff: [
    {
      name: "home",
      applies: function (location) {
        return location.pathname === "/";
      },
      maxDepth: 6000,
    },
    {
      name: "search",
      applies: function (location) {
        return location.pathname === "/results";
      },
      maxDepth: 6000,
    },
    {
      name: "subscriptions",
      applies: function (location) {
        return location.pathname === "/feed/subscriptions";
      },
      maxDepth: 9000,
    },
  ],
});
