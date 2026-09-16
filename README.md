# Assurance Playbook

Portable quality, safety, license, and identity assurance — extracted from the
Argus codebase (Node/pnpm monorepo) into a form a maintainer or an agent can
instantiate in a new repository. The **policies** are stack-agnostic; the
**mechanisms** are derived per project. The evidence so far is narrow, and worth
knowing: the mechanisms come from one Node/pnpm project, the procedure has been
executed on one other stack — a Python package, as far as Phase 2's human stop —
and one mandatory gate has a worked implementation only in Node. See
*Prerequisites*.

> **Public, and read-only.** This repository distributes the playbook; it does
> not take pull requests yet. What the playbook protects — personal identifiers,
> and the per-machine patterns that find them — is kept *outside* it by design
> ([identity-protection.md](policies/identity-protection.md) invariant 5), which
> is what makes it publishable. Its own answers to the questions it asks every
> project are in [TRACKER.md](TRACKER.md).

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
| `templates/`                | Runner-agnostic starting files: `AGENTS.md`, project plan, tracker with its decision table, ADR/PR/handover/task/package-README templates, the bootstrap summary, the go-public checklist, and the local scanner-patterns example |
| `runners/`                  | Runner-specific furniture, installed only for the harness a project names. `runners/claude/` holds the skill (canonical copy; installed at `~/.claude/skills/bootstrap-assurance/`), the harness entry-file template, and the sync check |
| `scripts/`                  | This repo's own maintenance checks — currently the documentation-consistency gate. Not part of what a project installs                            |
| `TRACKER.md`                | This repo's own Phase 0 answers and open decisions. Not part of what a project installs                                                          |

## Using it

**Nothing to install.** Clone this repository anywhere. Then work in the project
you are setting up — never in this repository:

- **With any agent:** tell it where the clone is, and to read the clone's
  `AGENTS.md` and follow its `BOOTSTRAP.md` in your project. The procedure assumes
  no particular harness, and stops at the steps only you can do: creating the
  remote, and — for a pseudonymous project — writing the local
  personal-identifier patterns file.
- **By hand:** follow [BOOTSTRAP.md](BOOTSTRAP.md) yourself. It is written to be
  executable by a human or an agent.
- **With Claude Code, optionally:** the `/bootstrap-assurance` skill walks the
  same procedure end to end. It is a convenience, not a requirement. From the
  clone:

  ```sh
  mkdir -p ~/.claude/skills/bootstrap-assurance
  cp runners/claude/skill/bootstrap-assurance/SKILL.md ~/.claude/skills/bootstrap-assurance/
  ```

  Tell the session where the clone is; the skill asks if it has not been told.

Start the project from a fresh `git init`, never a fork of a private repo. You can
write the up-front design first, from `templates/PROJECT-PLAN.template.md`: it
pre-answers several catalogue entries (§13a maps which) and shreds into the new
repo's docs.

## Prerequisites

**To use the playbook:** git, plus whatever your own stack needs. `BOOTSTRAP.md`
derives each gate's mechanism for your stack, so the tools are chosen per project.

**One cost to know before you start.** The decision-trigger check (Phase 2.10) is
mandatory at every tier, and its only worked implementation is a Node script,
`reference/node-pnpm/scripts/check-decisions.mjs`. On any other stack, run it under
Node or write the equivalent — the shape that ports is described in its header. A
portable implementation is an open decision in [TRACKER.md](TRACKER.md) (D-001).

**To run this repository's own checks** — `sh .githooks/pre-commit`, armed once
per clone with `git config core.hooksPath .githooks`:

| Tool | Licence | Needed for |
| --- | --- | --- |
| POSIX `sh`, `sed`, `awk`, `diff`, `tar` | — | every suite |
| git | GPL-2.0-only | the suites build throwaway repositories |
| Node.js 22 | MIT | the docs gate, and the decision check under test |
| Python 3 | Python-2.0 | one docs-suite case |
| gitleaks | MIT | optional — without it the hook-execution cases are skipped, and say so |

They have only run on macOS so far (D-002).

## Built with an earlier version

Two projects were set up using earlier versions of this playbook, before it was
extracted into the form here:

- **[argus-oss](https://github.com/WeaversMask/argus-oss)** — the Node/pnpm
  monorepo `reference/node-pnpm/` was taken from.
- **Gradient** — a Node/pnpm project. Private, so there is nothing to link.

Neither is a clean run of the procedure as it stands today: both predate it, and
what they show is this gate set surviving daily use, not a bootstrap. The
execution evidence for the current `BOOTSTRAP.md` is the narrower claim at the
top of this file.

## Maintaining the playbook

- When a policy improves in a live project (a new gotcha, a hardened gate),
  port the *invariant* back here; the project keeps its own mechanism.
- Policies lead, the reference lags: where a policy mandates something the
  Argus reference doesn't implement yet, the reference README says so
  explicitly.
- **The skill has two copies** — the canonical one here and the installed one
  at `~/.claude/skills/bootstrap-assurance/`, which is the copy that actually
  runs. They drifted once for a full release (the invariant-5a guidance sat here
  unrunnable), and `.githooks/pre-commit` now fails when they disagree. Edit the
  canonical file, then copy it across and confirm:

  ```sh
  cp runners/claude/skill/bootstrap-assurance/SKILL.md ~/.claude/skills/bootstrap-assurance/SKILL.md
  sh runners/claude/check-skill-sync.sh
  ```
- Never commit personal identifiers here — same rule as everywhere else.
  The local patterns file is per-machine and gitignored, even in this repo.

## Licence

MIT — see [LICENSE](LICENSE).
