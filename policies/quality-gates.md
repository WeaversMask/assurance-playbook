# Policy: Quality Gates

> Stack-agnostic invariants. Mechanisms are chosen per project (see
> `BOOTSTRAP.md`); `reference/node-pnpm/` shows one full instantiation.

## Invariants

1. **Every PR passes, in CI:** lint, static type/consistency check, a full
   build, and the full test suite. Local hooks may run subsets for speed;
   CI always runs the whole graph and is the authority.
2. **Sign-off runs at the workspace root against the whole dependency
   graph.** Filtered/partial runs (single package, single target) are for
   iteration only — they bypass graph-level failures (Argus P1-02: a
   workspace dependency cycle reached CI exactly this way). "Done" is only
   claimed after a full-graph run.
3. **Coverage floor on changed code:** ≥85% line, ≥80% branch (adjust per
   project at bootstrap, then hold). Coverage cannot drop across a PR.
4. **Coverage exclusions are explicit and justified.** Generated code,
   type-only files, logic-free re-export barrels, and test fixtures may be
   excluded — each exclusion listed in the coverage config with a comment
   saying why. No blanket directory excludes.
5. **Conventional commits** (`feat|fix|chore|refactor|docs|test`), enforced
   by a commit-msg hook, not convention alone.
6. **No silent suppression.** Every disabled lint rule, ignored warning, or
   type-checker escape hatch carries an inline justification comment.
7. **Every gate skip is named, scoped, and justified.** Skips target one
   gate (`SKIP=<gate>` or equivalent), never the whole hook chain
   (`--no-verify` is banned). The justification goes in the commit message
   (or PR description for push-time skips).
8. **Pre-existing debt ratchets.** Where a gate is introduced into a repo
   that already violates it, the existing violation count is recorded and
   may never increase; new violations block immediately.
9. **Independent review evidence on every PR**, mechanically enforced: a CI
   job fails any non-draft PR that lacks the review block/packet. Review
   tiers and reviewer rules are in [process.md](process.md) — doc-based
   process gates fail under momentum; only mechanical ones hold.
10. **PR hygiene:** linked task ID in the description; tracker and handover
    files updated (see [process.md](process.md)).
11. **Every committed generated file has a CI freshness check, shipped in
    the same PR as its generator** ([documentation.md](documentation.md)
    invariant 7). Prefer a `--check` mode on the generator over
    `regenerate && git diff --exit-code` in the workflow: only the
    generator knows which parts of its output are reproducible, and putting
    that knowledge in a YAML `sed`/ignore list guarantees the two drift
    apart. A check mode must **never write**, and must **fail closed** when
    it cannot find what it expects to compare — comparing nothing must
    never read as clean.

12. **Every expected value declares where it came from, and a gate refuses the
    repo's own output as an expectation.** Coverage says a line executed; it
    says nothing about whether anything was *checked*. A suite of `assert
    true` calls reaches 100% and passes every invariant above it.

    The common form of this failure is the **snapshot**: a snapshot is the
    repo's own output pinned as an expectation, so the reflexive answer to a
    red one is "update the snapshot" — which makes it a test that cannot fail
    on purpose. The two kinds of fixture look identical sitting in one
    directory while demanding opposite responses to an identical red: for a
    fixture derived from an external source, "update the number" is always
    wrong and means the code broke its contract with that source; for one
    pinning the repo's own behaviour it is often right.

    So: every fixture value carries a **provenance** — `source` (came from
    outside this repo) or `chosen` (this repo produced it) — and the loader
    refuses a `chosen` value anywhere in an *expected* position. If both kinds
    are genuinely needed they live in separate directories with headers saying
    which is which, never interleaved: a directory silently holding both is
    worth the weaker of the two.

    **What this gate does and does not do.** It checks that a declaration
    exists and is consistent. It cannot check that a declaration is *true* — a
    fixture labelled `source` that actually holds this repo's output will pass.
    That is a review obligation, and stating it is the difference between a
    gate and a claim.

    *(Ask the question before the number: how does wrong code in this module
    fail, and what is the actual oracle? The floor in invariant 3 is a floor,
    not a defence. Raising it without an oracle produces coverage-shaped tests
    instead of correctness-shaped ones.)*

