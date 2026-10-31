#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Resvg } from "@resvg/resvg-js";
import paper from "paper";
import { PNG } from "pngjs";

const DEFAULT_CANVAS = 1024;

function usage() {
  console.error(
    "Usage: node polish_svg_geometry.mjs --input INPUT.svg --out OUT.svg [--report REPORT.json] [--candidate-out CANDIDATE.svg] [--reference REFERENCE.png] [--tolerance 0.6] [--smooth none|continuous|geometric] [--precision 3] [--max-mean-delta 1.2] [--max-alpha-mean-delta 1.2] [--max-bbox-drift 2] [--max-centroid-drift 2] [--max-visible-pct-delta 0.015] [--max-reference-delta-increase 0.75]",
  );
}

function numberArg(value, name) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`${name} must be a finite number`);
  }
  return parsed;
}

function parseArgs(argv) {
  const parsed = {
    tolerance: 0.6,
    smooth: "none",
    precision: 3,
    maxMeanDelta: 1.2,
    maxAlphaMeanDelta: 1.2,
    maxBboxDrift: 2,
    maxCentroidDrift: 2,
    maxVisiblePctDelta: 0.015,
    maxReferenceDeltaIncrease: 0.75,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--input") {
      parsed.input = next;
      i += 1;
    } else if (arg === "--out") {
      parsed.out = next;
      i += 1;
    } else if (arg === "--report") {
      parsed.report = next;
      i += 1;
    } else if (arg === "--candidate-out") {
      parsed.candidateOut = next;
      i += 1;
    } else if (arg === "--reference") {
      parsed.reference = next;
      i += 1;
    } else if (arg === "--tolerance") {
      parsed.tolerance = numberArg(next, "--tolerance");
      i += 1;
    } else if (arg === "--smooth") {
      parsed.smooth = next;
      i += 1;
    } else if (arg === "--precision") {
      parsed.precision = numberArg(next, "--precision");
      i += 1;
    } else if (arg === "--max-mean-delta") {
      parsed.maxMeanDelta = numberArg(next, "--max-mean-delta");
      i += 1;
    } else if (arg === "--max-alpha-mean-delta") {
      parsed.maxAlphaMeanDelta = numberArg(next, "--max-alpha-mean-delta");
      i += 1;
    } else if (arg === "--max-bbox-drift") {
      parsed.maxBboxDrift = numberArg(next, "--max-bbox-drift");
      i += 1;
    } else if (arg === "--max-centroid-drift") {
      parsed.maxCentroidDrift = numberArg(next, "--max-centroid-drift");
      i += 1;
    } else if (arg === "--max-visible-pct-delta") {
      parsed.maxVisiblePctDelta = numberArg(next, "--max-visible-pct-delta");
      i += 1;
    } else if (arg === "--max-reference-delta-increase") {
      parsed.maxReferenceDeltaIncrease = numberArg(next, "--max-reference-delta-increase");
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input || !parsed.out) {
    throw new Error("--input and --out are required");
  }
  if (!["none", "continuous", "geometric"].includes(parsed.smooth)) {
    throw new Error('--smooth must be "none", "continuous", or "geometric"');
  }
  if (parsed.tolerance < 0) {
    throw new Error("--tolerance must be non-negative");
  }
  if (!Number.isInteger(parsed.precision) || parsed.precision < 0 || parsed.precision > 6) {
    throw new Error("--precision must be an integer from 0 to 6");
  }
  return parsed;
}

