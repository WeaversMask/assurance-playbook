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
# One python process parses the YAML once and prints a verdict per property; PyYAML
# reads the key `on` as the boolean True, which the script accounts for.
if python3 -c 'import yaml' >/dev/null 2>&1; then
  # The checks live in a file of their own: macOS's `sh` is bash 3.2, which mis-parses
  # the `${{ ... }}` this script has to quote when the heredoc is nested inside $( ).
  cat > "$work/workflow-check.py" <<'PY'
import re, sys, yaml
doc = yaml.safe_load(open(sys.argv[1])); text = open(sys.argv[1]).read()
def ok(name, cond): print(("ok    " if cond else "FAIL  ") + name)
on = doc.get("on", doc.get(True)) or {}
# `on` is a string, a list or a map; and only the PARSED triggers are tested, never the
# raw text, because the workflow's own comments name the thing it forbids.
if isinstance(on, str): on = {on: None}
elif isinstance(on, list): on = dict.fromkeys(on)
ok("the token is read-only: permissions is exactly contents: read", doc.get("permissions") == {"contents": "read"})
ok("no job widens the token", all("permissions" not in j for j in doc["jobs"].values()))
ok("it never triggers on pull_request_target", "pull_request_target" not in on)
uses = re.findall(r"^\s*-?\s*uses:\s*(\S+)", text, re.M)
ok("there are actions, and every one is pinned to a full commit SHA", bool(uses) and all(re.fullmatch(r"[^@\s]+@[0-9a-f]{40}", u) for u in uses))
steps = [s for j in doc["jobs"].values() for s in j.get("steps", [])]
ok("no step interpolates the event into a shell command", not any("${{ github.event" in (s.get("run") or "") or "${{ github.head_ref" in (s.get("run") or "") for s in steps))
ok("no step persists credentials", all((s.get("with") or {}).get("persist-credentials") is False for s in steps if str(s.get("uses", "")).startswith("actions/checkout")))
ok("it runs on both Linux and macOS", {"ubuntu-latest", "macos-latest"} <= set(doc["jobs"]["checks"]["strategy"]["matrix"]["os"]))
ok("a skipped case fails the run", any("SKIPPED" in (s.get("run") or "") and "exit 1" in (s.get("run") or "") for s in doc["jobs"]["checks"]["steps"]))
ok("gitleaks is installed by the pinned installer, in both jobs", all(any("scripts/install-gitleaks.sh" in (s.get("run") or "") for s in j["steps"]) for j in doc["jobs"].values()))
ok("the history job reads the whole history", any((s.get("with") or {}).get("fetch-depth") == 0 for s in doc["jobs"]["history"]["steps"]))
ok("the history job does not run on pull requests", "pull_request" in str(doc["jobs"]["history"].get("if")))
PY
  # The checker crashed once on a workflow with an empty `with:` block — its traceback went
  # to stderr, the lines already printed counted as passes, and the suite reported success
  # with FEWER cases than it should have run. So: a crash is a failure, and so is any
  # number of verdicts other than the eleven the script prints.
  if results="$(python3 "$work/workflow-check.py" "$workflow" 2>&1)"; then :; else
    fail=$((fail + 1)); printf '  FAIL  the workflow checker crashed\n'; printf '%s\n' "$results" | tail -3 | sed 's/^/          /'
  fi
  printf '%s\n' "$results"
  verdicts=$(printf '%s\n' "$results" | grep -cE '^(ok|FAIL) ' || true)
  if [ "$verdicts" != 11 ]; then
    fail=$((fail + 1)); printf '  FAIL  expected 11 workflow verdicts, got %s — a check that examined less must not read as clean\n' "$verdicts"
  fi
  # `grep -c` exits 1 when the count is 0, and `set -e` then kills the suite inside the
  # assignment with no summary line — the run with ZERO failures died and the run with one
  # printed. The third suite on this branch to be killed by exactly this.
  p=$(printf '%s\n' "$results" | grep -c '^ok' || true); f=$(printf '%s\n' "$results" | grep -c '^FAIL' || true)
  pass=$((pass + p)); fail=$((fail + f))
else
  skipped=$((skipped + 11)); printf '  SKIP  workflow cases — PyYAML not found (probe: python3 -c "import yaml", %s)\n' "$(date +%Y-%m-%d)"
fi

echo
if [ "$fail" -gt 0 ]; then printf '❌ ci: %s passed, %s FAILED\n' "$pass" "$fail"; exit 1; fi
if [ "$skipped" -gt 0 ]; then
  printf '✅ ci: %s passed, %s SKIPPED — those cases did not run\n' "$pass" "$skipped"
else
  printf '✅ ci: %s passed\n' "$pass"
fi
