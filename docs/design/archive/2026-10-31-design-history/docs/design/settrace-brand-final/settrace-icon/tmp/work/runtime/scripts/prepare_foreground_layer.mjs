#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { extname } from "node:path";
import jpeg from "jpeg-js";
import { PNG } from "pngjs";

function usage() {
  console.error(
    "Usage: node prepare_foreground_layer.mjs --input INPUT.{png,jpg,jpeg} --out OUT.png --mode light-on-dark|light-on-color|non-background [--background #000000] [--threshold 132] [--alpha-low 82] [--alpha-high 166] [--color #ffffff] [--preserve-rgb] [--min-rgb 0] [--grow 0] [--region x,y,w,h] [--keep-components largest|all]",
  );
}

function parseArgs(argv) {
  const parsed = {
    mode: "light-on-dark",
    threshold: 132,
    alphaLow: 82,
    alphaHigh: 166,
    background: "#000000",
    color: "#ffffff",
    preserveRgb: false,
    minRgb: 0,
    grow: 0,
    region: null,
    keepComponents: null,
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
    } else if (arg === "--mode") {
      parsed.mode = next;
      i += 1;
    } else if (arg === "--threshold") {
      parsed.threshold = Number(next);
      i += 1;
    } else if (arg === "--alpha-low") {
      parsed.alphaLow = Number(next);
      i += 1;
    } else if (arg === "--alpha-high") {
      parsed.alphaHigh = Number(next);
      i += 1;
    } else if (arg === "--background") {
      parsed.background = next;
      i += 1;
    } else if (arg === "--color") {
      parsed.color = next;
      i += 1;
    } else if (arg === "--preserve-rgb") {
      parsed.preserveRgb = true;
    } else if (arg === "--min-rgb") {
      parsed.minRgb = Number(next);
      i += 1;
    } else if (arg === "--grow") {
      parsed.grow = Number(next);
      i += 1;
    } else if (arg === "--region") {
      parsed.region = parseRegion(next);
      i += 1;
    } else if (arg === "--keep-components") {
      parsed.keepComponents = next;
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input || !parsed.out) {
    throw new Error("--input and --out are required");
  }
  if (!["light-on-dark", "light-on-color", "non-background"].includes(parsed.mode)) {
    throw new Error('--mode must be "light-on-dark", "light-on-color", or "non-background"');
  }
  parsed.keepComponents ??= parsed.mode === "non-background" ? "all" : "largest";
  if (!["largest", "all"].includes(parsed.keepComponents)) {
    throw new Error('--keep-components must be "largest" or "all"');
  }
  if (!Number.isFinite(parsed.threshold) || parsed.threshold < 0 || parsed.threshold > 255) {
    throw new Error("--threshold must be a number from 0 to 255");
  }
  if (!Number.isFinite(parsed.alphaLow) || !Number.isFinite(parsed.alphaHigh) || parsed.alphaLow < 0 || parsed.alphaHigh > 255 || parsed.alphaLow >= parsed.alphaHigh) {
    throw new Error("--alpha-low and --alpha-high must be ordered numbers from 0 to 255");
  }
  if (!Number.isInteger(parsed.grow) || parsed.grow < 0) {
    throw new Error("--grow must be a non-negative integer");
  }
  if (!Number.isFinite(parsed.minRgb) || parsed.minRgb < 0 || parsed.minRgb > 255) {
    throw new Error("--min-rgb must be a number from 0 to 255");
  }
  return parsed;
}

function parseRegion(value) {
  const parts = String(value).split(",").map((part) => Number(part.trim()));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part))) {
    throw new Error("--region must be x,y,w,h");
  }
  const [x, y, width, height] = parts;
  if (x < 0 || y < 0 || width <= 0 || height <= 0) {
    throw new Error("--region values must be non-negative x/y and positive width/height");
  }
  return { x, y, width, height };
}

function parseHexColor(value) {
  const match = /^#?([0-9a-fA-F]{6})$/.exec(String(value).trim());
  if (!match) {
    throw new Error(`expected 6-digit hex color, got: ${value}`);
  }
  const hex = match[1];
  return [
    Number.parseInt(hex.slice(0, 2), 16),
    Number.parseInt(hex.slice(2, 4), 16),
    Number.parseInt(hex.slice(4, 6), 16),
  ];
}

function decodePng(bytes) {
  const png = PNG.sync.read(bytes);
  return {
    width: png.width,
    height: png.height,
    data: png.data,
  };
}

function decodeJpeg(bytes) {
  const decoded = jpeg.decode(bytes, { useTArray: true, colorTransform: true });
  return {
    width: decoded.width,
    height: decoded.height,
    data: decoded.data,
  };
}

async function decodeImage(path) {
  const bytes = await readFile(path);
  const ext = extname(path).toLowerCase();
  if (ext === ".png") {
    return decodePng(bytes);
  }
  if (ext === ".jpg" || ext === ".jpeg") {
    return decodeJpeg(bytes);
  }
  throw new Error(`unsupported input extension: ${ext || "(none)"}`);
}

function luminance(data, offset) {
  return 0.2126 * data[offset] + 0.7152 * data[offset + 1] + 0.0722 * data[offset + 2];
}

function chroma(data, offset) {
  const max = Math.max(data[offset], data[offset + 1], data[offset + 2]);
  const min = Math.min(data[offset], data[offset + 1], data[offset + 2]);
  return max - min;
}

