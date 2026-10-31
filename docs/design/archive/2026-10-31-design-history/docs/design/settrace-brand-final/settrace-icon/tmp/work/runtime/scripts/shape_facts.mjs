#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { PNG } from "pngjs";

function usage() {
  console.error(
    "Usage: node shape_facts.mjs --reference REF.png [--candidate CAND.png] [--out REPORT.json] [--background #RRGGBB|auto] [--mode color-distance|light-on-dark|dark-on-light|light-on-color] [--threshold 42] [--min-alpha 8] [--min-component-pixels 8] [--samples 9]",
  );
}

function parseArgs(argv) {
  const parsed = {
    background: "auto",
    mode: "color-distance",
    threshold: 42,
    minAlpha: 8,
    minComponentPixels: 8,
    samples: 9,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];
    if (arg === "--reference") {
      parsed.reference = next;
      index += 1;
    } else if (arg === "--candidate") {
      parsed.candidate = next;
      index += 1;
    } else if (arg === "--out") {
      parsed.out = next;
      index += 1;
    } else if (arg === "--background") {
      parsed.background = next;
      index += 1;
    } else if (arg === "--mode") {
      parsed.mode = next;
      index += 1;
    } else if (arg === "--threshold") {
      parsed.threshold = Number(next);
      index += 1;
    } else if (arg === "--min-alpha") {
      parsed.minAlpha = Number(next);
      index += 1;
    } else if (arg === "--min-component-pixels") {
      parsed.minComponentPixels = Number(next);
      index += 1;
    } else if (arg === "--samples") {
      parsed.samples = Number(next);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.reference) {
    throw new Error("--reference is required");
  }
  if (!["color-distance", "light-on-dark", "dark-on-light", "light-on-color"].includes(parsed.mode)) {
    throw new Error("--mode must be color-distance, light-on-dark, dark-on-light, or light-on-color");
  }
  for (const [name, value] of [
    ["--threshold", parsed.threshold],
    ["--min-alpha", parsed.minAlpha],
    ["--min-component-pixels", parsed.minComponentPixels],
    ["--samples", parsed.samples],
  ]) {
    if (!Number.isFinite(value)) {
      throw new Error(`${name} must be a finite number`);
    }
  }
  if (parsed.threshold < 0 || parsed.threshold > 255) {
    throw new Error("--threshold must be between 0 and 255");
  }
  if (parsed.minAlpha < 0 || parsed.minAlpha > 255) {
    throw new Error("--min-alpha must be between 0 and 255");
  }
  if (!Number.isInteger(parsed.minComponentPixels) || parsed.minComponentPixels < 1) {
    throw new Error("--min-component-pixels must be a positive integer");
  }
  if (!Number.isInteger(parsed.samples) || parsed.samples < 3 || parsed.samples > 25) {
    throw new Error("--samples must be an integer from 3 to 25");
  }
  return parsed;
}

function parseHexColor(value) {
  const match = /^#?([0-9a-fA-F]{6})$/.exec(String(value).trim());
  if (!match) {
    throw new Error(`expected 6-digit hex color, got: ${value}`);
  }
  const hex = match[1].toUpperCase();
  return {
    rgb: [
      Number.parseInt(hex.slice(0, 2), 16),
      Number.parseInt(hex.slice(2, 4), 16),
      Number.parseInt(hex.slice(4, 6), 16),
    ],
    hex: `#${hex}`,
    source: "explicit",
  };
}

async function decodePng(path) {
  const bytes = await readFile(path);
  const png = PNG.sync.read(bytes);
  return {
    path: resolve(path),
    width: png.width,
    height: png.height,
    data: png.data,
  };
}

function quantizedKey(data, offset) {
  const r = Math.round(data[offset] / 16);
  const g = Math.round(data[offset + 1] / 16);
  const b = Math.round(data[offset + 2] / 16);
  return `${r},${g},${b}`;
}

function estimateBackground(image, minAlpha) {
  const bins = new Map();
  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const offset = (y * image.width + x) * 4;
      if (image.data[offset + 3] < minAlpha) {
        continue;
      }
      const key = quantizedKey(image.data, offset);
      const bin = bins.get(key) ?? { count: 0, r: 0, g: 0, b: 0 };
      bin.count += 1;
      bin.r += image.data[offset];
      bin.g += image.data[offset + 1];
      bin.b += image.data[offset + 2];
      bins.set(key, bin);
    }
  }
  if (bins.size === 0) {
    throw new Error("cannot estimate background from a fully transparent image");
  }
  const best = [...bins.values()].sort((a, b) => b.count - a.count)[0];
  const rgb = [
    Math.round(best.r / best.count),
    Math.round(best.g / best.count),
    Math.round(best.b / best.count),
  ];
  return {
    rgb,
    hex: rgbToHex(rgb),
    source: "auto-dominant-quantized-color",
  };
}

