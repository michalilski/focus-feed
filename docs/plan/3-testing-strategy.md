# FocusFeed Implementation Plan — 3. Testing strategy

The filters fight against websites that change without notice. Testing therefore has two jobs: prove our own logic is right (automated, fast), and notice when a site moved (live, partly manual).

## Layers

| # | Layer | Proves | Runs where | Command | Needs login |
| --- | --- | --- | --- | --- | --- |
| 1 | Router unit tests | Every URL in the keep/remove table gets the right decision | Simulator | `make test` | No |
| 2 | Filter fixture tests | Hide, mark, leak and cutoff rules do what we think, in real WebKit | Simulator | `make test` | No |
| 3 | Native unit tests | Message parsing, redirect-loop guard, cutoff geometry, scroll limit | Simulator | `make test` | No |
| 4 | UI smoke tests | App launches, switcher and controls exist | Simulator | `make uitest` | No |
| 5 | Live probe | Rules match the real site today | Simulator | `./scripts/live_probe.sh …` | Only for logged-in pages |
| 6 | Acceptance checklist | The keep/remove table holds on the phone, features still work | iPhone | By hand (USER) | Yes |
| 7 | Privacy audit | No network, analytics or cookie code crept in | Mac | `make audit` | No |
| 8 | In-app leak counters | A site changed its markup | iPhone, daily use | Look at the menu icon | Yes |

## 1. Router tests

Table-driven. `RouterTestCase` gives four helpers; each takes a URL string:

```swift
assertAllowed("https://m.youtube.com/watch?v=abc123")
assertRedirect("https://m.youtube.com/", to: "https://m.youtube.com/feed/subscriptions")
assertBlocked("https://m.youtube.com/feed/trending")
assertExternal("https://example.com/")
```

Every routing change starts by adding a line here and watching it fail.

## 2. Filter fixture tests

A fixture is a small HTML file in `FocusFeedTests/Fixtures/` that imitates the structure of one page. Elements carry an `id` and `data-expect="hidden"` or `data-expect="visible"`:

```html
<ytm-video-with-context-renderer id="short-result" data-expect="hidden">
  <a href="/shorts/xyz789">A short in results</a>
</ytm-video-with-context-renderer>
```

`FilterFixtureTestCase.assertFixture(name, profile:, path:)` loads the fixture into a real `WKWebView` built by the same `WebViewFactory` the app uses, with the base URL set to the platform's host plus `path` (so rules that look at `location.pathname` work), runs the engine once, and then checks:

- every `data-expect="hidden"` element is not rendered (no layout box, or zero height),
- every `data-expect="visible"` element is rendered,
- every leak counter is 0.

Rules for fixtures:

- Always include elements that must stay visible. A rule that hides everything would otherwise pass.
- Keep them minimal and synthetic. Never paste real page content with names, messages or IDs into a fixture; copy only the tag names, attributes and nesting.
- One fixture per page type (feed, profile, search, detail).

Limits: fixtures prove the rule logic, not that the real site still looks like the fixture. That is what layers 5, 6 and 8 are for.

## 3. Reading test output

`make test` prints for example:

```
	 Executed 45 tests, with 0 failures (0 unexpected) in 6.524 (6.537) seconds
** TEST SUCCEEDED **
Full log: build/test.log
```

On failure there are `error:` lines with file, line and the assertion message, for example `XCTAssertEqual failed: ("false") is not equal to ("true") - #short-result in youtube-search.html`. If the build itself fails there are compiler `error:` lines and no `Executed` line; fix those first. Lines containing `ProcessSuspension` in the full log are simulator noise and mean nothing.

## 5. Live probe

`scripts/live_probe.sh` builds the Debug app, installs it in the simulator, launches it straight onto one URL, waits, and collects three files in `build/probe/`:

| File | Content |
| --- | --- |
| `<platform>.png` | Screenshot. Open it with the Read tool to look at the page |
| `<platform>.html` | The page's DOM at that moment |
| `<platform>.json` | Final URL, user agent, hidden counts, leak counts. Also printed to the terminal |

```bash
./scripts/live_probe.sh youtube "https://m.youtube.com/results?search_query=lofi+music" 12
```

Reading the report:

- `url` is where the page ended up. Use it to check redirects.
- `leaks` must all be 0. Anything above 0 is a visible element that should be hidden.
- `hidden` counts above 0 show a rule is matching. A rule that is 0 on a page where you can see its target in the screenshot is broken.
- `-1` means the selector is invalid CSS.

YouTube works logged out (search, watch, channel pages). In the EU a consent dialog covers the screenshot on first run; the DOM and counters behind it are still valid. Instagram and X show only a login page when logged out.

Useful greps on the DOM file. Never print the whole file; it is around 1 MB:

```bash
grep -oE "<(ytm|yt|grid)[a-z0-9-]*" build/probe/youtube.html | sort | uniq -c | sort -rn | head -30
grep -oE 'data-testid="[^"]*"' build/probe/x.html | sort | uniq -c | sort -rn | head -40
grep -oE 'href="/[a-z_]+/' build/probe/instagram.html | sort | uniq -c | sort -rn | head -30
```

## 6. Acceptance checklists (USER)

Phases 4, 5 and 6 each end with a checklist derived from the spec's keep/remove table: every "keep" row must work, every "remove" row must be gone. Michał runs them on the phone, logged in. Results go into `changelog.md` with the date. A phase is not done until its checklist passes or each failing line has an entry under "Known gaps" in the changelog.

## Leak-fix loop

Use this whenever something that should be hidden is visible, during phases 4–6 and forever after.

1. **Capture.** On the phone, open the page where the leak shows. Menu → Filters → "Save DOM snapshot". Then on the Mac, with the phone connected: `make pull-snapshots`. The file is `snapshots/<platform>.html` (one per platform; a new snapshot overwrites the old one). In the simulator the same button works and the probe script does it automatically.
2. **Locate.** Find the leaking element in the snapshot by text or by link target, and print only a small window around it:

```bash
grep -o '.\{400\}Suggested for you.\{400\}' snapshots/instagram.html | head -3
```

3. **Choose a hook.** In order of preference: URL pattern in an `href`; `data-testid`; `aria-label`; `role`; custom element name; structural relation with `:has()`. Never a class name that looks generated (`x1lliihq`, `css-175oi2r`). Text matching is a last resort and must include the Polish text as well as the English, because the phone is set to Polish.
4. **Write the fixture first.** Add a minimal imitation of the element to the right fixture with `data-expect="hidden"`, plus a similar legitimate element with `data-expect="visible"` if the rule could over-match. Run `make test` and see it fail.
5. **Add the rule** to the platform's `.js` file: a `hide` entry if a selector is enough, a `mark` entry if it needs the URL or text. Add a `leaks` entry if the thing has a stable signature. Run `make test` and see it pass.
6. **Verify live.** `make device`, open the page, check the Filters sheet shows the new rule counting above 0 and the element is gone.
7. **Commit** the script, fixture and test. Never the snapshot. Add a changelog line.

If the leak is a whole page (a new URL for a feed), it is a routing fix instead: add a router test line, then a rule in the platform's `…Profile.swift`.

## Privacy checks

- `make audit` must print only `ok:` lines. It runs in phase 7 and before every `make device` from then on.
- Once, in phase 7 (USER): Settings → Privacy & Security → App Privacy Report on the phone, turn it on, use FocusFeed for a day, then check "App Network Activity" for FocusFeed. Only domains of the three platforms, their CDNs and login providers should appear.
