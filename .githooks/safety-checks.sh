#!/usr/bin/env sh
# The safety class, applied to this repository (identity-protection.md
# invariants 2 and 3; secret-scanning.md invariant 3). Every project the playbook
# bootstraps installs these at every tier, and the tier never scales them.
#
# NOT SKIPPABLE. There is deliberately no SKIP for anything below.
#
# EVERY MESSAGE IS CONTENT-FREE — names of files, never their matching lines.
# This output gets pasted into handovers.

set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# --- Identity (invariant 2) -------------------------------------------------
# The declared identity has ONE home: the declaration line in AGENTS.md, which
# is where invariant 1 puts it. Parsed rather than hardcoded here, so the hook
# cannot drift from the document that declares it.
#
# `git var` rather than `git config user.email`: reading config misses every
# override that actually matters. Probed 2026-09-16, git 2.49.0 — `git -c
# user.email=`, `git -c user.name=`, GIT_AUTHOR_EMAIL, GIT_COMMITTER_EMAIL and
# `--author=` are ALL visible here, and all five are refused.
# ONE pattern, anchored once. The first version of this block detected the
# declaration line with one regex and extracted the value with another, narrower
# one — `[A-Za-z0-9_-]+`, which rejects any display name containing a space. A
# declaration it could see but not read produced an empty value and blocked every
# commit. `WeaversMask` has no space, so this repo would never have shown it;
# a fixture named "T Declared" did, immediately. Same lesson as
# check-decisions.mjs: when detection and parsing disagree, one of them is wrong
# about a case nobody tried.
#
# TWO LINES FAIL RATHER THAN PICKING ONE. An identity that cannot be resolved
# unambiguously must not resolve confidently.
decl_lines="$(grep -cE '^\*\*Commits only as `[^`]+ <[^`]+>`\*\*' AGENTS.md || true)"
declared="$(grep -E '^\*\*Commits only as `[^`]+ <[^`]+>`\*\*' AGENTS.md \
  | head -1 | grep -oE '`[^`]+`' | head -1 | tr -d '`' || true)"
if [ -z "$declared" ] || [ "$decl_lines" != "1" ]; then
  echo "❌ safety: the declared identity cannot be read from AGENTS.md."
  echo "   Expected exactly one line of the form:"
  echo '     **Commits only as `Name <address>`**'
  echo "   A check that cannot evaluate must block."
  exit 1
fi

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

# --- Secret scan (secret-scanning.md invariants 1 and 3) --------------------
gitleaks_bin=""
if [ -x "$repo_root/.bin/gitleaks" ]; then gitleaks_bin="$repo_root/.bin/gitleaks"
elif command -v gitleaks >/dev/null 2>&1; then gitleaks_bin="gitleaks"
else
  echo "❌ safety: gitleaks not found, so the secret scan cannot run."
  echo "   Install it (brew install gitleaks) and retry. There is no bypass."
  exit 1
fi

if [ ! -f "$repo_root/.gitleaks.toml" ]; then
  echo "❌ safety: .gitleaks.toml is missing — the committed scanner config."
  echo "   The scan cannot run without it. Restore it before committing."
  exit 1
fi

"$gitleaks_bin" git --staged --redact --no-banner --config "$repo_root/.gitleaks.toml"
