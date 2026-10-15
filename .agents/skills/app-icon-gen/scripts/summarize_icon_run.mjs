#!/usr/bin/env node
import { readFile, readdir, writeFile } from "node:fs/promises";
import { basename, dirname, join, relative, resolve } from "node:path";

function usage() {
  console.error("Usage: node scripts/summarize_icon_run.mjs --root RUN_ROOT [--out SUMMARY_JSON]");
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--root") {
      parsed.root = next;
      i += 1;
    } else if (arg === "--out") {
      parsed.out = next;
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.root) {
    throw new Error("--root is required");
  }
  return parsed;
}

async function readJson(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

async function readOptionalJson(path) {
  try {
    return await readJson(path);
  } catch (error) {
    if (error?.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

function normalizedDecision(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("_", "-");
}

function isRejectedVisualDecision(visualReview) {
  return ["rejected", "not-candidate", "redesign-needed", "needs-source-vector", "needs-repair"].includes(
    normalizedDecision(visualReview?.decision),
  );
}

async function walk(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walk(path)));
    } else if (entry.name === "package-verification.json") {
      files.push(path);
    }
  }
  return files;
}

function countBy(rows, key) {
  const counts = {};
  for (const row of rows) {
    const value = String(row[key] ?? "unknown");
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

function buildRunRedFlags(rows) {
  const flags = [];
  const total = rows.length;
  if (total === 0) {
    return flags;
  }
  const pngFallbackCount = rows.filter((row) => row.route_status === "png_fallback_selected").length;
  const pngAssetCount = rows.filter((row) => row.asset_format === "png").length;
  const reviewRequiredCount = rows.filter((row) => row.review_required).length;
  const pixelOkCount = rows.filter((row) => row.pixel_status === "ok" && row.local_gate === "ok").length;

  if (total >= 3 && pngFallbackCount / total > 0.5) {
    flags.push({
      code: "png_fallback_dominates_run",
      severity: "high",
      message:
        "More than half of the run selected PNG fallback. Treat this as route review until each PNG is proven clean authored material or an accepted raster fallback.",
      affected_count: pngFallbackCount,
      total,
      recommended_action:
        "Keep clean flat, linear-gradient, text, raster, or dense-brand PNG layers; redraw dirty source-cut/material PNGs as SVG/base geometry or record explicit raster acceptance.",
    });
  }
  if (total >= 3 && pngAssetCount / total > 0.5) {
    flags.push({
      code: "png_assets_dominate_run",
      severity: "medium",
      message:
        "Most generated packages use PNG assets. This can be valid only when the assets are clean authored layers; source-cut PNGs can hide hard mattes, rectangular residue, or baked lighting.",
      affected_count: pngAssetCount,
      total,
      recommended_action:
        "Inspect isolated PNG assets on neutral/checker backgrounds and compare dirty candidates against semantic SVG/base-shape alternatives before reporting readiness.",
    });
  }
  if (pixelOkCount === total && reviewRequiredCount > 0) {
    flags.push({
      code: "pixel_ok_but_review_required",
      severity: "high",
      message:
        "Every package passed pixel gates, but at least one package is still review-required. Do not report the batch as complete.",
      affected_count: reviewRequiredCount,
      total,
      recommended_action: "Resolve route review, visual acceptance, PNG hygiene warnings, or explicitly record a deferred tradeoff.",
    });
  }
  return flags;
}

async function buildSummary(root) {
  const packageReports = (await walk(root)).sort();
  const rows = [];
  for (const reportPath of packageReports) {
    const report = await readJson(reportPath);
    const stylePath = join(dirname(reportPath), "style-report.json");
    let style = {};
    try {
      style = await readJson(stylePath);
    } catch {
      style = {};
    }
    const sidecarVisualReview = await readOptionalJson(join(dirname(reportPath), "visual-review.json"));
    const visualReview = sidecarVisualReview ?? report.visual_review;
    const visualDecisionSource = sidecarVisualReview ? "sidecar" : report.visual_review ? "verification_report" : "not_recorded";
    const rejectedVisualDecision = isRejectedVisualDecision(visualReview);
    const comparison = report.reference_comparison;
    const diagnostics = comparison?.diagnostics;
    rows.push({
      name: style.name ?? basename(dirname(reportPath)),
      path: relative(root, dirname(reportPath)),
      status: report.status,
      mean_delta: comparison?.mean_absolute_rgb_delta ?? null,
      max_mean_delta: comparison?.max_mean_delta ?? null,
      visual_delta_gate: comparison?.visual_delta_gate?.status ?? "not_checked",
      local_gate: comparison?.local_sample_gate?.status ?? "not_checked",
      pixel_status: report.outcome?.pixel_status ?? "unknown",
      route_status: rejectedVisualDecision ? "visual_review_rejected" : (report.outcome?.route_status ?? "unknown"),
      recommended_action: rejectedVisualDecision
        ? "repair_redraw_or_request_source_vector_before_rechecking"
        : (report.outcome?.recommended_action ?? "unknown"),
      review_required: Boolean(report.outcome?.review_required) || rejectedVisualDecision,
      semantic_status: report.semantic_review?.status ?? style.semantic_review?.status ?? "not_provided",
      identity_risk: report.semantic_review?.identity_risk ?? style.semantic_review?.identity_risk ?? "not_recorded",
      route: report.semantic_review?.route ?? style.semantic_review?.route ?? "not_provided",
      source_contract: report.source_analysis || style.source_analysis ? "present" : "missing",
      visual_decision: visualReview?.decision ?? "not_recorded",
      visual_decision_source: visualDecisionSource,
      asset_format: report.outcome?.asset_format ?? style.icon_composer_asset_format ?? "unknown",
      warnings: report.warnings?.length ?? 0,
      failures: report.failures?.length ?? 0,
      p95_delta: diagnostics?.pixel_delta?.p95_mean_rgb_delta ?? null,
      p99_delta: diagnostics?.pixel_delta?.p99_mean_rgb_delta ?? null,
      pct_pixels_gt_25: diagnostics?.pixel_delta?.pct_pixels_mean_rgb_gt_25 ?? null,
      pct_pixels_gt_50: diagnostics?.pixel_delta?.pct_pixels_mean_rgb_gt_50 ?? null,
    });
  }
  const counts = {
    status: countBy(rows, "status"),
    pixel_status: countBy(rows, "pixel_status"),
    local_gate: countBy(rows, "local_gate"),
    visual_delta_gate: countBy(rows, "visual_delta_gate"),
    route_status: countBy(rows, "route_status"),
    semantic_status: countBy(rows, "semantic_status"),
    identity_risk: countBy(rows, "identity_risk"),
    source_contract: countBy(rows, "source_contract"),
    visual_decision: countBy(rows, "visual_decision"),
    asset_format: countBy(rows, "asset_format"),
  };
  return {
    root,
    total: rows.length,
    counts,
    run_red_flags: buildRunRedFlags(rows),
    rows,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const root = resolve(args.root);
  const summary = await buildSummary(root);
  const text = `${JSON.stringify(summary, null, 2)}\n`;
  if (args.out) {
    await writeFile(resolve(args.out), text, "utf8");
  }
  console.log(text);
}

main().catch((error) => {
  usage();
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
