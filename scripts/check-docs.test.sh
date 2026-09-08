#!/usr/bin/env sh
# Regression tests for `scripts/check-docs.mjs`.
#
# WHY THIS EXISTS. `quality-gates.md` invariant 14: a gate that can be silently
# narrowed owes a regression test. This gate shipped without one, was reviewed
# once, and lost five ways on the first adversarial pass — four of them SILENT
# (the gate printed its success line, with its counts unchanged, while the thing
# it exists to catch walked through). Silent is the whole problem: a doc gate
# that reports "all resolve" is read as evidence, and four of these five made it
# report exactly that.
#
# THE RULE THIS ENCODES, inherited from reference/node-pnpm/test/gates.test.sh:
# **every case here is one a review found, not one the author thought of.**
#
# ASSERT THE MESSAGE, NOT THE EXIT CODE. Every failure this gate reports exits 1
# and prints the same footer, so a case that greps for "problem(s)" or checks
# only the exit status cannot tell one defect from another — it passes as long
# as ANYTHING is wrong. Each case below names a string only its own branch
# prints. That trap has already cost this repo three fixtures that passed for
# the wrong reason.
#
# FIXTURES ARE A COPY OF THE REAL TREE, not a synthetic one. The gate resolves
# real paths, parses the real BOOTSTRAP.md and the real catalogue, and dies
# fail-closed without them. A hand-built fixture tree would exercise what the
# author imagined the repo looks like — which is the failure mode that made the
# hand-verification of the other two gates useless four times running.
#
# Run: sh scripts/check-docs.test.sh

set -e

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

pass=0
fail=0

# One copy, reverted per case by re-copying the pristine tree. NEVER revert a
# fixture with `git checkout --`: it reverts to the committed state and silently
# destroys uncommitted work in the same file, which it has already done twice
# here mid-verification.
( cd "$root" && tar --exclude=.git --exclude=.DS_Store -cf - . ) | ( mkdir -p "$work/pristine" && cd "$work/pristine" && tar -xf - )

tree="$work/tree"
reset_tree() { rm -rf "$tree"; cp -R "$work/pristine" "$tree"; }
run_gate() { node "$tree/scripts/check-docs.mjs" 2>&1 || true; }
# The node call MUST be tested, not bare. `set -e` fires on an untested command
# that fails — so the first case where the gate correctly BLOCKS would kill the
# suite, with no summary line and no count. That is the same trap the gates
# suite records in its own header, hit again in a new file within the hour.
gate_status() {
  if node "$tree/scripts/check-docs.mjs" >/dev/null 2>&1; then echo 0; else echo $?; fi
}

# expect_block <name> <pattern> — the gate must FAIL and say something only this
# branch says.
expect_block() {
  name="$1"; pat="$2"
  status="$(gate_status)"
  out="$(run_gate)"
  if [ "$status" -eq 0 ]; then
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$name"
    printf '        gate PASSED; it should have blocked. It reported:\n'
    printf '        %s\n' "$(printf '%s' "$out" | tail -1)"
  elif printf '%s' "$out" | grep -qE "$pat"; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$name"
    printf '        gate blocked, but for a different reason than this case names.\n'
    printf '        wanted: %s\n' "$pat"
  fi
}

# expect_clean <name> — a false-positive guard. These matter as much as the
# blocks: a doc gate that fires on a legitimate citation is deleted in its first
# week, and both forms below fired on this gate's first run.
expect_clean() {
  name="$1"
  if [ "$(gate_status)" -eq 0 ]; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s (gate blocked a tree that is correct)\n' "$name"
    run_gate | sed 's/^/        /' | head -6
  fi
}

echo "check-docs.mjs"

# ── The baseline. If this is not clean, nothing below means anything. ────────
reset_tree
expect_clean "the repository as committed passes"

# ── 1. Case. `existsSync` is case-insensitive on APFS; GitHub and Linux CI are
#       not. A miscased citation resolved locally and was a dead link everywhere
#       that matters.
reset_tree
sed -i '' 's|`policies/process\.md`|`Policies/Process.md`|' "$tree/README.md"
expect_block "a citation whose case differs is reported" "differs in case"

