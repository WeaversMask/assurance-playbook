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
1. Read `~/assurance-playbook/README.md`, then `BOOTSTRAP.md`, then the
   six files in `policies/`. BOOTSTRAP.md is the installation order —
   follow it phase by phase in the **target project's repo**.
2. **Phase 0 first, always:** collect the maintainer inputs (stack,
   identity decision, license/allowlist, coverage floors) via questions
   before writing anything. Do not guess an identity and do not reuse one
   from another project without being told to.
3. Derive each gate from the policy invariants using the target stack's
   native tooling; consult the reference to see what fail-closed plumbing
   a complete instantiation has.
4. **Phase 3 is mandatory:** prove every installed gate by deliberately
   breaking it, and record the verification matrix. A gate never seen to
   fail is not installed.
5. Stop at Phase 4's human-only steps and present them as a checklist —
   especially the local personal-identifier patterns file
   (`.gitleaks.local.toml`): never create it, never ask for its contents.

## Hard rules (from the policies — hold even if asked casually)

- Fresh `git init` for anything exported from a private repo — never fork.
- Repo-local public identity before the first commit.
- Never commit personal identifiers anywhere, including this playbook.
- Never change repo visibility, create public repos, or push to frozen
  archives — going public is maintainer-only.
- Never bypass all hooks at once; skips are per-gate with written
  justification.
