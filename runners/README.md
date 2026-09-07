# Runner-specific furniture

Everything in this directory is **specific to one agent harness**. Nothing here
is normative. The normative content is `policies/`; the installation order is
`BOOTSTRAP.md`; both are runner-agnostic and neither depends on anything in here.

## Which of this a project installs

Only the subdirectory for the harness the project actually uses. A harness given
another harness's configuration files reads them as instructions it cannot act
on, which is worse than not having them.

**Every project gets `AGENTS.md`** — the runner-agnostic onboarding home
(`policies/process.md`, `templates/AGENTS.template.md`). A harness file from this
directory is a **pointer plus a delta**: what is true for that harness and absent
or different elsewhere. Where the two disagree on shared content, `AGENTS.md`
wins. A project with one harness and no harness-specific rules needs nothing from
here at all.

## For a harness that has no directory here

Read the descriptions below by **what each asset does**, not by how it does it,
and decide whether your harness has an equivalent worth building. The mechanics
are not portable; the intent usually is. **Nothing here is required.** The gates
and the invariants come from `policies/` and `BOOTSTRAP.md`; a project that
instantiates those without adopting a single asset from this directory is
correctly set up.

## What is here

### `claude/`

| Asset | What it does | Worth porting? |
| --- | --- | --- |
| `skill/bootstrap-assurance/SKILL.md` | An invocable entry point that walks `BOOTSTRAP.md` end to end, stopping at the two HUMAN STOPs. Encodes the ordering rule and the hard rules so a fresh session cannot skip them. | Only if your harness has a named-procedure mechanism. Otherwise the maintainer runs `BOOTSTRAP.md` directly — it is written to be executable by a human. |
| `CLAUDE.template.md` | Pointer plus delta: routes by role, sends the reader to `AGENTS.md` in full, then adds only what is Claude-specific — permission-prompt phrasing, harness affordances, and the blast-radius note that `.claude/` is local config running nowhere else. | The *pattern* — one auto-loaded entry file that points at the shared home rather than copying it — ports to any harness that auto-loads something. The content does not. |
| `check-skill-sync.sh` | Fails when this repo's canonical skill copy and the installed one disagree. The skill has two copies and nothing else enforced their agreement; they drifted for a full release once. | Only if your harness also installs a copy of something this repo holds canonically. The rule it serves is `policies/documentation.md` invariant 1 — one home per doc — not `policies/quality-gates.md` invariant 11, which governs *generated* files and their generators. |

## Maintaining this directory

A new runner subdirectory is added when a project is bootstrapped for that runner
and the maintainer decides an asset is worth keeping. Adding one is not a reason
to change `policies/` or `BOOTSTRAP.md`: if a runner cannot satisfy an invariant,
that is a recorded deviation in the project, not a weakening of the invariant.
