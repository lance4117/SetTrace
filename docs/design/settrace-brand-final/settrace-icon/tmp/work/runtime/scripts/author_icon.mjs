#!/usr/bin/env node
import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { access, lstat, mkdir, open, readFile, readdir, realpath, rename, rm, rmdir } from "node:fs/promises";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";
import { promisify } from "node:util";
import { Resvg } from "@resvg/resvg-js";
import { APPLE_EXPORT_SCALE, appleExportProfilesForTargets } from "./lib/apple_export_profiles.mjs";
import {
  PNG_FALLBACK_CATEGORIES,
  PNG_FALLBACK_ROUTES,
  backgroundImportRole,
  hasExplicitFill,
  hasFullCanvasRoundedRect,
  isBackgroundLikeLayerName,
  isComplexBackgroundImport,
  isVaguePngFallbackReason,
  previewOnlyBackgroundConsistency,
  validateFill,
} from "./lib/icon_contract.mjs";

const DEFAULT_CANVAS = 1024;
const DEFAULT_RADIUS = 224;
const APPLE_TARGET_PLATFORMS = new Set(["iOS", "iPadOS", "macOS", "watchOS"]);
const APPLE_DELIVERABLE_TYPES = new Set(["icon-composer-package", "rendered-review-assets"]);
const COMPOSER_APPEARANCES = new Set(["dark", "tinted"]);
const COMPOSER_BLEND_MODES = new Set(["normal", "multiply", "screen", "plus-lighter", "plus-darker"]);
const COMPOSER_LIGHTING = new Set(["individual", "combined"]);
const COMPOSER_SHADOW_KINDS = new Set(["neutral", "none"]);
const COMPOSER_FEATURES = new Set(["refractivity", "specular-location"]);
const execFileAsync = promisify(execFile);
const SEMANTIC_REVIEW_STATUSES = new Set([
  "exact-enough",
  "visually-close",
  "needs-source-vector",
  "png-fallback-recommended",
  "redesign-needed",
  "accepted-approximation",
]);
const SEMANTIC_REVIEW_ROUTES = new Set([
  "semantic-svg",
  "semantic-svg-approximation",
  "png-fallback",
  "png-fallback-recommended",
  "needs-source-vector",
  "style-only-approximation",
  "redesign-needed",
  "accepted-approximation",
]);
function usage() {
  console.error("Usage: node scripts/author_icon.mjs --spec SPEC_JSON --out OUT");
}

function parseArgs(argv) {
  const parsed = { layout: "delivery" };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--spec") {
      parsed.spec = next;
      i += 1;
    } else if (arg === "--out") {
      parsed.out = next;
      i += 1;
    } else if (arg === "--layout") {
      parsed.layout = next;
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.spec || !parsed.out) {
    throw new Error("--spec and --out are required");
  }
  if (parsed.layout === "classic") {
    parsed.layout = "package";
  }
  if (!["package", "delivery"].includes(parsed.layout)) {
    throw new Error("--layout must be package or delivery");
  }
  return parsed;
}

