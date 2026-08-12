#!/usr/bin/env bash
# Deploy the Henge marketing site (docs/) into the river-io-site repo,
# under henge/, so it is served at https://www.river.io/henge/ alongside
# the other products. The nighthawk-iOS pattern, adopted verbatim.
#
# CONVENTION: publish the site as part of cutting a release, not ad hoc.
#
#   scripts/deploy-site.sh          # copy + commit locally in river-io-site
#   scripts/deploy-site.sh --push   # also push river-io-site to production
#
# river-io-site is PUBLIC (www.river.io). Pushing publishes. The copy
# and local commit are safe; --push is the one outward step and is
# deliberately opt-in.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/docs"
DEST_REPO="${RIVER_IO_SITE:-$HOME/projects/river-io-site}"
DEST="$DEST_REPO/henge"

[ -d "$SRC" ] || { echo "no docs/ at $SRC" >&2; exit 1; }
[ -d "$DEST_REPO/.git" ] || {
  echo "river-io-site not found at $DEST_REPO" >&2
  echo "clone it or set RIVER_IO_SITE=/path/to/river-io-site" >&2
  exit 1
}

mkdir -p "$DEST"
# Mirror docs/ into the subdir. --delete keeps it a clean copy, EXCEPT
# Henge.dmg: the download artifact is staged there by build_dmg.sh, not
# by this script, and deleting it would break the live download link.
rsync -a --delete \
  --exclude '.DS_Store' \
  --exclude 'Henge.dmg' \
  "$SRC"/ "$DEST"/

cd "$DEST_REPO"
git add henge
if git diff --cached --quiet; then
  echo "river-io-site: henge already up to date, nothing to commit."
  # "Nothing to commit" is not "nothing to publish": an earlier run
  # without --push leaves its commit unpushed. (Lesson inherited from
  # nighthawk-iOS, where exiting here made --push a silent no-op.)
  if [ "${1:-}" = "--push" ] && [ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ]; then
    echo "river-io-site: unpushed commits from an earlier run — publishing those."
  else
    exit 0
  fi
fi

if ! git diff --cached --quiet; then
  SHA="$(cd "$HERE" && git rev-parse --short HEAD)"
  git commit -q -m "Deploy henge site (henge@$SHA)"
  echo "river-io-site: committed henge/ (from henge@$SHA)."
fi

if [ "${1:-}" = "--push" ]; then
  git push origin main
  echo "Pushed to production — live shortly at https://www.river.io/henge/"
else
  echo "Not pushed. Run 'git -C \"$DEST_REPO\" push origin main' (or re-run with --push) to publish."
fi
