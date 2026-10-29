#!/bin/zsh
set -euo pipefail

require_xcode() {
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode is missing. Install Xcode 26 or newer from the App Store."
    exit 1
  fi
}

install_xcodegen() {
  if command -v xcodegen >/dev/null; then
    return
  fi
  if ! command -v brew >/dev/null; then
    echo "XcodeGen is missing. Install Homebrew, then run: brew install xcodegen"
    exit 1
  fi
  brew install xcodegen
}

copy_template() {
  local target=$1
  if [[ -f $target ]]; then
    echo "ok:   $target exists"
  else
    cp "$target.example" "$target"
    echo "new:  $target created, edit it before building for a device"
  fi
}

require_xcode
install_xcodegen
copy_template Config/Local.xcconfig
copy_template Config/local.mk
xcodegen generate --quiet
echo "Done. Next: make test, make sim or make device"
