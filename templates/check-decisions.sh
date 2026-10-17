#!/usr/bin/env sh
# Decision-trigger gate, portable: POSIX sh and awk, no other dependency.
#
#   sh scripts/check-decisions.sh        (copy this file to your project's scripts/)
#
# THE INVARIANT: an open decision must name the event that will bring it back, and
# that event must not already have happened. This is the mechanism that makes
# declining a recommendation safe rather than a way to lose it (process.md, "Open
# decisions"). BOOTSTRAP.md Phase 2.10 makes it mandatory at every tier, and until
# this file existed its only worked implementation was a Node script, so a project
# on any other stack had to install Node for one gate or write 400 lines before its
# first commit.
#
# THIS IS A PORT, NOT A REDESIGN. `reference/node-pnpm/scripts/check-decisions.mjs`
# is the original; its header explains every fail-closed rule and the reviews that
# produced them, and none of that is restated here. The two are held to the same
# behaviour: `reference/node-pnpm/test/gates.test.sh` runs every one of its cases
# against BOTH, and the port was diffed byte for byte against the original over
# several hundred generated trackers before it was believed. What is stated here is
# only what differs.
#
# WHAT DIFFERS, and these are real limits:
#   * ASCII. Locale is pinned to C, so a task id is measured in bytes, not
#     characters, and whitespace means space, tab and CR, not every Unicode space.
#   * LF line endings. A tracker saved with CRLF is not specially handled by either.
#   * It has run on BSD awk 20200816 (macOS), GNU Awk 5.2.1 and mawk 1.3.4, in CI on
#     2026-10-17 (TRACKER.md, D-002); not on busybox awk. It is written to the POSIX
#     subset (no regex intervals, no gawk extensions) because mawk, the default awk on
#     a stock Debian or Ubuntu, is where a portable awk program breaks first.
#
# The tracker is `docs/IMPLEMENTATION.md`, resolved from this file's parent
# directory, as in the original. Making that a parameter is TRACKER.md D-003.
#
# EVERY MESSAGE IS CONTENT-FREE of absolute paths: only the tracker's relative name.

set -e
LC_ALL=C
export LC_ALL

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(dirname "$here")"
tracker="docs/IMPLEMENTATION.md"
path="$repo_root/$tracker"

# The original prints `err.code`, never the message: the message carries the
# absolute path, and this output is pasted into the verification matrix.
if [ ! -e "$path" ]; then code=ENOENT
elif [ -d "$path" ]; then code=EISDIR
elif [ ! -r "$path" ]; then code=EACCES
else code=""; fi
if [ -n "$code" ]; then
  echo "❌ decisions: cannot read $tracker ($code)." >&2
  echo "   A check that cannot evaluate must block." >&2
  exit 1
fi

today="$(date -u +%Y-%m-%d)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

cat > "$tmp/check.awk" <<'AWK'
function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
function say(s) { print "O" s }
function err(s) { print "E" s }
function fail(id, msg) { nfail++; fails[nfail] = id ": " msg }

