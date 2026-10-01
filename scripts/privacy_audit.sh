#!/bin/zsh
set -uo pipefail

FAILED=0

forbid() {
  local description=$1 pattern=$2
  shift 2
  if grep -rnE "$pattern" "$@" 2>/dev/null; then
    echo "FAIL: $description"
    FAILED=1
  else
    echo "ok:   $description"
  fi
}

forbid "no app-made network calls in Swift" 'URLSession|NWConnection|import Network|CFSocket|CFStream' FocusFeed
forbid "no analytics or crash SDKs" 'Firebase|Crashlytics|Sentry|Amplitude|Mixpanel|Segment|AppCenter|Analytics' FocusFeed project.yml
forbid "no third-party packages" '^packages:|package:' project.yml
forbid "no network or storage access from injected scripts" 'fetch\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|document\.cookie|localStorage|sessionStorage|indexedDB|new Image' FocusFeed/Resources/Filters
forbid "no remote URLs in injected scripts" 'https?://' FocusFeed/Resources/Filters
forbid "no insecure transport exceptions" 'NSAllowsArbitraryLoads|NSExceptionDomains' FocusFeed project.yml
forbid "no reading of cookies or credentials in Swift" 'httpCookieStore|HTTPCookie|SecItem|Keychain' FocusFeed

if find . -name Package.resolved -not -path "./build/*" | grep -q .; then
  echo "FAIL: Package.resolved found"
  FAILED=1
else
  echo "ok:   no resolved packages"
fi

exit $FAILED
