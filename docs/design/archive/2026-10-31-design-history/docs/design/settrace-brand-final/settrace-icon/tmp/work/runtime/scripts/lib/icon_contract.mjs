export const PNG_FALLBACK_CATEGORIES = new Set([
  "text-rendering",
  "embedded-raster",
  "dense-brand-geometry",
  "renderer-artifact",
  "custom-gradient",
  "raster-art",
  "strict-fidelity",
  "icon-composer-svg-artifact",
]);

export const PNG_FALLBACK_ROUTES = new Set(["attempted-and-failed", "not-viable", "user-approved-png"]);

const FILL_ERROR =
  'spec.fill must be "automatic", { "automatic-gradient": ... }, { "solid": ... }, or { "linear-gradient": [two stops], "orientation": ... }';

export function getAttr(tag, name) {
  const match = new RegExp(`\\s${name}\\s*=\\s*["']([^"']+)["']`, "i").exec(tag);
  return match?.[1];
}

export function hasFullCanvasRoundedRect(svg, canvas) {
  for (const match of String(svg).matchAll(/<rect\b[^>]*>/gi)) {
    const tag = match[0];
    const width = Number(getAttr(tag, "width"));
    const height = Number(getAttr(tag, "height"));
    const hasRadius = getAttr(tag, "rx") != null || getAttr(tag, "ry") != null;
    if (hasRadius && width === canvas && height === canvas) {
      return true;
    }
  }
  return false;
}

export function validateFill(fill) {
  if (fill === "automatic") {
    return;
  }
  if (!fill || typeof fill !== "object" || Array.isArray(fill)) {
    throw new Error(FILL_ERROR);
  }
  if (typeof fill.solid === "string") {
    return;
  }
  if (typeof fill["automatic-gradient"] === "string") {
    return;
  }
  const stops = fill["linear-gradient"];
  const orientation = fill.orientation;
  if (Array.isArray(stops) && stops.length !== 2) {
    throw new Error("spec.fill linear-gradient must use exactly 2 color stops for Icon Composer compatibility");
  }
  if (
    Array.isArray(stops) &&
    stops.length === 2 &&
    stops.every((item) => typeof item === "string") &&
    orientation?.start &&
    orientation?.stop &&
    Number.isFinite(Number(orientation.start.x)) &&
    Number.isFinite(Number(orientation.start.y)) &&
    Number.isFinite(Number(orientation.stop.x)) &&
    Number.isFinite(Number(orientation.stop.y))
  ) {
    return;
  }
  throw new Error(FILL_ERROR);
}

export function stableJson(value) {
  return JSON.stringify(sortDeep(value));
}

function sortDeep(value) {
  if (Array.isArray(value)) {
    return value.map(sortDeep);
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, item]) => [key, sortDeep(item)]));
  }
  return value;
}

export function isBackgroundLikeLayerName(name) {
  return /\b(background|backdrop|canvas|fill)\b/i.test(String(name ?? ""));
}

export function hasExplicitFill(fill) {
  return fill !== "automatic";
}

export function backgroundImportRole(layer) {
  return String(layer?.composer?.background_role ?? layer?.composer?.backgroundRole ?? "").trim();
}

export function isComplexBackgroundImport(layer) {
  return backgroundImportRole(layer) === "complex";
}

export function isComplexBackgroundDecision(decision) {
  return String(decision?.background_role ?? decision?.backgroundRole ?? "").trim() === "complex";
}

export function isVaguePngFallbackReason(reason) {
  const normalized = String(reason ?? "").trim().toLowerCase();
  return (
    !normalized ||
    normalized === "png import preserves visual fidelity for this layer" ||
    normalized === "foreground mark is imported as png to preserve source antialiasing and brand geometry" ||
    normalized === "preserve source antialiasing and brand geometry" ||
    normalized === "visual fidelity" ||
    normalized === "brand geometry"
  );
}

export function previewOnlyBackgroundConsistency(svg, canvas = 1024) {
  const renderedBody = String(svg)
    .replace(/<defs\b[\s\S]*?<\/defs>/gi, "")
    .replace(/<clipPath\b[\s\S]*?<\/clipPath>/gi, "")
    .replace(/<mask\b[\s\S]*?<\/mask>/gi, "");
  const primitives = [...renderedBody.matchAll(/<(rect|path|circle|ellipse|polygon|polyline|line|image)\b[^>]*>/gi)];
  if (primitives.length !== 1) {
    return {
      ok: false,
      reason: `preview-only simple backgrounds must be one broad fill primitive; found ${primitives.length} rendered primitives`,
    };
  }
  const [fullTag, tagName] = primitives[0];
  if (tagName.toLowerCase() !== "rect") {
    return {
      ok: false,
      reason: `preview-only simple backgrounds must be a full-canvas rect, not <${tagName}>`,
    };
  }
  const width = Number(getAttr(fullTag, "width"));
  const height = Number(getAttr(fullTag, "height"));
  const x = Number(getAttr(fullTag, "x") ?? 0);
  const y = Number(getAttr(fullTag, "y") ?? 0);
  if (width !== canvas || height !== canvas || x !== 0 || y !== 0) {
    return {
      ok: false,
      reason: `preview-only simple background rect must cover the full ${canvas}x${canvas} canvas`,
    };
  }
  return { ok: true, reason: "single broad full-canvas background fill" };
}
