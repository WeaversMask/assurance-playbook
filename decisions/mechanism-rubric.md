# The mechanism rubric

> How to evaluate a tool the playbook has never heard of, against a gate's
> invariants. This replaces the per-language tool table that used to end
> `policies/quality-gates.md`: a table cannot answer for a tool nobody has added
> to it yet, and it rots between the day it is written and the day it is read.
> A rubric does not.

Every gate in `BOOTSTRAP.md` Phase 2 is chosen by scoring candidate mechanisms
against the seven criteria below. Score them **out loud**, in the bootstrap
record — the scoring is the evidence that a mechanism was chosen rather than
recognised.

## The seven criteria

| # | Criterion | Rule |
| --- | --- | --- |
| 1 | Does it see the whole graph **at its declared scope**? | **must pass** |
| 2 | Does it fail closed on unknowns? | **must pass** |
| 3 | Can it go inert — measure nothing and pass? | may fail **only** with a declared arming condition; **never** for a safety-class gate |
| 4 | Does its failure output name itself? | **must pass** |
| 5 | Can its policy live outside its own config? | must answer; a "no" is a recorded deviation |
| 6 | What is its probe command, and how is a negative result recorded? | **must answer** |
| 7 | What does it *not* check? | **must answer** |

### 1 — Whole graph, at its declared scope

The failure this catches is a tool that **sees less than it advertises**. A
"full history" scanner that scans `base..head`; a coverage run that measures the
built output instead of the source; a licence checker that walks the installed
directory and misses packages that did not install on this host.

**Scope is per gate, not universal.** A staged-content scan deliberately examines
staged content and is correct to do so — the layering is the point
(`policies/secret-scanning.md` invariant 1). The question is not "does it see
everything" but **"does it see everything it claims to, and does its name match
its scope?"** A job called *full history* that scans a range fails this criterion
whatever its exit code says.

Test it by planting the violation **outside** the range you suspect it really
scans. A violation inside the range fails correctly and tells you nothing.

### 2 — Fail closed on unknowns

A check that cannot evaluate must block. Missing binary, unreadable version,
subprocess error, unknown licence identifier, unparseable config: each blocks
with instructions, never a silent allow.

The subtle case is a tool that exits 0 when its own internals fail. Ask what it
does when the thing it shells out to errors — several do not notice.

### 3 — Can it go inert?

A gate whose target does not exist yet measures nothing and passes. A coverage
glob matching no files; a size budget whose target was never built; a rule set
with zero rules.

**Inertness is not disqualifying — silent inertness is.** A mechanism that can go
inert is acceptable when it **declares an arming condition** and says `DORMANT`
on every run until that condition appears (`policies/quality-gates.md`). If the
mechanism cannot report its own dormancy, wrap it in something that can.

**Never for a safety-class gate.** Secret scanning, identity and provenance do
not get a dormant state — a safety gate that cannot be armed blocks bootstrap
completion instead.

### 4 — Does its failure output name itself?

A block is not a pass, and a red job is not evidence unless it says which gate
went red. Chained hooks fail fast, so one broken gate masks every gate behind it;
a verification-matrix row whose observed output names a different gate is a fail,
not a pass.

Ask: if this fires inside a chain of five, will the person reading the output
know which of the five spoke?

### 5 — Can its policy live outside its own config?

The pattern this serves: **policy data lives in one machine-readable place, tool
configs are projections of it, and a check fails when they disagree.** One table,
two consumers, no drift. It is what makes a mechanism swappable — replace the
tool, keep the policy — and it is how the same gate carries different values in
different projects without the shape changing.

A tool whose policy can only live in its own config format is still usable. It
means the policy has one home and that home is the tool's config, which is a
recorded deviation rather than a defect — but it also means swapping the tool
later is a migration, not a substitution.

### 6 — The probe, and how a negative is recorded

**Every recommendation ships with a command that answers "is this available and
working here?"** — owned by the project, not inferred. Never `command -v <tool>`:
availability is settled by invoking the thing, because a resolvable path is not a
working CLI, and a tool can ship somewhere `PATH` does not look.

**A negative result is recorded as an event, never as a fact:**

> `probe <command> returned <result> on <date>`

