# single-hue-gradient-soft-white-symbol-emberlite

Use this when the app should feel warm, clean, playful, and instantly readable through a soft white rounded symbol on a restrained single-hue gradient field.

This is a style family, not a fixed pink flame recipe. The stable grammar is the layer model: one single-color-family gradient background, one centered soft white app-specific symbol, and optional internal details as background-colored opaque overlay shapes.

Expected source-layer mapping:

- background -> `icon.json.fill` restrained single-hue gradient
- `white-symbol` -> one SVG filled rounded symbol path, optionally using a very subtle linear gradient
- `detail-left` / `detail-right` / `counter-overlay` -> background-colored SVG overlay shapes, not holes

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: clean premium iOS icon with a restrained single-hue {rose / coral / orange / blue / teal / green / violet} gradient and one soft white symbolic mark.
Background layer: same-color-family {hue} gradient, deeper {hue} in {lower-left / bottom / left} blending smoothly into lighter {hue} in {upper-right / top / right}; saturated enough to feel lively but still clean, no second hue family, no neon, no rainbow.
Subject: one centered soft white rounded {flame-ghost / droplet / leaf / cloud / spark / pet-face / app-specific symbolic mark}; broad smooth silhouette, about 45-60% of the canvas, with generous safe area; iconic and simple, not a detailed illustration.
Details: optional {one / two / three} simple internal shapes filled with the surrounding background hue as opaque overlay layers; use bean, oval, capsule, notch, or counter shapes only when they support the app metaphor.
Palette/material: single-hue gradient field, soft white foreground, optional very subtle white-to-light-gray tonal depth on the white symbol.
Layering: any apparent eye, counter, notch, gap, or hole is a separate opaque background-colored overlay shape above the white symbol, never transparent carved geometry.
Quality: premium App Store icon, minimal, friendly, strong silhouette, clean negative space, SVG-friendly structure.
If the subject must be literal, use one concrete noun and explicitly forbid nearby drift, such as `not a cloud`, `not a face`, or `not a mascot`.
No text, watermark, black outline, sticker border, cast shadow, inner shadow, bevel, glow, rim light, glossy plastic highlight, 3D render, tiny facial details, texture, or extra unrelated symbols.
```

## Variant Axes

- Background hue family: rose, coral, orange, blue, teal, green, violet.
- Gradient direction: lower-left to upper-right, top to bottom, left to right.
- Symbol family: flame-ghost, droplet, leaf, cloud, spark, pet-face, rounded app-specific mark.
- Symbol posture: centered, slightly raised, slightly tilted, wider/squatter, taller/narrower.
- Internal overlay details: bean eyes, oval counters, capsule notches, small background-colored gap covers, or no internal details.
- Material level: flat white, or very subtle white-to-light-gray tonal gradient. Do not use shadow or bevel to create softness.
- Subject strictness: use hybrid nouns only when semantic drift is acceptable; otherwise name one concrete object and forbid the two closest wrong readings.

## Template Conversion Flow

Default route: direct semantic SVG for the white symbol, with clean-mask retrace only when the generated silhouette is better than hand-authored geometry.

- Author the background as a restrained single-hue gradient.
- Keep the foreground as one soft white filled symbol plus optional background-colored overlay features. Apparent holes are opaque overlays.
- If retracing, isolate only the white symbol, run multiple threshold candidates, and recolor the SVG to pure white or warm white from the spec. A single compound path may preserve intentional internal counters/holes when the selected reference is one continuous white silhouette and overlay splitting would create seams or visible drift; document those counters in `source_analysis` and still reject masks, clipPaths, alpha cutouts, or accidental threshold holes.
- Reject 3D plastic shading, gray shadow residue, true alpha holes, fuzzy bevels, and sampled pink/orange background inside the symbol.

## Example Instantiation (Not A Default)

```text
Apple app icon for EmberLite, a lightweight streak and motivation app.
Seed: 640382.
Style: minimal red-pink gradient icon with one soft white abstract mascot-symbol.
Background: smooth single-hue rose gradient, deeper hot red-pink from lower-left and left edge, lighter bubblegum pink toward upper-right; saturated but clean, no orange, no violet, no multicolor.
Main shape: centered soft white abstract flame badge with a rounded lower mass and three uneven rounded top notches/peaks; compact and slightly wide, occupying the middle of the canvas with generous safe area.
Internal shapes: two opaque pink bean-shaped overlays on top of the white badge, matching the background hue; each eye is a rounded vertical oval-bean with a small side bite, larger than a slot.
Material: near-flat vector icon, only a faint white-to-light-gray internal gradient on the white badge, no external shadow.
Layering: all apparent eye gaps are opaque top overlays, not transparent holes.
Quality: premium iOS app icon, clean, iconic, high readability at 64px.
No text, watermark, black stroke, outline, sticker edge, shadow, bevel, glow, specular highlight, plastic, texture, mouth, extra symbol, or realistic flame.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 640382,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent eyes, counters, notches, gaps, and negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "EmberLite",
      "category": "lightweight streak and motivation app",
      "job_to_be_done": "show a small warm daily spark that feels approachable and easy to keep alive",
      "tone": "warm, clean, friendly, focused"
    },
    "style": {
      "direction": "single-hue-gradient-soft-white-symbol",
      "svg_convertibility": "high",
      "style_notes": "restrained single-hue gradient background, one centered soft white rounded symbol, internal details as background-colored overlay layers"
    },
    "icon_intent": {
      "metaphor": "soft daily ember companion",
      "small_size_readability": "must remain clear at 64x64 as one white rounded symbol on a vivid single-hue gradient",
      "must_feel_like": ["warm", "minimal", "friendly", "premium"],
      "must_not_feel_like": ["fire emoji", "sticker", "3D toy", "plastic render", "generic flame logo"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "The bean-shaped internal details are opaque rose-pink overlay shapes above the white symbol. Do not create transparent holes, masks, clipPaths, alpha cutouts, or carved geometry."
    },
    "variant_axes": {
      "background_hue_family": ["rose", "coral", "orange", "blue", "teal", "green", "violet"],
      "gradient_direction": ["lower-left-to-upper-right", "top-to-bottom", "left-to-right"],
      "symbol_family": ["flame-ghost", "droplet", "leaf", "cloud", "spark", "pet-face", "app-specific rounded mark"],
      "internal_overlay": ["bean eyes", "oval counters", "capsule notches", "background-colored gap covers", "none"]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.45, 0.60],
        "height_pct": [0.40, 0.58]
      },
      "safe_area": {
        "x": [160, 864],
        "y": [150, 850]
      },
      "alignment": "centered soft white symbol with generous rounded-square safe area"
    },
    "background": {
      "type": "single-hue-gradient",
      "hue_family": "rose-pink",
      "color": "#FF2A83",
      "gradient_stops": ["#FF173C", "#FF2B84", "#FF76D1"],
      "gradient_policy": {
        "contrast_level": "medium",
        "hue_relationship": "single-color-family rose-pink",
        "direction": "lower-left-to-upper-right",
        "must_preserve": [
          "saturated red-pink lower-left",
          "lighter vivid pink upper-right",
          "smooth same-hue transition",
          "clean app-icon field"
        ],
        "must_not_add": [
          "orange cast",
          "violet cast",
          "blue split",
          "rainbow gradient",
          "neon glow",
          "radial hotspot",
          "wallpaper texture"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          { "offset": 0, "color": "extended-srgb:1.000 0.090 0.235 1" },
          { "offset": 0.55, "color": "extended-srgb:1.000 0.169 0.518 1" },
          { "offset": 1, "color": "extended-srgb:1.000 0.463 0.820 1" }
        ]
      }
    },
    "layers": [
      {
        "id": "white-symbol",
        "order": 1,
        "role": "main soft white symbolic mark",
        "format_target": "svg",
        "shape_model": "single filled rounded organic symbol path",
        "description": "centered soft white abstract flame badge with a rounded lower mass, three uneven rounded top notches/peaks, and compact wide proportions",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [220, 805],
          "y": [215, 735]
        },
        "geometry_constraints": [
          "one filled path",
          "broad smooth Bezier curves",
          "opaque white fill",
          "optional very subtle linear gradient only",
          "no stroke",
          "no shadow",
          "no bevel",
          "no glow"
        ],
        "must_preserve": [
          "soft white foreground mass",
          "rounded lower body",
          "three short rounded top peaks",
          "compact centered scale"
        ],
        "must_not_add": [
          "black outline",
          "sticker border",
          "tall candle-like spire",
          "realistic fire",
          "mouth",
          "limbs",
          "plastic highlight",
          "3D material"
        ]
      },
      {
        "id": "detail-left",
        "order": 2,
        "role": "left background-colored internal overlay",
        "format_target": "svg",
        "shape_model": "bean-shaped overlay",
        "description": "opaque rose-pink bean-shaped overlay placed on top of the white symbol, reading like a soft eye or counter without cutting into the base shape",
        "fill": "#FF2B84",
        "bounds": {
          "x": [405, 515],
          "y": [455, 645]
        },
        "geometry_constraints": [
          "opaque background-colored overlay",
          "separate top layer",
          "rounded bean shape",
          "no transparency",
          "no mask",
          "no clipPath",
          "no shadow"
        ],
        "must_preserve": [
          "left internal rose-pink overlay",
          "organic bean silhouette",
          "larger than a narrow slot"
        ],
        "must_not_add": [
          "black eye",
          "pupil",
          "thin slot",
          "transparent hole",
          "shadowed recess"
        ]
      },
      {
        "id": "detail-right",
        "order": 3,
        "role": "right background-colored internal overlay",
        "format_target": "svg",
        "shape_model": "bean-shaped overlay",
        "description": "opaque rose-pink bean-shaped overlay placed on top of the white symbol, paired with detail-left",
        "fill": "#FF2B84",
        "bounds": {
          "x": [585, 710],
          "y": [440, 630]
        },
        "geometry_constraints": [
          "opaque background-colored overlay",
          "separate top layer",
          "rounded bean shape",
          "no transparency",
          "no mask",
          "no clipPath",
          "no shadow"
        ],
        "must_preserve": [
          "right internal rose-pink overlay",
          "organic bean silhouette",
          "paired relationship with detail-left"
        ],
        "must_not_add": [
          "black eye",
          "pupil",
          "thin slot",
          "transparent hole",
          "shadowed recess"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "3 foreground layers plus background",
      "svg_first": true,
      "allowed_svg_primitives": [
        "filled path",
        "linear gradient",
        "ellipse",
        "compound path"
      ],
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
      "png_fallback_allowed_only_for": [
        "custom-gradient",
        "renderer-artifact",
        "strict-fidelity"
      ]
    },
    "image_generation_constraints": {
      "priority": "clear separable SVG-convertible shapes over rendered beauty",
      "avoid": [
        "black outline",
        "sticker border",
        "cast shadow",
        "inner shadow",
        "bevel",
        "glow",
        "rim light",
        "glossy plastic highlight",
        "3D render",
        "realistic flame",
        "narrow eye slots",
        "transparent holes",
        "texture",
        "extra symbols"
      ]
    }
  }
}
```
