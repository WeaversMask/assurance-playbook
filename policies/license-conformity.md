# Policy: License Conformity & Dependency Intake

> Stack-agnostic invariants distilled from Argus ADR-0002 (licensing) and
> ADR-0003 (supply chain). The *allowlist* and the *project license* are
> per-project decisions confirmed at bootstrap; the gating discipline is not.

## License invariants

1. **Every dependency resolved into the tree** (including transitives and
   bundled/nested packages) **carries a license on the project's SPDX
   allowlist, or is a named exception.** Starting allowlist (adjust at
   bootstrap with maintainer sign-off, then hold):
   `MIT, ISC, Apache-2.0, BSD-2-Clause, BSD-3-Clause, 0BSD, Unlicense,
   CC0-1.0, BlueOak-1.0.0, Python-2.0`.
2. **Deny/flag by default:** `AGPL`, `GPL`, `LGPL` (as a *linked*
   dependency), `SSPL`, `Commons-Clause`, and any tool-specific restricted
   license (e.g. Semgrep-Rules-License). Weak copyleft (`MPL-2.0`) is not
   blanket-allowed — it goes through the exception process.
3. **Named exceptions are pinned to the exact reviewed license string.**
   An exception records package pattern, license string, and reason
   (maintainer-reviewed). It applies only while the package's license is
   byte-identical to what was reviewed — any change re-trips the gate.
4. **The gate fails closed:** unknown SPDX ids, `UNLICENSED`/`UNKNOWN`,
   custom license text, and SPDX `WITH` clauses all block for manual
   review. An unevaluable license is a blocked license.
5. **The gate runs as both a local script and a CI job**, and the policy
   (allowlist + exceptions) lives in exactly one reviewed place per repo.
6. **Notices:** a `THIRD-PARTY-NOTICES` file is generated from the
   dependency tree and regenerated whenever the tree changes (CI-verified).
   License notices are never dropped, even for permissive licenses.
7. **License file and manifest always agree** (e.g. `LICENSE` ↔
   `package.json#license` / `Cargo.toml#license`). The copyright holder
   string is a deliberate maintainer decision — see
   [identity-protection.md](identity-protection.md) for pseudonymous
   holders.

## Copyleft boundary (when the project shells out to tools)

- **Copyleft engines are subprocess-only:** invoked as arm's-length
  separate processes behind an adapter boundary — never imported, linked,
  statically bundled, vendored, or added as submodules.
- **No vendoring of third-party artifacts:** no committed binaries, tool
  source copies, or third-party rulesets whose license restricts
  redistribution. External tools are prerequisites the user installs;
  the README documents each tool and its license.
- **Container images:** a Dockerfile that *installs* external tools is a
  recipe and fine to publish; a *published prebuilt image* with copyleft
  tools baked in is redistribution and needs its own license review first.

## Supply-chain intake invariants

1. **Minimum release age:** the package manager refuses versions published
   less than ~3 days ago (the window in which malicious releases are
   typically detected and yanked). Locked, already-resolved versions are
   unaffected. Urgent security patches use a scoped, same-PR-removed
   exclusion with the advisory cited.
2. **Install/build scripts are denied by default,** with an explicit
   per-package review ledger: `true` = reviewed and allowed, `false` =
   reviewed and denied. Never a reflexive allow; the ledger entry is the
   review record.
3. **New dependencies are verified before install:** exact name (typo-squat
   check) and publisher checked against the registry; version age noted in
   the permission prompt / PR.

## Mechanism notes (non-normative)

- Node/pnpm reference: `reference/node-pnpm/scripts/check-licenses.mjs`
  (note its `.pnpm` virtual-store traversal workaround — pnpm-specific,
  do not port the workaround, port the policy) and
  `generate-third-party-notices.mjs`; supply-chain controls via
  `pnpm-workspace.yaml` `minimumReleaseAge` + `allowBuilds`.
- Other ecosystems have native equivalents that may satisfy several
  invariants at once — evaluate them *against the invariants above*, e.g.
  `cargo-deny` (Rust: licenses + bans + advisories), `pip-licenses` /
  `licensecheck` (Python), `go-licenses` (Go), LicensePlist (Swift/iOS).
  Whatever the tool, confirm it sees the *full resolved tree* and fails
  closed on unknowns — those are the two places native tools most often
  fall short.