# Task ids from the tables of section k, into the array passed. The first cell of
# every non-separator table row; no whitespace, at most 24 bytes, not the header.
function idsin(k, set,   i, line, parts, id) {
  for (i = sfirst[k]; i <= slast[k]; i++) {
    line = L[i]
    if (line ~ /^\|/ && line !~ /^\|[ \t\r:|-]+\|?$/) {
      split(line, parts, "|")
      id = trim(parts[2]); gsub(/[*`]/, "", id)
      if (id != "" && id !~ /[ \t\r]/ && length(id) <= 24 && tolower(id) != "id") set[id] = 1
    }
  }
}

# The current phase, from the "**Phase:**" line of the Current state section. The
# LINE, not the section: scanning the section took the first phase-shaped token and
# read a stale one as current. More than one token on the line FAILS.
function currentphase(   i, line, found, len, pos, rest, st, en, rl, prevc, nextc, ntok) {
  cp_err = ""
  if (ssec == 0) { cp_err = "no \"Current state\" section"; return }
  found = 0
  for (i = sfirst[ssec]; i <= slast[ssec]; i++) {
    if (index(L[i], "**Phase:**") > 0) { found = 1; line = L[i]; break }
  }
  if (!found) { cp_err = "no \"**Phase:**\" line in Current state"; return }
  ntok = 0; pos = 1; len = length(line)
  while (pos <= len) {
    rest = substr(line, pos)
    if (!match(rest, /P[0-9]+-[A-Za-z0-9]+/)) break
    st = pos + RSTART - 1; rl = RLENGTH; en = st + rl - 1
    prevc = (st > 1) ? substr(line, st - 1, 1) : ""
    nextc = (en < len) ? substr(line, en + 1, 1) : ""
    if ((prevc == "" || prevc !~ /[A-Za-z0-9_]/) && (nextc == "" || nextc !~ /[A-Za-z0-9_]/)) {
      ntok++
      if (ntok == 1) { cp_raw = substr(line, st, rl); cp_major = substr(cp_raw, 2, index(cp_raw, "-") - 2) + 0 }
      pos = en + 1
    } else pos = st + 1
  }
  if (ntok == 0) { cp_err = "the \"**Phase:**\" line holds no P<n>-<x> token: " trim(line); return }
  if (ntok > 1) { cp_err = "the \"**Phase:**\" line holds " ntok " phase tokens; which one is current is ambiguous"; return }
}

# Resolved LAZILY, on the first phase-boundary trigger: a tier-1 project has no
# phases, and demanding one up front locked those projects out of the gate.
function requirephase(id) {
  if (phase_done) return
  currentphase()
  if (cp_err != "") {
    err("❌ decisions: " id " has a phase-boundary trigger, but the current phase")
    err("   cannot be determined from " tracker ": " cp_err)
    err("   Expected exactly one token like \"P1-04\" on the \"**Phase:**\" line.")
    err("   A trigger that cannot be resolved must not read as unexpired.")
    exit 1
  }
  phase_done = 1; phase_major = cp_major; phase_raw = cp_raw
}

# The trigger token of a row: the Trigger column if the header has one and the cell
# is not empty or a dash, else an inline "Trigger:" label in any cell.
function triggerof(   v, j, c, p, rest, lr, q, cut, stars, k) {
  if (tcol > 0 && tc[tcol + 1] != "") {
    v = tc[tcol + 1]
    if (v != "" && v != "—" && v != "-") return v
  }
  for (j = 1; j <= nc; j++) {
    c = tc[j]; p = index(tolower(c), "trigger:")
    if (p > 0) {
      rest = substr(c, p + 8)
      sub(/^\*\*?/, "", rest); sub(/^[ \t\r]+/, "", rest)
      lr = tolower(rest); q = index(lr, "trigger:")
      if (q > 0) {
        cut = q - 1; stars = 0
        while (stars < 2 && cut > 0 && substr(rest, cut, 1) == "*") { cut--; stars++ }
        rest = substr(rest, 1, cut)
      }
      k = index(rest, ","); if (k > 0) rest = substr(rest, 1, k - 1)
      return trim(rest)
    }
  }
  return ""
}

{ L[NR] = $0 }

END {
  n = NR
  # ── sections: split on lines that begin "## " ──
  nsec = 0
  for (i = 1; i <= n; i++) {
    if (substr(L[i], 1, 3) == "## ") {
      nsec++; sraw[nsec] = substr(L[i], 4); sh[nsec] = trim(sraw[nsec]); sfirst[nsec] = i
      if (nsec > 1) slast[nsec - 1] = i - 1
    }
  }
  if (nsec > 0) slast[nsec] = n
  osec = 0; ssec = 0
  for (k = 1; k <= nsec; k++) {
    if (osec == 0 && index(sraw[k], "Open decisions") == 1) osec = k
    if (ssec == 0 && index(sraw[k], "Current state") == 1) ssec = k
  }
  if (osec == 0) {
    err("❌ decisions: no \"## Open decisions\" section in " tracker ".")
    err("   The section is where every declined recommendation lives. Its absence")
    err("   is not an empty table — it is a check with nothing to examine.")
    exit 1
  }

  # ── ids, harvested by section; a Map keyed by heading, later duplicates winning ──
  nh = 0
  for (k = 1; k <= nsec; k++) { if (!(sh[k] in hval)) { nh++; hord[nh] = sh[k] } hval[sh[k]] = k }
  compsec = 0
  for (j = 1; j <= nh; j++) {
    h = tolower(hord[j])
    if (h ~ /^(up next|in progress|blocked|recently completed|completed)/) idsin(hval[hord[j]], knownIds)
    if (compsec == 0 && (h ~ /recently completed/ || h ~ /^completed/)) compsec = hval[hord[j]]
  }
  if (compsec > 0) idsin(compsec, completedIds)

  # ── where the trigger lives: found by header, not by index ──
  tcol = -1; hdr = ""
  for (i = sfirst[osec]; i <= slast[osec]; i++) {
    if (L[i] ~ /^\|/ && index(tolower(L[i]), "trigger") > 0) { hdr = L[i]; break }
  }
  if (hdr != "") {
    nhc = split(hdr, hc, "|")
    for (j = 1; j <= nhc; j++) if (tolower(trim(hc[j])) == "trigger") { tcol = j - 1; break }
  }

  # ── rows: anything that LOOKS like a decision row, however malformed ──
  nrows = 0
  for (i = sfirst[osec]; i <= slast[osec]; i++) {
    if (L[i] ~ /^\|[ \t]*\*?\*?D-[0-9A-Za-z]+\*?\*?[ \t]*\|/) {
      nrows++; rowline[nrows] = L[i]
      t = substr(L[i], 2); sub(/^[ \t]*\*?\*?/, "", t); match(t, /^D-[0-9A-Za-z]+/); rowid[nrows] = substr(t, 1, RLENGTH)
    }
  }
  if (nrows == 0) {
    err("❌ decisions: the Open decisions table has no rows.")
    err("   At least the assurance-tier decision is recorded here at bootstrap, so")
    err("   an empty table means the section was gutted rather than that nothing")
    err("   has been declined. Comparing nothing must never read as clean.")
    exit 1
  }

  nopen = 0; nfail = 0; nnote = 0
  for (r = 1; r <= nrows; r++) {
    id = rowid[r]
    nc = split(rowline[r], cells, "|")
    for (j = 1; j <= nc; j++) tc[j] = trim(cells[j])
    if (nc < 5) { fail(id, "row will not parse (" (nc - 2) " cells found). Reported rather than skipped."); continue }
    d2 = tc[3]; sub(/^\*+/, "", d2)
    if (d2 ~ /^Closed [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) continue
    nopen++
    raw = triggerof()
    if (raw == "") { fail(id, "open row with no trigger. Every open row names the event that reopens it."); continue }
    token = raw; gsub(/[.`*]/, "", token); token = trim(token)
    if (token == "standing") { nnote++; notes[nnote] = id ": standing — no trigger by choice. Greppable, and that is the only mitigation."; continue }
    if (token ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
      if ((token "") <= (today "")) fail(id, "trigger date " token " has passed (today " today ").")
      continue
    }
    if (token ~ /^P[0-9]+-(start|exit)$/) {
      requirephase(id)
      dash = index(token, "-"); major = substr(token, 2, dash - 2) + 0; kind = substr(token, dash + 1)
      passed = (kind == "start") ? (phase_major >= major) : (phase_major > major)
      if (passed) fail(id, "trigger `" token "` has passed (current phase " phase_raw ").")
      continue
    }
    if (!(token in knownIds)) {
      fail(id, "trigger `" token "` is not a date, not a phase boundary, not `standing`, and resolves to no task id in the tracker. A typo is a trigger that never fires — and a completed task pruned from the tracker looks the same from here.")
      continue
    }
    if (compsec == 0) {
      fail(id, "trigger `" token "` names a task, but there is no \"Recently completed\" section to resolve it against. Either the section is missing or renamed, or nothing has completed yet — those are indistinguishable from here, so this blocks.")
      continue
    }
    if (token in completedIds) fail(id, "trigger `" token "` has completed. Answer the row or consciously re-date it.")
  }

  for (j = 1; j <= nnote; j++) say("⚠️  STANDING  " notes[j])
  if (nfail > 0) {
    err("❌ decisions: " nfail " problem(s) in " tracker ".")
    for (j = 1; j <= nfail; j++) err("   " fails[j])
    err("")
    err("   A trigger that has passed without the row being answered or re-dated")
    err("   is a decision that quietly stopped being open. That is the whole")
    err("   failure this gate exists to catch.")
    exit 1
  }
  against = phase_done ? "current phase " phase_raw : "today's date and the tracker's task ids"
  say("✅ decisions: " nopen " open row(s) checked against " against "; no trigger has passed.")
}
AWK

# awk cannot set a pipeline's exit status, and stderr/stdout order must be fixed, so
# it tags each line and this loop routes them in the order they were produced.
rc=0
awk -v tracker="$tracker" -v today="$today" -f "$tmp/check.awk" "$path" > "$tmp/out" || rc=$?
while IFS= read -r line; do
  case "$line" in
    E*) printf '%s\n' "${line#E}" >&2 ;;
    O*) printf '%s\n' "${line#O}" ;;
  esac
done < "$tmp/out"
exit "$rc"
