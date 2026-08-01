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

| File                                     | Demonstrates                                                                                                                              |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `hooks/pre-commit`                       | Staged-scope lint/format via lint-staged, then an **unskippable** gitleaks scan of staged content; per-gate `SKIP` for lint/format with normalization, `SKIP=gitleaks` rejected; **fail-closed toolchain floor check** |
| `hooks/pre-push`                         | gitleaks over the exact outgoing range, **no bypass**; conservative fallback range; **fail-closed on scanner operational errors** (a scan that never ran must not pass) |
| `hooks/commit-msg`                       | commitlint (conventional commits), skippable per-gate only                                                                                 |
| `ci/ci.yml`                              | The CI backstop layer: full-graph gates, full-history gitleaks, license job, review-evidence job (with bot-author exemption)                |
| `ci/mutation.yml`, `ci/release.yml`      | Mutation-testing job (Stryker) and changesets-based release flow                                                                           |
| `gitleaks.toml`                          | `useDefault = true` + narrowly-scoped fixture/lockfile allowlists                                                                          |
| `commitlint.config.cjs`, `lint-staged.config.mjs` | Commit-convention and staged-file gate config (note the shared `SKIP` normalization)                                              |
| `scripts/check-licenses.mjs`             | SPDX allowlist + named exceptions pinned to exact license strings, fail-closed on unknowns. The `.pnpm` virtual-store traversal is a **pnpm-specific workaround — port the policy, never the workaround** |
| `scripts/generate-third-party-notices.mjs` + `scripts/lib/` | Notices generation **plus the `--check` mode that verifies it** — `pnpm notices:check`, run by the `license` job. Compares only the host-independent part: packages declaring `os`/`cpu`/`libc` resolve differently per host, so they are inventoried below a marker the check stops at, and it fails closed if that marker is missing |
| `scripts/install-gitleaks.sh`            | Pinned scanner download with PATH fallback and fail-closed missing-binary behavior                                                         |

## Known gaps (policy leads, reference lags)

- **Identity gates** (identity-protection.md §2) are **not implemented
  here** — at copy time Argus enforced identity via repo-local git config
  only; the hook/CI verification layer is a pending Argus task. Build new
  projects to the policy, not to this gap.
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
