#!/usr/bin/env sh
# Regression tests for the two layers that look at what LEAVES the machine:
# `.githooks/pre-push` and `scripts/check-history.sh` (TRACKER.md, D-005).
#
# Pushes go to a real bare repository, through git's real hook protocol. The first
# draft of this idea read stdin lines in the format the reference hook documents; a
# test that fed the hook those lines by hand would have proved the hook agrees with
# the author about what git sends, which is the one thing it cannot check. A few
# cases feed crafted lines anyway — an unresolvable remote tip cannot be produced
# by a real push — but every case about identity, scope and refusal goes through
# `git push`.
#
# THE CASES ARE SHAPED BY WHAT WAS LEARNED, not by what came to mind:
#   * gitleaks exits 0 on a range it cannot resolve, logging ERR and "no leaks
#     found" (probed 2026-10-17). A history scan that never ran would read as
#     clean, so one case drives the scan function at a range that does not exist.
#   * Identity cases name WHICH half failed: a hook that checks only the author lets
#     `GIT_COMMITTER_EMAIL=... git commit` through.
#   * Scope is part of the contract: a push is judged by what it publishes, not by
#     history the remote already holds. One case pushes a bad commit past the hook
#     on purpose, then shows a later clean push is not re-judged by it.
#   * Planted values are constructed with printf, never written, so this file does
#     not trip the scanner it tests. Fixtures use a name WITH a space.
#   * Every fixture subshell clears git's exported environment, because this suite
#     runs from inside a commit hook, which exports the commit's identity and index.
#
# Run: sh scripts/check-push.test.sh

set -e

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
pushhook="$root/.githooks/pre-push"
history="$root/scripts/check-history.sh"
lib="$root/.githooks/safety-lib.sh"
config="$root/.gitleaks.toml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM
PUSHHOOK="$pushhook"; export PUSHHOOK

pass=0
fail=0
skipped=0

clear_git_env() {
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE \
        GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE \
        GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX GIT_CONFIG_PARAMETERS
}
in_fixture() { d="$1"; shift; ( clear_git_env; cd "$d" || exit 1; "$@" ); }

needs_scanner() {
  if command -v gitleaks >/dev/null 2>&1; then return 0; fi
  skipped=$((skipped + ${2:-1}))
  printf '  SKIP  %s — gitleaks not found (probe: command -v gitleaks, %s)\n' "$1" "$(date +%Y-%m-%d)"
  return 1
}

verdict() {  # verdict <name> <want 0|1> <got> <message fragment or ""> <output>
  n="$1"; w="$2"; g="$3"; f="$4"; o="$5"
  if { [ "$w" = 0 ] && [ "$g" != 0 ]; } || { [ "$w" != 0 ] && [ "$g" = 0 ]; }; then
    fail=$((fail + 1)); printf '  FAIL  %s — wanted exit %s, got %s\n' "$n" "$w" "$g"
    printf '%s\n' "$o" | sed 's/^/          /' | head -5; return
  fi
  # ASSERT THE MESSAGE, NOT ONLY THE CODE: every refusal exits non-zero.
  if [ -n "$f" ] && ! printf '%s' "$o" | grep -q "$f"; then
    fail=$((fail + 1)); printf '  FAIL  %s — refused for a different reason than it names\n' "$n"
    printf '        wanted: %s\n' "$f"; printf '%s\n' "$o" | sed 's/^/          /' | head -5; return
  fi
  pass=$((pass + 1)); printf '  ok    %s\n' "$n"
}
present() { if printf '%s' "$3" | grep -qF "$2"; then pass=$((pass + 1)); printf '  ok    %s\n' "$1"; else fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; fi; }
absent()  { if printf '%s' "$3" | grep -qF "$2"; then fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; else pass=$((pass + 1)); printf '  ok    %s\n' "$1"; fi; }

# The invented patterns file a fixture carries. The token is invented and in no rule
# of the committed config, so only the LOCAL pass can match it.
write_local() {
  cat > "$1/.gitleaks.local.toml" <<'TOML'
[extend]
path = ".gitleaks.toml"

[[rules]]
id = "local-only"
description = "invented"
regex = '''LOCALLEAK-[0-9A-Z]{8}'''
TOML
}

