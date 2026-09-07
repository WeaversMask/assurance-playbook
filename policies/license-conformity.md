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

   **An allowlist entry may be scoped to a path or file type.** A licence can
   be acceptable for one kind of artifact and not for another — `OFL-1.1` is
   right for a font asset and wrong for a source dependency — and a single
   global list forces the whole tree to the laxest entry that any one file
   needed. A scoped entry records the licence, the scope it applies within,
   and why the scope is the boundary. Unscoped remains the default: scope is
   a deliberate narrowing, not a way to slip a licence past review.
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

   **Its scope is an explicit decision, made at bootstrap and recorded.**
   The whole resolved tree, direct dependencies only, runtime only, or none —
   the honest default is the whole resolved tree, because that is what is
   redistributed. Whichever is chosen, **derive the set from the lockfile
   rather than from what is installed here**: packages constrained by
   platform, architecture or an unselected extra resolve differently per
   machine, so a walk of the installed directory silently omits packages the
   project still ships. Generating fewer notices than the project
   redistributes is the failure this decision exists to prevent, and it is
   invisible from the machine that generated them.
7. **A project licenses each asset class it ships, and says which is which.**
   Code, prose and content, and binary or data assets are three different
   things to license, and a repo that carries more than one of them rarely
   wants one licence over all of it — permissive code alongside content the
   maintainer does not want redistributed is the common case, not an edge
   case. Each class that diverges gets **its own licence file**, named so the
   boundary is legible (`LICENSE`, `LICENSE-content`, …), and the README
   states which covers what. A single-class project keeps a single `LICENSE`
   and is finished in one line — the invariant is that the answer is chosen,
   not that it is plural.

   **The licence file and the manifest always agree** for the class the
   manifest describes (e.g. `LICENSE` ↔ `package.json#license` /
   `Cargo.toml#license`). Most manifests can express exactly one licence, so
   the manifest carries the **code** licence and the other classes live in
   their own files; a manifest that silently claims the code licence covers
   committed content is the failure this rule prevents.

   **Third-party content the project does not own is not a licensing choice
   at all** — it is somebody else's terms, and those terms bind whatever the
   project's own licence says. Where the project ships or caches material it
   did not author, the governing terms are recorded alongside the licence
   decision, because they usually constrain the architecture — a caching
   layer can be a licence question before it is a performance question.

   The copyright holder string is a deliberate maintainer decision — see
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
