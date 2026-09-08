#!/usr/bin/env sh
# Regression tests for the two gates in this reference that have been broken by
# their own fixes, repeatedly.
#
# WHY THIS EXISTS. `quality-gates.md` invariant 14: a gate that can be silently
# narrowed owes a regression test. Proving a gate once proves it was installed,
# not that its behaviour survives the next edit. Both gates below were proven
# once, by hand, with fixtures written in the same session as the code — and
# each was then broken by a later fix, four times between them, including a
# regression that would have blocked the first commit of every bootstrapped
# repo. Ad-hoc verification kept failing for the same reason every time: the
# fixtures came from the same mental model as the code, so they exercised what
# the author imagined rather than what the templates actually produce.
#
# THE RULE THIS ENCODES: **every case here is one a review found, not one the
# author thought of.** When a review finds another, it is added here before it
# is fixed. That is what makes this a ratchet rather than a snapshot.
#
# TWO TRAPS THIS SUITE HAS ALREADY FALLEN INTO, both of which made a case pass
# for the wrong reason:
#
#   * A fixture that trips an EARLIER branch than the one it names. Assert the
#     message, not only the exit code.
#   * An assertion pattern that also matches the failure FOOTER. Every failure
#     prints "A trigger that has passed without the row being answered…", so a
#     case grepping for "has passed" matched on any failure whatsoever and could
#     not tell one branch from another. Patterns name the trigger token.
#
# AND ONE ABOUT TESTING THIS SUITE: when mutating a gate to check the suite
# notices, revert with a FILE COPY, never `git checkout --`. That reverts to the
# committed state and silently destroys uncommitted work in the same file —
# which it did, to two fixes, mid-verification.
#
# Fixtures are built at run time in a temp dir, never committed. In particular
# no file in this repository is ever named `.gitleaks.local.toml` — the local
# config states are written under that name only inside the temp dir, because
# an agent must never create that file in a real tree.
#
# Run: sh reference/node-pnpm/test/gates.test.sh

set -e

here="$(cd "$(dirname "$0")" && pwd)"
ref="$(dirname "$here")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

pass=0
fail=0

tmpl="$ref/../../templates"
# Every external input this suite reads gets the same guard. One of the three
# had it and two did not, so moving either template made the suite die under
# `set -e` after nineteen green ticks, with no summary line and no count —
# non-zero, so a hook blocks, but anyone skimming sees only the ticks.
for needed in \
  "$ref/hooks/pre-commit" \
  "$ref/scripts/check-decisions.mjs" \
  "$tmpl/gitleaks.local.example.toml" \
  "$tmpl/IMPLEMENTATION.skeleton.md"; do
  [ -f "$needed" ] || { printf '❌ gates: required input missing: %s\n' "$needed"; exit 1; }
done

# expect <name> <wanted-rc> <cmd...>
# expect_msg <name> <wanted-rc> <grep-pattern> <cmd...>
#
# A BLOCK IS NOT A PASS. An exit code alone says something refused, not that the
# check under test refused — and a fixture can easily trip an earlier branch
# instead. That is not hypothetical here: a mutation removing the missing-
# completed-section branch left this suite green, because the fixture meant to
# reach it failed one branch earlier on an unresolvable id. Where the distinction
# matters, assert the message.
_check() {
  name="$1"; want="$2"; pat="$3"; shift 3
  out="$("$@" 2>&1)" && got=0 || got=$?
  if [ "$got" -ne "$want" ]; then
    fail=$((fail + 1))
    printf '  FAIL  %s — wanted exit %s, got %s\n' "$name" "$want" "$got"
    printf '%s\n' "$out" | sed 's/^/          /'
    return
  fi
  if [ -n "$pat" ] && ! printf '%s' "$out" | grep -qE "$pat"; then
    fail=$((fail + 1))
    printf '  FAIL  %s — exited %s but for the wrong reason\n' "$name" "$got"
    printf '        expected output matching: %s\n' "$pat"
    printf '%s\n' "$out" | sed 's/^/          /'
    return
  fi
  if printf '%s' "$out" | grep -qE '(/Users|/home)/[A-Za-z0-9._-]+'; then
    fail=$((fail + 1))
    printf '  FAIL  %s — printed an absolute home path\n' "$name"
    printf '%s\n' "$out" | sed 's/^/          /'
    return
  fi
  pass=$((pass + 1))
  printf '  ok    %s\n' "$name"
}

