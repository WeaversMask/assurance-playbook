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
| T0 — tier | **3.** Asked as the catalogue asks it — if this were wrong tomorrow, how would you find out? A wrong instruction here is carried out by an agent in someone else's repository and looks right until that project fails, which is the definition of 3; the public-repo escalator alone gives 2. It applies to the content, not the gate set: this repo runs only the four things AGENTS.md lists, because most of what a tier gates judges code this repo does not contain. **The 12 catalogue entries that tier 2 and 3 admit are not yet worked here**; most are plainly n/a (no code to test, no dependencies to allowlist), but that is not yet recorded per entry. | answered 2026-10-17 — the agent's recommendation, applied at the maintainer's instruction; change it freely |
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
| D-000 | **Assurance tier 3** — see T0 above. The catalogue asks a tier-2+ project for a phase-boundary trigger; this repo has no phases, so the row carries a date, which the decision check accepts at any tier | re-read the escalators | 2027-03-15 | 2026-09-15 |
| D-001 | **Closed 2026-10-17** — `templates/check-decisions.sh`, POSIX sh and awk, is held to the Node original's behaviour: all 28 review-found cases run against both, and the two were diffed byte for byte over 5,900 generated trackers with no mismatch. Limits, stated: ASCII only; and it has since passed on BSD awk, GNU Awk 5.2.1 and mawk 1.3.4 in CI (D-002), though not on busybox awk | — | 2026-12-15 | 2026-09-15 |
| D-002 | **Closed 2026-10-17** — `.github/workflows/checks.yml` ran green on every job (run 39049017192, private repository): `ubuntu-latest` (dash, GNU Awk 5.2.1, GNU sed 4.9, GNU grep 3.11), `ubuntu-latest` with mawk 1.3.4 made `awk` (the row fails unless it really is mawk), `macos-latest` (arm64: BSD awk 20200816, BSD sed and grep), and the history check — every suite, no skipped case, and the real gitleaks download and its checksum on linux/x64 and darwin/arm64. The first run failed on macOS: eleven workflow cases needed PyYAML, which that runner lacks, and the skip guard caught it. Still untested: busybox awk and ash (Alpine), the darwin/x64 and linux/arm64 checksums (copied from the reference, never downloaded), Windows | — | 2026-11-15 | 2026-09-15 |
| D-003 | **Nothing reads this table** | make the tracker path in `check-decisions.mjs` a parameter and run it from `.githooks/pre-commit` | 2026-12-15 | 2026-09-15 |
| D-004 | **Closed 2026-10-17** — the safety class is armed on pre-commit: the commit's identity, a committed home-path rule, and a scan of the staged changes against both the committed rules and the maintainer's per-machine `.gitleaks.local.toml`, which is required and refused when absent, ruleless, still holding example values, or staged. One layer only — see D-005 | — | 2026-10-15 | 2026-09-15 |
| D-005 | **Closed 2026-10-17** — a pre-push hook (`.githooks/pre-push`) and a CI history check (`scripts/check-history.sh`) now sit behind pre-commit, share `.githooks/safety-lib.sh`, and are tested by `scripts/check-push.test.sh`. Limits, stated: `--no-verify` skips both hooks; the CI check sees the committed rules only; there is no bot allowlist, so a web-UI merge (committer GitHub) would be refused; and the CI layer has since run green on GitHub (D-002) | — | 2026-11-15 | 2026-10-17 |