function colorDistance(data, offset, background) {
  const dr = data[offset] - background[0];
  const dg = data[offset + 1] - background[1];
  const db = data[offset + 2] - background[2];
  return Math.sqrt(dr * dr + dg * dg + db * db);
}

function minChannel(data, offset) {
  return Math.min(data[offset], data[offset + 1], data[offset + 2]);
}

function foregroundScore(data, offset, args, background) {
  if (args.mode === "light-on-dark") {
    return luminance(data, offset);
  }
  if (args.mode === "light-on-color") {
    return minChannel(data, offset);
  }
  return Math.max(colorDistance(data, offset, background), chroma(data, offset));
}

function smoothstep(edge0, edge1, value) {
  const t = Math.max(0, Math.min(1, (value - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

function isInsideRegion(x, y, region) {
  if (!region) {
    return true;
  }
  return x >= region.x && y >= region.y && x < region.x + region.width && y < region.y + region.height;
}

function buildCandidateMask(image, args, background) {
  const mask = new Uint8Array(image.width * image.height);
  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const index = y * image.width + x;
      const offset = index * 4;
      if (isInsideRegion(x, y, args.region) && image.data[offset + 3] > 0 && foregroundScore(image.data, offset, args, background) >= args.threshold) {
        mask[index] = 1;
      }
    }
  }
  return mask;
}

function largestComponent(mask, width, height) {
  const visited = new Uint8Array(mask.length);
  const queue = [];
  let best = [];

  for (let start = 0; start < mask.length; start += 1) {
    if (!mask[start] || visited[start]) {
      continue;
    }
    const component = [];
    queue.length = 0;
    visited[start] = 1;
    queue.push(start);
    for (let cursor = 0; cursor < queue.length; cursor += 1) {
      const current = queue[cursor];
      component.push(current);
      const x = current % width;
      const y = Math.floor(current / width);
      const neighbors = [];
      if (x > 0) neighbors.push(current - 1);
      if (x < width - 1) neighbors.push(current + 1);
      if (y > 0) neighbors.push(current - width);
      if (y < height - 1) neighbors.push(current + width);
      for (const neighbor of neighbors) {
        if (mask[neighbor] && !visited[neighbor]) {
          visited[neighbor] = 1;
          queue.push(neighbor);
        }
      }
    }
    if (component.length > best.length) {
      best = component;
    }
  }

  if (best.length === 0) {
    throw new Error("no light foreground component found after thresholding");
  }
  const keep = new Uint8Array(mask.length);
  for (const index of best) {
    keep[index] = 1;
  }
  return { mask: keep, size: best.length };
}

function growMask(mask, width, height, passes) {
  const grown = new Uint8Array(mask);
  for (let pass = 0; pass < passes; pass += 1) {
    const copy = new Uint8Array(grown);
    for (let y = 1; y < height - 1; y += 1) {
      for (let x = 1; x < width - 1; x += 1) {
        const index = y * width + x;
        if (copy[index]) {
          continue;
        }
        if (copy[index - 1] || copy[index + 1] || copy[index - width] || copy[index + width]) {
          grown[index] = 1;
        }
      }
    }
  }
  return grown;
}

function renderForeground(image, keepMask, args, color, background) {
  const out = new PNG({ width: image.width, height: image.height });
  let visiblePixels = 0;
  let minX = image.width;
  let minY = image.height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const index = y * image.width + x;
      const offset = index * 4;
      const score = foregroundScore(image.data, offset, args, background);
      const alpha = keepMask[index] ? Math.round(255 * smoothstep(args.alphaLow, args.alphaHigh, score) * (image.data[offset + 3] / 255)) : 0;
      const outputAlpha = alpha < 4 ? 0 : alpha;
      if (outputAlpha === 0) {
        out.data[offset] = 0;
        out.data[offset + 1] = 0;
        out.data[offset + 2] = 0;
      } else if (args.preserveRgb) {
        out.data[offset] = Math.max(image.data[offset], args.minRgb);
        out.data[offset + 1] = Math.max(image.data[offset + 1], args.minRgb);
        out.data[offset + 2] = Math.max(image.data[offset + 2], args.minRgb);
      } else {
        out.data[offset] = color[0];
        out.data[offset + 1] = color[1];
        out.data[offset + 2] = color[2];
      }
      out.data[offset + 3] = outputAlpha;
      if (out.data[offset + 3] > 0) {
        visiblePixels += 1;
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }

  return {
    image: out,
    visiblePixels,
    bounds: visiblePixels > 0 ? { min_x: minX, min_y: minY, max_x: maxX, max_y: maxY } : null,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const color = parseHexColor(args.color);
  const background = parseHexColor(args.background);
  const source = await decodeImage(args.input);
  const candidate = buildCandidateMask(source, args, background);
  const component =
    args.keepComponents === "largest"
      ? largestComponent(candidate, source.width, source.height)
      : { mask: candidate, size: candidate.reduce((sum, value) => sum + value, 0) };
  if (component.size === 0) {
    throw new Error("no foreground pixels found after thresholding");
  }
  const keepMask = growMask(component.mask, source.width, source.height, args.grow);
  const output = renderForeground(source, keepMask, args, color, background);
  await writeFile(args.out, PNG.sync.write(output.image));
  console.log(
    JSON.stringify(
      {
        out: args.out,
        width: output.image.width,
        height: output.image.height,
        mode: args.mode,
        keep_components: args.keepComponents,
        component_pixels: component.size,
        visible_pixels: output.visiblePixels,
        visible_bounds: output.bounds,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  usage();
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
