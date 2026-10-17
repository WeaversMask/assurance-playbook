#!/usr/bin/env sh
# The safety class, applied to this repository (identity-protection.md
# invariants 2, 3 and 5; secret-scanning.md invariants 1 and 3). Every project the
# playbook bootstraps installs these at every tier, and the tier never scales them.
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

# --- The committed scanner config -------------------------------------------
if [ ! -f "$repo_root/.gitleaks.toml" ]; then
  echo "❌ safety: .gitleaks.toml is missing — the committed scanner config."
  echo "   The scan cannot run without it. Restore it before committing."
  exit 1
fi

# --- The per-machine patterns file (invariants 3, 5 and 5a) -----------------
# The patterns that find the maintainer's own email, legal name and home path
# disclose them if committed, so they cannot ship with the repo — which makes the
# file a manual step, which makes it forgettable. It was forgotten in Argus: a
# home path sat in a tracked file for months with three scan layers running and no
# rule that could match it. So its absence is a hard failure here, not a warning.
# Testing that a file EXISTS discloses nothing; nothing below prints a line of it.
pattern_file="$repo_root/.gitleaks.local.toml"

# The self-test, printed from every unarmed state — not only the absent one. The
# reference prints it only when the file is missing, which leaves anyone holding a
# file with no rules, or one still carrying example values, pointed at a block
# that never appears. A QUOTED heredoc: no expansion and no escaping, so what is
# printed is exactly what can be pasted. An inline `echo` version mangled `trap`
# and a `grep` pattern into doubled quotes; a remedy that is not runnable as
# printed is worse than a pointer, because it looks like it works.
print_selftest() {
  cat <<'PROBE'
     (
       d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
       {                                  # one line per rule, your REAL values
         echo "contact <your real email>"
         echo "mail anything@<your real domain>"
         echo "cd /Users/<your real username>/proj"
         echo "<Your Real Name> wrote this"
       } > "$d/probe.txt"
       gitleaks dir "$d" --no-banner --redact \
         --config .gitleaks.local.toml \
         --report-format json --report-path "$d/out.json"
       grep -o '"RuleID"[^,]*' "$d/out.json" | sort -u
     )
PROBE
  cat <<'MSG'

   EXPECT every rule id you defined, plus the committed config's
   absolute-home-path rule. An id that does not appear cannot match.
   --redact matters: without it the report holds your identifiers in cleartext
   on disk. Run it from the repo root, yourself; never paste its input into a
   session. Its output is only rule ids, and is safe to share.
MSG
}

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

if [ ! -f "$pattern_file" ]; then
  cat <<'MSG'
❌ safety: .gitleaks.local.toml is missing.
   Personal-identifier scanning is unarmed — the committed config cannot carry
   your email or legal name without disclosing them. Write the file by hand, in
   the repository root. NEVER let an agent create it or read its contents.

   ─── the shape it must have ───
   [extend]
   path = ".gitleaks.toml"

   then one [[rules]] block per identifier, each with an id and a regex:
     personal-email        your real address(es), regex-escaped
     personal-email-domain any address at your personal domain
     home-directory-path   /Users/<user>, /home/<user>, C:\Users\<user>
     real-name             your legal name, if it must stay out of content
   templates/gitleaks.local.example.toml is a filled-in example.

   ─── then prove it fires, one probe per rule ───
   Counting hits is not enough: the email rules overlap, so four hits can come
   from two working rules and two dead ones. Check the rule IDS.

MSG
  print_selftest
  exit 1
fi

# THE EMPTIEST VERSION OF THE FAILURE. `touch .gitleaks.local.toml` satisfies the
# existence check, and a file holding only the `[extend]` stanza does too — the
# scan then runs and reports clean, because nothing in it describes the
# maintainer. `id =` is a schema keyword, so testing for it discloses nothing; a
# commented-out rule does not count, because the match is anchored.
if ! grep -qE '^[[:space:]]*id[[:space:]]*=' "$pattern_file"; then
  cat <<'MSG'
❌ safety: .gitleaks.local.toml defines no rules.
   The file exists but holds no [[rules]] entry of its own, so the
   personal-identifier layer is unarmed: the scan runs and reports clean because
   nothing in it describes you. An empty file is not a configured file. Add one
   [[rules]] block per identifier, then prove each fires:

