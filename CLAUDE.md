# CLAUDE.md — the assurance playbook

**Read [AGENTS.md](AGENTS.md) now, in full, and follow it.** It is the onboarding
home for any agent working on this repository. This file is a pointer plus the
Claude Code delta; **where the two disagree on shared content, AGENTS.md wins.**

## The delta

- **The skill has two copies and only one of them runs.** The canonical copy is
  `runners/claude/skill/bootstrap-assurance/SKILL.md`; the installed copy at
  `~/.claude/skills/bootstrap-assurance/SKILL.md` is what a session actually
  loads. Edit the canonical one, then copy it across. `.githooks/pre-commit`
  runs `runners/claude/check-skill-sync.sh` on every commit here and fails when
  they disagree — it reports disagreement, not direction, so check which side
  holds the newer edit before overwriting either.

- **Arm the hook once per clone:** `git config core.hooksPath .githooks`.
  Committing the hook does not arm it, and it is repo-wide — it makes git ignore
  `.git/hooks/*` entirely.

- **`/bootstrap-assurance` runs in the *target* project, never here.** It walks
  `BOOTSTRAP.md` in a repo being set up. Running it in this repo would be
  bootstrapping the playbook onto itself, which AGENTS.md explains is mostly
  wrong.

- **Permission-prompt descriptions:** read-only commands get one short clause;
  state-changing ones get `action + exact target — why — scope & how to undo`.
  Split compound commands so each prompt is one decision.

- **Blast radius:** anything under `.claude/` here is local developer
  configuration. It runs on this machine, in this harness, and nowhere else —
  not in CI (there is none), and not for an agent on another harness. It
  substitutes for no gate.

*Nothing else belongs in this file.* A rule that applies to any agent that is not
Claude Code belongs in [AGENTS.md](AGENTS.md) — this is the one no other harness
reads.