# ── 2. The same bug from the other side: `endsWith(\".md\")` is case-SENSITIVE,
#       so a file named NOTES.MD was never scanned at all. It reported 27 files
#       either way, which is what made it silent.
reset_tree
printf '# Notes\n\nCites `policies/does-not-exist-at-all.md`.\n' > "$tree/policies/NOTES.MD"
expect_block "a .MD file is scanned like any other" "NOTES\.MD"

# ── 3. The catalogue split anchors on the entry id. An id outside the anchored
#       range is ABSORBED into the previous entry: uncounted, so the "N of the M
#       entries" claim still matched, and never checked for the two fields that
#       check 4 exists to enforce. The catalogue is designed to grow, and it
#       grows out of range at H.
reset_tree
cat >> "$tree/decisions/catalogue.md" <<'EOF'

### H1 — an entry outside the anchored range

**Tier 2** — applies from tier 2 up.

No Default field and no Blind spot field, and nothing noticed.
EOF
expect_block "an entry id outside the range is not absorbed" "entry heading|H1"

# ── 4. Any citation containing a one-character segment was skipped entirely —
#       not checked, and not counted. The exclusion exists for prose like `n/a`;
#       it was doing considerably more than that.
reset_tree
printf '\n`policies/x/process.md`\n' >> "$tree/README.md"
expect_block "a one-character segment does not buy an exemption" "policies/x/process\.md"

# ── 5. A broken symlink threw a raw ENOENT out of statSync. It exits 1, so it
#       fails closed — but by accident, with a stack trace instead of a finding,
#       and the fail-closed section claims that outcome by design.
reset_tree
ln -s /nonexistent/target "$tree/policies/dangling.md"
expect_block "a broken symlink is a finding, not a crash" "cannot be read"
reset_tree
ln -s /nonexistent/target "$tree/policies/dangling.md"
if run_gate | grep -q "at statSync\|node:fs:"; then
  fail=$((fail + 1)); printf '  FAIL  the symlink finding is reported, not thrown\n'
else
  pass=$((pass + 1)); printf '  ok    the symlink finding is reported, not thrown\n'
fi

# ── 6. The containment guard added by the fix above was itself a prefix test:
#       `resolve(dir).startsWith(ROOT)` is satisfied by any SIBLING whose name
#       merely starts with the repo's — `assurance-playbook-scratch` passes it.
#       A `../` citation could resolve to a directory beside the clone, green on
#       the machine that has it and dangling in every other checkout. Found by
#       reading back the fix, which the branch's own record says is where the
#       next defect always is.
reset_tree
mkdir -p "$work/tree-sibling"
printf '# Not in the repo\n' > "$work/tree-sibling/outside.md"
printf '\nSee [outside](../tree-sibling/outside.md).\n' >> "$tree/README.md"
expect_block "a ../ citation cannot escape into a sibling directory" "does not exist"

# ── False-positive guards. Both of these forms fired on this gate's first run,
#       and a gate that fires on correct citations does not survive to catch
#       anything.
reset_tree
printf '\nProse using `n/a` as a value, not a path.\n' >> "$tree/README.md"
expect_clean "\`n/a\` in prose is still not read as a path"

reset_tree
printf '\nSee [the rubric](../decisions/mechanism-rubric.md).\n' >> "$tree/policies/quality-gates.md"
expect_clean "a ../ citation still resolves"

reset_tree
printf '\n`policies/quality-gates.md` and `runners/claude/skill/bootstrap-assurance/SKILL.md`\n' >> "$tree/README.md"
expect_clean "correct citations of real files still pass"

echo
if [ "$fail" -gt 0 ]; then
  printf '❌ check-docs: %s passed, %s FAILED\n' "$pass" "$fail"
  exit 1
fi
printf '✅ check-docs: %s passed\n' "$pass"
