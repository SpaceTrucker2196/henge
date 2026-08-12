#!/bin/bash
# Build the macOS app in Release and wrap it in a drag-to-Applications
# .dmg — the artifact the Pages download page links to.
#
#   scripts/build_dmg.sh             build dist/Henge-<version>.dmg
#   scripts/build_dmg.sh --release   …and publish it to a GitHub release
#                                    (versioned asset for the archive, plus
#                                    a stable `Henge.dmg` the download
#                                    page's /releases/latest link needs)
#
# The version is read from project.yml (MARKETING_VERSION) so the tag, the
# volume name and the file name cannot drift from what the app reports.
#
# Signing: direct-download distribution wants a "Developer ID Application"
# identity, and the script uses one when the keychain has it. Until then it
# signs ad hoc, which runs fine locally but makes Gatekeeper ask for
# right-click → Open on first launch after download — the download page
# says so out loud rather than leaving users to a scary dialog.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml | head -1)
if [[ -z "$VERSION" ]]; then
    echo "error: MARKETING_VERSION not found in project.yml" >&2
    exit 1
fi

# The .xcodeproj is generated and gitignored — never hand-edited, always
# reproducible from project.yml.
[[ -d Henge.xcodeproj ]] || xcodegen generate

DERIVED=build/dmg-derived
DIST=dist
STAGING="$DIST/staging"
DMG="$DIST/Henge-$VERSION.dmg"
rm -rf "$DERIVED" "$STAGING" "$DMG"
mkdir -p "$DIST"

# Release build, signing disabled here: the identity decision is made once,
# below, rather than letting xcodebuild pick a development certificate that
# would be wrong for distribution anyway.
echo "building Henge-macOS $VERSION (Release)…"
set -o pipefail
xcodebuild -project Henge.xcodeproj -scheme Henge-macOS \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build |
    { grep -E "error:|warning:|BUILD" || true; }

APP="$DERIVED/Build/Products/Release/Henge.app"
[[ -d "$APP" ]] || { echo "error: $APP not produced" >&2; exit 1; }

# Both architectures or the download page's claim is wrong.
BINARY="$APP/Contents/MacOS/Henge"
lipo -archs "$BINARY" | grep -q x86_64 && lipo -archs "$BINARY" | grep -q arm64 \
    || { echo "error: binary is not universal: $(lipo -archs "$BINARY")" >&2; exit 1; }

# Prefer Developer ID when the keychain grows one; ad hoc otherwise.
# Hardened runtime only with a real identity — it exists for notarization,
# and combined with an ad-hoc signature it just breaks local debugging.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
if [[ -n "$IDENTITY" ]]; then
    echo "signing with: $IDENTITY"
    codesign --force --deep --options runtime --timestamp \
        --sign "$IDENTITY" "$APP"
else
    echo "no Developer ID identity — signing ad hoc (Gatekeeper will want right-click → Open)"
    codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep "$APP"

# The classic installer: the app beside an Applications symlink, zipped
# into a read-only UDZO image.
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Henge $VERSION" -srcfolder "$STAGING" \
    -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
hdiutil verify "$DMG" >/dev/null

echo "built $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"

if [[ "${1:-}" == "--release" ]]; then
    TAG="v$VERSION"
    # Two channels, one artifact: the GitHub release is the versioned
    # archive (public, since 2026-08-03 when the repo went public), and
    # www.river.io/henge/ is the download front door, the same directory-
    # per-app arrangement every River.io app uses. The site copy is what
    # the marketing pages link, so it is staged here rather than trusted
    # to someone remembering.
    cp "$DMG" "$DIST/Henge.dmg"
    if ! gh release view "$TAG" >/dev/null 2>&1; then
        gh release create "$TAG" --prerelease \
            --title "Henge $VERSION (early build)" \
            --notes "Early macOS build. Universal (Apple silicon + Intel), macOS 14 or later. Not yet notarized: right-click the app and choose Open on first launch."
    fi
    gh release upload "$TAG" "$DMG" "$DIST/Henge.dmg" --clobber

    # Keep the download page's figures honest — the version and size it
    # shows are stamped from the artifact itself, never typed by hand.
    # The page's SOURCE is docs/index.html in this repo (the site is
    # repo-owned and mirrored by scripts/deploy-site.sh); the artifact
    # itself is staged straight into the site checkout, which the deploy
    # script deliberately never touches.
    SIZE=$(du -h "$DMG" | cut -f1 | tr -d ' ')
    sed -i '' \
        -e "s|<!--v-->[^<]*<!--/v-->|<!--v-->$VERSION<!--/v-->|g" \
        -e "s|<!--s-->[^<]*<!--/s-->|<!--s-->$SIZE<!--/s-->|g" \
        docs/index.html
    SITE="${RIVER_IO_SITE:-../river-io-site}"
    if [[ -d "$SITE/henge" ]]; then
        cp "$DMG" "$SITE/henge/Henge.dmg"
        scripts/deploy-site.sh
        echo "published release $TAG; staged $SITE/henge/ — push river-io-site (or make publish-site) to deploy"
    else
        echo "published release $TAG — river-io-site not found at $SITE; set RIVER_IO_SITE to stage the public copy" >&2
    fi
fi