# mkrepo <name> [nolocal] — a repo with the declared identity, the real hook wired
# in through a wrapper, and a bare remote beside it. Prints the repo directory.
mkrepo() {
  base="$work/$1"; mkdir -p "$base/repo"
  ( clear_git_env; git init -q --bare "$base/remote.git" )
  ( clear_git_env; cd "$base/repo" || exit 1
    git init -q . && git symbolic-ref HEAD refs/heads/main
    git config user.name "T Declared"
    git config user.email "declared@example.invalid"
    printf '# AGENTS\n\n**Commits only as `T Declared <declared@example.invalid>`**,\nfrom repo-local git config.\n' > AGENTS.md
    cp "$config" .gitleaks.toml
    printf '.gitleaks.local.toml\n' > .gitignore
    mkdir -p .githooks
    # The wrapper finds the real hook through the environment, NOT a path written into
    # the file: a committed absolute path is exactly what the home-path rule exists to
    # catch, and it caught this one — in the fixture's own seed commit — on the first run.
    printf '#!/usr/bin/env sh\nexec sh "$PUSHHOOK" "$@"\n' > .githooks/pre-push
    chmod +x .githooks/pre-push
    git config core.hooksPath .githooks
    git remote add origin "$base/remote.git"
    git add AGENTS.md .gitleaks.toml .gitignore .githooks/pre-push
    git commit -q -m seed )
  [ "${2:-}" = nolocal ] || write_local "$base/repo"
  printf '%s' "$base/repo"
}

# commit <repo> <file> <printf-format> <arg> [more commit args...]
commit() {
  r="$1"; f="$2"; fmt="$3"; arg="$4"; shift 4
  in_fixture "$r" sh -c 'printf "$2\n" "$3" > "$1" && git add "$1" && shift 3 && git commit -q -m c "$@"' _ "$f" "$fmt" "$arg" "$@"
}

run() { r="$1"; shift; if out="$( in_fixture "$r" "$@" 2>&1 )"; then got=0; else got=$?; fi; }

reached() {   # reached <name> <repo> <branch> <yes|no> — did the REMOTE get the branch?
  if ( clear_git_env; git -C "$(dirname "$2")/remote.git" rev-parse -q --verify "refs/heads/$3" >/dev/null 2>&1 ); then have=yes; else have=no; fi
  if [ "$have" = "$4" ]; then pass=$((pass + 1)); printf '  ok    %s\n' "$1"
  else fail=$((fail + 1)); printf '  FAIL  %s — the remote %s the branch\n' "$1" "$( [ "$have" = yes ] && echo has || echo lacks )"; fi
}

echo "pre-push"

# ── identity: both halves, and which one failed ─────────────────────────────
r="$(mkrepo author)"
commit "$r" f.txt '%s' one --author='Someone Else <e@example.invalid>'
run "$r" git push -q origin main
verdict "a wrong AUTHOR anywhere in the pushed history is refused, and named" 1 "$got" '[0-9a-f] author$' "$out"
absent "the refusal does not print the wrong address" "e@example.invalid" "$out"
reached "a refused push does not reach the remote" "$r" main no

r="$(mkrepo committer)"
in_fixture "$r" env GIT_COMMITTER_EMAIL=e@example.invalid sh -c 'printf "x\n" > f.txt && git add f.txt && git commit -q -m c'
run "$r" git push -q origin main
verdict "a wrong COMMITTER is refused, and only the committer is named" 1 "$got" '[0-9a-f] committer$' "$out"

# ── the patterns file must never leave the machine ──────────────────────────
r="$(mkrepo infile)"
in_fixture "$r" sh -c 'git add -f .gitleaks.local.toml && git commit -q -m c'
run "$r" git push -q origin main
verdict "a commit holding the patterns file is refused" 1 "$got" "is in the history being checked" "$out"
reached "…and does not reach the remote" "$r" main no

r="$(mkrepo missing)"
in_fixture "$r" rm -f .gitleaks.local.toml
run "$r" git push -q origin main
verdict "a missing patterns file blocks the push" 1 "$got" "gitleaks.local.toml is missing" "$out"

# ── scope: a push is judged by what it publishes ────────────────────────────
if needs_scanner "a first push of clean history passes and reaches the remote" 2; then
r="$(mkrepo clean)"
run "$r" git push -q origin main
verdict "a first push of clean history passes" 0 "$got" "" "$out"
reached "…and reaches the remote" "$r" main yes
fi

