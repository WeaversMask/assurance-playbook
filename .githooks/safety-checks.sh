#!/usr/bin/env sh
# The safety class, applied to this repository's COMMITS (identity-protection.md
# invariants 2, 3 and 5; secret-scanning.md invariants 1 and 3). Every project the
# playbook bootstraps installs these at every tier, and the tier never scales them.
# The pre-push hook and the CI history check apply the same class to what leaves the
# machine; all three share .githooks/safety-lib.sh.
#
# NOT SKIPPABLE. There is deliberately no SKIP for anything below, and no opt-out
# marker either: this repo is pseudonymous (AGENTS.md), so the personal-identifier
# layer has no off switch for prose to trip. identity-protection.md invariant 5a
# records what happened to a marker that could be mentioned.
#
# THE ORDER IS CORRECTNESS. Identity needs only git. Everything that needs only the
# shell — the committed config, the per-machine patterns file — runs before the one
# thing that needs the scanner, so a machine without the scanner still gets every
# state check, and the suite can exercise them without it.
#
# EVERY MESSAGE IS CONTENT-FREE — names of files and line numbers, never their
# matching lines. This output gets pasted into handovers.

set -e

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
. "$here/safety-lib.sh"

# --- Identity (invariant 2) -------------------------------------------------
read_declared_identity

ident() { v="$(git var "$1")"; printf '%s' "${v% * *}"; }   # drop "<epoch> <tz>"
author="$(ident GIT_AUTHOR_IDENT)"
committer="$(ident GIT_COMMITTER_IDENT)"
if [ "$author" != "$declared" ] || [ "$committer" != "$declared" ]; then
  echo "❌ safety: this commit's identity is not the declared one."
  [ "$author" != "$declared" ]    && echo "   author does not match AGENTS.md"
  [ "$committer" != "$declared" ] && echo "   committer does not match AGENTS.md"
  echo "   Values are not printed. Compare them yourself:"
  echo "     git var GIT_AUTHOR_IDENT; git var GIT_COMMITTER_IDENT"
  exit 1
fi

require_committed_config

# The one mistake that cannot be undone after a push. .gitignore stops
# `git add -A`; only a forced add gets past it. Deletions are allowed through, so
# that unstaging a file that was committed by mistake is not itself refused.
if git diff --cached --name-only --diff-filter=ACMR | grep -qE '(^|/)\.gitleaks\.local\.toml$'; then
  cat <<'MSG'
❌ safety: .gitleaks.local.toml is staged for commit.
   It holds the patterns that find your identifiers, so committing it would
   publish exactly what it guards. It is gitignored, so this took a forced add.
   Unstage it:
     git rm --cached .gitleaks.local.toml
MSG
  exit 1
fi

require_patterns_file
find_scanner
scan_init

# Two passes. The local config extends the committed one, so its pass re-applies
# every committed rule and allowlist as well as the personal ones; the committed
# pass still runs on its own, first, so that a local file whose `[extend]` is wrong
# cannot take the committed rules down with it — and so a refusal says which pass.
scan "the committed rules (.gitleaks.toml)" "$repo_root/.gitleaks.toml" "the staged changes" --staged || exit 1
scan "your local patterns (.gitleaks.local.toml)" "$pattern_file" "the staged changes" --staged || exit 1
