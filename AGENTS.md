# AGENTS.md — the assurance playbook

Onboarding for any agent working **on this repository**. Harness-specific files
(`CLAUDE.md`) are pointers plus a delta; where they disagree with this file on
shared content, **this file wins**.

This repo is not a normal project. It **describes** how projects are set up; it
is not itself set up that way, and deliberately so — it has no remote, no CI and
one maintainer, so full self-application would be ceremony. See *Self-application*
below for the one exception.

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

## Self-application: exactly one thing

The skill exists in two copies — canonical here, installed where the harness
loads it — and they drifted for a full release, leaving guidance here that the
copy which actually runs did not have. `runners/claude/check-skill-sync.sh` fails
when they disagree and is armed via `core.hooksPath=.githooks`.

That is the whole of it. Adding gates to this repo is a decision to make on
purpose, not by accretion — and the deviation is recorded: `policies/quality-gates.md`
invariant 11 wants a CI check, this is a hook, and a hook is not CI.

## Working here

- Conventional commits. Small, reviewable, each leaving the repo internally
  consistent — no doc citing a path that does not yet resolve.
- When a commit's message makes a factual claim about what it changed, the claim
  is checkable and gets checked. Two have been wrong here already.
- Prove a mechanism before committing it, and prefer a case you did not think of
  while writing it. Tests written by the author of a check inherit its blind
  spots; that is what an independent pass is for.