expect() { name="$1"; want="$2"; shift 2; _check "$name" "$want" "" "$@"; }
expect_msg() { _check "$@"; }

# ═══════════════════════════════════════════════════════════════════════════
# 1. check-decisions.mjs
# ═══════════════════════════════════════════════════════════════════════════
echo "check-decisions.mjs"

d="$work/decisions"
mkdir -p "$d/scripts" "$d/docs"
cp "$ref/scripts/check-decisions.mjs" "$d/scripts/"
run_decisions() { node "$d/scripts/check-decisions.mjs"; }

tracker() { cat > "$d/docs/IMPLEMENTATION.md"; }

# The header every fixture shares: a resolvable phase and a completed task.
HEAD_OK='## Current state
- **Phase:** P1-04 — building

## Recently completed
| ID | Task | PR | Merged |
| --- | --- | --- | --- |
| T-001 | shipped a thing | #12 | 2026-09-01 |

## Open decisions
| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |'

tracker <<EOF
$HEAD_OK
| D-000 | open | — | P3-start | 2026-09-01 |
EOF
expect "trigger not yet due passes" 0 run_decisions

tracker <<EOF
$(printf '%s' "$HEAD_OK" | sed 's/P1-04/P3-02/')
| D-000 | open | — | P1-start | 2026-09-01 |
EOF
expect "passed phase boundary blocks" 1 run_decisions

tracker <<EOF
$HEAD_OK
| D-000 | open | — | 2026-01-01 | 2026-09-01 |
EOF
expect "passed date blocks" 1 run_decisions

# REVIEW FINDING: completion was tested per line for a word list, so a tracker
# whose completed rows carry no tick — which is the shape the template ships —
# read every completed-id trigger as unfired.
tracker <<EOF
$HEAD_OK
| D-000 | open | — | T-001 | 2026-09-01 |
EOF
expect_msg "completed task id blocks (tickless rows)" 1 "trigger .T-001. has completed" run_decisions

# REVIEW FINDING: the completed section was resolved by heading, and a miss
# produced an empty set silently — the same silent pass, one layer up.
tracker <<'EOF'
## Current state
- **Phase:** P1-04 — building
## Done this week
| ID | Task | PR | Merged |
| --- | --- | --- | --- |
| T-001 | shipped | #12 | 2026-09-01 |
## Open decisions
| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |
| D-000 | open | — | T-001 | 2026-09-01 |
EOF
expect_msg "renamed completed section blocks" 1 "no task id" run_decisions

# ...and the fixture above blocks one branch EARLIER, on the id not resolving.
# The missing-section branch needs a trigger that DOES resolve, with no completed
# section to resolve it against — otherwise that branch is never exercised and a
# mutation removing it leaves this suite green. It did, once.
tracker <<'EOF'
## Current state
- **Phase:** P1-04 — building
## Up next
| ID | Task | Depends on | Notes |
| --- | --- | --- | --- |
| T-001 | do a thing | — | — |
## Open decisions
| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |
| D-000 | open | — | T-001 | 2026-09-01 |
EOF
expect_msg "resolvable id, no completed section, blocks" 1 "no .Recently completed. section" run_decisions

# REVIEW FINDING: dropping the id regex made any first-column cell resolvable,
# so a decision id became a trigger that could never fire.
tracker <<EOF
$HEAD_OK
| D-000 | tier | — | 2027-01-01 | 2026-09-01 |
| D-001 | wait on D-000 | — | D-000 | 2026-09-01 |
EOF
expect_msg "decision id is not a usable trigger" 1 "no task id" run_decisions

