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
     doesn't resolve locally). This catches `SKIP`-ed commits and history
     rewritten after the staged scan (rebase, amend). Nothing unscanned
     leaves the machine.
   - **CI** — scans **full repository history** on every PR and push to the
     default branch. This layer can never be skipped.
2. **Fail closed on operational errors.** A scan that never ran must not
   pass: missing binary → block with install instructions; scanner's
   underlying git invocation errors → block. (Argus finding: gitleaks exits
   0 when its internal `git log` fails — the hook must detect and block
   that itself.)
3. **Skips are scoped and justified.** `SKIP=<scanner>` on one commit/push
   with written justification in the commit message (commit) or PR
   description (push). Never a blanket hook bypass.
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
