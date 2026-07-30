# henge — factory targets.
# `make test` is the oracle (factory/converge.md step 4): green plus a
# warning-clean `make build` means the factory is operational.

.PHONY: test uitest build build-ios build-mac generate clean run-mac

# The oracle. Runs against the shared engine through SwiftPM, so it needs no
# simulator and no Xcode project — which is what keeps it fast enough to run
# on every change. Logic belongs in HengeAstro/HengeGeometry for that reason.
test:
	swift test

# iOS builds also answer to fastlane (owner's order): `fastlane ios build`,
# `fastlane ios sim` (build+install+launch on the booted simulator),
# `fastlane ios uitest`. The lanes in fastlane/Fastfile wrap the same
# xcodebuild these targets use — same generated project, same
# CODE_SIGNING_ALLOWED=NO — so the two doors cannot drift.

# Pixel-level inspection: drives the real iOS app in the simulator and OCRs
# the screen. Exists because the rebuild card once drew upside down in a
# landscape window while the accessibility tree swore it was fine — a class
# of bug only the pixels can witness. Minutes rather than seconds, so it is
# its own target; run it when the chrome's compositing changes.
uitest: generate
	set -o pipefail; xcodebuild -project Henge.xcodeproj -scheme Henge \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-configuration Debug CODE_SIGNING_ALLOWED=NO test | \
		{ grep -E "error:|warning:|Test Suite|Test Case.*(passed|failed)|BUILD|TEST" || true; }

# Regenerate Henge.xcodeproj from project.yml. The .xcodeproj is generated —
# never hand-edit it, and never commit it (see .gitignore).
generate:
	xcodegen generate

# Both platforms must compile warning-clean before anything ships.
build: build-ios build-mac

# Piping xcodebuild anywhere hands the recipe's exit status to whatever is on
# the right of the pipe, so an unguarded `| tail` reports success on a failed
# build and quietly hides the diagnostics that would have said otherwise. Both
# halves of that are fixed here: pipefail so the failure propagates, and a
# filter that keeps every error and warning rather than the last five lines.
#
# Two things about the shell make this fiddlier than it looks, and both were
# silently returning zero on a failed build before they were fixed:
#
#   1. macOS ships GNU make 3.81, which predates `.SHELLFLAGS` and ignores it.
#      So `set -o pipefail` goes *inside* the recipe, where 3.81 will run it.
#   2. `||` binds looser than `|`, so `xcodebuild | grep || true` parses as
#      `(xcodebuild | grep) || true` and swallows the failure that pipefail had
#      just surfaced. The braces keep the `|| true` attached to grep, where it
#      belongs — grep exits 1 on a clean build with nothing to report, and that
#      is not a failure.
SHELL := /bin/bash

BUILD_FILTER := { grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" || true; }

build-ios: generate
	set -o pipefail; xcodebuild -project Henge.xcodeproj -scheme Henge \
		-destination 'generic/platform=iOS Simulator' \
		-configuration Debug CODE_SIGNING_ALLOWED=NO build | $(BUILD_FILTER)

build-mac: generate
	set -o pipefail; xcodebuild -project Henge.xcodeproj -scheme Henge-macOS \
		-destination 'platform=macOS' \
		-configuration Debug CODE_SIGNING_ALLOWED=NO build | $(BUILD_FILTER)

clean:
	swift package clean
	rm -rf .build Henge.xcodeproj

# Build and launch the macOS app — the fourth step of the cold-start loop.
run-mac: build-mac
	@open "$$(xcodebuild -project Henge.xcodeproj -scheme Henge-macOS \
		-configuration Debug -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $$2}' | head -1)/Henge.app"
