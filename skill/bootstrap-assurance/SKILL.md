---
name: bootstrap-assurance
description: Instantiate the maintainer's assurance playbook — quality gates, layered secret scanning, license conformity, identity protection, and agentic process — in a new or existing project of any stack. Use when starting a new project, or when asked to bootstrap, install, or port the assurance playbook / quality-and-safety workflows.
---

# Bootstrap the assurance playbook

The playbook lives at `~/assurance-playbook` (private repo; if missing, ask
the maintainer where it is). It splits every workflow into stack-agnostic
**policy** (`policies/*.md` — normative) and per-stack **mechanism**
(derived at bootstrap; `reference/node-pnpm/` is a worked example, never a
copy source).

## Procedure

0. **Plan first, if there is no plan.** If the target directory is empty
   or has no `PROJECT-PLAN.md`, offer to draft one together from
   `~/assurance-playbook/templates/PROJECT-PLAN.template.md` before any
   bootstrapping: interview the maintainer section by section, honor the
   template's writing rules and per-section contracts (license-check §4
   choices against `policies/license-conformity.md` while drafting, keep
   §11 tasks session-sized), and write it as `PROJECT-PLAN.md` in the
   project directory (no git needed yet — Phase 1 inits and commits it).
   Proceed to bootstrap only when the maintainer marks it **Agreed** or
   explicitly chooses to skip the plan. Shredding (§14) happens after
   bootstrap, as its own docs PR.
1. Read `~/assurance-playbook/README.md`, then `BOOTSTRAP.md` — including
   its **"The ordering rule"** preamble — then the six files in
   `policies/`. BOOTSTRAP.md is the installation order; follow it phase by
   phase in the **target project's repo**.
2. **Phase 0 first, always:** collect the maintainer inputs (stack,
   identity decision, pseudonymity yes/no, license/allowlist, coverage
   floors) via questions before writing anything. Do not guess an identity
   and do not reuse one from another project without being told to. Say up
   front that a pseudonymous project needs a hand-written
   `.gitleaks.local.toml` before the gates can be proven, so it is ready
   when the run reaches it.
3. **The pseudonymity answer is effectively irreversible after the first
   PR** (invariant 7a): `refs/pull/*` survive history rewrites, so a later
   change of mind means a fresh repo and the loss of every PR and review
   thread. Record the decision in the project's CLAUDE.md. A "no" is
   legitimate and selects the `assurance:no-local-identity-rules` opt-out
   marker in the committed scanner config — it must be chosen, not
   defaulted into.

   **On a "yes", never write that marker string into the scanner config at
   all — not even in a comment saying it is deliberately absent.** The hooks
   detect the opt-out by searching that file, so any occurrence disarms the
   personal-identifier layer, silently. Describe the marker instead of
   quoting it, and match it anchored to a standalone comment line. This is a
   real 2026-08-15 finding, not a hypothetical: the explaining comment was
   the thing that disabled the check.
4. **Commit the Phase 1 foundation before arming any gate.** That is the
   last unhooked commit; everything after it is committed through the
   gates. Derive each gate from the policy invariants using the target
   stack's native tooling, and consult the reference to see what
   fail-closed plumbing a complete instantiation has — except the identity
   gates, which the reference does not implement (build them from the
   invariant 2 spec).
5. **Two HUMAN STOPs, and they are not both at the end.** Present each as
   a checklist item and stop there:
   - **End of Phase 2 — the local personal-identifier patterns file.**
     Never create `.gitleaks.local.toml`, never ask for its contents. The
     hooks fail closed while it is missing (invariant 5a), so Phase 2's own
     work cannot be committed and Phase 3 can prove nothing until the
     maintainer writes it. Say that plainly — the block is the feature, and
     **nothing routes around it**: the secret scan is unskippable at every
     layer (secret-scanning invariant 3) and the hooks reject
     `SKIP=gitleaks` rather than honouring it. Waiting is the only move.
   - **Phase 4.1 — creating the remote.** Maintainer-only; it unblocks the
     CI rows in Phase 3B, which are finished after it.
6. **Phase 3 is mandatory, and a block is not a pass.** Prove every
   installed gate by deliberately breaking it, and record the matrix with
   the **observed failure output**. Hooks fail fast and chain, so one
   gate's block masks every gate behind it — a missing local config
   refuses `git commit -m "bad message"` before commitlint ever runs.
   Check that the output names the gate the row is testing; if it names a
   different one, the row is a fail. A gate never seen to fail on its own
   terms is not installed.
7. **Anything the bootstrap installs a generator for gets its freshness
   check in the same phase** (quality-gates.md invariant 11,
   documentation.md invariant 7) — notices files, generated configs,
   generated docs. Never install a generator and leave "add the check
   later" as a follow-up; that is the follow-up that does not happen.
8. **Open the bootstrap PR as a draft.** It is the first PR judged by the
   review-evidence gate it installs; drafts pass trivially, ready PRs
   without evidence fail. Undraft once a fresh-context reviewer has
   reviewed the diff and the matrix.

## Hard rules (from the policies — hold even if asked casually)

- Fresh `git init` for anything exported from a private repo — never fork.
- Repo-local public identity before the first commit.
- Never commit personal identifiers anywhere, including this playbook.
- Never change repo visibility, create public repos, or push to frozen
  archives — going public is maintainer-only.
- **The secret scan is never skipped** — no `SKIP=gitleaks`, no
  `--no-verify`, at any layer. Legitimate secret-shaped strings get a
  reviewed allowlist entry in the committed config. Lint and format keep
  scoped, justified per-commit skips; the scanner does not.
- The single exception is building the Phase 3 "Secret / push" fixture
  (`git -c core.hooksPath=/dev/null commit`, reverted in the same step) —
  never to land work.
