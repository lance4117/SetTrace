# single-hue-gradient-outlined-mascot-charmbyte

Use this when the app should feel playful, bold, and graphic through a white mascot or badge shape with a thick black backing outline on a restrained single-hue gradient field.

This is a style family, not a fixed purple cat-skull recipe. The stable grammar is the layer model: one single-color-family gradient, one black backing silhouette, one white inset mascot face/badge, and a few black overlay details.

Expected source-layer mapping:

- background -> `icon.json.fill` restrained single-hue gradient
- `black-backing` -> one SVG filled backing silhouette, not a stroke
- `white-face` -> one SVG filled inset mascot/badge face
- `eye-left` / `eye-right` / `detail-mark` -> simple black SVG overlay shapes

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: playful flat vector mascot icon on a restrained single-color-family {purple / orange / teal / blue / green / red} gradient field.
Background layer: restrained single-color-family {hue} gradient, {lighter hue name} in {upper-left / top / left} blending smoothly into {richer hue name} in {lower-right / bottom / right}; subtle, clean, app-icon-like, no neon, no two-color split, no radial glow.
Subject: one large white abstract {app-specific mascot badge / dog-mask badge / fox badge / bear head / ghost badge / creature badge / cat-skull badge}, centered and slightly tilted; simple readable silhouette with no tiny anatomy.
Topology: select the mascot family from the app semantics before drawing; do not reuse source-specific ears, skull cheeks, or zigzag cheek marks unless that personality is explicitly selected.
Layer model: black filled backing silhouette underneath, white inset mascot face shape above it, black facial/detail overlays above the white face.
Details: use one to three simple black overlays chosen from {vertical oval eye / rounded dot / soft capsule / simple visor / nose mark / cheek mark / badge mark / zigzag charm}; include paired eyes only when the selected mascot topology needs a face.
Palette/material: restrained {hue} gradient background, pure white face fill, deep black backing outline and black detail overlays.
Layering: the black outline is a filled backing shape, not a stroke; eyes and details are opaque black overlays, not transparent holes.
Quality: premium App Store icon, playful, bold, crisp, high contrast, clean SVG-friendly geometry.
No text, watermark, unselected animal traits, source-specific facial details, repeated cheek mark, neon gradient, rainbow, two-color split, radial glow, wallpaper texture, realistic anatomy, teeth row, fur, whiskers, shadow, bevel, glow, glossy material, sticker border, 3D render, or extra symbols.
```

## Variant Axes

- Background hue family: purple, orange, teal, blue, green, red.
- Gradient direction: upper-left to lower-right, top to bottom, left to right.
- Mascot family: app-specific mascot badge, dog-mask badge, fox badge, bear head, ghost badge, creature badge, cat-skull badge.
- Face topology: rounded badge, visor face, soft jaw curve, floppy ears, pointed ears, ghost lower edge, or no ears.
- Detail overlays: oval eyes, dot eyes, capsule eyes, zigzag charm, nose mark, cheek mark, badge mark.
- Source drift guard: do not reuse cat ears, skull cheeks, oval-eye spacing, or the zigzag cheek mark unless the selected app metaphor asks for that exact personality.
- Tilt: centered, slight left tilt, slight right tilt.

## Template Conversion Flow

Default route: semantic SVG with optional clean-mask retrace for the black backing shape and white inset.

- Keep the background as a single-hue gradient fill in the spec.
- Build the mascot from a black filled backing shape, a white inset face/body shape, and simple black overlay details. Do not use SVG strokes for the outline.
- If retracing, trace only stable silhouette components, then recolor them to pure black or white from the spec.
- Reject mascot texture, tiny facial details, gradient-filled outlines, transparent cutouts, and a PNG fallback unless the user accepts strict-fidelity raster for a dense mascot.

## Example Instantiation (Not A Default)

```text
Apple app icon for GhostKey, a playful private-login avatar app.
Seed: 927314.
Style: playful flat vector mascot icon on a restrained single-color-family orange gradient field.
Background layer: restrained single-color-family orange gradient, soft cream-orange in the upper-left blending smoothly into richer tangerine in the lower-right; subtle, clean, app-icon-like, no neon, no red-yellow split, no radial glow.
Subject: one large white abstract ghost-key badge, centered and slightly tilted; rounded ghost-like upper mass merging into a simple key-tab lower edge, no cat ears and no skull anatomy.
Layer model: black filled backing silhouette underneath, white inset badge shape above it, black facial/detail overlays above the white badge.
Details: one simple black soft visor overlay and one small black key-dot badge mark near the lower-right.
Palette/material: restrained orange gradient background, pure white badge fill, deep black backing outline and black detail overlays.
Layering: the black outline is a filled backing shape, not a stroke; eyes and details are opaque black overlays, not transparent holes.
Quality: premium App Store icon, playful, bold, crisp, high contrast, clean SVG-friendly geometry.
No text, watermark, neon gradient, rainbow, two-color split, radial glow, wallpaper texture, realistic anatomy, teeth row, bones, horror texture, fur, whiskers, shadow, bevel, glow, glossy material, sticker border, 3D render, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 583914,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "The black outline must be a filled backing shape behind the white face, never a stroke. All eyes, mouth marks, counters, gaps, and details must be rendered as separate opaque overlay layers; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "CharmByte",
      "category": "theme and avatar customization app",
      "job_to_be_done": "show a playful customizable companion badge with bold graphic personality",
      "tone": "playful, bold, clean, graphic"
    },
    "style": {
      "direction": "single-hue-gradient-outlined-mascot",
      "svg_convertibility": "high",
      "style_notes": "restrained single-hue gradient background, black filled backing silhouette, white inset mascot face, black overlay details"
    },
    "icon_intent": {
      "metaphor": "custom companion badge",
      "small_size_readability": "must remain clear at 64x64 as one white mascot badge with black backing and black facial overlays",
      "must_feel_like": ["playful", "bold", "clean", "graphic"],
      "must_not_feel_like": ["AI neon gradient", "horror skull", "sticker sheet", "3D toy", "detailed mascot"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "The black outline is a filled backing silhouette below the white face. Eyes and zigzag mark are black opaque overlays above the white face. Do not use strokes, masks, clipPaths, transparency, or boolean holes."
    },
    "variant_axes": {
      "background_hue_family": ["purple", "orange", "teal", "blue", "green", "red"],
      "gradient_direction": ["upper-left-to-lower-right", "top-to-bottom", "left-to-right"],
      "mascot_family": ["app-specific mascot badge", "dog-mask badge", "fox badge", "bear head", "ghost badge", "creature badge", "cat-skull badge"],
      "detail_overlay": ["oval eyes", "dot eyes", "capsule eyes", "zigzag charm", "nose mark", "cheek mark", "badge mark"]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.58, 0.76],
        "height_pct": [0.54, 0.74]
      },
      "safe_area": {
        "x": [120, 900],
        "y": [120, 900]
      },
      "alignment": "large centered mascot badge with slight tilt and generous app-icon safe area"
    },
    "background": {
      "type": "single-hue-gradient",
      "hue_family": "purple",
      "color": "#A66BE8",
      "gradient_stops": ["#D6A7F4", "#AA6AEA", "#7E43D0"],
      "gradient_policy": {
        "contrast_level": "low-to-medium",
        "hue_relationship": "single-color-family purple",
        "direction": "upper-left-to-lower-right",
        "must_preserve": [
          "single hue family",
          "light lavender-violet upper-left",
          "richer violet lower-right",
          "smooth simple app-icon gradient"
        ],
        "must_not_add": [
          "neon gradient",
          "magenta-pink hotspot",
          "blue split",
          "rainbow",
          "radial glow",
          "wallpaper texture"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          { "offset": 0, "color": "extended-srgb:0.839 0.655 0.957 1" },
          { "offset": 0.55, "color": "extended-srgb:0.667 0.416 0.918 1" },
          { "offset": 1, "color": "extended-srgb:0.494 0.263 0.816 1" }
        ]
      }
    },
    "layers": [
      {
        "id": "black-backing",
        "order": 1,
        "role": "thick black outline backing",
        "format_target": "svg",
        "shape_model": "single filled backing silhouette",
        "description": "large thick black filled cat-skull backing shape, centered and slightly tilted, creating a broad outline around the white inset face",
        "fill": "#050506",
        "bounds": {
          "x": [135, 885],
          "y": [135, 900]
        },
        "geometry_constraints": [
          "one filled path",
          "crisp boundary",
          "broad backing outline",
          "not a stroke",
          "no shadow",
          "no bevel",
          "no glow"
        ],
        "must_preserve": [
          "thick black outer silhouette",
          "cat-ear top points",
          "simple rounded lower edge",
          "slight tilt"
        ],
        "must_not_add": [
          "thin stroke outline",
          "separate outline stroke",
          "teeth row",
          "bones",
          "fur",
          "whiskers",
          "shadow"
        ]
      },
      {
        "id": "white-face",
        "order": 2,
        "role": "white inset mascot face",
        "format_target": "svg",
        "shape_model": "single filled inset face path",
        "description": "white inset cat-skull face shape above the black backing, leaving a broad visible black border around the perimeter",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [205, 830],
          "y": [190, 820]
        },
        "geometry_constraints": [
          "one filled path",
          "crisp boundary",
          "pure white fill",
          "no transparency",
          "no stroke",
          "no shadow"
        ],
        "must_preserve": [
          "white face fill",
          "broad black border remains visible",
          "simple cat-skull badge silhouette"
        ],
        "must_not_add": [
          "gray shading",
          "texture",
          "teeth row",
          "repeated bottom scallops",
          "fur"
        ]
      },
      {
        "id": "eye-left",
        "order": 3,
        "role": "left black eye overlay",
        "format_target": "svg",
        "shape_model": "vertical oval overlay",
        "description": "black vertical oval eye overlay on the left side of the white face",
        "fill": "#050506",
        "bounds": {
          "x": [295, 405],
          "y": [475, 640]
        },
        "geometry_constraints": ["opaque black overlay", "simple vertical oval", "no transparency", "no pupil"],
        "must_preserve": ["left black oval eye"],
        "must_not_add": ["pupil", "eyelash", "highlight", "outline"]
      },
      {
        "id": "eye-right",
        "order": 4,
        "role": "right black eye overlay",
        "format_target": "svg",
        "shape_model": "vertical oval overlay",
        "description": "black vertical oval eye overlay on the right side of the white face",
        "fill": "#050506",
        "bounds": {
          "x": [560, 690],
          "y": [465, 660]
        },
        "geometry_constraints": ["opaque black overlay", "simple vertical oval", "no transparency", "no pupil"],
        "must_preserve": ["right black oval eye"],
        "must_not_add": ["pupil", "eyelash", "highlight", "outline"]
      },
      {
        "id": "detail-mark",
        "order": 5,
        "role": "small black zigzag charm",
        "format_target": "svg",
        "shape_model": "filled angular zigzag overlay",
        "description": "small black jagged zigzag charm mark near the lower-left cheek",
        "fill": "#050506",
        "bounds": {
          "x": [290, 445],
          "y": [635, 735]
        },
        "geometry_constraints": [
          "opaque black overlay",
          "simple filled angular shape",
          "no stroke-only line",
          "no text"
        ],
        "must_preserve": ["small zigzag charm", "lower-left placement"],
        "must_not_add": ["letters", "teeth", "extra marks", "shadow"]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "5 foreground layers plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "ellipse", "linear gradient"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "clipPath",
        "mask",
        "stroke-only outline",
        "opacity",
        "shadow",
        "bevel",
        "glow",
        "blur",
        "boolean hole",
        "alpha cutout"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "must": [
        "restrained single-color-family gradient",
        "one black filled backing silhouette",
        "one white inset mascot face",
        "black overlay facial details",
        "flat vector-friendly appearance"
      ],
      "avoid": [
        "neon gradient",
        "rainbow",
        "two-color split",
        "radial glow",
        "wallpaper texture",
        "realistic anatomy",
        "teeth row",
        "fur",
        "whiskers",
        "shadow",
        "bevel",
        "glossy material",
        "3D render",
        "text",
        "watermark"
      ],
      "tested_prompt_note": "V2 testing showed that single-color-family lavender/violet gradients look cleaner than vibrant purple-to-magenta prompts, which produced obvious AI neon gradients."
    }
  }
}
```
