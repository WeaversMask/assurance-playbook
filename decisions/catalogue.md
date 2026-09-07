# The decision catalogue

22 entries. How they fire, what the three outcomes are, and where answers live:
[README.md](README.md). Work them in order from `BOOTSTRAP.md` Phase 0.

**Before the first question, say the cost of declining** — otherwise the check
that makes declining safe reads as a penalty for it:

> Anything you decline gets one row naming what brings it back. Decline nothing
> and the table is empty and costs you nothing. Decline something and a short
> check makes sure that row cannot be quietly forgotten. That check is the reason
> you are allowed to decline at all.

Each entry: **tier · class · applies when · default · alternatives · how to tell ·
consequences · probe · records as · blind spot.** `P0` = Phase-0-evaluable.

---

## T0 — What is the assurance tier?

**Tier —  · P0 · always.** Asked before everything, inline in `BOOTSTRAP.md`.

**The question.** *If this code were wrong tomorrow, how would you find out, and
how long would it take?* (1) it crashes or is obviously broken → **1**; (2)
someone notices eventually → **2**; (3) it looks right, is wrong, and gets acted
on → **3**. Answerable per module, which is usually the honest answer.

**Default 2**, for a maintainer who will not answer — most projects are mixed,
and 2 is the least-wrong guess. But an unanswered T0 is the one default worth
pushing back on: it scales everything else.

**The dial is detection latency, not severity.** A crash can be catastrophic and
still be tier 1, because you find out at once.

**Follow-up probe** *(this is what actually separates 1 from 3)*: does anything
downstream act on the output — a script, a spreadsheet, another service?

**Escalators**, because this is a self-assessment by someone who wants to start
building. `tier = max(self-assessment, floor)`:

| Fact | Floor |
| --- | --- |
| The repo will be public | ≥ 2 |
| It holds data it cannot regenerate | ≥ 2 |
| More than one person commits | ≥ 2 |
| Its output is consumed by another system | **3** |

Going lower is permitted and becomes a **recorded deviation with a reason**.

**Per module.** Project tier is the maximum and decides which entries are asked;
per-module tier scales values inside the answers. A module created later joins
the documentation capture trigger for *"a module is created or its public surface
changes"* — no new mechanism.

**Consequences.** Tier gates 13 of the 22 entries, the values inside several
more, which gates Phase 2 installs, and how many Phase 3 rows must be proven.
**It never scales the safety class.**

**Records as** a row in the tracker's Open decisions table — not `decisions.md`,
so the trigger check reads it. Trigger: an **ISO date** at tier 1 (no phases
exist yet) or a **phase boundary** at tier 2+.

**Blind spot** three of them: it is a self-assessment with incomplete escalators;
it is answered before the code exists, so the honest answer is available six
months later; and a module created between re-evaluations carries no tier until
the capture trigger fires.

---

## A — Identity and disclosure

### A1 — Is this project pseudonymous?
**Tier 1 · P0 · always.** Inline in `BOOTSTRAP.md`.
**Default** yes.
**⚠ Effectively irreversible after the first PR.** `refs/pull/*` survive history
rewrites, so changing your mind later means migrating to a fresh repo and
discarding every PR, review thread and issue link. Deciding at `git init` costs
nothing; deciding after PR #1 may cost the history. *This warning belongs here,
at the point of decision — never in an appendix.*
**Alternatives** no — which is legitimate and selects the opt-out marker in the
committed scanner config.
**How to tell** would linking this repo to your legal name cost you anything, now
or in five years? "Probably not" is a yes-to-pseudonymous answer, because the
cost of being wrong is asymmetric.
**Consequences** yes ⇒ you hand-write `.gitleaks.local.toml` before any commit
can land, and identity gates install at every tier · no ⇒ the marker goes in the
committed config as a standalone comment line, and never as prose mentioning it.
**Probe** none — a judgement.
**Records as** `AGENTS.md` plus a `decisions.md` line.
**Blind spot** provider web-UI merge commits are stamped with the account's
*profile display name*, not the noreply email. Keep the profile name
pseudonymous too, or this decision leaks through a channel it does not cover.

### A2 — Fresh persona, or one you already use?
**Tier 1 · P0 · applies when** pseudonymous.
**Default** fresh.
**Alternatives** reuse an existing persona.
**How to tell** reusing one links this project to the others under it — not to
you, but to each other. Would that linkage matter if any one of them were
deanonymised?
**Consequences** shared ⇒ one reputation, one blast radius · fresh ⇒ more
bookkeeping, independent failure.
**Records as** `decisions.md`; the identity itself goes in `AGENTS.md`.
**Blind spot** tooling fingerprints link projects too. A distinctive gate set is
itself a signature.

