# henge — agent instructions

Repo-local rules for any coding agent (Claude Code, Copilot, Codex). Build and
infra runbook lives in `FACTORY.md`; charter in `MISSION.md`; the pattern and
the autonomy contract in `factory/dark-factory.md`.

## What henge is

**Not yet decided.** The repo carries a working multiplatform Swift scaffold
and a green oracle; `MISSION.md` is deliberately unwritten. Until the owner
sets the mission, this repo runs at **Level 3** — an agent proposes, the owner
decides. Do not invent a product direction and start building it.

The name is inherited from a 2014-era Objective-C agricultural calendar that
was wiped on 2026-07-27. Its history is still in this repo. It is **not** a
constraint on what henge becomes.

## Architecture

Two app targets over one shared engine:

- **`HengeCore`** — domain logic. Pure Swift and Foundation. No SwiftUI, no
  UIKit or AppKit, no file or network I/O.
- **`HengeUI`** — the shared SwiftUI surface. Depends on `HengeCore`.
- **`App/`** — the `@main` entry point, compiled into both the iOS and macOS
  targets. One definition of the app's structure.
- **`iOSApp/`, `macOSApp/`** — Info.plists and anything genuinely
  platform-specific.

Two dependency rules, and they are rules rather than descriptions:

1. **`HengeCore` never imports `HengeUI`, SwiftUI, or an app target.** Logic
   that ends up in a view is logic the oracle cannot reach.
2. **The app targets never hold logic.** They are shells. If a decision is
   being made, it belongs in `HengeCore` where a test can pin it.

Both platforms link the identical package products, so iOS and macOS cannot
diverge in behaviour. Divergence in *presentation* goes behind `#if os(...)`
inside `HengeUI`.

## Discipline

- **Tests must pass.** `make test` returns 0 before any push. Never commit a
  red test, never skip one, never weaken an assertion to get green.
- **Builds are warning-clean**, both platforms.
- **A bug fix ships with the test that would have caught it.** This is how the
  factory learns: every escape becomes a new inspection step.
- **Never write a test that feeds a parser its own output.** That loop passes
  when both halves are wrong.
- **`Henge.xcodeproj` is generated.** Never hand-edit it; it is gitignored.
  Edit `project.yml` and run `make generate`.
- **No third-party dependencies.** The package has none, so a cold clone
  builds offline. The first one is a stops-and-asks.

## Conventions

- **Commit messages.** Imperative subject, blank line, body explaining the
  *why*. `Co-Authored-By` trailer when an agent landed the change.
- **Branches.** Work on `main`. No long-running feature branches.
- **`git add` specific files.** Never `git add -A` or `git add .`.
- **No destructive git operations** without explicit owner authorisation.
- **Swift style:** four-space indent, comments wrapped near 80 columns, and
  comments that explain *why* rather than restating the code.

## Token / cost ledger

The owner bills from `LEDGER.md` (exact, never estimated). After every
substantive commit: run `~/.claude/billing/ledger.py --append --summary
"<desc>"`, then commit `LEDGER.md` as its own `chore(ledger): <sha>` commit.
Never hand-author, estimate, or rewrite rows — append-only. If the script
can't produce a row, stop and surface it.

Start billable sessions **inside this repo**, not the workspace root:
`ledger.py` attributes by the session's project directory and cannot account
for sessions launched from outside.

## User context

User: Jeff Kunzelman (`SpaceTrucker2196` on GitHub). River.io LLC.
