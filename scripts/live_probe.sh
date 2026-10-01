#!/bin/zsh
set -euo pipefail

PLATFORM=${1:?usage: live_probe.sh <instagram|youtube|x> <url> [wait-seconds]}
URL=${2:?usage: live_probe.sh <instagram|youtube|x> <url> [wait-seconds]}
WAIT=${3:-10}
BUNDLE_ID=com.michalilski.focusfeed
SIMULATOR=${SIMULATOR:-iPhone 17 Pro}
OUT=build/probe

boot_simulator() {
  xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
  xcrun simctl bootstatus "$SIMULATOR" >/dev/null
}

install_app() {
  xcodebuild build -project FocusFeed.xcodeproj -scheme FocusFeed \
    -destination "platform=iOS Simulator,name=$SIMULATOR" -derivedDataPath build -quiet
  xcrun simctl install "$SIMULATOR" build/Build/Products/Debug-iphonesimulator/FocusFeed.app
}

run_probe() {
  xcrun simctl terminate "$SIMULATOR" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID" -FFPlatform "$PLATFORM" -FFURL "$URL" -FFSnapshotAfter "$WAIT" >/dev/null
  sleep $((WAIT + 3))
}

collect() {
  local container
  container=$(xcrun simctl get_app_container "$SIMULATOR" "$BUNDLE_ID" data)
  mkdir -p "$OUT"
  xcrun simctl io "$SIMULATOR" screenshot "$OUT/$PLATFORM.png" >/dev/null 2>&1
  cp "$container/Documents/snapshots/$PLATFORM.html" "$container/Documents/snapshots/$PLATFORM.json" "$OUT/"
  cat "$OUT/$PLATFORM.json"
}

boot_simulator
install_app
run_probe
collect
