#!/usr/bin/env sh
# Regression tests for the CI pieces: `scripts/install-gitleaks.sh` and
# `.github/workflows/checks.yml` (TRACKER.md, D-002).
#
# WHAT THIS CANNOT COVER, said first. The installer's SUCCESS path needs the real
# release tarball, whose SHA-256 is pinned in the script; the workflow cannot run
# without GitHub. Both are exercised by the first CI run, and nothing here pretends
# otherwise. What it can cover is the installer's FAILURE paths — which is where an
# installer that "worked" without installing anything would hide — over file://, so no
# network is touched, and the workflow's security properties, which are static.
#
# THE INSTALLER'S CASES are the ones where a soft failure would let a green CI run
# stand on a scanner that is not there: an unsupported platform, a download that
# fails, a tarball that does not hash to the pin (which must install NOTHING), and an
# existing binary at the wrong version (which must not count as installed).
#
# THE WORKFLOW'S CASES are text, and a text assertion cannot be complete about control
# flow; they are here because each guards a property that is easy to loosen by editing
# one line and hard to notice in review: the token's scope, `pull_request_target`, an
# action left on a mutable tag, and the step that turns a skipped case into a failure.
#
# Run: sh scripts/check-ci.test.sh

set -e

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
installer="$root/scripts/install-gitleaks.sh"
workflow="$root/.github/workflows/checks.yml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

pass=0
fail=0
skipped=0
# curl quotes the URL it was given. In real use that is a public GitHub URL; in the two
# cases that point it at a file:// base it is a local path, which is a test artifact and
# not the installer's output. Allowed in exactly those cases, set and cleared around them.
allow_path=

verdict() {  # verdict <name> <want 0|1> <got> <message fragment or ""> <output>
  n="$1"; w="$2"; g="$3"; f="$4"; o="$5"
  if { [ "$w" = 0 ] && [ "$g" != 0 ]; } || { [ "$w" != 0 ] && [ "$g" = 0 ]; }; then
    fail=$((fail + 1)); printf '  FAIL  %s — wanted exit %s, got %s\n' "$n" "$w" "$g"
    printf '%s\n' "$o" | sed 's/^/          /' | head -5; return
  fi
  if [ -n "$f" ] && ! printf '%s' "$o" | grep -q "$f"; then
    fail=$((fail + 1)); printf '  FAIL  %s — refused for a different reason than it names\n' "$n"
    printf '        wanted: %s\n' "$f"; printf '%s\n' "$o" | sed 's/^/          /' | head -5; return
  fi
  # NO ABSOLUTE PATH, on any branch: this output is pasted into handovers.
  if [ "${allow_path:-}" != 1 ] && { printf '%s' "$o" | grep -qF "$work" || printf '%s' "$o" | grep -qE '(/Users|/home)/[A-Za-z0-9._-]+'; }; then
    fail=$((fail + 1)); printf '  FAIL  %s — printed an absolute path\n' "$n"; return
  fi
  pass=$((pass + 1)); printf '  ok    %s\n' "$n"
}
flag() { if [ "$2" = yes ]; then pass=$((pass + 1)); printf '  ok    %s\n' "$1"; else fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; fi; }

# A fresh checkout-shaped tree holding only the installer, so `.bin` lands inside it.
mktree() {
  t="$work/$1"; mkdir -p "$t/scripts"; cp "$installer" "$t/scripts/install-gitleaks.sh"; printf '%s' "$t"
}
# A `uname` that reports whatever the case says, ahead of the real one on PATH.
shim="$work/shim"; mkdir -p "$shim"
cat > "$shim/uname" <<'UNAME'
#!/bin/sh
case "$1" in -m) echo "${FAKE_UNAME_M:-x86_64}" ;; *) echo "${FAKE_UNAME_S:-Linux}" ;; esac
UNAME
chmod +x "$shim/uname"

run() { r="$1"; shift; if out="$( cd "$r" && "$@" 2>&1 )"; then got=0; else got=$?; fi; }
none() { if [ -e "$1/.bin/gitleaks" ]; then echo no; else echo yes; fi; }

echo "install-gitleaks.sh"

