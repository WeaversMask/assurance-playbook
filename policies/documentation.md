# Policy: Documentation Structure & Progressive Capture

> Stack-agnostic. Generalized from Argus `docs/plan/03-documentation.md`.
> The per-task obligation this defines is enforced through the completion
> checklist in [process.md](process.md) and the PR template's
> Documentation section — a forced, conscious decision every task is what
> makes documentation accumulate; a soft reminder does not.

## Principle

Documentation is **captured progressively, in the cheapest durable form
closest to the code, the moment its trigger fires** — because rationale is
freshest when the code is written, and writing docs at the end is
archaeology. A polished docs *site* is a late assembly phase that edits
and wires together what the streams below have already captured; commit to
no site tooling before then. Serve four reader goals: **understand** the
product, **trust** it, **maintain** it, **reuse** it.

## Canonical layout (created at bootstrap)

```
docs/
  IMPLEMENTATION.md   living tracker (~150-line budget)         — state, not history
  HANDOVER.md         session handover (~100-line budget)
  handovers/          archived handover snapshots
  adr/                decision records (templates/ADR.template.md)
  architecture.md     how the modules fit together
  guide/              user-facing how-to docs
  dev/                contributor recipes, one per repeatable pattern
  risks.md            risk register (create when the first risk appears)
  plan/               process/documentation/quality-gates policies (installed
                      at bootstrap), decisions.md (what the catalogue asked and
                      what this project answered), phases/ (one doc per phase),
                      and archive/ (the shredded PROJECT-PLAN, immutable)
```

Modules/packages carry their own `README.md`
(`templates/README.package.template.md`). Root carries the trust assets:
`LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `THIRD-PARTY-NOTICES`.

## The capture streams

Each stream has a fixed home and a trigger. Fill it when the trigger fires
— not before, not at the end.

| Reader goal          | Stream                          | Home                        | Capture trigger                                    |
| -------------------- | ------------------------------- | --------------------------- | -------------------------------------------------- |
| Understand           | User guide                      | `docs/guide/`               | A user-facing capability ships                     |
| Understand + Maintain | Architecture map               | `docs/architecture.md`      | The module graph or a boundary changes             |
| Understand + Maintain | Module "what / why / surface"  | `<module>/README.md`        | A module is created or its public surface changes  |
| Maintain             | Contributor recipes             | `docs/dev/`                 | The **first** instance of a repeatable pattern     |
| Trust                | Decision rationale              | `docs/adr/`                 | An architectural decision is made                  |
| Reuse / Understand   | Reference (API, config)         | **Doc comments on public exports** → generated later | A public export is added or changed |

## Invariants

1. **Every doc has exactly one home.** Content needed in two places is
   written once and linked from the other — never duplicated. (Trust
   assets and policy files are linked to, not restated.)

   **The onboarding home is runner-agnostic.** `AGENTS.md` holds the content
   every agent needs; a harness-specific entry file (`CLAUDE.md` and its
   equivalents) is a **pointer plus a delta** — what is true for that harness
   and absent or different elsewhere — with an explicit precedence rule saying
   which wins on shared content. Two full copies drift, and the copy that
   drifts is always the one a given agent does not read.

   **Entry docs route by role before they route by content.** Some roles have
   *contradictory* onboarding: an independent reviewer must **not** read the
   tracker or the handover, because those carry the author's account and the
   value of the pass is that the reviewer has not been told what to conclude.
   So the role gate is the first thing in the file, before any instruction to
   read anything else — including before "read the other entry file in full".
   A reviewer routed through the author's onboarding on the way to its own
   brief has already lost the property it was launched for.
2. **Reference is doc-comment-first.** Public exports carry native doc
   comments (TSDoc / docstrings / rustdoc / DocC / godoc) as they are
   written — in-editor help now, the generated reference's source later.
   A public export without a doc comment is an **undocumented public
   surface: incomplete now**, not a to-do for the assembly phase.
3. **Every task records a documentation delta — or an explicit
   "no docs delta" with a one-line reason.** The delta is satisfied when,
   for each stream the change touched: affected module READMEs are
   current · new/changed public exports carry doc comments · shipped
   user-facing capability is reflected in `guide/` · a first-of-a-pattern
   has a `dev/` recipe · an architectural decision has an ADR. "No docs
   delta" (e.g. internal refactor, no surface/behavior change) is a valid,
   complete answer — but it must be stated, same discipline as the ADR
   line.
4. **ADRs are written when the decision is made,** from
   `templates/ADR.template.md`, numbered sequentially, with a status
   (Proposed / Accepted / Superseded-by-NNNN). A superseded ADR is never
   deleted or edited into agreement — it is marked and linked.
5. **Working docs hold their budgets** (tracker ~150 lines, handover
   ~100): they are paid for by every session that loads them. Trim by
   moving detail into archives (`docs/handovers/`, ADRs), never by
   omitting gotchas.
6. **Scope discipline:** the ongoing cost stays small — a README when a
   module is born, a doc comment when you export, a guide paragraph when
   a feature ships. No site, no polish, no tooling until assembly.
7. **A generated file and its freshness check ship in the same PR as the
   generator.** Not "later", not "recommended" — the generator is not done
   until CI can tell you the committed output is stale. A committed
   artifact nobody verifies drifts from its source, and every downstream
   claim about it becomes false without anyone finding out.
   *(Argus: the notices generator shipped in P0-11; the check arrived a
   year later. Two tasks in between deferred it as "known, revisit later" —
   that phrasing is the smell. The delay cost far more than the check
   would have: the committed file had to be reformatted after the fact and
   the script split in three, all of which is free on day one, when the
   file does not exist yet.)*
8. **A doc sentence claiming something is checked, enforced or gated must
   name the script path or CI job that does it.** If you cannot name one,
   the honest sentence is the aspirational form — "regenerate whenever the
   tree changes" — not the indicative "regenerated and diffed on every
   change". This is a **review obligation, not a CI gate**: recognizing a
   claim is a judgment call, so it lives on the completion checklist and in
   the reviewer's brief. Mechanize only the part that genuinely is
   mechanical — a CI step asserting that every script path and CI job name
   a doc cites actually resolves, which catches stale references but not
   invented ones.
   *(Argus: a README claimed notices were "regenerated and diffed on every
   change". Nothing diffed anything. It survived a year of reviews because
   nobody had a rule telling them to check.)*

## Routing quick reference

- *What is this module, why, what's its surface?* → the module's README.
- *How do the modules fit together?* → `docs/architecture.md`.
- *How do I use the product?* → `docs/guide/`.
- *How do I add another `<pattern>`?* → `docs/dev/`, first time the
  pattern is built.
- *Why is it done this way?* → an ADR.
- *What does this export do?* → its doc comment.
- *What changed / what's next / what hurt?* → tracker and handover.

## Assembly phase (what this feeds)

The eventual docs site does **not** write documentation from scratch:
module READMEs + architecture.md → architecture section · doc comments →
generated API/config reference · `guide/` → user guide, edited ·
`dev/` → contributor guide · `adr/` → decision index. If every stream was
fed along the way, assembly is editing and wiring — not remembering how
the system was built.
