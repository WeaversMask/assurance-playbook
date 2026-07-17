<!--
  PROJECT-PLAN template — the comprehensive up-front implementation document,
  written by the maintainer or an agent at project start, BEFORE or alongside
  /bootstrap-assurance.

  How this document fits the workflow (read before writing a word):

  * It is a SOURCE, not a living document. After it is agreed, it is
    SHREDDED into the repo's modular docs (see §14, the shred map) and the
    original is archived immutable at docs/plan/archive/PROJECT-PLAN-v1.md.
    The modular docs are canonical from then on — this file is never
    updated to match reality; reality is tracked in docs/IMPLEMENTATION.md.
  * Every section carries a CONTRACT comment: which workflow artifact
    consumes it and what form makes it consumable. Content that meets the
    contract flows into the workflow mechanically; content that doesn't is
    where "sudden surprises" come from.
  * Writing rules, both author kinds (human or agent):
      1. Decisions state their alternatives — every "we use X" that had a
         plausible Y is ADR-extractable and gets listed in §12.
      2. Dependencies are license-checked AT DESIGN TIME (§4) — never
         commit the design to a library the intake gate will reject.
      3. Architecture is stated as enforceable rules ("A never imports
         B"), not aspirations ("keep things decoupled").
      4. Tasks are session-sized with testable acceptance criteria (§11).
      5. No personal identifiers, secrets, or absolute local paths — the
         scanning policies apply to planning docs too.
      6. Glossary terms (§3) are used consistently from here on — in this
         doc, the code, the tests, and the UI.
-->

# {{PROJECT}} — Project Plan

**Status:** Draft | Agreed (shredded YYYY-MM-DD)
**Author:** <maintainer / agent + session>
**Stack:** <language, package manager, test runner, target platforms>

## 1. Product overview

<!-- CONTRACT: seeds the repo README and docs/guide/. One paragraph pitch +
     goals; non-goals are load-bearing — they are what keeps scope stable
     when tasks get decomposed. -->

_What this is, for whom, and the single most important thing it does._

**Goals:** _3–7 bullets._
**Non-goals (deliberate):** _what this project will NOT do, so nobody
"helpfully" adds it later._

## 2. Architecture

<!-- CONTRACT: becomes docs/architecture.md + the boundary rules the
     quality gates enforce (lint boundaries / self-scan / review). Every
     rule here must be mechanically checkable — name modules, not vibes. -->

**Style:** _e.g. hexagonal (ports & adapters), layered, pipeline — and why
in one sentence (full rationale → seed ADR, §12)._

**Module map:** _one row per top-level module/package._

| Module | Responsibility (one line) | May import | Must never import |
| ------ | ------------------------- | ---------- | ----------------- |
|        |                           |            |                   |

**Dependency rule:** _the import direction in one enforceable sentence,
e.g. "apps → orchestration → domain ← adapters; never the reverse."_

**Boundary notes:** _anything subprocess-only, interface-only, or
zero-dependency by design — these become contract tests and license-
boundary rules._

## 3. Domain model & ubiquitous language

<!-- CONTRACT: the glossary is binding — code identifiers, test names,
     docs, and UI labels use these exact terms. Consumed by every future
     session; inconsistency here multiplies into every file. -->

| Term | Meaning (one line) | Not to be confused with |
| ---- | ------------------ | ----------------------- |
|      |                    |                         |

_Core entities and their relationships — a short mermaid diagram beats
prose:_

```mermaid
classDiagram
```

## 4. Core libraries & external tools

<!-- CONTRACT: consumed by the license-conformity + supply-chain intake
     gate (policies/license-conformity.md). Every row is checked against
     the SPDX allowlist BEFORE the design is agreed — a dependency the
     gate would reject must not appear here without its exception row.
     "Linked vs subprocess" decides the copyleft boundary. -->

| Dependency | Role | License (SPDX) | Linked or subprocess | Intake notes (allowlist pass / named exception / install scripts?) |
| ---------- | ---- | -------------- | -------------------- | ------------------------------------------------------------------ |
|            |      |                |                      |                                                                    |

**Alternatives considered:** _for each load-bearing choice, the runner-up
and why it lost (one line each — ADR-extractable, list in §12)._

**External tools the user installs themselves:** _name, role, license —
seeds the README prerequisites section._

## 5. Functionality inventory

<!-- CONTRACT: each capability maps to exactly one phase in §11; anything
     unmapped is scope creep caught at design time. -->

| Capability | Priority (MVP / later / stretch) | Phase (§11) |
| ---------- | -------------------------------- | ----------- |
|            |                                  |             |

## 6. Data flow

<!-- CONTRACT: becomes the heart of docs/architecture.md. Pick the 2–4
     flows that define the system end-to-end; per flow: entry point →
     transformations (named modules from §2) → outputs/side effects. -->

```mermaid
flowchart LR
```

_Persistence & state: what is stored, where, in what shape, and what is
deliberately NOT persisted._

## 7. Interface surfaces

<!-- CONTRACT: public surfaces get doc comments from day one
     (documentation policy §2) and freeze late — mark stability. -->

_CLI commands / HTTP endpoints / UI screens / library API — each surface:
its contract, and whether it is stable, experimental, or internal._

## 8. Cross-cutting concerns

<!-- CONTRACT: these become repo-wide conventions the review pass holds
     every PR against — state them as rules, not preferences. -->

- **Error handling:** _errors-as-values vs exceptions, and where each._
- **Configuration:** _sources, precedence, validation at startup
  (.env pattern per secret-scanning policy §6)._
- **Logging/observability:** _what, where, never-log list (secrets, PII)._
- **Concurrency model:** _if applicable._

## 9. Testing strategy

<!-- CONTRACT: consumed by the quality gates — coverage floors confirmed
     here become the bootstrap inputs; the fixture approach must respect
     the secret-scanning fixture rules. -->

- **Pyramid target:** _e.g. ~70% unit / ~20% integration / ~10% e2e._
- **Coverage floors:** _confirm or adjust the default 85% line / 80%
  branch._
- **Contract tests:** _which boundaries from §2 get them._
- **Fixtures:** _approach; secret-shaped fixtures use the synthetic
  fakeSecret pattern + allowlisted directory, never real-looking data._

## 10. Security & privacy posture

<!-- CONTRACT: consumed by the secret-scanning and identity policies at
     bootstrap; anything project-specific beyond the standard gates goes
     here (threat notes, data sensitivity, pseudonymity decision). -->

- **Identity:** _which public identity this project commits under (per
  identity-protection policy — decided, not defaulted)._
- **Sensitive data the system touches:** _and how it is kept out of the
  repo, logs, and fixtures._
- **Threat notes:** _the 2–3 abuse cases worth designing against now._

## 11. Phase roadmap & task decomposition

<!-- CONTRACT: the tracker (docs/IMPLEMENTATION.md) consumes this
     directly — phases become phase docs, tasks become Up-Next rows.
     RULES: every task fits ONE session (context budget); every task has
     testable acceptance criteria; IDs (P0-01…) are used verbatim in
     branches, commits, and PRs; dependencies are explicit so agents can
     pick any unblocked task. Decompose fully for phase 0–1; later phases
     may stay at capability level until their predecessor is underway. -->

### Phase 0 — Foundation

_Exit criteria: …_

| ID    | Task | Acceptance criteria (testable) | Depends on |
| ----- | ---- | ------------------------------ | ---------- |
| P0-01 |      |                                |            |

### Phase 1 — <name>

_Exit criteria: …_

| ID    | Task | Acceptance criteria (testable) | Depends on |
| ----- | ---- | ------------------------------ | ---------- |

### Later phases (capability level)

| Phase | Theme | Exit criteria sketch |
| ----- | ----- | -------------------- |

## 12. Seed ADRs

<!-- CONTRACT: extracted verbatim into docs/adr/ at shredding time using
     templates/ADR.template.md. Any decision in this doc with a plausible
     alternative that is NOT listed here will silently live only in the
     archived plan — that is a future surprise. List them all. -->

| ADR  | Decision (from section) | Alternatives it beat |
| ---- | ----------------------- | -------------------- |
| 0001 |                         |                      |

## 13. Risks & open questions

<!-- CONTRACT: risks seed docs/risks.md; open questions seed the
     tracker's Open Decisions table (each with a recommendation — the
     escalation format from the process policy). -->

