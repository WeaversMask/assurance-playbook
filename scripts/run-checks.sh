#!/usr/bin/env sh
# This repository's verification checks — runnable by anyone, at any time,
# without committing anything:
#
#   sh scripts/run-checks.sh
#
# They are also what `.githooks/pre-commit` runs. THE SPLIT IS DELIBERATE. The
# hook additionally enforces the safety class, which requires a per-machine file
# only the maintainer can write — so a reader who cloned this repo to try the
# checks would be blocked by a gate that has nothing to do with them. Anyone can
# run this; only the maintainer can commit.
#
# SCOPE, deliberately narrow. This repo does NOT self-apply the playbook. Most of
# what the playbook installs judges a project's code — dependencies, tests,
# coverage, releases, incoming pull requests — and this repo has none of those to
# judge. Three things earn their place here, and each was earned rather than
# assumed:
#
#   1. The skill-copy freshness check. The two copies drifted for a full
#      release, leaving guidance here that the copy which actually runs lacked.
#
#   2. The documentation-consistency check. Eight of the nine regressions on
#      that branch were in markdown — a moved directory, a renumbered phase, a
#      stale count — and none had any mechanical protection; every one was found
#      by running the same greps again by hand. It checks claims about the
#      present that resolve to a name, and nothing about wording.
#
#   3. The gate regression suites. `quality-gates.md` invariant 14 says a gate
#      that can be silently narrowed owes a regression test, and the two gates
#      this repo ships as executable code were broken by their own fixes four
#      times — once by a change that would have blocked the first commit of
#      every bootstrapped repo. Every case in those suites is one a review
#      found, not one their author thought of.
#
#      `check-docs.test.sh` joined them after the doc gate — the newest of the
#      three, and the only one that had shipped with no suite at all — lost six
#      ways on its first adversarial pass, four of them silently, printing its
#      success line with its counts unchanged while the defect walked through.
#
# Adding anything else is a decision to make on purpose, not by accretion.

set -e

repo_root="$(git rev-parse --show-toplevel)"

sh "$repo_root/runners/claude/check-skill-sync.sh"
sh "$repo_root/runners/claude/check-skill-sync.test.sh"
sh "$repo_root/reference/node-pnpm/test/gates.test.sh"
sh "$repo_root/scripts/check-docs.test.sh"
node "$repo_root/scripts/check-docs.mjs"
