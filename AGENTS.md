# AGENTS.md — the assurance playbook

Onboarding for any agent working **on this repository**. Harness-specific files
(`CLAUDE.md`) are pointers plus a delta; where they disagree with this file on
shared content, **this file wins**.

This repo is not a normal project. It **describes** how projects are set up; it
is not itself set up that way. Most of what the playbook installs judges a
project's code — dependencies, tests, coverage, releases, incoming pull requests —
and this repo has none of those to judge, so those gates would check nothing here.
*Self-application* below lists the three things that do run. What is still
missing — the safety class and CI — is an open row in [TRACKER.md](TRACKER.md),
not an unstated gap.

## This repository's identity

**Commits only as `WeaversMask <131781531+WeaversMask@users.noreply.github.com>`**,
from repo-local git config — never inherited from global config. **Pseudonymous:
yes.** Nothing verifies either yet (`TRACKER.md`, D-004): until something does,
this is a declaration, not a gate.

## What is here

| Path | What it is |
| --- | --- |
| `policies/` | **The normative content.** Six stack-agnostic invariant sets. Everything else serves these. |
| `decisions/` | The questions a project must answer, and the rubric for scoring a mechanism the playbook has never heard of. Variable, not normative. |
| `BOOTSTRAP.md` | The installation order — runnable by a human or an agent, in the *target* project's repo. |
| `templates/` | Runner-agnostic starting files. |
| `runners/` | Harness-specific furniture, installed only for the harness a project names. |
| `reference/node-pnpm/` | One worked instantiation. **An exhibit, never a copy source.** |

## Before you change anything

1. **Policies lead; the reference lags.** Where a policy requires something the
   reference does not implement, the reference's README says so explicitly.
   Never resolve the gap by weakening the policy, and never let the reference
   lead silently — that inversion has happened here and went unnoticed for a
   release.
2. **A change to an invariant is a change to every project built from it.** New
   invariants come from something that actually failed somewhere, with the
   failure recorded. An invariant nobody has seen fire is the decoration this
   repo exists to argue against.
3. **Read the whole policy before editing part of it.** Several invariants exist
   because of a specific incident, and the reasoning is in the prose around them.

## Never, in this repo either

- **No personal identifiers, anywhere.** No personal emails, no absolute
  home-directory paths (`~/assurance-playbook`, never the expanded form), no
  machine identifiers — in file content, in examples, in commit messages, and in
  the output any script here prints. Output gets pasted into handovers, so a
  script that prints an absolute path leaks one just as surely as a committed
  file does.
- **Never create, read, or ask about `.gitleaks.local.toml`** — here or anywhere.
  It is maintainer-written, per machine, and gitignored, including in this repo.
- **Never weaken the no-bypass rule** on the secret scan, at any layer, in any
  restructuring.
- **Agents never merge.** Branches and commits, yes; landing them is the
  maintainer's.

## Self-application: exactly three things

This repo does not run the playbook on itself. Three exceptions earned their
place, each after something broke that nothing was watching:

1. **The skill-copy freshness check.** The two copies drifted for a full release,
   leaving guidance here that the copy which actually runs did not have.
   `runners/claude/check-skill-sync.sh`.
2. **`scripts/check-docs.mjs`** — path citations, `Phase N.M` cross-references,
   phase item ordering, and the catalogue's own counts and fields. Eight of the
   nine regressions on this branch were in markdown and none had mechanical
   protection.

   It checks **claims about the present that resolve to a name** and nothing
   about wording — a doc gate that fires on phrasing is deleted within a week,
   and one that tries to keep two documents in prose agreement fires on phrasing
   by construction. Its ongoing cost is one maintained list: the roots that name
   a *bootstrapped* project's tree (`docs/`, `src/`, …) rather than this one.

3. **Regression suites for the executable gates** —
   `reference/node-pnpm/test/gates.test.sh` and
   `runners/claude/check-skill-sync.test.sh`. Invariant 14 says a gate that can
   be silently narrowed owes a regression test; these two gates were broken by
   their own fixes four times, once by a change that would have blocked the
   first commit of every bootstrapped repo.

All are armed by `core.hooksPath=.githooks`, which runs them on every commit
here.

**If you change either gate, add the case that would have caught the change you
are making, before you make it.** Every case in those suites is one a review
found, not one their author thought of — which is the only reason they catch
anything. The author's own fixtures had been green through all four breakages.

**And check the tests can still fail.** Break the gate deliberately and confirm
the suite goes red. A case that passes for the wrong reason is a false pass, and
that has happened three times here: twice a fixture tripped an earlier branch
than the one it named, once a temp-directory path could not reach the condition
being asserted. Assert the *message*, not only the exit code.

Recorded deviation: `policies/quality-gates.md` invariant 11 wants a CI check for
a duplicated file; this is a hook, and a hook is not CI.

## Working here

- Conventional commits. Small, reviewable, each leaving the repo internally
  consistent — no doc citing a path that does not yet resolve.
- When a commit's message makes a factual claim about what it changed, the claim
  is checkable and gets checked. Two have been wrong here already.
- Prove a mechanism before committing it, and prefer a case you did not think of
  while writing it. Tests written by the author of a check inherit its blind
  spots; that is what an independent pass is for.
