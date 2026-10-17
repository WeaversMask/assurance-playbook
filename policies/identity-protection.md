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
   `AGENTS.md`/contributor doc — the runner-agnostic onboarding home, so the
   declaration reaches an agent on any harness ([documentation.md](documentation.md)
   invariant 1) — and set as **repo-local** git config at clone time. Global git config is never relied on.
2. **The identity is gate-verified, not just configured** — same layering
   as secret scanning:
   - **Pre-commit:** fail if the effective identity differs from the
     declared one (single source of truth in a repo config file, not
     hardcoded in the hook). Check **both `GIT_AUTHOR_IDENT` and
     `GIT_COMMITTER_IDENT`**, not `user.email`/`user.name` — git stamps
     author and committer separately, and reading config misses every
     override that actually matters. `git -c user.email=…`, `--author=…`,
     `GIT_AUTHOR_EMAIL=…` and `GIT_COMMITTER_EMAIL=…` all beat repo config,
     and a hook that checks only the author lets
     `GIT_COMMITTER_EMAIL=personal@… git commit` through silently. (Found
     in a live port, 2026-08-15: pre-push and CI caught it via `%ce`, so
     nothing reached a remote — but the cheapest layer should not be the
     porous one.)
   - **Pre-push:** scan the outgoing range's author *and* committer emails
     against an allowlist (declared identity + known bots such as
     dependabot/release bots); fail closed on anything else.
   - **CI:** the same range/history check as backstop.
