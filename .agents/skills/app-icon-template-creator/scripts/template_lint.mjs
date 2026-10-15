#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import Ajv from "ajv";

const input = process.argv[2];

if (!input) {
  console.error("Usage: npm --prefix <skill-dir>/scripts run template-lint -- <template.md>");
  process.exit(2);
}

const inputBaseDir = process.env.INIT_CWD || process.cwd();
const filePath = path.isAbsolute(input) ? input : path.resolve(inputBaseDir, input);
let markdown;

try {
  markdown = fs.readFileSync(filePath, "utf8").replace(/\r\n?/g, "\n");
} catch (error) {
  console.error(JSON.stringify({ ok: false, file: filePath, failures: [`cannot read file: ${error.message}`] }, null, 2));
  process.exit(2);
}

const requiredHeadings = [
  "## Style Family Template",
  "## Variant Axes",
  "## Template Conversion Flow",
  "## Example Instantiation (Not A Default)",
  "## Example Conversion Contract (Adapt After Selection)"
];
const failures = [];
const markdownStructure = parseMarkdownStructure(markdown);
const structuralMarkdown = markdownStructure.masked;
const contractSchema = JSON.parse(
  fs.readFileSync(new URL("../references/template-conversion-contract.schema.json", import.meta.url), "utf8"),
);
const validateContract = new Ajv({ allErrors: true }).compile(contractSchema);