### A3 — Visibility now, and later?
**Tier 1 · P0 · always.**
**Default** private, with no plan to go public.
**Alternatives** private then public · public from the first commit.
**How to tell** answer for *later* as well as now — it is the later answer that
sets the escalator in T0 and decides whether the go-public checklist is live.
**Consequences** ever-public ⇒ tier floor ≥ 2, history must be clean from birth,
and the go-public checklist applies · public from day one ⇒ everything above,
immediately.
**Records as** `decisions.md`.
**Blind spot** "private forever" is a decision that gets revisited by
circumstance rather than by intent, which is why the tier row is re-evaluated on
its own trigger.

---

## B — Licensing

### B1 — Which licence covers what?
**Tier 1 · P0 · always.**
**Default** one licence, applied to everything.
**Alternatives** a licence per asset class — code, content and prose, binary or
data assets — each in its own file.
**How to tell** does this repo ship anything you did not write as code? Sample
data, prose, fonts, images, recorded fixtures. If yes, does the same licence you
want for the code actually make sense for it?
**Consequences** one licence ⇒ one `LICENSE`, done in a line · several ⇒ one file
per class, named so the boundary is legible, and the README says which covers
what. The manifest carries the **code** licence, since most express only one.
**Sub-question** the copyright holder string — for a pseudonymous project it
follows from A1/A2 and is recorded on this row rather than asked separately.
**Third-party material you ship but do not own is not a licensing choice at
all** — those terms bind whatever you pick, and they often constrain the
architecture. A cache can be a licence question before it is a performance one.
**Records as** ADR if not the default; `decisions.md` if it is.
**Blind spot** a licence file says what you grant. It says nothing about whether
you had the right to grant it.

### B2 — The dependency allowlist
**Tier 1 · P0 · applies when** the project has dependencies.
**Default** the starting SPDX set in `policies/license-conformity.md` invariant 1.
**Alternatives** add or remove entries, with sign-off.
**How to tell** run the gate once against your current tree and read what it
refuses. The list you need is usually the default plus nothing.
**Consequences** additions widen what enters the tree permanently; removals may
block an existing dependency, which is a finding rather than a nuisance.
**Probe** the licence gate itself, scored against the rubric — see
[mechanism-rubric.md](mechanism-rubric.md) for a worked example.
**Records as** `decisions.md`, or an ADR for any addition.
**Blind spot** the allowlist governs *declared* licences. It cannot see licence
text that disagrees with the declaration, or code vendored inside a package.

### B3 — Any allowlist entries scoped to part of the tree?
**Tier 2 · P0 · applies when** the project ships non-code assets or more than one
asset class.
**Default** no — the allowlist is global.
**Alternatives** entries scoped by path or file type.
**How to tell** is there a licence you would accept for one kind of artifact and
refuse for another? A font licence is the usual first case.
**Consequences** global ⇒ the whole tree runs at the laxest entry any single file
needed · scoped ⇒ the boundary is recorded with its reason, and the gate must
support path scoping (check before promising).
**Records as** ADR.
**Blind spot** a scope is only as good as the path pattern; a moved file silently
changes which rules apply to it.

### B4 — Notices scope
**Tier 2 · P0 · applies when** dependencies are redistributed.
**Default** every package in the resolved tree, derived from the lockfile.
**Alternatives** direct dependencies only · runtime only · no notices file.
**How to tell** does your generator read the lockfile, or the installed
directory? The second silently omits packages constrained by platform,
architecture or an unselected extra — which you still ship.
**Consequences** whole tree ⇒ regenerates on every lockfile change and owes a
freshness check · direct-only ⇒ faster and legally incomplete · none ⇒ defensible
only if you redistribute nothing.
**Probe** the generator's `--check` mode: it must exit non-zero on a stale file
and never write. No check mode is a finding.
**Records as** ADR if not the default.
**Blind spot** notices prove attribution, not compatibility. Whether two licences
in the tree can coexist is a different question with a different gate.

---

## C — Supply chain

### C1 — Intake controls
**Tier 2 · P0 · applies when** the package manager supports them.
**Default** refuse versions published less than ~3 days ago; deny install and
build scripts by default with a per-package review ledger.
**Alternatives** either control alone · neither, recorded as a deviation.
**How to tell** probe the package manager. If it supports both, taking the
default costs one config line and this is announced rather than asked.
**Consequences** release age ⇒ blocks the window in which malicious releases are
typically caught and yanked; urgent patches use a scoped, same-PR-removed
exclusion with the advisory cited · script denial ⇒ some packages need an
explicit reviewed allow, and the ledger entry *is* the review record.
**Probe** the package manager's own help output — recorded as a dated result.
**Records as** `decisions.md`, or a deviation if unsupported.
**Blind spot** neither control looks at what the code does. A package that waits
four days is not thereby safe.

