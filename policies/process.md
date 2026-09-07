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

## Open decisions, and the triggers that reopen them

This is what makes "not now" a safe answer. A recommendation the maintainer
declines does not evaporate: it becomes a row naming the event that will bring it
back, and a gate fails the build when that event has already passed.

**Say the cost before the first question, not after the first decline.** Anything
declined gets one row. Decline nothing and the table is empty and costs nothing.
Decline something and a short check makes sure the row cannot be quietly
forgotten — that check is the reason declining is allowed at all. Stated
afterwards it reads as a penalty for declining; stated first it is a property of
the system.

1. **Every open row carries a trigger, and it is one of exactly four:** a **task
   or group id**, a **phase boundary** (`P2-start`, `P3-exit`), an **ISO date**,
   or **`standing`** — deliberately no trigger, revisited only on demand. A
   closed row needs none.

   The vocabulary is deliberately not extended. "When the first non-allowlisted
   dependency appears" is unfirable without the gate that was just declined, and
   an unfirable trigger is worse than no trigger because it reads as one. **A
   trigger must be evaluable by something the project already has.**

2. **Every trigger-bearing row lives in one place** — the tracker's Open
   decisions table — because that is the artifact the check reads. Defaults
   recorded elsewhere and decisions written up as ADRs do not carry triggers.
   A check that tried to keep three documents in agreement would fire on wording
   and be deleted within a month.

3. **A trigger that has passed fails the build.** Not a convention: the tracker
   said "reviewed before every merge" for months while two rows walked straight
   past their own triggers, and both were found by hand rather than by anything
   mechanical. **Elapsed time is not the measure — merges are**, because each one
   was a moment the rule above the table says the row should have been read.

4. **Fail closed on a missing section, an unparseable table, an unreadable
   current phase, and a trigger naming an id that resolves to nothing.** A typo'd
   id is a trigger that never fires. Detection is looser than parsing on purpose:
   anything that *looks* like a decision row and will not parse is reported, not
   skipped — otherwise the rows the parser cannot read are exactly the rows the
   gate never knows exist.

**Its stated limits**, which are real rather than oversights: it cannot tell
whether a closed row's answer is an actual answer; it cannot judge whether a
trigger is the *right* one, or even a firable one; and `standing` is an escape
hatch a row can hide in forever, mitigated only by being greppable.

## Independent review (every PR, mechanically enforced)

A fresh-context agent reviews the diff before merge is requested. CI fails
any non-draft PR without review evidence — doc-based process gates fail
under momentum; only mechanical ones hold. Tiered by diff risk:

- **Light** — docs/config-only, no executable logic: bugs-only findings +
  verdict as an `## Independent review` block in the PR description.
- **Full packet** — executable logic or security-relevant behavior:
  risk-ranked findings, acceptance-criteria mapping, and "what to manually
  verify in <10 min", posted as an `## Independent review packet` comment.

**Reviewer brief (both tiers).** Review the diff, not the repo. Do not re-run
verification the author documented — spot-check at most one — and **skip any rule
that ships with a negative test CI ran**: a lint rule, boundary rule or floor
with a committed fixture proving it fires is already evidenced, and re-deriving
that by hand is the reviewer's most wasted budget. Spend it on paths the author
did *not* exercise, and on the one question no gate can answer: **is there an
existing thing in this repo this should have reused, and is the simplest version
of this smaller?**

Watch for the failure class with no mechanical defence: a change that is
plausible, confident and wrong.

**Where a runner script injects this brief into a reviewer's prompt, it extracts
it from this file at run time rather than restating it.** N runners, one brief,
no drift — a brief pasted into a script diverges from the policy silently, and a
drifted reviewer brief is worse than none because it still looks authoritative.

**Model-family diversity is a decision this project records, not a rule this
policy imposes.** The argument cuts both ways and the balance is project-specific:
review exists mainly to catch the one failure class nothing mechanical catches —
a plausible but false correction — and that is precisely what a same-family
reviewer is likeliest to agree with. But the more gates a project has, the less
diversity buys, because everything else is already caught. Decide it per project
and write the answer down; "whichever was handy" is not an answer.

## Task completion checklist

> **This checklist is trimmed at bootstrap to the gates the project actually
> installed.** A project that installed no coverage gate must not carry a
> checklist demanding coverage: a process doc that disagrees with the gates is
> worse than no process doc, because it teaches people that the list is
> decorative. Where a line is dropped, the omission is a recorded decision, not a
> silent edit.

- [ ] Acceptance criteria met
- [ ] Full-graph gates clean at repo root (lint, typecheck, build, test)
- [ ] Coverage floor met on new code *(where a coverage gate is installed)*
- [ ] **Documentation delta recorded — or an explicit "no docs delta" with
      a one-line reason.** Streams, homes, and the normative definition:
      [documentation.md](documentation.md). The forced conscious decision
      is what makes docs accumulate; a soft reminder does not.
- [ ] Independent review evidence on the PR *(where a review gate is installed)*
- [ ] PR opened from the template, task ID linked
- [ ] Tracker updated; handover rewritten for the next picker

## Handover rotation

After every significant task and always at phase boundaries: snapshot the
current handover into `docs/handovers/`, rewrite `HANDOVER.md` fresh from
the template, commit both in the task's PR. Budget ~100 lines — trim by
moving detail into the archived snapshot, never by omitting gotchas.

**A probe result is written as an event, never as a fact about the world:**
`probe <command> returned <result> on <date>`, not "tool X is not installed".
The handover is where a false negative hardens — three consecutive sessions once
recorded a tool as unavailable while the binary sat working where the resolver
looks, each believing the last handover, until the option had left the option set
entirely and the session that inherited it spent over a million tokens working
around a tool that was present the whole time. A probe that failed for an
operational reason is **not** a negative result, and recording it as one is that
failure starting again.

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