function rgbToHex(rgb) {
  return `#${rgb.map((value) => value.toString(16).padStart(2, "0")).join("").toUpperCase()}`;
}

function colorDistance(data, offset, background) {
  const dr = data[offset] - background[0];
  const dg = data[offset + 1] - background[1];
  const db = data[offset + 2] - background[2];
  return Math.sqrt(dr * dr + dg * dg + db * db);
}

function luminance(data, offset) {
  return 0.2126 * data[offset] + 0.7152 * data[offset + 1] + 0.0722 * data[offset + 2];
}

function minChannel(data, offset) {
  return Math.min(data[offset], data[offset + 1], data[offset + 2]);
}

function foregroundScore(image, offset, args, background) {
  if (args.mode === "light-on-dark") {
    return luminance(image.data, offset);
  }
  if (args.mode === "dark-on-light") {
    return 255 - luminance(image.data, offset);
  }
  if (args.mode === "light-on-color") {
    return minChannel(image.data, offset);
  }
  return colorDistance(image.data, offset, background);
}

function buildMask(image, args, background) {
  const mask = new Uint8Array(image.width * image.height);
  let visible = 0;
  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const index = y * image.width + x;
      const offset = index * 4;
      if (image.data[offset + 3] >= args.minAlpha && foregroundScore(image, offset, args, background.rgb) >= args.threshold) {
        mask[index] = 1;
        visible += 1;
      }
    }
  }
  return { mask, visible };
}

function bboxFromStats(stats) {
  return {
    min_x: stats.minX,
    min_y: stats.minY,
    max_x: stats.maxX,
    max_y: stats.maxY,
    width: stats.maxX - stats.minX + 1,
    height: stats.maxY - stats.minY + 1,
  };
}

function round2(value) {
  return Number(value.toFixed(2));
}

function connectedComponents(mask, width, height, minPixels) {
  const visited = new Uint8Array(mask.length);
  const queue = new Int32Array(mask.length);
  const components = [];

  for (let start = 0; start < mask.length; start += 1) {
    if (!mask[start] || visited[start]) {
      continue;
    }
    let head = 0;
    let tail = 0;
    const pixels = [];
    const stats = {
      minX: width,
      minY: height,
      maxX: -1,
      maxY: -1,
      sumX: 0,
      sumY: 0,
    };
    visited[start] = 1;
    queue[tail] = start;
    tail += 1;
    while (head < tail) {
      const current = queue[head];
      head += 1;
      pixels.push(current);
      const x = current % width;
      const y = Math.floor(current / width);
      stats.minX = Math.min(stats.minX, x);
      stats.minY = Math.min(stats.minY, y);
      stats.maxX = Math.max(stats.maxX, x);
      stats.maxY = Math.max(stats.maxY, y);
      stats.sumX += x;
      stats.sumY += y;
      if (x > 0) tail = enqueue(current - 1, mask, visited, queue, tail);
      if (x < width - 1) tail = enqueue(current + 1, mask, visited, queue, tail);
      if (y > 0) tail = enqueue(current - width, mask, visited, queue, tail);
      if (y < height - 1) tail = enqueue(current + width, mask, visited, queue, tail);
    }
    if (pixels.length >= minPixels) {
      components.push({ pixels, stats });
    }
  }

  return components.sort((a, b) => b.pixels.length - a.pixels.length);
}

function enqueue(index, mask, visited, queue, tail) {
  if (mask[index] && !visited[index]) {
    visited[index] = 1;
    queue[tail] = index;
    return tail + 1;
  }
  return tail;
}