---

## D — Code rules and structure

### D1 — What does this project forbid?
**Tier 1 · P0 · always.** The highest value-per-minute question here.
**Default** nothing declared.
**Alternatives** a list of "must never" statements.
**How to tell** most maintainers answer "nothing" and are wrong. Derive them:
what must never reach the client bundle? What may only be touched through one
module? What must never enter the repo at all? What did you have to fix twice?
**Consequences** each rule routes — mechanisable ⇒ a lint or boundary rule
**with a negative test proving it fires**; not mechanisable ⇒ a line in the
reviewer's brief. The negative test is what lets a reviewer skip the rule and
spend a finite budget on what only judgment decides.
**Records as** `AGENTS.md` (so an agent reads it *before* writing) plus the
gate itself. This is the cheapest place to assure code quality.
**Blind spot** a rule with no mechanism costs reviewer attention on every PR,
forever. Prefer three enforced rules to twelve written ones.

### D2 — Module boundaries
**Tier 2 · deferred · applies when** more than two modules exist.
**Default** none — any module may import any other.
**Alternatives** a declared "must never import" table.
**How to tell** is there a module you would be alarmed to see imported from a
particular place? That alarm is the rule.
**Consequences** declared ⇒ the architecture doc's table is the source of truth,
the boundary tool's config a projection of it, and each rule owes a negative test.
**Probe** does the tool resolve the import graph without building? If so it needs
a build step first, or a gitignored artifact reads as a violation.
**Records as** ADR.
**Blind spot** boundary tools see static imports. Dynamic resolution, string
paths and dependency injection go straight through.

### D3 — Generators added after bootstrap
**Tier 2 · deferred · applies when** a generator is added later.
**Default** every committed generated file gets its freshness check in the same
change as its generator.
**Alternatives** none — this is the invariant. The decision is *recognising* that
something you just added is a generator.
**How to tell** does a committed file get produced by running something? Notices,
generated configs, generated docs, compiled content.
**Consequences** Phase 2 already covers bootstrap-time generators unconditionally.
This entry exists so the obligation does not lapse the moment bootstrap ends —
"add the check later" is the follow-up that does not happen.
**Records as** the check itself; a `decisions.md` line only if the output is
deliberately gitignored instead, which owes no check.
**Blind spot** a `--check` mode written by the same hand as the generator shares
its blind spots. It catches staleness, not wrongness.

---

## E — Test strategy

### E1 — What is the oracle, per module?
**Tier 1 · P0 · always.** Asked **before** E2, because the floor is derived from
this answer rather than chosen alongside it.
**Default** none stated — which is the answer most projects give and the reason
this is asked.
**The question.** When a test says the output is right, right *according to
what*?
**Alternatives** an external source of truth · a consistency or metamorphic
relation · a differential comparison against a reference implementation · a
property (round-trip, idempotence, conservation) · a human reading it once,
recorded.
**How to tell** if the answer is "according to what the code produced", you have
a snapshot: the repo's own output pinned as an expectation, where the reflex
answer to a red is "update the snapshot" — a test that cannot fail on purpose.
**Consequences** every fixture value declares `source` or `chosen`, and a loader
refuses a `chosen` value in an expected position
(`policies/quality-gates.md` invariant 12).
**Records as** ADR where a module's oracle is non-obvious; `decisions.md`
otherwise.
**Blind spot** the gate checks that a declaration exists and is consistent, never
that it is *true*. A fixture mislabelled `source` passes. That is a review
obligation, and saying so is the difference between a gate and a claim.

### E2 — Coverage floors
**Tier 2 · P0 · always** (installs DORMANT where no source exists yet).
**Default** 85% line / 80% branch, uniform.
**Alternatives** tiered per module, matched to failure mode.
**How to tell** from E1 and T0's per-module answers. A module whose failure is
silent wants a higher floor — **but only where a real oracle exists.** Raising a
floor without one produces coverage-shaped tests instead of correctness-shaped
ones.
**Consequences** floors live in one module; the runner's config is a projection;
a second pass re-derives them from the report, because a runner cannot fail on a
floor that governs no files.
**Records as** ADR if tiered.
**Blind spot** coverage measures execution, not assertion. `assert true` reaches
100%.

### E3 — Mutation testing
**Tier 3 · deferred · applies when** a test suite exists.
**Default** not installed.
**Alternatives** weekly and report-only · per-PR with a break threshold.
**How to tell** only worth it where a wrong answer is plausible and silent — it
is the most expensive gate here per unit of assurance, re-running the suite once
per mutant.
**Consequences** report-only until a baseline settles, then set the threshold
just below it so regressions fail rather than drift.
**Records as** ADR.
**Blind spot** it measures whether tests notice a perturbation, not whether they
assert the *right* thing.

