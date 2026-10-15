#!/usr/bin/env node
import { constants, lstatSync, realpathSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { open, readFile, rename, rm } from "node:fs/promises";
import { basename, dirname, relative, resolve } from "node:path";
import { PNG } from "pngjs";
import { APPLE_EXPORT_SCALE, appleExportProfilesForTargets } from "./lib/apple_export_profiles.mjs";
import {
  PNG_FALLBACK_CATEGORIES,
  PNG_FALLBACK_ROUTES,
  hasFullCanvasRoundedRect,
  isBackgroundLikeLayerName,
  isComplexBackgroundDecision,
  isVaguePngFallbackReason,
  previewOnlyBackgroundConsistency,
  stableJson,
  validateFill,
} from "./lib/icon_contract.mjs";

const DEFAULT_CANVAS = 1024;
const DEFAULT_REFERENCE_MEAN_DELTA = 9.99;
const STRICT_REPAIR_RANGE_UPPER = 15;
const LOCAL_SAMPLE_RADIUS = 4;
const DIAGNOSTIC_TILE_COLUMNS = 8;
const DIAGNOSTIC_TILE_ROWS = 8;
const HIGH_DELTA_THRESHOLD = 25;
const VISUAL_DELTA_GATE_PCT_GT_25 = 1.5;
const VISUAL_DELTA_GATE_PCT_GT_50 = 1.0;
const VISUAL_DELTA_GATE_BROAD_MEDIUM_PCT_GT_25 = 5.0;
const VISUAL_DELTA_GATE_BROAD_MEDIUM_MIN_HIGH_DELTA_PIXELS = 50000;
const VISUAL_DELTA_GATE_MIN_HIGH_DELTA_PIXELS = 10000;
const VISUAL_DELTA_GATE_FRAME_GUTTER_RATIO = 80 / DEFAULT_CANVAS;
const VISUAL_DELTA_GATE_FRAME_DOMINATED_SHARE = 60;
const VISUAL_DELTA_GATE_FRAME_MIN_EDGES = 3;
const PNG_LAYER_EDGE_GUTTER = 8;
const LOCAL_SAMPLE_GATE_MEAN_DELTA = 96;
const LOCAL_SAMPLE_GATE_P95_DELTA = 220;
const SIDE_BY_SIDE_GUTTER = 96;
const LOCAL_SAMPLE_POINTS = [
  ["top_left", "top left", 0.25, 0.25],
  ["top", "top", 0.5, 0.25],
  ["top_right", "top right", 0.75, 0.25],
  ["left", "left", 0.25, 0.5],
  ["center", "center", 0.5, 0.5],
  ["right", "right", 0.75, 0.5],
  ["bottom_left", "bottom left", 0.25, 0.75],
  ["bottom", "bottom", 0.5, 0.75],
  ["bottom_right", "bottom right", 0.75, 0.75],
];
const ALLOWED_SOURCE_VECTOR_PROVENANCE = new Set([
  "user-provided",
  "project-local",
  "generated-in-task",
  "official-user-approved",
]);
const ALLOWED_TARGET_PLATFORMS = new Set(["iOS", "iPadOS", "macOS", "watchOS"]);
const ALLOWED_DELIVERABLE_TYPES = new Set(["icon-composer-package", "source-package", "rendered-review-assets"]);

function usage() {
  console.error("Usage: node scripts/verify_icon_package.mjs --out OUT [--reference PNG] [--max-mean-delta N]");
  console.error(`When --reference is provided without --max-mean-delta, the default target is ${DEFAULT_REFERENCE_MEAN_DELTA}.`);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--out") {
      parsed.out = next;
      i += 1;
    } else if (arg === "--reference") {
      parsed.reference = next;
      i += 1;
    } else if (arg === "--max-mean-delta") {
      const value = Number(next);
      if (!Number.isFinite(value) || value < 0) {
        throw new Error("--max-mean-delta must be a non-negative number");
      }
      parsed.maxMeanDelta = value;
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.out) {
    throw new Error("--out is required");
  }
  if (parsed.maxMeanDelta != null && !parsed.reference) {
    throw new Error("--max-mean-delta requires --reference");
  }
  if (parsed.reference && parsed.maxMeanDelta == null) {
    parsed.maxMeanDelta = DEFAULT_REFERENCE_MEAN_DELTA;
  }
  return parsed;
}

function inside(root, path) {
  const rootStat = lstatSync(root);
  if (rootStat.isSymbolicLink()) {
    throw new Error(`refusing symlink output directory: ${root}`);
  }
  if (!rootStat.isDirectory()) {
    throw new Error(`output path must be a directory: ${root}`);
  }
  const full = resolve(root, path);
  const rel = relative(root, full);
  if (rel.startsWith("..") || rel === "") {
    throw new Error(`path escapes output directory: ${path}`);
  }
  let stat = null;
  try {
    stat = lstatSync(full);
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }
  if (stat) {
    if (stat.isSymbolicLink()) {
      throw new Error(`refusing symlink inside output directory: ${full}`);
    }
    const canonicalRoot = realpathSync(root);
    const canonicalPath = realpathSync(full);
    const canonicalRel = relative(canonicalRoot, canonicalPath);
    if (canonicalRel.startsWith("..") || canonicalRel === "") {
      throw new Error(`resolved path escapes output directory: ${path}`);
    }
  }
  return full;
}

function writeInside(root, path) {
  const full = inside(root, path);
  const canonicalRoot = realpathSync(root);
  const parent = dirname(full);
  const parentStat = lstatSync(parent);
  if (parentStat.isSymbolicLink()) {
    throw new Error(`refusing symlink write directory: ${parent}`);
  }
  const canonicalParent = realpathSync(parent);
  const parentRel = relative(canonicalRoot, canonicalParent);
  if (parentRel.startsWith("..")) {
    throw new Error(`write path escapes output directory: ${path}`);
  }
  return full;
}