function detectHoles(component, width, height) {
  const bbox = bboxFromStats(component.stats);
  const boxWidth = bbox.width;
  const boxHeight = bbox.height;
  const componentMask = new Uint8Array(boxWidth * boxHeight);
  for (const pixelIndex of component.pixels) {
    const x = pixelIndex % width;
    const y = Math.floor(pixelIndex / width);
    componentMask[(y - bbox.min_y) * boxWidth + (x - bbox.min_x)] = 1;
  }

  const visited = new Uint8Array(componentMask.length);
  const queue = new Int32Array(componentMask.length);
  const holes = [];

  for (let start = 0; start < componentMask.length; start += 1) {
    if (componentMask[start] || visited[start]) {
      continue;
    }
    let head = 0;
    let tail = 0;
    let touchesEdge = false;
    const stats = {
      minX: boxWidth,
      minY: boxHeight,
      maxX: -1,
      maxY: -1,
      count: 0,
      sumX: 0,
      sumY: 0,
    };
    visited[start] = 1;
    queue[tail] = start;
    tail += 1;
    while (head < tail) {
      const current = queue[head];
      head += 1;
      const localX = current % boxWidth;
      const localY = Math.floor(current / boxWidth);
      if (localX === 0 || localY === 0 || localX === boxWidth - 1 || localY === boxHeight - 1) {
        touchesEdge = true;
      }
      stats.minX = Math.min(stats.minX, localX);
      stats.minY = Math.min(stats.minY, localY);
      stats.maxX = Math.max(stats.maxX, localX);
      stats.maxY = Math.max(stats.maxY, localY);
      stats.count += 1;
      stats.sumX += localX + bbox.min_x;
      stats.sumY += localY + bbox.min_y;
      if (localX > 0) tail = enqueueHole(current - 1, componentMask, visited, queue, tail);
      if (localX < boxWidth - 1) tail = enqueueHole(current + 1, componentMask, visited, queue, tail);
      if (localY > 0) tail = enqueueHole(current - boxWidth, componentMask, visited, queue, tail);
      if (localY < boxHeight - 1) tail = enqueueHole(current + boxWidth, componentMask, visited, queue, tail);
    }
    if (!touchesEdge) {
      holes.push({
        area_pixels: stats.count,
        centroid: {
          x: round2(stats.sumX / stats.count),
          y: round2(stats.sumY / stats.count),
        },
        bbox: {
          min_x: stats.minX + bbox.min_x,
          min_y: stats.minY + bbox.min_y,
          max_x: stats.maxX + bbox.min_x,
          max_y: stats.maxY + bbox.min_y,
          width: stats.maxX - stats.minX + 1,
          height: stats.maxY - stats.minY + 1,
        },
      });
    }
  }
  return holes.sort((a, b) => b.area_pixels - a.area_pixels);
}

function enqueueHole(index, componentMask, visited, queue, tail) {
  if (!componentMask[index] && !visited[index]) {
    visited[index] = 1;
    queue[tail] = index;
    return tail + 1;
  }
  return tail;
}

function sampleCoordinates(size, count) {
  const coords = [];
  for (let index = 1; index <= count; index += 1) {
    coords.push(Math.round((index * size) / (count + 1)));
  }
  return [...new Set(coords.map((coord) => Math.max(0, Math.min(size - 1, coord))))];
}

function intervalsForHorizontal(mask, width, y) {
  const intervals = [];
  let start = null;
  for (let x = 0; x < width; x += 1) {
    const foreground = Boolean(mask[y * width + x]);
    if (foreground && start == null) {
      start = x;
    }
    if ((!foreground || x === width - 1) && start != null) {
      intervals.push([start, foreground && x === width - 1 ? x : x - 1]);
      start = null;
    }
  }
  return intervals;
}

function intervalsForVertical(mask, width, height, x) {
  const intervals = [];
  let start = null;
  for (let y = 0; y < height; y += 1) {
    const foreground = Boolean(mask[y * width + x]);
    if (foreground && start == null) {
      start = y;
    }
    if ((!foreground || y === height - 1) && start != null) {
      intervals.push([start, foreground && y === height - 1 ? y : y - 1]);
      start = null;
    }
  }
  return intervals;
}

function scanlines(mask, width, height, sampleCount) {
  return {
    horizontal: sampleCoordinates(height, sampleCount).map((y) => ({
      y,
      intervals: intervalsForHorizontal(mask, width, y),
    })),
    vertical: sampleCoordinates(width, sampleCount).map((x) => ({
      x,
      intervals: intervalsForVertical(mask, width, height, x),
    })),
  };
}

