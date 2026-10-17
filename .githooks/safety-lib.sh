# Shared by the three places the safety class runs: .githooks/safety-checks.sh
# (pre-commit), .githooks/pre-push, and scripts/check-history.sh (CI). SOURCED,
# never run; it defines functions and does nothing else.
#
# WHY ONE LIBRARY. The identity declaration is parsed here once. The first version
# of that parse detected the line with one pattern and read it with a narrower one,
# and blocked every commit for any display name containing a space. A second copy of
# it in a push hook would be where the two next disagreed. The same goes for the
# patterns-file checks, and for the scan: one function decides what the scanner is
# allowed to print, and what a scanner that did not run means.
#
# The caller has set `repo_root` and cd'd into it. Every function exits the calling
# script on failure, with a message that is content-free — names of files, rule ids
# and line numbers, never the matching text. This output gets pasted into handovers.

# Reads the one declared identity out of AGENTS.md into $declared.
read_declared_identity() {
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
}

# The committed scanner config must exist before anything is scanned against it.
require_committed_config() {
if [ ! -f "$repo_root/.gitleaks.toml" ]; then
  echo "❌ safety: .gitleaks.toml is missing — the committed scanner config."
  echo "   The scan cannot run without it. Restore it before committing."
  exit 1
fi
}

# --- The per-machine patterns file (invariants 3, 5 and 5a) -----------------
# The patterns that find the maintainer's own email, legal name and home path
# disclose them if committed, so they cannot ship with the repo — which makes the
# file a manual step, which makes it forgettable. It was forgotten in Argus: a
# home path sat in a tracked file for months with three scan layers running and no
# rule that could match it. So its absence is a hard failure here, not a warning.
# Testing that a file EXISTS discloses nothing; nothing below prints a line of it.
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

# Sets $pattern_file, and refuses each way the per-machine patterns file can exist
# and still be unarmed: absent, defining no rules, or still holding example values.
require_patterns_file() {
  pattern_file="$repo_root/.gitleaks.local.toml"
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
}

# Sets $gitleaks_bin. A repo-local copy wins over PATH, so a pinned install is used.
find_scanner() {
  gitleaks_bin=""
  if [ -x "$repo_root/.bin/gitleaks" ]; then gitleaks_bin="$repo_root/.bin/gitleaks"
  elif command -v gitleaks >/dev/null 2>&1; then gitleaks_bin="gitleaks"
  else
    echo "❌ safety: gitleaks not found, so the secret scan cannot run."
    echo "   Install it (brew install gitleaks) and retry. There is no bypass."
    exit 1
  fi
}

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
#
# GITLEAKS EXITS 0 ON A RANGE IT COULD NOT RESOLVE. A nonexistent SHA, a nonexistent
# ref and a garbage option each exit 0, log ERR, and print "no leaks found" — probed
# 2026-10-17, gitleaks 8.30.1. A history scan that never ran would read as clean, so
# the log is inspected (never printed) and any ERR line is a scanner that could not
# run. The match is the bare token: the log's own lines carry no repository content,
# and a false positive here can only block.
scan_init() {
  report_dir="$(mktemp -d)"
  trap 'rm -rf "$report_dir"' EXIT INT TERM
  cat > "$report_dir/finding.tmpl" <<'TMPL'
{{ range . }}{{ .RuleID }} {{ .File }}:{{ .StartLine }}{{ if .Commit }} {{ printf "%.8s" .Commit }}{{ end }}
{{ end }}
TMPL
}

# scan <layer> <config file> <subject> <gitleaks git arguments...>
#   e.g. scan "your local patterns (.gitleaks.local.toml)" "$pattern_file" \
#          "the staged changes" --staged
scan() {
  scan_layer="$1"; scan_conf="$2"; scan_subject="$3"; shift 3
  scan_rc=0
  "$gitleaks_bin" git "$@" --redact --no-banner --exit-code 2 --config "$scan_conf" \
    --report-format template --report-template "$report_dir/finding.tmpl" \
    --report-path "$report_dir/out.txt" >"$report_dir/log.txt" 2>&1 </dev/null || scan_rc=$?
  if [ "$scan_rc" = 0 ] && grep -q 'ERR' "$report_dir/log.txt"; then scan_rc=1; fi
  case "$scan_rc" in
    0) return 0 ;;
    2) echo "❌ safety: $scan_layer matched $scan_subject:"
       awk 'NF { print "     " $0 }' "$report_dir/out.txt"
       return 1 ;;
    *) echo "❌ safety: the scanner could not run for $scan_layer over $scan_subject (exit $scan_rc)."
       echo "   A check that cannot evaluate must block. Its output is not shown, because"
       echo "   a config error can quote the config; reproduce it yourself, not through an"
       echo "   agent, by running gitleaks against that config file."
       return 1 ;;
  esac
}

# check_identity_range <words for git log>
# Every commit in the range must have been AUTHORED and COMMITTED as the declared
# identity (invariant 2). Both halves: a check of the author alone lets
# `GIT_COMMITTER_EMAIL=... git commit` through, which is the live finding invariant 2
# records. `git log` failing must not read as "no offenders", so its status is read
# before the output is filtered. Declared value goes in through ENVIRON, not -v,
# which would process backslash escapes.
check_identity_range() {
  idr_out="$(git log --format='%h%x09%an <%ae>%x09%cn <%ce>' $1 2>/dev/null)" || {
    echo "❌ safety: the commits to be checked could not be listed."
    echo "   A check that cannot evaluate must block."
    return 1
  }
  idr_bad="$(printf '%s\n' "$idr_out" | DECL="$declared" awk -F '\t' 'NF >= 3 {
    w = ""
    if ($2 != ENVIRON["DECL"]) w = w " author"
    if ($3 != ENVIRON["DECL"]) w = w " committer"
    if (w != "") print "     " $1 w
  }')"
  if [ -n "$idr_bad" ]; then
    echo "❌ safety: $(printf '%s\n' "$idr_bad" | wc -l | tr -d ' ') commit(s) were not made as the declared identity:"
    printf '%s\n' "$idr_bad"
    echo "   Values are not printed. Compare one yourself:"
    echo "     git show -s --format='%an <%ae> | %cn <%ce>' <sha>"
    return 1
  fi
}

# check_no_patterns_file_in_range <words for git log>
# The per-machine patterns file must never be in a commit that is about to leave the
# machine. The pre-commit gate refuses to stage it; this catches the commit that was
# made with the hook bypassed, while it can still be undone — before the push.
check_no_patterns_file_in_range() {
  np_out="$(git log --diff-filter=ACMR --name-only --format='commit %h' $1 2>/dev/null)" || {
    echo "❌ safety: the commits to be checked could not be listed."
    echo "   A check that cannot evaluate must block."
    return 1
  }
  np_bad="$(printf '%s\n' "$np_out" | awk '/^commit /{ c = $2 } /(^|\/)\.gitleaks\.local\.toml$/ { print "     " c }' | sort -u)"
  if [ -n "$np_bad" ]; then
    echo "❌ safety: .gitleaks.local.toml is in the history being checked:"
    printf '%s\n' "$np_bad"
    echo "   It holds the patterns that find your identifiers; publishing it would publish"
    echo "   exactly what it guards. Remove it from those commits before they leave this machine."
    return 1
  fi
}