async function writeFileInside(root, path, data, encoding = null) {
  const full = writeInside(root, path);
  const temporary = writeInside(root, resolve(dirname(full), `.${basename(full)}.tmp-${randomUUID()}`));
  const flags = constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | (constants.O_NOFOLLOW ?? 0);
  let handle = null;
  try {
    handle = await open(temporary, flags, 0o666);
    await handle.writeFile(data, encoding ? { encoding } : undefined);
    await handle.close();
    handle = null;
    writeInside(root, full);
    await rename(temporary, full);
  } finally {
    await handle?.close();
    await rm(temporary, { force: true });
  }
  return full;
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

async function readStyleReport(outDir) {
  const candidates = [inside(outDir, "style-report.json"), inside(outDir, "tmp/reports/style-report.json")];
  for (const path of candidates) {
    const report = await readOptionalJson(path);
    if (report) {
      return { styleReport: report, styleReportPath: path };
    }
  }
  throw new Error("style-report.json is missing at output root or tmp/reports");
}

function outputRelativePath(root, path) {
  const rel = relative(root, path).split("\\").join("/");
  return rel || ".";
}

function validateImportedSvg(asset, svg, failures) {
  const banned = [
    [/<text\b/i, "<text>"],
    [/<image\b/i, "<image>"],
    [/<filter\b/i, "<filter>"],
    [/\sfilter\s*=/i, "filter attribute"],
    [/<clipPath\b/i, "<clipPath>"],
    [/\sclip-path\s*=/i, "clip-path attribute"],
    [/<mask\b/i, "<mask>"],
    [/\smask\s*=/i, "mask attribute"],
    [/<foreignObject\b/i, "<foreignObject>"],
    [/<script\b/i, "<script>"],
    [/\s(?:xlink:)?href\s*=\s*["'](?:https?:|file:|data:|[^#])/i, "external href"],
  ];
  for (const [pattern, label] of banned) {
    if (pattern.test(svg)) {
      failures.push(`${asset} cannot be imported as Icon Composer SVG because it contains ${label}`);
    }
  }
  if (hasFullCanvasRoundedRect(svg, DEFAULT_CANVAS)) {
    failures.push(`${asset} contains a full-canvas rounded rect; keep app masks out of Icon Composer SVG assets`);
  }
}

function countSvgPrimitives(svg) {
  return (svg.match(/<(path|rect|circle|ellipse|polygon|polyline|line)\b/gi) ?? []).length;
}

function opacityAttributes(svg) {
  const matches = [];
  for (const match of svg.matchAll(/\s(?:opacity|fill-opacity|stroke-opacity)\s*=\s*["']([^"']+)["']/gi)) {
    const value = Number(match[1]);
    if (!Number.isFinite(value) || value < 1) {
      matches.push(match[0].trim());
    }
  }
  return matches;
}

function styleDeclarations(svg) {
  return [...String(svg).matchAll(/\sstyle\s*=\s*["']([^"']*)["']/gi)].map((match) => match[1]);
}

function stylePropertyValues(svg, property) {
  const values = [];
  for (const style of styleDeclarations(svg)) {
    for (const declaration of style.split(";")) {
      const separator = declaration.indexOf(":");
      if (separator === -1) {
        continue;
      }
      const name = declaration.slice(0, separator).trim().toLowerCase();
      if (name === property) {
        values.push(declaration.slice(separator + 1).trim());
      }
    }
  }
  return values;
}

function hasStyleStroke(svg) {
  return stylePropertyValues(svg, "stroke").some((value) => value && !/^none\b/i.test(value));
}

function styleOpacityValues(svg) {
  return ["opacity", "fill-opacity", "stroke-opacity"].flatMap((property) => stylePropertyValues(svg, property));
}

function riskyOpacityValues(values) {
  return values.filter((value) => {
    const numeric = Number(value);
    return !Number.isFinite(numeric) || numeric < 1;
  });
}

function hasFillNoneStrokeStyle(svg) {
  return styleDeclarations(svg).some((style) => {
    const fill = style
      .split(";")
      .map((declaration) => declaration.trim())
      .find((declaration) => /^fill\s*:/i.test(declaration));
    const stroke = style
      .split(";")
      .map((declaration) => declaration.trim())
      .find((declaration) => /^stroke\s*:/i.test(declaration));
    return Boolean(fill && /:\s*none\b/i.test(fill) && stroke && !/:\s*none\b/i.test(stroke));
  });
}

function inspectImportedSvgMaterial(asset, svg, decision) {
  if (isBackgroundLikeLayerName(decision?.layer)) {
    return null;
  }
  const indicators = [];
  const primitiveCount = countSvgPrimitives(svg);
  const hasStroke = /\sstroke\s*=\s*["'](?!none["'\s>])[^"']+["']/i.test(svg) || hasStyleStroke(svg);
  const hasFillNoneStroke = /<[^>]*\bfill\s*=\s*["']none["'][^>]*\bstroke\s*=/i.test(svg)
    || /<[^>]*\bstroke\s*=[^>]*\bfill\s*=\s*["']none["']/i.test(svg)
    || hasFillNoneStrokeStyle(svg);
  const opacities = [...opacityAttributes(svg), ...riskyOpacityValues(styleOpacityValues(svg))];
  const hasGradient = /<(linearGradient|radialGradient)\b/i.test(svg) || /fill\s*=\s*["']url\(#/i.test(svg) || stylePropertyValues(svg, "fill").some((value) => /^url\(#/i.test(value));
  const hasPattern = /<pattern\b/i.test(svg);
  const materialIdOrClass = /\b(id|class)\s*=\s*["'][^"']*(glass|highlight|shine|sheen|bevel|shadow|glow|specular|edge|rim|blur)[^"']*["']/i.test(svg);

  if (hasStroke) {
    indicators.push("stroke_attribute");
  }
  if (hasFillNoneStroke) {
    indicators.push("fill_none_stroke");
  }
  if (opacities.length > 0) {
    indicators.push("opacity_attribute");
  }
  if (hasGradient && (primitiveCount > 1 || materialIdOrClass)) {
    indicators.push("gradient_material_risk");
  }
  if (hasPattern) {
    indicators.push("pattern_material_risk");
  }
  if (materialIdOrClass) {
    indicators.push("material_named_id_or_class");
  }

  if (indicators.length === 0) {
    return null;
  }
  return {
    asset,
    layer: decision?.layer ?? null,
    source_layer: decision?.source_layer ?? null,
    primitive_count: primitiveCount,
    indicators: [...new Set(indicators)],
    recommendation:
      "Imported foreground SVG should be a clean base shape for Icon Composer; remove baked highlight/bevel/glass/shadow material, or document a deliberate reviewed exception.",
  };
}

function readPng(bytes, label, failures) {
  try {
    return PNG.sync.read(bytes);
  } catch (error) {
    failures.push(`${label} is not a readable PNG: ${error instanceof Error ? error.message : String(error)}`);
    return null;
  }
}

function sameStringSet(actual, expected) {
  return (
    Array.isArray(actual) &&
    actual.length === expected.length &&
    new Set(actual).size === actual.length &&
    [...actual].sort().every((value, index) => value === [...expected].sort()[index])
  );
}

async function validateAppleExports(outDir, styleReport, failures) {
  const appleExports = styleReport.apple_exports;
  const deliverableType = styleReport.deliverable_type;
  const targetPlatforms = styleReport.target_platforms;
  const problems = [];
  const appleTargets = Array.isArray(targetPlatforms)
    ? targetPlatforms.filter((platform) => ALLOWED_TARGET_PLATFORMS.has(platform))
    : [];

  const targetPlatformsValid =
    Array.isArray(targetPlatforms) &&
    new Set(targetPlatforms).size === targetPlatforms.length &&
    new Set(appleTargets).size === appleTargets.length;
  if (!targetPlatformsValid) {
    problems.push("style-report target_platforms must contain unique platform labels");
  }
  if (!ALLOWED_DELIVERABLE_TYPES.has(deliverableType)) {
    problems.push("style-report deliverable_type must be icon-composer-package, source-package, or rendered-review-assets");
  }
  if (!appleExports || typeof appleExports !== "object" || Array.isArray(appleExports)) {
    problems.push("style-report apple_exports must be an object with generated or skipped status");
    failures.push(...problems.map((problem) => `Apple export validation: ${problem}`));
    return {
      status: "invalid",
      platforms: [],
      files: [],
      problems,
    };
  }

  const expectedProfiles = targetPlatformsValid ? appleExportProfilesForTargets(appleTargets) : [];
  const expectedPlatforms = expectedProfiles.map((profile) => profile.platform);
  const expectedFiles = expectedProfiles.flatMap((profile) =>
    profile.renditions.map((rendition) => `apple/${profile.platform}/${rendition.name}.png`),
  );
  const validateProfileMetadata = () => {
    if (appleExports?.scale !== APPLE_EXPORT_SCALE) {
      problems.push(`apple_exports.scale must be ${APPLE_EXPORT_SCALE}`);
    }
    if (!sameStringSet(appleExports?.platforms, expectedPlatforms)) {
      problems.push(`apple_exports.platforms must match requested export profiles: ${expectedPlatforms.join(", ")}`);
    }
    if (!Array.isArray(appleExports?.profiles) || appleExports.profiles.length !== expectedProfiles.length) {
      problems.push("apple_exports.profiles must contain one entry for every requested export profile");
      return;
    }
    for (const expected of expectedProfiles) {
      const actual = appleExports.profiles.find((profile) => profile?.platform === expected.platform);
      const expectedRenditions = expected.renditions.map((rendition) => rendition.name);
      if (
        !actual ||
        actual.width !== expected.width ||
        actual.height !== expected.height ||
        !sameStringSet(actual.renditions, expectedRenditions)
      ) {
        problems.push(
          `${expected.platform} profile must be ${expected.width}x${expected.height} with renditions: ${expectedRenditions.join(", ")}`,
        );
      }
    }
  };

  if (deliverableType === "source-package") {
    validateProfileMetadata();
    if (appleExports?.status !== "skipped" || appleExports?.reason !== "not-requested-for-source-package") {
      problems.push("source-package apple_exports must be skipped with reason not-requested-for-source-package");
    }
    if (!sameStringSet(appleExports?.files, [])) {
      problems.push("source-package must not claim generated Apple platform render files");
    }
    failures.push(...problems.map((problem) => `Apple export validation: ${problem}`));
    return {
      status: problems.length > 0 ? "invalid" : "not_requested",
      platforms: [],
      files: [],
      problems,
    };
  }
  if (appleExports?.status !== "generated") {
    if (appleExports != null) {
      validateProfileMetadata();
      if (appleExports.status !== "skipped" || typeof appleExports.reason !== "string" || appleExports.reason.trim() === "") {
        problems.push("apple_exports must be generated or skipped with a non-empty reason");
      }
      if (!sameStringSet(appleExports.files, [])) {
        problems.push("skipped apple_exports must not list rendered files");
      }
    }
    failures.push(...problems.map((problem) => `Apple export validation: ${problem}`));
    return {
      status: problems.length > 0 ? "invalid" : "not_generated",
      platforms: [],
      files: [],
      problems,
    };
  }

  validateProfileMetadata();
  if (!sameStringSet(appleExports.files, expectedFiles)) {
    problems.push("apple_exports.files must contain every expected platform rendition exactly once");
  }

  const renderedFiles = [];
  for (const profile of expectedProfiles) {
    for (const rendition of profile.renditions) {
      const file = `apple/${profile.platform}/${rendition.name}.png`;
      try {
        const localFailures = [];
        const png = readPng(await readFile(inside(outDir, file)), file, localFailures);
        problems.push(...localFailures);
        if (png && (png.width !== profile.width || png.height !== profile.height)) {
          problems.push(`${file} must be ${profile.width}x${profile.height}, got ${png.width}x${png.height}`);
        }
        if (png) {
          renderedFiles.push({ file, width: png.width, height: png.height });
        }
      } catch (error) {
        problems.push(`${file} cannot be read safely: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  failures.push(...problems.map((problem) => `Apple export validation: ${problem}`));
  return {
    status: problems.length > 0 ? "invalid" : "valid",
    platforms: expectedPlatforms,
    files: expectedFiles,
    rendered_files: renderedFiles,
    problems,
  };
}

function isIdentitySensitiveReview(semanticReview) {
  const status = semanticReview?.status;
  const risk = semanticReview?.identity_risk;
  return Boolean(status) && (risk === "medium" || risk === "high" || status !== "exact-enough");
}

function isAcceptedApproximation(semanticReview) {
  return semanticReview?.status === "accepted-approximation" || semanticReview?.route === "accepted-approximation";
}

function normalizedDecision(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("_", "-");
}

function isAcceptedVisualDecision(visualReview) {
  return ["accepted", "approved", "accepted-approximation", "complete-candidate"].includes(normalizedDecision(visualReview?.decision));
}

function hasRecordedVisualAcceptance(visualReview) {
  const reviewer = String(visualReview?.reviewer ?? "").trim();
  const notes = String(visualReview?.notes ?? "").trim();
  const evidence = visualReview?.evidence;
  const hasEvidence = Array.isArray(evidence) ? evidence.some((item) => String(item).trim() !== "") : String(evidence ?? "").trim() !== "";
  return isAcceptedVisualDecision(visualReview) && reviewer !== "" && notes !== "" && hasEvidence;
}

function isIndependentOrHumanVisualReview(visualReview) {
  const reviewer = normalizedDecision(visualReview?.reviewer);
  const reviewerType = normalizedDecision(visualReview?.reviewer_type);
  const acceptedBy = normalizedDecision(visualReview?.accepted_by);
  return [reviewer, reviewerType, acceptedBy].some((value) =>
    ["user", "human", "independent-visual-review", "external-agent", "subagent-review"].includes(value) || value.includes("independent"),
  );
}

function isAcceptedIndependentVisualDecision(visualReview) {
  return hasRecordedVisualAcceptance(visualReview) && isIndependentOrHumanVisualReview(visualReview);
}

function hasAcceptanceEvidence(acceptance, visualReview) {
  if (!acceptance?.accepted_by || !acceptance?.evidence || !acceptance?.scope) {
    return false;
  }
  if (acceptance.accepted_by === "user" || acceptance.accepted_by === "human") {
    return true;
  }
  if (acceptance.accepted_by === "independent_visual_review") {
    return Boolean(isAcceptedVisualDecision(visualReview) && visualReview?.reviewer && (visualReview.evidence || visualReview.notes));
  }
  return false;
}

function hasHumanAcceptance(acceptance) {
  return acceptance?.accepted_by === "user" || acceptance?.accepted_by === "human";
}

function textEvidence(value) {
  if (Array.isArray(value)) {
    return value.map(textEvidence).join(" ");
  }
  if (value && typeof value === "object") {
    return Object.values(value).map(textEvidence).join(" ");
  }
  return String(value ?? "");
}

function hasWholeIconMaterialAcceptance(acceptance, visualReview) {
  const text = [
    acceptance?.scope,
    acceptance?.evidence,
    visualReview?.scope,
    visualReview?.evidence,
    visualReview?.notes,
    visualReview?.material_boundary,
  ]
    .map(textEvidence)
    .join(" ")
    .toLowerCase();
  const coversWholeIcon = /(whole[-\s]?icon|overall|full icon|entire icon|global likeness|整体|整图|全局|整个图标)/i.test(text);
  const coversMaterial = /(material|glass|liquid glass|highlight|bevel|glow|shadow|edge lighting|lighting|refraction|renderer|材质|玻璃|高光|阴影|边缘光|光照|渲染)/i.test(text);
  return coversWholeIcon && coversMaterial;
}

function isRejectedVisualDecision(visualReview) {
  return ["rejected", "not-candidate", "redesign-needed", "needs-source-vector", "needs-repair"].includes(
    normalizedDecision(visualReview?.decision),
  );
}

function optionalString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function nonEmptyStrings(value) {
  return Array.isArray(value) && value.length > 0 && value.every((item) => typeof item === "string" && item.trim() !== "");
}

function validateSourceAnalysisContract(sourceAnalysis, decisions = []) {
  if (sourceAnalysis == null) {
    return { status: "missing", problems: [] };
  }
  if (typeof sourceAnalysis !== "object" || Array.isArray(sourceAnalysis)) {
    return { status: "invalid", problems: ["source_analysis must be an object"] };
  }
  const problems = [];
  for (const field of ["must_preserve", "must_not_add", "acceptance_checks"]) {
    if (!nonEmptyStrings(sourceAnalysis[field])) {
      problems.push(`source_analysis.${field} must be a non-empty array of strings`);
    }
  }
  if (!Array.isArray(sourceAnalysis.components) || sourceAnalysis.components.length === 0) {
    problems.push("source_analysis.components must be a non-empty array");
  }
  const componentLayers = new Set();
  for (const [index, component] of (sourceAnalysis.components ?? []).entries()) {
    if (!component || typeof component !== "object" || Array.isArray(component)) {
      problems.push(`source_analysis.components[${index}] must be an object`);
      continue;
    }
    const id = typeof component.id === "string" ? component.id.trim() : "";
    const layer = typeof component.layer === "string" ? component.layer.trim() : "";
    const format = typeof component.format === "string" ? component.format.trim() : "";
    if (!id || !layer || !["svg", "png", "mixed", "not-imported"].includes(format)) {
      problems.push(`source_analysis.components[${index}] must include id, layer, and format`);
    }
    const sourceVector = optionalString(component.source_vector);
    if (sourceVector) {
      const sourceProvenance = optionalString(component.source_provenance);
      const alignmentBasis = optionalString(component.alignment_basis);
      if (!sourceProvenance || !ALLOWED_SOURCE_VECTOR_PROVENANCE.has(sourceProvenance)) {
        problems.push(
          `source_analysis.components[${index}].source_provenance must be one of ${[...ALLOWED_SOURCE_VECTOR_PROVENANCE].join(", ")} when source_vector is used`,
        );
      }
      if (/^https?:\/\//i.test(sourceVector) && sourceProvenance !== "official-user-approved") {
        problems.push(`source_analysis.components[${index}].source_vector uses a web URL without official-user-approved provenance`);
      }
      if (!alignmentBasis) {
        problems.push(`source_analysis.components[${index}].alignment_basis is required when source_vector is used`);
      }
    }
    if (layer) {
      componentLayers.add(layer);
    }
  }
  for (const decision of decisions) {
    if (decision?.layer && !componentLayers.has(decision.layer)) {
      problems.push(`source_analysis.components must include included layer "${decision.layer}"`);
    }
  }
  return {
    status: problems.length > 0 ? "invalid" : "valid",
    problems,
  };
}

function referencePixelStatus(referenceComparison, semanticReview) {
  if (!referenceComparison) {
    return "not_required";
  }
  if (referenceComparison.status !== "compared") {
    return referenceComparison.status;
  }
  if (referenceComparison.visual_delta_gate?.status === "failed" && !isAcceptedApproximation(semanticReview)) {
    return "failed_visual_delta";
  }
  if (referenceComparison.max_mean_delta != null && referenceComparison.mean_absolute_rgb_delta > referenceComparison.max_mean_delta) {
    if (isAcceptedApproximation(semanticReview)) {
      return "accepted_mean_delta";
    }
    return "failed_mean_delta";
  }
  return "ok";
}

function routeAssessment({ semanticReview, sourceAnalysisValidation, referenceComparison, assetFormat, warnings, failures, acceptance, visualReview, deliverableType }) {
  const pixelStatus = referencePixelStatus(referenceComparison, semanticReview);
  const localGateStatus = referenceComparison?.local_sample_gate?.status ?? "not_checked";
  const pixelNeedsRepair = !["ok", "accepted_mean_delta", "not_required"].includes(pixelStatus);
  const semanticStatus = semanticReview?.status ?? "not_provided";
  const identityRisk = semanticReview?.identity_risk ?? "not_recorded";
  const route = semanticReview?.route ?? "not_provided";
  let routeStatus = "not_assessed";
  let recommendedAction = "inspect_outputs";
  let reviewRequired = warnings.length > 0;

  if (isRejectedVisualDecision(visualReview)) {
    routeStatus = "visual_review_rejected";
    recommendedAction = "repair_redraw_or_request_source_vector_before_rechecking";
    reviewRequired = true;
  } else if (!semanticReview) {
    routeStatus = "semantic_review_missing";
    recommendedAction = "add_semantic_review_for_identity_sensitive_or_reference_driven_work";
    reviewRequired = true;
  } else if (isIdentitySensitiveReview(semanticReview) && sourceAnalysisValidation?.status === "missing") {
    routeStatus = "source_analysis_missing";
    recommendedAction = "add_source_analysis_contract_before_repair_or_acceptance";
    reviewRequired = true;
  } else if (isIdentitySensitiveReview(semanticReview) && sourceAnalysisValidation?.status === "invalid") {
    routeStatus = "source_analysis_invalid";
    recommendedAction = "repair_source_analysis_contract_before_repair_or_acceptance";
    reviewRequired = true;
  } else if (semanticStatus === "needs-source-vector" || route === "needs-source-vector") {
    routeStatus = "needs_source_vector";
    recommendedAction = "request_or_use_owned_or_user_approved_source_vector_before_claiming_identity_reproduction";
    reviewRequired = true;
  } else if (semanticStatus === "png-fallback-recommended" || route === "png-fallback-recommended" || route === "png-fallback") {
    routeStatus = assetFormat === "png" || assetFormat === "mixed" ? "png_fallback_selected" : "png_fallback_recommended_but_not_selected";
    if (routeStatus === "png_fallback_selected" && isAcceptedIndependentVisualDecision(visualReview)) {
      recommendedAction = "inspect_named_outputs_and_icon_composer_assets";
    } else {
      recommendedAction =
        routeStatus === "png_fallback_selected"
          ? "inspect_png_fallback_hygiene_and_get_human_or_independent_visual_acceptance"
          : "switch_the_identity_sensitive_layer_to_a_clean_png_fallback_or_change_route";
      reviewRequired = true;
    }
  } else if (semanticStatus === "redesign-needed" || route === "redesign-needed") {
    routeStatus = "redesign_needed";
    recommendedAction = "return_to_semantic_authoring_before_claiming_reproduction";
    reviewRequired = true;
  } else if (semanticStatus === "accepted-approximation" || route === "accepted-approximation") {
    routeStatus = "accepted_approximation";
    if (!hasAcceptanceEvidence(acceptance, visualReview)) {
      recommendedAction = "record_explicit_acceptance_evidence_before_completion";
      reviewRequired = true;
    } else if (!isAcceptedIndependentVisualDecision(visualReview)) {
      recommendedAction = "record_human_or_independent_visual_acceptance_before_completion";
      reviewRequired = true;
    } else if (
      pixelStatus === "accepted_mean_delta" &&
      referenceComparison?.mean_absolute_rgb_delta > STRICT_REPAIR_RANGE_UPPER &&
      !hasHumanAcceptance(acceptance) &&
      !hasWholeIconMaterialAcceptance(acceptance, visualReview)
    ) {
      routeStatus = "accepted_approximation_needs_whole_icon_material_acceptance";
      recommendedAction = "record_whole_icon_material_acceptance_or_repair_likeness";
      reviewRequired = true;
    } else {
      recommendedAction =
        pixelStatus === "accepted_mean_delta"
          ? "preserve_the_accepted_semantic_candidate_and_do_not_chase_pixel_delta"
          : "inspect_named_outputs_and_icon_composer_assets";
    }
  } else if (pixelNeedsRepair || localGateStatus === "failed") {
    routeStatus = isIdentitySensitiveReview(semanticReview) ? "needs_repair_or_route_escalation" : "needs_visual_repair";
    recommendedAction = localGateStatus === "failed" ? "repair_geometry_placement_or_identity_shape_before_rechecking" : "repair_visual_delta_or_reclassify_as_style_only";
    reviewRequired = true;
  } else if (semanticStatus === "visually-close" || route === "semantic-svg-approximation" || route === "style-only-approximation") {
    routeStatus = "numeric_pass_with_identity_approximation";
    recommendedAction = "inspect_semantic_fidelity_or_record_accepted_approximation";
    reviewRequired = true;
  } else if ((identityRisk === "medium" || identityRisk === "high") && !isAcceptedIndependentVisualDecision(visualReview)) {
    routeStatus = "independent_visual_review_required";
    recommendedAction = "record_human_or_independent_visual_acceptance_before_completion";
    reviewRequired = true;
  } else if (!hasRecordedVisualAcceptance(visualReview)) {
    routeStatus = "technical_candidate";
    recommendedAction = "inspect_preview_app_canvas_and_isolated_assets_then_record_visual_review";
    reviewRequired = true;
  } else {
    routeStatus = "complete_candidate";
    recommendedAction = "inspect_named_outputs_and_icon_composer_assets";
  }

  if (failures.length > 0) {
    routeStatus = "package_validation_failed";
    recommendedAction = "repair_package_validation_failures_before_rechecking";
    reviewRequired = true;
  }

  return {
    pixel_status: pixelStatus,
    local_gate_status: localGateStatus,
    semantic_status: semanticStatus,
    identity_risk: identityRisk,
    route,
    deliverable_type: deliverableType,
    asset_format: assetFormat ?? "unknown",
    route_status: routeStatus,
    review_required: reviewRequired,
    recommended_action: recommendedAction,
  };
}

function pngStats(png) {
  let visible = 0;
  let minX = png.width;
  let minY = png.height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const offset = (y * png.width + x) * 4;
      if (png.data[offset + 3] > 0) {
        visible += 1;
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  return {
    width: png.width,
    height: png.height,
    visible_pixels: visible,
    visible_bounds: visible > 0 ? { min_x: minX, min_y: minY, max_x: maxX, max_y: maxY } : null,
  };
}

function isSemanticSvgRoute(semanticReview) {
  const route = String(semanticReview?.route ?? "").trim();
  return route === "semantic-svg" || route === "semantic-svg-approximation";
}

function isTextPngDecision(decision) {
  return Boolean(decision?.text_rendering?.font_family && decision?.text_rendering?.render_method);
}

function validatePngFallbackDecisionEvidence(decision, failures) {
  if (decision.format !== "png" || isBackgroundLikeLayerName(decision.layer) || isTextPngDecision(decision)) {
    return;
  }
  const evidence = decision.png_fallback_evidence;
  if (!evidence || typeof evidence !== "object" || Array.isArray(evidence)) {
    failures.push(`PNG fallback layer "${decision.layer}" must include png_fallback_evidence with concrete per-layer evidence`);
    return;
  }
  const category = String(evidence.category ?? "").trim();
  const svgRoute = String(evidence.svg_route ?? evidence.svgRoute ?? "").trim();
  const evidenceText = String(evidence.evidence ?? "").trim();
  const cleanlinessCheck = String(evidence.cleanliness_check ?? evidence.cleanlinessCheck ?? "").trim();
  if (!PNG_FALLBACK_CATEGORIES.has(category)) {
    failures.push(`PNG fallback layer "${decision.layer}" has invalid png_fallback_evidence.category`);
  }
  if (!PNG_FALLBACK_ROUTES.has(svgRoute)) {
    failures.push(`PNG fallback layer "${decision.layer}" has invalid png_fallback_evidence.svg_route`);
  }
  if (evidenceText.length < 16) {
    failures.push(`PNG fallback layer "${decision.layer}" png_fallback_evidence.evidence is too vague`);
  }
  if (cleanlinessCheck.length < 16) {
    failures.push(`PNG fallback layer "${decision.layer}" png_fallback_evidence.cleanliness_check is too vague`);
  }
  if (isVaguePngFallbackReason(decision.reason)) {
    failures.push(`PNG fallback layer "${decision.layer}" reason is too generic; record a concrete per-layer reason`);
  }
}

function countVisibleInRow(png, y, minX, maxX) {
  let count = 0;
  for (let x = minX; x <= maxX; x += 1) {
    const offset = (y * png.width + x) * 4;
    if (png.data[offset + 3] > 0) {
      count += 1;
    }
  }
  return count;
}

function rectangularEdgeEvidence(png, visibleBounds) {
  if (!visibleBounds) {
    return null;
  }
  const boundsWidth = visibleBounds.max_x - visibleBounds.min_x + 1;
  const boundsHeight = visibleBounds.max_y - visibleBounds.min_y + 1;
  if (boundsWidth < 64 || boundsHeight < 64) {
    return null;
  }

  const scanDepth = Math.min(4, Math.floor(Math.min(boundsWidth, boundsHeight) / 8));
  const horizontalEdges = [
    ["top", visibleBounds.min_y, 1],
    ["bottom", visibleBounds.max_y, -1],
  ];
  const bestByEdge = {};
  for (const [edge, startY, direction] of horizontalEdges) {
    for (let step = 0; step < scanDepth; step += 1) {
      const y = startY + step * direction;
      const ratio = countVisibleInRow(png, y, visibleBounds.min_x, visibleBounds.max_x) / boundsWidth;
      if (ratio >= 0.72 && (!bestByEdge[edge] || ratio > bestByEdge[edge].visible_ratio)) {
        bestByEdge[edge] = { edge, visible_ratio: rounded(ratio), bounds_width: boundsWidth, bounds_height: boundsHeight };
      }
    }
  }
  if (!bestByEdge.top || !bestByEdge.bottom) {
    return null;
  }
  const best = bestByEdge.top.visible_ratio >= bestByEdge.bottom.visible_ratio ? bestByEdge.top : bestByEdge.bottom;
  best.opposite_edge = best.edge === "top" ? "bottom" : "top";
  best.opposite_visible_ratio = best.edge === "top" ? bestByEdge.bottom.visible_ratio : bestByEdge.top.visible_ratio;
  return best;
}

function pngLayerHygiene(png, { edgeGutter = PNG_LAYER_EDGE_GUTTER } = {}) {
  let visible = 0;
  let opaque = 0;
  let semiTransparent = 0;
  let edgeVisible = 0;
  let minX = png.width;
  let minY = png.height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const offset = (y * png.width + x) * 4;
      const alpha = png.data[offset + 3];
      if (alpha > 0) {
        visible += 1;
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
        if (alpha >= 250) {
          opaque += 1;
        } else {
          semiTransparent += 1;
        }
        if (x < edgeGutter || y < edgeGutter || x >= png.width - edgeGutter || y >= png.height - edgeGutter) {
          edgeVisible += 1;
        }
      }
    }
  }

  const totalPixels = png.width * png.height;
  const visibleBounds = visible > 0 ? { min_x: minX, min_y: minY, max_x: maxX, max_y: maxY } : null;
  const rectangularEdge = rectangularEdgeEvidence(png, visibleBounds);
  return {
    edge_gutter_px: edgeGutter,
    visible_pixels: visible,
    visible_pct: pct(visible, totalPixels),
    opaque_pixels: opaque,
    opaque_pct: pct(opaque, totalPixels),
    semi_transparent_pixels: semiTransparent,
    semi_transparent_pct: pct(semiTransparent, totalPixels),
    edge_visible_pixels: edgeVisible,
    edge_visible_pct: pct(edgeVisible, Math.max(1, (png.width * edgeGutter * 2) + (png.height * edgeGutter * 2) - edgeGutter * edgeGutter * 4)),
    visible_bounds: visibleBounds,
    rectangular_edge_evidence: rectangularEdge,
    touches_canvas_edge: Boolean(
      visibleBounds &&
        (visibleBounds.min_x < edgeGutter ||
          visibleBounds.min_y < edgeGutter ||
          visibleBounds.max_x >= png.width - edgeGutter ||
          visibleBounds.max_y >= png.height - edgeGutter),
    ),
  };
}

function validatePngFallbackHygiene(assetPath, decision, hygiene, failures) {
  if (isBackgroundLikeLayerName(decision.layer)) {
    return;
  }
  if (hygiene.edge_visible_pixels > 0 || hygiene.touches_canvas_edge) {
    failures.push(
      `${assetPath} appears to contain canvas-edge or background residue (${hygiene.edge_visible_pixels} visible edge pixels; bounds ${JSON.stringify(
        hygiene.visible_bounds,
      )}); foreground PNG fallbacks must be clean transparent layers for Icon Composer. Rebuild the matte or redraw this layer as SVG.`,
    );
  }
}

function warnOnSuspiciousPngFallback(assetPath, decision, hygiene, warnings) {
  if (isBackgroundLikeLayerName(decision.layer)) {
    return;
  }
  if (hygiene.visible_pixels > 0 && hygiene.visible_pct > 5 && hygiene.semi_transparent_pixels === 0) {
    warnings.push(
      `${assetPath} has no semi-transparent edge pixels; inspect the isolated foreground PNG on a neutral/checker background for baked background, glow, shadow, or hard-matte residue.`,
    );
  }
  if (hygiene.rectangular_edge_evidence) {
    warnings.push(
      `${assetPath} has a suspicious rectangular visible edge (${hygiene.rectangular_edge_evidence.edge}, ratio ${hygiene.rectangular_edge_evidence.visible_ratio}); inspect the isolated foreground PNG for source-background residue or matte blocks.`,
    );
  }
}

function rounded(value, digits = 4) {
  return Number(value.toFixed(digits));
}

function percentile(sortedValues, p) {
  if (sortedValues.length === 0) {
    return 0;
  }
  const index = Math.min(sortedValues.length - 1, Math.max(0, Math.ceil(sortedValues.length * p) - 1));
  return sortedValues[index];
}

function pct(count, total) {
  return total > 0 ? rounded((count / total) * 100, 4) : 0;
}

function scaledVisualDeltaMinPixels(width, height) {
  const scale = (width * height) / (DEFAULT_CANVAS * DEFAULT_CANVAS);
  return Math.max(1, Math.round(VISUAL_DELTA_GATE_MIN_HIGH_DELTA_PIXELS * scale));
}

function scaledFrameGutter(width, height) {
  return Math.max(1, Math.round(Math.min(width, height) * VISUAL_DELTA_GATE_FRAME_GUTTER_RATIO));
}

function createVisualDeltaRegionTracker() {
  return {
    pixels: 0,
    total: 0,
    gt_10: 0,
    gt_25: 0,
    gt_50: 0,
    highDeltaBounds: createBoundsTracker(),
  };
}

function addVisualDeltaRegionPoint(region, x, y, pixelMean) {
  region.pixels += 1;
  region.total += pixelMean;
  if (pixelMean > 10) {
    region.gt_10 += 1;
  }
  if (pixelMean > 25) {
    region.gt_25 += 1;
    addBoundsPoint(region.highDeltaBounds, x, y);
  }
  if (pixelMean > 50) {
    region.gt_50 += 1;
  }
}

function summarizeVisualDeltaRegion(region) {
  return {
    pixel_count: region.pixels,
    mean_absolute_rgb_delta: region.pixels > 0 ? rounded(region.total / region.pixels) : 0,
    pct_pixels_mean_rgb_gt_10: pct(region.gt_10, region.pixels),
    pct_pixels_mean_rgb_gt_25: pct(region.gt_25, region.pixels),
    pct_pixels_mean_rgb_gt_50: pct(region.gt_50, region.pixels),
    high_delta_pixels: region.gt_25,
    high_delta_region: finishBounds(region.highDeltaBounds),
  };
}

function summarizeFrameEdges(edgeCounts, minHighDeltaPixelsPerEdge) {
  const edges = Object.entries(edgeCounts)
    .filter(([, count]) => count >= minHighDeltaPixelsPerEdge)
    .map(([edge]) => edge);
  return {
    min_high_delta_pixels_per_edge: minHighDeltaPixelsPerEdge,
    high_delta_pixels_by_edge: edgeCounts,
    edges_with_enough_high_delta: edges,
    count: edges.length,
  };
}

function requiredReportString(report, field, failures) {
  const value = report[field];
  if (typeof value === "string" && value.trim() !== "") {
    return value;
  }
  failures.push(`style-report.json is missing ${field}`);
  return null;
}

const MANAGED_REPORT_NAMES = [
  "style-report.json",
  "package-verification.json",
  "reference-diff.png",
  "reference-overlay.png",
  "reference-side-by-side.png",
  "visual-review.json",
];

function manifestDirectories(files) {
  const directories = new Set();
  for (const file of files) {
    let directory = dirname(file).split("\\").join("/");
    while (directory && directory !== ".") {
      directories.add(directory);
      const parent = dirname(directory).split("\\").join("/");
      if (!parent || parent === "." || parent === directory) {
        break;
      }
      directory = parent;
    }
  }
  return [...directories];
}

function normalizedManifestEntries(value, field, problems) {
  if (!Array.isArray(value) || value.length === 0) {
    problems.push(`${field} must be a non-empty array of normalized relative paths`);
    return [];
  }
  const entries = [];
  const seen = new Set();
  for (const entry of value) {
    if (
      typeof entry !== "string" ||
      entry.trim() !== entry ||
      entry === "" ||
      entry.includes("\\") ||
      entry.startsWith("/") ||
      entry.split("/").some((part) => part === "" || part === "." || part === "..")
    ) {
      problems.push(`${field} contains a non-normalized relative path: ${String(entry)}`);
      continue;
    }
    if (seen.has(entry)) {
      problems.push(`${field} contains a duplicate path: ${entry}`);
      continue;
    }
    seen.add(entry);
    entries.push(entry);
  }
  return entries;
}

function validateGeneratedFilesManifest(outDir, reportsDir, styleReport) {
  const problems = [];
  const generatedFiles = normalizedManifestEntries(styleReport.generated_files, "generated_files", problems);
  const generatedDirectories = normalizedManifestEntries(
    styleReport.generated_directories,
    "generated_directories",
    problems,
  );
  const reportFiles = MANAGED_REPORT_NAMES.map((name) => outputRelativePath(outDir, resolve(reportsDir, name)));
  let appleFiles = [];
  if (styleReport.apple_exports?.status === "generated") {
    try {
      appleFiles = appleExportProfilesForTargets(styleReport.target_platforms ?? []).flatMap((profile) =>
        profile.renditions.map((rendition) => `apple/${profile.platform}/${rendition.name}.png`),
      );
    } catch (error) {
      problems.push(`cannot derive generated_files Apple entries: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  const readme = styleReport.layout === "delivery" ? "tmp/README.md" : styleReport.layout === "package" ? "README.md" : null;
  if (!readme) {
    problems.push("style-report.json layout must be package or delivery for generated_files validation");
  }
  const expectedFiles = [
    styleReport.preview_svg,
    styleReport.preview_png,
    styleReport.app_svg,
    styleReport.app_png,
    ...(Array.isArray(styleReport.layers) ? styleReport.layers : []),
    typeof styleReport.icon_composer_bundle === "string" ? `${styleReport.icon_composer_bundle}/icon.json` : null,
    ...(Array.isArray(styleReport.icon_composer_assets) ? styleReport.icon_composer_assets : []),
    ...appleFiles,
    readme,
    ...reportFiles,
  ].filter((entry) => typeof entry === "string" && entry !== "");

  const generatedSet = new Set(generatedFiles);
  const expectedSet = new Set(expectedFiles);
  const unexpected = generatedFiles.filter((entry) => !expectedSet.has(entry));
  const missing = expectedFiles.filter((entry) => !generatedSet.has(entry));
  if (unexpected.length > 0) {
    problems.push(`generated_files claims unexpected leaves: ${[...new Set(unexpected)].join(", ")}`);
  }
  if (missing.length > 0) {
    problems.push(`generated_files omits expected leaves: ${[...new Set(missing)].join(", ")}`);
  }

  for (const entry of generatedFiles) {
    try {
      const full = inside(outDir, entry);
      if (lstatSync(full).isDirectory()) {
        problems.push(`generated_files entry is a directory rather than a leaf file: ${entry}`);
      }
    } catch (error) {
      if (error?.code !== "ENOENT") {
        problems.push(`generated_files entry is unsafe: ${entry} (${error instanceof Error ? error.message : String(error)})`);
      }
    }
  }

  const expectedDirectories = manifestDirectories(generatedFiles);
  const directorySet = new Set(generatedDirectories);
  const expectedDirectorySet = new Set(expectedDirectories);
  if (
    generatedDirectories.some((entry) => !expectedDirectorySet.has(entry)) ||
    expectedDirectories.some((entry) => !directorySet.has(entry))
  ) {
    problems.push("generated_directories must exactly match the directories derived from generated_files");
  }

  return {
    status: problems.length === 0 ? "valid" : "invalid",
    files: generatedFiles,
    problems,
  };
}

function createBoundsTracker() {
  return {
    count: 0,
    minX: Number.POSITIVE_INFINITY,
    minY: Number.POSITIVE_INFINITY,
    maxX: -1,
    maxY: -1,
    sumX: 0,
    sumY: 0,
  };
}

function addBoundsPoint(bounds, x, y) {
  bounds.count += 1;
  bounds.minX = Math.min(bounds.minX, x);
  bounds.minY = Math.min(bounds.minY, y);
  bounds.maxX = Math.max(bounds.maxX, x);
  bounds.maxY = Math.max(bounds.maxY, y);
  bounds.sumX += x;
  bounds.sumY += y;
}

function finishBounds(bounds) {
  if (bounds.count === 0) {
    return null;
  }
  return {
    count: bounds.count,
    bbox: { min_x: bounds.minX, min_y: bounds.minY, max_x: bounds.maxX, max_y: bounds.maxY },
    centroid: { x: rounded(bounds.sumX / bounds.count, 2), y: rounded(bounds.sumY / bounds.count, 2) },
  };
}

function createTileBuckets(width, height, columns = DIAGNOSTIC_TILE_COLUMNS, rows = DIAGNOSTIC_TILE_ROWS) {
  return Array.from({ length: columns * rows }, (_, index) => {
    const column = index % columns;
    const row = Math.floor(index / columns);
    const minX = Math.floor((column * width) / columns);
    const maxX = Math.floor(((column + 1) * width) / columns) - 1;
    const minY = Math.floor((row * height) / rows);
    const maxY = Math.floor(((row + 1) * height) / rows) - 1;
    return {
      id: `r${row}c${column}`,
      row,
      column,
      bounds: { min_x: minX, min_y: minY, max_x: maxX, max_y: maxY },
      values: [],
    };
  });
}

function summarizeTileDiagnostics(tiles, totalPixels) {
  const summarized = tiles.map((tile) => {
    tile.values.sort((a, b) => a - b);
    const total = tile.values.reduce((sum, value) => sum + value, 0);
    const mean = tile.values.length > 0 ? total / tile.values.length : 0;
    return {
      id: tile.id,
      row: tile.row,
      column: tile.column,
      bounds: tile.bounds,
      pixel_count: tile.values.length,
      pixel_pct: pct(tile.values.length, totalPixels),
      mean_rgb_delta: rounded(mean),
      p95_pixel_mean_rgb_delta: rounded(percentile(tile.values, 0.95)),
      max_pixel_mean_rgb_delta: rounded(tile.values[tile.values.length - 1] ?? 0),
    };
  });
  return {
    diagnostic_only: true,
    not_a_gate: true,
    grid: { columns: DIAGNOSTIC_TILE_COLUMNS, rows: DIAGNOSTIC_TILE_ROWS },
    top_tiles_by_mean: [...summarized]
      .sort((a, b) => b.mean_rgb_delta - a.mean_rgb_delta)
      .slice(0, 8),
    top_tiles_by_p95: [...summarized]
      .sort((a, b) => b.p95_pixel_mean_rgb_delta - a.p95_pixel_mean_rgb_delta)
      .slice(0, 8),
    top_tiles_by_max: [...summarized]
      .sort((a, b) => b.max_pixel_mean_rgb_delta - a.max_pixel_mean_rgb_delta)
      .slice(0, 8),
  };
}

function buildLocalSamples(iconPng, reference, radius = LOCAL_SAMPLE_RADIUS) {
  const points = LOCAL_SAMPLE_POINTS.map(([id, label, nx, ny]) => {
    const x = Math.round((iconPng.width - 1) * nx);
    const y = Math.round((iconPng.height - 1) * ny);
    const minX = Math.max(0, x - radius);
    const maxX = Math.min(iconPng.width - 1, x + radius);
    const minY = Math.max(0, y - radius);
    const maxY = Math.min(iconPng.height - 1, y + radius);
    const iconTotals = [0, 0, 0, 0];
    const referenceTotals = [0, 0, 0, 0];
    const pixelMeanDeltas = [];
    let maxChannel = 0;
    let count = 0;

    for (let py = minY; py <= maxY; py += 1) {
      for (let px = minX; px <= maxX; px += 1) {
        const offset = (py * iconPng.width + px) * 4;
        const dr = Math.abs(iconPng.data[offset] - reference.data[offset]);
        const dg = Math.abs(iconPng.data[offset + 1] - reference.data[offset + 1]);
        const db = Math.abs(iconPng.data[offset + 2] - reference.data[offset + 2]);
        const da = Math.abs(iconPng.data[offset + 3] - reference.data[offset + 3]);
        pixelMeanDeltas.push((dr + dg + db) / 3);
        maxChannel = Math.max(maxChannel, dr, dg, db, da);
        for (let channel = 0; channel < 4; channel += 1) {
          iconTotals[channel] += iconPng.data[offset + channel];
          referenceTotals[channel] += reference.data[offset + channel];
        }
        count += 1;
      }
    }

    pixelMeanDeltas.sort((a, b) => a - b);
    const iconMean = iconTotals.map((value) => rounded(value / count, 2));
    const referenceMean = referenceTotals.map((value) => rounded(value / count, 2));
    const delta = {
      r: rounded(Math.abs(iconMean[0] - referenceMean[0]), 2),
      g: rounded(Math.abs(iconMean[1] - referenceMean[1]), 2),
      b: rounded(Math.abs(iconMean[2] - referenceMean[2]), 2),
      a: rounded(Math.abs(iconMean[3] - referenceMean[3]), 2),
      mean_rgb: rounded((Math.abs(iconMean[0] - referenceMean[0]) + Math.abs(iconMean[1] - referenceMean[1]) + Math.abs(iconMean[2] - referenceMean[2])) / 3),
      p95_pixel_mean_rgb: rounded(percentile(pixelMeanDeltas, 0.95)),
      max_pixel_mean_rgb: rounded(pixelMeanDeltas[pixelMeanDeltas.length - 1] ?? 0),
      max_channel: rounded(maxChannel, 2),
    };

    return {
      id,
      label,
      x,
      y,
      nx,
      ny,
      source: "grid_3x3",
      window_bounds: { min_x: minX, min_y: minY, max_x: maxX, max_y: maxY },
      icon_rgba_mean: iconMean,
      reference_rgba_mean: referenceMean,
      delta,
    };
  });

  const worstByMean = points.reduce((worst, point) => (point.delta.mean_rgb > worst.delta.mean_rgb ? point : worst), points[0]);
  const worstByP95 = points.reduce((worst, point) => (point.delta.p95_pixel_mean_rgb > worst.delta.p95_pixel_mean_rgb ? point : worst), points[0]);

  return {
    schema_version: 1,
    method: "grid_window",
    diagnostic_only: true,
    not_a_gate: true,
    interpretation: "Use samples to choose inspection regions after side-by-side and overlay/diff review; do not optimize samples directly.",
    grid: { columns: 3, rows: 3 },
    coordinate_space: "image_pixels",
    window: { radius_px: radius, width_px: radius * 2 + 1, height_px: radius * 2 + 1 },
    summary: {
      sample_count: points.length,
      max_mean_rgb_delta: worstByMean ? worstByMean.delta.mean_rgb : 0,
      worst_sample_id: worstByMean?.id ?? null,
      max_p95_pixel_mean_rgb_delta: worstByP95 ? worstByP95.delta.p95_pixel_mean_rgb : 0,
      worst_p95_sample_id: worstByP95?.id ?? null,
    },
    points,
  };
}

function evaluateLocalSampleGate(localSamples) {
  const severeSamples = localSamples.points
    .filter((point) => point.delta.mean_rgb >= LOCAL_SAMPLE_GATE_MEAN_DELTA && point.delta.p95_pixel_mean_rgb >= LOCAL_SAMPLE_GATE_P95_DELTA)
    .map((point) => ({
      id: point.id,
      label: point.label,
      x: point.x,
      y: point.y,
      mean_rgb_delta: point.delta.mean_rgb,
      p95_pixel_mean_rgb_delta: point.delta.p95_pixel_mean_rgb,
      window_bounds: point.window_bounds,
    }));

  return {
    status: severeSamples.length > 0 ? "failed" : "ok",
    thresholds: {
      mean_rgb_delta: LOCAL_SAMPLE_GATE_MEAN_DELTA,
      p95_pixel_mean_rgb_delta: LOCAL_SAMPLE_GATE_P95_DELTA,
      rule: "both_thresholds_must_be_met",
    },
    severe_samples: severeSamples,
    interpretation:
      severeSamples.length > 0
        ? "A small stable sample has severe local mismatch even if the full-image mean passes; inspect side-by-side and overlay/diff for position, scale, or shape drift."
        : "No stable sample exceeded the severe local mismatch gate.",
  };
}

function visualDeltaThresholdExceeded(measured, minHighDeltaPixels) {
  return (
    measured.pct_pixels_mean_rgb_gt_25 >= VISUAL_DELTA_GATE_PCT_GT_25 &&
    measured.pct_pixels_mean_rgb_gt_50 >= VISUAL_DELTA_GATE_PCT_GT_50 &&
    measured.high_delta_pixels >= minHighDeltaPixels
  );
}

function evaluateVisualDeltaGate(pixelDelta, frameDelta) {
  const highDeltaCount = pixelDelta.high_delta_region?.count ?? 0;
  const frameHighDeltaCount = frameDelta?.frame?.high_delta_pixels ?? 0;
  const frameHighDeltaShare = highDeltaCount > 0 ? rounded((frameHighDeltaCount / highDeltaCount) * 100, 4) : 0;
  const interiorMeasured = frameDelta?.interior ?? null;
  const minHighDeltaPixels = frameDelta?.min_high_delta_pixels ?? VISUAL_DELTA_GATE_MIN_HIGH_DELTA_PIXELS;
  const frameEdgeCount = frameDelta?.frame_edges?.count ?? 0;
  const severeContourResidual =
    interiorMeasured != null ? visualDeltaThresholdExceeded(interiorMeasured, minHighDeltaPixels) : visualDeltaThresholdExceeded({
      pct_pixels_mean_rgb_gt_25: pixelDelta.pct_pixels_mean_rgb_gt_25,
      pct_pixels_mean_rgb_gt_50: pixelDelta.pct_pixels_mean_rgb_gt_50,
      high_delta_pixels: highDeltaCount,
    }, minHighDeltaPixels);
  const broadMediumInteriorResidual =
    interiorMeasured != null &&
    interiorMeasured.pct_pixels_mean_rgb_gt_25 >= VISUAL_DELTA_GATE_BROAD_MEDIUM_PCT_GT_25 &&
    (interiorMeasured.high_delta_pixels ?? 0) >= VISUAL_DELTA_GATE_BROAD_MEDIUM_MIN_HIGH_DELTA_PIXELS;
  const frameDominatedResidual =
    visualDeltaThresholdExceeded({
      pct_pixels_mean_rgb_gt_25: pixelDelta.pct_pixels_mean_rgb_gt_25,
      pct_pixels_mean_rgb_gt_50: pixelDelta.pct_pixels_mean_rgb_gt_50,
      high_delta_pixels: highDeltaCount,
    }, minHighDeltaPixels) &&
    !severeContourResidual &&
    frameHighDeltaShare >= VISUAL_DELTA_GATE_FRAME_DOMINATED_SHARE &&
    frameEdgeCount >= VISUAL_DELTA_GATE_FRAME_MIN_EDGES;
  const failures = [];
  if (severeContourResidual) {
    failures.push("severe_contour_or_silhouette_residual");
  }
  if (broadMediumInteriorResidual) {
    failures.push("broad_medium_intensity_residual");
  }
  return {
    status: failures.length > 0 ? "failed" : "ok",
    thresholds: {
      pct_pixels_mean_rgb_gt_25: VISUAL_DELTA_GATE_PCT_GT_25,
      pct_pixels_mean_rgb_gt_50: VISUAL_DELTA_GATE_PCT_GT_50,
      broad_medium_pct_pixels_mean_rgb_gt_25: VISUAL_DELTA_GATE_BROAD_MEDIUM_PCT_GT_25,
      broad_medium_min_high_delta_pixels: VISUAL_DELTA_GATE_BROAD_MEDIUM_MIN_HIGH_DELTA_PIXELS,
      min_high_delta_pixels: minHighDeltaPixels,
      frame_gutter_ratio: VISUAL_DELTA_GATE_FRAME_GUTTER_RATIO,
      frame_gutter_px: frameDelta?.gutter_px ?? null,
      frame_dominated_share_pct: VISUAL_DELTA_GATE_FRAME_DOMINATED_SHARE,
      frame_min_edges: VISUAL_DELTA_GATE_FRAME_MIN_EDGES,
      rule: "fail on severe high-intensity residual, or broad interior medium-intensity residual",
    },
    measured: {
      pct_pixels_mean_rgb_gt_25: pixelDelta.pct_pixels_mean_rgb_gt_25,
      pct_pixels_mean_rgb_gt_50: pixelDelta.pct_pixels_mean_rgb_gt_50,
      high_delta_pixels: highDeltaCount,
      high_delta_region: pixelDelta.high_delta_region,
      frame_high_delta_share_pct: frameHighDeltaShare,
      frame_delta: frameDelta,
    },
    failures,
    review_flags: frameDominatedResidual ? ["frame_or_rounded_mask_residual_dominated"] : [],
    interpretation:
      failures.length > 0
        ? "Diff has enough interior residual pixels to indicate visible contour, silhouette, material, or major local shape drift even when global mean and fixed local samples pass."
        : frameDominatedResidual
          ? "Full-canvas diff exceeded the broad residual threshold, but the excess is dominated by the outer rounded app-mask/frame region; inspect the frame separately and do not treat it as foreground shape drift."
          : "No broad high-intensity diff residual exceeded the visual delta gate.",
  };
}

async function compareReference(outDir, reportsDir, iconPng, referencePath, maxMeanDelta, failures, warnings, options = {}) {
  const enforceMeanDelta = options.enforceMeanDelta ?? true;
  const reference = readPng(await readFile(referencePath), "reference", failures);
  if (!reference) {
    return null;
  }
  if (reference.width !== iconPng.width || reference.height !== iconPng.height) {
    warnings.push(`reference dimensions ${reference.width}x${reference.height} differ from icon ${iconPng.width}x${iconPng.height}; skipped pixel diff`);
    if (maxMeanDelta != null) {
      failures.push("--max-mean-delta cannot be enforced because reference dimensions differ from the generated icon");
    }
    return {
      status: "skipped",
      reason: "dimension_mismatch",
      reference_width: reference.width,
      reference_height: reference.height,
      icon_width: iconPng.width,
      icon_height: iconPng.height,
    };
  }

  const diff = new PNG({ width: iconPng.width, height: iconPng.height });
  const overlay = new PNG({ width: iconPng.width, height: iconPng.height });
  const sideBySide = new PNG({ width: iconPng.width * 2 + SIDE_BY_SIDE_GUTTER, height: iconPng.height });
  let total = 0;
  let max = 0;
  let alphaTotal = 0;
  let alphaMax = 0;
  const pixelMeanDeltas = [];
  const alphaDeltas = [];
  const thresholdCounts = { gt_10: 0, gt_25: 0, gt_50: 0 };
  const highDeltaBounds = createBoundsTracker();
  const frameRegion = createVisualDeltaRegionTracker();
  const interiorRegion = createVisualDeltaRegionTracker();
  const frameGutterPx = scaledFrameGutter(iconPng.width, iconPng.height);
  const minHighDeltaPixels = scaledVisualDeltaMinPixels(iconPng.width, iconPng.height);
  const minFrameEdgeHighDeltaPixels = Math.max(1, Math.round(frameGutterPx * 0.75));
  const frameEdgeHighDeltaCounts = { top: 0, right: 0, bottom: 0, left: 0 };
  const tiles = createTileBuckets(iconPng.width, iconPng.height);
  for (let offset = 0; offset < iconPng.data.length; offset += 4) {
    const dr = Math.abs(iconPng.data[offset] - reference.data[offset]);
    const dg = Math.abs(iconPng.data[offset + 1] - reference.data[offset + 1]);
    const db = Math.abs(iconPng.data[offset + 2] - reference.data[offset + 2]);
    const da = Math.abs(iconPng.data[offset + 3] - reference.data[offset + 3]);
    const pixelMean = (dr + dg + db) / 3;
    const pixelIndex = offset / 4;
    const x = pixelIndex % iconPng.width;
    const y = Math.floor(pixelIndex / iconPng.width);
    const inLeftFrame = x < frameGutterPx;
    const inTopFrame = y < frameGutterPx;
    const inRightFrame = x >= iconPng.width - frameGutterPx;
    const inBottomFrame = y >= iconPng.height - frameGutterPx;
    const inFrameGutter = inLeftFrame || inTopFrame || inRightFrame || inBottomFrame;
    const tileColumn = Math.min(DIAGNOSTIC_TILE_COLUMNS - 1, Math.floor((x * DIAGNOSTIC_TILE_COLUMNS) / iconPng.width));
    const tileRow = Math.min(DIAGNOSTIC_TILE_ROWS - 1, Math.floor((y * DIAGNOSTIC_TILE_ROWS) / iconPng.height));
    tiles[tileRow * DIAGNOSTIC_TILE_COLUMNS + tileColumn].values.push(pixelMean);
    pixelMeanDeltas.push(pixelMean);
    alphaDeltas.push(da);
    total += pixelMean;
    alphaTotal += da;
    max = Math.max(max, dr, dg, db, da);
    alphaMax = Math.max(alphaMax, da);
    if (pixelMean > 10) {
      thresholdCounts.gt_10 += 1;
    }
    if (pixelMean > 25) {
      thresholdCounts.gt_25 += 1;
      addBoundsPoint(highDeltaBounds, x, y);
    }
    if (pixelMean > 50) {
      thresholdCounts.gt_50 += 1;
    }
    if (inFrameGutter) {
      addVisualDeltaRegionPoint(frameRegion, x, y, pixelMean);
      if (pixelMean > HIGH_DELTA_THRESHOLD) {
        if (inTopFrame) {
          frameEdgeHighDeltaCounts.top += 1;
        }
        if (inRightFrame) {
          frameEdgeHighDeltaCounts.right += 1;
        }
        if (inBottomFrame) {
          frameEdgeHighDeltaCounts.bottom += 1;
        }
        if (inLeftFrame) {
          frameEdgeHighDeltaCounts.left += 1;
        }
      }
    } else {
      addVisualDeltaRegionPoint(interiorRegion, x, y, pixelMean);
    }

    diff.data[offset] = dr;
    diff.data[offset + 1] = dg;
    diff.data[offset + 2] = db;
    diff.data[offset + 3] = 255;

    overlay.data[offset] = Math.round((iconPng.data[offset] + reference.data[offset]) / 2);
    overlay.data[offset + 1] = Math.round((iconPng.data[offset + 1] + reference.data[offset + 1]) / 2);
    overlay.data[offset + 2] = Math.round((iconPng.data[offset + 2] + reference.data[offset + 2]) / 2);
    overlay.data[offset + 3] = Math.max(iconPng.data[offset + 3], reference.data[offset + 3]);

    const sideBySideOffset = (y * sideBySide.width + x) * 4;
    const sideBySideIconOffset = (y * sideBySide.width + x + iconPng.width + SIDE_BY_SIDE_GUTTER) * 4;
    sideBySide.data[sideBySideOffset] = reference.data[offset];
    sideBySide.data[sideBySideOffset + 1] = reference.data[offset + 1];
    sideBySide.data[sideBySideOffset + 2] = reference.data[offset + 2];
    sideBySide.data[sideBySideOffset + 3] = reference.data[offset + 3];
    sideBySide.data[sideBySideIconOffset] = iconPng.data[offset];
    sideBySide.data[sideBySideIconOffset + 1] = iconPng.data[offset + 1];
    sideBySide.data[sideBySideIconOffset + 2] = iconPng.data[offset + 2];
    sideBySide.data[sideBySideIconOffset + 3] = iconPng.data[offset + 3];
  }

  const diffPath = await writeFileInside(outDir, resolve(reportsDir, "reference-diff.png"), PNG.sync.write(diff));
  const overlayPath = await writeFileInside(outDir, resolve(reportsDir, "reference-overlay.png"), PNG.sync.write(overlay));
  const sideBySidePath = await writeFileInside(outDir, resolve(reportsDir, "reference-side-by-side.png"), PNG.sync.write(sideBySide));

  const totalPixels = iconPng.width * iconPng.height;
  pixelMeanDeltas.sort((a, b) => a - b);
  alphaDeltas.sort((a, b) => a - b);

  const meanAbsoluteRgbDelta = Number((total / totalPixels).toFixed(4));
  if (maxMeanDelta != null && enforceMeanDelta && meanAbsoluteRgbDelta > maxMeanDelta) {
    failures.push(`reference mean delta ${meanAbsoluteRgbDelta} exceeds target ${maxMeanDelta}`);
  }

  const pixelDeltaDiagnostics = {
    p95_mean_rgb_delta: rounded(percentile(pixelMeanDeltas, 0.95)),
    p99_mean_rgb_delta: rounded(percentile(pixelMeanDeltas, 0.99)),
    max_pixel_mean_rgb_delta: rounded(pixelMeanDeltas[pixelMeanDeltas.length - 1] ?? 0),
    pct_pixels_mean_rgb_gt_10: pct(thresholdCounts.gt_10, totalPixels),
    pct_pixels_mean_rgb_gt_25: pct(thresholdCounts.gt_25, totalPixels),
    pct_pixels_mean_rgb_gt_50: pct(thresholdCounts.gt_50, totalPixels),
    high_delta_threshold: HIGH_DELTA_THRESHOLD,
    high_delta_region: finishBounds(highDeltaBounds),
  };
  const frameDeltaDiagnostics = {
    gutter_px: frameGutterPx,
    gutter_ratio: VISUAL_DELTA_GATE_FRAME_GUTTER_RATIO,
    min_high_delta_pixels: minHighDeltaPixels,
    frame: summarizeVisualDeltaRegion(frameRegion),
    interior: summarizeVisualDeltaRegion(interiorRegion),
    frame_edges: summarizeFrameEdges(frameEdgeHighDeltaCounts, minFrameEdgeHighDeltaPixels),
  };
  const visualDeltaGate = evaluateVisualDeltaGate(pixelDeltaDiagnostics, frameDeltaDiagnostics);
  if (maxMeanDelta != null && visualDeltaGate.status === "failed") {
    failures.push(
      `visual delta gate failed: ${visualDeltaGate.failures.join(", ")}; inspect reference-diff.png and reference-overlay.png before claiming completion`,
    );
  }

  const localSamples = buildLocalSamples(iconPng, reference);
  const localSampleGate = evaluateLocalSampleGate(localSamples);
  if (maxMeanDelta != null && localSampleGate.status === "failed") {
    for (const sample of localSampleGate.severe_samples) {
      failures.push(
        `local sample ${sample.id} mean delta ${sample.mean_rgb_delta} and p95 ${sample.p95_pixel_mean_rgb_delta} exceeds local gate; inspect position/scale/shape drift around ${JSON.stringify(
          sample.window_bounds,
        )}`,
      );
    }
  }

  const comparison = {
    status: "compared",
    reference_width: reference.width,
    reference_height: reference.height,
    mean_absolute_rgb_delta: meanAbsoluteRgbDelta,
    max_channel_delta: max,
    diff_png: outputRelativePath(outDir, diffPath),
    overlay_png: outputRelativePath(outDir, overlayPath),
    side_by_side_png: outputRelativePath(outDir, sideBySidePath),
    visual_delta_gate: visualDeltaGate,
    diagnostics: {
      diagnostic_only: true,
      not_a_gate: true,
      interpretation: "Use these metrics to locate repair regions after inspecting side-by-side and overlay/diff; hard gates are mean_absolute_rgb_delta, visual_delta_gate, local_sample_gate, and visual review.",
      pixel_delta: pixelDeltaDiagnostics,
      frame_delta: frameDeltaDiagnostics,
      alpha_delta: {
        mean_absolute_alpha_delta: rounded(alphaTotal / totalPixels),
        p95_alpha_delta: rounded(percentile(alphaDeltas, 0.95)),
        p99_alpha_delta: rounded(percentile(alphaDeltas, 0.99)),
        max_alpha_delta: alphaMax,
      },
      tile_heatmap: summarizeTileDiagnostics(tiles, totalPixels),
    },
    local_samples: localSamples,
    local_sample_gate: localSampleGate,
  };
  if (maxMeanDelta != null) {
    comparison.max_mean_delta = maxMeanDelta;
  }
  return comparison;
}

async function verifyGenericIcon({ args, outDir, reportsDir, styleReport, styleReportPath, failures, warnings, generatedFilesManifestValidation }) {
  const expectedCanvas = Number(styleReport.canvas);
  if (!Number.isInteger(expectedCanvas) || expectedCanvas <= 0) {
    failures.push("style-report.json canvas must be a positive integer for generic verification");
  }
  const previewSvgName = requiredReportString(styleReport, "preview_svg", failures);
  const previewPngName = requiredReportString(styleReport, "preview_png", failures);
  const appSvgName = requiredReportString(styleReport, "app_svg", failures);
  const appPngName = requiredReportString(styleReport, "app_png", failures);

  for (const svgName of [previewSvgName, appSvgName].filter(Boolean)) {
    const svg = await readFile(inside(outDir, svgName), "utf8");
    if (!/<svg\b/i.test(svg)) {
      failures.push(`${svgName} is not an SVG document`);
    }
  }
  if (appSvgName) {
    const appSvg = await readFile(inside(outDir, appSvgName), "utf8");
    if (/<clipPath\b/i.test(appSvg) || /\sclip-path\s*=/i.test(appSvg)) {
      failures.push(`${appSvgName} must be an unrounded app/source canvas and must not contain a preview clipping mask`);
    }
  }

  const readSizedPng = async (name) => {
    if (!name) return null;
    const png = readPng(await readFile(inside(outDir, name)), name, failures);
    const stats = png ? pngStats(png) : null;
    if (stats && (stats.width !== expectedCanvas || stats.height !== expectedCanvas)) {
      failures.push(`${name} must be ${expectedCanvas}x${expectedCanvas}`);
    }
    if ((stats?.visible_pixels ?? 0) <= 0) {
      failures.push(`${name} has no visible pixels`);
    }
    return { png, stats };
  };
  const preview = await readSizedPng(previewPngName);
  const app = await readSizedPng(appPngName);

  for (const layerPath of styleReport.layers ?? []) {
    if (layerPath.endsWith(".svg")) {
      const svg = await readFile(inside(outDir, layerPath), "utf8");
      if (!/<svg\b/i.test(svg)) {
        failures.push(`${layerPath} is not an SVG document`);
      }
    } else if (layerPath.endsWith(".png")) {
      readPng(await readFile(inside(outDir, layerPath)), layerPath, failures);
    } else {
      failures.push(`${layerPath} must be .svg or .png`);
    }
  }

  const visualReview = await readOptionalJson(inside(outDir, resolve(reportsDir, "visual-review.json")));
  const referenceComparison =
    args.reference && preview.png
      ? await compareReference(outDir, reportsDir, preview.png, resolve(args.reference), args.maxMeanDelta, failures, warnings, {
          enforceMeanDelta: true,
        })
      : null;
  const outcome = {
    pixel_status: referenceComparison ? (failures.length === 0 ? "ok" : "failed") : "not_required",
    route_status: isRejectedVisualDecision(visualReview) ? "visual_review_rejected" : "generic_assets_ready",
    review_required: isRejectedVisualDecision(visualReview),
  };
  const verification = {
    status: failures.length === 0 ? "ok" : "failed",
    out: outDir,
    style_report: outputRelativePath(outDir, styleReportPath),
    reports_dir: outputRelativePath(outDir, reportsDir),
    target_platforms: styleReport.target_platforms ?? [],
    canvas: { width: expectedCanvas, height: expectedCanvas },
    preview_svg: previewSvgName,
    preview_png: preview.stats,
    app_svg: appSvgName,
    app_png: app.stats,
    generic_assets: { layers: styleReport.layers ?? [] },
    apple_adapter: null,
    generated_files_manifest_validation: generatedFilesManifestValidation,
    visual_review: visualReview,
    outcome,
    reference_comparison: referenceComparison,
    warnings,
    failures,
  };
  await writeFileInside(outDir, resolve(reportsDir, "package-verification.json"), `${JSON.stringify(verification, null, 2)}\n`, "utf8");
  if (failures.length > 0) {
    throw new Error(`generic icon verification failed: ${failures.join("; ")}`);
  }
  console.log(JSON.stringify(verification, null, 2));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const outDir = resolve(args.out);
  const failures = [];
  const warnings = [];

  const { styleReport, styleReportPath } = await readStyleReport(outDir);
  const reportsDir = dirname(styleReportPath);
  const generatedFilesManifestValidation = validateGeneratedFilesManifest(outDir, reportsDir, styleReport);
  failures.push(
    ...generatedFilesManifestValidation.problems.map((problem) => `generated files manifest: ${problem}`),
  );
  if (!styleReport.apple_adapter && !styleReport.icon_composer_bundle) {
    await verifyGenericIcon({
      args,
      outDir,
      reportsDir,
      styleReport,
      styleReportPath,
      failures,
      warnings,
      generatedFilesManifestValidation,
    });
    return;
  }
  const iconBundle = styleReport.icon_composer_bundle;
  if (!iconBundle || typeof iconBundle !== "string") {
    failures.push("style-report.json is missing icon_composer_bundle");
  }
  const iconJsonPath = iconBundle ? inside(outDir, `${iconBundle}/icon.json`) : null;
  const iconJson = iconJsonPath ? await readJson(iconJsonPath) : null;
  if (iconJson) {
    try {
      validateFill(iconJson.fill);
    } catch (error) {
      failures.push(String(error instanceof Error ? error.message : error).replace("spec.fill", "icon.json fill"));
    }
    if (styleReport.icon_composer_fill !== undefined && stableJson(iconJson.fill) !== stableJson(styleReport.icon_composer_fill)) {
      failures.push("icon.json fill does not match style-report.json icon_composer_fill");
    }
  }
  const decisions = styleReport.icon_composer_layer_decisions ?? [];
  const includedBackgroundDecisions = decisions
    .map((decision, index) => ({ decision, index }))
    .filter(({ decision }) => isBackgroundLikeLayerName(decision.layer));
  const duplicatedBackgroundDecisions = iconJson && iconJson.fill !== "automatic"
    ? includedBackgroundDecisions.filter(({ decision }) => !isComplexBackgroundDecision(decision))
    : [];
  if (duplicatedBackgroundDecisions.length > 0) {
    failures.push(
      `explicit icon.json fill must not be duplicated by simple background-like Icon Composer asset layers: ${duplicatedBackgroundDecisions
        .map(({ decision }) => decision.layer)
        .join(", ")}; mark a deliberate imported complex background with background_role "complex"`,
    );
  }
  for (const { decision, index } of includedBackgroundDecisions) {
    if (index !== 0) {
      failures.push(`background-like Icon Composer asset layer "${decision.layer}" must be first in bottom-to-top layer order`);
    }
  }
  if (
    decisions.length === 1 &&
    includedBackgroundDecisions.length === 1 &&
    isComplexBackgroundDecision(includedBackgroundDecisions[0].decision)
  ) {
    failures.push(
      "Icon Composer package contains only one full-artwork complex background asset; this is a rendered snapshot, not a layered Icon Composer composition. Keep full rendered baselines outside the .icon bundle, or add separated foreground layers over icon.json fill.",
    );
  }
  const semanticReview = styleReport.semantic_review ?? null;
  if (isSemanticSvgRoute(semanticReview)) {
    const foregroundDecisions = decisions.filter((decision) => !isBackgroundLikeLayerName(decision.layer));
    const hasSvgForeground = foregroundDecisions.some((decision) => decision.format === "svg");
    if (foregroundDecisions.length > 0 && !hasSvgForeground) {
      failures.push(
        `semantic-svg route "${semanticReview.route}" cannot package only PNG foreground assets; use SVG for vector-friendly foreground layers or reclassify the route as a documented PNG fallback.`,
      );
    }
  }

  const previewSvgName = requiredReportString(styleReport, "preview_svg", failures);
  const previewPngName = requiredReportString(styleReport, "preview_png", failures);
  const appSvgName = styleReport.app_svg ?? null;
  const appPngName = styleReport.app_png ?? null;

  if (previewSvgName) {
    const iconSvgPath = inside(outDir, previewSvgName);
    const iconSvg = await readFile(iconSvgPath, "utf8");
    if (!/<svg\b/i.test(iconSvg)) {
      failures.push(`${previewSvgName} is not an SVG document`);
    }
  }

  let iconPng = null;
  if (previewPngName) {
    const iconPngPath = inside(outDir, previewPngName);
    iconPng = readPng(await readFile(iconPngPath), previewPngName, failures);
  }
  const iconPngStats = iconPng ? pngStats(iconPng) : null;
  if (iconPngStats?.width !== DEFAULT_CANVAS || iconPngStats?.height !== DEFAULT_CANVAS) {
    failures.push(`${previewPngName} must be ${DEFAULT_CANVAS}x${DEFAULT_CANVAS}`);
  }
  if ((iconPngStats?.visible_pixels ?? 0) <= 0) {
    failures.push(`${previewPngName} has no visible pixels`);
  }

  if (appSvgName) {
    const appSvg = await readFile(inside(outDir, appSvgName), "utf8");
    if (!/<svg\b/i.test(appSvg)) {
      failures.push(`${appSvgName} is not an SVG document`);
    }
    if (/<clipPath\b/i.test(appSvg) || /\sclip-path\s*=/i.test(appSvg)) {
      failures.push(`${appSvgName} must be an unrounded app/source canvas and must not contain a preview clipping mask`);
    }
  }
  let appPngStats = null;
  if (appPngName) {
    const appPng = readPng(await readFile(inside(outDir, appPngName)), appPngName, failures);
    appPngStats = appPng ? pngStats(appPng) : null;
    if (appPngStats?.width !== DEFAULT_CANVAS || appPngStats?.height !== DEFAULT_CANVAS) {
      failures.push(`${appPngName} must be ${DEFAULT_CANVAS}x${DEFAULT_CANVAS}`);
    }
    if ((appPngStats?.visible_pixels ?? 0) <= 0) {
      failures.push(`${appPngName} has no visible pixels`);
    }
  }

  const includedSourceLayers = new Set((styleReport.icon_composer_layer_decisions ?? []).map((decision) => decision.source_layer).filter(Boolean));
  const inferredPreviewBackgrounds = (styleReport.layers ?? [])
    .filter((layerPath) => !includedSourceLayers.has(layerPath))
    .filter((layerPath) => isBackgroundLikeLayerName(layerPath));
  const previewBackgroundLayers =
    styleReport.preview_background_layers ?? inferredPreviewBackgrounds.map((sourceLayer) => ({ layer: sourceLayer, source_layer: sourceLayer }));
  for (const previewLayer of previewBackgroundLayers) {
    const sourceLayer = previewLayer.source_layer;
    if (!sourceLayer || !sourceLayer.endsWith(".svg")) {
      continue;
    }
    const sourceSvg = await readFile(inside(outDir, sourceLayer), "utf8");
    const consistency = previewOnlyBackgroundConsistency(sourceSvg, DEFAULT_CANVAS);
    if (!consistency.ok) {
      failures.push(
        `${sourceLayer} is a preview-only simple background that icon.json.fill cannot reproduce: ${consistency.reason}. Remove localized preview material or import a deliberate complex background layer.`,
      );
    }
  }

  for (const layerPath of styleReport.layers ?? []) {
    if (layerPath.endsWith(".svg")) {
      const layerSvg = await readFile(inside(outDir, layerPath), "utf8");
      if (!/<svg\b/i.test(layerSvg)) {
        failures.push(`${layerPath} is not an SVG document`);
      }
    } else if (layerPath.endsWith(".png")) {
      const layerPng = readPng(await readFile(inside(outDir, layerPath)), layerPath, failures);
      const stats = layerPng ? pngStats(layerPng) : null;
      if ((stats?.visible_pixels ?? 0) <= 0) {
        failures.push(`${layerPath} has no visible pixels`);
      }
    } else {
      failures.push(`${layerPath} must be .svg or .png`);
    }
  }

  const iconJsonLayers = iconJson?.groups?.flatMap((group) => group.layers ?? []) ?? [];
  const iconJsonAssetNames = iconJsonLayers.map((layer) => layer["image-name"]);
  const reportAssetNames = (styleReport.icon_composer_json_assets ?? styleReport.icon_composer_assets ?? []).map((asset) => asset.split("/").pop());
  if (JSON.stringify(iconJsonAssetNames) !== JSON.stringify(reportAssetNames)) {
    failures.push("icon.json layer image-name order does not match style-report.json Icon Composer JSON asset order");
  }
  const pngLayerHygieneReports = [];
  const svgMaterialWarnings = [];
  const decisionsByAsset = new Map(
    (styleReport.icon_composer_layer_decisions ?? [])
      .filter((decision) => decision?.asset)
      .map((decision) => [decision.asset, decision]),
  );

  for (const assetPath of styleReport.icon_composer_assets ?? []) {
    const assetFullPath = inside(outDir, assetPath);
    if (assetPath.endsWith(".svg")) {
      const assetSvg = await readFile(assetFullPath, "utf8");
      validateImportedSvg(assetPath, assetSvg, failures);
      const materialWarning = inspectImportedSvgMaterial(assetPath, assetSvg, decisionsByAsset.get(assetPath));
      if (materialWarning) {
        svgMaterialWarnings.push(materialWarning);
        warnings.push(
          `${assetPath} may contain baked material effects (${materialWarning.indicators.join(", ")}); keep Icon Composer foreground SVG assets as clean base shapes unless this is a reviewed exception`,
        );
      }
    } else if (assetPath.endsWith(".png")) {
      const assetPng = readPng(await readFile(assetFullPath), assetPath, failures);
      const stats = assetPng ? pngStats(assetPng) : null;
      if ((stats?.visible_pixels ?? 0) <= 0) {
        failures.push(`${assetPath} has no visible pixels`);
      }
    } else {
      failures.push(`${assetPath} must be .svg or .png`);
    }
  }

  for (const decision of styleReport.icon_composer_layer_decisions ?? []) {
    const sourceLayer = decision.source_layer;
    const asset = decision.asset;
    validatePngFallbackDecisionEvidence(decision, failures);
    if (!sourceLayer || !asset) {
      failures.push(`decision for layer ${decision.layer ?? "(unknown)"} is missing source_layer or asset`);
      continue;
    }
    if (sourceLayer.endsWith(".svg")) {
      const sourceSvg = await readFile(inside(outDir, sourceLayer), "utf8");
      const containsText = /<text\b/i.test(sourceSvg);
      const containsImage = /<image\b/i.test(sourceSvg);
      if ((containsText || containsImage) && decision.format !== "png") {
        failures.push(`${sourceLayer} contains text/image and must map to a PNG Icon Composer asset`);
      }
      if (containsText && (!decision.text_rendering?.font_family || !decision.text_rendering?.render_method)) {
        failures.push(`${sourceLayer} contains text and needs text_rendering.font_family and text_rendering.render_method`);
      }
    } else if (sourceLayer.endsWith(".png")) {
      const sourcePng = readPng(await readFile(inside(outDir, sourceLayer)), sourceLayer, failures);
      const stats = sourcePng ? pngStats(sourcePng) : null;
      if ((stats?.visible_pixels ?? 0) <= 0) {
        failures.push(`${sourceLayer} has no visible pixels`);
      }
      if (decision.format !== "png") {
        failures.push(`${sourceLayer} is a PNG source layer and must map to a PNG Icon Composer asset`);
      }
    } else {
      failures.push(`${sourceLayer} must be .svg or .png`);
    }
    if (decision.format === "png" && !asset.endsWith(".png")) {
      failures.push(`decision for ${decision.layer} says PNG but asset is not .png`);
    }
    if (decision.format === "svg" && !asset.endsWith(".svg")) {
      failures.push(`decision for ${decision.layer} says SVG but asset is not .svg`);
    }
    if (decision.format === "png" && asset.endsWith(".png")) {
      const assetPng = readPng(await readFile(inside(outDir, asset)), asset, failures);
      if (assetPng) {
        const hygiene = pngLayerHygiene(assetPng);
        const report = {
          layer: decision.layer,
          asset,
          source_layer: sourceLayer,
          background_like: isBackgroundLikeLayerName(decision.layer),
          ...hygiene,
        };
        pngLayerHygieneReports.push(report);
        validatePngFallbackHygiene(asset, decision, hygiene, failures);
        warnOnSuspiciousPngFallback(asset, decision, hygiene, warnings);
      }
    }
  }

  if ((styleReport.layers?.length ?? 0) < 2 || (styleReport.layers?.length ?? 0) > 8) {
    warnings.push("recommended package shape is 2-5 semantic layers, or at most 8 for an explicit bounded pane/sticker style");
  }

  const acceptance = styleReport.acceptance ?? null;
  const sourceAnalysis = styleReport.source_analysis ?? null;
  const sourceAnalysisValidation = validateSourceAnalysisContract(sourceAnalysis, styleReport.icon_composer_layer_decisions ?? []);
  let visualReview = await readOptionalJson(inside(outDir, resolve(reportsDir, "visual-review.json")));
  if (!visualReview && reportsDir !== outDir) {
    visualReview = await readOptionalJson(inside(outDir, "visual-review.json"));
  }
  const referenceComparison =
    args.reference && iconPng
      ? await compareReference(outDir, reportsDir, iconPng, resolve(args.reference), args.maxMeanDelta, failures, warnings, {
          enforceMeanDelta: !isAcceptedApproximation(semanticReview),
        })
      : null;
  const appleExportsValidation = await validateAppleExports(outDir, styleReport, failures);
  const outcome = routeAssessment({
    semanticReview,
    sourceAnalysisValidation,
    referenceComparison,
    assetFormat: styleReport.icon_composer_asset_format,
    warnings,
    failures,
    acceptance,
    visualReview,
    deliverableType: styleReport.deliverable_type ?? "icon-composer-package",
  });

  const verification = {
    status: failures.length === 0 ? "ok" : "failed",
    out: outDir,
    style_report: outputRelativePath(outDir, styleReportPath),
    reports_dir: outputRelativePath(outDir, reportsDir),
    target_platforms: styleReport.target_platforms,
    deliverable_type: styleReport.deliverable_type,
    preview_svg: previewSvgName,
    preview_png: iconPngStats,
    app_svg: appSvgName,
    app_png: appPngStats,
    icon_composer_bundle: iconBundle,
    apple_adapter: styleReport.apple_adapter ?? { bundle: iconBundle, exports: styleReport.apple_exports },
    generated_files_manifest_validation: generatedFilesManifestValidation,
    checked_assets: styleReport.icon_composer_assets ?? [],
    icon_composer_layer_decisions: styleReport.icon_composer_layer_decisions ?? [],
    svg_material_warnings: svgMaterialWarnings,
    png_layer_hygiene: pngLayerHygieneReports,
    semantic_review: semanticReview,
    source_analysis: sourceAnalysis,
    source_analysis_validation: sourceAnalysisValidation,
    acceptance,
    visual_review: visualReview,
    apple_exports_validation: appleExportsValidation,
    outcome,
    reference_comparison: referenceComparison,
    warnings,
    failures,
  };
  await writeFileInside(outDir, resolve(reportsDir, "package-verification.json"), `${JSON.stringify(verification, null, 2)}\n`, "utf8");

  if (failures.length > 0) {
    throw new Error(`package verification failed: ${failures.join("; ")}`);
  }
  console.log(JSON.stringify(verification, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
