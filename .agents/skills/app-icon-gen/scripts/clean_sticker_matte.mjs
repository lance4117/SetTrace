#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { PNG } from "pngjs";

function usage() {
  console.error(
    "Usage: node clean_sticker_matte.mjs --input INPUT.png --out OUT.png [--preview-on-black PREVIEW.png] [--mode souvenir-decal-stickers] [--aa-threshold 2]",
  );
}

function parseArgs(argv) {
  const parsed = {
    mode: "souvenir-decal-stickers",
    aaThreshold: 2,
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
    } else if (arg === "--preview-on-black") {
      parsed.previewOnBlack = next;
      i += 1;
    } else if (arg === "--mode") {
      parsed.mode = next;
      i += 1;
    } else if (arg === "--aa-threshold") {
      parsed.aaThreshold = Number(next);
      i += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!parsed.input || !parsed.out) {
    throw new Error("--input and --out are required");
  }
  if (parsed.mode !== "souvenir-decal-stickers") {
    throw new Error('--mode currently supports only "souvenir-decal-stickers"');
  }
  if (!Number.isInteger(parsed.aaThreshold) || parsed.aaThreshold < 1 || parsed.aaThreshold > 8) {
    throw new Error("--aa-threshold must be an integer from 1 to 8");
  }
  return parsed;
}

function luminance(r, g, b) {
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function isSouvenirStickerPixel(data, offset) {
  const r = data[offset];
  const g = data[offset + 1];
  const b = data[offset + 2];
  const alpha = data[offset + 3];
  if (alpha === 0) {
    return false;
  }

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const chroma = max - min;
  const lightness = luminance(r, g, b);

  const blackOrDarkDetail = lightness < 130;
  const saturatedOrColored = chroma > 24;
  const warmWhiteSticker = r > 224 && g > 215 && b > 196 && r >= b - 2 && g >= b - 8;
  const creamStickerEdge = r > 205 && g > 198 && b > 178 && r >= b + 2 && g >= b - 10;

  // Souvenir decal generations often include a cool gray-blue halo from the
  // source background shadow. Keep warm decal paper, flat color, and dark ink;
  // drop only low-chroma cool-gray exterior pixels.
  const coolGrayShadowHalo = chroma < 22 && b >= r - 2 && g >= r - 10 && lightness > 135 && lightness < 248;

  return blackOrDarkDetail || saturatedOrColored || warmWhiteSticker || creamStickerEdge || !coolGrayShadowHalo;
}

function buildCoreMask(image) {
  const mask = new Uint8Array(image.width * image.height);
  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const index = y * image.width + x;
      const offset = index * 4;
      if (isSouvenirStickerPixel(image.data, offset)) {
        mask[index] = 1;
      }
    }
  }
  return mask;
}

function cleanMatte(image, coreMask, aaThreshold) {
  const out = new PNG({ width: image.width, height: image.height });
  const stats = {
    visible_pixels_before: 0,
    semi_transparent_pixels_before: 0,
    visible_pixels_after: 0,
    semi_transparent_pixels_after: 0,
    removed_visible_pixels: 0,
    bounds_after: null,
  };
  let minX = image.width;
  let minY = image.height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      const index = y * image.width + x;
      const offset = index * 4;
      const sourceAlpha = image.data[offset + 3];
      if (sourceAlpha > 0) {
        stats.visible_pixels_before += 1;
        if (sourceAlpha < 255) {
          stats.semi_transparent_pixels_before += 1;
        }
      }

      if (coreMask[index]) {
        out.data[offset] = image.data[offset];
        out.data[offset + 1] = image.data[offset + 1];
        out.data[offset + 2] = image.data[offset + 2];
        out.data[offset + 3] = 255;
      } else {
        let neighbors = 0;
        let red = 0;
        let green = 0;
        let blue = 0;
        for (let yy = -1; yy <= 1; yy += 1) {
          for (let xx = -1; xx <= 1; xx += 1) {
            if (xx === 0 && yy === 0) {
              continue;
            }
            const nx = x + xx;
            const ny = y + yy;
            if (nx < 0 || ny < 0 || nx >= image.width || ny >= image.height) {
              continue;
            }
            const neighborIndex = ny * image.width + nx;
            if (coreMask[neighborIndex]) {
              const neighborOffset = neighborIndex * 4;
              neighbors += 1;
              red += image.data[neighborOffset];
              green += image.data[neighborOffset + 1];
              blue += image.data[neighborOffset + 2];
            }
          }
        }
        if (neighbors >= aaThreshold) {
          out.data[offset] = Math.round(red / neighbors);
          out.data[offset + 1] = Math.round(green / neighbors);
          out.data[offset + 2] = Math.round(blue / neighbors);
          out.data[offset + 3] = Math.min(160, Math.round((neighbors / 8) * 220));
        } else {
          out.data[offset] = image.data[offset];
          out.data[offset + 1] = image.data[offset + 1];
          out.data[offset + 2] = image.data[offset + 2];
          out.data[offset + 3] = 0;
        }
      }

      const outputAlpha = out.data[offset + 3];
      if (outputAlpha > 0) {
        stats.visible_pixels_after += 1;
        if (outputAlpha < 255) {
          stats.semi_transparent_pixels_after += 1;
        }
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }

  stats.removed_visible_pixels = stats.visible_pixels_before - stats.visible_pixels_after;
  stats.bounds_after =
    stats.visible_pixels_after > 0
      ? {
          min_x: minX,
          min_y: minY,
          max_x: maxX,
          max_y: maxY,
        }
      : null;
  return { image: out, stats };
}

function renderOnBlack(image) {
  const out = new PNG({ width: image.width, height: image.height });
  for (let index = 0; index < image.width * image.height; index += 1) {
    const offset = index * 4;
    const alpha = image.data[offset + 3] / 255;
    out.data[offset] = Math.round(image.data[offset] * alpha);
    out.data[offset + 1] = Math.round(image.data[offset + 1] * alpha);
    out.data[offset + 2] = Math.round(image.data[offset + 2] * alpha);
    out.data[offset + 3] = 255;
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const input = PNG.sync.read(await readFile(args.input));
  const coreMask = buildCoreMask(input);
  const cleaned = cleanMatte(input, coreMask, args.aaThreshold);
  await writeFile(args.out, PNG.sync.write(cleaned.image));
  if (args.previewOnBlack) {
    await writeFile(args.previewOnBlack, PNG.sync.write(renderOnBlack(cleaned.image)));
  }
  console.log(
    JSON.stringify(
      {
        out: args.out,
        mode: args.mode,
        aa_threshold: args.aaThreshold,
        ...cleaned.stats,
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
