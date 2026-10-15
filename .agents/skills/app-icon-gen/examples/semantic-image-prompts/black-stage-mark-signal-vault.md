# black-stage-mark-signal-vault

Use this for a premium/security/dev-tool icon where the result should be a flat black stage, one high-contrast geometric mark, and one small palette-harmonized vivid accent.

The accent color in this example is only a sample choice. Replace it when another vivid color fits the app identity or palette better.

Expected source-layer mapping:

- background -> `icon.json.fill`
- `primary-mark` -> one SVG filled path
- `diamond-cover` -> one background-colored SVG overlay diamond
- `accent-spark` -> one SVG diamond/polygon

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: flat near-black stage with one premium pure-white geometric mark and one small vivid accent.
Subject: one app-specific abstract mark based on {vault slab / focused workspace / tool glyph / data shard / signal block / finance tile}; centered, sharp, calm, high contrast, not a literal shield or radio-wave logo.
Composition: centered mark with optional small accent at {right / lower-right / upper-right}; keep the accent separate and simple.
Palette/material: solid near-black field, pure-white foreground, one clean vivid accent chosen to fit the app palette.
Layering: any apparent cutout, counter, gap, stripe, or inset should read as a separate opaque background-colored overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, shield cliché, tiny UI details, or extra symbols.
```

## Variant Axes

- Mark topology: vault slab, focused workspace, tool glyph, data shard, signal block, finance tile.
- Accent shape: small square, diamond, dot, short bar, or compact spark.
- Accent placement: right, lower-right, or upper-right; never centered enough to become a second subject.
- Palette: accent can be red, hot pink, cyan, green, blue, or another app-appropriate vivid color; keep it clean and saturated, not gray or muddy.

## Template Conversion Flow

Default route: semantic SVG or clean-mask `potrace` retrace. Treat the generated image as a stable black stage with three semantic components: background, pure-white mark, vivid accent.

- Build `source_analysis.components[]` for `primary-mark`, any background-colored overlay covers, and `accent-spark`; do not add extra components for antialiasing, bevels, or interior tonal shifts.
- If the mark geometry is not easy to author directly, produce several binary mask candidates for the primary mark in `tmp/work/`, trace the cleanest candidate, then set the SVG fill to pure white from the spec.
- Trace or author the accent as one simple filled SVG shape and recolor it to the chosen vivid accent; keep it clean and saturated.
- Reject palette-quantized tracing, multiple off-white fills, copied lighting, shadow, bevel, rim highlights, or gray/yellow contamination in the foreground.

## Example Instantiation (Not A Default)

```text
Apple app icon for Signal Vault, a privacy security utility.
Seed: 714293.
Style: flat near-black stage with a premium pure-white geometric mark and one small vivid accent.
Subject: an abstract protected-signal angular slab, centered, sharp, calm, high contrast; not a shield and not radio-wave rings.
Palette/material: black field, pure-white foreground, one clean palette-harmonized vivid accent.
Layering: any apparent cutout, counter, gap, stripe, or inset should read as a separate opaque background-colored overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, shield cliché, tiny UI details, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 714293,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent cutouts, counters, gaps, stripes, or negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "Signal Vault",
      "category": "privacy security utility",
      "job_to_be_done": "show that private signals are protected in a focused workspace",
      "tone": "calm, crisp, trustworthy, premium"
    },
    "style": {
      "direction": "black-stage-mark",
      "svg_convertibility": "high",
      "style_notes": "flat near-black stage, pure-white geometric mark, one small palette-harmonized vivid accent"
    },
    "icon_intent": {
      "metaphor": "protected signal",
      "small_size_readability": "must remain clear at 64x64",
      "must_feel_like": ["secure", "focused", "premium"],
      "must_not_feel_like": ["generic shield", "3D render", "game badge"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "Any apparent cutout, counter, notch, gap, or negative space is a separate opaque layer placed above the base shape. Do not request boolean holes, masks, clipPaths, alpha cutouts, or carved geometry."
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.48, 0.56],
        "height_pct": [0.52, 0.62]
      },
      "safe_area": {
        "x": [220, 804],
        "y": [200, 824]
      },
      "alignment": "centered"
    },
    "background": {
      "type": "solid",
      "color": "#08090D",
      "gradient_stops": [],
      "composer_fill_target": {
        "solid": "extended-srgb:0.031 0.035 0.051 1"
      }
    },
    "layers": [
      {
        "id": "primary-mark",
        "order": 1,
        "role": "foreground symbol",
        "format_target": "svg",
        "shape_model": "single filled angular mark",
        "description": "pure-white angular mark that will receive a separate background-colored diamond overlay above it",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [260, 764],
          "y": [230, 790]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp boundary",
          "no stroke",
          "no opacity",
          "no shadow",
          "no glow"
        ],
        "must_preserve": [
          "mirrored wing relationship",
          "sharp outer terminals"
        ],
        "must_not_add": [
          "true cutout",
          "mask",
          "clipPath",
          "generic shield outline",
          "rim highlight",
          "bevel",
          "extra signal waves"
        ]
      },
      {
        "id": "diamond-cover",
        "order": 2,
        "role": "background-colored overlay cover",
        "format_target": "svg",
        "shape_model": "four-point diamond overlay",
        "description": "background-colored diamond placed above the primary mark to create the apparent central cutout as an independent layer",
        "fill": "#08090D",
        "bounds": {
          "x": [448, 576],
          "y": [500, 628]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp boundary",
          "separate top layer",
          "no mask",
          "no clipPath",
          "no alpha cutout",
          "no shadow"
        ],
        "must_preserve": [
          "apparent central diamond created by overlay, not a hole"
        ],
        "must_not_add": [
          "boolean cutout",
          "transparent hole",
          "shadowed recess"
        ]
      },
      {
        "id": "accent-spark",
        "order": 3,
        "role": "small accent",
        "format_target": "svg",
        "shape_model": "four-point diamond",
        "description": "small vivid accent diamond below the center of the primary mark",
        "fill": "#FF2E88",
        "bounds": {
          "x": [474, 550],
          "y": [700, 776]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp boundary",
          "no shadow"
        ],
        "must_preserve": [
          "small supporting scale"
        ],
        "must_not_add": [
          "glow",
          "extra sparkles"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "2-3",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "compound path", "polygon"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "clipPath",
        "mask",
        "stroke",
        "opacity",
        "shadow",
        "glow",
        "bevel",
        "blur",
        "soft unclear boundary",
        "boolean hole",
        "alpha cutout"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "priority": "clear separable SVG-convertible shapes over rendered beauty",
      "avoid": [
        "photorealism",
        "drop shadow",
        "inner shadow",
        "soft glow",
        "3D object rendering",
        "busy texture",
        "tiny detail",
        "existing app icon or brand mark",
        "boolean cutout",
        "mask",
        "clipPath"
      ]
    }
  }
}
```
