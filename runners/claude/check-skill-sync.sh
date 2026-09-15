#!/usr/bin/env sh
# Skill-copy freshness check (quality-gates.md invariant 11, recorded as a
# deviation — see below).
#
# THE INVARIANT is documentation.md invariant 1 — one home per doc. NOT
# quality-gates invariant 11, which governs *generated* files and their
# generators: SKILL.md is a hand-edited copy with no generator, so citing 11
# would restate it as something broader than it says. What 11 contributes is the
# shape of the remedy — a check that fails closed rather than a convention — and
# the deviation recorded below is against that shape. The skill has two copies — the canonical one in this repo and the
# installed one the harness actually loads — and for a full release nothing
# enforced their agreement. The invariant-5a guidance sat here unrunnable while
# the copy that runs lacked it. This is that check.
#
# RECORDED DEVIATION. Invariant 11 requires a **CI** freshness check. This repo
# has no CI, and a CI runner would have nothing to compare: the copy that drifts
# is installed on the maintainer's machine. So this runs as a pre-commit hook via
# `core.hooksPath=.githooks`. Mechanical rather than remembered, but a hook is
# not CI, and that gap is recorded rather than papered over.
#
# ITS BLIND SPOT: it fires on commits to THIS repo. An edit made directly to the
# installed copy stays undetected until the next commit here. The check tells you
# the copies disagree; it does not tell you which one moved.
#
# FAIL-CLOSED, in three ways: a missing canonical file, a missing installed file,
# and an unreadable installed directory all FAIL. Comparing nothing must never
# read as clean (invariant 11: "a check mode must never write, and must fail
# closed when it cannot find what it expects to compare").
#
# TWO ENVIRONMENT VARIABLES, both deliberate:
#
#   ASSURANCE_SKILL_NOT_INSTALLED=1  — acknowledges a machine where the skill is
#     deliberately not installed. An explicit, greppable opt-out that says so out
#     loud rather than passing quietly.
#
#   ASSURANCE_SKILL_INSTALL_DIR      — TEST SEAM ONLY, for exercising this
#     script's failure paths without touching the real installed copy. Pointed at
#     the canonical file's own directory it makes the check compare a file with
#     itself and pass — a silent pass, which is the thing the line above says
#     this script does not do. Named here so that is a known limitation of a
#     testing affordance rather than an undocumented bypass.

set -e

repo_root="$(git rev-parse --show-toplevel)"
canonical="$repo_root/runners/claude/skill/bootstrap-assurance/SKILL.md"
installed="${ASSURANCE_SKILL_INSTALL_DIR:-$HOME/.claude/skills}/bootstrap-assurance/SKILL.md"

# EVERY PATH THIS SCRIPT PRINTS IS HOME-RELATIVE OR REPO-RELATIVE, never absolute.
# Its output is pasted into handovers and verification matrices, and an absolute
# home path carries the local username into a file forever — the exact leak
# identity-protection invariant 5a exists to catch. Caught in this script's own
# first run, which is why the rule is written down here rather than remembered.
# Parameter expansion, not sed: `$HOME` interpolated into a BRE breaks on any
# `|` or `[` in the path. And a path OUTSIDE $HOME has no `~` form at all — the
# first version printed it in full, so an override elsewhere leaked an absolute
# path into exactly the output the comment above says gets pasted into
# handovers. Found in review, 2026-09-07.
# `${HOME:-/nonexistent}`: with HOME unset the pattern would degrade to `/*`,
# every absolute path would match, and the function would print `~` glued to a
# full path — an absolute path in the output this comment says gets pasted.
tilde() {
  case "$1" in
    # `$HOME/...`, not `~/...`: the remedy is printed inside double quotes, where
    # `~` does not expand — `mkdir -p "$(dirname "~/x")"` makes a directory
    # literally named `~`. Found in review, 2026-09-08.
    "${HOME:-/nonexistent}"/*) printf '$HOME%s' "${1#"${HOME:-/nonexistent}"}" ;;
    *) printf '$ASSURANCE_SKILL_INSTALL_DIR/bootstrap-assurance/SKILL.md' ;;
  esac
}
canonical_shown="runners/claude/skill/bootstrap-assurance/SKILL.md"
installed_shown="$(tilde "$installed")"

if [ ! -f "$canonical" ]; then
  echo "❌ skill-sync: canonical copy is missing."
  echo "   Expected: $canonical_shown"
  echo "   This check cannot evaluate, so it blocks."
  exit 1
fi

if [ ! -f "$installed" ]; then
  if [ "${ASSURANCE_SKILL_NOT_INSTALLED:-}" = "1" ]; then
    echo "⚠️  skill-sync: installed copy absent, acknowledged via"
    echo "   ASSURANCE_SKILL_NOT_INSTALLED=1. Nothing was compared."
    exit 0
  fi
  echo "❌ skill-sync: the installed copy is missing."
  echo "   Looked for: $installed_shown"
  echo "   Install it:"
  echo "     mkdir -p \"\$(dirname \"$installed_shown\")\""
  echo "     cp \"$canonical_shown\" \"$installed_shown\"   # from the repo root"
  echo "   Or, on a machine where it is deliberately not installed, set"
  echo "   ASSURANCE_SKILL_NOT_INSTALLED=1 — an explicit opt-out, not a silent pass."
  exit 1
fi

if diff -q "$canonical" "$installed" > /dev/null 2>&1; then
  echo "✅ skill-sync: the two copies agree."
  exit 0
fi

echo "❌ skill-sync: the two skill copies have drifted."
echo
diff -u --label "$installed_shown" --label "$canonical_shown" "$installed" "$canonical" || true
echo
echo "   Left  = installed (the copy that actually runs)"
echo "   Right = canonical (this repo)"
echo
echo "   Edit the canonical file, then copy it across:"
echo "     cp \"$canonical_shown\" \"$installed_shown\"   # from the repo root"
echo
echo "   If the INSTALLED copy holds the newer edit, port it back here first —"
echo "   this check reports disagreement, not direction."
exit 1
