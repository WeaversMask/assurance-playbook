# TRACKER — the playbook's own decisions

> This repository's answers to the Phase 0 questions it asks every project, and
> the decisions it has left open. Not part of anything a project installs.
>
> **Nothing reads the Open decisions table yet** (D-003). It is written in the
> format `reference/node-pnpm/scripts/check-decisions.mjs` reads, so arming that
> check here means pointing it at this file rather than rewriting it. Until then a
> trigger that passes fails nothing, and this table is a note — which is the thing
> the playbook argues a declined decision must never be.

## Phase 0 answers

| Entry | Answer | Recorded as |
| --- | --- | --- |
| T0 — tier | Not yet self-assessed. The escalator sets a floor of 2, because the repo will be public. | open — D-000 |
| A1 — pseudonymous | Yes. Every commit since the first is under the pseudonym. | default — announced, not asked |
| A2 — persona | Shared: **WeaversMask**, the persona Argus and Gradient also commit as. Declared in `AGENTS.md`. Consequence accepted: publishing this repo publishes its gate set, and a distinctive gate set is a signature ([identity-protection.md](policies/identity-protection.md) invariant 8), so a later project that must stay unlinkable from this persona cannot adopt these gates unmodified. | asked, 2026-09-11 |
| A3 — visibility | Public, read-only, no pull requests yet — a divergence from the default. What the repo protects is kept outside it by design (invariant 5), so it is publishable as built. A project records a divergence as an ADR; this repo has no ADR directory, so the reason is this row. | asked, 2026-09-11 |
| B1 — licence | MIT, one licence for everything. `LICENSE`. | asked, 2026-09-11 |

## Open decisions

> Every open row carries a trigger: a task id, a phase boundary, an ISO date, or
> `standing`. This repo has no task tables and no phases, so every trigger here is
> a date.

| ID | Decision needed | Recommendation | Trigger | Raised |
| --- | --- | --- | --- | --- |
| D-000 | **Assurance tier** — floor 2 from the public escalator; not yet self-assessed | 3. A wrong instruction here is executed by an agent in another repo and looks right until that repo fails, and the escalator for output consumed by another system sets 3 | 2027-03-15 | 2026-09-15 |
| D-001 | **The decision-trigger check has one implementation, in Node** — `BOOTSTRAP.md` Phase 2.10 makes it mandatory at every tier, so a project on any other stack writes its own | a POSIX sh and awk implementation with its own regression suite, since every project already runs sh hooks; meanwhile state the cost at Phase 2.10 and in the README | 2026-12-15 | 2026-09-15 |
| D-002 | **No CI** — the checks have only ever run on macOS | one job running the pre-commit hook's checks on Linux and macOS, once the remote exists | 2026-10-15 | 2026-09-15 |
| D-003 | **Nothing reads this table** | make the tracker path in `check-decisions.mjs` a parameter and run it from `.githooks/pre-commit` | 2026-12-15 | 2026-09-15 |
| D-004 | **The personal-identifier layer is half armed.** The identity check, the committed home-path rule and the staged scan landed 2026-09-16; the per-machine `.gitleaks.local.toml` requirement is not armed, so identifiers that only a local pattern would match are still uncaught | arm the local-config requirement once the maintainer has written that file, before the visibility flip | 2026-10-15 | 2026-09-15 |
