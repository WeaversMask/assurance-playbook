# Runner-specific furniture

Everything in this directory is **specific to one agent harness**. Nothing here
is normative. The normative content is `policies/`; the installation order is
`BOOTSTRAP.md`; both are runner-agnostic and neither depends on anything in here.

## Which of this a project installs

Catalogue entry **G2** ("which runner(s) will work in this project?") decides. A
project installs the subdirectory for the runner(s) it named and nothing else — a
harness given another harness's configuration files reads them as instructions it
cannot act on, which is worse than not having them.

**Every project gets `AGENTS.md`** (from `templates/AGENTS.template.md`)
regardless of runner. That is the home for onboarding content. A runner-specific
entry file is a **pointer plus a delta**: what is true for that harness and absent
or different elsewhere. Where the two disagree on shared content, `AGENTS.md`
wins.

## For a harness that has no directory here

Read the descriptions below by **what each asset does**, not by how it does it,
and decide whether your harness has an equivalent worth building. The mechanics
are not portable; the intent usually is. Nothing here is required — a project with
only `AGENTS.md` is correctly set up.

## What is here

### `claude/`

| Asset | What it does | Worth porting? |
| --- | --- | --- |
| `skill/bootstrap-assurance/SKILL.md` | An invocable entry point that walks `BOOTSTRAP.md` end to end, stopping at the two HUMAN STOPs. Encodes the ordering rule and the hard rules so a fresh session cannot skip them. | Only if your harness has a named-procedure mechanism. Otherwise the maintainer runs `BOOTSTRAP.md` directly — it is written to be executable by a human. |
| `CLAUDE.template.md` | The pointer-plus-delta entry file for this harness: sends the reader to `AGENTS.md` in full, then adds what only applies here (context-budget behaviour, permission-prompt phrasing, harness-specific gotchas). | The *pattern* ports to any harness with an auto-loaded entry file. The content does not. |
| `check-skill-sync.sh` | Fails when this repo's canonical skill copy and the installed one disagree. The skill has two copies and nothing else enforces their agreement; they drifted for a full release once. | Only if your harness also installs a copy of something this repo holds canonically. The general rule — invariant 11 — is that any duplicated file ships with a freshness check. |

## Maintaining this directory

A new runner subdirectory is added when a project is bootstrapped for that runner
and the maintainer decides an asset is worth keeping. Adding one is not a reason
to change `policies/` or `BOOTSTRAP.md`: if a runner cannot satisfy an invariant,
that is a recorded deviation in the project, not a weakening of the invariant.