| Risk / question | Impact | Mitigation / recommendation | Owner |
| --------------- | ------ | --------------------------- | ----- |

## 14. Shred map (executed once, at agreement)

<!-- CONTRACT: this is the handoff. When the maintainer marks the plan
     Agreed, a session executes this table top to bottom, then moves this
     file to docs/plan/archive/PROJECT-PLAN-v1.md and records the
     shredding as a docs PR. After that, the modular docs are truth and
     this file is history — never edited again. -->

| Section | Destination | Notes |
| ------- | ----------- | ----- |
| §1 | root `README.md` + `docs/guide/` seed | non-goals verbatim |
| §2, §6 | `docs/architecture.md` | boundary table + flows; wire boundary rules into lint/self-scan config where the stack allows |
| §3 | `docs/architecture.md` §Glossary | binding vocabulary |
| §4 | dependency intake: run the license gate against the planned tree; exceptions → the ledger; externals → README prerequisites | before any install |
| §5, §11 | `docs/plan/phases/phase-NN-<name>.md` (one file per phase) + `docs/IMPLEMENTATION.md` Up-Next | tasks verbatim with IDs |
| §7 | surface docs + doc-comment obligations | stability markers kept |
| §8, §9 | `CLAUDE.md` conventions + coverage config | rules, not prose |
| §10 | bootstrap Phase 0 inputs (identity, floors) | confirm, don't re-ask |
| §12 | `docs/adr/0001…` via ADR template | one PR per batch is fine |
| §13 | `docs/risks.md` + tracker Open Decisions | recommendations included |