t="$(mktree os)"
run "$t" env PATH="$shim:$PATH" FAKE_UNAME_S=Plan9 sh scripts/install-gitleaks.sh
verdict "an unsupported OS is a hard failure" 1 "$got" "unsupported OS" "$out"
flag "…and installs nothing" "$(none "$t")"

t="$(mktree arch)"
run "$t" env PATH="$shim:$PATH" FAKE_UNAME_M=riscv64 sh scripts/install-gitleaks.sh
verdict "an unsupported architecture is a hard failure" 1 "$got" "unsupported architecture" "$out"
flag "…and installs nothing" "$(none "$t")"

# A base that does not exist: if the installer tried to download, this would fail it.
t="$(mktree current)"; mkdir -p "$t/.bin"
printf '#!/bin/sh\necho 8.30.1\n' > "$t/.bin/gitleaks"; chmod +x "$t/.bin/gitleaks"; before="$(cat "$t/.bin/gitleaks")"
run "$t" env GITLEAKS_DOWNLOAD_BASE="file://$work/does-not-exist" sh scripts/install-gitleaks.sh
verdict "a binary already at the pinned version is left alone, with no download" 0 "$got" "" "$out"
flag "…and is unchanged" "$( [ "$(cat "$t/.bin/gitleaks")" = "$before" ] && echo yes || echo no )"

t="$(mktree stale)"; mkdir -p "$t/.bin"
printf '#!/bin/sh\necho 8.0.0\n' > "$t/.bin/gitleaks"; chmod +x "$t/.bin/gitleaks"
run "$t" env GITLEAKS_DOWNLOAD_BASE="file://$work/does-not-exist" sh scripts/install-gitleaks.sh
allow_path=1; verdict "a binary at the WRONG version does not count as installed" 1 "$got" "the download failed" "$out"; allow_path=

t="$(mktree nodl)"
run "$t" env GITLEAKS_DOWNLOAD_BASE="file://$work/does-not-exist" sh scripts/install-gitleaks.sh
allow_path=1; verdict "a failed download is a hard failure, not a soft skip" 1 "$got" "NOT installed" "$out"; allow_path=
flag "…and installs nothing" "$(none "$t")"

# A tarball that is the right NAME but not the pinned CONTENT. Built for this platform.
case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) os="" ;; esac
case "$(uname -m)" in x86_64|amd64) arch=x64 ;; arm64|aarch64) arch=arm64 ;; *) arch="" ;; esac
if [ -n "$os" ] && [ -n "$arch" ]; then
  serve="$work/serve"; mkdir -p "$serve/pack"
  printf '#!/bin/sh\necho 8.30.1\n' > "$serve/pack/gitleaks"; chmod +x "$serve/pack/gitleaks"
  ( cd "$serve/pack" && tar -czf "$serve/gitleaks_8.30.1_${os}_${arch}.tar.gz" gitleaks )
  t="$(mktree mismatch)"
  run "$t" env GITLEAKS_DOWNLOAD_BASE="file://$serve" sh scripts/install-gitleaks.sh
  verdict "a tarball that does not hash to the pin is refused" 1 "$got" "SHA-256 mismatch" "$out"
  flag "…and NOTHING is installed, not even a binary that claims the right version" "$(none "$t")"
else
  skipped=$((skipped + 2)); printf '  SKIP  checksum-mismatch cases — this platform is not one the installer supports\n'
fi

echo
echo "checks.yml"
# DEPENDENCY-FREE ON PURPOSE. The first version parsed the YAML with PyYAML. The first CI
# run skipped all eleven of those cases on the macOS runner, whose python3 has no yaml
# module — and the workflow's own skip guard failed the run, correctly. A suite for the CI
# pieces cannot depend on something the CI runner may lack, so this reads the file with
# grep and awk alone (no regex intervals in awk: mawk is Ubuntu's default).
#
# COMMENTS ARE STRIPPED FIRST, so prose that names a forbidden thing cannot trip a check
# and prose that names a required thing cannot satisfy one. Everything below reads CODE.
code="$work/workflow.code"
grep -vE '^[[:space:]]*#' "$workflow" > "$code" || true

