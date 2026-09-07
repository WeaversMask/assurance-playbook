# BOOTSTRAP — Instantiating the Assurance Playbook in a New Project

> Written to be executed by a Claude Code agent (via the
> `/bootstrap-assurance` skill) or by the maintainer manually, inside the
> new project's repo. The policies in `policies/` are the normative
> content; this file is the installation order. **Do not copy the
> `reference/node-pnpm/` files blindly** — they are one stack's worked
> example; derive mechanisms for the target stack from the policies and
> use the reference to see what a complete instantiation looks like.

## The ordering rule (read before starting)

Arming a fail-closed gate changes what the rest of this procedure is
able to do. From the moment the hooks are live, every commit runs the
gauntlet — including the commits that install the remaining gates and the
deliberate violations that prove them. Two consequences drive the phase
order below, and neither is optional:

- **Commit the foundation before arming anything** (Phase 1.7). That is
  the last commit that runs unhooked.
- **The gates cannot be proven until the local patterns file exists**
  (HUMAN STOP at the end of Phase 2). While `.gitleaks.local.toml` is
  missing, the hooks fail closed on *that* — masking every other gate and
  turning Phase 3 into a row of false passes. See the warning in Phase 3.

Two steps in this procedure only the maintainer may perform. They are
marked **HUMAN STOP** and sit where they are actually needed, not
collected at the end: an agent that runs past one produces an unprovable
install.

## Phase 0 — Maintainer inputs (STOP and ask; do not guess)

> If the maintainer supplies a project plan written from
> `templates/PROJECT-PLAN.template.md`, most of these inputs are already
> answered (stack in its header, dependencies/licenses in §4, coverage in
> §9, identity in §10) — **verify against the plan rather than re-ask**,
> and let its shred map (§14) drive what Phase 1's furniture is seeded
> with. Only genuinely missing or ambiguous items go back to the
> maintainer.

Collect before touching anything:

1. **Project name** and short description.
2. **Stack** (language, package manager, test runner) — detect from the
   repo if it exists, confirm with the maintainer.
3. **Public identity decision** ([identity-protection.md](policies/identity-protection.md)
   §8): reuse the existing persona or a fresh one? Which
   name + noreply email will this repo commit as?
4. **Is this project pseudonymous at all?** Decide now and record the
   answer in the project's CLAUDE.md. It is effectively irreversible
   after the first PR (invariant 7a): `refs/pull/*` survive history
   rewrites, so a later change of mind means migrating to a fresh repo
   and discarding every PR and review thread. A "no" here is legitimate —
   it selects the `assurance:no-local-identity-rules` opt-out in Phase 2
   — but it must be chosen, not defaulted into.
5. **Project license** and copyright holder string, and any adjustments to
   the starting SPDX allowlist
   ([license-conformity.md](policies/license-conformity.md) §1).
6. **Coverage floors** (default 85% line / 80% branch) and any gate the
   maintainer explicitly waives at bootstrap (record the waiver).

**Tell the maintainer now** that a pseudonymous project needs a
hand-written `.gitleaks.local.toml` before the gates can be proven (the
HUMAN STOP ending Phase 2). Flagging it here means it is ready when the
procedure reaches it, instead of stalling the run.

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
5. Process furniture from `templates/`: the runner entry file (for Claude
   Code, `CLAUDE.md` from `runners/claude/CLAUDE.template.md`, placeholders filled — including the pseudonymity
   decision from Phase 0.4), `docs/IMPLEMENTATION.md` (from the
   skeleton), `docs/HANDOVER.md`, and the full documentation layout from
   [documentation.md](policies/documentation.md) (`docs/handovers/`,
   `docs/adr/`, `docs/guide/`, `docs/dev/`, `docs/architecture.md` stub),
   plus task/PR/handover/ADR templates. Trim anything inapplicable — the
   policies are the invariant, the file layout is convention.
6. **Install the day-to-day policies into the repo** so sessions there
   never depend on this playbook being present: copy
   `policies/process.md` → `docs/plan/process.md`,
   `policies/documentation.md` → `docs/plan/documentation.md`, and
   `policies/quality-gates.md` → `docs/plan/quality-gates.md`, each
   trimmed to the target stack (drop the stack-mapping tables, keep the
   invariants). The templates and `CLAUDE.md` reference these
   `docs/plan/` paths. The other three policies (secret, license,
   identity) are installation-time guides — their product is the gates
   themselves; they stay in the playbook.
7. **Commit the foundation now**, before any gate is armed. This is the
   last commit that runs without hooks, and doing it here keeps Phase 2's
   install off the critical path of its own gates. Everything from Phase
   2 onwards is committed *through* the gates — which is the point.

## Phase 2 — Gates, in dependency order

For each gate: choose the stack-native mechanism *against the policy's
invariants*, wire it locally (hook) **and** in CI, then record it in the
verification matrix (Phase 3).

The order below is a dependency order, not a preference. In particular
the scanner **config** lands before the hooks that read it: a hook whose
committed config is missing reports the failure against the wrong file
(it greps that config for the opt-out marker), and the first run of a
fresh install is the worst possible time to debug a misattributed error.

