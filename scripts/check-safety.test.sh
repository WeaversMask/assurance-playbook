#!/usr/bin/env sh
# Regression tests for `.githooks/safety-checks.sh` — the safety class applied to
# this repository (TRACKER.md, D-004).
#
# WHY THIS EXISTS. quality-gates.md invariant 14: a gate that can be silently
# narrowed owes a regression test. This one can be narrowed in two directions at
# once — it can stop refusing what it should refuse, or start refusing
# everything — and the second is not hypothetical:
#
#   * The first draft detected the identity declaration with one regex and
#     extracted it with a narrower one that rejected any name containing a
#     space. The declaration was visible but unreadable, so the gate blocked
#     every commit. `WeaversMask` has no space; a fixture named "T Declared"
#     found it on the first run. Every fixture here therefore uses a name WITH a
#     space.
#   * A case named for `git -c user.email` ran a plain commit with no override
#     at all — it passed as long as anything was wrong, and failed the moment
#     nothing was. `-c` is a git option, not an environment variable, so it
#     cannot go through the env harness and gets its own invocation.
#
# PLANTED PATHS ARE CONSTRUCTED, NEVER WRITTEN. A fixture containing a literal
# home path would be caught by this repo's own scanner when this file is staged.
# Allowlisting this file by path was tried and rejected: a path-scoped allowlist
# suppresses REAL leaks in the same file, verified 2026-09-16. `printf` with the
# account name as an argument leaves the shape here and the instance only at
# runtime.
#
#   * It passed standalone and FAILED inside a commit. Git exports the pending
#     commit's GIT_AUTHOR_* and GIT_COMMITTER_* to its hooks, and this suite runs
#     from one — so every fixture commit inherited the OUTER identity, overrode
#     the fixture's repo-local config, and was refused by the fixture's own gate.
#     Standalone there is no such environment, so neither the first run nor four
#     mutation tests could see it. check-skill-sync.test.sh records the same
#     shape. Every subshell that touches a fixture clears those variables first,
#     and the last case below locks it.
#
# WITHOUT GITLEAKS, THE SCAN CASES SKIP — and say so, and are counted, as
# gates.test.sh does. The first version failed four cases on any machine without
# the scanner, which turned `sh scripts/run-checks.sh` red for a reader who only
# wanted to try it, contradicting the README that calls gitleaks optional there.
# The identity cases still run without it: the gate refuses those before it
# looks for a scanner. A skipped case never reads as coverage that ran.
#
# Run: sh scripts/check-safety.test.sh

set -e

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
script="$root/.githooks/safety-checks.sh"
config="$root/.gitleaks.toml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

pass=0
fail=0

# Cleared inside each fixture subshell rather than once at the top, so that the
# suite's OWN environment can still carry a stray value — which is what the
# hermeticity case at the end needs in order to mean anything. GIT_DIR and
# GIT_INDEX_FILE matter as much as the identity ones: inherited from a hook they
# point at the repository being committed, not at the fixture.
clear_git_env() {
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE \
        GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE \
        GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX GIT_CONFIG_PARAMETERS
}

# Runs a command inside a fixture, with the caller's git environment cleared.
in_fixture() { d="$1"; shift; ( clear_git_env; cd "$d" || exit 1; "$@" ); }

# The scanner the gate will find inside a fixture. Fixtures have no .bin/, so
# PATH is the only place it can come from.
skipped=0
needs_scanner() {
  if command -v gitleaks >/dev/null 2>&1; then return 0; fi
  skipped=$((skipped + 1))
  printf '  SKIP  %s — gitleaks not found (probe: command -v gitleaks, %s)\n' "$1" "$(date +%Y-%m-%d)"
  return 1
}

# A fixture repo whose declared identity is fake and whose hook is the real
# script under test. The seed commit bypasses the hook deliberately — that is
# this repo's Phase-1 ordering rule, not a bypass of a gate for work.
mkfixture() {
  d="$work/$1"; mkdir -p "$d"
  ( clear_git_env; cd "$d" || exit 1
    git init -q .
    git config user.name "T Declared"
    git config user.email "declared@example.invalid"
    printf '# AGENTS\n\n**Commits only as `T Declared <declared@example.invalid>`**,\nfrom repo-local git config.\n' > AGENTS.md
    cp "$config" .gitleaks.toml
    mkdir -p .githooks
    printf '#!/usr/bin/env sh\nsh "%s"\n' "$script" > .githooks/pre-commit
    chmod +x .githooks/pre-commit
    git config core.hooksPath .githooks
    git add AGENTS.md .gitleaks.toml .githooks/pre-commit
    git -c core.hooksPath=/dev/null commit -qm seed )
  printf '%s' "$d"
}

stage() { in_fixture "$1" sh -c 'git reset -q --hard && printf "%s\n" "$1" > f.txt && git add f.txt' _ "$2"; }

# Every assertion below TESTS the command rather than running it bare. `set -e`
# fires on an untested failure, so the first case where the gate correctly
# refuses would kill this suite with no summary — the trap three suites in this
# repo have already hit.
check() {   # check <name> <wanted 0|1> <dir> <message-fragment-or-empty> [env...]
  name="$1"; want="$2"; d="$3"; frag="$4"; shift 4
  if out="$( in_fixture "$d" env "$@" git commit -qm t 2>&1 )"; then got=0; else got=$?; fi
  verdict "$name" "$want" "$got" "$frag" "$out"
}

