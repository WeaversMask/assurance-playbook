#!/usr/bin/env node
// Documentation-consistency gate for THIS repository.
//
// WHY IT EXISTS. Of the regressions found on the advisor-mode branch — things
// that worked and then broke because something else was fixed — eight of nine
// were in markdown, and none had any mechanical protection. A moved directory
// left four citations dangling; renumbering a phase left three cross-references
// pointing at the wrong item; moving one catalogue entry between tiers left a
// stated count wrong; a table row was added without removing the one it
// replaced. Every one was found by hand, by running the same greps again, and
// every round of hand-checking found something.
//
// ─── SCOPE, deliberately narrow ────────────────────────────────────────────
// This checks claims about the PRESENT that resolve to a name. It does not
// check wording, phrasing, or whether two documents agree in prose. A doc gate
// that fires on wording is deleted within a week, and one that tries to keep
// three documents in agreement fires on wording by construction.
//
// Four checks:
//
//   1. A cited path with a directory prefix must exist, unless that prefix names
//      a bootstrapped project's tree (`docs/`, `src/`, …) rather than this one.
//      Prose, link targets, and fenced code blocks are all scanned; inside a
//      fence a token needs a real file extension to count as a path claim.
//   2. A `Phase N.M` citation must name an item that exists in that phase.
//   3. Within a phase, list-item numbers must ascend — markdown renumbers from
//      the first item, so an out-of-order label renders as a different number
//      than every cross-reference to it says.
//   4. The catalogue's own counts and per-entry fields must hold.
//
// ─── WHAT IT DOES NOT CHECK, and these are real limits ─────────────────────
//
//   * Bare filenames (`documentation.md`, `HANDOVER.md`). They are ambiguous:
//     most describe a file in a BOOTSTRAPPED project, not one here, and
//     resolving them relative to the citing file would fire on every one of
//     those. Only paths with a directory prefix are checked.
//   * A path whose prefix names a target project's tree. That set is a
//     maintained list, and maintaining it is this check's ongoing cost.
//   * Whether a cited file says what the citation claims it says. It resolves;
//     that is all this knows.
//   * Whether prose in two policies agrees. Deliberately out of scope.
//   * Anchors (`#section`), which are stripped before resolution.
//   * Globs and placeholders — `policies/*.md`, `runners/<harness>/`. They name
//     a set or a variable, not a file, so "does it exist" is the wrong
//     question. Both appear in the repo today and both fired on the first run.
//
// ─── FAIL-CLOSED ───────────────────────────────────────────────────────────
// Zero markdown files, zero path citations, zero phases, zero catalogue
// entries, or a missing BOOTSTRAP/catalogue all FAIL. A check that examined
// nothing must never read as clean.
//
// Check 4 is the closest thing here to a wording check: it requires each
// catalogue entry to carry a `**Default` and a `**Blind spot` field. That is
// justified because `decisions/README.md` states the field contract
// explicitly, and because a missing blind spot is what makes a catalogue read
// as coverage. If it ever starts firing on renamed-but-equivalent fields,
// delete it rather than loosening it.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { resolve, join, dirname, sep } from "node:path";
import process from "node:process";
import console from "node:console";

const ROOT = resolve(import.meta.dirname, "..");
const problems = [];
const note = (m) => problems.push(m);

function die(...lines) {
  for (const l of lines) console.error(l);
  process.exit(1);
}

// ── Collect the markdown ────────────────────────────────────────────────────
function markdownFiles(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    if (name === ".git" || name === "node_modules") continue;
    const full = join(dir, name);
    // A broken symlink threw a raw ENOENT out of statSync and took the whole
    // gate with it. That exits non-zero, so it fails closed — but by accident,
    // with a stack trace where a finding belongs. An unreadable entry in the
    // docs tree IS a finding; report it as one.
    let stat;
    try {
      stat = statSync(full);
    } catch {
      note(`${full.slice(ROOT.length + 1)}: cannot be read (broken symlink or unreadable)`);
      continue;
    }
    if (stat.isDirectory()) markdownFiles(full, acc);
    // `.endsWith(".md")` is case-SENSITIVE while the filesystem underneath is
    // not, so a file named NOTES.MD was never scanned and the file count did
    // not move. Same root cause as the case bug in checkPath, from the other
    // side: one comparison too strict, one too loose.
    else if (name.toLowerCase().endsWith(".md")) acc.push(full);
  }
  return acc;
}

const files = markdownFiles(ROOT);
if (files.length === 0) die("❌ docs: no markdown files found. A check that examined nothing must block.");

const rel = (f) => f.slice(ROOT.length + 1);