1. **Secret-scanning config first**
   ([secret-scanning.md](policies/secret-scanning.md)): the committed
   config with its fixture allowlist, plus the committed absolute-home-path
   rule ([identity-protection.md](policies/identity-protection.md)
   invariant 5a). For a non-pseudonymous project (Phase 0.4), put the
   `assurance:no-local-identity-rules` marker comment in it now.
2. **Hook manager** appropriate to the stack (husky, pre-commit, lefthook,
   or plain `core.hooksPath`).
3. **Secret scanning layers**: pinned scanner install (fail-closed when
   missing) · pre-commit staged scan · pre-push outgoing-range scan
   (fail-closed on operational errors) · CI full-history scan · the
   missing-local-config check in both hooks.
4. **Identity gates** ([identity-protection.md](policies/identity-protection.md)
   §2): pre-commit config check · pre-push author/committer range check
   with bot allowlist · CI backstop. Single source of truth for the
   declared identity. **The reference does not implement these** (see its
   README's known-gaps section) — build them from the invariant 2 spec,
   and expect to write them from scratch rather than adapt an exhibit.
5. **Commit conventions:** commit-msg hook enforcing conventional commits.
6. **Quality gates** ([quality-gates.md](policies/quality-gates.md)):
   lint + format · strict type/static check · tests + coverage floors with
   explicit-exclusions config · full-graph root commands · CI jobs for all
   of it · scoped-skip support **for these gates only** — the secret scan
   is never skippable ([secret-scanning.md](policies/secret-scanning.md)
   invariant 3) — with the `--no-verify` ban documented.
7. **License + supply-chain gate**
   ([license-conformity.md](policies/license-conformity.md)): full-tree
   license check (local script + CI job), fail-closed · allowlist +
   named-exceptions in one reviewed place · notices generation wired to
   dependency changes · minimum-release-age and install-script controls
   where the package manager supports them (record a deviation where it
   doesn't).
8. **Review-evidence CI gate** ([process.md](policies/process.md)): fail
   non-draft PRs lacking the `## Independent review` block/packet.
9. **Freshness checks ship with their generators.** Anything installed
   above that generates a committed file (notices, generated configs or
   docs) gets its `--check`-style CI verification in this same phase
   ([quality-gates.md](policies/quality-gates.md) invariant 11) — never
   as a follow-up.

### HUMAN STOP — the local personal-identifier patterns file

Pseudonymous projects only; a Phase 0.4 "no" skips this via the opt-out
marker placed in Phase 2.1.

The maintainer creates `.gitleaks.local.toml` **by hand**, from
`templates/gitleaks.local.example.toml`. It contains the identifiers being
protected: **an agent must never write it, read it, or be told its
contents**, and it is gitignored (Phase 1.3).

Until it exists, the hooks fail closed — so this file gates the first
hooked commit, which means Phase 2's own work cannot be committed and
Phase 3 cannot prove anything. That block is the feature, not a
misconfiguration to work around, and there is **no flag that routes around
it**: the secret scan is unskippable at every layer
([secret-scanning.md](policies/secret-scanning.md) invariant 3), and the
hooks reject `SKIP=gitleaks` rather than honouring it. Waiting for the
maintainer is the only way forward, which is why Phase 0 warns them it is
coming.

Once the file exists, commit Phase 2's work. That commit is the first
real exercise of the gates.

## Phase 3 — Prove every gate by breaking it (mandatory)

A gate that was never seen to fail is decoration. For each installed gate,
introduce a deliberate violation, observe the failure, revert, and record
the result in a **verification matrix** in the bootstrap PR description.

> **A block is not a pass. The block must name the gate under test.**
> Hooks are chained and fail fast, so one broken gate masks every gate
> behind it: with `.gitleaks.local.toml` missing, `git commit -m "bad
> message"` is refused by the pre-commit missing-config check and
> commitlint never runs at all — an observer recording "commit blocked ✅"
> has proven nothing. This is the same blind spot invariant 5a exists to
> close (three healthy scan layers, no rule that could match), so do not
> reproduce it in the procedure that is supposed to catch it. Paste the
> **actual failure output** into the matrix and check that it came from
> the gate the row is testing.

### 3A — Local layers (after the Phase 2 HUMAN STOP)

| Gate              | Deliberate violation                                   | Expected failure   | Observed output (paste) |
| ----------------- | ------------------------------------------------------ | ------------------ | ----------------------- |
| Secret / commit   | Stage a synthetic `ghp_`-shaped token outside fixtures | pre-commit blocks  |                         |
| Secret / push     | Author the token commit with hooks off (see below), then push | pre-push blocks | |
| Bypass refused    | `SKIP=gitleaks git commit` on any change               | pre-commit blocks, says the scan cannot be skipped | |
| Identity / commit | `git -c user.email=wrong@example.com commit`           | pre-commit blocks  |                         |
| Identity / push   | Commit with wrong author via env override, push        | pre-push blocks    |                         |
| Commit message    | `git commit -m "bad message"`                          | commit-msg blocks  |                         |
| Local patterns    | Temporarily rename `.gitleaks.local.toml`, commit      | pre-commit blocks, names the missing file | |
| Committed config  | Temporarily rename `.gitleaks.toml`, commit            | pre-commit blocks, names *that* file, not the local one | |
| Lint / types      | Introduce a violation, run root gate                   | non-zero exit      |                         |
| Coverage          | Add uncovered logic, run coverage gate                 | floor breach fails |                         |
| License           | Add a GPL-licensed dev dependency                      | gate blocks, names the package | |
| Fail-closed paths | Remove/rename the scanner binary, attempt commit       | block with instructions | |

**The push rows need no real remote.** Push to a throwaway local bare repo
(`git init --bare /tmp/probe.git`) — the pre-push hook receives the same
ref lines either way, and takes its conservative new-ref range.

**Constructing the "Secret / push" case.** Pre-push exists to catch commits
the staged scan never saw, so proving it requires *making* such a commit —
and since the scanner is unskippable (invariant 3), the only way is to
author it with hooks disabled:

```sh
git -c core.hooksPath=/dev/null commit -m "probe: planted token"   # verification only
git push probe HEAD:refs/heads/probe                               # expect: pre-push blocks
git reset --hard HEAD~1                                            # revert immediately
```

This is the **one** sanctioned hook bypass in the whole procedure, and it
is not an exception to invariant 3 — it is how the test fixture for
invariant 1's pre-push layer gets built. It is confined to a pre-remote
repo, reverted in the same step, and never used to land work. If you find
yourself reaching for it outside this row, the answer is an allowlist
entry, not a bypass.

### 3B — CI layers (after Phase 4.1 creates the remote)

| Gate            | Deliberate violation                                                    | Expected failure                          | Observed output (paste) |
| --------------- | ----------------------------------------------------------------------- | ----------------------------------------- | ----------------------- |
| CI layers       | Push a branch exercising one violation per CI job                       | jobs fail as expected                     |                         |
| Secret / depth  | Plant a secret in an **old** commit, not at the tip, and push           | CI secret job fails                       |                         |
| Review / draft  | Open a draft PR with no review block, then mark it **ready for review** | review job re-runs on the ready PR and fails |                      |

The last two rows exist because the first one cannot catch either failure,
and both were live findings (2026-08-15):

- **Depth.** A violation planted in the branch's own commits is *inside* the
  range a range-scanning tool examines, so the job fails, the row passes, and
  the fact that CI never scans history stays invisible. Only an old commit
  distinguishes "scans this push" from "scans the repository"
  ([secret-scanning.md](policies/secret-scanning.md) invariant 1).
- **Draft → ready.** The review gate passes trivially on drafts by design, and
  the default `pull_request` event types omit `ready_for_review`. So a draft's
  green check survives onto the ready PR on the same SHA and the gate is
  bypassed with nothing to observe. Re-running the job by hand does not
  surface it either: a re-run replays the stored event payload, where the PR
  is still a draft. This row is the only thing that catches it — and note the
  bootstrap PR itself is opened as a draft, so the very first PR the gate
  judges is the one that exercises this path.

Every row gets: pass/fail, the observed output, and a one-line note. **A
row that cannot be made to fail means the gate is not installed, whatever
the config says** — and a row whose observed output names a different gate
than the one under test is also a fail, not a pass.

**A gate must be seen to fail on its own terms.** "The job went red" is not
the assertion; "the job went red *for the reason this gate claims to
enforce*" is. A gate that fails for an adjacent reason — a range scan
catching a tip-level secret while claiming to scan history, a job blocking on
a different gate earlier in the chain — is decoration wearing a passing row.

## Phase 4 — Remote, then the remaining human-only steps

Step 1 is a HUMAN STOP that unblocks the rest of Phase 3; the steps after
it are terminal. Present them as a checklist.

### HUMAN STOP — 1. Create the remote

The maintainer creates the remote repo (**private**) and pushes. Agents
never create repos, never change visibility, and never push to
retired/frozen archives ([identity-protection.md](policies/identity-protection.md)
invariants 6 and 7).

Then finish **Phase 3B** against it.

### Terminal steps

2. Enable branch protection with the CI jobs as required checks.
3. Review the named-exception ledger and any recorded deviations/waivers.
4. If/when the project goes public: `templates/go-public-checklist.md`,
   maintainer-only.

## Phase 5 — Record

- Bootstrap PR includes: the completed verification matrix (with observed
  output), recorded deviations (invariants not natively satisfiable, with
  reasons), and the identity/allowlist decisions from Phase 0.
- **Open the bootstrap PR as a draft.** It is the first PR judged by the
  review-evidence gate installed in Phase 2.8, which passes drafts
  trivially and fails ready PRs with no review evidence. Take it out of
  draft once a fresh-context reviewer has reviewed the bootstrap diff and
  the matrix, and the `## Independent review` block/packet is attached —
  the gate applies to its own installation like any other change.
- First `docs/HANDOVER.md` entry: what was installed, what was waived,
  what's pending from Phase 4.
- Port any *new* invariant discovered during bootstrap back to this
  playbook (policy first, reference later).