# REVIEW FINDING: the phase was resolved eagerly, locking out tier-1 projects
# whose triggers are all dates and which therefore have no phases.
tracker <<'EOF'
## Current state
- **Phase:** 0 — Foundation (tier 1, no phases yet)
## Open decisions
| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |
| D-000 | tier 1 | — | 2099-01-01 | 2026-09-07 |
EOF
expect "no phase needed, none demanded" 0 run_decisions

# REVIEW FINDING: the first phase-shaped token anywhere won, so a stale one
# read as current and the gate passed while printing it.
tracker <<'EOF'
## Current state
- **Phase:** finishing P1-17, now entering P3-01
## Open decisions
| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |
| D-000 | open | — | P2-start | 2026-09-01 |
EOF
expect_msg "ambiguous phase line blocks" 1 "phase tokens" run_decisions

tracker <<EOF
$HEAD_OK
| D-000 | open | — | standing | 2026-09-01 |
EOF
expect "standing warns and passes" 0 run_decisions

tracker <<EOF
$HEAD_OK
| D-000 | open | — |  | 2026-09-01 |
EOF
expect "open row with no trigger blocks" 1 run_decisions

tracker <<EOF
$HEAD_OK
| D-000 | open | — | until Vite 8 helps | 2026-09-01 |
EOF
expect "prose trigger blocks" 1 run_decisions

tracker <<EOF
$HEAD_OK
| D-000 | open | — | T-999 | 2026-09-01 |
EOF
expect "unresolvable id blocks" 1 run_decisions

tracker <<EOF
$HEAD_OK
| D-000 | **Closed 2026-09-07** — answered | — | P1-start | 2026-09-01 |
| D-001 | open | — | P9-exit | 2026-09-01 |
EOF
expect "closed rows are skipped" 0 run_decisions

tracker <<EOF
$HEAD_OK
| **D-000** | missing cells |
EOF
expect "malformed row is reported, not skipped" 1 run_decisions

tracker <<'EOF'
## Current state
- **Phase:** P1-04
EOF
expect "missing section blocks" 1 run_decisions

tracker <<EOF
$HEAD_OK
EOF
expect "zero rows blocks" 1 run_decisions

rm -f "$d/docs/IMPLEMENTATION.md"
expect "missing tracker blocks" 1 run_decisions

# THE ONE THAT MATTERED MOST: the gate must run against the template this repo
# actually ships. It did not, for the whole of its first life.
sed -e 's/{{TIER}}/2/' -e 's/{{WHY}}/mixed/' -e 's/{{DATE_OR_PHASE}}/2099-01-01/' \
    -e 's/{{DATE}}/2026-09-07/' \
    "$tmpl/IMPLEMENTATION.skeleton.md" > "$d/docs/IMPLEMENTATION.md"
expect "the shipped tracker template runs" 0 run_decisions

# ─── Cases added because a mutation survived without them ──────────────────

# m1: the script's own header calls this its central design decision — detection
# looser than parsing, so a row that will not parse is REPORTED. Dropping the
# bold-tolerance from DECISION_LINE left the suite green, because the case named
# for it had a single-row fixture and asserted the exit code only: the mutant
# exited 1 through the ZERO-ROWS branch instead. A healthy row beside it is what
# makes the branch observable.
tracker <<EOF
$HEAD_OK
| D-000 | fine | — | 2099-01-01 | 2026-09-01 |
| **D-001** | missing cells |
EOF
expect_msg "bolded malformed row beside a healthy one is reported" 1 "will not parse" run_decisions

# m2: no fixture had a fired `-exit` trigger, so half the phase vocabulary was
# unexercised and `p.major > major` could be replaced with `false`.
tracker <<EOF
$(printf '%s' "$HEAD_OK" | sed 's/P1-04/P3-02/')
| D-000 | open | — | P2-exit | 2026-09-01 |
EOF
expect_msg "a fired phase-exit trigger blocks" 1 "trigger .P2-exit. has passed" run_decisions