verdict() {  # verdict <name> <want> <got> <frag> <out>
  n="$1"; w="$2"; g="$3"; f="$4"; o="$5"
  if { [ "$w" = 0 ] && [ "$g" != 0 ]; } || { [ "$w" != 0 ] && [ "$g" = 0 ]; }; then
    fail=$((fail + 1)); printf '  FAIL  %s — wanted exit %s, got %s\n' "$n" "$w" "$g"
    printf '%s\n' "$o" | sed 's/^/          /' | head -4; return
  fi
  # ASSERT THE MESSAGE, NOT ONLY THE CODE. Every refusal here exits 1, so a case
  # that checked the code alone would pass for any reason at all.
  if [ -n "$f" ] && ! printf '%s' "$o" | grep -q "$f"; then
    fail=$((fail + 1)); printf '  FAIL  %s — refused for a different reason than it names\n' "$n"
    printf '        wanted: %s\n' "$f"; printf '%s\n' "$o" | sed 's/^/          /' | head -4; return
  fi
  # CONTENT-FREE OUTPUT, on every branch. This output is pasted into handovers.
  if printf '%s' "$o" | grep -qE '(/Users|/home)/[A-Za-z0-9._-]+'; then
    fail=$((fail + 1)); printf '  FAIL  %s — printed an absolute home path\n' "$n"; return
  fi
  pass=$((pass + 1)); printf '  ok    %s\n' "$n"
}

echo "safety-checks.sh"

d="$(mkfixture ok)"

if needs_scanner "a clean commit passes, with a space in the declared name"; then
stage "$d" one
check "a clean commit passes, with a space in the declared name" 0 "$d" ""
fi

stage "$d" two
if out="$( in_fixture "$d" git -c user.email=w@example.invalid commit -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "git -c user.email is refused" 1 "$got" "author does not match" "$out"

stage "$d" three
if out="$( in_fixture "$d" git -c user.name='Wrong Name' commit -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "git -c user.name is refused" 1 "$got" "author does not match" "$out"

stage "$d" four
check "GIT_AUTHOR_EMAIL is refused" 1 "$d" "author does not match" GIT_AUTHOR_EMAIL=w@example.invalid

# The committer half specifically: a hook that checked only the author would let
# this through silently, which is the live finding invariant 2 records.
stage "$d" five
check "GIT_COMMITTER_EMAIL is refused, and names the committer" 1 "$d" "committer does not match" GIT_COMMITTER_EMAIL=w@example.invalid

stage "$d" six
if out="$( in_fixture "$d" git commit --author='Someone Else <e@example.invalid>' -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "--author= is refused" 1 "$got" "author does not match" "$out"

# ── The scan layer ──────────────────────────────────────────────────────────
if needs_scanner "a staged absolute home path is refused"; then
in_fixture "$d" sh -c 'git reset -q --hard && printf "run: cd /Users/%s/project\n" "probeuser" > note.md && git add note.md'
check "a staged absolute home path is refused" 1 "$d" "leaks found"
fi

if needs_scanner "an ordinary staged file is not refused"; then
in_fixture "$d" sh -c 'git reset -q --hard && printf "nothing suspicious\n" > note.md && git add note.md'
check "an ordinary staged file is not refused" 0 "$d" ""
fi

# ── Fail-closed: comparing nothing must never read as clean ─────────────────
t="$(mkfixture twodecl)"
in_fixture "$t" sh -c 'printf "\n**Commits only as \`Other Name <other@example.invalid>\`**,\n" >> AGENTS.md && git add AGENTS.md && git -c core.hooksPath=/dev/null commit -qm x'
stage "$t" x
check "two declaration lines block rather than picking one" 1 "$t" "cannot be read"

m="$(mkfixture nodecl)"
in_fixture "$m" sh -c 'printf "# AGENTS\n\nno declaration here\n" > AGENTS.md && git add AGENTS.md && git -c core.hooksPath=/dev/null commit -qm x'
stage "$m" x
check "an unparseable declaration blocks" 1 "$m" "cannot be read"

n="$(mkfixture noconfig)"
in_fixture "$n" sh -c 'rm .gitleaks.toml && git add -A && git -c core.hooksPath=/dev/null commit -qm x'
if needs_scanner "a missing committed scanner config blocks"; then
stage "$n" x
check "a missing committed scanner config blocks" 1 "$n" "gitleaks.toml is missing"
fi

# PATH without gitleaks. The fixture has no .bin/gitleaks either, so both
# resolution branches fail and the scan cannot run.
g="$(mkfixture nogitleaks)"
stage "$g" x
if out="$( in_fixture "$g" env PATH=/usr/bin:/bin git commit -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "a missing scanner blocks rather than skipping" 1 "$got" "gitleaks not found" "$out"

# ── Hermeticity: the regression that only appeared inside a commit ──────────
# With a stray identity in THIS process's environment — exactly what a hook
# inherits — a fixture commit must still be judged on the fixture's own config.
GIT_AUTHOR_EMAIL=outer@example.invalid
GIT_COMMITTER_EMAIL=outer@example.invalid
export GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL
if needs_scanner "a stray identity in the environment does not reach a fixture"; then
stage "$d" hermetic
check "a stray identity in the environment does not reach a fixture" 0 "$d" ""
fi
unset GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL

echo
if [ "$fail" -gt 0 ]; then printf '❌ safety: %s passed, %s FAILED\n' "$pass" "$fail"; exit 1; fi
if [ "$skipped" -gt 0 ]; then
  printf '✅ safety: %s passed, %s SKIPPED — the scan cases did not run\n' "$pass" "$skipped"
else
  printf '✅ safety: %s passed\n' "$pass"
fi
