# Go-Public Checklist (maintainer-only — never agentic)

> Going public is a voluntary, unscheduled, manual step performed by the
> maintainer alone. Agents never change repo visibility, never create
> public repos, never push to retired archives. Generalized from the Argus
> go-public runbook; adapt bracketed items per project.

## Preconditions

- [ ] The repo's history has been clean **from birth** (fresh `git init`,
      repo-local identity from the first commit). If not — if any history
      rewrite happened — the pre-rewrite repo is frozen (archived,
      read-only, never public: its `refs/pull/*` keep old commits
      fetchable) and this repo was born from the cleaned history.

## Identity audit (must all come back clean)

- [ ] Author/committer audit: `git log --format='%ae %ce' origin/<default>`
      shows **only** the declared public identity + known bots.
      `git log --format='%an %cn'` likewise.
- [ ] Full-history content scan with the **local personal-identifier
      patterns** (`.gitleaks.local.toml`): 0 hits across all blobs.
- [ ] Grep full history for home-directory paths and machine names:
      0 hits.
- [ ] Secret scan over full history (the CI layer's config): clean.

## Legal / licensing

- [ ] `LICENSE` copyright-holder placeholder resolved to the intended
      (pseudonymous, if applicable) holder; manifest license field agrees.
- [ ] `THIRD-PARTY-NOTICES` regenerated and current with the tree.
- [ ] License gate green; named-exception ledger reviewed one last time.
- [ ] README "external tools / prerequisites" section current, with each
      tool's license (if the project shells out to external tools).

## The flip

- [ ] Rename repos if desired **before** publishing (renames after
      publication break links).
- [ ] Public-only settings that cannot be pre-set while private: private
      vulnerability reporting toggle; review the Actions / fork-PR
      permission defaults the provider applies on flip.
- [ ] Flip visibility → Public.

## Immediately after the flip (public-only quality layers)

- [ ] Enable CodeQL default setup (or the provider's free public-repo
      SAST) — secrets are covered by the scanner; this covers code-level
      vulnerability patterns.
- [ ] Run OpenSSF Scorecard; add the badge/action if the score merits it
      (pinned deps, blocked install scripts, SHA-pinned actions, branch
      protection are its heavyweight criteria).
- [ ] Check the account **profile display name** — the provider stamps it
      on web-UI merge commits; keep it pseudonymous if linkability
      matters.

## Package-registry publishing (separate later step)

- [ ] Registry tokens are set **at this moment, not before**.
- [ ] Publish artifacts reviewed for embedded paths/identifiers (source
      maps, debug info) before the first publish.
