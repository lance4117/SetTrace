#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { extname } from "node:path";
import jpeg from "jpeg-js";
import { PNG } from "pngjs";

function usage() {
  console.error("Usage: node prepare_bitmap_layer.mjs --input INPUT.{png,jpg,jpeg} --out OUT.png [--mode dark-on-light] [--color #000000] [--cutoff 250] [--padding 0] [--preserve-canvas]");
}

function parseArgs(argv) {
  const parsed = {
    mode: "dark-on-light",
    color: "#000000",
    cutoff: 250,
    padding: 0,
    preserveCanvas: false,
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
    } else if (arg === "--color") {
      parsed.color = next;
      i += 1;
    } else if (arg === "--cutoff") {
      parsed.cutoff = Number(next);
      i += 1;
    } else if (arg === "--padding") {
      parsed.padding = Number(next);
      i += 1;
    } else if (arg === "--preserve-canvas") {
      parsed.preserveCanvas = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input || !parsed.out) {
    throw new Error("--input and --out are required");
  }
  if (parsed.mode !== "dark-on-light") {
    throw new Error('only --mode dark-on-light is currently supported');
  }
  if (!Number.isFinite(parsed.cutoff) || parsed.cutoff <= 0 || parsed.cutoff > 255) {
    throw new Error("--cutoff must be a number from 1 to 255");
  }
  if (!Number.isInteger(parsed.padding) || parsed.padding < 0) {
    throw new Error("--padding must be a non-negative integer");
  }
  return parsed;
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

function alphaFromDarkOnLight({ r, g, b, a }, cutoff) {
  const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  if (luminance >= cutoff || a === 0) {
    return 0;
  }
  const matteAlpha = Math.round(((cutoff - luminance) / cutoff) * 255);
  return Math.max(0, Math.min(255, Math.round((matteAlpha * a) / 255)));
}

function buildMatte(image, color, cutoff) {
  const out = new PNG({ width: image.width, height: image.height });
  let minX = image.width;
  let minY = image.height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const offset = (y * image.width + x) * 4;
      const alpha = alphaFromDarkOnLight(
        {
          r: image.data[offset],
          g: image.data[offset + 1],
          b: image.data[offset + 2],
          a: image.data[offset + 3],
        },
        cutoff,
      );
      out.data[offset] = color[0];
      out.data[offset + 1] = color[1];
      out.data[offset + 2] = color[2];
      out.data[offset + 3] = alpha;
      if (alpha > 0) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }

  if (maxX < 0) {
    throw new Error("no visible dark artwork found after matte extraction");
  }
  return { image: out, bounds: { minX, minY, maxX, maxY } };
}

function cropWithPadding(source, bounds, padding) {
  const minX = Math.max(0, bounds.minX - padding);
  const minY = Math.max(0, bounds.minY - padding);
  const maxX = Math.min(source.width - 1, bounds.maxX + padding);
  const maxY = Math.min(source.height - 1, bounds.maxY + padding);
  const width = maxX - minX + 1;
  const height = maxY - minY + 1;
  const out = new PNG({ width, height });

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const srcOffset = ((minY + y) * source.width + (minX + x)) * 4;
      const dstOffset = (y * width + x) * 4;
      out.data[dstOffset] = source.data[srcOffset];
      out.data[dstOffset + 1] = source.data[srcOffset + 1];
      out.data[dstOffset + 2] = source.data[srcOffset + 2];
      out.data[dstOffset + 3] = source.data[srcOffset + 3];
    }
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const color = parseHexColor(args.color);
  const source = await decodeImage(args.input);
  const matte = buildMatte(source, color, args.cutoff);
  const output = args.preserveCanvas ? matte.image : cropWithPadding(matte.image, matte.bounds, args.padding);
  await writeFile(args.out, PNG.sync.write(output));
  console.log(
    JSON.stringify(
      {
        out: args.out,
        width: output.width,
        height: output.height,
        preserve_canvas: args.preserveCanvas,
        visible_bounds: {
          min_x: matte.bounds.minX,
          min_y: matte.bounds.minY,
          max_x: matte.bounds.maxX,
          max_y: matte.bounds.maxY,
        },
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
