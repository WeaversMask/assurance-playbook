# Assurance Playbook

Portable quality, safety, license, and identity assurance for any project —
extracted from the Argus codebase (Node/pnpm monorepo) into a stack-agnostic
form that a maintainer or an agent can instantiate in a new repository of any
language or ecosystem.

> **This repository stays private, permanently.** It is operational tooling.
> The identity-protection policy and the go-public checklist reference the
> very things they protect; nothing here needs to be public, so nothing here
> ever is. See [policies/identity-protection.md](policies/identity-protection.md).

## The design

Three kinds of content, and keeping them apart is what makes this portable:

- **Policy** — what must always be true, and what evidence proves it.
  Stack-agnostic, normative, in `policies/`.
- **Decisions** — what a project must *choose*, each with a default, the
  alternatives, a test for which applies, and what happens when the answer is
  "not now". In `decisions/`.
- **Mechanism** — how one stack enforces a policy. Re-derived per project by
  scoring candidates against `decisions/mechanism-rubric.md`;
  `reference/node-pnpm/` is one complete instantiation, as an exhibit.

The policy says dependencies carry acceptable licences. The catalogue asks which
licences, scoped how, with notices covering what. The invariant does not change
per project; the answer always does.

**It advises, and it still installs.** The advisor is Phase 0: an interview over
22 catalogue entries, sized by how silently the project fails. Its record is what
`BOOTSTRAP.md` then executes against, so a project set up through the questions
ends up as genuinely gated as one set up through the old defaults.

A gate that was never seen to fail is decoration. The bootstrap procedure
requires **proving every gate by deliberately breaking it** before the project
is considered protected.

**And recommending is not enforcing**, which is the tension an advisor has to
resolve: advice decays. So a declined recommendation becomes a tracked row naming
the event that brings it back, and a check fails the build when that event has
passed. Decline nothing and the table is empty and costs nothing — the cost lands
only on the debt actually taken on. That check is why declining is allowed at
all.

## Layout

| Path                        | What it is                                                                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `BOOTSTRAP.md`              | Agent-facing procedure to instantiate the policies in a new repo                                                                                |
| `policies/quality-gates.md` | Lint / typecheck / tests / coverage / review-evidence invariants                                                                                |
| `policies/secret-scanning.md` | Three-layer secret scanning, fixtures, env-file rules, incident response                                                                      |
| `policies/license-conformity.md` | SPDX allowlist, named exceptions, notices, copyleft boundary, supply-chain intake                                                          |
| `policies/identity-protection.md` | Pseudonymous identity: declared, gate-verified, leak-scanned                                                                              |
| `policies/process.md`       | Agentic execution: onboarding, context budget, review tiers, handover rotation                                                                  |
| `policies/documentation.md` | Documentation structure: capture streams, homes, triggers, per-task delta, doc-comment-first reference                                          |
| `decisions/catalogue.md`    | The 22 questions a project answers at Phase 0 — default, alternatives, how to tell which applies, what each branch costs, and where the answer is recorded |
| `decisions/mechanism-rubric.md` | Seven criteria for scoring a mechanism the playbook has never heard of, with a pass rule and a worked example. Replaces the tool table that used to rot here |
| `reference/node-pnpm/`      | Real hooks, CI, and scripts — a worked example, not a copy source                                                                               |
| `templates/`                | Runner-agnostic starting files: `AGENTS.md`, project plan, tracker with its decision table, ADR/PR/handover/task templates, the bootstrap summary, the go-public checklist, and the local scanner-patterns example |
| `runners/`                  | Runner-specific furniture, installed only for the harness a project names. `runners/claude/` holds the skill (canonical copy; installed at `~/.claude/skills/bootstrap-assurance/`), the harness entry-file template, and the sync check |
| `scripts/`                  | This repo's own maintenance checks — currently the documentation-consistency gate. Not part of what a project installs                            |

## Using it

**Quick start:** optionally write the up-front design first from
`templates/PROJECT-PLAN.template.md` — it pre-answers several catalogue entries
(§13a maps which) and shreds into the repo's docs. Then create the new project
repo (fresh `git init` — never a fork of a private repo) and run the procedure
inside it: **any agent can follow `BOOTSTRAP.md` directly**, and Claude Code has
`/bootstrap-assurance`, which walks it end to end and stops at the steps only you
can do (the local patterns file, remote creation).

**Manual:** follow [BOOTSTRAP.md](BOOTSTRAP.md) yourself; it is written to be
executable by either a human or an agent.

## Maintaining the playbook

- When a policy improves in a live project (a new gotcha, a hardened gate),
  port the *invariant* back here; the project keeps its own mechanism.
- Policies lead, the reference lags: where a policy mandates something the
  Argus reference doesn't implement yet, the reference README says so
  explicitly.
- **The skill has two copies and nothing enforces their agreement** — the
  canonical one here and the installed one at
  `~/.claude/skills/bootstrap-assurance/`, which is the copy that actually
  runs. It has drifted before (the invariant-5a guidance sat here unrunnable
  for a full release), so edit the canonical file, then copy it across and
  confirm:

  ```sh
  cp runners/claude/skill/bootstrap-assurance/SKILL.md ~/.claude/skills/bootstrap-assurance/SKILL.md
  sh runners/claude/check-skill-sync.sh
  ```
- Never commit personal identifiers here — same rule as everywhere else.
  The local patterns file is per-machine and gitignored, even in this repo.