// Roots that name a BOOTSTRAPPED project's tree rather than this one. Anything
// else with a directory prefix is checked.
//
// THE SCOPING WAS THE OTHER WAY ROUND AND IT DEFEATED THE CHECK. It only looked
// at paths whose first segment is a directory that exists HERE — which a moved
// directory's old path can never satisfy, because the old directory is gone.
// Reverting `runners/claude/skill/…` to `skill/…`, the exact regression this
// gate was written for, passed. Found by mutating the gate; reading it would
// not have shown this.
//
// `docs/` is principled rather than arbitrary: documentation.md DEFINES it as
// the target project's layout. The rest are roots that appear only in examples.
// A new example root will produce a loud false positive — add it here, and
// prefer that to the silent miss the allowlist gave.
const TARGET_ROOTS = new Set([
  "docs", "src", "packages", "apps", ".husky", "node_modules", "dist", "test-results",
]);

// ── 1. Path citations ───────────────────────────────────────────────────────
// Backticked paths, markdown link targets, and paths inside fenced code blocks.
//
// THE CODE FENCES ARE NOT OPTIONAL. The regression this gate exists for lived
// in a shell recipe inside an indented fence — a `cp` line citing a directory
// that had moved. Scanning only prose missed it twice while the gate looked
// correct, which is the second time reading the check would not have shown what
// mutating it did.
//
// Inside a fence the ambiguity is much higher — commands, refs, placeholders —
// so a token there is only treated as a path claim if it carries a real file
// extension. Without that, `dev/null`, `refs/heads/probe` and `path/to/file`
// were reported, which is four false positives against five checked tokens: the
// profile of a gate that gets deleted in its first week.
const BACKTICKED = /`([^`\s]+\/[^`\s]+)`/g;
const LINKED = /\]\((?!https?:|#)([^)\s]+)\)/g;
// Indented fences count: the recipe that regressed sits inside a list item.
const FENCE = /^[ \t]*```[a-z]*\n([\s\S]*?)^[ \t]*```/gm;
// The left boundary stops `~/.claude/x` matching as `.claude/x`.
const FENCE_TOKEN = /(?<![A-Za-z0-9._~/-])([A-Za-z0-9][A-Za-z0-9._-]*(?:\/[A-Za-z0-9._-]+)+)/g;
// Case-insensitive, like the file walker. It was not, so `.MD` inside a fence
// stayed invisible after discovery was fixed — half a fix reads as a whole one.
const FENCE_EXT = /\.(md|sh|mjs|js|cjs|toml|yml|yaml|json|ts|tsx)$/i;

/**
 * `n/a` and friends: prose that is a fraction, not a path. The original test —
 * "any segment shorter than two characters" — excluded far more than that. It
 * silently dropped EVERY citation containing a one-character directory,
 * unchecked AND uncounted, so `policies/x/process.md` bought an exemption by
 * having an `x` in it. Requiring the absence of a file extension keeps `n/a`
 * out while keeping extensionless real files (`.githooks/pre-commit`,
 * `hooks/pre-commit` — exactly the files this repo keeps moving) in.
 */
function isProseFraction(raw) {
  if (/\.[A-Za-z0-9]+$/.test(raw)) return false;
  // EVERY segment, not ANY. `some` was still exempting `policies/x/pre-commit`
  // and every `./`-prefixed path — a far wider hole than the `n/a` this exists
  // for, and the second time this one test has been too broad. A real path has
  // at least one segment worth naming; `n/a` and `a/b` do not.
  const segs = raw.split("/").filter(Boolean);
  return segs.length > 0 && segs.every((seg) => seg.length < 2);
}

let pathCitations = 0;

/**
 * Resolve `raw` under `base`, one segment at a time, against the real directory
 * listing.
 *
 * WHY NOT existsSync. It defers to the filesystem, and APFS here is
 * case-INSENSITIVE while the Linux runners these projects use for CI are not.
 * `Policies/Process.md` resolved locally, was a dead link on GitHub, and would
 * fail in CI — the gate reported "all resolve" throughout. A doc gate whose
 * answer depends on which machine ran it is not a gate.
 *
 * Returns the real (correctly-cased) path, or null when nothing matches.
 */
function resolveExact(base, raw) {
  let dir = base;
  const real = [];
  for (const seg of raw.split("/")) {
    if (seg === "" || seg === ".") continue;
    if (seg === "..") {
      dir = dirname(dir);
      real.push("..");
      continue;
    }
    let entries;
    try {
      entries = readdirSync(dir);
    } catch {
      return null;
    }
    const exact = entries.includes(seg)
      ? seg
      : entries.find((e) => e.toLowerCase() === seg.toLowerCase());
    if (!exact) return null;
    real.push(exact);
    dir = join(dir, exact);
  }
  // A `../` citation must not escape the repository. One that did would match
  // against whatever sits beside the clone on this machine — green here, and
  // meaningless in any other checkout.
  //
  // NOT A PREFIX TEST. `startsWith(ROOT)` is satisfied by any SIBLING whose name
  // merely begins with the repo's — `assurance-playbook-scratch` passes it — so
  // the first version of this guard let the escape it was written to stop walk
  // straight through. Compare against the boundary, not the string.
  const abs = resolve(dir);
  if (abs !== ROOT && !abs.startsWith(ROOT + sep)) return null;
  return real.join("/");
}

/** Report a cited path unless it resolves from the root or from the citing file. */
function checkPath(file, raw) {
  pathCitations += 1;
  const want = raw.split("/").filter((s) => s !== "" && s !== ".").join("/");
  // BOTH BASES BEFORE ANY VERDICT. The first version returned on the first base
  // that resolved AT ALL, so a citation matching exactly relative to the citing
  // file was reported as a case error whenever the root happened to hold a
  // case-insensitive near-match. That rejects a correct citation — the failure
  // this repo says gets a doc gate deleted in its first week — and the case fix
  // introduced it. An exact match anywhere wins; a near-miss is only reported
  // when no base matched exactly.
  const nearMisses = [];
  for (const base of [ROOT, dirname(file)]) {
    const real = resolveExact(base, raw);
    if (real === null) continue;
    if (real === want) return;
    nearMisses.push(real);
  }
  if (nearMisses.length > 0) {
    note(`${rel(file)}: cites \`${raw}\`, which differs in case from \`${nearMisses[0]}\``);
    return;
  }
  note(`${rel(file)}: cites \`${raw}\`, which does not exist`);
}

for (const file of files) {
  const text = readFileSync(file, "utf8");

  FENCE.lastIndex = 0;
  for (const block of text.matchAll(FENCE)) {
    FENCE_TOKEN.lastIndex = 0;
    for (const m of block[1].matchAll(FENCE_TOKEN)) {
      const raw = m[1];
      if (!FENCE_EXT.test(raw)) continue;
      if (TARGET_ROOTS.has(raw.split("/")[0])) continue;
      if (isProseFraction(raw)) continue;
      checkPath(file, raw);
    }
  }

  for (const re of [BACKTICKED, LINKED]) {
    re.lastIndex = 0;
    for (const m of text.matchAll(re)) {
      const raw = m[1].split("#")[0].replace(/[.,;:]$/, "");
      if (!raw.includes("/")) continue;
      const first = raw.split("/")[0];
      if (TARGET_ROOTS.has(first) || first === "" || first.startsWith("~")) continue;
      // A glob or a placeholder is not a claim that a specific file exists:
      // `policies/*.md` means the policy set, `runners/<harness>/` means
      // whichever harness a project named. Both fired on the very first run,
      // which is how a doc gate earns deletion in its first week.
      if (/[*?<>{}@]/.test(raw)) continue;
      // Prose like `n/a` is not a path. Requiring every segment to be at least
      // two characters excludes it without excluding real extensionless files —
      // an extension test looked simpler and silently dropped every hook path
      // (`hooks/pre-commit`, `.githooks/pre-commit`), which are exactly the
      // files this repo moves around.
      if (isProseFraction(raw)) continue;
      // Resolved from the repo root, and also relative to the citing file — a
      // citation inside reference/node-pnpm/ may legitimately be either.
      checkPath(file, raw);
    }
  }
}
if (pathCitations === 0) {
  die("❌ docs: no in-repo path citations found at all.", "   That is not a clean repo, it is a broken scanner.");
}

// ── 2 & 3. Phase items and the citations that name them ─────────────────────
const bootstrapPath = join(ROOT, "BOOTSTRAP.md");
if (!existsSync(bootstrapPath)) die("❌ docs: BOOTSTRAP.md is missing.");
const bootstrap = readFileSync(bootstrapPath, "utf8");

/** phase number -> { list: [numbers in document order], all: Set<number> } */
const phases = new Map();
let current = null;
for (const line of bootstrap.split("\n")) {
  const head = line.match(/^## Phase (\d+)/);
  if (head) {
    current = Number(head[1]);
    phases.set(current, { list: [], all: new Set() });
    continue;
  }
  if (current === null) continue;
  const item = line.match(/^(\d+)\.\s/);
  if (item) {
    const n = Number(item[1]);
    phases.get(current).list.push(n);
    phases.get(current).all.add(n);
    continue;
  }
  // An item can also live in a sub-heading: "### HUMAN STOP — 1. Create the remote".
  const inHeading = line.match(/^#{3,}.*?—\s*(\d+)\.\s/);
  if (inHeading) phases.get(current).all.add(Number(inHeading[1]));
}
if (phases.size === 0) die("❌ docs: no phases found in BOOTSTRAP.md — the parser or the file changed shape.");

// 3. Labels must ascend, or markdown renders numbers no cross-reference matches.
for (const [n, { list }] of phases) {
  for (let i = 1; i < list.length; i += 1) {
    if (list[i] <= list[i - 1]) {
      note(
        `BOOTSTRAP.md: Phase ${n} item labels do not ascend (${list[i - 1]} then ${list[i]}). ` +
          `Markdown renumbers from the first item, so the rendered numbers will not match citations.`,
      );
      break;
    }
  }
}

// 2. Every `Phase N.M` citation names an item that exists.
let phaseCitations = 0;
for (const file of files) {
  const text = readFileSync(file, "utf8");
  for (const m of text.matchAll(/Phase (\d+)\.(\d+)/g)) {
    phaseCitations += 1;
    const [, p, i] = m;
    const phase = phases.get(Number(p));
    if (!phase) {
      note(`${rel(file)}: cites Phase ${p}.${i}, but BOOTSTRAP.md has no Phase ${p}`);
    } else if (!phase.all.has(Number(i))) {
      const have = [...phase.all].sort((a, b) => a - b).join(", ");
      note(`${rel(file)}: cites Phase ${p}.${i}, but Phase ${p} has items {${have}}`);
    }
  }
}
if (phaseCitations === 0) {
  die("❌ docs: no `Phase N.M` citations found — the scanner is looking for the wrong shape.");
}

// ── 4. The catalogue's own numbers and fields ───────────────────────────────
const cataloguePath = join(ROOT, "decisions", "catalogue.md");
if (!existsSync(cataloguePath)) die("❌ docs: decisions/catalogue.md is missing.");
const catalogue = readFileSync(cataloguePath, "utf8");

// THE ANCHOR WAS THE VULNERABILITY. Splitting on `T0|[A-G]\d` meant an entry
// whose id fell outside that range was not a boundary — it was ABSORBED into
// the entry above it. It never appeared in `blocks`, so the `N of the M
// entries` claim still matched, and it was never checked for the two fields
// check 4 exists to enforce. The catalogue is designed to grow, and the letters
// grow out of range at H — and BOTH expressions excluded lowercase, so the one
// shape this check exists to catch walked past it in the form nobody predicts.
// Found by an external review, round 7.
const blocks = catalogue.split(/^(?:### |## )(?=[A-Za-z]\d)/m).slice(1);
if (blocks.length === 0) die("❌ docs: no catalogue entries parsed — the entry heading shape changed.");

// Widening the anchor fixes the ids we can predict. This catches the ones we
// cannot: heading ids are counted INDEPENDENTLY of the split, so any shape the
// split still fails to treat as a boundary (`AA1`, a lowercase id) shows up as
// a disagreement rather than as silence. A count derived from the same regex as
// the thing it counts can only ever agree with itself.
const headingIds = [...catalogue.matchAll(/^(?:### |## )([A-Za-z]+\d+)\b/gm)].map((m) => m[1]);
if (headingIds.length !== blocks.length) {
  note(
    `catalogue: ${headingIds.length} entry heading(s) but ${blocks.length} parsed block(s) — ` +
      `an entry id outside the anchored range is being absorbed into the entry above it`,
  );
}

let tierGated = 0;
for (const block of blocks) {
  const id = block.split(/\s|—/)[0];
  const tier = block.match(/^\*\*Tier ([123—])/m);
  if (!tier) {
    note(`catalogue ${id}: no \`**Tier N\` line`);
    continue;
  }
  if (tier[1] === "2" || tier[1] === "3") tierGated += 1;
  if (id === "T0") continue; // T0's layout is deliberately different
  for (const field of ["**Default", "**Blind spot"]) {
    if (!block.includes(field)) note(`catalogue ${id}: missing a \`${field}\` field`);
  }
}

const claim = catalogue.match(/Tier gates (\d+) of the (\d+) entries/);
if (!claim) {
  note("catalogue: the `Tier gates N of the M entries` claim is missing — it is what makes the counts checkable");
} else {
  if (Number(claim[2]) !== blocks.length) {
    note(`catalogue: claims ${claim[2]} entries, found ${blocks.length}`);
  }
  if (Number(claim[1]) !== tierGated) {
    note(`catalogue: claims ${claim[1]} tier-gated entries, found ${tierGated}`);
  }
}

// ── Report ──────────────────────────────────────────────────────────────────
if (problems.length) {
  console.error(`❌ docs: ${problems.length} problem(s).`);
  for (const p of problems) console.error(`   ${p}`);
  console.error("");
  console.error("   These are claims about the present that stopped resolving.");
  console.error("   Fix the citation or the thing it names — do not loosen the check.");
  process.exit(1);
}

console.log(
  `✅ docs: ${files.length} files, ${pathCitations} in-repo path citations, ` +
    `${phaseCitations} phase citations, ${blocks.length} catalogue entries — all resolve.`,
);
