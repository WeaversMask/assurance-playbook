#!/usr/bin/env sh
# Regression tests for check-skill-sync.sh.
#
# Same reason as reference/node-pnpm/test/gates.test.sh: this check was proven
# once by hand and then broken by its own follow-up fix, which printed an
# absolute home path in one branch — into the output whose own comment says it
# gets pasted into handovers. Ad-hoc verification found it only because someone
# read the output; nothing would have caught it on the next edit.
#
# The cases here are the ones that were actually got wrong, not the ones that
# came to mind while writing the script.
#
# Run: sh runners/claude/check-skill-sync.test.sh

set -e

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/check-skill-sync.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

pass=0
fail=0

# check <name> <wanted-rc> <grep-pattern-or-empty> <env-assignments...> --
_run() {
  name="$1"; want="$2"; pat="$3"; shift 3
  out="$(env "$@" sh "$script" 2>&1)" && got=0 || got=$?
  if [ "$got" -ne "$want" ]; then
    fail=$((fail + 1)); printf '  FAIL  %s — wanted exit %s, got %s\n' "$name" "$want" "$got"
    printf '%s\n' "$out" | sed 's/^/          /'; return
  fi
  if [ -n "$pat" ] && ! printf '%s' "$out" | grep -qE "$pat"; then
    fail=$((fail + 1)); printf '  FAIL  %s — exited %s but for the wrong reason\n' "$name" "$got"
    printf '        expected: %s\n' "$pat"; printf '%s\n' "$out" | sed 's/^/          /'; return
  fi
  # NO ABSOLUTE HOME PATHS, on any branch. This is the one that was got wrong.
  if printf '%s' "$out" | grep -qE '(/Users|/home)/[A-Za-z0-9._-]+'; then
    fail=$((fail + 1)); printf '  FAIL  %s — printed an absolute home path\n' "$name"
    printf '%s\n' "$out" | sed 's/^/          /'; return
  fi
  pass=$((pass + 1)); printf '  ok    %s\n' "$name"
}

echo "check-skill-sync.sh"

# In sync — the real installed copy, whatever it is on this machine.
_run "in sync passes" 0 "copies agree"

# Missing installed copy fails closed.
_run "missing installed copy blocks" 1 "installed copy is missing" \
  "ASSURANCE_SKILL_INSTALL_DIR=$work/absent"

# ...and the explicit opt-out passes, loudly.
_run "explicit opt-out passes" 0 "acknowledged" \
  "ASSURANCE_SKILL_INSTALL_DIR=$work/absent" "ASSURANCE_SKILL_NOT_INSTALLED=1"

# Drift blocks.
mkdir -p "$work/drifted/bootstrap-assurance"
{ cat "$here/skill/bootstrap-assurance/SKILL.md"; printf '\n<!-- drift -->\n'; } \
  > "$work/drifted/bootstrap-assurance/SKILL.md"
_run "drift blocks" 1 "have drifted" "ASSURANCE_SKILL_INSTALL_DIR=$work/drifted"

# REVIEW FINDING: an install dir outside $HOME printed in full, because the
# tilde helper only rewrote a literal $HOME prefix.
#
# THE FIXTURE HAS TO BE HOME-SHAPED. A `mktemp -d` path lives under /var or
# /tmp, so the absolute-path assertion never fires against it and this test
# passes whatever the script prints — verified by mutation: reverting the fix
# left these green until the paths below were made home-shaped. The directory
# does not need to exist; these branches only print it.
_run "install dir under another home prints no absolute path" 1 "" \
  "ASSURANCE_SKILL_INSTALL_DIR=/Users/someoneelse/skills"
_run "install dir under a linux home prints no absolute path" 1 "" \
  "ASSURANCE_SKILL_INSTALL_DIR=/home/someoneelse/skills"

# REVIEW FINDING: with HOME unset the case pattern degraded to /*, so every
# absolute path matched the tilde branch and printed with a ~ glued on.
_run "HOME unset prints no absolute path" 1 "" \
  "ASSURANCE_SKILL_INSTALL_DIR=/Users/someoneelse/skills" "HOME="
_run "HOME empty prints no absolute path" 1 "" \
  "ASSURANCE_SKILL_INSTALL_DIR=/home/someoneelse/skills" "HOME="

# Drift, with a home-shaped install dir, so the diff labels are covered too.
mkdir -p "$work/drifted/bootstrap-assurance"
_run "drift from a home-shaped dir prints no absolute path" 1 "have drifted" \
  "ASSURANCE_SKILL_INSTALL_DIR=$work/drifted" "HOME=$work"

echo
if [ "$fail" -gt 0 ]; then
  printf '❌ skill-sync tests: %s passed, %s FAILED\n' "$pass" "$fail"; exit 1
fi
printf '✅ skill-sync tests: %s passed\n' "$pass"
