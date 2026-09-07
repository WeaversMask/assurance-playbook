# {{PROJECT}} — what this setup gave you

> Written at Phase 5, committed to the repo, and linked from the bootstrap PR —
> the file is the home, the PR points at it. **Sections 1–4 at every tier;
> 5–7 from tier 2.** A tier-1 project that fills in all seven has not been
> proportionate, it has been thorough about the wrong thing.

## 1. What this project is, and the tier it chose

{{ONE_PARAGRAPH}}

**Tier {{TIER}}** — chosen because, asked *"if this code were wrong tomorrow, how
would you find out?"*, the answer was: {{TIER_ANSWER}}.
{{ESCALATOR_NOTE}}

Per module, where they differ: {{PER_MODULE_TIERS}}.

## 2. What was decided

| Entry | Outcome | Where |
| --- | --- | --- |
| {{ID}} | asked → {{ANSWER}} | {{ADR_OR_LINE}} |
| {{ID}} | default — announced, not asked | `docs/plan/decisions.md` |
| {{ID}} | **declined** — {{REASON}} | tracker row, **trigger:** {{TRIGGER}} |
| {{ID}} | n/a — {{REASON}} | tracker row, **trigger:** {{TRIGGER}} |

**Deferred** — not asked yet, and what will ask them:

| Entry | Waiting on |
| --- | --- |
| {{ID}} | {{CAPTURE_TRIGGER}} |

*A declined row is not a gap in this table; it is the table working. The
decision-trigger check fails the build when one of those triggers passes.*

## 3. The gates you now have

| Gate | Runs | Catches | **Does not catch** | State |
| --- | --- | --- | --- | --- |
| {{GATE}} | hook + CI | {{CATCHES}} | {{BLIND_SPOT}} | armed |
| {{GATE}} | CI | {{CATCHES}} | {{BLIND_SPOT}} | **DORMANT** — arms when {{CONDITION}} |

**The fourth column is not garnish.** Without stated blind spots a list of
installed gates reads as coverage, and this table is exactly where that
misreading happens. Every gate has one.

Verification matrix: {{MATRIX_PATH}}. It is **standing evidence** — gates added
later are proven the same way and recorded in the same file.

## 4. How work happens here

1. Sync, read the tracker, then the handover. Pick a task with no unmet
   dependencies; branch from `{{DEFAULT_BRANCH}}`.
2. **Commit** → {{HOOK_GATES}} run. Order is deliberate; the secret scan runs
   last so it sees post-formatting content.
3. **Push** → {{PUSH_GATES}} run over the outgoing range.
4. **PR** → {{CI_GATES}}.
5. {{REVIEW_STEP}}
6. **The maintainer merges.** Agents never do, never change visibility, never
   create repos.

**Only you can:** write `.gitleaks.local.toml` on each machine · create the
remote · change visibility · merge.

---

*Sections below are for tier 2 and above.*

## 5. What this costs

| | Cost | Basis |
| --- | --- | --- |
| Per commit | {{T}} | observed (Phase 3) |
| Per push | {{T}} | observed (Phase 3) |
| Per PR (CI) | {{T}} | observed once, one branch, cold cache |
| Per task overhead | {{T}} | **estimated** |
| Handover rotation | {{T}} | **estimated** |

**Read the basis column.** Phase 3 exercises each gate in a *failing*
configuration on a fail-fast chain, which measures time-to-first-failure, not the
pass-path cost quoted here — so Phase 3 also runs one clean pass and times that.
Anything marked estimated is a guess, and saying so is the point: a uniformly
precise-looking table is the one nobody questions.

## 6. Still open

| Row | Brings it back |
| --- | --- |
| {{DECLINED}} | {{TRIGGER}} |
| {{STANDING}} | `standing` — no trigger by choice, revisited on demand |

**Known limits of the thing that watches these:** it cannot judge whether a
trigger is *firable* — `P7-start` on a project that never reaches phase 7 parses,
resolves and never comes due — and `standing` is an escape hatch a row can hide
in forever. Both are mitigated only by being greppable.

## 7. If you moved tier

**Up to {{NEXT_TIER}}** would add: {{ADDS}}.
**Down to {{PREV_TIER}}** would drop: {{DROPS}} — and drop nothing from the
safety class, which is identical at every tier.

The tier row in the tracker carries its own trigger ({{TIER_TRIGGER}}). Re-read
the escalators then: a public repo, data you cannot regenerate, a second
committer, or output another system consumes each raise the floor regardless of
what the original answer was.