3. **Personal identifiers never appear in file content either:** no
   personal emails, no home-directory paths (`/Users/<name>/…`), no machine
   identifiers — in code, docs, fixtures, build outputs, or source maps.
   Enforced by extending the secret scanner with **local personal-identifier
   rules** (invariant 5) **plus a committed, name-free rule for absolute
   home-directory paths** (invariant 5a).

   Agents produce these constantly and innocently: a handover recording
   "run `cd /Users/<name>/proj` first" is the natural way to write down a
   shell gotcha, and it carries a legal name into the history forever.
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

   **5a. The local file's absence is a hard gate, and the path-shape rule
   is committed.** Invariant 5 as originally written was a manual bootstrap
   step with nothing verifying it happened — and in Argus it did not
   happen. The history was scrubbed of a personal email on 2026-07-04; on
   2026-07-23 an agent committed `/Users/<name>/argus` into a handover, and
   it survived for months with pre-commit, pre-push **and** full-history CI
   scanning running the whole time. Three layers, all healthy, none holding
   a pattern that could match — because the only file with such a pattern
   was never created. Two corrections, both in `reference/node-pnpm/`:

   - **The hooks fail when `.gitleaks.local.toml` is missing** (opt out
     with an `assurance:no-local-identity-rules` marker comment in the
     committed config for non-pseudonymous projects). Testing that a file
     *exists* discloses nothing, so this check is safe to commit.

     **The marker only counts as a standalone comment line**, and the hook
     must match it anchored — `^\s*#\s*assurance:no-local-identity-rules\s*$`,
     not a bare substring search. A substring search is disarmable by prose:
     any text in the committed config that merely *mentions* the marker
     satisfies it, and the most likely such text is a comment explaining
     that the project does not opt out. That is not hypothetical — it
     happened during a live port on 2026-08-15, where a pseudonymous
     project's config carried the line "the `assurance:…` marker is
     deliberately ABSENT" and thereby disarmed the entire check. Silently:
     three healthy scan layers, no rule that could match, which is the exact
     failure this invariant exists to prevent, reproduced inside the file
     implementing it.

     Assert it both ways when you install it — that a real standalone marker
     opts out, and that a mention in prose does not.
   - **The absolute-home-path rule ships in the committed config.** Unlike
     an email or a legal name, `(/Users/|/home/|C:\Users\)<something>/` is
     a *shape* — it names nobody, so publishing it leaks nothing, and it
     arms the highest-frequency case from the first commit with no manual
     step at all.

     **Two limits of that rule, both verified against gitleaks 8.30.1.**
     `--redact` hides only a rule's *secret group*, and here that group is the
     folder prefix — so a verbose finding or a JSON report reads
     `cd REDACTED<account>/project` and prints the name the rule exists to keep
     out. Nothing committed asks for either, so this is latent: the first person
     to debug a failing scan with `-v` on a public repo's CI would be the one to
     publish it. Do not add `-v`; do not keep a report of this rule's findings.
     And do **not** close the gap by making the prefix non-capturing: with the
     whole match as the secret and the default rules extended, every `/home/<name>/`
     path stops being caught while `/Users/` ones still are. A fix that loses half
     the rule is worse than the leak it closes, and a suite that never planted a
     `/home/` path would not notice — so each prefix has its own case.

   - **An existing file is not an armed file.** The example ships placeholder
     values behind a marker comment on every fillable line, and the hooks
     **reject any local config that still carries one**. Without this, the
     obvious move — copy the example, mean to edit it, get distracted — leaves
     a file that satisfies the existence check while holding no rule that could
     match: the same three-healthy-layers-nothing-to-match failure, one step
     later.

     **Describe the marker; never quote it.** This is invariant 5a's own lesson
     applied to invariant 5a's own fix. A comment explaining the marker
     *contains* the marker, so prose about the check jams the check — there it
     silently opted a project out, here it would reject a correctly filled file
     forever until someone deleted the explanation. The example's header
     therefore points at the markers on the lines below rather than spelling one
     out.

     **Three ways a file can exist and still be unarmed, and the hook rejects
     all three.** They were not found together: the first check shipped closing
     only the third, and review found the other two the same day.

     - **No rules at all.** `touch .gitleaks.local.toml` satisfied both the
       existence and marker checks, and gitleaks reports "no leaks found" on a
       config with zero rules rather than erroring — so every layer went green
       with the layer entirely absent. A file holding only the `[extend]`
       stanza did the same. The hook now requires at least one rule id. `id =`
       is a schema keyword, so testing for it discloses nothing.
     - **Markers deleted, values kept.** The marker is a trailing comment,
       separable from the value on its own line, so "replace the value **and**
       delete the marker" was two independently satisfiable instructions of
       which only the second was enforced. The example's placeholder values are
       unique strings and are now rejected on their own.
     - **Copied and untouched** — the original case.

     **What none of them closes: a file filled in with values that are simply
     wrong.** A rule whose regex has a typo is armed against nobody and looks
     identical to a working one. Only the self-test covers that.

   - **The block prints the shape and the self-test, not a copy of the example.**
     The maintainer is stopped in a terminal, and sending them to a file in
     another repository is where the procedure loses people. The hook states
     which rules must exist, the `[extend]` line, and how to prove it fires. It
     does **not** reproduce the example's regexes: that would be a second copy
     with nothing cross-checking it. A requirement list and a filled
     instantiation are not copies of each other.

   - **Every message is content-free — file and line numbers only.** This output
     is pasted into the verification matrix, so echoing a matching line would
     write the identifiers being protected into a committed file and an agent's
     context at once.

   - **The self-test checks rule IDs, not a hit count**, and is run by the
     maintainer. This is the only gate a human installs by hand and was the only
     one never proven — a gate never seen to fail is decoration, and that
     applies here too. Counting hits is insufficient because the rules overlap:
     one address trips both the address rule and the domain rule, so four hits
     can come from two working rules and two dead ones. Write one probe line per
     rule using real values, confirm **every** defined rule id appears, and
     include the inherited committed-config rule. Clean up with a trap rather
     than a following `rm` — the file holds real identifiers and must not
     survive a mid-way failure, which is exactly when a trailing command does
     not run.

     Its output — the list of rule ids — is content-free and is what goes in the
     matrix. **The maintainer exercises these rows, not an agent:** proving them
     requires the file to exist in an unarmed state, and an agent never creates,
     reads, or asks about that file. The bootstrap procedure carries a matrix row
     for the missing-file, empty-config and placeholder-value branches. It does
     **not** yet carry one for the self-test, so that part of this paragraph is
     still a requirement on the procedure rather than a description of it.

   *Gotcha, verified against gitleaks 8.30.1:* a rule-scoped allowlist
   needs the plural `[[rules.allowlists]]` form **and**
   `regexTarget = "match"`. The default target is `secret`, which is not
   the same span as the match for a path rule — get it wrong and the
   allowlist is silently inert, which for a CI-runner path
   (`/home/runner/…`) means constant false positives and pressure to
   delete the rule. Test any allowlist by asserting both the hit and the
   miss; an untested allowlist is the usual way a rule ends up disabled.
6. **Going public is maintainer-only, voluntary, unscheduled — never
   agentic.** Agents never change repo visibility, never create public
   repos, and never push to retired/frozen archives. The flip follows
   `templates/go-public-checklist.md`.
7. **Retired pre-scrub repos are frozen forever.** GitHub keeps
   `refs/pull/*` fetchable even after history rewrites — a pre-scrub
   repo's PRs make scrubbed commits recoverable, so such a repo must never
   go public and never be pushed to. Archive it read-only.

   **7a. Corollary — the pseudonymity decision is made before the first
   PR, not before going public.** From the moment a PR exists, its
   `refs/pull/*` pin the tree it was opened against, and `filter-repo`
   plus a force-push cannot reach them; the only complete remedy is
   migrating to a fresh repo, which discards every PR, review thread and
   issue link. On a repo whose *purpose* is demonstrating process, that
   trail is much of the artifact — so a leak discovered late forces a real
   choice between hiding the identifier and keeping the evidence. Deciding
   at `git init` costs nothing; deciding after PR #1 may cost the history.
   Record the decision in the project's `AGENTS.md` at bootstrap, where every
   agent reads it, rather than in a file only one harness loads.
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
