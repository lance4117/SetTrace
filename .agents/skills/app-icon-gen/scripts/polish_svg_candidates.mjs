#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const polishScript = fileURLToPath(new URL("./polish_svg_geometry.mjs", import.meta.url));
const DEFAULT_CANDIDATES = [
  { tolerance: 0.1, smooth: "none" },
  { tolerance: 0.2, smooth: "none" },
  { tolerance: 0.4, smooth: "none" },
  { tolerance: 0.15, smooth: "continuous" },
];

function usage() {
  console.error(
    "Usage: node polish_svg_candidates.mjs --input INPUT.svg --out-dir OUT_DIR [--report REPORT.json] [--reference REFERENCE.png] [--candidate 0.2:none] [--precision 3] [polish guardrail flags]",
  );
}

function numberArg(value, name) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`${name} must be a finite number`);
  }
  return parsed;
}

function parseCandidate(value) {
  const [toleranceRaw, smoothRaw = "none"] = String(value).split(":");
  const tolerance = Number(toleranceRaw);
  if (!Number.isFinite(tolerance) || tolerance < 0) {
    throw new Error(`invalid --candidate tolerance: ${value}`);
  }
  if (!["none", "continuous", "geometric"].includes(smoothRaw)) {
    throw new Error(`invalid --candidate smooth value: ${value}`);
  }
  return { tolerance, smooth: smoothRaw };
}

function parseArgs(argv) {
  const parsed = {
    candidates: [],
    passThrough: {},
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--input") {
      parsed.input = next;
      i += 1;
    } else if (arg === "--out-dir") {
      parsed.outDir = next;
      i += 1;
    } else if (arg === "--report") {
      parsed.report = next;
      i += 1;
    } else if (arg === "--reference") {
      parsed.reference = next;
      i += 1;
    } else if (arg === "--candidate") {
      parsed.candidates.push(parseCandidate(next));
      i += 1;
    } else if (
      [
        "--precision",
        "--max-mean-delta",
        "--max-alpha-mean-delta",
        "--max-bbox-drift",
        "--max-centroid-drift",
        "--max-visible-pct-delta",
        "--max-reference-delta-increase",
      ].includes(arg)
    ) {
      parsed.passThrough[arg] = numberArg(next, arg);
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input || !parsed.outDir) {
    throw new Error("--input and --out-dir are required");
  }
  if (parsed.candidates.length === 0) {
    parsed.candidates = DEFAULT_CANDIDATES;
  }
  return parsed;
}

function candidateId(candidate, index) {
  const tolerance = String(candidate.tolerance).replace(".", "p");
  return `${String(index + 1).padStart(2, "0")}-t${tolerance}-${candidate.smooth}`;
}

function passThroughArgs(args) {
  return Object.entries(args.passThrough).flatMap(([key, value]) => [key, String(value)]);
}

function scoreCandidate(report) {
  if (report.decision !== "accepted") {
    return Number.POSITIVE_INFINITY;
  }
  const referenceScore =
    report.reference_comparison?.status === "compared"
      ? report.reference_comparison.candidate_mean_rgb_delta
      : null;
  const driftScore =
    report.comparison_to_original.mean_rgb_delta +
    report.drift.bbox_px * 0.25 +
    report.drift.centroid_px * 0.25 +
    report.drift.visible_pct_delta * 100;
  return Number(((referenceScore ?? 0) + driftScore).toFixed(4));
}

async function writeJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const inputPath = resolve(args.input);
  const outDir = resolve(args.outDir);
  await mkdir(outDir, { recursive: true });
  const candidates = [];
  for (let index = 0; index < args.candidates.length; index += 1) {
    const candidate = args.candidates[index];
    const id = candidateId(candidate, index);
    const acceptedOut = resolve(outDir, `${id}.accepted-or-original.svg`);
    const candidateOut = resolve(outDir, `${id}.candidate.svg`);
    const reportPath = resolve(outDir, `${id}.report.json`);
    const polishArgs = [
      polishScript,
      "--input",
      inputPath,
      "--out",
      acceptedOut,
      "--candidate-out",
      candidateOut,
      "--report",
      reportPath,
      "--tolerance",
      String(candidate.tolerance),
      "--smooth",
      candidate.smooth,
      ...passThroughArgs(args),
    ];
    if (args.reference) {
      polishArgs.push("--reference", resolve(args.reference));
    }
    execFileSync("node", polishArgs, { stdio: "pipe" });
    const report = JSON.parse(await readFile(reportPath, "utf8"));
    const score = scoreCandidate(report);
    candidates.push({
      id,
      tolerance: candidate.tolerance,
      smooth: candidate.smooth,
      decision: report.decision,
      reasons: report.reasons,
      score: Number.isFinite(score) ? score : null,
      candidate_svg: candidateOut,
      accepted_or_original_svg: acceptedOut,
      report: reportPath,
      comparison_to_original: report.comparison_to_original,
      drift: report.drift,
      reference_comparison: report.reference_comparison,
    });
  }
  const accepted = candidates
    .filter((candidate) => candidate.decision === "accepted")
    .sort((a, b) => a.score - b.score);
  const summary = {
    schema_version: 1,
    input: inputPath,
    out_dir: outDir,
    status: accepted.length > 0 ? "accepted_candidates_ready_for_review" : "no_accepted_candidates",
    candidate_count: candidates.length,
    accepted_count: accepted.length,
    rejected_count: candidates.length - accepted.length,
    recommended_candidate: accepted[0] ?? null,
    candidates,
    semantic_note:
      "This ranks geometry candidates by bounded rendered drift. The recommended candidate still needs source-analysis, overlay/diff, and final package verification before use.",
  };
  const reportPath = resolve(args.report ?? `${outDir}/polish-svg-candidates-report.json`);
  await writeJson(reportPath, summary);
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error.stack ?? error.message);
  process.exit(1);
});