### E4 — A project-specific gate class
**Tier 2 · deferred · applies when** a category of thing must never enter the repo.
**Default** none.
**Alternatives** a provenance gate over the tree.
**How to tell** is there material — licensed course content, customer data,
third-party source — whose presence would be a problem independent of any other
rule?
**Consequences** this is a **safety**-class gate: no bypass, no dormant state, and
it blocks bootstrap completion if it cannot be armed.
**Records as** ADR.
**Blind spot** it matches what you told it to match. A renamed or reformatted copy
of the same material walks through.

---

## F — Enforcement shape

### F1 — Which gates run where
**Tier 2 · P0 · applies when** CI exists or is planned.
**Default** every gate that can run locally runs in a hook **and** in CI.
**Alternatives** hook only, recorded as a deviation, where no CI exists yet.
**How to tell** the hook is fast feedback and skippable with justification; CI is
the backstop and never skippable. A gate in only one of them covers only that
layer, and its blast radius says so.
**Consequences** hooks chain and fail fast, so their **order is correctness**;
CI wants the opposite — independent jobs, no dependency edges, so a failure names
its own gate.
**Records as** `decisions.md`; deviations as rows.
**Blind spot** a hook does not run for a contributor who never installed it, or
for an agent on another harness.

### F2 — Which gates are skippable
**Tier 2 · P0 · applies when** quality-class gates exist.
**Default** lint and format only, with justification in the commit message.
**Alternatives** a narrower set.
**How to tell** the skippable set is exactly the quality class. Safety gates are
never skippable and budget gates use a named opt-out variable instead.
**Consequences** the set is asserted by a test, because adding a skip for one
more gate is three lines and nothing outside that file would notice.
**Records as** `decisions.md`; the set itself in the hook and its test.
**Blind spot** `--no-verify` bypasses every hook at once and no hook can stop it.
That is a documented ban, not a gate.

### F3 — Budget gates
**Tier 3 · P0 · applies when** agent or model budget is being spent.
**Default** none.
**Alternatives** a named opt-out environment variable per budget control.
**How to tell** is there a control whose purpose is cost rather than safety —
review breadth, model class, agent count?
**Consequences** without a sanctioned valve, budget overruns get taken
unilaterally and invisibly, and people learn to route around the *safety* rule
when what they needed was the budget one.
**Records as** `decisions.md`, and the variable name in `AGENTS.md`.
**Blind spot** a named opt-out records that a budget decision was made, not
whether it was a good one.

### F4 — Review tier(s)
**Tier 2 · P0 · always.**
**Default** two tiers — light for docs and config, a full packet for executable
logic.
**Alternatives** a single lightweight tier · none.
**How to tell** the packet's cost is real and its value falls as mechanical gates
accumulate. A project with heavy gates can often justify one tier.
**Consequences** whichever is chosen, **a CI job fails any non-draft PR without
evidence** — doc-based process gates fail under momentum. Dropping the gate
entirely is a decision with a trigger, not a silent omission.
**Records as** ADR if not the default; the completion checklist and PR template
are trimmed to match.
**Blind spot** the gate checks that evidence *exists*. It cannot check that the
review was any good.

---

## G — Agents and runners

### G1 — Reviewer model-family diversity
**Tier 3 · P0 · applies when** more than one runner is available.
**Default** open — decided per session, not by habit.
**Alternatives** require a different family · same family is fine.
**How to tell** the argument cuts both ways and is computable per project: review
exists mainly to catch the one failure class nothing mechanical catches — a
plausible but false correction — and that is precisely what a same-family
reviewer agrees with. But the more gates you have, the less diversity buys.
**Consequences** whichever way, **name the reviewer and runner in the evidence**,
so "whichever was handy" is visible when it happens.
**Probe** the runner's own `--check`, never `command -v`. A negative is recorded
as `probe X returned Y on date Z`.
**Records as** a tracker row while open; an ADR when settled.
**Blind spot** diversity of model family is not diversity of training data.

### G2 — Which runner(s) will work in this project?
**Tier 1 · P0 · always.**
**Default** detected from the session, confirmed rather than asked.
**Alternatives** several · none decided yet.
**How to tell** which harness will a session actually run in? Answer for the ones
you expect, not every one that exists.
**Consequences** every project gets `AGENTS.md` regardless. Each named harness
additionally gets its entry file as a pointer plus delta from `runners/`. A
harness given another harness's configuration reads it as instructions it cannot
act on, which is worse than not having it.
**Records as** `decisions.md`; the furniture itself in Phase 1.
**Blind spot** a runner nobody named still runs. `AGENTS.md` is what it finds,
which is the whole reason that file is the home.
