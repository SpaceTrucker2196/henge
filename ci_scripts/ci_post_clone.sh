#!/bin/sh
# Xcode Cloud auto-runs this file after `git clone` and before resolving
# SPM packages or running `xcodebuild`. Apple's runner is a clean macOS
# VM, and `Henge.xcodeproj` is generated and gitignored — so without this
# step xcodebuild has nothing to open and the build fails immediately.
#
# Same convention as `StatusGalactic-iOS` and `clientAPT`, which is the
# working reference if anything here diverges. One deliberate difference,
# noted below: henge stages no `Package.resolved`.
#
# Anything written to stdout/stderr appears in the Xcode Cloud build log
# under the "Post-clone" step.

set -eu

echo "▶︎ ci_post_clone.sh: bootstrapping the xcodegen build environment"

# Xcode Cloud invokes ci_scripts/ci_post_clone.sh with CWD set to the
# ci_scripts/ directory itself. Hop up to the repo root so `xcodegen
# generate` (which reads ./project.yml) finds the file.
cd "$(dirname "$0")/.."
echo "  • repo root: $(pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "  • installing xcodegen via Homebrew…"
  brew install xcodegen
else
  echo "  • xcodegen already on PATH ($(xcodegen --version))"
fi

echo "  • running xcodegen generate"
xcodegen generate

# No Package.resolved staging here, unlike the sibling repos.
#
# Both of them commit a copy at ci_scripts/Package.resolved and paste it
# into the regenerated workspace, because Xcode Cloud disables automatic
# SPM resolution and refuses to build without a lockfile. That applies to
# *remote* dependencies. henge has none — AGENTS.md makes the first
# third-party dependency a stops-and-asks — and its only package is
# `HengeLocal`, a local path package pointing at the repo root. There is
# nothing to resolve from the network and therefore nothing to pin.
#
# If a remote dependency is ever added, this is where the sibling
# pattern comes back:
#
#   cp Henge.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
#      ci_scripts/Package.resolved
#
# and a copy in the other direction here, before xcodebuild runs.

echo "✓ Henge.xcodeproj is ready for xcodebuild"
