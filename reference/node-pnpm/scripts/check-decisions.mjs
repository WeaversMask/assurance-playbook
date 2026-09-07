#!/usr/bin/env node
// Decision-trigger gate — the mechanism that makes declining a recommendation
// safe rather than a way to lose it (process.md, "Open decisions").
//
// THE INVARIANT: an open decision must name the event that will bring it back,
// and that event must not already have happened.
//
// WHY IT EXISTS. A tracker's decision table said "reviewed before every merge —
// answered or consciously re-dated" and nothing enforced it. Two rows walked
// straight past triggers they had set themselves; several merges passed with
// neither re-dated, and both were eventually found by hand rather than by
// anything mechanical. ELAPSED TIME IS NOT THE MEASURE — merges are, because
// every merge was a moment the rule above the table says the row should have
// been read. This is the mechanism that reads it.
//
// It is also what lets the setup procedure offer a recommendation without
// forcing it. A declined recommendation becomes a row with a trigger; without
// this gate that row is a note, and "we'll consider it later" is where deferred
// quality goes to die.
//
// ─── SCOPE, deliberately narrow ────────────────────────────────────────────
// The "Open decisions" table in the tracker, and nothing else. Not the risk
// register, which mirrors some of these rows in prose and is a different kind of
// document; not the ADRs, which record decisions already made. A check that
// tried to keep three documents in agreement would fire on wording and be
// deleted within a month.
//
// ─── FAIL-CLOSED, in five ways ─────────────────────────────────────────────
// A missing section, an unparseable table, zero rows, an unreadable current
// phase, or a trigger naming an id that resolves to nothing all FAIL. A check
// that examined nothing must never read as clean.
//
// Zero rows fails rather than reporting itself dormant: the tier decision itself
// is recorded as a row here, so a table with no rows means the tracker was
// gutted, not that nothing has been declined.
//
// DETECTION IS LOOSER THAN PARSING, and that gap is the point. The first version
// of this idea anchored both on the same regex, so a row the parser could not
// read was a row the gate never knew existed — a bolded id or a missing cell
// dropped it silently and the gate printed a tick over a decision that had
// rotted. Every row that LOOKS like a decision row is detected; every detected
// row that will not parse is REPORTED.
//
// ─── WHAT IT DOES NOT CHECK, and these are real limits ─────────────────────
//
//   * whether a closed row's answer is CORRECT, or even an answer. "Closed —
//     we'll see" passes. Only a human catches that.
//   * whether a `standing` row should have a real trigger. `standing` is an
//     escape hatch and honest about being one; its cost is that a row can hide
//     there forever. It is greppable, which is the mitigation.
//   * whether the trigger is the RIGHT one. Restricting the vocabulary to four
//     forms does catch the obviously unfirable trigger — prose like "until X
//     buys us something specific" is rejected as a bad form rather than passed
//     as unexpired — but a WELL-FORMED trigger can still be unfirable in spirit:
//     `P7-start` on a project that will never reach phase 7 parses, resolves,
//     and never comes due. Naming an event that will actually happen is a
//     judgement, and no parser makes it.
//
// ─── PORTING THIS ──────────────────────────────────────────────────────────
// This is an exhibit, not a copy source. What ports is the shape: read one
// table, resolve each trigger against something the project already knows, fail
// closed everywhere. What does not port is how the current phase and the known
// ids are discovered — that is this tracker's layout and yours will differ.

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import process from "node:process";
import console from "node:console";

const REPO_ROOT = resolve(import.meta.dirname, "..");
const TRACKER = "docs/IMPLEMENTATION.md";

/** A row is closed when its decision cell opens with the closure marker. */
const CLOSED = /^\*{0,2}Closed \d{4}-\d{2}-\d{2}/;

/**
 * Anything that LOOKS like a decision row, however malformed. Deliberately
 * permissive: bolded ids and missing cells must still be seen.
 */
const DECISION_LINE = /^\|\s*\*{0,2}(D-[0-9A-Za-z]+)\*{0,2}\s*\|/;

const TRIGGER_LABEL = /\*{0,2}Trigger:\*{0,2}\s*/i;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const PHASE_BOUNDARY = /^P(\d+)-(start|exit)$/;

const fail = [];
const dormantNotes = [];

function die(...lines) {
  for (const l of lines) console.error(l);
  process.exit(1);
}

