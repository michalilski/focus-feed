(function () {
  "use strict";
  if (window.FocusFeed) {
    return;
  }

  const HIDE_ATTRIBUTE = "data-focusfeed-hidden";
  const COLLAPSE_ATTRIBUTE = "data-focusfeed-collapsed";
  const STYLE_ID = "focusfeed-style";
  const TICK_DELAY_MS = 150;
  const OLD_RUN_LENGTH = 3;
  const COLLAPSE_STYLE =
    "height: 0 !important; min-height: 0 !important; margin: 0 !important; padding: 0 !important; " +
    "border: 0 !important; overflow: hidden !important; visibility: hidden !important;";

  class FilterEngine {
    constructor() {
      this.hideRules = [];
      this.markRules = [];
      this.actions = [];
      this.leakRules = [];
      this.cutoffPolicies = [];
      this.timer = null;
      this.lastStats = "";
      this.lastCutoff = "";
      this.cutoffKey = null;
      this.cutoffY = null;
      this.cutoffExtensions = 0;
    }

    install(config) {
      this.hideRules = config.hide || [];
      this.markRules = config.mark || [];
      this.actions = config.actions || [];
      this.leakRules = config.leaks || [];
      this.cutoffPolicies = config.cutoff || [];
      this.ensureStyle();
      const observer = new MutationObserver(() => this.schedule());
      observer.observe(document.documentElement, { childList: true, subtree: true });
      window.addEventListener("scroll", () => this.schedule(), { passive: true });
      this.tick();
    }

    styleText() {
      const rules = this.hideRules.map((rule) => `${rule.selector} { display: none !important; }`);
      rules.push(`[${HIDE_ATTRIBUTE}] { display: none !important; }`);
      rules.push(`[${COLLAPSE_ATTRIBUTE}] { ${COLLAPSE_STYLE} }`);
      return rules.join("\n");
    }

    ensureStyle() {
      if (document.getElementById(STYLE_ID)) {
        return;
      }
      const style = document.createElement("style");
      style.id = STYLE_ID;
      style.textContent = this.styleText();
      document.documentElement.appendChild(style);
    }

    schedule() {
      if (this.timer !== null) {
        return;
      }
      this.timer = setTimeout(() => {
        this.timer = null;
        this.tick();
      }, TICK_DELAY_MS);
    }

    tick() {
      this.ensureStyle();
      this.applyMarks();
      this.runActions();
      this.reportStats();
      this.updateCutoff();
    }

    markAttribute(rule) {
      return rule.collapse ? COLLAPSE_ATTRIBUTE : HIDE_ATTRIBUTE;
    }

    applyMarks() {
      for (const rule of this.markRules) {
        const attribute = this.markAttribute(rule);
        const matches = new Set(this.safely(() => rule.find(), []));
        for (const stale of document.querySelectorAll(`[${attribute}="${rule.name}"]`)) {
          if (!matches.has(stale)) {
            stale.removeAttribute(attribute);
          }
        }
        for (const element of matches) {
          if (element && !element.hasAttribute(attribute)) {
            element.setAttribute(attribute, rule.name);
          }
        }
      }
    }

    runActions() {
      for (const action of this.actions) {
        this.safely(() => action.run(), null);
      }
    }

    reportStats() {
      const counts = {};
      for (const rule of this.hideRules) {
        counts[rule.name] = this.count(rule.selector);
      }
      for (const rule of this.markRules) {
        counts[rule.name] = this.count(`[${this.markAttribute(rule)}="${rule.name}"]`);
      }
      const message = { type: "stats", counts: counts, leaks: this.leakCounts() };
      const serialized = JSON.stringify(message);
      if (serialized === this.lastStats) {
        return;
      }
      this.lastStats = serialized;
      this.post(message);
    }

    leakCounts() {
      const leaks = {};
      for (const rule of this.leakRules) {
        leaks[rule.name] = this.safely(
          () => Array.from(document.querySelectorAll(rule.selector)).filter((element) => this.isRendered(element)).length,
          -1
        );
      }
      return leaks;
    }

    updateCutoff() {
      const policy = this.cutoffPolicies.find((candidate) => this.safely(() => candidate.applies(window.location), false));
      const key = policy ? `${policy.name}|${window.location.pathname}${window.location.search}` : null;
      if (key !== this.cutoffKey) {
        this.cutoffKey = key;
        this.cutoffY = null;
        this.cutoffExtensions = 0;
      }
      if (policy) {
        const measured = this.safely(() => this.measureCutoff(policy), null);
        if (measured !== null) {
          this.cutoffY = Math.round(measured);
        }
      }
      this.reportCutoff(policy);
    }

    measureCutoff(policy) {
      if (policy.maxDepth) {
        const depth = policy.maxDepth * (1 + this.cutoffExtensions);
        return document.documentElement.scrollHeight > depth ? depth : null;
      }
      const items = Array.from(document.querySelectorAll(policy.items)).filter((item) => this.isRendered(item));
      const limit = Date.now() - policy.maxAgeHours * 3600 * 1000;
      const old = items.map((item) => this.isOlderThan(item, limit));
      for (let index = 0; index < items.length; index += 1) {
        const run = old.slice(index, index + OLD_RUN_LENGTH);
        if (run.length === OLD_RUN_LENGTH && run.every(Boolean)) {
          return items[index].getBoundingClientRect().top + window.scrollY;
        }
      }
      return null;
    }

    isRendered(element) {
      const rects = element.getClientRects();
      return rects.length > 0 && rects[0].height > 0;
    }

    isOlderThan(item, limit) {
      const time = item.querySelector("time[datetime]");
      if (!time) {
        return false;
      }
      const stamp = Date.parse(time.getAttribute("datetime"));
      return !Number.isNaN(stamp) && stamp < limit;
    }

    reportCutoff(policy) {
      const message = { type: "cutoff", y: this.cutoffY, extendable: Boolean(policy && policy.maxDepth) };
      const serialized = JSON.stringify(message);
      if (serialized === this.lastCutoff) {
        return;
      }
      this.lastCutoff = serialized;
      this.post(message);
    }

    extendCutoff() {
      this.cutoffExtensions += 1;
      this.tick();
    }

    count(selector) {
      return this.safely(() => document.querySelectorAll(selector).length, -1);
    }

    safely(work, fallback) {
      try {
        return work();
      } catch (error) {
        return fallback;
      }
    }

    post(message) {
      const handlers = window.webkit && window.webkit.messageHandlers;
      if (handlers && handlers.focusFeed) {
        handlers.focusFeed.postMessage(message);
      }
    }

    containersOf(innerSelector, containerSelector) {
      const found = [];
      for (const inner of document.querySelectorAll(innerSelector)) {
        const container = inner.closest(containerSelector);
        if (container) {
          found.push(container);
        }
      }
      return found;
    }

    withText(selector, pattern) {
      return Array.from(document.querySelectorAll(selector)).filter((element) =>
        pattern.test((element.textContent || "").trim())
      );
    }
  }

  window.FocusFeed = new FilterEngine();
})();
