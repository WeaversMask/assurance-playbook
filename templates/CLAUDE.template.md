# CLAUDE.md — {{PROJECT}} agent onboarding

**Start here every session:** sync first — `git switch {{DEFAULT_BRANCH}} && git pull --ff-only` (a stale branch carries a stale tracker/handover) — then read [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) (current state, Up Next), then [docs/HANDOVER.md](docs/HANDOVER.md) (previous session's context), then whatever active plan doc IMPLEMENTATION.md names. Load nothing else preemptively.

## Context budget (user-enforced — do not bypass)

- At **~50% context used**: finish the current commit, update `HANDOVER.md`, stop cleanly.
- **Never start new work past 70%** — rotate the handover instead (archive + rewrite).
- Prefer tasks that fit one session. Broad searches go through a search subagent so only conclusions enter this context.

## Permission-prompt descriptions

Write every Bash `description` so the maintainer can decide from the prompt alone:

- **Read-only** commands: one short clause.
- **State-changing** commands (installs, writes, push, deletions, downloads, config edits): `action + exact target — why / task ID — scope & how to undo`.
- Never vaguer than the real effect. Split compound commands so each prompt is one decision. Justification longer than ~2 sentences goes in chat _before_ the call.

## Best practices (hold these at all times)

- **Sign-off gates run at the repo ROOT before every push:** `{{ROOT_GATE_COMMANDS}}`. Filtered/partial runs are for iteration only, never sign-off — they miss whole-graph failures.
- **Independent review pass before requesting merge — never skip it.** Fresh-context agent, tiered by diff risk: light for docs/config-only, full packet for executable logic; mid-tier model by default, **escalated model for domain core / boundary code / releases**, cross-family reviewer preferred.
- **Secret scanning is layered — keep every layer intact:** pre-commit scans staged content, pre-push scans the outgoing range, CI scans full history. Skipping any local layer requires written justification.
- **Identity is gate-verified:** this repo commits only as `{{PUBLIC_NAME}} <{{PUBLIC_NOREPLY_EMAIL}}>` (repo-local git config + hooks + CI). Never commit with a personal identity; personal identifiers never appear in file content.
- Work through the full Task Completion Checklist (docs/plan/process.md) before calling a task done.

## Evergreen gotchas

- Never bypass all hooks at once (`--no-verify` is banned). Use a scoped `SKIP=<gate>` with written justification.
- Conventional commits only: `feat|fix|chore|refactor|docs|test`.
- Every task records a doc delta (or an explicit "no docs delta" + one-line reason).
- One task = one branch = one PR. Branch from `{{DEFAULT_BRANCH}}`; plan/doc changes other tasks depend on land first as their own small PR.
- Agents may push branches and open PRs. **Agents never merge — the maintainer does.**
- **Going public is maintainer-only, voluntary, unscheduled — never agentic.** Agents never change repo visibility or create public repos.