function analyzeImage(image, args, background) {
  const { mask, visible } = buildMask(image, args, background);
  const rawComponents = connectedComponents(mask, image.width, image.height, args.minComponentPixels);
  const components = rawComponents.map((component, index) => {
    const holes = detectHoles(component, image.width, image.height);
    const bbox = bboxFromStats(component.stats);
    const touchesCanvasEdge = bbox.min_x === 0 || bbox.min_y === 0 || bbox.max_x === image.width - 1 || bbox.max_y === image.height - 1;
    return {
      id: `component-${index + 1}`,
      area_pixels: component.pixels.length,
      area_ratio: round2(component.pixels.length / (image.width * image.height)),
      touches_canvas_edge: touchesCanvasEdge,
      role_hint: touchesCanvasEdge ? "edge_or_canvas_artifact" : "interior_foreground_candidate",
      centroid: {
        x: round2(component.stats.sumX / component.pixels.length),
        y: round2(component.stats.sumY / component.pixels.length),
      },
      bbox,
      holes: {
        count: holes.length,
        items: holes,
      },
    };
  });
  const interiorMask = new Uint8Array(mask.length);
  rawComponents.forEach((component, index) => {
    if (components[index].touches_canvas_edge) {
      return;
    }
    for (const pixelIndex of component.pixels) {
      interiorMask[pixelIndex] = 1;
    }
  });
  return {
    width: image.width,
    height: image.height,
    path: image.path,
    mask: {
      mode: args.mode,
      threshold: args.threshold,
      min_alpha: args.minAlpha,
      background,
      foreground_pixels: visible,
      foreground_ratio: round2(visible / (image.width * image.height)),
    },
    components: {
      count: components.length,
      interior_count: components.filter((component) => !component.touches_canvas_edge).length,
      edge_touching_count: components.filter((component) => component.touches_canvas_edge).length,
      items: components,
    },
    scanlines: scanlines(mask, image.width, image.height, args.samples),
    interior_scanlines: scanlines(interiorMask, image.width, image.height, args.samples),
  };
}

function compareReports(reference, candidate) {
  const refPrimary = reference.components.items[0] ?? null;
  const candPrimary = candidate.components.items[0] ?? null;
  const comparison = {
    diagnostic_only: true,
    not_a_completion_gate: true,
    component_count_delta: {
      reference: reference.components.count,
      candidate: candidate.components.count,
      delta: candidate.components.count - reference.components.count,
    },
    interior_component_count_delta: {
      reference: reference.components.interior_count,
      candidate: candidate.components.interior_count,
      delta: candidate.components.interior_count - reference.components.interior_count,
    },
    edge_touching_component_count_delta: {
      reference: reference.components.edge_touching_count,
      candidate: candidate.components.edge_touching_count,
      delta: candidate.components.edge_touching_count - reference.components.edge_touching_count,
    },
    primary_component: refPrimary && candPrimary ? compareComponents(refPrimary, candPrimary) : null,
    scanline_drift: {
      horizontal: compareScanlineSet(reference.scanlines.horizontal, candidate.scanlines.horizontal),
      vertical: compareScanlineSet(reference.scanlines.vertical, candidate.scanlines.vertical),
    },
    interior_scanline_drift: {
      horizontal: compareScanlineSet(reference.interior_scanlines.horizontal, candidate.interior_scanlines.horizontal),
      vertical: compareScanlineSet(reference.interior_scanlines.vertical, candidate.interior_scanlines.vertical),
    },
    risk_notes: [
      "Shape facts are diagnostic and can reject or localize drift, but they do not prove brand identity or final Icon Composer rendering.",
      "Material, glow, shadow, bevel, antialiasing, text, mascot details, and dense brand geometry may be misclassified by mask thresholds.",
    ],
  };
  return {
    summary: summarizeComparison(comparison),
    ...comparison,
  };
}

function summarizeComparison(comparison) {
  const summary = {
    component_counts: {
      all_delta: comparison.component_count_delta.delta,
      interior_delta: comparison.interior_component_count_delta.delta,
      edge_touching_delta: comparison.edge_touching_component_count_delta.delta,
    },
    primary_component: comparison.primary_component
      ? {
          centroid_distance_px: comparison.primary_component.centroid_distance_px,
          bbox_delta: comparison.primary_component.bbox_delta,
          hole_count_delta: comparison.primary_component.hole_count_delta.delta,
        }
      : null,
    scanline_drift: {
      horizontal: summarizeScanlineDrift(comparison.scanline_drift.horizontal),
      vertical: summarizeScanlineDrift(comparison.scanline_drift.vertical),
    },
    interior_scanline_drift: {
      horizontal: summarizeScanlineDrift(comparison.interior_scanline_drift.horizontal),
      vertical: summarizeScanlineDrift(comparison.interior_scanline_drift.vertical),
    },
    interpretation: ["shape_facts_are_diagnostic_only"],
  };

  if (Math.abs(summary.component_counts.interior_delta) > 0) {
    summary.interpretation.push("interior_component_count_changed");
  }
  if (Math.abs(summary.component_counts.edge_touching_delta) > 0) {
    summary.interpretation.push("edge_or_canvas_artifact_count_changed");
  }
  const interiorMax = Math.max(
    summary.interior_scanline_drift.horizontal.max_endpoint_delta_px,
    summary.interior_scanline_drift.vertical.max_endpoint_delta_px,
  );
  if (interiorMax > 24) {
    summary.interpretation.push("interior_shape_edges_need_review");
  }
  if (summary.primary_component?.centroid_distance_px > 12) {
    summary.interpretation.push("primary_component_centroid_shifted");
  }
  return summary;
}