13. **A gate that can measure nothing declares what arms it, and says
    `DORMANT` until then.** Gates are installed before the code they govern —
    that is this playbook's own ordering rule — so at bootstrap a coverage
    glob may match no files, a size budget's target may not be built, and a
    rule set may govern nothing. Each of those is a green run over an
    unmeasured thing.

    Three states, not two: **armed · dormant · failed.** A dormant gate names
    its arming condition as data, not prose, and prints `DORMANT` on **every**
    run until the condition appears. Plain fail-closed is insufficient here:
    blocking on not-yet-existing source makes the gate un-installable, so it
    gets set aside "for later", and later does not come.

    **Two hard limits.**

    - **DORMANT is available to quality and budget gates only.** A
      safety-class gate — secret scanning, identity, provenance — that cannot
      be armed **blocks bootstrap completion**; it does not earn a dormant
      row. A layer that never fires is the failure
      [secret-scanning.md](secret-scanning.md) invariant 3 exists to prevent,
      whatever the reason it never fired.
    - **The transition is proven, not assumed.** A wrapper that prints
      `DORMANT` forever satisfies a check that only looks for the marker —
      the decoration problem reappearing inside the anti-decoration
      mechanism. Prove it with a temporary fixture: create the prerequisite,
      confirm the gate arms, break it deliberately, observe the failure,
      remove the fixture, confirm it returns to `DORMANT`.

    *Its blind spot:* arming arms the **gate**, not the **prose about the
    gate**. A comment explaining why something is dormant goes stale the
    moment it arms, and nothing catches that.

14. **A gate that can be silently narrowed owes a regression test.** Proving a
    gate once (bootstrap Phase 3) proves it was installed. It does not stop
    the next change from quietly shrinking what it covers — adding a skip for
    one more gate is three lines of shell, and without a test nothing outside
    that file would notice. Where a gate's *scope* is expressible — the set of
    skippable gates, the set of paths a rule covers, the set of jobs that
    resolve the graph without building — assert that set.

## Gate classes, and what each may bypass

Four classes, and the bypass policy is a property of the class rather than of
the gate:

| Class | Examples | Bypass |
| --- | --- | --- |
| **Safety** | secret scanning, identity, provenance | **none, at any layer.** Not skippable, not deviable, not dormant |
| **Quality** | lint, format, types, coverage, licence | scoped, named, justified (invariant 7) |
| **Budget** | review breadth, model class, agent count | a named opt-out environment variable |
| **Meta** | gates guarding the assurance layer itself — the decision-trigger check, a skippable-set assertion, an inertness check | **none.** A meta-gate is the thing that notices when another gate has been narrowed or forgotten, so a bypass on it hides the bypass it exists to catch. Skipping the assertion that guards the skip set is the shape of the problem |

*(A hook manager or a package manager is a **prerequisite**, not a gate: it
enforces nothing on its own and has no bypass policy to state.)*

The budget class exists because without a sanctioned valve, budget overruns get
taken unilaterally and invisibly. A wide review is a budget decision, not a
safety one, and conflating the two teaches people to route around the safety
rule when what they needed was the budget one.

**Every control states its blast radius.** A hook is local developer config: it
does not run in CI, it does not run for a contributor who has not installed it,
and it does not run for an agent on a different harness. A control whose scope
is not written down silently becomes fiction for the next person on a different
setup — so each one says which layer it covers and what it substitutes for
(usually: nothing).

## Policy in one place: source of truth → projection → cross-check

The pattern that makes a gate portable and a value project-specific at the same
time:

1. **The policy data lives in one machine-readable module** — the floors, the
   budgets, the allowlist, the module boundaries.
2. **Tool configs are projections of it**, generated or imported, never
   retyped.
3. **A check re-derives the policy from the tool's own output and fails on
   disagreement.**

Two tables that disagree fail as the *weaker* one, silently, which is why step 3
is not optional. Apply it to every gate whose policy is more than a flag: swap
the tool and keep the policy, or change the values without changing the shape.

## Enforcement layering

