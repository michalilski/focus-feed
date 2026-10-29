-include Config/local.mk

SIMULATOR ?= iPhone 17 Pro
DEVICE ?=
BUNDLE_ID = com.michalilski.focusfeed
XCODE = xcodebuild -project FocusFeed.xcodeproj -scheme FocusFeed -derivedDataPath build
SIM_DESTINATION = -destination 'platform=iOS Simulator,name=$(SIMULATOR)'
SIM_APP = build/Build/Products/Debug-iphonesimulator/FocusFeed.app
DEVICE_APP = build/Build/Products/Release-iphoneos/FocusFeed.app

.PHONY: setup gen build test uitest audit sim device pull-snapshots icon require-device clean

setup:
	./scripts/setup.sh

gen:
	xcodegen generate --quiet

build: gen
	$(XCODE) build $(SIM_DESTINATION) -quiet

test: gen
	SIMULATOR='$(SIMULATOR)' ./scripts/test.sh -only-testing:FocusFeedTests

uitest: gen
	SIMULATOR='$(SIMULATOR)' ./scripts/test.sh -only-testing:FocusFeedUITests

audit:
	./scripts/privacy_audit.sh

sim: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	open -a Simulator
	xcrun simctl install '$(SIMULATOR)' $(SIM_APP)
	xcrun simctl launch '$(SIMULATOR)' $(BUNDLE_ID)

device: require-device gen
	$(XCODE) build -destination 'generic/platform=iOS' -configuration Release -allowProvisioningUpdates -quiet
	xcrun devicectl device install app --device $(DEVICE) $(DEVICE_APP)
	xcrun devicectl device process launch --device $(DEVICE) $(BUNDLE_ID)

pull-snapshots: require-device
	mkdir -p snapshots
	xcrun devicectl device copy from --device $(DEVICE) --domain-type appDataContainer \
		--domain-identifier $(BUNDLE_ID) --source Documents/snapshots --destination snapshots

icon:
	swift scripts/make_icon.swift FocusFeed/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

require-device:
	@test -n '$(DEVICE)' || { echo 'Set DEVICE in Config/local.mk or run: make device DEVICE=<identifier>'; exit 1; }

clean:
	rm -rf build
