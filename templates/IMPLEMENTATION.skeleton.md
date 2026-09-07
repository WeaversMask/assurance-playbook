# {{PROJECT}} — Implementation Tracker

> The single source of truth for project state. Every session starts here.
> Keep it ~150 lines: this file is *state*, not history — history lives in
> git and `docs/handovers/`.

## Current state

- **Phase:** P0-01 — Foundation
      <!-- Exactly one P<n>-<x> token on this line. The decision-trigger
           check resolves phase-boundary triggers against it and fails
           closed if it finds none or more than one. -->
- **Active plan doc:** <link the one doc a session should load>
- **Last updated:** YYYY-MM-DD (session/PR)

## Up next

| ID    | Task | Depends on | Notes |
| ----- | ---- | ---------- | ----- |
| T-001 |      |            |       |

## In progress

| ID | Task | Owner (agent/session) | Branch |
| -- | ---- | --------------------- | ------ |

## Blocked

| ID | Task | Blocker | Since |
| -- | ---- | ------- | ----- |

## Recently completed

| ID | Task | PR | Merged |
| -- | ---- | -- | ------ |

## Open decisions

> Escalations awaiting the maintainer, and every recommendation this project
> declined. Each entry: the question, the recommendation, a **trigger**, and the
> date raised.
>
> **Every open row carries a trigger**, and it is exactly one of: a **task or
> group id** (`W1`, `P1-17`), a **phase boundary** (`P2-start`, `P3-exit`), an
> **ISO date**, or **`standing`** — deliberately no trigger, revisited on demand.
> A closed row needs none.
>
> This used to read "reviewed before every merge — answered or consciously
> re-dated", which was a convention with nothing behind it: two rows walked
> straight past triggers they had set themselves and both were found by hand.
> Elapsed time is not the measure; merges are. `{{DECISION_CHECK}}` fails the
> build when a trigger has passed, which is what makes declining a recommendation
> safe rather than a way to lose it.

| ID  | Decision needed | Recommendation | Trigger | Raised |
| --- | --------------- | -------------- | ------- | ------ |
| D-000 | **Assurance tier {{TIER}}** — {{WHY}} | re-read the escalators | {{DATE_OR_PHASE}} | {{DATE}} |

*(`D-000` is seeded at bootstrap and is why this table is never empty — the check
fails closed on zero rows, because an empty table means the section was gutted
rather than that nothing has been declined.)*

## Metrics snapshot

> Updated at phase boundaries: coverage, gate ratchet counts, open risks.