# A top-level key's block: its lines, up to the next line that starts in column 0.
top() { awk -v key="$1" '$0 ~ "^" key ":" { inside = 1; next } inside && /^[^ \t]/ { inside = 0 } inside { print }' "$code"; }
# A job's lines: from its key (indented two spaces under `jobs:`) to the next job key.
job() {
  awk -v name="$1" '
    /^jobs:/ { injobs = 1; next }
    injobs && /^[^ \t]/ { injobs = 0 }
    injobs && /^  [A-Za-z0-9_-]+:[ \t]*$/ { cur = $0; sub(/^  /, "", cur); sub(/:[ \t]*$/, "", cur); inside = (cur == name); next }
    injobs && inside { print }
  ' "$code"
}
yes_if() { if "$@"; then echo yes; else echo no; fi; }

perm="$(top permissions)"
flag "the token is read-only: permissions is exactly contents: read" \
  "$(yes_if sh -c '[ "$(printf "%s\n" "$1" | grep -c . || true)" = 1 ] && printf "%s\n" "$1" | grep -qx "  contents: read"' _ "$perm")"
flag "no job widens the token" "$(yes_if sh -c '! grep -qE "^[[:space:]]+permissions:" "$1"' _ "$code")"
flag "it never triggers on pull_request_target" "$(yes_if sh -c '! grep -q pull_request_target "$1"' _ "$code")"

uses="$(grep -E '^[[:space:]-]*uses:' "$code" || true)"
unpinned="$(printf '%s\n' "$uses" | grep -vE '@[0-9a-f]{40}([[:space:]]|$)' | grep . || true)"
flag "there are actions, and every one is pinned to a full commit SHA" \
  "$(yes_if sh -c '[ -n "$1" ] && [ -z "$2" ]' _ "$uses" "$unpinned")"

flag "no step interpolates the event into a shell command" \
  "$(yes_if sh -c '! grep -qE "[$][{][{][[:space:]]*github[.](event|head_ref)" "$1"' _ "$code")"

nco="$(grep -c 'actions/checkout@' "$code" || true)"; npc="$(grep -c 'persist-credentials: false' "$code" || true)"
flag "no step persists credentials" "$(yes_if sh -c '[ "$1" -gt 0 ] && [ "$1" = "$2" ]' _ "$nco" "$npc")"

osline="$(grep -E '^[[:space:]]*os:[[:space:]]*\[' "$code" | head -1 || true)"
case "$osline" in
  *ubuntu-latest*macos-latest*|*macos-latest*ubuntu-latest*) both=yes ;;
  *) both=no ;;
esac
flag "it runs on both Linux and macOS" "$both"

jc="$(job checks)"; jh="$(job history)"
flag "a skipped case fails the run" \
  "$(yes_if sh -c 'printf "%s\n" "$1" | awk "/grep -q SKIPPED/ { s = NR } s && NR - s <= 8 && /exit 1/ { ok = 1 } END { exit !ok }"' _ "$jc")"
flag "gitleaks is installed by the pinned installer, in both jobs" \
  "$(yes_if sh -c 'printf "%s\n" "$1" | grep -q "scripts/install-gitleaks.sh" && printf "%s\n" "$2" | grep -q "scripts/install-gitleaks.sh"' _ "$jc" "$jh")"
flag "the history job reads the whole history" \
  "$(yes_if sh -c 'printf "%s\n" "$1" | grep -qE "fetch-depth:[[:space:]]*0"' _ "$jh")"
flag "the history job does not run on pull requests" \
  "$(yes_if sh -c 'printf "%s\n" "$1" | grep -E "^[[:space:]]*if:" | grep -q pull_request' _ "$jh")"

echo
if [ "$fail" -gt 0 ]; then printf '❌ ci: %s passed, %s FAILED\n' "$pass" "$fail"; exit 1; fi
if [ "$skipped" -gt 0 ]; then
  printf '✅ ci: %s passed, %s SKIPPED — those cases did not run\n' "$pass" "$skipped"
else
  printf '✅ ci: %s passed\n' "$pass"
fi