Every gate that can run locally runs in a git hook *and* in CI. The hook is
the fast feedback layer and may be skipped with justification (invariant 7);
CI is the backstop and is never skippable. A gate that exists only as
documentation is not a gate.

**Hooks and CI want opposite treatments, and the reason is attribution.** Hooks
chain and fail fast, so their *order* is correctness: reject retired bypass
flags before anything can act on one, check the toolchain floor before anything
that would crash cryptically below it, check identity before deciding a commit
may exist, run formatters before the secret scan so the scan sees
post-formatting content. CI goes the other way — **independent gates get
independent jobs, with no dependency edges between them.** Serialising them
saves little and destroys the property the verification matrix exists to
establish: when one job's failure masks four others, the matrix fills with rows
that were never really tested. Attribution is a first-class reason to split a
job, and the cheapest gate to attribute earns its own square.

## Fail-closed rule

A check that cannot evaluate must block, not pass. If the tool is missing,
its version is unreadable, or its subprocess errors, the gate fails with
instructions — never a silent allow.

**Distinguish "cannot evaluate" from "nothing to evaluate yet."** The first
blocks. The second is invariant 13's dormant state — but only for a quality or
budget gate, and only with a declared arming condition. A gate that cannot tell
the two apart must treat both as blocking. (Argus applies this to the hook
toolchain floor, the secret-scan layers, and the license gate; apply it to
every gate you build.)

## Choosing a mechanism

There is no table of tools here. There was one — five columns of linters and
test runners per language — and it could not answer for a tool nobody had added
to it, which is the question a project actually asks. It is replaced by
[`decisions/mechanism-rubric.md`](../decisions/mechanism-rubric.md): seven
criteria a candidate is scored against, a pass rule, and a worked scoring.

Score every gate's mechanism against it, out loud, in the bootstrap record. The
scoring is the evidence that a mechanism was **chosen** rather than recognised.

## Assertion quality

Coverage measures execution, not assertion. Mutation testing is the mechanism
that measures the second: it perturbs the code and asks whether any test
noticed. The reference has carried a weekly, report-only mutation workflow since
before this policy mentioned it — the reference leading the policy, which is the
inversion this repo's README says must not happen silently.

It is **report-only until a baseline settles**, and weekly rather than per-PR,
because it re-runs the suite once per mutant. Once the baseline is stable, set
the break threshold just below it so regressions fail rather than drift. Do not
install it on a project whose failure mode is loud: it is the most expensive
gate here per unit of assurance, and it earns its cost only where a wrong answer
is plausible and silent.

## The verification matrix is standing evidence

The matrix is not a bootstrap deliverable that stops being appended to. Gates
installed after bootstrap are proven the same way and recorded in the same file,
under their own section, or the claim "every gate here has been seen to fail"
quietly stops being true a week after Phase 3.

**Four row states**, and only the first three close a bootstrap:

| State | Meaning |
| --- | --- |
| **pass** | proven to fail on its own terms; observed output pasted |
| **fail** | could not be made to fail — the gate is not installed, whatever the config says |
| **dormant** | quality/budget gate, arming condition declared and not yet met; transition proven with a temporary fixture (invariant 13) |
| **deferred** | its prerequisite is a step the maintainer has not taken yet (a remote, for instance). Not a state a project ships in — bootstrap is incomplete until the row closes |

A row whose observed output names a *different* gate is a fail, not a pass.

## Proportionality: what scales with the tier

Assurance is spent in proportion to **how silently the thing fails** — not to
project size. The question is: *if this code were wrong tomorrow, how would you
find out, and how long would it take?* Answerable per module, and usually
different per module.

What scales:

- **which quality gates are installed** — a project whose failures are loud does
  not need coverage floors, a review gate, or a notices generator;
- **the values inside them** — floor heights, review escalation thresholds;
- **how many matrix rows must be proven.**

What does **not** scale, at any tier, for any project size:

- **the safety class.** Secret scanning, identity and provenance are identical on
  a two-file utility and a two-hundred-file monorepo. A leaked credential does
  not care how small the repo was.

The corollary for sizing work rather than gates: **never group work whose failure
is silent.** Grouping is a review-cost optimisation, and it is exactly wrong
where review is the only defence.
