# Reference implementation — Node 22 / pnpm / Turborepo (Argus)

Taken from the Argus monorepo (private, 2026-07-17). These files are
**exhibits, not a copy source**: they call pnpm scripts, paths, and package
names that don't exist outside Argus. Their value is showing what a
complete, battle-tested instantiation of each policy looks like — including
the fail-closed plumbing that a naive port would miss.

> **No longer a verbatim copy.** The two hooks have since been hardened
> here ahead of Argus: the secret scan is unskippable (secret-scanning.md
> invariant 3 — `SKIP=gitleaks` is rejected, not honoured), and a missing
> committed `.gitleaks.toml` is reported against itself instead of being
> misattributed to the local patterns file. Argus still carries the older,
> skippable hooks — see the known gaps below.
>
> **Three further corrections landed 2026-08-15**, all found by an
> independent review during a live port to a new project — each one a gate
> that could not do the job its name claimed:
>
> 1. The missing-local-config check matched the opt-out marker as a bare
>    substring, so a comment *mentioning* the marker disarmed it. Now
>    anchored to a standalone comment line (identity-protection.md 5a).
> 2. `ci.yml` scanned a commit range while calling itself a full-history
>    scan, because `gitleaks-action` only full-scans on `workflow_dispatch`
>    and `schedule`. Now runs `gitleaks detect --log-opts="--all"` directly.
> 3. The identity spec's pre-commit layer described checking
>    `user.email`/`user.name`, which misses `GIT_COMMITTER_EMAIL`. The
>    policy now requires checking author **and** committer idents.

| File                                     | Demonstrates                                                                                                                              |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `hooks/pre-commit`                       | Staged-scope lint/format via lint-staged, then an **unskippable** gitleaks scan of staged content; per-gate `SKIP` for lint/format with normalization, `SKIP=gitleaks` rejected; **fail-closed toolchain floor check** |
| `hooks/pre-push`                         | gitleaks over the exact outgoing range, **no bypass**; conservative fallback range; **fail-closed on scanner operational errors** (a scan that never ran must not pass) |
| `hooks/commit-msg`                       | commitlint (conventional commits), skippable per-gate only                                                                                 |
| `ci/ci.yml`                              | The CI backstop layer: full-graph gates, **genuinely** full-history gitleaks (run directly, not via the range-scanning action), license job, review-evidence job (with bot-author exemption). Note `types: [… ready_for_review]` on the `pull_request` trigger — without it a draft's green check survives onto the ready PR and the review gate is bypassed |
| `ci/mutation.yml`, `ci/release.yml`      | Mutation-testing job (Stryker) and changesets-based release flow                                                                           |
| `gitleaks.toml`                          | `useDefault = true` + narrowly-scoped fixture/lockfile allowlists                                                                          |
| `commitlint.config.cjs`, `lint-staged.config.mjs` | Commit-convention and staged-file gate config (note the shared `SKIP` normalization)                                              |
| `scripts/check-licenses.mjs`             | SPDX allowlist + named exceptions pinned to exact license strings, fail-closed on unknowns. The `.pnpm` virtual-store traversal is a **pnpm-specific workaround — port the policy, never the workaround** |
| `scripts/generate-third-party-notices.mjs` + `scripts/lib/` | Notices generation **plus the `--check` mode that verifies it** — `pnpm notices:check`, run by the `license` job. Compares only the host-independent part: packages declaring `os`/`cpu`/`libc` resolve differently per host, so they are inventoried below a marker the check stops at, and it fails closed if that marker is missing |
| `scripts/install-gitleaks.sh`            | Pinned scanner download with PATH fallback and fail-closed missing-binary behavior                                                         |

| `scripts/check-decisions.mjs`            | Decision-trigger gate: fails when an open decision's trigger has already passed. Fail-closed on a missing section, an unparseable table, zero rows, an unreadable phase, or a trigger resolving to no id |

## Known gaps (policy leads, reference lags)

- **`scripts/check-decisions.mjs` is not wired into anything here.** BOOTSTRAP Phase 2
  item 10 requires it in a hook **and** in CI; this exhibit ships the script and
  neither invocation, so the gate has never been seen to fail in the reference.
  It was exercised against fixtures before shipping, but a gate proven only by
  its author's fixtures is exactly what this playbook warns about — and this one
  had two silent passes found in review, both because the fixtures used a
  tracker shape the templates here do not produce. Wire it and prove it before
  treating this row as a worked example.

- **Identity gates** (identity-protection.md §2) are **not implemented
  here** — at copy time Argus enforced identity via repo-local git config
  only; the hook/CI verification layer is a pending Argus task. Build new
  projects to the policy, not to this gap. The invariant-2 spec was
  tightened on 2026-08-15 to require checking `GIT_AUTHOR_IDENT` **and**
  `GIT_COMMITTER_IDENT` at pre-commit; a first implementation built from the
  older wording checked only the author.
- **Argus now lags the three 2026-08-15 corrections above** (anchored
  opt-out marker, direct full-history CI scan, author+committer identity
  check), in addition to the unskippable-scanner rule below. Porting them
  across is a pending Argus task.
- **Argus lags the unskippable-scanner rule.** Its live `.husky/pre-commit`
  and `.husky/pre-push` still honour `SKIP=gitleaks`, and
  `docs/SECURITY-NOTES.md` still documents it as sanctioned with written
  justification. The hooks here are the corrected form; porting them back
  to Argus (hooks + SECURITY-NOTES + the CLAUDE.md skip rule, plus an
  allowlist entry for anything currently relying on the flag) is a pending
  Argus task. New projects get the corrected form from the start.

## Ecosystem gotchas worth carrying

- Worktrees share `core.hooksPath` → hooks execute from the primary
  checkout; anything per-checkout (identity, toolchain) must resolve per
  worktree.
- `license-checker` cannot follow pnpm's symlinked virtual store past
  direct dependencies — hence the per-directory union in
  `check-licenses.mjs` (verified empirically: 16 of 333 packages visible
  from the root without it).
- pnpm supply-chain controls live in `pnpm-workspace.yaml`
  (`minimumReleaseAge: 4320`, `allowBuilds` review ledger) — not copied
  here because the file is mostly workspace layout; see
  policies/license-conformity.md §Supply-chain.
- Hooks inherit the invoking shell's toolchain — the pre-commit Node-floor
  guard exists because a below-floor Node made the hook *itself* crash
  cryptically. Any stack with version-sensitive hook tooling needs the
  same guard.
