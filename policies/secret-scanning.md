# Policy: Secret Scanning & Sensitive Data

> Stack-agnostic invariants. The scanner itself (gitleaks) is
> language-agnostic, so this policy ports to any stack nearly verbatim —
> only the hook manager and CI wiring change.

## Never committed

- Credentials of any kind: API keys, tokens, private keys/certificates,
  connection strings with passwords, JWT/webhook/signing secrets,
  encryption keys, commercial license keys.
- Local environment data: non-template `.env*` files, local databases,
  IDE workspace files with absolute paths, build outputs and source maps.
- Third-party/customer data: real code from partners as fixtures, internal
  hostnames/IPs/topology, names/emails/identifiers, re-identifiable
  "anonymised" data.
- Personal data of contributors: home-directory paths in any file, personal
  email addresses, machine identifiers. (Identity enforcement is its own
  policy: [identity-protection.md](identity-protection.md).)

## Invariants

1. **Three independent scan layers, all honouring the same config:**
   - **Pre-commit** — scans exactly what will be committed (staged content,
     after any auto-formatting has run).
   - **Pre-push** — scans the exact range the push would publish
     (`remote-sha..local-sha`; conservative fallback when the remote SHA
     doesn't resolve locally). Plenty of commits never pass through the
     staged scan: history rewritten after it (rebase, amend), conflict
     resolutions written during a merge or rebase, cherry-picks, and
     anything authored in a clone where the hooks were not installed.
     Nothing unscanned leaves the machine.
   - **CI** — scans **full repository history** on every PR and push to the
     default branch. This layer can never be skipped.

     **A range-scanning mechanism does not satisfy this, however it is
     labelled.** The distinction is easy to lose because the job name says
     "full history" while the tool underneath scans `base..head`. Verified
     against `gitleaks/gitleaks-action@ff98106e` (v2.3.9), which the
     reference used: on `pull_request` and `push` it builds
     `--log-opts=--no-merges --first-parent <base>^..<head>`, and on a push
     whose refs match it passes `--log-opts=-1` — a **single commit**. Its
     unscoped full scan runs only on `workflow_dispatch` and `schedule`. So
     a repo with no scheduled trigger never scanned its history at all.

     Three specific things a range misses, all of which this layer exists to
     catch: anything older than the range (a secret committed before the
     gates were installed — including the bootstrap's own pre-hook
     foundation commit), anything dropped by `--no-merges` (conflict
     resolutions written during a merge, which is one of the cases pre-push
     is justified by), and anything beyond a truncated commit list (GitHub
     caps a push event's `commits` array at 20).

     Test it by planting a secret in an **old** commit, not at the tip. A
     violation in the branch's own commits is inside the range, so it fails
     correctly and tells you nothing about history depth.
2. **Fail closed on operational errors.** A scan that never ran must not
   pass: missing binary → block with install instructions; scanner's
   underlying git invocation errors → block. (Argus finding: gitleaks exits
   0 when its internal `git log` fails — the hook must detect and block
   that itself.)
3. **The secret scan has no bypass.** Other gates (lint, format) may offer
   a scoped, justified `SKIP=<gate>` for one commit; the scanner never
   does, at any layer, and `--no-verify` is banned outright. A per-commit
   escape hatch is indistinguishable from no scan at all on the one commit
   that needed it most — and where the hooks also gate the
   personal-identifier config (identity-protection.md invariant 5a), a
   single flag disarms the secret layer and the identity layer together.

   The hooks **reject** the retired flag rather than ignoring it: someone
   who types `SKIP=gitleaks` believes the scan was skipped, so failing
   loudly beats silently scanning anyway.

   A string that must legitimately be committed gets a **scoped allowlist
   entry in the committed config** — reviewable, permanent, and visible to
   everyone — instead of a bypass whose only trace is a commit message.
   The cost is real and accepted: a broken or missing scanner blocks all
   commits and pushes until it is fixed. That is the gate working.
4. **Scanner versions are pinned** — the local binary via an install script
   with a pinned version, CI via a pinned action/version — and bumped
   together in the same PR.
5. **Secret-shaped test fixtures are synthetic, deterministic, and
   allowlisted by path.** A `fakeSecret()`-style helper produces obviously
   fake values (`AKIA-FAKE-TEST-FIXTURE-…`); fixtures live in one dedicated
   allowlisted directory with a README stating they are fake. Real secrets
   — even expired ones — never appear in fixtures.
6. **Env template pattern:** every env-var-consuming config ships a
   committed `.env.example` with placeholder values; the real `.env` is
   gitignored; the application validates required vars at startup and
   refuses to start with a clear error.
7. **Build outputs are path-sanitised:** source maps and debug info
   reference project-relative paths, never `/Users/...` or `/home/...`.

## Incident response — a secret was committed

In this order:

1. **Rotate the secret first.** It is compromised the moment it is pushed —
   history is cached, mirrored, and indexed by bots within seconds.
2. Remove it from history (`git filter-repo` — a follow-up commit deleting
   the line leaves it in history).
3. Force-push the cleaned history if the branch is unmerged.
4. Record an incident note in the repo's incident/handover doc.
5. If it reached a merged branch: revoke the access it granted and audit
   logs for the exposure window.

## Mechanism notes (non-normative)

- **gitleaks** with `[extend] useDefault = true` plus project allowlists is
  the reference scanner — see `reference/node-pnpm/gitleaks.toml` and the
  three layers in `reference/node-pnpm/hooks/` + `reference/node-pnpm/ci/ci.yml`.
- The same config file must be honoured by all three layers so allowlists
  apply uniformly.
- Personal-identifier rules (your own name/email) extend the scan via a
  **gitignored local config** — see
  [identity-protection.md](identity-protection.md) and
  `templates/gitleaks.local.example.toml`; they are never committed.