async function pathStat(path) {
  try {
    return await lstat(path);
  } catch (error) {
    if (error?.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

async function realCandidate(path) {
  let cursor = resolve(path);
  const missingParts = [];
  while (true) {
    try {
      const existing = await realpath(cursor);
      return resolve(existing, ...missingParts.reverse());
    } catch (error) {
      if (error?.code !== "ENOENT") {
        throw error;
      }
      const parent = dirname(cursor);
      if (parent === cursor) {
        throw error;
      }
      missingParts.push(basename(cursor));
      cursor = parent;
    }
  }
}

async function assertSafeOutDir(outDir) {
  const normalized = resolve(outDir);
  const stat = await pathStat(normalized);
  if (stat?.isSymbolicLink()) {
    throw new Error(`refusing symlink output directory: ${normalized}`);
  }
  if (stat && !stat.isDirectory()) {
    throw new Error(`output path must be a directory: ${normalized}`);
  }

  const canonical = await realCandidate(normalized);
  const forbidden = [await realCandidate("/"), await realCandidate(process.cwd())];
  if (process.env.HOME) {
    forbidden.push(await realCandidate(process.env.HOME));
  }
  if (forbidden.includes(canonical)) {
    throw new Error(`refusing to replace unsafe output directory: ${canonical}`);
  }
  if (canonical.split(/[\\/]+/).filter(Boolean).length < 3) {
    throw new Error(`refusing to replace shallow output directory: ${canonical}`);
  }
  return stat;
}

function normalizeRelativePath(relPath) {
  return relPath.split(/[\\/]+/).filter(Boolean).join("/");
}

function preserveRelationship(relPath, preserveRelPaths) {
  const normalized = normalizeRelativePath(relPath);
  for (const preserveRelPath of preserveRelPaths) {
    if (normalized === preserveRelPath) {
      return "self";
    }
    if (normalized.startsWith(`${preserveRelPath}/`)) {
      return "child";
    }
    if (preserveRelPath.startsWith(`${normalized}/`)) {
      return "ancestor";
    }
  }
  return "none";
}

function safeRelativeOutputPath(outDir, relPath) {
  if (
    typeof relPath !== "string" ||
    relPath.trim() === "" ||
    relPath.trim() !== relPath ||
    relPath.includes("\\") ||
    isAbsolute(relPath)
  ) {
    throw new Error(`invalid generated output path: ${relPath}`);
  }
  const parts = relPath.split("/");
  if (parts.some((part) => part === "" || part === "." || part === "..")) {
    throw new Error(`invalid generated output path: ${relPath}`);
  }
  const normalized = parts.join("/");
  const fullPath = resolve(outDir, normalized);
  const rel = relative(outDir, fullPath);
  if (rel.startsWith("..") || rel === "") {
    throw new Error(`generated output path escapes output directory: ${relPath}`);
  }
  return { normalized, fullPath };
}

async function assertNoSymlinkAncestors(outDir, targetPath, { allowFinalSymlink = false } = {}) {
  const rel = relative(outDir, targetPath);
  if (rel.startsWith("..") || isAbsolute(rel)) {
    throw new Error(`path escapes output directory: ${targetPath}`);
  }
  let current = outDir;
  const parts = rel.split(/[\\/]+/).filter(Boolean);
  for (const [index, part] of parts.entries()) {
    current = resolve(current, part);
    const stat = await pathStat(current);
    if (!stat) {
      return;
    }
    const isFinal = index === parts.length - 1;
    if (stat.isSymbolicLink() && !(isFinal && allowFinalSymlink)) {
      throw new Error(`refusing symlink inside output directory: ${current}`);
    }
  }
}

async function assertOutputTargetsAvailable(outDir, { directories = [], files = [], replaceableFiles = [] }) {
  const replaceable = new Set(replaceableFiles.map((path) => resolve(path)));
  for (const directory of [...new Set(directories.map((path) => resolve(path)))]) {
    await assertNoSymlinkAncestors(outDir, directory);
    const stat = await pathStat(directory);
    if (stat && !stat.isDirectory()) {
      throw new Error(`output directory target is occupied by a non-directory: ${directory}`);
    }
  }
  for (const file of [...new Set(files.map((path) => resolve(path)))]) {
    await assertNoSymlinkAncestors(outDir, file);
    const stat = await pathStat(file);
    if (!stat) {
      continue;
    }
    if (replaceable.has(file) && stat.isFile()) {
      continue;
    }
    throw new Error(`refusing to overwrite unowned output path: ${file}`);
  }
}

async function writeOutputFile(outDir, targetPath, data, encoding = null, { replaceExisting = false } = {}) {
  const fullPath = resolve(targetPath);
  await assertNoSymlinkAncestors(outDir, fullPath);
  const canonicalRoot = await realpath(outDir);
  const canonicalParent = await realpath(dirname(fullPath));
  const parentRel = relative(canonicalRoot, canonicalParent);
  if (parentRel.startsWith("..") || isAbsolute(parentRel)) {
    throw new Error(`write path escapes output directory: ${fullPath}`);
  }
  const flags = constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | (constants.O_NOFOLLOW ?? 0);
  if (!replaceExisting) {
    const handle = await open(fullPath, flags, 0o666);
    try {
      await handle.writeFile(data, encoding ? { encoding } : undefined);
    } finally {
      await handle.close();
    }
    return;
  }

  const temporaryPath = resolve(dirname(fullPath), `.${basename(fullPath)}.tmp-${randomUUID()}`);
  await assertNoSymlinkAncestors(outDir, temporaryPath);
  let handle = null;
  try {
    handle = await open(temporaryPath, flags, 0o666);
    await handle.writeFile(data, encoding ? { encoding } : undefined);
    await handle.close();
    handle = null;
    await assertNoSymlinkAncestors(outDir, fullPath);
    await rename(temporaryPath, fullPath);
  } finally {
    await handle?.close();
    await rm(temporaryPath, { force: true });
  }
}

async function containsOnlyPreservedContent(outDir, preserveRelPaths, relPath = "") {
  const dir = relPath ? resolve(outDir, relPath) : outDir;
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const childRelPath = relPath ? join(relPath, entry.name) : entry.name;
    const relationship = preserveRelationship(childRelPath, preserveRelPaths);
    if (relationship === "self" || relationship === "child") {
      continue;
    }
    if (relationship === "ancestor" && entry.isDirectory() && !entry.isSymbolicLink()) {
      if (!(await containsOnlyPreservedContent(outDir, preserveRelPaths, childRelPath))) {
        return false;
      }
      continue;
    }
    return false;
  }
  return true;
}

function expectedGeneratedFilesForReport(styleReport, outDir, layout) {
  const reportName = upperCamel(styleReport.name);
  const outputs = outputNames({ name: reportName }, layout);
  const bundle = `${reportName}.icon`;
  const appleAdapter = styleReport.apple_adapter;
  const layers = (Array.isArray(styleReport.layers) ? styleReport.layers : []).filter((path) =>
    /^layers\/[^/]+\.(?:svg|png)$/i.test(path),
  );
  const assets = appleAdapter
    ? (Array.isArray(styleReport.icon_composer_assets) ? styleReport.icon_composer_assets : []).filter((path) =>
        path.startsWith(`${bundle}/Assets/`) &&
        !path.slice(`${bundle}/Assets/`.length).includes("/") &&
        /\.(?:svg|png)$/i.test(path),
      )
    : [];
  const appleFiles =
    appleAdapter?.exports?.status === "generated" && Array.isArray(styleReport.target_platforms)
      ? appleExportProfilesForTargets(styleReport.target_platforms).flatMap((profile) =>
          profile.renditions.map((rendition) => `apple/${profile.platform}/${rendition.name}.png`),
        )
      : [];
  const reportNames = [
    "style-report.json",
    "package-verification.json",
    "reference-diff.png",
    "reference-overlay.png",
    "reference-side-by-side.png",
    "visual-review.json",
  ];
  return [
    outputs.previewSvg,
    outputs.previewPng,
    outputs.appSvg,
    outputs.appPng,
    ...layers,
    ...(appleAdapter ? [`${bundle}/icon.json`] : []),
    ...assets,
    ...appleFiles,
    normalizeRelativePath(relative(outDir, layout.readmePath)),
    ...reportNames.map((name) => normalizeRelativePath(relative(outDir, resolve(layout.reportsDir, name)))),
  ].filter(Boolean);
}

function setDifference(left, right) {
  const rightSet = new Set(right);
  return [...new Set(left)].filter((value) => !rightSet.has(value));
}

async function validatedGeneratedFilesManifest(styleReport, outDir, layout, preserveRelPaths) {
  if (!Array.isArray(styleReport.generated_files) || styleReport.generated_files.length === 0) {
    throw new Error("owned style report must contain a non-empty generated_files leaf manifest");
  }

  const generatedFiles = [];
  const seen = new Set();
  for (const entry of styleReport.generated_files) {
    if (typeof entry !== "string" || entry.trim() === "") {
      throw new Error("generated_files entries must be non-empty relative file paths");
    }
    const { normalized, fullPath } = safeRelativeOutputPath(outDir, entry);
    if (entry !== normalized) {
      throw new Error(`generated_files entry must use its normalized relative form: ${entry}`);
    }
    if (seen.has(normalized)) {
      throw new Error(`generated_files contains a duplicate entry: ${normalized}`);
    }
    if (preserveRelationship(normalized, preserveRelPaths) !== "none") {
      throw new Error(`generated_files must not claim preserved output content: ${normalized}`);
    }
    await assertNoSymlinkAncestors(outDir, fullPath);
    const stat = await pathStat(fullPath);
    if (stat?.isDirectory()) {
      throw new Error(`generated_files must contain leaf files, not directories: ${normalized}`);
    }
    seen.add(normalized);
    generatedFiles.push(normalized);
  }

  const expectedFiles = expectedGeneratedFilesForReport(styleReport, outDir, layout);
  const unexpectedFiles = setDifference(generatedFiles, expectedFiles);
  const missingFiles = setDifference(expectedFiles, generatedFiles);
  if (unexpectedFiles.length > 0 || missingFiles.length > 0) {
    throw new Error(
      `generated_files does not match the safe report-derived leaf set` +
        `${unexpectedFiles.length > 0 ? `; unexpected: ${unexpectedFiles.join(", ")}` : ""}` +
        `${missingFiles.length > 0 ? `; missing: ${missingFiles.join(", ")}` : ""}`,
    );
  }

  const expectedDirectories = reportGeneratedDirectories(generatedFiles);
  if (!Array.isArray(styleReport.generated_directories)) {
    throw new Error("owned style report must contain generated_directories derived from generated_files");
  }
  const generatedDirectories = [];
  for (const entry of styleReport.generated_directories) {
    if (typeof entry !== "string" || entry.trim() === "") {
      throw new Error("generated_directories entries must be non-empty relative directory paths");
    }
    const { normalized } = safeRelativeOutputPath(outDir, entry);
    if (entry !== normalized || generatedDirectories.includes(normalized)) {
      throw new Error(`generated_directories contains a non-normalized or duplicate entry: ${entry}`);
    }
    generatedDirectories.push(normalized);
  }
  const unexpectedDirectories = setDifference(generatedDirectories, expectedDirectories);
  const missingDirectories = setDifference(expectedDirectories, generatedDirectories);
  if (unexpectedDirectories.length > 0 || missingDirectories.length > 0) {
    throw new Error("generated_directories must exactly match the directories derived from generated_files");
  }

  return generatedFiles;
}

function directoriesForFiles(files) {
  const directories = new Set();
  for (const file of files) {
    let directory = normalizeRelativePath(dirname(file));
    while (directory && directory !== ".") {
      directories.add(directory);
      const parent = normalizeRelativePath(dirname(directory));
      if (!parent || parent === "." || parent === directory) {
        break;
      }
      directory = parent;
    }
  }
  return [...directories].sort((a, b) => b.split("/").length - a.split("/").length);
}

function reportGeneratedDirectories(generatedFiles) {
  return directoriesForFiles(generatedFiles);
}

async function readOwnedStyleReport(outDir, layout) {
  await assertNoSymlinkAncestors(outDir, layout.styleReportPath);
  const stat = await pathStat(layout.styleReportPath);
  if (!stat?.isFile()) {
    return null;
  }
  try {
    const report = JSON.parse(await readFile(layout.styleReportPath, "utf8"));
    if (report?.mode !== "icon-spec-authoring" || report?.layout !== layout.layout) {
      return null;
    }
    return report;
  } catch {
    return null;
  }
}

async function removeManifestFiles(outDir, paths, preserveRelPaths = []) {
  for (const relPath of [...new Set(paths)].filter(Boolean)) {
    const { normalized, fullPath } = safeRelativeOutputPath(outDir, relPath);
    if (preserveRelationship(normalized, preserveRelPaths) !== "none") {
      continue;
    }
    await assertNoSymlinkAncestors(outDir, fullPath, { allowFinalSymlink: true });
    const stat = await pathStat(fullPath);
    if (!stat) {
      continue;
    }
    if (stat.isDirectory()) {
      throw new Error(`refusing to recursively remove manifest file path that is now a directory: ${fullPath}`);
    }
    await rm(fullPath, { force: true });
  }
}

async function pruneManifestDirectories(outDir, directories, preserveRelPaths = []) {
  for (const relPath of [...new Set(directories)].filter(Boolean).sort((a, b) => b.split("/").length - a.split("/").length)) {
    const { normalized, fullPath } = safeRelativeOutputPath(outDir, relPath);
    if (preserveRelationship(normalized, preserveRelPaths) !== "none") {
      continue;
    }
    const stat = await pathStat(fullPath);
    if (!stat || stat.isSymbolicLink() || !stat.isDirectory()) {
      continue;
    }
    try {
      await rmdir(fullPath);
    } catch (error) {
      if (!["ENOENT", "ENOTEMPTY"].includes(error?.code)) {
        throw error;
      }
    }
  }
}

async function prepareOutputDir(outDir, layout) {
  const stat = await assertSafeOutDir(outDir);
  if (!stat) {
    return;
  }
  const entries = await readdir(outDir);
  if (entries.length === 0) {
    return;
  }

  const preserveRelPaths = layout.preserveRelPaths.map(normalizeRelativePath);
  for (const preserveRelPath of preserveRelPaths) {
    const { fullPath } = safeRelativeOutputPath(outDir, preserveRelPath);
    await assertNoSymlinkAncestors(outDir, fullPath);
  }
  const ownedReport = await readOwnedStyleReport(outDir, layout);
  if (ownedReport) {
    const generatedFiles = await validatedGeneratedFilesManifest(ownedReport, outDir, layout, preserveRelPaths);
    await removeManifestFiles(outDir, generatedFiles, preserveRelPaths);
    await pruneManifestDirectories(outDir, reportGeneratedDirectories(generatedFiles), preserveRelPaths);
    return;
  }
  if (await containsOnlyPreservedContent(outDir, preserveRelPaths)) {
    return;
  }
  throw new Error(`refusing to replace non-empty unowned output directory: ${outDir}`);
}

function upperCamel(value) {
  return String(value)
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((part) => `${part[0].toUpperCase()}${part.slice(1)}`)
    .join("") || "AppIcon";
}

function safeName(value) {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "layer";
}

function svgDocument(content, defs = "", canvas = DEFAULT_CANVAS) {
  return `<svg width="${canvas}" height="${canvas}" viewBox="0 0 ${canvas} ${canvas}" fill="none" xmlns="http://www.w3.org/2000/svg">
${defs ? `<defs>${defs}</defs>` : ""}
${content}
</svg>
`;
}

function renderOptions(spec, { background = "transparent", width = DEFAULT_CANVAS } = {}) {
  return {
    background,
    fitTo: { mode: "width", value: width },
    font: {
      fontFiles: spec.fontFiles,
      loadSystemFonts: true,
      defaultFontFamily: spec.defaultFontFamily,
    },
  };
}

function escapeAttr(value) {
  return String(value).replace(/&/g, "&amp;").replace(/"/g, "&quot;");
}

function readSvgParts(layer, canvas, baseDir) {
  const pngSource = layer.png ?? layer.source_png;
  if (pngSource != null) {
    if (layer.svg != null) {
      throw new Error(`layer ${layer.name ?? "(unnamed)"} cannot define both svg and png`);
    }
    const imagePath = resolve(baseDir, String(pngSource));
    return {
      content: `<image href="${escapeAttr(imagePath)}" width="${canvas}" height="${canvas}"/>`,
      defs: "",
      pngSource: true,
    };
  }
  if (typeof layer.svg === "string") {
    return { content: layer.svg, defs: layer.defs ?? "", pngSource: false };
  }
  if (layer.svg && typeof layer.svg === "object" && typeof layer.svg.content === "string") {
    return { content: layer.svg.content, defs: layer.svg.defs ?? layer.defs ?? "", pngSource: false };
  }
  throw new Error(`layer ${layer.name ?? "(unnamed)"} must define svg as a string, svg as { content, defs }, or png as a source image path`);
}

function validateComposerSvg(layerName, svg, canvas) {
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
  const hit = banned.find(([pattern]) => pattern.test(svg));
  if (hit) {
    throw new Error(`layer ${layerName} cannot import as Icon Composer SVG because it contains ${hit[1]}; use composer.format "png"`);
  }
  if (hasFullCanvasRoundedRect(svg, canvas)) {
    throw new Error(`layer ${layerName} cannot import a full-canvas rounded mask as Icon Composer SVG; keep masks only in local preview or use PNG`);
  }
}

function collectIds(svg) {
  return [...svg.matchAll(/\sid\s*=\s*["']([^"']+)["']/gi)].map((match) => match[1]);
}

function normalizePngFallbackEvidence(rawEvidence, layerName) {
  if (rawEvidence == null) {
    return null;
  }
  if (typeof rawEvidence !== "object" || Array.isArray(rawEvidence)) {
    throw new Error(`layer ${layerName} png_fallback_evidence must be an object`);
  }
  const category = String(rawEvidence.category ?? "").trim();
  const svgRoute = String(rawEvidence.svg_route ?? rawEvidence.svgRoute ?? "").trim();
  const evidence = String(rawEvidence.evidence ?? "").trim();
  const cleanlinessCheck = String(rawEvidence.cleanliness_check ?? rawEvidence.cleanlinessCheck ?? "").trim();
  if (!PNG_FALLBACK_CATEGORIES.has(category)) {
    throw new Error(`layer ${layerName} png_fallback_evidence.category must be one of: ${[...PNG_FALLBACK_CATEGORIES].join(", ")}`);
  }
  if (!PNG_FALLBACK_ROUTES.has(svgRoute)) {
    throw new Error(`layer ${layerName} png_fallback_evidence.svg_route must be one of: ${[...PNG_FALLBACK_ROUTES].join(", ")}`);
  }
  if (evidence.length < 16) {
    throw new Error(`layer ${layerName} png_fallback_evidence.evidence must describe the concrete per-layer reason`);
  }
  if (cleanlinessCheck.length < 16) {
    throw new Error(`layer ${layerName} png_fallback_evidence.cleanliness_check must describe isolated PNG inspection`);
  }
  return {
    category,
    svg_route: svgRoute,
    evidence,
    cleanliness_check: cleanlinessCheck,
  };
}

function normalizeSemanticReview(rawReview) {
  if (rawReview == null) {
    return null;
  }
  if (typeof rawReview !== "object" || Array.isArray(rawReview)) {
    throw new Error("spec.semantic_review must be an object when provided");
  }
  const status = String(rawReview.status ?? "");
  if (!SEMANTIC_REVIEW_STATUSES.has(status)) {
    throw new Error(`spec.semantic_review.status must be one of: ${[...SEMANTIC_REVIEW_STATUSES].join(", ")}`);
  }
  const basis = rawReview.basis ? String(rawReview.basis).trim() : "";
  if (status !== "exact-enough" && !basis) {
    throw new Error("spec.semantic_review.basis is required when status is not exact-enough");
  }
  const route = rawReview.route ? String(rawReview.route).trim() : status === "exact-enough" ? "semantic-svg" : "";
  if (!route) {
    throw new Error("spec.semantic_review.route is required when semantic_review is provided");
  }
  if (!SEMANTIC_REVIEW_ROUTES.has(route)) {
    throw new Error(`spec.semantic_review.route must be one of: ${[...SEMANTIC_REVIEW_ROUTES].join(", ")}`);
  }
  return {
    status,
    identity_risk: rawReview.identity_risk ? String(rawReview.identity_risk) : "not-recorded",
    basis,
    route,
    notes: rawReview.notes ? String(rawReview.notes) : "",
  };
}

function nonEmptyStringList(value, path) {
  if (!Array.isArray(value) || value.length === 0 || value.some((item) => typeof item !== "string" || item.trim() === "")) {
    throw new Error(`${path} must be a non-empty array of strings`);
  }
  return value.map((item) => item.trim());
}

const ALLOWED_SOURCE_VECTOR_PROVENANCE = new Set([
  "user-provided",
  "project-local",
  "generated-in-task",
  "official-user-approved",
]);

function optionalString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeSourceAnalysis(rawAnalysis, layers, semanticReview) {
  const needsAnalysis =
    semanticReview &&
    (semanticReview.status !== "exact-enough" || semanticReview.identity_risk === "medium" || semanticReview.identity_risk === "high");
  if (rawAnalysis == null) {
    if (needsAnalysis) {
      throw new Error("spec.source_analysis is required for identity-sensitive or approximate semantic review");
    }
    return null;
  }
  if (typeof rawAnalysis !== "object" || Array.isArray(rawAnalysis)) {
    throw new Error("spec.source_analysis must be an object when provided");
  }
  const components = rawAnalysis.components;
  if (!Array.isArray(components) || components.length === 0) {
    throw new Error("spec.source_analysis.components must be a non-empty array");
  }
  const normalizedComponents = components.map((component, index) => {
    if (!component || typeof component !== "object" || Array.isArray(component)) {
      throw new Error(`spec.source_analysis.components[${index}] must be an object`);
    }
    const id = component.id ? String(component.id).trim() : "";
    const layer = component.layer ? String(component.layer).trim() : "";
    const format = component.format ? String(component.format).trim() : "";
    if (!id || !layer || !["svg", "png", "mixed", "not-imported"].includes(format)) {
      throw new Error(`spec.source_analysis.components[${index}] must include id, layer, and format`);
    }
    const normalized = {
      id,
      layer,
      format,
      spec_constraints: Array.isArray(component.spec_constraints)
        ? component.spec_constraints.map((item) => String(item).trim()).filter(Boolean)
        : [],
    };
    const sourceVector = optionalString(component.source_vector);
    if (sourceVector) {
      const sourceProvenance = optionalString(component.source_provenance);
      const alignmentBasis = optionalString(component.alignment_basis);
      if (!sourceProvenance || !ALLOWED_SOURCE_VECTOR_PROVENANCE.has(sourceProvenance)) {
        throw new Error(
          `spec.source_analysis.components[${index}].source_provenance must be one of ${[...ALLOWED_SOURCE_VECTOR_PROVENANCE].join(", ")} when source_vector is used`,
        );
      }
      if (/^https?:\/\//i.test(sourceVector) && sourceProvenance !== "official-user-approved") {
        throw new Error(`spec.source_analysis.components[${index}].source_vector uses a web URL; only official-user-approved web vectors are allowed`);
      }
      if (!alignmentBasis) {
        throw new Error(`spec.source_analysis.components[${index}].alignment_basis is required when source_vector is used`);
      }
      normalized.source_vector = sourceVector;
      normalized.source_provenance = sourceProvenance;
      normalized.alignment_basis = alignmentBasis;
    }
    return normalized;
  });
  const componentLayers = new Set(normalizedComponents.map((component) => component.layer));
  for (const layer of layers.filter((item) => item.includeInComposer)) {
    if (!componentLayers.has(layer.name)) {
      throw new Error(`spec.source_analysis.components must include included layer "${layer.name}"`);
    }
  }
  return {
    fidelity_target: rawAnalysis.fidelity_target ? String(rawAnalysis.fidelity_target).trim() : "not-recorded",
    identity_risk: rawAnalysis.identity_risk ? String(rawAnalysis.identity_risk).trim() : semanticReview?.identity_risk ?? "not-recorded",
    route: rawAnalysis.route ? String(rawAnalysis.route).trim() : semanticReview?.route ?? "not-recorded",
    must_preserve: nonEmptyStringList(rawAnalysis.must_preserve, "spec.source_analysis.must_preserve"),
    must_not_add: nonEmptyStringList(rawAnalysis.must_not_add, "spec.source_analysis.must_not_add"),
    components: normalizedComponents,
    acceptance_checks: nonEmptyStringList(rawAnalysis.acceptance_checks, "spec.source_analysis.acceptance_checks"),
  };
}

function normalizeAcceptance(rawAcceptance) {
  if (rawAcceptance == null) {
    return null;
  }
  if (typeof rawAcceptance !== "object" || Array.isArray(rawAcceptance)) {
    throw new Error("spec.acceptance must be an object when provided");
  }
  const acceptedBy = rawAcceptance.accepted_by ? String(rawAcceptance.accepted_by).trim() : "";
  if (!["user", "human", "independent_visual_review"].includes(acceptedBy)) {
    throw new Error('spec.acceptance.accepted_by must be "user", "human", or "independent_visual_review"');
  }
  const evidence = rawAcceptance.evidence ? String(rawAcceptance.evidence).trim() : "";
  const scope = rawAcceptance.scope ? String(rawAcceptance.scope).trim() : "";
  if (!evidence || !scope) {
    throw new Error("spec.acceptance.evidence and spec.acceptance.scope are required");
  }
  return {
    accepted_by: acceptedBy,
    evidence,
    scope,
  };
}

function requirePlainObject(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
}

function normalizeOptionalBoolean(value, label) {
  if (value == null) {
    return undefined;
  }
  if (typeof value !== "boolean") {
    throw new Error(`${label} must be a boolean`);
  }
  return value;
}

function normalizeFiniteNumber(value, label, { min = -Infinity, max = Infinity } = {}) {
  const normalized = Number(value);
  if (!Number.isFinite(normalized) || normalized < min || normalized > max) {
    throw new Error(`${label} must be a finite number between ${min} and ${max}`);
  }
  return normalized;
}

function normalizeOptionalFiniteNumber(value, label, range) {
  return value == null ? undefined : normalizeFiniteNumber(value, label, range);
}

function normalizeBlendMode(value, label) {
  if (typeof value !== "string" || !COMPOSER_BLEND_MODES.has(value)) {
    throw new Error(`${label} must be one of: ${[...COMPOSER_BLEND_MODES].join(", ")}`);
  }
  return value;
}

function normalizeOptionalBlendMode(value, label) {
  return value == null ? undefined : normalizeBlendMode(value, label);
}

function normalizeSpecular(value, label) {
  if (typeof value !== "boolean" && value !== "inside" && value !== "outside") {
    throw new Error(`${label} must be true, false, "inside", or "outside"`);
  }
  return value;
}

function normalizePosition(value, label) {
  requirePlainObject(value, label);
  const translation = value["translation-in-points"];
  if (!Array.isArray(translation) || translation.length !== 2) {
    throw new Error(`${label}.translation-in-points must be a two-number array`);
  }
  return {
    scale: normalizeFiniteNumber(value.scale, `${label}.scale`, { min: 0.01, max: 100 }),
    "translation-in-points": translation.map((item, index) => normalizeFiniteNumber(item, `${label}.translation-in-points[${index}]`)),
  };
}

function normalizeTranslucency(value, label) {
  requirePlainObject(value, label);
  if (typeof value.enabled !== "boolean") {
    throw new Error(`${label}.enabled must be a boolean`);
  }
  return { enabled: value.enabled, value: normalizeFiniteNumber(value.value, `${label}.value`, { min: 0, max: 1 }) };
}

function normalizeRefractivity(value, label) {
  requirePlainObject(value, label);
  if (typeof value.enabled !== "boolean") {
    throw new Error(`${label}.enabled must be a boolean`);
  }
  return {
    enabled: value.enabled,
    strength: normalizeFiniteNumber(value.strength, `${label}.strength`, { min: -1, max: 1 }),
    depth: normalizeFiniteNumber(value.depth, `${label}.depth`, { min: 0, max: 1 }),
  };
}

function normalizeShadow(value, label) {
  requirePlainObject(value, label);
  if (!COMPOSER_SHADOW_KINDS.has(value.kind)) {
    throw new Error(`${label}.kind must be one of: ${[...COMPOSER_SHADOW_KINDS].join(", ")}`);
  }
  return { kind: value.kind, opacity: normalizeFiniteNumber(value.opacity, `${label}.opacity`, { min: 0, max: 1 }) };
}

function normalizeSupportedPlatforms(value) {
  requirePlainObject(value, "spec.composer.supported_platforms");
  if (value.squares !== "shared") {
    throw new Error('spec.composer.supported_platforms.squares must be "shared"');
  }
  if (!Array.isArray(value.circles) || value.circles.length === 0 || new Set(value.circles).size !== value.circles.length || value.circles.some((platform) => platform !== "watchOS")) {
    throw new Error('spec.composer.supported_platforms.circles must be the unique list ["watchOS"]');
  }
  return { circles: [...value.circles], squares: "shared" };
}

function normalizeSpecializations(value, label, validateValue) {
  if (value == null) {
    return undefined;
  }
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be an array`);
  }
  const appearances = new Set();
  return value.map((item, index) => {
    const itemLabel = `${label}[${index}]`;
    requirePlainObject(item, itemLabel);
    const appearance = item.appearance == null ? null : String(item.appearance).trim();
    if (appearance != null && (!COMPOSER_APPEARANCES.has(appearance) || appearances.has(appearance))) {
      throw new Error(`${itemLabel}.appearance must be a unique supported appearance: ${[...COMPOSER_APPEARANCES].join(", ")}`);
    }
    if (appearance == null && appearances.has("default")) {
      throw new Error(`${label} can contain only one default specialization without appearance`);
    }
    if (!Object.prototype.hasOwnProperty.call(item, "value")) {
      throw new Error(`${itemLabel}.value is required`);
    }
    validateValue(item.value, `${itemLabel}.value`);
    appearances.add(appearance ?? "default");
    return appearance == null ? { value: item.value } : { appearance, value: item.value };
  });
}

function validateBlendModeSpecializationValue(value, label) {
  normalizeBlendMode(value, label);
}

function validateFillSpecializationValue(value, label) {
  if (typeof value === "string") {
    if (!value.trim()) {
      throw new Error(`${label} must be a non-empty string or a fill object`);
    }
    return;
  }
  try {
    validateFill(value);
  } catch (error) {
    throw new Error(`${label} is invalid: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function validateGlassSpecializationValue(value, label) {
  if (typeof value !== "boolean") {
    throw new Error(`${label} must be a boolean`);
  }
}

function validateOpacitySpecializationValue(value, label) {
  normalizeFiniteNumber(value, label, { min: 0, max: 1 });
}

function validateBlurMaterialSpecializationValue(value, label) {
  normalizeFiniteNumber(value, label, { min: 0, max: 1 });
}

function validateSpecularSpecializationValue(value, label) {
  normalizeSpecular(value, label);
}

function validateTranslucencySpecializationValue(value, label) {
  normalizeTranslucency(value, label);
}

function normalizeLayerComposer(rawComposer, layerName) {
  const composer = rawComposer ?? {};
  requirePlainObject(composer, `layer ${layerName} composer`);
  const normalized = {
    ...composer,
    hidden: normalizeOptionalBoolean(composer.hidden, `layer ${layerName} composer.hidden`),
    opacity: normalizeOptionalFiniteNumber(composer.opacity, `layer ${layerName} composer.opacity`, { min: 0, max: 1 }),
    position: composer.position == null ? undefined : normalizePosition(composer.position, `layer ${layerName} composer.position`),
    "blend-mode": normalizeOptionalBlendMode(composer["blend-mode"] ?? composer.blend_mode, `layer ${layerName} composer.blend-mode`),
    "blend-mode-specializations": normalizeSpecializations(
      composer["blend-mode-specializations"],
      `layer ${layerName} composer.blend-mode-specializations`,
      validateBlendModeSpecializationValue,
    ),
    "fill-specializations": normalizeSpecializations(
      composer["fill-specializations"],
      `layer ${layerName} composer.fill-specializations`,
      validateFillSpecializationValue,
    ),
    "glass-specializations": normalizeSpecializations(
      composer["glass-specializations"],
      `layer ${layerName} composer.glass-specializations`,
      validateGlassSpecializationValue,
    ),
    "opacity-specializations": normalizeSpecializations(
      composer["opacity-specializations"],
      `layer ${layerName} composer.opacity-specializations`,
      validateOpacitySpecializationValue,
    ),
  };
  for (const key of ["hidden", "opacity", "position", "blend-mode", "blend-mode-specializations", "fill-specializations", "glass-specializations", "opacity-specializations"]) {
    if (normalized[key] == null) {
      delete normalized[key];
    }
  }
  return normalized;
}

function normalizeComposer(rawComposer) {
  const composer = rawComposer ?? {};
  requirePlainObject(composer, "spec.composer");
  const group = composer.group ?? {};
  requirePlainObject(group, "spec.composer.group");
  const normalizedGroup = {
    ...group,
    hidden: normalizeOptionalBoolean(group.hidden, "spec.composer.group.hidden"),
    "blend-mode": normalizeOptionalBlendMode(group["blend-mode"] ?? group.blend_mode, "spec.composer.group.blend-mode"),
    "blend-mode-specializations": normalizeSpecializations(
      group["blend-mode-specializations"],
      "spec.composer.group.blend-mode-specializations",
      validateBlendModeSpecializationValue,
    ),
    "blur-material": normalizeOptionalFiniteNumber(group["blur-material"], "spec.composer.group.blur-material", { min: 0, max: 1 }),
    "blur-material-specializations": normalizeSpecializations(
      group["blur-material-specializations"],
      "spec.composer.group.blur-material-specializations",
      validateBlurMaterialSpecializationValue,
    ),
    specular: group.specular == null ? undefined : normalizeSpecular(group.specular, "spec.composer.group.specular"),
    "specular-specializations": normalizeSpecializations(
      group["specular-specializations"],
      "spec.composer.group.specular-specializations",
      validateSpecularSpecializationValue,
    ),
    opacity: normalizeOptionalFiniteNumber(group.opacity, "spec.composer.group.opacity", { min: 0, max: 1 }),
    "opacity-specializations": normalizeSpecializations(
      group["opacity-specializations"],
      "spec.composer.group.opacity-specializations",
      validateOpacitySpecializationValue,
    ),
    refractivity: group.refractivity == null ? undefined : normalizeRefractivity(group.refractivity, "spec.composer.group.refractivity"),
    shadow: group.shadow == null ? undefined : normalizeShadow(group.shadow, "spec.composer.group.shadow"),
    translucency: group.translucency == null ? undefined : normalizeTranslucency(group.translucency, "spec.composer.group.translucency"),
    "translucency-specializations": normalizeSpecializations(
      group["translucency-specializations"],
      "spec.composer.group.translucency-specializations",
      validateTranslucencySpecializationValue,
    ),
    lighting: group.lighting == null ? undefined : String(group.lighting),
    position: group.position == null ? undefined : normalizePosition(group.position, "spec.composer.group.position"),
  };
  if (normalizedGroup.lighting != null && !COMPOSER_LIGHTING.has(normalizedGroup.lighting)) {
    throw new Error(`spec.composer.group.lighting must be one of: ${[...COMPOSER_LIGHTING].join(", ")}`);
  }
  for (const key of ["hidden", "blend-mode", "blend-mode-specializations", "blur-material", "blur-material-specializations", "specular", "specular-specializations", "opacity", "opacity-specializations", "refractivity", "shadow", "translucency", "translucency-specializations", "lighting", "position"]) {
    if (normalizedGroup[key] == null) delete normalizedGroup[key];
  }
  const features = composer.features == null ? undefined : nonEmptyStringList(composer.features, "spec.composer.features");
  if (features && (new Set(features).size !== features.length || features.some((feature) => !COMPOSER_FEATURES.has(feature)))) {
    throw new Error(`spec.composer.features must contain unique supported features: ${[...COMPOSER_FEATURES].join(", ")}`);
  }
  const supportedPlatforms = composer.supported_platforms == null ? undefined : normalizeSupportedPlatforms(composer.supported_platforms);
  return {
    ...composer,
    ...(features ? { features } : {}),
    ...(supportedPlatforms ? { supported_platforms: supportedPlatforms } : {}),
    group: normalizedGroup,
  };
}

function normalizeLayer(rawLayer, index, canvas, baseDir) {
  if (!rawLayer || typeof rawLayer !== "object") {
    throw new Error(`layers[${index}] must be an object`);
  }
  if (!rawLayer.name) {
    throw new Error(`layers[${index}] is missing name`);
  }
  const svgParts = readSvgParts(rawLayer, canvas, baseDir);
  const composer = normalizeLayerComposer(rawLayer.composer, rawLayer.name);
  const includeInComposer = composer.include !== false;
  const format = composer.format ?? "svg";
  const hasExplicitGlass = Object.prototype.hasOwnProperty.call(composer, "glass");
  if (!["svg", "png"].includes(format)) {
    throw new Error(`layer ${rawLayer.name} composer.format must be "svg" or "png"`);
  }
  const sourceSvg = svgDocument(svgParts.content, svgParts.defs, canvas);
  const containsText = /<text\b/.test(sourceSvg);
  const containsImage = /<image\b/.test(sourceSvg);
  const sourceLayerFormat = svgParts.pngSource || (format === "png" && containsImage) ? "png" : "svg";
  const pngFallbackEvidence = normalizePngFallbackEvidence(
    rawLayer.png_fallback_evidence ?? composer.png_fallback_evidence ?? composer.fallback_evidence,
    rawLayer.name,
  );
  if (svgParts.pngSource && includeInComposer && format !== "png") {
    throw new Error(`layer ${rawLayer.name} defines png source and must import as composer.format "png"`);
  }
  if (includeInComposer && format === "svg") {
    validateComposerSvg(rawLayer.name, sourceSvg, canvas);
  }
  if (includeInComposer && format === "png" && containsText) {
    if (!rawLayer.text_rendering?.font_family || !rawLayer.text_rendering?.render_method) {
      throw new Error(`layer ${rawLayer.name} contains SVG text and imports as PNG; text_rendering.font_family and text_rendering.render_method are required`);
    }
  }
  if (includeInComposer && format === "png" && !containsText && !isBackgroundLikeLayerName(rawLayer.name)) {
    if (!pngFallbackEvidence) {
      throw new Error(`layer ${rawLayer.name} imports as PNG and must include png_fallback_evidence for non-text foreground layers`);
    }
    if (isVaguePngFallbackReason(composer.reason)) {
      throw new Error(`layer ${rawLayer.name} PNG fallback reason is too generic; record a concrete per-layer reason`);
    }
  }
  return {
    name: String(rawLayer.name),
    fileStem: safeName(rawLayer.name),
    sourceSvg,
    content: svgParts.content,
    defs: svgParts.defs,
    containsImage,
    containsText,
    sourceLayerFormat,
    includeInComposer,
    composer: {
      format,
      reason: composer.reason ?? (format === "png" ? "PNG import preserves visual fidelity for this layer" : "simple editable vector layer"),
      position: composer.position ?? { scale: 1, "translation-in-points": [0, 0] },
      glass: Boolean(composer.glass),
      glassExplicit: hasExplicitGlass || format === "png",
      fill: composer.fill,
      "blend-mode": composer["blend-mode"],
      ...(composer.hidden != null ? { hidden: composer.hidden } : {}),
      ...(composer.opacity != null ? { opacity: composer.opacity } : {}),
      ...(composer["blend-mode-specializations"] != null ? { "blend-mode-specializations": composer["blend-mode-specializations"] } : {}),
      ...(composer["fill-specializations"] != null ? { "fill-specializations": composer["fill-specializations"] } : {}),
      ...(composer["glass-specializations"] != null ? { "glass-specializations": composer["glass-specializations"] } : {}),
      ...(composer["opacity-specializations"] != null ? { "opacity-specializations": composer["opacity-specializations"] } : {}),
      ...(backgroundImportRole(rawLayer) ? { background_role: backgroundImportRole(rawLayer) } : {}),
    },
    pngFallbackEvidence,
    textHandling: rawLayer.text_handling ?? (containsText ? "source SVG text rendered to transparent PNG for font fidelity; no imported SVG text" : "not text"),
    textRendering: rawLayer.text_rendering,
  };
}

function normalizeSpec(rawSpec, { baseDir = process.cwd() } = {}) {
  if (!rawSpec || typeof rawSpec !== "object") {
    throw new Error("spec must be a JSON object");
  }
  const name = upperCamel(rawSpec.name);
  const canvas = Number(rawSpec.canvas ?? DEFAULT_CANVAS);
  const radius = Number(rawSpec.radius ?? Math.round((DEFAULT_RADIUS * canvas) / DEFAULT_CANVAS));
  if (!Number.isInteger(canvas) || canvas <= 0) {
    throw new Error("spec.canvas must be a positive integer");
  }
  if (!Array.isArray(rawSpec.layers) || rawSpec.layers.length === 0) {
    throw new Error("spec.layers must contain at least one layer");
  }
  validateFill(rawSpec.fill ?? "automatic");
  const fontFiles = Array.isArray(rawSpec.font_files) ? rawSpec.font_files.map((item) => resolve(baseDir, String(item))) : [];
  const defaultFontFamily = rawSpec.default_font_family ? String(rawSpec.default_font_family) : "sans-serif";
  const targetPlatforms = rawSpec.target_platforms == null ? [] : nonEmptyStringList(rawSpec.target_platforms, "spec.target_platforms");
  const deliverableType = rawSpec.deliverable_type == null ? null : String(rawSpec.deliverable_type);
  const appleTargets = targetPlatforms.filter((platform) => APPLE_TARGET_PLATFORMS.has(platform));
  const useAppleAdapter = deliverableType !== "source-package" && (appleTargets.length > 0 || APPLE_DELIVERABLE_TYPES.has(deliverableType));
  const composer = normalizeComposer(rawSpec.composer);
  const layers = rawSpec.layers.map((layer, index) => normalizeLayer(layer, index, canvas, baseDir));
  const semanticReview = normalizeSemanticReview(rawSpec.semantic_review);
  const sourceAnalysis = normalizeSourceAnalysis(rawSpec.source_analysis, layers, semanticReview);
  const acceptance = normalizeAcceptance(rawSpec.acceptance);
  const layerNames = new Set();
  const fileStems = new Set();
  const ids = new Map();
  for (const layer of layers) {
    if (layerNames.has(layer.name)) {
      throw new Error(`duplicate layer name: ${layer.name}`);
    }
    if (fileStems.has(layer.fileStem)) {
      throw new Error(`duplicate layer filename stem: ${layer.fileStem}`);
    }
    layerNames.add(layer.name);
    fileStems.add(layer.fileStem);
    for (const id of collectIds(layer.sourceSvg)) {
      if (ids.has(id)) {
        throw new Error(`duplicate SVG id "${id}" in layers "${ids.get(id)}" and "${layer.name}"`);
      }
      ids.set(id, layer.name);
    }
  }
  const warnings = [];
  if (layers.length < 2 || layers.length > 8) {
    warnings.push("recommended package shape is 2-5 semantic layers, or at most 8 for an explicit bounded pane/sticker style");
  }
  const includedLayers = useAppleAdapter ? layers.filter((layer) => layer.includeInComposer) : [];
  const includedBackgrounds = includedLayers.filter((layer) => isBackgroundLikeLayerName(layer.name));
  const duplicatedBackgrounds = includedBackgrounds.filter((layer) => hasExplicitFill(rawSpec.fill ?? "automatic") && !isComplexBackgroundImport(layer));
  if (useAppleAdapter && duplicatedBackgrounds.length > 0) {
    throw new Error(
      `background-like layers (${duplicatedBackgrounds.map((layer) => layer.name).join(", ")}) cannot be included in Icon Composer Assets when spec.fill is explicit unless composer.background_role is "complex"; keep simple backgrounds in icon.json fill and import only deliberate complex backgrounds`,
    );
  }
  for (const layer of useAppleAdapter ? layers.filter((item) => !item.includeInComposer && isBackgroundLikeLayerName(item.name)) : []) {
    const consistency = previewOnlyBackgroundConsistency(layer.sourceSvg, canvas);
    if (!consistency.ok) {
      throw new Error(
        `preview-only background layer "${layer.name}" is not representable by icon.json.fill: ${consistency.reason}. Remove localized material from the local preview or import it as a deliberate complex background layer.`,
      );
    }
    if (hasFullCanvasRoundedRect(layer.sourceSvg, canvas)) {
      throw new Error(
        `preview-only background layer "${layer.name}" contains a full-canvas rounded mask. Keep platform rounded masks in *.preview.* only; use a square fill/background layer so *.app.* outputs stay unrounded.`,
      );
    }
  }
  for (const backgroundLayer of includedBackgrounds) {
    if (includedLayers.indexOf(backgroundLayer) !== 0) {
      throw new Error(`background-like included layer "${backgroundLayer.name}" must be the first included Icon Composer layer in bottom-to-top order`);
    }
  }
  return {
    name,
    canvas,
    radius,
    fontFiles,
    defaultFontFamily,
    targetPlatforms: [...new Set(targetPlatforms)],
    deliverableType,
    appleTargets,
    useAppleAdapter,
    sourceReference: rawSpec.source_reference ?? rawSpec.sourceReference ?? "",
    brief: rawSpec.brief ?? "",
    fill: rawSpec.fill ?? "automatic",
    composer,
    semanticReview,
    sourceAnalysis,
    acceptance,
    layers,
    warnings,
  };
}

function numberedFileName(index, name, extension) {
  return `${String(index + 1).padStart(2, "0")}-${name}.${extension}`;
}

function sourceLayerPath(spec, layer) {
  return `layers/${numberedFileName(spec.layers.indexOf(layer), layer.fileStem, layer.sourceLayerFormat)}`;
}

function composerDecisions(spec) {
  return spec.layers
    .filter((layer) => layer.includeInComposer)
    .map((layer, index) => ({
      layer,
      index,
      assetName: numberedFileName(index, layer.fileStem, layer.composer.format),
      sourceLayer: sourceLayerPath(spec, layer),
    }));
}

function iconComposerJsonDecisions(decisions) {
  return [...decisions].reverse();
}

function composeIconSvg(spec, { portable = false, roundedMask = true } = {}) {
  const clipId = `${safeName(spec.name)}-clip`;
  const layerDefs = spec.layers
    .filter((layer) => !portable || layer.sourceLayerFormat === "svg")
    .map((layer) => layer.defs)
    .filter(Boolean)
    .join("");
  const defs = `${layerDefs}${
    roundedMask ? `<clipPath id="${clipId}"><rect width="${spec.canvas}" height="${spec.canvas}" rx="${spec.radius}"/></clipPath>` : ""
  }`;
  const content = spec.layers
    .map((layer) => {
      if (portable && layer.sourceLayerFormat === "png") {
        return `<image href="${sourceLayerPath(spec, layer)}" width="${spec.canvas}" height="${spec.canvas}"/>`;
      }
      return layer.content;
    })
    .join("\n");
  return svgDocument(roundedMask ? `<g clip-path="url(#${clipId})">${content}</g>` : content, defs, spec.canvas);
}

function previewSvg(spec, { portable = false } = {}) {
  return composeIconSvg(spec, { portable, roundedMask: true });
}

function appCanvasSvg(spec, { portable = false } = {}) {
  return composeIconSvg(spec, { portable, roundedMask: false });
}

function outputNames(spec, { layout = "package", deliveryStem = null } = {}) {
  if (layout === "delivery") {
    const stem = deliveryStem ?? safeName(spec.name);
    return {
      previewSvg: `${stem}.preview.svg`,
      previewPng: `${stem}.preview.png`,
      appSvg: `${stem}.svg`,
      appPng: `${stem}.png`,
    };
  }
  return {
    previewSvg: `${spec.name}.preview.svg`,
    previewPng: `${spec.name}.preview.png`,
    appSvg: `${spec.name}.app.svg`,
    appPng: `${spec.name}.app.png`,
  };
}

function outputLayout(outDir, args) {
  if (args.layout === "delivery") {
    const deliveryStem = safeName(basename(outDir));
    return {
      layout: "delivery",
      deliveryStem,
      readmePath: resolve(outDir, "tmp", "README.md"),
      reportsDir: resolve(outDir, "tmp", "reports"),
      styleReportPath: resolve(outDir, "tmp", "reports", "style-report.json"),
      workSpecPath: resolve(outDir, "tmp", "work", "spec.json"),
      workSpecRelative: "tmp/work/spec.json",
      preserveRelPaths: ["tmp/work", `${deliveryStem}.origin.png`, `${deliveryStem}.origin.svg`],
    };
  }
  return {
    layout: "package",
    deliveryStem: null,
    readmePath: resolve(outDir, "README.md"),
    reportsDir: outDir,
    styleReportPath: resolve(outDir, "style-report.json"),
    workSpecPath: null,
    workSpecRelative: null,
    preserveRelPaths: [],
  };
}

function generatedFilesForRun(outDir, spec, layout, outputs, decisions, appleExports) {
  const reportNames = [
    "style-report.json",
    "package-verification.json",
    "reference-diff.png",
    "reference-overlay.png",
    "reference-side-by-side.png",
    "visual-review.json",
  ];
  return [
    outputs.previewSvg,
    outputs.previewPng,
    outputs.appSvg,
    outputs.appPng,
    ...spec.layers.map((layer) => sourceLayerPath(spec, layer)),
    ...(spec.useAppleAdapter ? [`${spec.name}.icon/icon.json`] : []),
    ...(spec.useAppleAdapter ? decisions.map((decision) => `${spec.name}.icon/Assets/${decision.assetName}`) : []),
    ...(appleExports?.files ?? []),
    normalizeRelativePath(relative(outDir, layout.readmePath)),
    ...reportNames.map((name) => normalizeRelativePath(relative(outDir, resolve(layout.reportsDir, name)))),
  ];
}

function relPath(...parts) {
  return parts.join("/");
}

async function executableExists(path) {
  try {
    await access(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

async function iconComposerIctoolCandidates() {
  const candidates = [];
  const override = process.env.APP_ICON_GEN_ICON_COMPOSER_ICTOOL || process.env.ICON_COMPOSER_ICTOOL;
  if (override) {
    candidates.push(resolve(override));
  }
  const applicationsDir = "/Applications";
  try {
    const entries = await readdir(applicationsDir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory() || !entry.name.endsWith(".app")) {
        continue;
      }
      const appPath = resolve(applicationsDir, entry.name);
      if (entry.name.startsWith("Icon Composer")) {
        candidates.push(resolve(appPath, "Contents", "Executables", "ictool"));
      }
      if (entry.name.startsWith("Xcode")) {
        candidates.push(resolve(appPath, "Contents", "Applications", "Icon Composer.app", "Contents", "Executables", "ictool"));
      }
    }
  } catch {
    // Missing or unreadable /Applications just means there is no automatic Apple export path.
  }
  return [...new Set(candidates)];
}

async function findIconComposerIctool() {
  if (/^(1|true|yes)$/i.test(process.env.APP_ICON_GEN_SKIP_APPLE_EXPORTS ?? "")) {
    return { path: null, reason: "disabled-by-environment" };
  }
  if (process.platform !== "darwin") {
    return { path: null, reason: "not-macos" };
  }
  for (const candidate of await iconComposerIctoolCandidates()) {
    if (await executableExists(candidate)) {
      return { path: candidate, reason: "found" };
    }
  }
  return { path: null, reason: "icon-composer-ictool-not-found" };
}

async function writeAppleExports(outDir, bundleDir, targetPlatforms, deliverableType) {
  const exportProfiles = appleExportProfilesForTargets(targetPlatforms);
  const base = {
    scale: APPLE_EXPORT_SCALE,
    platforms: exportProfiles.map((profile) => profile.platform),
    profiles: exportProfiles.map((profile) => ({
      platform: profile.platform,
      width: profile.width,
      height: profile.height,
      renditions: profile.renditions.map((rendition) => rendition.name),
    })),
    files: [],
  };
  if (deliverableType === "source-package") {
    return {
      status: "skipped",
      reason: "not-requested-for-source-package",
      ...base,
    };
  }
  const tool = await findIconComposerIctool();
  if (!tool.path) {
    return {
      status: "skipped",
      reason: tool.reason,
      ...base,
    };
  }

  const appleDir = resolve(outDir, "apple");
  await assertOutputTargetsAvailable(outDir, { directories: [appleDir] });
  await mkdir(appleDir, { recursive: true });
  const files = [];
  for (const profile of exportProfiles) {
    const platformDir = resolve(appleDir, profile.platform);
    await assertOutputTargetsAvailable(outDir, { directories: [platformDir] });
    await mkdir(platformDir, { recursive: true });
    for (const rendition of profile.renditions) {
      const outputPath = resolve(platformDir, `${rendition.name}.png`);
      await assertOutputTargetsAvailable(outDir, { files: [outputPath] });
      const temporaryOutputPath = resolve(platformDir, `.${rendition.name}.tmp-${randomUUID()}.png`);
      const args = [
        bundleDir,
        "--export-image",
        "--output-file",
        temporaryOutputPath,
        "--platform",
        profile.platform,
        "--rendition",
        rendition.name,
        "--width",
        String(profile.width),
        "--height",
        String(profile.height),
        "--scale",
        String(APPLE_EXPORT_SCALE),
      ];
      if (rendition.tintColor != null) {
        args.push("--tint-color", rendition.tintColor, "--tint-strength", rendition.tintStrength);
      }
      try {
        await execFileAsync(tool.path, args, { maxBuffer: 1024 * 1024 });
        const temporaryStat = await pathStat(temporaryOutputPath);
        if (!temporaryStat?.isFile() || temporaryStat.isSymbolicLink()) {
          throw new Error(`ictool did not produce a safe regular file: ${temporaryOutputPath}`);
        }
        await assertOutputTargetsAvailable(outDir, { files: [outputPath] });
        await rename(temporaryOutputPath, outputPath);
      } finally {
        await rm(temporaryOutputPath, { force: true });
      }
      files.push(relPath("apple", profile.platform, `${rendition.name}.png`));
    }
  }

  return {
    status: "generated",
    tool: tool.path,
    ...base,
    files,
  };
}

async function writeCompositeOutputs(outDir, spec, names) {
  const renderPreviewSvg = previewSvg(spec);
  const portablePreviewSvg = previewSvg(spec, { portable: true });
  const renderAppSvg = appCanvasSvg(spec);
  const portableAppSvg = appCanvasSvg(spec, { portable: true });
  const previewPng = new Resvg(renderPreviewSvg, renderOptions(spec, { width: spec.canvas })).render().asPng();
  const appPng = new Resvg(renderAppSvg, renderOptions(spec, { width: spec.canvas })).render().asPng();

  await writeOutputFile(outDir, resolve(outDir, names.previewSvg), portablePreviewSvg, "utf8");
  await writeOutputFile(outDir, resolve(outDir, names.previewPng), previewPng);
  await writeOutputFile(outDir, resolve(outDir, names.appSvg), portableAppSvg, "utf8");
  await writeOutputFile(outDir, resolve(outDir, names.appPng), appPng);

  return names;
}

function iconJson(spec, decisions) {
  const group = spec.composer.group ?? {};
  const jsonDecisions = iconComposerJsonDecisions(decisions);
  const hasPngLayer = jsonDecisions.some((decision) => decision.layer.composer.format === "png");
  const groupTranslucency = group.translucency ?? (hasPngLayer ? { enabled: false, value: 0 } : undefined);
  const icon = {
    "color-space-for-untagged-svg-colors": spec.composer.color_space ?? "display-p3",
    fill: spec.fill,
    groups: [
      {
        "blend-mode": group["blend-mode"] ?? group.blend_mode ?? "normal",
        ...(group["blur-material"] != null ? { "blur-material": group["blur-material"] } : {}),
        hidden: group.hidden ?? false,
        layers: jsonDecisions.map((decision) => {
          const entry = {
            "image-name": decision.assetName,
            name: decision.layer.name,
            position: decision.layer.composer.position,
          };
          if (decision.layer.composer.hidden != null) {
            entry.hidden = decision.layer.composer.hidden;
          }
          if (decision.layer.composer.opacity != null) {
            entry.opacity = decision.layer.composer.opacity;
          }
          if (decision.layer.composer["blend-mode"] != null) {
            entry["blend-mode"] = decision.layer.composer["blend-mode"];
          }
          if (decision.layer.composer["blend-mode-specializations"] != null) {
            entry["blend-mode-specializations"] = decision.layer.composer["blend-mode-specializations"];
          }
          if (decision.layer.composer.fill != null) {
            entry.fill = decision.layer.composer.fill;
          }
          if (decision.layer.composer["fill-specializations"] != null) {
            entry["fill-specializations"] = decision.layer.composer["fill-specializations"];
          }
          if (decision.layer.composer.glassExplicit) {
            entry.glass = Boolean(decision.layer.composer.glass);
          }
          if (decision.layer.composer["glass-specializations"] != null) {
            entry["glass-specializations"] = decision.layer.composer["glass-specializations"];
          }
          if (decision.layer.composer["opacity-specializations"] != null) {
            entry["opacity-specializations"] = decision.layer.composer["opacity-specializations"];
          }
          return entry;
        }),
        lighting: group.lighting ?? "individual",
        name: safeName(spec.name),
        position: group.position ?? { scale: 1, "translation-in-points": [0, 0] },
        ...(group["blend-mode-specializations"] != null ? { "blend-mode-specializations": group["blend-mode-specializations"] } : {}),
        ...(group["blur-material-specializations"] != null ? { "blur-material-specializations": group["blur-material-specializations"] } : {}),
        ...(group.specular != null ? { specular: group.specular } : {}),
        ...(group["specular-specializations"] != null ? { "specular-specializations": group["specular-specializations"] } : {}),
        ...(group.opacity != null ? { opacity: group.opacity } : {}),
        ...(group["opacity-specializations"] != null ? { "opacity-specializations": group["opacity-specializations"] } : {}),
        ...(group.refractivity != null ? { refractivity: group.refractivity } : {}),
        ...(group.shadow != null ? { shadow: group.shadow } : {}),
        ...(groupTranslucency != null ? { translucency: groupTranslucency } : {}),
        ...(group["translucency-specializations"] != null ? { "translucency-specializations": group["translucency-specializations"] } : {}),
      },
    ],
    "supported-platforms": spec.composer.supported_platforms ?? { circles: ["watchOS"], squares: "shared" },
  };
  if (Array.isArray(spec.composer.features) && spec.composer.features.length > 0) {
    icon.features = spec.composer.features;
  }
  return {
    ...icon,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const specPath = resolve(args.spec);
  const outDir = resolve(args.out);

  const rawSpec = await readFile(specPath, "utf8");
  const spec = normalizeSpec(JSON.parse(rawSpec), { baseDir: dirname(specPath) });
  const layout = outputLayout(outDir, args);
  const layersDir = resolve(outDir, "layers");
  const bundleDir = resolve(outDir, `${spec.name}.icon`);
  const assetsDir = resolve(bundleDir, "Assets");
  const decisions = spec.useAppleAdapter ? composerDecisions(spec) : [];
  const outputs = outputNames(spec, layout);
  const layerTargets = spec.layers.map((layer, index) =>
    resolve(layersDir, numberedFileName(index, layer.fileStem, layer.sourceLayerFormat)),
  );
  const assetTargets = decisions.map((decision) => resolve(assetsDir, decision.assetName));
  const coreFileTargets = [
    ...layerTargets,
    ...assetTargets,
    resolve(outDir, outputs.previewSvg),
    resolve(outDir, outputs.previewPng),
    resolve(outDir, outputs.appSvg),
    resolve(outDir, outputs.appPng),
    ...(spec.useAppleAdapter ? [resolve(bundleDir, "icon.json")] : []),
    layout.styleReportPath,
    layout.readmePath,
    ...(layout.workSpecPath ? [layout.workSpecPath] : []),
  ];
  const coreDirectoryTargets = [
    layersDir,
    ...(spec.useAppleAdapter ? [bundleDir, assetsDir] : []),
    layout.reportsDir,
    dirname(layout.readmePath),
    ...(layout.workSpecPath ? [dirname(layout.workSpecPath)] : []),
  ];

  await prepareOutputDir(outDir, layout);
  await assertOutputTargetsAvailable(outDir, {
    directories: coreDirectoryTargets,
    files: coreFileTargets,
    replaceableFiles: layout.workSpecPath ? [layout.workSpecPath] : [],
  });
  await mkdir(layersDir, { recursive: true });
  if (spec.useAppleAdapter) {
    await mkdir(assetsDir, { recursive: true });
  }
  await mkdir(layout.reportsDir, { recursive: true });
  await mkdir(dirname(layout.readmePath), { recursive: true });
  if (layout.workSpecPath) {
    await mkdir(dirname(layout.workSpecPath), { recursive: true });
    await writeOutputFile(outDir, layout.workSpecPath, rawSpec.endsWith("\n") ? rawSpec : `${rawSpec}\n`, "utf8", {
      replaceExisting: true,
    });
  }

  for (const [index, layer] of spec.layers.entries()) {
    const layerPath = layerTargets[index];
    if (layer.sourceLayerFormat === "png") {
      const png = new Resvg(layer.sourceSvg, renderOptions(spec, { width: spec.canvas })).render().asPng();
      await writeOutputFile(outDir, layerPath, png);
    } else {
      await writeOutputFile(outDir, layerPath, layer.sourceSvg, "utf8");
    }
  }

  for (const [index, decision] of decisions.entries()) {
    const layer = decision.layer;
    if (layer.composer.format === "png") {
      const png = new Resvg(layer.sourceSvg, renderOptions(spec, { width: spec.canvas })).render().asPng();
      await writeOutputFile(outDir, assetTargets[index], png);
    } else {
      await writeOutputFile(outDir, assetTargets[index], layer.sourceSvg, "utf8");
    }
  }

  await writeCompositeOutputs(outDir, spec, outputs);
  const iconComposerJson = spec.useAppleAdapter ? iconJson(spec, decisions) : null;
  if (iconComposerJson) {
    await writeOutputFile(outDir, resolve(bundleDir, "icon.json"), `${JSON.stringify(iconComposerJson, null, 2)}\n`, "utf8");
  }
  const appleExports = spec.useAppleAdapter
    ? await writeAppleExports(outDir, bundleDir, spec.appleTargets, spec.deliverableType)
    : null;
  const generatedFiles = generatedFilesForRun(outDir, spec, layout, outputs, decisions, appleExports);
  const generatedDirectories = directoriesForFiles(generatedFiles);

  const formatSet = new Set(decisions.map((decision) => decision.layer.composer.format));
  const jsonDecisions = iconComposerJson ? iconComposerJsonDecisions(decisions) : [];
  const styleReport = {
    mode: "icon-spec-authoring",
    layout: layout.layout,
    spec: specPath,
    ...(layout.workSpecRelative ? { work_spec: layout.workSpecRelative } : {}),
    name: spec.name,
    canvas: spec.canvas,
    target_platforms: spec.targetPlatforms,
    deliverable_type: spec.deliverableType,
    source_reference: spec.sourceReference,
    brief: spec.brief,
    renderer: "@resvg/resvg-js",
    generated_files: generatedFiles,
    generated_directories: generatedDirectories,
    preview_svg: outputs.previewSvg,
    preview_png: outputs.previewPng,
    app_svg: outputs.appSvg,
    app_png: outputs.appPng,
    layers: spec.layers.map((layer) => sourceLayerPath(spec, layer)),
    apple_adapter: spec.useAppleAdapter
      ? {
          bundle: `${spec.name}.icon`,
          exports: appleExports,
        }
      : null,
    ...(spec.useAppleAdapter
      ? {
          icon_composer_bundle: `${spec.name}.icon`,
          apple_exports: appleExports,
          icon_composer_asset_format: formatSet.size === 1 ? [...formatSet][0] : "mixed",
          icon_composer_assets: decisions.map((decision) => `${spec.name}.icon/Assets/${decision.assetName}`),
          icon_composer_features: iconComposerJson.features,
          icon_composer_group_settings: iconComposerJson.groups[0],
          icon_composer_json_layer_order: "front-to-back",
          icon_composer_json_assets: jsonDecisions.map((decision) => `${spec.name}.icon/Assets/${decision.assetName}`),
        }
      : {}),
    preview_background_layers: spec.layers
      .filter((layer) => !layer.includeInComposer && isBackgroundLikeLayerName(layer.name))
      .map((layer) => ({
        layer: layer.name,
        source_layer: sourceLayerPath(spec, layer),
        role: "preview-only-simple-fill",
      })),
    icon_composer_layer_decisions: decisions.map((decision) => ({
      layer: decision.layer.name,
      asset: `${spec.name}.icon/Assets/${decision.assetName}`,
      source_layer: decision.sourceLayer,
      format: decision.layer.composer.format,
      reason: decision.layer.composer.reason,
      editability:
        decision.layer.composer.format === "svg"
          ? "imported as editable vector"
          : decision.layer.sourceLayerFormat === "svg"
            ? "imported as raster; source SVG retained"
            : "imported as raster; source PNG fallback evidence retained",
      text_handling: decision.layer.textHandling,
      ...(decision.layer.composer["blend-mode"] ? { blend_mode: decision.layer.composer["blend-mode"] } : {}),
      ...(decision.layer.composer.fill ? { fill: decision.layer.composer.fill } : {}),
      ...(decision.layer.textRendering ? { text_rendering: decision.layer.textRendering } : {}),
      ...(decision.layer.composer.background_role ? { background_role: decision.layer.composer.background_role } : {}),
      ...(decision.layer.pngFallbackEvidence ? { png_fallback_evidence: decision.layer.pngFallbackEvidence } : {}),
    })),
    background_mode: "spec",
    ...(spec.useAppleAdapter ? { icon_composer_fill: spec.fill } : {}),
    ...(spec.fontFiles.length > 0 ? { font_files: spec.fontFiles } : {}),
    ...(spec.semanticReview ? { semantic_review: spec.semanticReview } : {}),
    ...(spec.sourceAnalysis ? { source_analysis: spec.sourceAnalysis } : {}),
    ...(spec.acceptance ? { acceptance: spec.acceptance } : {}),
    warnings: spec.warnings,
    claims: [
      "spec-driven reusable cross-platform icon source package",
      "semantic source layers retained",
      "rounded preview PNG rendered by @resvg/resvg-js",
      "unrounded app/source canvas outputs retained separately from preview masking",
      ...(spec.useAppleAdapter
        ? ["Icon Composer SVG imports contain no text, image, filter, clipPath, mask, foreignObject, script, external href, or full-canvas rounded mask elements"]
        : []),
    ],
  };
  await writeOutputFile(outDir, layout.styleReportPath, `${JSON.stringify(styleReport, null, 2)}\n`, "utf8");
  await writeOutputFile(
    outDir,
    layout.readmePath,
    `# ${spec.name}

Generated from \`${specPath}\`.

- Use \`${outputs.previewSvg}\` and \`${outputs.previewPng}\` for rounded local review.
- Use \`${outputs.appSvg}\` and \`${outputs.appPng}\` for an unrounded source/app canvas.
${spec.useAppleAdapter ? `- Apple adapter: import \`${spec.name}.icon/Assets/\` into Icon Composer as separated layers.\n` : "- Generic source assets can be adapted to a requested platform after review.\n"}
`,
    "utf8",
  );

  console.log(JSON.stringify({ out: outDir, icon: spec.name, layout: layout.layout, assets: decisions.length }, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
