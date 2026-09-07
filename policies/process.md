# Policy: Agentic Process

> How agents (and the maintainer) pick up work, execute, review, and hand
> off. Fully stack-agnostic. The templates referenced here live in
> `templates/`.

## Repo furniture every project gets

- `AGENTS.md` at root: the onboarding home every agent reads regardless of
  harness — role routing, session start, the rules this project declares, how
  work is done, context budget, and the never-on-any-harness list
  (`templates/AGENTS.template.md`).
- **Optionally**, one entry file per harness in use — a pointer plus that
  harness's delta, never a second copy (`runners/<harness>/`; for Claude Code,
  `runners/claude/CLAUDE.template.md`). A project with one harness and no
  harness-specific rules needs none of these.
- `docs/IMPLEMENTATION.md`: living tracker — current phase, in
  progress, blocked, recently completed, open decisions
  (`templates/IMPLEMENTATION.skeleton.md`).
- `docs/HANDOVER.md` (~100-line budget) + `docs/handovers/` archive.
- The full documentation layout and capture streams —
  [documentation.md](documentation.md).
- Task/PR/handover/ADR templates from `templates/`.

## Session onboarding (every session)

1. **Sync before reading:** switch to the default branch and pull
   fast-forward only — the tracker/handover on a stale branch mislead.
   Check whether the previous session's PR merged.
2. Read the tracker, then the handover, then only the docs the tracker
   names as active. **Load nothing else preemptively** — extra files
   pollute context and slow decisions.
3. Pick a task with no unmet dependencies; mark it in progress in the
   tracker; branch from the default branch (`<task-id>-<slug>`).

## Context budget (user-enforced)

- At **~50% context used:** finish the current commit, update the
  handover, stop cleanly.
- **Never start new work past 70%** — rotate the handover instead.
- Prefer tasks that fit one session. Broad searches go through a search
  subagent so only conclusions enter the working context.

## During execution

- Small conventional commits; tests before every commit.
- One task = one branch = one PR. Plan/doc changes other tasks depend on
  land first as their own small PR — never buried in a feature branch.
- Blocked → document blocker in the task file, mark tracker, pick up other
  work. Decision needed → ADR draft + "Open Decisions" entry, keep moving.
- **Agents may push branches and open PRs. Agents never merge — the
  maintainer does.** Agents never change repo visibility
  ([identity-protection.md](identity-protection.md)).

## Permission-prompt descriptions

Write every shell-command description so the maintainer can decide from the
prompt alone:

- **Read-only:** one short clause.
- **State-changing:** `action + exact target — why / task ID — scope & how
  to undo`.
- Never vaguer than the real effect; split compound commands so each prompt
  is one decision; justification longer than ~2 sentences goes in chat
  before the call.

## Independent review (every PR, mechanically enforced)

A fresh-context agent reviews the diff before merge is requested. CI fails
any non-draft PR without review evidence — doc-based process gates fail
under momentum; only mechanical ones hold. Tiered by diff risk:

- **Light** — docs/config-only, no executable logic: bugs-only findings +
  verdict as an `## Independent review` block in the PR description.
- **Full packet** — executable logic or security-relevant behavior:
  risk-ranked findings, acceptance-criteria mapping, and "what to manually
  verify in <10 min", posted as an `## Independent review packet` comment.

Reviewer brief (both tiers): review the diff, not the repo; don't re-run
verification the author documented (spot-check at most one); spend budget
on paths the author did *not* exercise. **Model diversity:** prefer a
reviewer from a different model family than the author; default mid-tier,
escalate model class for domain core, adapter boundaries, and releases.

## Task completion checklist

- [ ] Acceptance criteria met
- [ ] Full-graph gates clean at repo root (lint, typecheck, build, test)
- [ ] Coverage floor met on new code
- [ ] **Documentation delta recorded — or an explicit "no docs delta" with
      a one-line reason.** Streams, homes, and the normative definition:
      [documentation.md](documentation.md). The forced conscious decision
      is what makes docs accumulate; a soft reminder does not.
- [ ] Independent review evidence on the PR (tier per diff risk)
- [ ] PR opened from the template, task ID linked
- [ ] Tracker updated; handover rewritten for the next picker

## Handover rotation

After every significant task and always at phase boundaries: snapshot the
current handover into `docs/handovers/`, rewrite `HANDOVER.md` fresh from
the template, commit both in the task's PR. Budget ~100 lines — trim by
moving detail into the archived snapshot, never by omitting gotchas.

## Escalation to the maintainer

Escalate (as an "Open Decisions" tracker entry with a recommendation, then
pick up other work) when: a decision affects more than one module's public
API · an ADR conflicts with a new requirement · tests fail in a way that
suggests a design issue · effort exceeds 2× the estimate · a new external
dependency is being considered · a new risk emerges.

## Parallel lanes (multi-agent)

Two writer agents only when their declared file sets are disjoint, declared
up front in each task file. Shared tracker files are updated by whichever
PR merges first; the other lane rebases. Fresh-context *reviewer* agents
are always allowed.