function summarizeScanlineDrift(drift) {
  return {
    max_endpoint_delta_px: drift.max_endpoint_delta_px,
    interval_count_mismatches: drift.interval_count_mismatches,
  };
}

function compareComponents(reference, candidate) {
  const bboxDelta = {};
  for (const key of ["min_x", "min_y", "max_x", "max_y", "width", "height"]) {
    bboxDelta[key] = candidate.bbox[key] - reference.bbox[key];
  }
  const dx = candidate.centroid.x - reference.centroid.x;
  const dy = candidate.centroid.y - reference.centroid.y;
  return {
    area_delta_pixels: candidate.area_pixels - reference.area_pixels,
    area_ratio_delta: round2(candidate.area_ratio - reference.area_ratio),
    centroid_delta: {
      x: round2(dx),
      y: round2(dy),
    },
    centroid_distance_px: round2(Math.sqrt(dx * dx + dy * dy)),
    bbox_delta: bboxDelta,
    hole_count_delta: {
      reference: reference.holes.count,
      candidate: candidate.holes.count,
      delta: candidate.holes.count - reference.holes.count,
    },
  };
}

function compareScanlineSet(referenceLines, candidateLines) {
  let count_mismatches = 0;
  let maxEndpointDelta = 0;
  const lines = referenceLines.map((referenceLine, index) => {
    const candidateLine = candidateLines[index];
    const compared = compareIntervals(referenceLine.intervals, candidateLine.intervals);
    if (compared.count_delta !== 0) {
      count_mismatches += 1;
    }
    maxEndpointDelta = Math.max(maxEndpointDelta, compared.max_endpoint_delta_px);
    return {
      coordinate: referenceLine.y ?? referenceLine.x,
      reference_intervals: referenceLine.intervals,
      candidate_intervals: candidateLine.intervals,
      ...compared,
    };
  });
  return {
    max_endpoint_delta_px: maxEndpointDelta,
    interval_count_mismatches: count_mismatches,
    lines,
  };
}

function compareIntervals(referenceIntervals, candidateIntervals) {
  const common = Math.min(referenceIntervals.length, candidateIntervals.length);
  let maxEndpointDelta = 0;
  for (let index = 0; index < common; index += 1) {
    maxEndpointDelta = Math.max(
      maxEndpointDelta,
      Math.abs(candidateIntervals[index][0] - referenceIntervals[index][0]),
      Math.abs(candidateIntervals[index][1] - referenceIntervals[index][1]),
    );
  }
  return {
    count_delta: candidateIntervals.length - referenceIntervals.length,
    max_endpoint_delta_px: maxEndpointDelta,
  };
}

async function writeJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const referenceImage = await decodePng(args.reference);
  const background = args.background === "auto" ? estimateBackground(referenceImage, args.minAlpha) : parseHexColor(args.background);
  const reference = analyzeImage(referenceImage, args, background);
  const report = {
    schema_version: 1,
    purpose: "diagnostic shape facts for app-icon semantic SVG authoring and repair; not an automatic SVG generator or completion gate",
    reference,
  };

  if (args.candidate) {
    const candidateImage = await decodePng(args.candidate);
    if (candidateImage.width !== referenceImage.width || candidateImage.height !== referenceImage.height) {
      throw new Error("candidate image must have the same dimensions as reference image");
    }
    const candidate = analyzeImage(candidateImage, args, background);
    report.candidate = candidate;
    report.comparison = compareReports(reference, candidate);
  }

  if (args.out) {
    await writeJson(resolve(args.out), report);
  }
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error instanceof Error ? error.stack : String(error));
  process.exit(1);
});
