#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { extname, resolve } from "node:path";
import { Resvg } from "@resvg/resvg-js";

function usage() {
  console.error("Usage: node normalize_reference.mjs --input INPUT.{png,jpg,jpeg} --out OUT.png [--width 1024] [--radius 224]");
}

function parseArgs(argv) {
  const parsed = {
    width: 1024,
    radius: 224,
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
    } else if (arg === "--width") {
      parsed.width = Number(next);
      i += 1;
    } else if (arg === "--radius") {
      parsed.radius = Number(next);
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input || !parsed.out) {
    throw new Error("--input and --out are required");
  }
  if (!Number.isFinite(parsed.width) || parsed.width <= 0) {
    throw new Error("--width must be a positive number");
  }
  if (!Number.isFinite(parsed.radius) || parsed.radius < 0) {
    throw new Error("--radius must be a non-negative number");
  }
  const ext = extname(parsed.input).toLowerCase();
  if (![".png", ".jpg", ".jpeg"].includes(ext)) {
    throw new Error(`unsupported input extension: ${ext || "(none)"}`);
  }
  return parsed;
}

function escapeAttr(value) {
  return String(value).replace(/&/g, "&amp;").replace(/"/g, "&quot;");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const input = resolve(args.input);
  const out = resolve(args.out);
  await readFile(input);
  const radius = Math.min(args.radius, args.width / 2);
  const clip = radius > 0 ? `<defs><clipPath id="icon-mask"><rect width="${args.width}" height="${args.width}" rx="${radius}"/></clipPath></defs>` : "";
  const openGroup = radius > 0 ? '<g clip-path="url(#icon-mask)">' : "";
  const closeGroup = radius > 0 ? "</g>" : "";
  const svg = `<svg width="${args.width}" height="${args.width}" viewBox="0 0 ${args.width} ${args.width}" xmlns="http://www.w3.org/2000/svg">
${clip}
${openGroup}<image href="${escapeAttr(input)}" width="${args.width}" height="${args.width}"/>${closeGroup}
</svg>
`;
  const png = new Resvg(svg, { fitTo: { mode: "width", value: args.width } }).render().asPng();
  await writeFile(out, png);
  console.log(JSON.stringify({ out, width: args.width, radius }, null, 2));
}

main().catch((error) => {
  usage();
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
