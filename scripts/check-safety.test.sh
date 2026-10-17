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
#   * It passed standalone and FAILED inside a commit. Git exports the pending
#     commit's GIT_AUTHOR_* and GIT_COMMITTER_* to its hooks, and this suite runs
#     from one — so every fixture commit inherited the OUTER identity, overrode
#     the fixture's repo-local config, and was refused by the fixture's own gate.
#     Standalone there is no such environment, so neither the first run nor four
#     mutation tests could see it. check-skill-sync.test.sh records the same
#     shape. Every subshell that touches a fixture clears those variables first,
#     and the last case below locks it.
#
# PLANTED PATHS ARE CONSTRUCTED, NEVER WRITTEN. A fixture containing a literal
# home path would be caught by this repo's own scanner when this file is staged.
# Allowlisting this file by path was tried and rejected: a path-scoped allowlist
# suppresses REAL leaks in the same file, verified 2026-09-16. `printf` with the
# account name as an argument leaves the shape here and the instance only at
# runtime.
#
# THE PATTERNS-FILE CASES WRITE A FILE WITH THE NAME OF THE MAINTAINER'S REAL ONE
# — into a temp directory, with invented values, removed by the trap on exit.
# gates.test.sh does the same for the reference hook, and there is no other way to
# exercise the states that matter: absent, empty, still-example, armed. This suite
# never reads, writes or copies the file at the repository root.
#
# WITHOUT GITLEAKS, THE SCAN CASES SKIP — and say so, and are counted, as
# gates.test.sh does. The first version failed four cases on any machine without
# the scanner, which turned `sh scripts/run-checks.sh` red for a reader who only
# wanted to try it, contradicting the README that calls gitleaks optional there.
# The identity cases and every patterns-file STATE case still run without it: the
# gate refuses those before it looks for a scanner. A skipped case never reads as
# coverage that ran.
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
# PATH is the only place it can come from. A group of cases that share one guard
# passes its size, so the skip count stays the number of cases that did not run.
skipped=0
needs_scanner() {
  if command -v gitleaks >/dev/null 2>&1; then return 0; fi
  skipped=$((skipped + ${2:-1}))
  printf '  SKIP  %s — gitleaks not found (probe: command -v gitleaks, %s)\n' "$1" "$(date +%Y-%m-%d)"
  return 1
}

# The invented patterns file a fixture carries unless a case replaces it. The
# token is invented and appears in no rule of the committed config, so only the
# LOCAL pass can match it — which is what makes the local-layer case mean
# something.
write_local() {   # write_local <dir> <state>
  f="$1/.gitleaks.local.toml"
  case "$2" in
    armed)
      cat > "$f" <<'TOML'
[extend]
path = ".gitleaks.toml"

[[rules]]
id = "local-only"
description = "invented"
regex = '''LOCALLEAK-[0-9A-Z]{8}'''
TOML
      ;;
    empty)
      : > "$f" ;;
    extend-only)
      printf '[extend]\npath = ".gitleaks.toml"\n' > "$f" ;;
    commented-rule)
      printf '[extend]\npath = ".gitleaks.toml"\n# id = "personal-email"\n' > "$f" ;;
    comment-line)
      write_local "$1" armed
      printf '# the example used PLACEHOLDER, Firstname, Lastname and example.invalid\n' >> "$f" ;;
    marker-kept)
      printf '[extend]\npath = ".gitleaks.toml"\n\n[[rules]]\nid = "r"\ndescription = "d"\nregex = %sLOCALLEAK-[0-9A-Z]{8}%s # ASSURANCE-PLACEHOLDER\n' "'''" "'''" > "$f" ;;
    value:*)
      printf '[extend]\npath = ".gitleaks.toml"\n\n[[rules]]\nid = "r"\ndescription = "d"\nregex = %s%s%s\n' "'''" "${2#value:}" "'''" > "$f" ;;
  esac
}

