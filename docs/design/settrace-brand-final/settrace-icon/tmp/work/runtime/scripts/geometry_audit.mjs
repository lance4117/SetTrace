#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import paper from "paper";

const DEFAULT_CANVAS = 1024;

function usage() {
  console.error(
    "Usage: node geometry_audit.mjs --input INPUT.svg [--report REPORT.json] [--micro-segment-threshold 2] [--high-line-ratio 0.7] [--max-command-count 140] [--fragment-gap 1.5] [--flatten-tolerance 0.5]",
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
    microSegmentThreshold: 2,
    highLineRatio: 0.7,
    maxCommandCount: 140,
    fragmentGap: 1.5,
    flattenTolerance: 0.5,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--input") {
      parsed.input = next;
      i += 1;
    } else if (arg === "--report") {
      parsed.report = next;
      i += 1;
    } else if (arg === "--micro-segment-threshold") {
      parsed.microSegmentThreshold = numberArg(next, "--micro-segment-threshold");
      i += 1;
    } else if (arg === "--high-line-ratio") {
      parsed.highLineRatio = numberArg(next, "--high-line-ratio");
      i += 1;
    } else if (arg === "--max-command-count") {
      parsed.maxCommandCount = numberArg(next, "--max-command-count");
      i += 1;
    } else if (arg === "--fragment-gap") {
      parsed.fragmentGap = numberArg(next, "--fragment-gap");
      i += 1;
    } else if (arg === "--flatten-tolerance") {
      parsed.flattenTolerance = numberArg(next, "--flatten-tolerance");
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input) {
    throw new Error("--input is required");
  }
  if (parsed.microSegmentThreshold < 0 || parsed.fragmentGap < 0 || parsed.flattenTolerance <= 0) {
    throw new Error("threshold values must be positive");
  }
  if (parsed.highLineRatio < 0 || parsed.highLineRatio > 1) {
    throw new Error("--high-line-ratio must be between 0 and 1");
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

function pathElements(svg) {
  const pathRegex = /<path\b[^>]*\bd\s*=\s*(["'])(.*?)\1[^>]*>/gis;
  return [...svg.matchAll(pathRegex)].map((match, index) => ({
    index,
    tag: match[0],
    d: match[2],
    fill: attr(match[0], "fill") ?? "not-recorded",
  }));
}

function attr(tag, name) {
  const match = new RegExp(`\\b${name}\\s*=\\s*["']([^"']+)["']`, "i").exec(tag);
  return match?.[1] ?? null;
}

function commandCounts(pathData) {
  const counts = {};
  for (const command of pathData.match(/[AaCcHhLlMmQqSsTtVvZz]/g) ?? []) {
    const normalized = command.toUpperCase();
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }
  const total = Object.values(counts).reduce((sum, count) => sum + count, 0);
  const moveClose = (counts.M ?? 0) + (counts.Z ?? 0);
  const drawing = Math.max(0, total - moveClose);
  const line = (counts.L ?? 0) + (counts.H ?? 0) + (counts.V ?? 0);
  const curve = (counts.C ?? 0) + (counts.S ?? 0) + (counts.Q ?? 0) + (counts.T ?? 0) + (counts.A ?? 0);
  return {
    counts,
    total,
    drawing,
    line,
    curve,
    line_ratio: drawing > 0 ? Number((line / drawing).toFixed(4)) : 0,
  };
}

function pointDistance(a, b) {
  return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

function flattenedSegmentStats(path, args) {
  const clone = path.clone();
  clone.flatten(args.flattenTolerance);
  const lengths = [];
  for (let i = 1; i < clone.segments.length; i += 1) {
    const length = pointDistance(clone.segments[i - 1].point, clone.segments[i].point);
    if (length > 0) {
      lengths.push(length);
    }
  }
  if (clone.closed && clone.segments.length > 1) {
    const length = pointDistance(clone.segments.at(-1).point, clone.segments[0].point);
    if (length > 0) {
      lengths.push(length);
    }
  }
  clone.remove();
  const micro = lengths.filter((length) => length < args.microSegmentThreshold);
  return {
    flattened_segment_count: lengths.length,
    micro_segment_count: micro.length,
    micro_segment_ratio: lengths.length > 0 ? Number((micro.length / lengths.length).toFixed(4)) : 0,
    shortest_segment_px: lengths.length > 0 ? Number(Math.min(...lengths).toFixed(4)) : null,
  };
}

function boundsOf(item) {
  const bounds = item.bounds;
  return {
    min_x: Number(bounds.left.toFixed(4)),
    min_y: Number(bounds.top.toFixed(4)),
    max_x: Number(bounds.right.toFixed(4)),
    max_y: Number(bounds.bottom.toFixed(4)),
    width: Number(bounds.width.toFixed(4)),
    height: Number(bounds.height.toFixed(4)),
  };
}

function analyzePath(pathElement, args, canvas) {
  paper.project?.clear?.();
  paper.setup(new paper.Size(canvas.width, canvas.height));
  const commands = commandCounts(pathElement.d);
  const moveCount = (pathElement.d.match(/[Mm]/g) ?? []).length;
  const item =
    moveCount > 1
      ? new paper.CompoundPath({ pathData: pathElement.d })
      : new paper.Path(pathElement.d);
  const paths = item.className === "CompoundPath" ? item.children : [item];
  const segmentStats = paths.map((path) => flattenedSegmentStats(path, args));
  const flattenedSegmentCount = segmentStats.reduce((sum, stats) => sum + stats.flattened_segment_count, 0);
  const microSegmentCount = segmentStats.reduce((sum, stats) => sum + stats.micro_segment_count, 0);
  const shortestValues = segmentStats.map((stats) => stats.shortest_segment_px).filter((value) => value != null);
  const length = paths.reduce((sum, path) => sum + path.length, 0);
  const report = {
    index: pathElement.index,
    fill: pathElement.fill,
    class_name: item.className,
    child_count: paths.length,
    command_counts: commands.counts,
    command_count: commands.total,
    drawing_command_count: commands.drawing,
    line_command_count: commands.line,
    curve_command_count: commands.curve,
    line_command_ratio: commands.line_ratio,
    path_length_px: Number(length.toFixed(4)),
    flattened_segment_count: flattenedSegmentCount,
    micro_segment_count: microSegmentCount,
    micro_segment_ratio: flattenedSegmentCount > 0 ? Number((microSegmentCount / flattenedSegmentCount).toFixed(4)) : 0,
    shortest_segment_px: shortestValues.length > 0 ? Number(Math.min(...shortestValues).toFixed(4)) : null,
    bounds: boundsOf(item),
  };
  item.remove();
  return report;
}

function boxGap(a, b) {
  const dx = Math.max(0, Math.max(a.min_x - b.max_x, b.min_x - a.max_x));
  const dy = Math.max(0, Math.max(a.min_y - b.max_y, b.min_y - a.max_y));
  return Math.sqrt(dx ** 2 + dy ** 2);
}

function fragmentedPairs(paths, args) {
  const pairs = [];
  for (let i = 0; i < paths.length; i += 1) {
    for (let j = i + 1; j < paths.length; j += 1) {
      if (paths[i].fill !== paths[j].fill) {
        continue;
      }
      const gap = boxGap(paths[i].bounds, paths[j].bounds);
      if (gap <= args.fragmentGap) {
        pairs.push({
          path_indexes: [paths[i].index, paths[j].index],
          fill: paths[i].fill,
          bbox_gap_px: Number(gap.toFixed(4)),
        });
      }
    }
  }
  return pairs;
}

function buildWarnings(pathReports, fragmentPairs, args) {
  const warnings = [];
  for (const path of pathReports) {
    if (path.command_count > args.maxCommandCount) {
      warnings.push({
        code: "excessive_path_commands",
        severity: "medium",
        path_index: path.index,
        message: `path has ${path.command_count} commands; inspect whether the SVG is an over-traced bitmap`,
      });
    }
    if (path.line_command_ratio >= args.highLineRatio && path.line_command_count >= 8 && path.curve_command_count === 0) {
      warnings.push({
        code: "high_line_command_ratio",
        severity: "medium",
        path_index: path.index,
        message: `path is ${(path.line_command_ratio * 100).toFixed(1)}% line commands with no curve commands; use low-tolerance geometry polish or semantic curve repair if it should be rounded`,
      });
    }
    if (path.micro_segment_count >= 8 || path.micro_segment_ratio >= 0.2) {
      warnings.push({
        code: "micro_segments_present",
        severity: "medium",
        path_index: path.index,
        message: `path has ${path.micro_segment_count} flattened segments shorter than ${args.microSegmentThreshold}px; inspect for trace noise`,
      });
    }
    if (path.class_name === "CompoundPath") {
      warnings.push({
        code: "compound_path_detected",
        severity: "info",
        path_index: path.index,
        message: "compound path detected; verify that holes and negative space are intentional",
      });
    }
  }
  if (fragmentPairs.length > 0) {
    warnings.push({
      code: "possible_fragmented_contour",
      severity: "info",
      pairs: fragmentPairs,
      message: "same-fill path bounds touch or overlap; verify this is intentional disconnected geometry rather than a split continuous mark",
    });
  }
  return warnings;
}

async function writeJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const inputPath = resolve(args.input);
  const svg = await readFile(inputPath, "utf8");
  const canvas = parseCanvas(svg);
  const paths = pathElements(svg);
  const pathReports = paths.map((path) => analyzePath(path, args, canvas));
  const fragmentPairs = fragmentedPairs(pathReports, args);
  const warnings = buildWarnings(pathReports, fragmentPairs, args);
  if (paths.length === 0) {
    warnings.push({
      code: "no_path_elements_found",
      severity: "medium",
      message: "no SVG path elements were found",
    });
  }
  const blockingWarnings = warnings.filter((warning) => warning.severity !== "info");
  const report = {
    schema_version: 1,
    input: inputPath,
    status: blockingWarnings.length > 0 ? "review_recommended" : "ok",
    canvas,
    parameters: {
      micro_segment_threshold_px: args.microSegmentThreshold,
      high_line_ratio: args.highLineRatio,
      max_command_count: args.maxCommandCount,
      fragment_gap_px: args.fragmentGap,
      flatten_tolerance_px: args.flattenTolerance,
    },
    path_count: paths.length,
    paths: pathReports,
    warnings,
    recommended_methods: [...new Set(warnings.flatMap((warning) => {
      if (warning.code === "high_line_command_ratio" || warning.code === "micro_segments_present") {
        return ["polish-svg-geometry", "semantic-curve-repair"];
      }
      if (warning.code === "possible_fragmented_contour") {
        return ["single-foreground-path-review"];
      }
      if (warning.code === "compound_path_detected") {
        return ["negative-space-review"];
      }
      return [];
    }))],
    semantic_note:
      "This is a geometry audit, not approval or repair. Use it to choose a route, then regenerate from the JSON spec and run verify.",
  };
  if (args.report) {
    await writeJson(resolve(args.report), report);
  }
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error.stack ?? error.message);
  process.exit(1);
});