tracker <<EOF
$(printf '%s' "$HEAD_OK" | sed 's/P1-04/P2-07/')
| D-000 | open | — | P2-exit | 2026-09-01 |
EOF
expect "an unfired phase-exit trigger passes" 0 run_decisions

# m14: `token <= today` could become `<` — a trigger dated today never fires.
tracker <<EOF
$HEAD_OK
| D-000 | open | — | $(date -u +%Y-%m-%d) | 2026-09-01 |
EOF
expect_msg "a trigger dated today has passed" 1 "trigger date .* has passed" run_decisions

# m13: CLOSED could drop its date requirement, so a bare "Closed" closes a row.
tracker <<EOF
$HEAD_OK
| D-000 | **Closed** — no date | — |  | 2026-09-01 |
EOF
expect_msg "a closure with no date does not close a row" 1 "no trigger" run_decisions

# m8: `standing` is an escape hatch whose only mitigation is being visible.
# Deleting the notice made those rows pass in total silence.
tracker <<EOF
$HEAD_OK
| D-000 | open | — | standing | 2026-09-01 |
EOF
expect_msg "a standing row is announced, not silent" 0 "STANDING" run_decisions

# m15: TASK_SECTIONS could drop `in progress` and `blocked` unnoticed, because
# every fixture put its task in Up next or Recently completed. A trigger naming
# work that is in progress is the ordinary case.
tracker <<'EOF'
## Current state
- **Phase:** P1-04 — x
## In progress
| ID | Task | Owner | Branch |
| --- | --- | --- | --- |
| T-007 | mid-flight | agent | t-007-slug |
## Recently completed
| ID | Task | PR | Merged |
| --- | --- | --- | --- |
| T-001 | shipped | #12 | 2026-09-01 |
## Open decisions
| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |
| D-000 | open | — | T-007 | 2026-09-01 |
EOF
expect "a trigger naming in-progress work resolves" 0 run_decisions

# m3: every fixture had Trigger at the same index, so reading the header rather
# than a fixed column was an untested claim.
tracker <<'EOF'
## Current state
- **Phase:** P1-04 — x
## Open decisions
| ID | Trigger | Decision needed | Recommendation | Raised |
| --- | --- | --- | --- | --- |
| D-000 | 2026-01-01 | open | — | 2026-09-01 |
EOF
expect_msg "the Trigger column is found by header, not index" 1 "trigger date 2026-01-01 has passed" run_decisions

# m4: the inline `**Trigger:**` form is documented as still in use.
tracker <<'EOF'
## Current state
- **Phase:** P3-01 — x
## Open decisions
| ID | Decision needed | Recommendation | Raised |
| --- | --- | --- | --- |
| D-000 | old-style row | — **Trigger:** P1-start | 2026-09-01 |
EOF
expect_msg "the inline Trigger form still parses" 1 "trigger .P1-start. has passed" run_decisions

# ═══════════════════════════════════════════════════════════════════════════
# 2. The pre-commit local-config states
# ═══════════════════════════════════════════════════════════════════════════
echo
echo "pre-commit: local personal-identifier config states"

h="$work/hook"
mkdir -p "$h"
# Extract the block under test. Fail closed if the anchors move: a test that
# silently exercises nothing is the failure this whole file is about.
awk '/^# TWO FAILURES, NOT ONE/,/^fi$/' "$ref/hooks/pre-commit" > "$h/block.sh"
if [ ! -s "$h/block.sh" ] || ! grep -q 'gitleaks.local.toml' "$h/block.sh"; then
  echo "  FAIL  could not extract the identity block from hooks/pre-commit"
  echo "        (its anchor comment moved — fix this extraction, do not skip it)"
  exit 1
fi
{ printf 'repo_root="$1"\n'; cat "$h/block.sh"; printf '\nexit 0\n'; } > "$h/probe.sh"
run_block() { sh "$h/probe.sh" "$1"; }

example="$tmpl/gitleaks.local.example.toml"