MSG
  print_selftest
  exit 1
fi

# BOTH HALVES, NOT ONE. The example marks each fillable line with a trailing
# comment, which is separable from the value on its own line — so "replace the
# value and delete the marker" is two independent instructions, and checking only
# the marker leaves a file armed against nobody that passes. The example's values
# are unique strings, so they are rejected too. Only regex and id lines are read:
# a comment that merely NAMES these tokens must not jam a correct file.
placeholder_re='PLACEHOLDER|example[\\.]*invalid|Firstname|Lastname'
if grep -E '^[[:space:]]*(regex|id)[[:space:]]*=' "$pattern_file" | grep -qE "$placeholder_re"; then
  lines="$(grep -nE '^[[:space:]]*(regex|id)[[:space:]]*=' "$pattern_file" \
    | grep -E "$placeholder_re" | cut -d: -f1 | tr '\n' ' ')"
  echo "❌ safety: .gitleaks.local.toml still holds example placeholders."
  echo "   Placeholder markers or example values remain on line(s): $lines"
  cat <<'MSG'
   It was copied but not fully filled in, so the personal-identifier layer is
   unarmed: the file exists and at least one rule in it cannot match anything
   real. Replace the VALUE on each of those lines — deleting the marker comment
   alone is not enough — then prove each rule fires:

MSG
  print_selftest
  exit 1
fi

# --- The scanner (secret-scanning.md invariants 1 and 3) --------------------
gitleaks_bin=""
if [ -x "$repo_root/.bin/gitleaks" ]; then gitleaks_bin="$repo_root/.bin/gitleaks"
elif command -v gitleaks >/dev/null 2>&1; then gitleaks_bin="gitleaks"
else
  echo "❌ safety: gitleaks not found, so the secret scan cannot run."
  echo "   Install it (brew install gitleaks) and retry. There is no bypass."
  exit 1
fi

# WHAT THE SCANNER IS ALLOWED TO PRINT. Its own output is thrown away, and the
# gate prints rule id, file and line from a report template instead. Not `-v`:
# `--redact` hides only the rule's SECRET GROUP, and for the home-path rule that
# group is just the `/Users/` prefix — so a verbose finding reads
# `cd REDACTED<account>/project` and prints the very name this layer guards. Probed
# 2026-09-21, gitleaks 8.30.1. Without either, a refusal said only "leaks found: 1"
# and could not say where, or which of the two passes had spoken.
#
# `--exit-code 2` separates a leak (2) from a scanner that could not run (1: a
# missing or invalid config). Both block; they are not the same message, and the
# second must not be read as "clean" or as "a leak". Its own output is not shown
# because a config error can quote the config.
report_dir="$(mktemp -d)"
trap 'rm -rf "$report_dir"' EXIT INT TERM
cat > "$report_dir/finding.tmpl" <<'TMPL'
{{ range . }}{{ .RuleID }} {{ .File }}:{{ .StartLine }}
{{ end }}
TMPL

scan() {   # scan <what is being applied> <config file>
  rc=0
  "$gitleaks_bin" git --staged --redact --no-banner --exit-code 2 --config "$2" \
    --report-format template --report-template "$report_dir/finding.tmpl" \
    --report-path "$report_dir/out.txt" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) return 0 ;;
    2) echo "❌ safety: $1 matched the staged changes:"
       awk 'NF { print "     " $0 }' "$report_dir/out.txt"
       return 1 ;;
    *) echo "❌ safety: the scanner could not run against $1 (exit $rc)."
       echo "   A check that cannot evaluate must block. Its output is not shown,"
       echo "   because a config error can quote the config; reproduce it yourself:"
       echo "     gitleaks git --staged --redact --no-banner --config <that file>"
       return 1 ;;
  esac
}

# Two passes. The local config extends the committed one, so its pass re-applies
# every committed rule and allowlist as well as the personal ones; the committed
# pass still runs on its own, first, so that a local file whose `[extend]` is wrong
# cannot take the committed rules down with it — and so a refusal says which pass.
scan "the committed rules (.gitleaks.toml)" "$repo_root/.gitleaks.toml" || exit 1
scan "your local patterns (.gitleaks.local.toml)" "$pattern_file" || exit 1
