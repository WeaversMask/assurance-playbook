# Policy: Quality Gates

> Stack-agnostic invariants. Mechanisms are chosen per project (see
> `BOOTSTRAP.md`); `reference/node-pnpm/` shows one full instantiation.

## Invariants

1. **Every PR passes, in CI:** lint, static type/consistency check, a full
   build, and the full test suite. Local hooks may run subsets for speed;
   CI always runs the whole graph and is the authority.
2. **Sign-off runs at the workspace root against the whole dependency
   graph.** Filtered/partial runs (single package, single target) are for
   iteration only — they bypass graph-level failures (Argus P1-02: a
   workspace dependency cycle reached CI exactly this way). "Done" is only
   claimed after a full-graph run.
3. **Coverage floor on changed code:** ≥85% line, ≥80% branch (adjust per
   project at bootstrap, then hold). Coverage cannot drop across a PR.
4. **Coverage exclusions are explicit and justified.** Generated code,
   type-only files, logic-free re-export barrels, and test fixtures may be
   excluded — each exclusion listed in the coverage config with a comment
   saying why. No blanket directory excludes.
5. **Conventional commits** (`feat|fix|chore|refactor|docs|test`), enforced
   by a commit-msg hook, not convention alone.
6. **No silent suppression.** Every disabled lint rule, ignored warning, or
   type-checker escape hatch carries an inline justification comment.
7. **Every gate skip is named, scoped, and justified.** Skips target one
   gate (`SKIP=<gate>` or equivalent), never the whole hook chain
   (`--no-verify` is banned). The justification goes in the commit message
   (or PR description for push-time skips).
8. **Pre-existing debt ratchets.** Where a gate is introduced into a repo
   that already violates it, the existing violation count is recorded and
   may never increase; new violations block immediately.
9. **Independent review evidence on every PR**, mechanically enforced: a CI
   job fails any non-draft PR that lacks the review block/packet. Review
   tiers and reviewer rules are in [process.md](process.md) — doc-based
   process gates fail under momentum; only mechanical ones hold.
10. **PR hygiene:** linked task ID in the description; tracker and handover
    files updated (see [process.md](process.md)).

## Enforcement layering

Every gate that can run locally runs in a git hook *and* in CI. The hook is
the fast feedback layer and may be skipped with justification (invariant 7);
CI is the backstop and is never skippable. A gate that exists only as
documentation is not a gate.

## Fail-closed rule

A check that cannot evaluate must block, not pass. If the tool is missing,
its version is unreadable, or its subprocess errors, the gate fails with
instructions — never a silent allow. (Argus applies this to the hook
toolchain floor, the secret-scan layers, and the license gate; apply it to
every gate you build.)

## Stack mapping hints (non-normative)

| Invariant        | Node/TS (reference)         | Python                    | Rust                      | Swift                      |
| ---------------- | --------------------------- | ------------------------- | ------------------------- | -------------------------- |
| Lint             | ESLint + Prettier           | ruff (+ format)           | clippy + rustfmt          | SwiftLint + swift-format   |
| Type check       | `tsc --noEmit` (strict)     | mypy/pyright (strict)     | `cargo check`             | `swift build`              |
| Tests + coverage | vitest + v8 coverage        | pytest + coverage.py      | cargo test + llvm-cov     | XCTest + xccov             |
| Commit lint      | commitlint                  | commitizen/gitlint        | committed/commitlint      | commitlint                 |
| Hook manager     | husky + lint-staged         | pre-commit                | lefthook / cargo-husky    | lefthook / plain hooksPath |

The mapping is a starting point; the invariant list above is what must
survive the translation.