state() {                       # state <name> [awk-program]
  mkdir -p "$h/$1"
  printf 'title = "committed"\n' > "$h/$1/.gitleaks.toml"
}

# A config filled in the way BOOTSTRAP documents: copy the example, replace the
# four values, delete the markers, keep the header and footer.
fill() {
  awk -v skip4="${SKIP4:-}" '
    /^regex = / {
      sub(/ # ASSURANCE-PLACEHOLDER/, "")
      n++
      if (n == 1) $0 = "regex = '\''real\\.user@somewhere\\.test'\''"
      else if (n == 2) $0 = "regex = '\''[A-Za-z0-9._%+-]+@somewhere\\.test'\''"
      else if (n == 3) $0 = "regex = '\''(/Users/someuser|/home/someuser)'\''"
      else if (n == 4 && skip4 == "") $0 = "regex = '\''(?i)Realfirst\\s+Reallast'\''"
    }
    { print }' "$example"
}

state armed;      fill > "$h/armed/.gitleaks.local.toml"
expect "a correctly filled config passes" 0 run_block "$h/armed"

# REVIEW FINDING, and a regression: the pattern matched anywhere in the file, so
# the example's own heading rejected a correctly filled config — blocking the
# first commit of every bootstrapped repo.
state armed_cmt
{ fill; printf '\n# note: replaced the Firstname/Lastname PLACEHOLDER example.invalid rule\n'; } \
  > "$h/armed_cmt/.gitleaks.local.toml"
expect "comments naming the tokens do not jam it" 0 run_block "$h/armed_cmt"

state unedited;   cp "$example" "$h/unedited/.gitleaks.local.toml"
expect "the unedited example blocks" 1 run_block "$h/unedited"

# REVIEW FINDING: the marker is a trailing comment, separable from the value.
state stripped;   sed 's/ # ASSURANCE-PLACEHOLDER//' "$example" > "$h/stripped/.gitleaks.local.toml"
expect_msg "markers deleted, values kept, blocks" 1 "example placeholders" run_block "$h/stripped"

# REVIEW FINDING: the real-name alternative could not match its own example.
state partly;     SKIP4=1 fill > "$h/partly/.gitleaks.local.toml"; SKIP4=
expect_msg "one rule left as the example blocks" 1 "example placeholders" run_block "$h/partly"

# REVIEW FINDING: `example\.invalid` could not match the example's own
# `your\.name@example\.invalid` — a literal backslash sits between `example` and
# the dot — so BOTH email rules could be left as shipped and pass, with the
# personal-email layer armed against a fake address. The one partial-fill
# fixture left rule 4 unfilled, which is one of the two the pattern DID reach:
# it was shaped around the working half.
state emails_unfilled
awk '/^regex = /{sub(/ # ASSURANCE-PLACEHOLDER/,""); n++
  if (n==3) $0="regex = QQ(/Users/someuser|/home/someuser)QQ"
  else if (n==4) $0="regex = QQ(?i)Realfirst\\s+ReallastQQ"}
  {print}' "$example" | sed "s/QQ/'/g" > "$h/emails_unfilled/.gitleaks.local.toml"
expect_msg "both email rules left as the example blocks" 1 "example placeholders" \
  run_block "$h/emails_unfilled"

# REVIEW FINDING: an existing file is not an armed file.
state empty;      : > "$h/empty/.gitleaks.local.toml"
expect_msg "an empty config blocks" 1 "defines no rules" run_block "$h/empty"

state extonly;    printf '[extend]\npath = ".gitleaks.toml"\n' > "$h/extonly/.gitleaks.local.toml"
expect_msg "an extend-only config blocks" 1 "defines no rules" run_block "$h/extonly"

state missing
expect "a missing config blocks" 1 run_block "$h/missing"

state optout;     printf '# assurance:no-local-identity-rules\n' >> "$h/optout/.gitleaks.toml"
expect "a standalone opt-out marker passes" 0 run_block "$h/optout"

