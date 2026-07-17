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

Each assurance workflow is split into **policy** (what must always be true,
and what evidence proves it — stack-agnostic) and **mechanism** (how one
particular stack enforces it). Policies live in `policies/` and are the
normative content. Mechanisms are re-derived per project by mapping each
invariant onto the target stack's native tooling; `reference/node-pnpm/`
holds one complete, battle-tested instantiation as a worked example.

A gate that was never seen to fail is decoration. The bootstrap procedure
requires **proving every gate by deliberately breaking it** before the
project is considered protected.

## Layout

| Path                        | What it is                                                                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `BOOTSTRAP.md`              | Agent-facing procedure to instantiate the policies in a new repo                                                                                |
| `policies/quality-gates.md` | Lint / typecheck / tests / coverage / review-evidence invariants                                                                                |
| `policies/secret-scanning.md` | Three-layer secret scanning, fixtures, env-file rules, incident response                                                                      |
| `policies/license-conformity.md` | SPDX allowlist, named exceptions, notices, copyleft boundary, supply-chain intake                                                          |
| `policies/identity-protection.md` | Pseudonymous identity: declared, gate-verified, leak-scanned                                                                              |
| `policies/process.md`       | Agentic execution: onboarding, context budget, review tiers, handover rotation                                                                  |
| `reference/node-pnpm/`      | Argus's real hooks, CI, and scripts — a worked example, not a copy source                                                                       |
| `templates/`                | Genericized starting files: CLAUDE.md, tracker, handover/task/PR templates, go-public checklist, local gitleaks patterns example                 |
| `skill/bootstrap-assurance/` | Canonical copy of the Claude Code skill that drives BOOTSTRAP.md (installed at `~/.claude/skills/bootstrap-assurance/`)                        |

## Using it

**Human quick start:** create the new project repo (fresh `git init` — never a
fork of a private repo), then in a Claude Code session inside that repo run
`/bootstrap-assurance`. The skill walks BOOTSTRAP.md end to end and stops at
the steps only you can do (identity decision, local patterns file, remote
creation).

**Manual:** follow [BOOTSTRAP.md](BOOTSTRAP.md) yourself; it is written to be
executable by either a human or an agent.

## Maintaining the playbook

- When a policy improves in a live project (a new gotcha, a hardened gate),
  port the *invariant* back here; the project keeps its own mechanism.
- Policies lead, the reference lags: where a policy mandates something the
  Argus reference doesn't implement yet, the reference README says so
  explicitly.
- Never commit personal identifiers here — same rule as everywhere else.
  The local patterns file is per-machine and gitignored, even in this repo.
