# kinetic-pop-tempostride-ribbon

Use this for a running, pace, workout, event, or fast-action app where the result should feel energetic without becoming a generic arrow, bolt, or rainbow-gradient sports icon.

This example intentionally keeps the background vivid but coherent: one solid hue or same-hue gradient, low-to-medium contrast, and no multi-hue sports-rainbow jump.

Expected source-layer mapping:

- background -> `icon.json.fill` solid color or same-hue linear gradient
- `lower-sweep` -> one SVG rounded crescent/ribbon path
- `upper-stride` -> one SVG rounded leaning capsule/ribbon path
- `stride-gap-cover` -> one background-colored SVG overlay cover if the split needs to be explicit

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: energetic solid or same-hue gradient field with one bold pure-white rounded motion symbol.
Subject: one app-specific kinetic symbol based on {stride ribbon / sweep curve / flame wedge / play wave / track bend / event burst}; it should feel fast through silhouette and angle, not through blur or clutter.
Composition: diagonal energy from {lower-left to upper-right / upper-left to lower-right / centered forward sweep}; foreground size follows the metaphor and safe area.
Palette/material: solid color or same-hue gradient chosen for the app; keep the foreground as pure-white motion shapes and choose a background hue/depth that preserves strong contrast.
Layering: any apparent split, gap, or inner separation should read as a separate opaque overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, speed-line clutter, motion blur, or extra symbols.
```

## Variant Axes

- Kinetic symbol: stride ribbon, sweep curve, flame wedge, play wave, track bend, event burst.
- Background family: solid or same-hue gradient in orange, red, magenta, blue, teal, green, or another app-appropriate hue; avoid pale backgrounds that weaken the pure-white foreground.
- Motion direction: rising diagonal, falling diagonal, or centered forward sweep.
- Foreground construction: one filled shape by default; two shapes only when the split is meaningful.

## Template Conversion Flow

Default route: direct semantic SVG for the motion symbol. Use the generated image for composition and palette, not for copying rendered edge effects.

- Keep the background as a solid or low-contrast gradient fill in the spec.
- Author the main motion symbol as one clean shape family or a small number of deliberate colored segments; each segment must correspond to a real visual part.
- If retracing a generated silhouette, run multi-threshold mask candidates for the whole symbol or named segment, then recolor with the chosen palette rather than preserving sampled color patches.
- Reject shadows, plastic highlights, fuzzy speed lines, accidental tiny fragments, and conversions where color quantization invents extra layers.

## Example Instantiation (Not A Default)

```text
Apple app icon for TempoStride, a running interval coach.
Seed: 384916.
Style: energetic orange same-hue gradient with bold rounded pure-white motion ribbons.
Subject: two diagonal stride ribbons that feel athletic and fast without becoming arrows.
Palette/material: orange same-hue background; clean pure-white foreground shapes.
Layering: any apparent split, gap, or inner separation should read as a separate opaque overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, speed-line clutter, motion blur, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 384916,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent cutouts, counters, gaps, stripes, or negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "TempoStride",
      "category": "running interval trainer and pace coach",
      "job_to_be_done": "show controlled forward rhythm for running intervals",
      "tone": "energetic, clean, premium, athletic"
    },
    "style": {
      "direction": "kinetic-pop",
      "svg_convertibility": "medium",
      "style_notes": "single-hue orange gradient background, two-piece pure-white rounded stride ribbon, no generic speed icon"
    },
    "icon_intent": {
      "metaphor": "controlled running stride rhythm",
      "small_size_readability": "must remain clear at 64x64 through pure-white foreground contrast against the chosen background",
      "must_feel_like": ["fast", "controlled", "athletic", "premium"],
      "must_not_feel_like": ["generic arrow", "paper plane", "lightning bolt", "checkmark", "brand swoosh", "rainbow sports icon"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "Any apparent cutout, counter, notch, gap, or negative space is a separate opaque layer placed above the base shape. Do not request boolean holes, masks, clipPaths, alpha cutouts, or carved geometry."
    },
    "subject_topology": {
      "type": "two-piece split ribbon stride",
      "primary_parts": [
        "lower-sweep: broad rounded crescent ribbon, starts near lower-left safe area, rises into center, rounded terminal, no pointed arrow tip",
        "upper-stride: shorter thick rounded leaning segment, begins near center, leans toward upper-right, rounded terminal, no triangular head"
      ],
      "overlay_parts": [
        "stride-gap-cover: small background-colored opaque cover between the ribbons only if needed to clarify the split"
      ],
      "silhouette_rejects": [
        "arrowhead",
        "paper-plane triangle",
        "lightning bolt zigzag",
        "single giant swoosh",
        "thin speed line",
        "runner body",
        "letter T or S"
      ]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.58, 0.7],
        "height_pct": [0.55, 0.68]
      },
      "safe_area": {
        "x": [160, 864],
        "y": [150, 860]
      },
      "alignment": "centered diagonal rhythm, large but with corner breathing room"
    },
    "background": {
      "type": "same-hue-linear-gradient",
      "color": "#FF8A24",
      "gradient_stops": ["#FF6A00", "#FF8A24", "#FFA33A"],
      "gradient_policy": {
        "contrast_level": "low-to-medium",
        "hue_relationship": "same-hue orange ramp",
        "stop_count": [1, 3],
        "must": [
          "smooth single-hue transition or solid field",
          "warm sporty energy without rainbow effect",
          "background supports the pure-white stride mark instead of competing with it"
        ],
        "avoid": [
          "multi-hue gradient",
          "pale low-contrast background behind white foreground",
          "blue-green-yellow palette",
          "rainbow gradient",
          "deep blue to bright yellow",
          "neon multi-color sweep",
          "high-contrast corner clash",
          "hard hue jump"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          "extended-srgb:1.000 0.416 0.000 1",
          "extended-srgb:1.000 0.541 0.141 1",
          "extended-srgb:1.000 0.639 0.227 1"
        ]
      }
    },
    "layers": [
      {
        "id": "lower-sweep",
        "order": 1,
        "role": "lower stride ribbon",
        "format_target": "svg",
        "shape_model": "single filled rounded crescent ribbon",
        "description": "broad pure-white crescent ribbon rising from lower-left into center with rounded terminals and no pointed tip",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [190, 650],
          "y": [430, 820]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp boundary",
          "rounded terminals",
          "no stroke",
          "no opacity",
          "no shadow",
          "no glow",
          "no blur"
        ],
        "must_preserve": [
          "broad crescent mass",
          "lower-left to center motion",
          "rounded ends"
        ],
        "must_not_add": [
          "arrowhead",
          "thin tail",
          "runner leg details",
          "speed lines"
        ]
      },
      {
        "id": "upper-stride",
        "order": 2,
        "role": "upper stride ribbon",
        "format_target": "svg",
        "shape_model": "single filled leaning rounded capsule ribbon",
        "description": "shorter pure-white rounded leaning ribbon above the lower sweep, suggesting a forward foot strike without forming an arrow",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [455, 790],
          "y": [210, 565]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp boundary",
          "rounded terminals",
          "no stroke",
          "no opacity",
          "no shadow",
          "no glow",
          "no blur"
        ],
        "must_preserve": [
          "forward lean",
          "separate upper mass",
          "rounded ends"
        ],
        "must_not_add": [
          "triangle point",
          "arrowhead",
          "bolt zigzag",
          "letterform"
        ]
      },
      {
        "id": "stride-gap-cover",
        "order": 3,
        "role": "background-colored overlay cover",
        "format_target": "svg",
        "shape_model": "small rounded wedge overlay",
        "description": "small opaque background-colored cover placed above the ribbons to clarify the split gap as an independent layer, not a real hole",
        "fill": "#FF8A24",
        "bounds": {
          "x": [462, 585],
          "y": [455, 555]
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
          "reads as an overlay cover",
          "does not become transparent"
        ],
        "must_not_add": [
          "inner shadow",
          "bevel",
          "soft edge",
          "transparent gap"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "2-3 foreground layers plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "linear gradient"],
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
        "blur",
        "soft unclear boundary",
        "boolean hole",
        "alpha cutout"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "must": [
        "flat vector-friendly app icon",
        "two broad rounded ribbon shapes",
        "solid or same-hue gradient background",
        "no generic arrow",
        "clear layer separation"
      ],
      "avoid": [
        "arrowhead",
        "paper plane",
        "lightning bolt",
        "checkmark",
        "Nike-like swoosh",
        "rainbow gradient",
        "blue-green-yellow palette",
        "deep blue to bright yellow",
        "motion blur",
        "speed lines",
        "3D rendering",
        "cast shadow",
        "glow",
        "transparent cutout",
        "mask",
        "clipPath",
        "tiny detail",
        "text"
      ]
    }
  }
}
```
