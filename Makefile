# henge — factory targets.
# `make test` is the oracle (factory/converge.md step 4): green plus a
# warning-clean `make build` means the factory is operational.

.PHONY: test build build-ios build-mac generate clean run-mac

# The oracle. Runs against the shared engine through SwiftPM, so it needs no
# simulator and no Xcode project — which is what keeps it fast enough to run
# on every change. Logic belongs in HengeAstro/HengeGeometry for that reason.
test:
	swift test

# Regenerate Henge.xcodeproj from project.yml. The .xcodeproj is generated —
# never hand-edit it, and never commit it (see .gitignore).
generate:
	xcodegen generate

# Both platforms must compile warning-clean before anything ships.
build: build-ios build-mac

build-ios: generate
	xcodebuild -project Henge.xcodeproj -scheme Henge \
		-destination 'generic/platform=iOS Simulator' \
		-configuration Debug CODE_SIGNING_ALLOWED=NO build | tail -5

build-mac: generate
	xcodebuild -project Henge.xcodeproj -scheme Henge-macOS \
		-destination 'platform=macOS' \
		-configuration Debug CODE_SIGNING_ALLOWED=NO build | tail -5

clean:
	swift package clean
	rm -rf .build Henge.xcodeproj

# Build and launch the macOS app — the fourth step of the cold-start loop.
run-mac: build-mac
	@open "$$(xcodebuild -project Henge.xcodeproj -scheme Henge-macOS \
		-configuration Debug -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $$2}' | head -1)/Henge.app"