if (markdownStructure.fencedBlocks.some((block) => !block.closed)) {
  failures.push("template contains an unclosed fenced block");
}
if (/^ {0,3}<(?:\/?[A-Za-z][A-Za-z0-9-]*(?:[ \t]|\/?>)|\?|![A-Z]|!\[CDATA\[)/m.test(structuralMarkdown)) {
  failures.push("raw HTML blocks are not allowed in semantic templates");
}

function sourceLines(source) {
  const lines = [];
  let start = 0;
  while (start < source.length) {
    const newline = source.indexOf("\n", start);
    const contentEnd = newline === -1 ? source.length : newline;
    const end = newline === -1 ? source.length : newline + 1;
    lines.push({ start, end, text: source.slice(start, contentEnd) });
    start = end;
  }
  return lines;
}

function maskRanges(source, ranges) {
  let masked = source;
  for (const range of [...ranges].sort((left, right) => right.start - left.start)) {
    const replacement = source.slice(range.start, range.end).replace(/[^\n]/g, " ");
    masked = `${masked.slice(0, range.start)}${replacement}${masked.slice(range.end)}`;
  }
  return masked;
}

function parseMarkdownStructure(source) {
  const fencedBlocks = [];
  const maskedRanges = [];
  let activeFence = null;
  let commentStart = null;

  for (const line of sourceLines(source)) {
    if (activeFence) {
      const closingPattern = new RegExp(
        `^ {0,3}${activeFence.character}{${activeFence.length},}[ \\t]*$`,
      );
      if (closingPattern.test(line.text)) {
        const block = {
          ...activeFence,
          closed: true,
          contentEnd: line.start,
          end: line.end,
        };
        fencedBlocks.push(block);
        maskedRanges.push({ start: block.start, end: block.end });
        activeFence = null;
      }
      continue;
    }

    if (commentStart != null) {
      const close = line.text.indexOf("-->");
      if (close === -1) {
        continue;
      }
      maskedRanges.push({ start: commentStart, end: line.start + close + 3 });
      commentStart = null;
      let cursor = close + 3;
      while (cursor < line.text.length) {
        const nextOpen = line.text.indexOf("<!--", cursor);
        if (nextOpen === -1) {
          break;
        }
        const nextClose = line.text.indexOf("-->", nextOpen + 4);
        if (nextClose === -1) {
          commentStart = line.start + nextOpen;
          break;
        }
        maskedRanges.push({ start: line.start + nextOpen, end: line.start + nextClose + 3 });
        cursor = nextClose + 3;
      }
      continue;
    }

    const opening = /^( {0,3})(`{3,}|~{3,})(.*)$/.exec(line.text);
    if (opening && !(opening[2][0] === "`" && opening[3].includes("`"))) {
      activeFence = {
        start: line.start,
        contentStart: line.end,
        character: opening[2][0],
        length: opening[2].length,
        info: opening[3].trim(),
      };
      continue;
    }

    let cursor = 0;
    while (cursor < line.text.length) {
      const open = line.text.indexOf("<!--", cursor);
      if (open === -1) {
        break;
      }
      const close = line.text.indexOf("-->", open + 4);
      if (close === -1) {
        commentStart = line.start + open;
        break;
      }
      maskedRanges.push({ start: line.start + open, end: line.start + close + 3 });
      cursor = close + 3;
    }
  }

  if (activeFence) {
    const block = { ...activeFence, closed: false, contentEnd: source.length, end: source.length };
    fencedBlocks.push(block);
    maskedRanges.push({ start: block.start, end: block.end });
  }
  if (commentStart != null) {
    maskedRanges.push({ start: commentStart, end: source.length });
  }

  return { fencedBlocks, masked: maskRanges(source, maskedRanges) };
}

function exactLineMatch(source, marker) {
  const escapedMarker = marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`^${escapedMarker}[ \\t]*$`, "m").exec(source);
}

const secondLevelHeadings = [...structuralMarkdown.matchAll(/^## .+?[ \t]*$/gm)].map((match) => ({
  index: match.index,
  length: match[0].length,
}));

function rangeAfterStructuralMarker(marker) {
  const match = exactLineMatch(structuralMarkdown, marker);
  if (!match) {
    return null;
  }
  const bodyStart = match.index + match[0].length;
  const nextHeading = secondLevelHeadings.find((heading) => heading.index > match.index);
  return { start: bodyStart, end: nextHeading?.index ?? markdown.length };
}

function bodyAfterStructuralMarker(source, marker) {
  const range = rangeAfterStructuralMarker(marker);
  return range ? source.slice(range.start, range.end).trim() : "";
}

function fencedContentAfterMarker(marker, language) {
  const range = rangeAfterStructuralMarker(marker);
  if (!range) {
    return null;
  }
  const block = markdownStructure.fencedBlocks.find((candidate) => {
    const [candidateLanguage] = candidate.info.split(/[ \t]+/);
    return candidate.closed && candidate.start >= range.start && candidate.end <= range.end && candidateLanguage === language;
  });
  return block ? markdown.slice(block.contentStart, block.contentEnd) : null;
}

const titleMatch = structuralMarkdown.match(/^# [a-z0-9]+(?:-[a-z0-9]+)*\n/m);
if (!titleMatch) {
  failures.push("title must be lowercase hyphen-case");
} else {
  const mappingMatch = exactLineMatch(structuralMarkdown, "Expected source-layer mapping:");
  const mappingIndex = mappingMatch?.index ?? -1;
  const preamble = mappingIndex >= 0
    ? structuralMarkdown.slice(titleMatch.index + titleMatch[0].length, mappingIndex).trim()
    : "";
  const openingParagraph = preamble.split(/\n\s*\n/)[0]?.replace(/\s+/g, " ").trim() ?? "";
  if (openingParagraph.length < 40 || /^[-#]/.test(openingParagraph)) {
    failures.push("missing descriptive opening paragraph with intended categories and core visual grammar");
  }
}

let lastHeadingIndex = -1;
for (const heading of requiredHeadings) {
  const escapedHeading = heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const headingPattern = new RegExp(`^${escapedHeading}[ \\t]*$`, "gm");
  const headingMatches = [...structuralMarkdown.matchAll(headingPattern)];
  if (headingMatches.length === 0) {
    failures.push(`missing heading: ${heading}`);
    continue;
  }
  if (headingMatches.length > 1) {
    failures.push(`duplicate heading: ${heading}`);
  }
  const index = headingMatches[0].index;
  if (index < lastHeadingIndex) {
    failures.push(`heading out of order: ${heading}`);
  }
  lastHeadingIndex = index;
}

const variantBody = bodyAfterStructuralMarker(structuralMarkdown, "## Variant Axes");
if (!/^- \S.+$/m.test(variantBody)) {
  failures.push("Variant Axes must contain at least one non-empty bullet");
}

const conversionFlowBody = bodyAfterStructuralMarker(structuralMarkdown, "## Template Conversion Flow");
if (conversionFlowBody.replace(/\s+/g, " ").trim().length < 40) {
  failures.push("Template Conversion Flow must describe a concrete app-icon-gen route");
}

const mappingBody = bodyAfterStructuralMarker(structuralMarkdown, "Expected source-layer mapping:");
if (!exactLineMatch(structuralMarkdown, "Expected source-layer mapping:")) {
  failures.push("missing Expected source-layer mapping section");
} else if (!/^- .+ -> .+$/m.test(mappingBody)) {
  failures.push("Expected source-layer mapping must include one or more '- layer -> target' entries");
}

const styleContent = fencedContentAfterMarker("## Style Family Template", "text");
if (styleContent == null) {
  failures.push("missing text fence in Style Family Template");
} else if (styleContent.trim().length < 40 || !styleContent.includes("{app_name}")) {
  failures.push("Style Family Template text fence must include {app_name}");
}

const exampleContent = fencedContentAfterMarker("## Example Instantiation (Not A Default)", "text");
if (exampleContent == null || exampleContent.trim().length < 40) {
  failures.push("Example Instantiation must contain a non-empty text example");
}

const contractContent = fencedContentAfterMarker("## Example Conversion Contract (Adapt After Selection)", "json");
if (contractContent == null) {
  failures.push("missing JSON fence in Example Conversion Contract");
} else {
  try {
    const contract = JSON.parse(contractContent);
    if (!validateContract(contract)) {
      const details = validateContract.errors
        .map((error) => `${error.instancePath || "/"} ${error.message}`)
        .join("; ");
      failures.push(`Example Conversion Contract does not match schema: ${details}`);
    }
  } catch (error) {
    failures.push(`Example Conversion Contract JSON is invalid: ${error.message}`);
  }
}

const unresolvedMarkers = ["TB" + "D", "TO" + "DO", "fill\\s+in\\s+later"];
const unresolvedPattern = new RegExp(`\\b(?:${unresolvedMarkers.join("|")})\\b`, "i");
if (unresolvedPattern.test(markdown)) {
  failures.push("template contains unresolved marker language");
}

if (failures.length > 0) {
  console.error(JSON.stringify({ ok: false, file: filePath, failures }, null, 2));
  process.exit(1);
}

console.log(JSON.stringify({ ok: true, file: filePath }, null, 2));