if needs_scanner "a home path committed earlier is refused, by the committed rules" 3; then
r="$(mkrepo homepath)"
commit "$r" planted.md 'run: cd /Users/%s/proj' probeuser
run "$r" git push -q origin main
verdict "a home path committed earlier is refused, by the committed rules" 1 "$got" "committed rules" "$out"
present "the refusal names the rule, file, line and commit" "absolute-home-path planted.md:1 " "$out"
absent "the refusal does not print the account name" "probeuser" "$out"
fi

if needs_scanner "a secret only the local patterns match is refused, by the local patterns" 2; then
r="$(mkrepo localtoken)"
commit "$r" f.txt 'k = %s' LOCALLEAK-ABCD1234
run "$r" git push -q origin main
verdict "a secret only the local patterns match is refused, by the local patterns" 1 "$got" "local patterns" "$out"
absent "…and the refusal does not print it" "ABCD1234" "$out"
fi

if needs_scanner "SKIP=gitleaks does not get a secret through a push"; then
r="$(mkrepo skip)"
commit "$r" f.txt 'k = %s' LOCALLEAK-ABCD1234
run "$r" env SKIP=gitleaks git push -q origin main
verdict "SKIP=gitleaks does not get a secret through a push" 1 "$got" "local patterns" "$out"
fi

# What the remote already holds is not re-judged. The bad commit goes past the hook on
# purpose (--no-verify), which is the bypass the CI layer exists to backstop.
if needs_scanner "history already on the remote is not re-scanned" 4; then
r="$(mkrepo scope)"
run "$r" git push -q origin main
commit "$r" f.txt 'k = %s' LOCALLEAK-ABCD1234
run "$r" git push -q --no-verify origin main
verdict "--no-verify gets a bad commit past the hook (the bypass CI backstops)" 0 "$got" "" "$out"
commit "$r" g.txt '%s' clean
run "$r" git push -q origin main
verdict "history already on the remote is not re-scanned" 0 "$got" "" "$out"
reached "…and the later push reached the remote" "$r" main yes
# The same holds for a NEW branch: it is judged by what it adds, not by the bad commit
# the remote already holds underneath it. Without this case, deleting the exclusion
# from the new-ref range left every other case green.
in_fixture "$r" git checkout -q -b feature3
commit "$r" h.txt '%s' clean
run "$r" git push -q origin feature3
verdict "a new branch is not re-judged by history the remote already holds" 0 "$got" "" "$out"
fi

if needs_scanner "a new branch is judged by what it adds" 4; then
r="$(mkrepo branch)"
run "$r" git push -q origin main
in_fixture "$r" git checkout -q -b feature
commit "$r" f.txt 'k = %s' LOCALLEAK-ABCD1234
run "$r" git push -q origin feature
verdict "a new branch holding a bad commit is refused" 1 "$got" "local patterns" "$out"
reached "…and the branch does not reach the remote" "$r" feature no
in_fixture "$r" sh -c 'git checkout -q main && git checkout -q -b feature2'
run "$r" git push -q origin feature2
verdict "a new branch adding nothing passes, however old its history" 0 "$got" "" "$out"
run "$r" git push -q origin :feature2
verdict "deleting a remote branch passes" 0 "$got" "" "$out"
fi

# An unresolvable remote tip cannot be produced by a real push, so these two lines
# are crafted. The fallback must announce itself AND still refuse the bad commit.
if needs_scanner "an unresolvable remote tip falls back to the wide range" 2; then
r="$(mkrepo unresolvable)"
commit "$r" planted.md 'run: cd /Users/%s/proj' probeuser
head="$(in_fixture "$r" git rev-parse HEAD)"
if out="$( in_fixture "$r" sh -c 'printf "refs/heads/main %s refs/heads/main %s\n" "$1" "$2" | sh "$3" origin unused' _ "$head" 1111111111111111111111111111111111111111 "$pushhook" 2>&1 )"; then got=0; else got=$?; fi
verdict "an unresolvable remote tip falls back to the wide range, and still refuses" 1 "$got" "committed rules" "$out"
present "…and says it fell back" "not in this clone" "$out"
fi

# PATH without gitleaks; the fixture has no .bin/gitleaks either.
r="$(mkrepo noscanner)"
run "$r" env PATH=/usr/bin:/bin git push -q origin main
verdict "a missing scanner blocks the push rather than skipping" 1 "$got" "gitleaks not found" "$out"