# REVIEW FINDING (2026-08-15, in a live port): prose mentioning the marker
# disarmed the whole check.
state prose;      printf '# we do NOT use assurance:no-local-identity-rules here\n' >> "$h/prose/.gitleaks.toml"
expect_msg "the marker mentioned in prose does not opt out" 1 "is missing" run_block "$h/prose"

# No message may echo file content: this output goes into a verification matrix.
leak="$(run_block "$h/unedited" 2>&1 | grep -E 'example\.invalid|Firstname|PLACEHOLDER' || true)"
if [ -n "$leak" ]; then
  fail=$((fail + 1)); printf '  FAIL  rejection output echoes file content\n'
else
  pass=$((pass + 1)); printf '  ok    rejection output is content-free\n'
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. Hook structure — the parts the extracted fragment cannot reach
# ═══════════════════════════════════════════════════════════════════════════
#
# Section 2 extracts ONE block of the hook, so everything above and below it is
# unexercised — and what sits there is the no-bypass rule and the scan
# invocations themselves. Mutations replacing the SKIP=gitleaks rejection with a
# branch that honours it, or deleting the line that scans the local config, both
# left this suite green: the secret scan could be made fully bypassable — a
# section-5 non-negotiable — under 30 green ticks. Found in review, 2026-09-08.
#
# Running the whole hook here is impractical (it wants git state, a gitleaks
# binary, a node toolchain), so these are SOURCE assertions — which is the form
# invariant 14 names: read the shell script and assert the set.
echo
echo "hook structure"

hook="$ref/hooks/pre-commit"

assert_src() {                  # assert_src <name> <1=want-found|0=want-absent> <pattern>
  name="$1"; want="$2"; pat="$3"
  if grep -qE "$pat" "$hook"; then found=1; else found=0; fi
  if [ "$found" -eq "$want" ]; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$name"
    printf '        pattern: %s\n' "$pat"
  fi
}

assert_src "SKIP=gitleaks is rejected, not honoured" 1 '\*",gitleaks,"\*\)'
assert_src "the rejection says so and exits" 1 'SKIP=gitleaks is not supported'
assert_src "no branch honours a gitleaks skip" 0 'is_skipped[[:space:]]+gitleaks'
assert_src "the committed config is scanned" 1 'protect --staged.*gitleaks\.toml'
assert_src "the local config is scanned when present" 1 'protect --staged.*gitleaks\.local\.toml'

# THE SKIPPABLE SET IS EXACTLY {lint, format} — the example invariant 14 gives by
# name. Adding a skip for another gate is three lines of shell.
skips="$(grep -oE 'is_skipped [a-z]+' "$hook" | awk '{print $2}' | sort -u | tr '\n' ' ')"
if [ "$skips" = "format lint " ]; then
  pass=$((pass + 1)); printf '  ok    the skippable set is exactly {lint, format}\n'
else
  fail=$((fail + 1))
  printf '  FAIL  the skippable set changed — got: %s\n' "$skips"
  printf '        Adding a skip is a decision; update this assertion deliberately.\n'
fi

# The scan must run AFTER the formatters, so it sees post-formatting content.
fmt_line="$(grep -n 'lint-staged' "$hook" | head -1 | cut -d: -f1)"
scan_line="$(grep -n 'protect --staged' "$hook" | head -1 | cut -d: -f1)"
if [ -n "$fmt_line" ] && [ -n "$scan_line" ] && [ "$scan_line" -gt "$fmt_line" ]; then
  pass=$((pass + 1)); printf '  ok    the secret scan runs after formatting\n'
else
  fail=$((fail + 1)); printf '  FAIL  ordering: formatting %s, first scan %s\n' "$fmt_line" "$scan_line"
fi

# ═══════════════════════════════════════════════════════════════════════════
echo
if [ "$fail" -gt 0 ]; then
  printf '❌ gates: %s passed, %s FAILED\n' "$pass" "$fail"
  exit 1
fi
printf '✅ gates: %s passed\n' "$pass"
