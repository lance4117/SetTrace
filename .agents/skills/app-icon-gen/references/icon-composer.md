# Icon Composer Notes

Use this when a task depends on Icon Composer-specific behavior, `.icon` bundle structure, canvas fill, layer ordering, text handling, or Liquid Glass options.

## Contents

- [Official Guidance To Preserve](#official-guidance-to-preserve)
- [Skill Output Rules](#skill-output-rules)
- [Fill Modes](#fill-modes)
- [High-Contrast Black Mark On Light Fill](#high-contrast-black-mark-on-light-fill)
- [PNG Layer Fallback](#png-layer-fallback)
- [Asset Format Decision](#asset-format-decision)
- [Text Handling](#text-handling)
- [Known `icon.json` Fields From Local Evidence](#known-iconjson-fields-from-local-evidence)

## Official Guidance To Preserve

Apple describes Icon Composer as a tool for creating layered Liquid Glass icons from a single design for iPhone, iPad, Mac, and Apple Watch. The tool lets users organize artwork layers and adjust properties such as specular highlights, refraction, translucency, and shadows. Source: https://developer.apple.com/icon-composer/

The WWDC25 Icon Composer session adds practical export rules:

- Use a 1024px canvas for iPhone, iPad, and Mac artwork.
- Keep the shared `author-icon`/Icon Composer source canvas at 1024px. The delivered watchOS render is a 1088px circle in the Default appearance only; `ictool` performs that platform export. Do not set a watch-only author spec to a 1088px source canvas, and do not treat iOS/macOS dark, tinted, or clear exports as watchOS deliverables. Inspect the circular crop separately and avoid a solid black full-canvas background that visually disappears into the watch display/bezel.
- Design with layers; each layer is a Z-depth step, with the background at the bottom and foreground layers stacked above it.
- Export source layers as SVG when the artwork is flat/vector-friendly.
- Keep source art flat, opaque, and easy to control; add blur, shadow, specular, opacity, translucency, and glass behavior inside Icon Composer instead of baking them into source SVGs.
- Keep source `layers/` and spec order bottom-to-top for local preview. In generated `.icon/icon.json`, write `groups[].layers` in front-to-back display order: local Icon Composer/Quick Look evidence shows the first JSON entry renders above later entries.
- Add simple background colors and gradients directly in Icon Composer instead of exporting them as SVG layers.
- Convert text to outlines before exporting because SVG does not preserve fonts reliably for this use.
- Export custom gradients, raster images, and non-SVG effects as PNG when SVG cannot express them cleanly.
- Do not include rounded rectangle or circle masks in exports; Icon Composer applies the platform crop later.

Source: https://developer.apple.com/videos/play/wwdc2025/361/

The related app-icon design session emphasizes simpler frontal artwork, bolder shapes, rounder corners, layering, translucency, more breathing room, and softer light-to-dark backgrounds that harmonize with the lighting model. It also recommends reducing baked-in static effects, using the material to add nuance, and considering colored backgrounds for stronger distinction across appearance modes. Source: https://developer.apple.com/videos/play/wwdc2025/220/

## Skill Output Rules

- Keep preview/app SVG/PNG outputs separate from the Apple `.icon` bundle.
- In delivery layout, put `<delivery-name>.preview.svg`, `<delivery-name>.preview.png`, `<delivery-name>.svg`, `<delivery-name>.png`, optional source evidence `<delivery-name>.origin.png` or `<delivery-name>.origin.svg`, root `layers/*.svg` or `layers/*.png`, root `<IconName>.icon/`, optional `apple/` rendered products, `tmp/reports/style-report.json`, and `tmp/README.md` under the delivery root.
- Put only Icon Composer import assets and `icon.json` inside the UpperCamelCase `.icon` bundle.
- Use `*.preview.*` for rounded review/presentation and reference diff. Use the plain root `.svg`/`.png` pair for the unrounded source/app canvas. Use `*.origin.*` only for the selected source/reference/generated concept evidence; do not import it into `.icon/Assets`.
- On macOS, when Icon Composer.app's bundled `ictool` exists, `author-icon` exports only the requested platform profiles under `apple/`: iOS and macOS receive 1024px `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, and `ClearDark` products; watchOS receives one 1088px `Default` product. `iPadOS` uses the iOS export profile. Use `tint-color 0.25` and `tint-strength 0.75` for iOS/macOS tinted renditions.
- Treat `apple/` as rendered product output that still needs visual inspection, not as proof of app integration or publication readiness. Absence of `apple/` on non-macOS machines or machines without Icon Composer.app's `ictool` is expected and should produce `platform_review_pending`, not a structural package failure.
- Omit `preview.html`.
- Do not emit `<text>` in `.icon/Assets/*.svg`. A local source SVG may contain `<text>` only when that layer is rendered to PNG before Icon Composer import.
- Do not emit `<image>` in `.icon/Assets/*.svg`. Render embedded-image layers to PNG before Icon Composer import.
- Do not include app-icon rounded masks in `.icon/Assets` or app/source outputs. Keep masks only in `*.preview.*` outputs.
- For simple solid or gradient backgrounds, use Icon Composer canvas fill in `icon.json.fill` and record the chosen fill in `style-report.json`.
- Do not invent inner border strokes or frame highlights in source layers unless they are requested or visible in the source.
- Do not bake Liquid Glass material into `.icon/Assets` SVGs. Imported SVG layers should describe editable shapes; specular highlights, bevel edges, refraction, translucency, blur, and soft shadows should be Icon Composer settings or an explicit PNG fallback.
- Geometry-polished SVGs are acceptable only when they remain clean base shapes. Smoothing should remove trace noise or uneven arcs; it must not add strokes, opacity layers, gradients, filters, or material helper paths, and it must not alter the mark's identity-defining negative space or terminals.
- Do not write shadow, glass, translucency, bevel, or specular Icon Composer settings by default. These settings can create visible extra outlines or duplicate-looking layers; include them only when the spec or user explicitly asks for that material behavior.
- When the user asks for a Liquid Glass rendered product, or a template has an explicit Composer material preset, keep the source SVG flat and put material in `icon.json` group/layer settings. Locally observed Icon Composer 2.0 output uses group fields such as `blur-material`, `refractivity`, `translucency`, and `shadow`, plus layer fields such as `fill` and `blend-mode`.
- Preview-only layers may simulate rendered material for local review, but they must set `composer.include: false` and must not appear in `.icon/Assets` or `icon.json.groups[].layers`.
- For complex visual backgrounds, include a background SVG or PNG as the bottom imported layer.
- Do not use one full rendered icon PNG as the only imported layer. That bypasses Icon Composer composition and blocks useful background, material, and appearance-mode adjustments. Keep full rendered images as local evidence, not as the whole `.icon` bundle.
- Keep `icon.json.fill` conservative. Local preview SVGs can use richer gradients for reference comparison, but the `.icon` fill must use an observed Icon Composer-safe form. In local testing, 4-stop `linear-gradient` previewed correctly but made Icon Composer refuse to open the `.icon`.
- For SVG rendering artifacts inside Icon Composer, keep the source SVGs in local `layers/` and put pre-rendered PNG assets in `.icon/Assets` for the affected icon only.
- Decide SVG vs PNG per layer, not per whole icon.
- PNG is acceptable Icon Composer source material when it is clean authored: flat color, linear gradient, text/raster content, dense brand artwork, or a deliberate custom-gradient layer with no source-background residue.
- If the route is `semantic-svg` or `semantic-svg-approximation`, keep at least one SVG foreground import in `.icon/Assets`; PNG-only foreground imports are a PNG fallback route and reduce appearance/material adaptability.
- A source-cut PNG layer that matches a rendered reference can still fail in Icon Composer. Liquid Glass can reveal hard mattes, rectangular bounds, baked shadows, copied highlights, or background residue. Treat those screenshots as evidence to redraw the layer as SVG/base geometry, not as a reason to tune the PNG harder.

## Fill Modes

Use these observed `icon.json.fill` forms:

```json
"fill": "automatic"
```

```json
"fill": {
  "automatic-gradient": "extended-srgb:0.00000,0.53333,1.00000,1.00000"
}
```

```json
"fill": {
  "solid": "extended-gray:1.00000,1.00000"
}
```

```json
"fill": {
  "linear-gradient": [
    "extended-gray:1.00000,1.00000",
    "extended-srgb:0.00000,0.75294,0.90980,1.00000"
  ],
  "orientation": {
    "start": { "x": 0.5, "y": 1 },
    "stop": { "x": 0.5, "y": 0 }
  }
}
```

`linear-gradient` must use exactly two color stops for Icon Composer compatibility. Stops may use `extended-gray`, `extended-srgb`, or a mix of both. Prefer `extended-gray` for neutral gray/white fills and `extended-srgb` for colored fills. If a reference preview needs 3+ stops or localized light patches, either approximate the `.icon` fill with two broad stops while keeping the richer local preview background, or import a deliberate complex background layer.

## High-Contrast Black Mark On Light Fill

Use this Icon Composer treatment when the selected concept is a near-black, flat SVG foreground on a near-white or warm-white canvas, and the mark's identity depends on a bold silhouette rather than color detail. This is especially useful for generated app-icon concepts where the local preview has a black organic or geometric mark over an off-white field.

Recommended `.icon` behavior:

- Keep the near-white background as `icon.json.fill`, not as an imported background asset.
- Keep the foreground as a clean SVG asset. Do not rasterize it only to preserve black-on-white contrast.
- Leave the default/light appearance as the flat dark mark over the light fill.
- In dark appearance, set the foreground layer to `system-light` and enable glass for that appearance so the mark remains visible and participates in the material model.
- In tinted appearance, set an explicit solid tint color on the foreground layer instead of relying on the black source fill.
- Use group-level `lighting: "individual"` with a neutral shadow and low translucency when the mark is a large simple silhouette; this gives Icon Composer enough depth without adding baked SVG highlights or extra outline paths.

Spec example:

```json
{
  "fill": {
    "solid": "extended-srgb:0.96863,0.95686,0.92549,1.00000"
  },
  "composer": {
    "group": {
      "lighting": "individual",
      "shadow": {
        "kind": "neutral",
        "opacity": 0.6
      },
      "translucency": {
        "enabled": true,
        "value": 0.2
      }
    }
  },
  "layers": [
    {
      "name": "black foreground mark",
      "svg": "<path d=\"...\" fill=\"#000000\"/>",
      "composer": {
        "format": "svg",
        "reason": "high-contrast black foreground remains editable while Icon Composer handles appearance variants",
        "blend-mode-specializations": [
          {
            "appearance": "dark",
            "value": "normal"
          }
        ],
        "fill-specializations": [
          {
            "appearance": "dark",
            "value": "system-light"
          },
          {
            "appearance": "tinted",
            "value": {
              "solid": "extended-srgb:0.00000,0.53333,1.00000,1.00000"
            }
          }
        ],
        "glass-specializations": [
          {
            "appearance": "dark",
            "value": true
          }
        ]
      }
    }
  ]
}
```

Do not use this preset for multicolor marks, low-contrast dark backgrounds, or source artwork whose identity depends on baked shadows, gradients, or texture. For those, choose per-layer SVG/PNG treatment from the asset-format rules instead.

## PNG Layer Fallback

Prefer SVG for editable flat/vector-friendly layers. Use PNG as a deliberate per-layer material when text, embedded raster, dense brand geometry, flat/linear-gradient raster artwork, renderer artifacts, unsupported SVG effects, or strict fidelity requirements make SVG unsuitable. Do not use PNG merely because it is easier to pass a reference diff.

There are two PNG routes:

- pre-authoring choice: text, embedded raster, flat color/linear gradient raster layers, dense brand marks, and complex artwork that should preserve rendered appearance
- post-preview fallback: one SVG layer looks correct in the preview SVG/PNG but renders poorly in Icon Composer

Use a PNG composer layer when needed:

```json
{
  "composer": { "format": "png", "reason": "Icon Composer import fidelity" }
}
```

This keeps source evidence in `layers/`, writes `*.png` files only for selected `.icon/Assets` layer entries, and points `icon.json.groups[].layers[].image-name` at those PNG files. If the source starts as an embedded bitmap, keep that source evidence as `layers/*.png` instead of generating a local SVG wrapper with an absolute `<image href>`. Do not convert every icon to PNG by default because that weakens editability and can make later Icon Composer tuning harder.

Visible jagged edges at high zoom are not always a blocker. PNG assets are raster images and will show pixels when magnified beyond their authored resolution. Treat this as acceptable when the icon reads cleanly at normal app-icon sizes. Investigate only if the artifact remains visible in realistic usage.

## Asset Format Decision

Default to SVG when a layer is:

- a simple silhouette, geometric mark, or clean flat vector shape
- made of a small number of paths
- expected to stay editable in Icon Composer or a vector editor
- free of text, bitmap effects, mesh-like gradients, and fragile filters
- free of baked Liquid Glass simulation such as inner shine strokes, bevel strokes, drop shadows, blur, or edge glints

Prefer PNG when a layer is:

- a user-supplied brand logo with dense paths or many boolean operations
- visually complex enough that SVG import fidelity is more important than editability
- a clean flat-color or linear-gradient raster layer that is easier to control as PNG and has no hidden source residue
- built from custom gradients, raster art, blur, or other effects that Icon Composer may not match
- intentionally pre-rendered because preserving the exact material look matters more than Icon Composer editability
- text whose font metrics, kerning, or exact appearance matter
- an SVG layer that looks correct in the preview SVG but shows Icon Composer-specific artifacts

Do not prefer PNG when the only advantage is a lower local reference diff. For Liquid Glass, a slightly looser semantic SVG can be the correct package because Icon Composer will generate the material response itself.

For user-owned brand/logo/text layers, ask before switching to PNG. The tradeoff is clear: PNG usually preserves the rendered look better, while SVG remains more editable.

When a PNG fallback starts from dark artwork on a white or light bitmap background, prepare a clean matte first. A fuzzy transparency operation often leaves white RGB in antialiased edge pixels; Icon Composer then shows dirty slices, halos, or ragged inner contours. Use `prepare-bitmap-layer` to turn luminance into alpha and force foreground RGB to the chosen ink color.

Imported SVG assets should fail loudly when they contain unsupported or risky constructs. Do not silently strip `<text>`, `<image>`, filters, masks, clip paths, `foreignObject`, scripts, external hrefs, or full-canvas app masks.

## Text Handling

Do not emit `<text>` in final SVG assets that are imported into Icon Composer. Use one of these routes:

- Convert text to outlines only when the shape remains accurate and editable enough.
- If outline conversion distorts the design or font fidelity matters, render the text from an intermediate/source SVG that uses `<text>` into a transparent PNG, then import the PNG layer into Icon Composer.
- Do not approximate real typography with hand-built rectangles or crude paths when a font-rendered PNG layer would preserve the design better.
- Record the font name and render command in `style-report.json` when a text layer is rasterized, so the source decision is auditable.

Keep local source evidence for text layers, but do not rely on Icon Composer to preserve SVG text layout.

## Known `icon.json` Fields From Local Evidence

The `.icon` file format is not fully documented as a stable public schema. Treat these fields as observed, not exhaustive:

```text
color-space-for-untagged-svg-colors
features
fill
groups[].layers[].image-name
groups[].layers[].position
groups[].layers[].hidden
groups[].layers[].blend-mode
groups[].layers[].blend-mode-specializations
groups[].layers[].fill
groups[].layers[].fill-specializations
groups[].layers[].glass
groups[].layers[].glass-specializations
groups[].layers[].opacity
groups[].layers[].opacity-specializations
groups[].blend-mode
groups[].blend-mode-specializations
groups[].hidden
groups[].blur-material
groups[].blur-material-specializations
groups[].lighting
groups[].refractivity
groups[].shadow
groups[].translucency
groups[].opacity
groups[].opacity-specializations
groups[].specular
groups[].specular-specializations
groups[].translucency-specializations
supported-platforms
```

Use the advanced fields only for an explicit material or appearance requirement. The author accepts the system-observed rules below and otherwise keeps the conservative defaults:

- Specializations accept one default entry as `{ "value": ... }`, plus at most one each of `"dark"` and `"tinted"`. Do not invent an `appearance` name.
- `blend-mode` and its specializations are one of `normal`, `multiply`, `screen`, `plus-lighter`, or `plus-darker`.
- `opacity`, `blur-material`, and `translucency.value` are in `[0, 1]`; `refractivity.strength` is in `[-1, 1]`; `refractivity.depth` is in `[0, 1]`.
- `specular` is `true`, `false`, `"inside"`, or `"outside"`. `shadow.kind` is `neutral` or `none`, with opacity in `[0, 1]`.
- `lighting` is `individual` or `combined`. `position` is `{ "scale": positive-number, "translation-in-points": [x, y] }`.
- `features` is a unique subset of `refractivity` and `specular-location`. `supported-platforms` uses `{ "circles": ["watchOS"], "squares": "shared" }`.

Locally observed Icon Composer 2.0 saved this useful group-level Liquid Glass preset for a blue continuous-loop icon:

```json
{
  "features": ["refractivity"],
  "groups": [
    {
      "blend-mode": "normal",
      "blur-material": 0.5,
      "lighting": "individual",
      "refractivity": {
        "enabled": true,
        "strength": 0.4,
        "depth": 0.4
      },
      "shadow": {
        "kind": "neutral",
        "opacity": 0.4
      },
      "translucency": {
        "enabled": true,
        "value": 0.5
      },
      "layers": [
        {
          "blend-mode": "normal",
          "fill": "automatic"
        }
      ]
    }
  ]
}
```

This preset should stay in `icon.json`, not in imported SVG geometry. It produces a stronger rendered gradient/refraction/shadow response in `ictool` exports while keeping the source foreground as one clean editable SVG.

When uncertain, prefer conservative `icon.json` output plus editable SVG assets and let the user fine-tune in Icon Composer.
