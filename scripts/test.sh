#!/bin/zsh
set -uo pipefail

SIMULATOR=${SIMULATOR:-iPhone 17 Pro}
LOG=build/test.log

mkdir -p build
xcodebuild test -project FocusFeed.xcodeproj -scheme FocusFeed \
  -destination "platform=iOS Simulator,name=$SIMULATOR" -derivedDataPath build "$@" >"$LOG" 2>&1
STATUS=$?
grep -E ": error: |Executed [0-9]+ tests|\*\* TEST" "$LOG" | grep -v ProcessSuspension | sort -u
echo "Full log: $LOG"
exit $STATUS
