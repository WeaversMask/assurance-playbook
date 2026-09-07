# CLAUDE.md — {{PROJECT}}

**Are you the independent reviewer?** Go to [AGENTS.md](AGENTS.md) and read its
first section, then stop. Your onboarding *negates* the sequence below — you must
not read the tracker or the handover.

**Otherwise: read [AGENTS.md](AGENTS.md) now, in full, and follow it.** It is the
onboarding home for every agent in this repo regardless of harness — session
start, the rules this project declares, how work is done, the context budget, and
the never-on-any-harness list. This file is a **pointer plus a delta**: only what
is true for Claude Code and absent or different elsewhere. **Where the two
disagree on shared content, AGENTS.md wins.**

---

## Permission-prompt descriptions

Every Bash `description` is written so the maintainer can decide from the prompt
alone:

- **Read-only** commands: one short clause.
- **State-changing** commands (installs, writes, pushes, deletions, downloads,
  config edits): `action + exact target — why / task ID — scope & how to undo`.
- Never vaguer than the real effect. Split compound commands so each prompt is
  one decision. Justification longer than ~2 sentences goes in chat *before* the
  call.

## Harness affordances this repo relies on

- **Search subagents** for broad sweeps, so only conclusions enter the working
  context — the context-budget rule in AGENTS.md assumes this is available.
- **Slash commands / skills** where this repo defines them: {{SKILLS}}.
- `{{HOOKS_NOTE}}`

**Blast radius:** anything in `.claude/` is *local developer configuration*. It
does not run in CI, it does not run for a contributor who has not installed it,
and it does not run for an agent on another harness. It substitutes for no CI
gate. Where a rule must hold for everyone, it belongs in a gate, and AGENTS.md
restates it by hand for the agents this configuration never reaches.

## Evergreen gotchas

{{GOTCHAS}}

---

*Nothing else belongs here.* If a rule applies to any agent that is not Claude
Code, it belongs in [AGENTS.md](AGENTS.md) — this file is the one no other
harness reads.