# ── a listing that fails is not a clean listing ─────────────────────────────
# `git log` failing inside a pipeline would read as "no offenders". No case made it
# fail, so the branch that prevents that could be deleted unnoticed.
r="$(mkrepo unlistable)"
if out="$( in_fixture "$r" sh -c 'repo_root=$(git rev-parse --show-toplevel); . "$1"; read_declared_identity; check_identity_range no-such-ref' _ "$lib" 2>&1 )"; then got=0; else got=$?; fi
verdict "a commit range git cannot list fails the identity check closed" 1 "$got" "could not be listed" "$out"
if out="$( in_fixture "$r" sh -c 'repo_root=$(git rev-parse --show-toplevel); . "$1"; check_no_patterns_file_in_range no-such-ref' _ "$lib" 2>&1 )"; then got=0; else got=$?; fi
verdict "a commit range git cannot list fails the patterns-file check closed" 1 "$got" "could not be listed" "$out"

# ── the scan function itself: a range gitleaks cannot resolve ───────────────
if needs_scanner "a range gitleaks cannot resolve fails closed, not clean"; then
r="$(mkrepo badrange)"
if out="$( in_fixture "$r" sh -c 'repo_root=$(git rev-parse --show-toplevel); . "$1"; find_scanner; scan_init; scan "x" "$repo_root/.gitleaks.toml" "a range" --log-opts=no-such-ref' _ "$lib" 2>&1 )"; then got=0; else got=$?; fi
verdict "a range gitleaks cannot resolve fails closed, not clean" 1 "$got" "could not run" "$out"
fi

echo
echo "check-history.sh"

# The CI contract: no patterns file is needed, because none can exist on a runner.
if needs_scanner "clean history passes with NO patterns file present"; then
r="$(mkrepo hclean nolocal)"
run "$r" sh "$history"
verdict "clean history passes with NO patterns file present" 0 "$got" "" "$out"
fi

r="$(mkrepo hauthor nolocal)"
commit "$r" f.txt '%s' one --author='Someone Else <e@example.invalid>'
run "$r" sh "$history"
verdict "a wrong author in the history is refused" 1 "$got" '[0-9a-f] author$' "$out"

r="$(mkrepo hinfile nolocal)"
in_fixture "$r" sh -c 'printf "x\n" > .gitleaks.local.toml && git add -f .gitleaks.local.toml && git commit -q -m c'
run "$r" sh "$history"
verdict "a copy of the patterns file anywhere in the history is refused" 1 "$got" "is in the history being checked" "$out"

if needs_scanner "a home path anywhere in the history is refused" 2; then
r="$(mkrepo hhome nolocal)"
commit "$r" planted.md 'run: cd /Users/%s/proj' probeuser
commit "$r" g.txt '%s' later
run "$r" sh "$history"
verdict "a home path anywhere in the history is refused" 1 "$got" "committed rules" "$out"
present "…naming the rule, file, line and commit" "absolute-home-path planted.md:1 " "$out"
fi

# A limit, stated and held: this layer applies the committed rules only. If it ever
# starts requiring or reading the patterns file, this case fails and forces a decision.
if needs_scanner "the CI check applies the committed rules only"; then
r="$(mkrepo hlocal)"
commit "$r" f.txt 'k = %s' LOCALLEAK-ABCD1234
run "$r" sh "$history"
verdict "the CI check applies the committed rules only (a local-only token passes it)" 0 "$got" "" "$out"
fi

r="$(mkrepo hnodecl nolocal)"
in_fixture "$r" sh -c 'printf "# AGENTS\n\nno declaration\n" > AGENTS.md && git add AGENTS.md && git commit -q -m c'
run "$r" sh "$history"
verdict "an unreadable declaration blocks the history check" 1 "$got" "cannot be read" "$out"

r="$(mkrepo hnoscan nolocal)"
run "$r" env PATH=/usr/bin:/bin sh "$history"
verdict "a missing scanner blocks the history check" 1 "$got" "gitleaks not found" "$out"

echo
if [ "$fail" -gt 0 ]; then printf '❌ push: %s passed, %s FAILED\n' "$pass" "$fail"; exit 1; fi
if [ "$skipped" -gt 0 ]; then
  printf '✅ push: %s passed, %s SKIPPED — the scan cases did not run\n' "$pass" "$skipped"
else
  printf '✅ push: %s passed\n' "$pass"
fi