# A fixture repo whose declared identity is fake and whose hook is the real
# script under test. The seed commit bypasses the hook deliberately — that is
# this repo's Phase-1 ordering rule, not a bypass of a gate for work. The
# patterns file is ignored, as in the real repo, so staging it takes a forced add.
mkfixture() {
  d="$work/$1"; mkdir -p "$d"
  ( clear_git_env; cd "$d" || exit 1
    git init -q .
    git config user.name "T Declared"
    git config user.email "declared@example.invalid"
    printf '# AGENTS\n\n**Commits only as `T Declared <declared@example.invalid>`**,\nfrom repo-local git config.\n' > AGENTS.md
    cp "$config" .gitleaks.toml
    printf '.gitleaks.local.toml\n' > .gitignore
    mkdir -p .githooks
    printf '#!/usr/bin/env sh\nsh "%s"\n' "$script" > .githooks/pre-commit
    chmod +x .githooks/pre-commit
    git config core.hooksPath .githooks
    git add AGENTS.md .gitleaks.toml .gitignore .githooks/pre-commit
    git -c core.hooksPath=/dev/null commit -qm seed )
  write_local "$d" armed
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

present() {   # present <name> <text that must appear> <output>
  if printf '%s' "$3" | grep -qF "$2"; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$1"
  else
    fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"
  fi
}

absent() {   # absent <name> <text that must not appear> <output>
  if printf '%s' "$3" | grep -qF "$2"; then
    fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"
  else
    pass=$((pass + 1)); printf '  ok    %s\n' "$1"
  fi
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

# ── The committed scan layer ────────────────────────────────────────────────
if needs_scanner "a staged absolute home path is refused" 3; then
in_fixture "$d" sh -c 'git reset -q --hard && printf "run: cd /Users/%s/project\n" "probeuser" > note.md && git add note.md'
check "a staged absolute home path is refused, by the committed rules" 1 "$d" "committed rules"
# The Finding line of a VERBOSE report reads `cd REDACTED<account>/project`: the
# rule's secret group is only the prefix. The account name must not be printed.
absent "a refused home path does not print the account name" "probeuser" "$out"
present "the refusal names the rule, file and line" "absolute-home-path note.md:1" "$out"
fi

if needs_scanner "an ordinary staged file is not refused"; then
in_fixture "$d" sh -c 'git reset -q --hard && printf "nothing suspicious\n" > note.md && git add note.md'
check "an ordinary staged file is not refused" 0 "$d" ""
fi

# ── The local scan layer ────────────────────────────────────────────────────
# A token only the LOCAL rule matches, so only the local pass can refuse it — and
# the refusal must name that rule, which is what proves which layer spoke.
if needs_scanner "a secret only the local layer matches is refused, by the local layer" 3; then
stage "$d" "k = LOCALLEAK-ABCD1234"
if out="$( in_fixture "$d" git commit -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "a secret only the local layer matches is refused, by the local layer" 1 "$got" "local patterns" "$out"
present "the refusal names the local rule, file and line" "local-only f.txt:1" "$out"
absent "the local layer's refusal does not print the secret" "ABCD1234" "$out"
fi

# No flag, in any spelling, gets a secret past the scan. Executed, not grepped.
if needs_scanner "SKIP=gitleaks does not get a secret through"; then
stage "$d" "k = LOCALLEAK-ABCD1234"
check "SKIP=gitleaks does not get a secret through" 1 "$d" "local patterns" SKIP=gitleaks
fi

# ── The patterns file, every state ──────────────────────────────────────────
# All of these refuse BEFORE the gate looks for a scanner, so none needs one.
p="$(mkfixture missing)"
in_fixture "$p" rm -f .gitleaks.local.toml
stage "$p" x
check "a missing patterns file blocks" 1 "$p" "gitleaks.local.toml is missing"

for state in empty extend-only commented-rule; do
  s="$(mkfixture "state-$state")"; write_local "$s" "$state"; stage "$s" x
  check "a patterns file that is '$state' defines no rules, and blocks" 1 "$s" "defines no rules"
done

# ONE CASE PER VALUE, not one per file. Whole-file fixtures stay green while a
# single alternative in the pattern goes dead — `example\.invalid` in particular,
# which is only matched by the bracket expression, not by the plain spelling.
i=0
for v in 'PLACEHOLDER' 'someone@example.invalid' 'someone@example\.invalid' 'Firstname' 'Lastname'; do
  i=$((i + 1))
  s="$(mkfixture "value-$i")"; write_local "$s" "value:$v"; stage "$s" x
  check "the example value '$v' alone blocks" 1 "$s" "example placeholders"
done

s="$(mkfixture marker-kept)"; write_local "$s" marker-kept; stage "$s" x
check "a replaced value with the marker comment still on its line blocks" 1 "$s" "example placeholders"

# The same pattern from the other side: prose that NAMES the tokens, on a line of
# its own, must not jam a file that is correctly filled in.
if needs_scanner "a comment that names the example tokens does not jam a correct file"; then
s="$(mkfixture comment-line)"; write_local "$s" comment-line; stage "$s" x
check "a comment that names the example tokens does not jam a correct file" 0 "$s" ""
fi

# A scanner that cannot run is neither clean nor a leak. The file below passes
# every state check — it has an id and no example values — and is not valid TOML.
if needs_scanner "an unusable patterns file blocks as a scanner failure, not a leak" 2; then
s="$(mkfixture bad-toml)"
printf '[extend]\npath = ".gitleaks.toml"\nid = "r"\nthis is [not valid\n' > "$s/.gitleaks.local.toml"
stage "$s" x
if out="$( in_fixture "$s" git commit -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "an unusable patterns file blocks as a scanner failure, not a leak" 1 "$got" "could not run" "$out"
absent "a scanner failure does not quote the config" "not valid" "$out"
fi

# ── Never commit the patterns file ──────────────────────────────────────────
sg="$(mkfixture staged)"
in_fixture "$sg" sh -c 'printf "x\n" > f.txt && git add f.txt && git add -f .gitleaks.local.toml'
if out="$( in_fixture "$sg" git commit -qm t 2>&1 )"; then got=0; else got=$?; fi
verdict "a staged patterns file is refused" 1 "$got" "is staged for commit" "$out"

# The remedy it prints must work as printed — run it, then commit.
if needs_scanner "the printed unstage command works as printed"; then
cmd="$(printf '%s\n' "$out" | grep -E '^     git rm --cached ' | head -1 | sed 's/^ *//')"
if [ -z "$cmd" ]; then
  fail=$((fail + 1)); printf '  FAIL  %s\n' "the printed unstage command works as printed — it printed no command"
else
  in_fixture "$sg" sh -c "$cmd" >/dev/null 2>&1 || true
  check "the printed unstage command works as printed" 0 "$sg" ""
fi
fi

# Removing a file that was committed by mistake must not itself be refused: the
# gate lets a staged DELETION through. A comment saying so is a claim; this is the
# test of it.
if needs_scanner "removing a mistakenly committed patterns file is not refused"; then
r="$(mkfixture removal)"
in_fixture "$r" sh -c 'git add -f .gitleaks.local.toml && git -c core.hooksPath=/dev/null commit -qm oops && git rm -q --cached .gitleaks.local.toml'
check "removing a mistakenly committed patterns file is not refused" 0 "$r" ""
fi

# ── The printed self-test runs as printed ───────────────────────────────────
# Taken from what the gate actually PRINTS, filled with invented values, and
# executed against an invented four-rule file. Section 3 of gates.test.sh only
# checks the reference's equivalent PARSES; a block that parses and prints nothing
# useful is the failure this guards, and the maintainer is the one who finds it.
if needs_scanner "the printed self-test runs as printed and lists every rule id"; then
t="$(mkfixture selftest)"
in_fixture "$t" rm -f .gitleaks.local.toml
stage "$t" x
if out="$( in_fixture "$t" git commit -qm t 2>&1 )"; then :; fi
probe="$(printf '%s\n' "$out" | awk '/^     \($/{p=1} p{print} /^     \)$/{p=0}')"
filled="$(printf '%s\n' "$probe" | sed \
  -e 's|<your real email>|inventedperson@invented-domain.test|' \
  -e 's|<your real domain>|invented-domain.test|' \
  -e 's|<your real username>|inventeduser|' \
  -e 's|<Your Real Name>|Invented Person|')"
cat > "$t/.gitleaks.local.toml" <<'TOML'
[extend]
path = ".gitleaks.toml"

[[rules]]
id = "personal-email"
description = "invented"
regex = '''inventedperson@invented-domain\.test'''

[[rules]]
id = "personal-email-domain"
description = "invented"
regex = '''[A-Za-z0-9._%+-]+@invented-domain\.test'''

[[rules]]
id = "home-directory-path"
description = "invented"
regex = '''(/Users/|/home/)inventeduser'''

[[rules]]
id = "real-name"
description = "invented"
regex = '''(?i)Invented\s+Person'''
TOML
# VERIFY THE FIXTURE CHANGED. An empty extraction, or a placeholder the sed did
# not reach, would let this case "run" a block that does nothing.
sound=1
[ -n "$probe" ] || sound=0
case "$filled" in *"gitleaks dir"*) ;; *) sound=0 ;; esac
case "$filled" in *"<your real"*|*"<Your Real"*) sound=0 ;; esac
if [ "$sound" = 1 ]; then
  if result="$( in_fixture "$t" sh -c "$filled" 2>&1 )"; then :; fi
  missing=""
  for id in personal-email personal-email-domain home-directory-path real-name absolute-home-path; do
    printf '%s' "$result" | grep -q "\"$id\"" || missing="$missing $id"
  done
  if [ -z "$missing" ]; then
    pass=$((pass + 1)); printf '  ok    %s\n' "the printed self-test runs as printed and lists every rule id"
  else
    fail=$((fail + 1)); printf '  FAIL  %s — missing:%s\n' "the printed self-test runs as printed and lists every rule id" "$missing"
  fi
else
  fail=$((fail + 1)); printf '  FAIL  %s — the block was not extracted or not filled in\n' "the printed self-test runs as printed and lists every rule id"
fi
fi

# ── Fail-closed: comparing nothing must never read as clean ─────────────────
tw="$(mkfixture twodecl)"
in_fixture "$tw" sh -c 'printf "\n**Commits only as \`Other Name <other@example.invalid>\`**,\n" >> AGENTS.md && git add AGENTS.md && git -c core.hooksPath=/dev/null commit -qm x'
stage "$tw" x
check "two declaration lines block rather than picking one" 1 "$tw" "cannot be read"

m="$(mkfixture nodecl)"
in_fixture "$m" sh -c 'printf "# AGENTS\n\nno declaration here\n" > AGENTS.md && git add AGENTS.md && git -c core.hooksPath=/dev/null commit -qm x'
stage "$m" x
check "an unparseable declaration blocks" 1 "$m" "cannot be read"

n="$(mkfixture noconfig)"
in_fixture "$n" sh -c 'rm .gitleaks.toml && git add -A && git -c core.hooksPath=/dev/null commit -qm x'
stage "$n" x
check "a missing committed scanner config blocks" 1 "$n" "gitleaks.toml is missing"

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