function parseCanvas(svg) {
  const viewBox = /\bviewBox\s*=\s*["']([^"']+)["']/i.exec(svg)?.[1];
  if (viewBox) {
    const parts = viewBox.trim().split(/[,\s]+/).map(Number);
    if (parts.length === 4 && parts.every((part) => Number.isFinite(part)) && parts[2] > 0 && parts[3] > 0) {
      return { width: parts[2], height: parts[3], viewBox };
    }
  }
  const width = Number(/\bwidth\s*=\s*["']([0-9.]+)/i.exec(svg)?.[1] ?? DEFAULT_CANVAS);
  const height = Number(/\bheight\s*=\s*["']([0-9.]+)/i.exec(svg)?.[1] ?? width);
  return {
    width: Number.isFinite(width) && width > 0 ? width : DEFAULT_CANVAS,
    height: Number.isFinite(height) && height > 0 ? height : DEFAULT_CANVAS,
    viewBox: `0 0 ${DEFAULT_CANVAS} ${DEFAULT_CANVAS}`,
  };
}

function countPathCommands(pathData) {
  return (pathData.match(/[AaCcHhLlMmQqSsTtVvZz]/g) ?? []).length;
}

function roundPathData(pathData, precision) {
  const factor = 10 ** precision;
  return pathData.replace(/-?\d*\.?\d+(?:e[-+]?\d+)?/gi, (value) => {
    const rounded = Math.round(Number(value) * factor) / factor;
    if (Object.is(rounded, -0)) {
      return "0";
    }
    return Number.isInteger(rounded) ? String(rounded) : String(rounded);
  });
}

function polishPathData(pathData, args, canvas) {
  paper.project?.clear?.();
  paper.setup(new paper.Size(canvas.width, canvas.height));
  const moveCount = (pathData.match(/[Mm]/g) ?? []).length;
  const item =
    moveCount > 1
      ? new paper.CompoundPath({ pathData })
      : new paper.Path(pathData);
  const paths = item.className === "CompoundPath" ? item.children : [item];
  for (const path of paths) {
    if (args.tolerance > 0) {
      path.simplify(args.tolerance);
    }
    if (args.smooth !== "none") {
      path.smooth({ type: args.smooth });
    }
  }
  return roundPathData(item.pathData, args.precision);
}

function replacePathData(svg, args, canvas) {
  const pathRegex = /<path\b[^>]*\bd\s*=\s*(["'])(.*?)\1[^>]*>/gis;
  const pathReports = [];
  let changed = false;
  const candidate = svg.replace(pathRegex, (tag, quote, pathData) => {
    const beforeCommands = countPathCommands(pathData);
    let polishedData;
    try {
      polishedData = polishPathData(pathData, args, canvas);
    } catch (error) {
      pathReports.push({
        status: "failed",
        error: error.message,
        original_command_count: beforeCommands,
      });
      return tag;
    }
    const afterCommands = countPathCommands(polishedData);
    const polishedTag = tag.replace(/\bd\s*=\s*(["'])(.*?)\1/is, `d=${quote}${polishedData}${quote}`);
    if (polishedTag !== tag) {
      changed = true;
    }
    pathReports.push({
      status: "polished",
      original_command_count: beforeCommands,
      candidate_command_count: afterCommands,
      original_length: pathData.length,
      candidate_length: polishedData.length,
    });
    return polishedTag;
  });
  return {
    candidate,
    changed,
    pathReports,
    pathCount: pathReports.length,
  };
}

function renderSvg(svg, canvas) {
  const png = new Resvg(svg, {
    background: "transparent",
    fitTo: { mode: "width", value: Math.round(canvas.width) },
  }).render().asPng();
  return PNG.sync.read(png);
}

function visibleStats(png) {
  let minX = png.width;
  let minY = png.height;
  let maxX = -1;
  let maxY = -1;
  let visible = 0;
  let sumX = 0;
  let sumY = 0;
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const alpha = png.data[(y * png.width + x) * 4 + 3];
      if (alpha > 8) {
        visible += 1;
        sumX += x;
        sumY += y;
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  return {
    visible_pixels: visible,
    bbox: visible > 0 ? { min_x: minX, min_y: minY, max_x: maxX, max_y: maxY } : null,
    centroid: visible > 0 ? { x: sumX / visible, y: sumY / visible } : null,
  };
}

function premultiplied(data, offset, channel) {
  return (data[offset + channel] * data[offset + 3]) / 255;
}

function comparePngs(a, b) {
  if (a.width !== b.width || a.height !== b.height) {
    throw new Error(`image dimensions differ: ${a.width}x${a.height} vs ${b.width}x${b.height}`);
  }
  let rgbTotal = 0;
  let alphaTotal = 0;
  let maxPixelMeanRgb = 0;
  let pixelsGt10 = 0;
  const pixelCount = a.width * a.height;
  for (let index = 0; index < pixelCount; index += 1) {
    const offset = index * 4;
    const rgbDelta =
      (Math.abs(premultiplied(a.data, offset, 0) - premultiplied(b.data, offset, 0)) +
        Math.abs(premultiplied(a.data, offset, 1) - premultiplied(b.data, offset, 1)) +
        Math.abs(premultiplied(a.data, offset, 2) - premultiplied(b.data, offset, 2))) /
      3;
    rgbTotal += rgbDelta;
    alphaTotal += Math.abs(a.data[offset + 3] - b.data[offset + 3]);
    maxPixelMeanRgb = Math.max(maxPixelMeanRgb, rgbDelta);
    if (rgbDelta > 10) {
      pixelsGt10 += 1;
    }
  }
  return {
    mean_rgb_delta: Number((rgbTotal / pixelCount).toFixed(4)),
    mean_alpha_delta: Number((alphaTotal / pixelCount).toFixed(4)),
    max_pixel_mean_rgb_delta: Number(maxPixelMeanRgb.toFixed(4)),
    pct_pixels_mean_rgb_gt_10: Number(((pixelsGt10 / pixelCount) * 100).toFixed(4)),
  };
}

function bboxDrift(a, b) {
  if (!a || !b) {
    return Number.POSITIVE_INFINITY;
  }
  return Math.max(
    Math.abs(a.min_x - b.min_x),
    Math.abs(a.min_y - b.min_y),
    Math.abs(a.max_x - b.max_x),
    Math.abs(a.max_y - b.max_y),
  );
}

function centroidDrift(a, b) {
  if (!a || !b) {
    return Number.POSITIVE_INFINITY;
  }
  return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

function visiblePctDelta(a, b) {
  return Math.abs(a - b) / Math.max(1, a);
}

async function writeText(path, text) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, text, "utf8");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const inputPath = resolve(args.input);
  const outPath = resolve(args.out);
  const reportPath = resolve(args.report ?? `${args.out}.geometry-polish.json`);
  const originalSvg = await readFile(inputPath, "utf8");
  const canvas = parseCanvas(originalSvg);
  const replacement = replacePathData(originalSvg, args, canvas);
  const reasons = [];

  if (replacement.pathCount === 0) {
    reasons.push("no_path_elements_found");
  }
  if (!replacement.changed) {
    reasons.push("candidate_has_no_path_changes");
  }
  if (replacement.pathReports.some((item) => item.status === "failed")) {
    reasons.push("one_or_more_paths_failed_to_polish");
  }

  const originalPng = renderSvg(originalSvg, canvas);
  const candidatePng = renderSvg(replacement.candidate, canvas);
  const originalStats = visibleStats(originalPng);
  const candidateStats = visibleStats(candidatePng);
  const candidateComparison = comparePngs(originalPng, candidatePng);
  const drift = {
    bbox_px: Number(bboxDrift(originalStats.bbox, candidateStats.bbox).toFixed(4)),
    centroid_px: Number(centroidDrift(originalStats.centroid, candidateStats.centroid).toFixed(4)),
    visible_pct_delta: Number(visiblePctDelta(originalStats.visible_pixels, candidateStats.visible_pixels).toFixed(6)),
  };

  if (candidateComparison.mean_rgb_delta > args.maxMeanDelta) {
    reasons.push("candidate_mean_delta_exceeds_limit");
  }
  if (candidateComparison.mean_alpha_delta > args.maxAlphaMeanDelta) {
    reasons.push("candidate_alpha_delta_exceeds_limit");
  }
  if (drift.bbox_px > args.maxBboxDrift) {
    reasons.push("candidate_bbox_drift_exceeds_limit");
  }
  if (drift.centroid_px > args.maxCentroidDrift) {
    reasons.push("candidate_centroid_drift_exceeds_limit");
  }
  if (drift.visible_pct_delta > args.maxVisiblePctDelta) {
    reasons.push("candidate_visible_area_drift_exceeds_limit");
  }

  let referenceComparison = null;
  if (args.reference) {
    const referencePng = PNG.sync.read(await readFile(resolve(args.reference)));
    if (referencePng.width !== originalPng.width || referencePng.height !== originalPng.height) {
      reasons.push("reference_dimensions_do_not_match_rendered_svg");
      referenceComparison = {
        status: "skipped_dimension_mismatch",
        reference_width: referencePng.width,
        reference_height: referencePng.height,
      };
    } else {
      const originalToReference = comparePngs(originalPng, referencePng);
      const candidateToReference = comparePngs(candidatePng, referencePng);
      const meanDeltaIncrease = Number((candidateToReference.mean_rgb_delta - originalToReference.mean_rgb_delta).toFixed(4));
      referenceComparison = {
        status: "compared",
        original_mean_rgb_delta: originalToReference.mean_rgb_delta,
        candidate_mean_rgb_delta: candidateToReference.mean_rgb_delta,
        mean_rgb_delta_increase: meanDeltaIncrease,
        max_reference_delta_increase: args.maxReferenceDeltaIncrease,
      };
      if (meanDeltaIncrease > args.maxReferenceDeltaIncrease) {
        reasons.push("candidate_reference_delta_worsened");
      }
    }
  }

  const accepted = reasons.length === 0;
  const decision = accepted ? "accepted" : "rejected_kept_original";
  await writeText(outPath, accepted ? replacement.candidate : originalSvg);
  if (args.candidateOut) {
    await writeText(resolve(args.candidateOut), replacement.candidate);
  }

  const report = {
    schema_version: 1,
    input: inputPath,
    out: outPath,
    candidate_out: args.candidateOut ? resolve(args.candidateOut) : null,
    decision,
    reasons,
    parameters: {
      tolerance: args.tolerance,
      smooth: args.smooth,
      precision: args.precision,
      max_mean_delta: args.maxMeanDelta,
      max_alpha_mean_delta: args.maxAlphaMeanDelta,
      max_bbox_drift: args.maxBboxDrift,
      max_centroid_drift: args.maxCentroidDrift,
      max_visible_pct_delta: args.maxVisiblePctDelta,
      max_reference_delta_increase: args.maxReferenceDeltaIncrease,
    },
    path_count: replacement.pathCount,
    paths: replacement.pathReports,
    comparison_to_original: candidateComparison,
    drift,
    original_stats: originalStats,
    candidate_stats: candidateStats,
    reference_comparison: referenceComparison,
    semantic_note:
      "This report is a geometry drift guard, not semantic approval. The agent must still inspect the icon, overlay, and source_analysis before replacing an identity-sensitive layer.",
  };
  await writeText(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify({ decision, report: reportPath, out: outPath, reasons }, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error.stack ?? error.message);
  process.exit(1);
});
