# decisions/

The third kind of content in this playbook.

| | |
| --- | --- |
| `policies/` | **What must always be true.** Normative, stack-agnostic. |
| `decisions/` | **What a project must choose.** Variable, with defaults. |
| `reference/` | **How one stack did it.** An exhibit. |

`policies/` says a project's dependencies carry acceptable licences. `decisions/`
asks which licences, scoped how, with notices covering what. The invariant does
not change per project; the answer always does.

## The two files

- **`catalogue.md`** — 22 entries. The questions Phase 0 asks, in order.
- **`mechanism-rubric.md`** — how Phase 2 scores a tool the playbook has never
  heard of, with a pass rule and a worked example.

## How an entry fires

    tier >= entry.tier  AND  applies(project)

Two axes, because they are two different questions and running them down one
axis was wrong. **Tier** scales with how silently the project fails. **Applies**
scales with what the project actually contains — asking a single-file project
about module boundaries is noise at every tier.

Applicability comes in two classes, because **Phase 0 runs before `git init`**:

| Class | Test | When false |
| --- | --- | --- |
| **Phase-0-evaluable** | answerable from the maintainer's answers, the stack, or a project plan — pseudonymity, visibility, package manager, dependencies present, whether a remote exists, asset classes | **an `n/a` row with a real trigger** |
| **Deferred** | a fact about code that does not exist yet — module count, a generator added later, a forbidden category, a test suite | **no row.** The entry attaches to a documentation capture trigger and is asked when the shape appears |

A question that *cannot yet be evaluated* is not the same as one *evaluated and
found not to apply*. Only the second earns a row, and inventing an `n/a` row for
the first would need a trigger the vocabulary deliberately cannot express.

## Three outcomes, all recorded

| Mode | When | What it writes |
| --- | --- | --- |
| **Asked** | a real choice exists here | the answer |
| **Announced + recorded** | a default with no realistic alternative for this project | `default — announced, not asked` |
| **Not applicable + recorded** | a Phase-0-evaluable test fails | `n/a — <reason>` plus a trigger |

**An announced default is not a recorded decision unless it is written down.** Six
months later nobody can tell an inherited default from a chosen one, and the
forcing function of this whole catalogue is the recording, not the choice.

Deferred entries produce a line in a **Deferred** list rather than a row.

## Where answers live

- **Took the default** → one line in `docs/plan/decisions.md`: id, answer, link.
  It restates no rationale, so it cannot drift on wording.
- **Diverged** → an ADR. This is where the reasoning goes.
- **Carries a trigger** — declines, `n/a` rows, and the tier itself → the
  tracker's **Open decisions** table, which is the one artifact the
  decision-trigger check reads. Three documents with triggers and one check
  reading them is how a check ends up deleted.

## Drafting rules

- **Two small decisions beat one convoluted one.** Merge entries only when one
  genuinely cannot be answered without the other.
- **An entry has its own default, its own how-to-tell test, and its own decline
  path with a firable trigger. Failing *any* of the three makes it a
  sub-question.** The copyright-holder string has a default and a test but no
  independent decline — a `LICENSE` needs a string — so it lives inside the
  licence entry.
- **Budget: ~400 lines, ~18 per entry.** An entry needing more is an ADR-shaped
  thing. The budget exists because a 22 × 9 grid otherwise outgrows the entire
  policy set, which is accretion arriving through the back door.
- **A criterion or field that has never changed an answer is deleted**, not kept
  for symmetry.
