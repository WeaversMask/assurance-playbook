# BOOTSTRAP — Instantiating the Assurance Playbook in a New Project

> Written to be executed by a Claude Code agent (via the
> `/bootstrap-assurance` skill) or by the maintainer manually, inside the
> new project's repo. The policies in `policies/` are the normative
> content; this file is the installation order. **Do not copy the
> `reference/node-pnpm/` files blindly** — they are one stack's worked
> example; derive mechanisms for the target stack from the policies and
> use the reference to see what a complete instantiation looks like.

## Phase 0 — Maintainer inputs (STOP and ask; do not guess)

Collect before touching anything:

1. **Project name** and short description.
2. **Stack** (language, package manager, test runner) — detect from the
   repo if it exists, confirm with the maintainer.
3. **Public identity decision** ([identity-protection.md](policies/identity-protection.md)
   §8): reuse the existing persona or a fresh one? Which
   name + noreply email will this repo commit as?
4. **Project license** and copyright holder string, and any adjustments to
   the starting SPDX allowlist
   ([license-conformity.md](policies/license-conformity.md) §1).
5. **Coverage floors** (default 85% line / 80% branch) and any gate the
   maintainer explicitly waives at bootstrap (record the waiver).

## Phase 1 — Repo foundation

1. If the repo doesn't exist: `git init` — **fresh history, never a fork
   or clone of a private repo**. If it exists: verify no private-repo
   history was carried in.
2. Set **repo-local** git identity to the declared public identity.
   Verify: `git config user.email` inside the repo.
3. `.gitignore`: env files, local databases, IDE workspace files, build
   outputs, the local scanner-patterns file (`.gitleaks.local.toml`),
   local tool binaries.
4. `LICENSE` + manifest license field, agreeing with each other.
5. Process furniture from `templates/`: `CLAUDE.md` (from
   `CLAUDE.template.md`, placeholders filled), `docs/IMPLEMENTATION.md`
   (from the skeleton), `docs/HANDOVER.md`, and the full documentation
   layout from [documentation.md](policies/documentation.md)
   (`docs/handovers/`, `docs/adr/`, `docs/guide/`, `docs/dev/`,
   `docs/architecture.md` stub), plus task/PR/handover/ADR templates.
   Trim anything inapplicable — the policies are the invariant, the file
   layout is convention.

## Phase 2 — Gates, in dependency order

For each gate: choose the stack-native mechanism *against the policy's
invariants*, wire it locally (hook) **and** in CI, then record it in the
verification matrix (Phase 3).

1. **Hook manager** appropriate to the stack (husky, pre-commit, lefthook,
   or plain `core.hooksPath`).
2. **Secret scanning** ([secret-scanning.md](policies/secret-scanning.md)):
   pinned scanner install (fail-closed when missing) · pre-commit staged
   scan · pre-push outgoing-range scan (fail-closed on operational
   errors) · CI full-history scan · shared config with fixture allowlist.
3. **Identity gates** ([identity-protection.md](policies/identity-protection.md)
   §2): pre-commit config check · pre-push author/committer range check
   with bot allowlist · CI backstop. Single source of truth for the
   declared identity.
4. **Commit conventions:** commit-msg hook enforcing conventional commits.
5. **Quality gates** ([quality-gates.md](policies/quality-gates.md)):
   lint + format · strict type/static check · tests + coverage floors with
   explicit-exclusions config · full-graph root commands · CI jobs for all
   of it · scoped-skip support with the `--no-verify` ban documented.
6. **License + supply-chain gate**
   ([license-conformity.md](policies/license-conformity.md)): full-tree
   license check (local script + CI job), fail-closed · allowlist +
   named-exceptions in one reviewed place · notices generation wired to
   dependency changes · minimum-release-age and install-script controls
   where the package manager supports them (record a deviation where it
   doesn't).
7. **Review-evidence CI gate** ([process.md](policies/process.md)): fail
   non-draft PRs lacking the `## Independent review` block/packet.

## Phase 3 — Prove every gate by breaking it (mandatory)

A gate that was never seen to fail is decoration. For each installed gate,
introduce a deliberate violation, observe the failure, revert, and record
the result in a **verification matrix** in the bootstrap PR description:

| Gate               | Deliberate violation                                   | Expected failure               |
| ------------------ | ------------------------------------------------------ | ------------------------------ |
| Secret / commit    | Stage a synthetic `ghp_`-shaped token outside fixtures | pre-commit blocks              |
| Secret / push      | Commit it with `SKIP=gitleaks`, attempt push           | pre-push blocks                |
| Identity / commit  | `git -c user.email=wrong@example.com commit`           | pre-commit blocks              |
| Identity / push    | Commit with wrong author via env override, push        | pre-push blocks                |
| Commit message     | `git commit -m "bad message"`                          | commit-msg blocks              |
| Lint / types       | Introduce a violation, run root gate                   | non-zero exit                  |
| Coverage           | Add uncovered logic, run coverage gate                 | floor breach fails             |
| License            | Add a GPL-licensed dev dependency                      | gate blocks, names the package |
| Fail-closed paths  | Remove/rename the scanner binary, attempt commit       | block with instructions        |
| CI layers          | Push a branch exercising one violation per CI job      | jobs fail as expected          |

Every row gets: pass/fail, and a one-line note. **A row that cannot be
made to fail means the gate is not installed, whatever the config says.**

## Phase 4 — Human-only steps (list them, never do them)

Present these to the maintainer as a checklist and stop:

1. Create the **local personal-identifier patterns file**
   (`.gitleaks.local.toml` from `templates/gitleaks.local.example.toml`)
   — it contains the identifiers being protected; an agent must never
   write or be told its contents.
2. Create the remote repo (private) and push; enable branch protection
   with the CI jobs as required checks.
3. Review the named-exception ledger and any recorded deviations/waivers.
4. If/when the project goes public: `templates/go-public-checklist.md`,
   maintainer-only.

## Phase 5 — Record

- Bootstrap PR includes: the verification matrix, recorded deviations
  (invariants not natively satisfiable, with reasons), and the identity/
  allowlist decisions from Phase 0.
- First `docs/HANDOVER.md` entry: what was installed, what was waived,
  what's pending from Phase 4.
- Port any *new* invariant discovered during bootstrap back to this
  playbook (policy first, reference later).