never *"tool X is not available"*. This is the most expensively-learned rule in
the playbook. Three consecutive sessions recorded a tool as "not installed" in
their handovers while the binary sat working where the resolver looks; each
believed the previous handover, none had a cheap way to test it, and by the
fourth the option had left the option set entirely — at a cost of over a million
tokens spent on a workaround for a tool that was present the whole time.

The distinction matters because the two failures look identical in a handover: a
tool that is genuinely absent, and a probe that broke. A probe that fails for an
operational reason — a missing helper, a timeout, a permissions error — is **not
a negative result**, and recording it as one is the failure mode itself.

### 7 — What does it not check?

Publish the blind spot with the gate. Without stated blind spots **a list of
installed gates reads as coverage**, and a bootstrap summary is exactly where
that misreading happens.

Every gate has one. A notices file proves attribution, not licence
compatibility. A secret scanner finds secret-*shaped* strings, so a credential
that looks like a word is invisible to it. A decision-trigger check cannot judge
whether a trigger is *firable*.

## The pass rule

**A candidate failing a must-pass criterion is not rejected outright — it is
wrapped, deviated, or rejected, and which one is a decision that gets recorded.**
Silence is not an option; seven observations and no verdict is where the tool
table already left people.

- **Wrap** — a thin script that satisfies the criterion and treats the tool as a
  component. This is criterion 5's pattern applied to a third-party tool: the
  wrapper owns the policy and the failure message, the tool does the measuring.
  **A wrapper is itself a gate and owes a negative fixture** proving it fires.
- **Deviate** — record the gap against the invariant, with the reason, in the
  bootstrap record. Available for **quality and budget** gates only.
- **Reject** — the only option when a **safety-class** gate's candidate fails a
  must-pass criterion. Safety requirements are not deviable at any tier; find
  another mechanism or do not ship the gate as satisfied.

## A worked scoring

A mechanism deliberately absent from `reference/node-pnpm/`, so this demonstrates
the rubric rather than restating the exhibit.

**Gate:** licence conformity (`policies/license-conformity.md` invariants 1–7).
**Stack:** Python, `uv`. **Candidate:** `pip-licenses`.

| # | Finding | Verdict |
| --- | --- | --- |
| 1 | Reads installed distribution metadata in the active environment. Misses platform-constrained wheels and unselected extras — packages the project still redistributes. | **fail** |
| 2 | Prints `UNKNOWN` for a package it cannot classify and exits 0. | **fail** |
| 3 | An empty environment yields an empty table and a clean exit. | **fail** |
| 4 | Output names the tool and the offending package. | pass |
| 5 | Accepts an allowlist from a file, so the policy can live in one reviewed place. | pass |
| 6 | `uv run pip-licenses --version`. A failure here is recorded as a dated probe result, not as "unavailable on this stack". | answered |
| 7 | Checks declared licence metadata only: not compatibility between licences, not vendored code inside a wheel, not licence text that disagrees with the declared identifier. | answered |

**Verdict: wrap.** Three must-pass failures, none of them a reason to reject —
they are all the same defect, which is that the tool answers "what is installed
here" while the invariant asks "what does this project resolve". A ~40-line
wrapper reads the lockfile for the resolved set, uses `pip-licenses` only for
licence metadata, fails closed on unknown or missing entries, and fails when the
lockfile holds a package the report does not. The policy lives in one module; the
tool's allowlist file is a projection of it; the wrapper fails on disagreement.
Criterion 3 is satisfied because the wrapper fails when the lockfile is present
and the report is empty, rather than passing over nothing.

The wrapper gets its own negative fixture: a lockfile entry with a denied licence
must make it exit non-zero and name the package.

**What the scoring did not settle**, recorded with the decision: whether a
licence declared in metadata matches the licence text actually shipped in the
wheel. Neither the tool nor the wrapper reads licence files. That is criterion
7's answer, and it belongs in the bootstrap summary next to the gate rather than
being discovered later.

## Two things the rubric will not do

- **It will not tell you a tool is good.** It tells you where a tool is
  *blind*, which is the question that matters when you are choosing something to
  rely on rather than something to use.
- **It will not keep itself current.** It is a set of questions, so it does not
  rot the way a tool table does — but a criterion that stops catching anything is
  a criterion to delete, not to keep for symmetry. Criteria earn their place by
  having failed a candidate.
