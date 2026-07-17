# Policy: Identity Protection

> For projects developed under a pseudonymous public identity. All
> mechanisms here are git/GitHub-level — they port to any stack verbatim.
> Hard-won context: Argus had to rewrite its entire history (2026-07-04) to
> scrub a personal email that repo-local config alone failed to keep out.
> Configuration is not enforcement.

## Invariants

1. **Each project declares exactly one public identity** — display name +
   provider noreply email (e.g. `<handle>` +
   `<id>+<handle>@users.noreply.github.com`) — recorded in the project's
   CLAUDE.md/contributor doc and set as **repo-local** git config at clone
   time. Global git config is never relied on.
2. **The identity is gate-verified, not just configured** — same layering
   as secret scanning:
   - **Pre-commit:** fail if the effective `user.email`/`user.name` differ
     from the declared identity (single source of truth in a repo config
     file, not hardcoded in the hook).
   - **Pre-push:** scan the outgoing range's author *and* committer emails
     against an allowlist (declared identity + known bots such as
     dependabot/release bots); fail closed on anything else.
   - **CI:** the same range/history check as backstop.
3. **Personal identifiers never appear in file content either:** no
   personal emails, no home-directory paths (`/Users/<name>/…`), no machine
   identifiers — in code, docs, fixtures, build outputs, or source maps.
   Enforced by extending the secret scanner with **local personal-identifier
   rules** (invariant 5).
4. **Anything exported out of a private repo gets fresh history** — copy
   files into a new `git init`, never fork/clone-push. A private repo's
   history may contain things its files no longer show.
5. **The enforcement patterns live outside the repo.** A scanner rule
   containing your personal email would *disclose* it if ever published.
   Personal-identifier patterns therefore live in a **per-machine,
   gitignored local config** that extends the committed scanner config
   (see `templates/gitleaks.local.example.toml`). The committed config
   never contains them; creating the local file is a human bootstrap step,
   never an agent's.
6. **Going public is maintainer-only, voluntary, unscheduled — never
   agentic.** Agents never change repo visibility, never create public
   repos, and never push to retired/frozen archives. The flip follows
   `templates/go-public-checklist.md`.
7. **Retired pre-scrub repos are frozen forever.** GitHub keeps
   `refs/pull/*` fetchable even after history rewrites — a pre-scrub
   repo's PRs make scrubbed commits recoverable, so such a repo must never
   go public and never be pushed to. Archive it read-only.
8. **Cross-project linkability is a conscious decision.** Reusing one
   pseudonym (and recognizable tooling fingerprints) across projects links
   the projects to each other, though not to you. Decide per project at
   bootstrap: shared persona or a fresh one.

## Incident response — personal identifier committed

Same shape as a leaked secret, adapted:

1. Assess exposure: private repo, or already public/pushed to a shared
   remote? Private-only buys time; public means assume indexed.
2. Rewrite history (`git filter-repo`) to scrub the identifier from all
   author/committer fields and blob content.
3. If the repo had PRs/issues referencing pre-rewrite commits: migrate work
   to a **new repo with the cleaned history** and freeze the old one
   (invariant 7) — the rewrite alone does not make old commits
   unfetchable.
4. Verify with a full-history scan using the local personal-identifier
   patterns, and an author/committer audit
   (`git log --format='%ae %ce' | sort -u`).
5. Record the incident and the verification result in the handover.

## Mechanism notes (non-normative)

- The Argus reference implements invariants 1 and 3–7 but **not yet the
  identity gates of invariant 2** — the policy leads the reference there
  (tracked in Argus as a pending task). The gate spec in invariant 2 is
  what to build.
- Worktree gotcha: with a shared `core.hooksPath`, hooks run from the
  primary checkout — identity gates must resolve config *per worktree*.
- Provider caveat: web-UI merge/squash commits are stamped with the
  account's *profile display name*; the email stays the noreply address.
  Keep the profile name pseudonymous too if linkability matters.
