# AGENTS.md — {{PROJECT}}

The onboarding home for every agent working in this repo, whatever harness it
runs on. Harness-specific files (`CLAUDE.md` and friends) are **pointers plus a
delta** — what is true for that harness and absent or different elsewhere. **If a
harness file and this one disagree on shared content, this file wins.**

---

## Are you the independent reviewer? Read this section, then stop

If your prompt contains a reviewer brief and a diff to review, you are the
review. Then:

- **Do not read `docs/IMPLEMENTATION.md` or `docs/HANDOVER.md`.** They carry the
  author's own account of what changed and what they verified. Your brief
  requires a fresh-context, diff-only pass, and its whole value is that you have
  not been told what to conclude. The "read these" instruction below is for
  agents doing **authoring** work.
- **Do not launch another review.** Whatever started you would start another,
  and that one would start another.
- **Do not write, stage, commit or push.** You are read-only. If you believe a
  file must change, say so as a finding.
- Review the **diff, not the repo**. Open a file beyond the diff only to settle a
  specific question the diff raises.
- {{PROJECT_RULES_THAT_OUTRANK_EVERYTHING}} — a violation of either outranks
  anything else you find.

Your brief is in `docs/plan/process.md`, under **Independent review**. Where a
runner script injects it, it is extracted from that file at run time so the brief
and the policy cannot drift.

**Everything below is for authoring agents.**

---

## Start here, every session

1. **Sync before reading:** `git switch {{DEFAULT_BRANCH}} && git pull --ff-only`.
   A stale branch carries a stale tracker and handover, which is worse than no
   tracker at all. Check whether the previous session's PR merged.
2. Read `docs/IMPLEMENTATION.md` (current state, Up next), then
   `docs/HANDOVER.md` (last session's context), then only the docs the tracker
   names as active. **Load nothing else preemptively.**
3. Pick a task with no unmet dependencies, mark it in progress, branch from
   `{{DEFAULT_BRANCH}}` as `<task-id>-<slug>`.

## What this project forbids

Rules this repo declares about its own code. Each is enforced mechanically where
it can be, and each mechanised one ships with a test proving it fires — which is
what lets a reviewer skip it and spend their budget on what only judgment can
decide.

{{DECLARED_RULES}}

*(Example shape: "nothing outside `src/adapters/` imports the driver — enforced
by `<rule>`, negative test at `<path>`." A rule with no mechanism is still worth
writing here; it becomes a line in the reviewer's brief instead.)*

## How work is done here

- **Sign-off runs at the repo root over the whole graph:** `{{ROOT_GATE_COMMANDS}}`.
  Filtered or single-package runs are for iteration only — they miss graph-level
  failures, which is exactly the class that reaches CI.
- Small conventional commits (`feat|fix|chore|refactor|docs|test`); tests before
  every commit.
- One task = one branch = one PR. Plan or doc changes other tasks depend on land
  first, as their own small PR — never buried in a feature branch.
- Blocked → record the blocker in the task file, mark the tracker, pick up other
  work. Decision needed → an ADR draft plus an **Open decisions** row with a
  trigger, then keep moving.
- **Agents may push branches and open PRs. Agents never merge** — the maintainer
  does. Agents never change repo visibility and never create public repos.

## Context budget

- At **~50% used:** finish the current commit, update the handover, stop cleanly.
- **Never start new work past 70%** — rotate the handover instead.
- Prefer tasks that fit one session. Broad searches go through a search subagent
  so only conclusions enter this context.

## Recording what you find out

- **A probe result is an event, not a fact.** Write `probe <command> returned
  <result> on <date>`, never "tool X is unavailable". A handover is where a false
  negative hardens into a fact that the next three sessions inherit, and a probe
  that broke for an operational reason is not a negative result at all.
- **An open decision names the event that will bring it back** — a task or group
  id, a phase boundary, an ISO date, or `standing`. A row whose trigger has
  passed fails the build ({{DECISION_CHECK}}).
- Every task records a documentation delta, or an explicit "no docs delta" with a
  one-line reason.

## Never, on any harness

- Commit with a personal identity, or put a personal identifier in file content —
  no personal emails, no absolute home-directory paths, no machine identifiers.
- Bypass the whole hook chain (`--no-verify` is banned). A scoped
  `SKIP=<gate>` with written justification, for the gates that permit it.
- **Skip the secret scan.** Not at any layer, not with any flag. A string that
  must legitimately be committed gets a reviewed allowlist entry in the committed
  config.
- Create, read, or ask about `.gitleaks.local.toml`. It is written by the
  maintainer, per machine, and gitignored. Its absence blocking commits is the
  feature.
- Change repo visibility, create a public repo, or push to a frozen archive.