// ── Read the tracker ────────────────────────────────────────────────────────
let text;
try {
  text = readFileSync(resolve(REPO_ROOT, TRACKER), "utf8");
} catch (err) {
  die(`❌ decisions: cannot read ${TRACKER} — ${err.message}`, "   A check that cannot evaluate must block.");
}

// ── The section ─────────────────────────────────────────────────────────────
const section = text.split(/^## /m).find((s) => s.startsWith("Open decisions"));
if (!section) {
  die(
    `❌ decisions: no "## Open decisions" section in ${TRACKER}.`,
    "   The section is where every declined recommendation lives. Its absence",
    "   is not an empty table — it is a check with nothing to examine.",
  );
}

// ── Current phase: the thing triggers are resolved against ──────────────────
// Read from the "**Phase:**" line in the tracker's Current state section — the
// LINE, not the section.
//
// The first version scanned the whole section for the first phase-shaped token,
// which is a fail-OPEN: "finishing P1-17, now entering P3-01" resolved to P1-17,
// so a trigger of P2-start read as unexpired and the gate PASSED while printing
// the stale phase in its own success line. A check that resolves the wrong
// value confidently is worse than one that cannot resolve at all.
//
// More than one token on the line therefore FAILS rather than picking one.
function currentPhase() {
  const state = text.split(/^## /m).find((s) => s.startsWith("Current state"));
  if (!state) return { error: 'no "Current state" section' };
  const line = state.split("\n").find((l) => /\*\*Phase:\*\*/.test(l));
  if (!line) return { error: 'no "**Phase:**" line in Current state' };
  const tokens = [...line.matchAll(/\bP(\d+)-([A-Za-z0-9]+)\b/g)];
  if (tokens.length === 0) return { error: `the "**Phase:**" line holds no P<n>-<x> token: ${line.trim()}` };
  if (tokens.length > 1) {
    return { error: `the "**Phase:**" line holds ${tokens.length} phase tokens; which one is current is ambiguous` };
  }
  return { major: Number(tokens[0][1]), raw: tokens[0][0] };
}

const phase = currentPhase();
if (phase.error) {
  die(
    `❌ decisions: cannot determine the current phase from ${TRACKER}.`,
    `   ${phase.error}`,
    '   Expected exactly one token like "P1-04" on the "**Phase:**" line.',
    "   Phase-boundary triggers cannot be resolved without it, and a trigger",
    "   that cannot be resolved must not read as unexpired.",
  );
}

// ── Ids, harvested by section ───────────────────────────────────────────────
// Two sets, and the difference between them is the whole completed-id check.
//
// `knownIds` catches the typo: a trigger naming an id that appears nowhere never
// fires, and is indistinguishable from one that has not come due.
//
// `completedIds` decides whether a trigger has FIRED, and it is read from the
// "Recently completed" section BY HEADING. The first version tested each line
// for /Recently completed|✅|Done/ with no idea which section the line was in —
// so against the tracker template this repo actually ships, whose completed
// rows are `| ID | Task | PR | Merged |` and carry none of those words, every
// completed-id trigger read as unfired. A silent pass in the gate whose stated
// premise is that a check examining nothing must never read as clean.
//
// The id shape is deliberately NOT pattern-matched. An earlier regex accepted
// `W1` and `P1-17` and rejected `T-001`, which is the shape the tracker template
// advertises — so the exhibit and the template disagreed about ids while both
// claimed to be the reference. A trigger token that is not a date, a phase
// boundary or `standing` must simply RESOLVE: found in the tracker, or the row
// fails. Prose fails that test for free.
function idsIn(sectionText) {
  const ids = new Set();
  if (!sectionText) return ids;
  for (const line of sectionText.split("\n")) {
    if (!/^\|/.test(line) || /^\|[\s:|-]+\|?$/.test(line)) continue;
    const first = line.split("|")[1];
    if (!first) continue;
    const id = first.trim().replace(/[*`]/g, "");
    if (id && !/\s/.test(id) && id.length <= 24 && id.toLowerCase() !== "id") ids.add(id);
  }
  return ids;
}

const sectionsByHeading = new Map(
  text.split(/^## /m).slice(1).map((s) => [s.split("\n")[0].trim(), s]),
);
const sectionNamed = (re) => [...sectionsByHeading].find(([h]) => re.test(h))?.[1];

const knownIds = new Set();
for (const [, s] of sectionsByHeading) for (const id of idsIn(s)) knownIds.add(id);

const completedIds = idsIn(sectionNamed(/recently completed|^completed/i));

// ── Where the trigger lives ─────────────────────────────────────────────────
// Two shapes are accepted, because both are in use. A dedicated `Trigger`
// column is the clearer one and is what the template ships; an inline
// `**Trigger:** <token>` inside the recommendation cell is what a table
// predating the column looks like. Reading the header rather than a fixed index
// means adding a column elsewhere does not silently shift what this reads.
const headerLine = section.split("\n").find((l) => /^\|/.test(l) && /trigger/i.test(l));
const triggerColumn = headerLine
  ? headerLine.split("|").map((c) => c.trim().toLowerCase()).findIndex((c) => c === "trigger")
  : -1;

/** The trigger token for a row, or null if it has none. */
function triggerOf(cells) {
  if (triggerColumn > 0 && cells[triggerColumn]) {
    const v = cells[triggerColumn].trim();
    if (v && v !== "—" && v !== "-") return v;
  }
  const labelled = cells.find((c) => TRIGGER_LABEL.test(c));
  if (labelled) return labelled.split(TRIGGER_LABEL)[1].split(/[,|]/)[0].trim();
  return null;
}

// ── Walk the rows ───────────────────────────────────────────────────────────
const rows = section.split("\n").filter((l) => DECISION_LINE.test(l));
if (rows.length === 0) {
  die(
    `❌ decisions: the Open decisions table has no rows.`,
    "   At least the assurance-tier decision is recorded here at bootstrap, so",
    "   an empty table means the section was gutted rather than that nothing",
    "   has been declined. Comparing nothing must never read as clean.",
  );
}

let open = 0;
for (const line of rows) {
  const id = line.match(DECISION_LINE)[1];
  const cells = line.split("|").map((c) => c.trim());

  if (cells.length < 5) {
    fail.push(`${id}: row will not parse (${cells.length - 2} cells found). Reported rather than skipped.`);
    continue;
  }

  const decision = cells[2];
  if (CLOSED.test(decision.replace(/^\*+/, ""))) continue;
  open += 1;

  const raw = triggerOf(cells);
  if (!raw) {
    fail.push(`${id}: open row with no trigger. Every open row names the event that reopens it.`);
    continue;
  }

  const token = raw.replace(/[.`*]/g, "").trim();

  if (token === "standing") {
    dormantNotes.push(`${id}: standing — no trigger by choice. Greppable, and that is the only mitigation.`);
    continue;
  }

  if (ISO_DATE.test(token)) {
    const today = new Date().toISOString().slice(0, 10);
    if (token <= today) fail.push(`${id}: trigger date ${token} has passed (today ${today}).`);
    continue;
  }

  const boundary = token.match(PHASE_BOUNDARY);
  if (boundary) {
    const major = Number(boundary[1]);
    const passed = boundary[2] === "start" ? phase.major >= major : phase.major > major;
    if (passed) fail.push(`${id}: trigger \`${token}\` has passed (current phase ${phase.raw}).`);
    continue;
  }

  if (!knownIds.has(token)) {
    fail.push(
      `${id}: trigger \`${token}\` is not a date, not a phase boundary, not \`standing\`, ` +
        `and resolves to no id in the tracker. A typo is a trigger that never fires.`,
    );
    continue;
  }

  if (completedIds.has(token)) {
    fail.push(`${id}: trigger \`${token}\` has completed. Answer the row or consciously re-date it.`);
  }
}

// ── Report ──────────────────────────────────────────────────────────────────
for (const note of dormantNotes) console.log(`⚠️  STANDING  ${note}`);

if (fail.length) {
  console.error(`❌ decisions: ${fail.length} problem(s) in ${TRACKER}.`);
  for (const f of fail) console.error(`   ${f}`);
  console.error("");
  console.error("   A trigger that has passed without the row being answered or re-dated");
  console.error("   is a decision that quietly stopped being open. That is the whole");
  console.error("   failure this gate exists to catch.");
  process.exit(1);
}

console.log(`✅ decisions: ${open} open row(s) checked against current phase ${phase.raw}; no trigger has passed.`);
