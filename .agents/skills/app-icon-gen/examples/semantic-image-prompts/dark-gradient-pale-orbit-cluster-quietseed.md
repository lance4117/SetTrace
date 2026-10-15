# dark-gradient-pale-orbit-cluster-quietseed

Use this when the app should feel calm, premium, organic, or cyclical through a single-color field and a sparse orbit of high-contrast capsule marks.

This is a style family, not a fixed flower recipe. The stable grammar is the layer model: one solid color or same-hue monochrome gradient background, 5-7 independent pure-white or pure-black organic capsule layers chosen by contrast, and an optional center gap as a background-colored opaque overlay layer.

Expected source-layer mapping:

- background -> `icon.json.fill` solid color or same-hue monochrome gradient
- `capsule-*` -> independent SVG filled oval/seed/capsule paths in pure white or pure black, chosen for contrast
- `center-gap-overlay` -> background-colored SVG overlay shape, not a transparent hole

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: single-color organic field with a high-contrast separated orbit cluster.
Background: solid {deep moss / pine / charcoal / umber / plum} or a smooth same-hue monochrome gradient toward {upper-right / top / right}; no cross-hue blend, no texture.
Subject: {5 / 6 / 7} large pure-{white / black} {seed / breath / leaf / moonseed / focus-interval / app-specific capsule} shapes arranged around a small center gap; choose pure white on dark backgrounds and pure black on light backgrounds. Each piece is an independent opaque rounded capsule layer with varied length, scale, and angle.
Composition: centered sparse orbit cluster, about 55-75% of the canvas, with generous corner safe area; organic asymmetry is preferred over a perfect radial diagram.
Palette/material: single-color background family, pure black or pure white foreground pieces only; no ivory, cream, mint, or tinted foreground.
Layering: any center gap, counter, pause gap, or separation must read as a background-colored opaque overlay layer or as visible space between independent opaque layers, never transparent carved geometry.
Quality: premium App Store icon, calm, minimal, strong small-size silhouette, SVG-friendly layer structure.
If the subject may drift, explicitly forbid nearby readings such as `not a daisy`, `not a face`, `not a clock`, or `not a complete flower illustration`.
No text, watermark, stem, flower center dot, leaf veins, face, glow, shadow, bevel, blur, glass, plastic shine, texture, or extra unrelated symbols.
```

## Variant Axes

- Background hue family: solid deep moss, monochrome pine, monochrome charcoal, monochrome umber, or monochrome plum.
- Gradient direction: upper-right slightly lighter field, top slightly lighter field, right-edge slightly lighter field, or subtle vertical dark-to-light same-hue ramp.
- Capsule count: 5, 6, or 7 independent pieces.
- Capsule semantics: breath markers, seed cycle, sleep rhythm markers, focus intervals, care cycle, moonseed orbit, or app-specific rounded markers.
- Cluster geometry: source-like asymmetric orbit, looser cycle, incomplete orbit, compact wreath, or slightly off-center swirl.
- Foreground palette: pure white `#FFFFFF` on dark backgrounds or pure black `#000000` on light backgrounds. Do not use cream, ivory, mint, or tinted off-white.
- Center treatment: small dark overlay ellipse/bean, visible dark field between separated pieces, or no explicit center overlay when the pieces do not imply a hole.

## Template Conversion Flow

Default route: direct semantic SVG. The generated image should only determine capsule count, placement, and broad rhythm; do not trace gradient noise.

- Author the background as a solid or low-contrast gradient fill in the spec.
- Author each capsule/marker as one clean SVG layer or one repeated path family with explicit positions; keep the center gap as visible background between layers.
- Choose black or white/pale marker fill from contrast against the background, not from sampled rendered pixels.
- Reject palette quantization, tiny marker fragments, glow halos, flower-petal drift, clock-tick layouts, and any attempt to trace the background gradient into foreground patches.

## Example Instantiation (Not A Default)

```text
Apple app icon for CoreBreath, a guided breathing timer.
Seed: 386912.
Style: premium single-hue dark organic gradient with a sparse pure-white breath-orbit mark.
Background: black-pine monochrome field, slightly lighter in the upper-right, restrained and quiet, no noisy material or cross-hue shift.
Subject: six pure-white breath capsules arranged as an incomplete orbit around a small off-center dark gap; capsules are broad, rounded, separated, and app-specific to breath pacing, not a literal flower.
Layering: any gap or counter is an opaque dark overlay shape matching the background, never transparent carved geometry.
Quality: clean iOS icon, readable at 64px, simple SVG-style filled paths with crisp pure black/white contrast.
No text, watermark, stem, center pollen, realistic flower, veins, dirt texture, cast shadow, rim glow, bevel, or extra leaves.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 386912,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent center gaps, counters, separations, or negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "QuietSeed",
      "category": "gentle plant-care reminder app",
      "job_to_be_done": "show a calm care cycle that returns daily without feeling busy or clinical",
      "tone": "quiet, organic, premium, minimal"
    },
    "style": {
      "direction": "dark-gradient-pale-orbit-cluster",
      "svg_convertibility": "high",
      "style_notes": "solid or same-hue monochrome background, sparse orbit of pure-white or pure-black independent capsule layers chosen by contrast, center gap as an opaque background-colored overlay when needed"
    },
    "icon_intent": {
      "metaphor": "quiet recurring care cycle",
      "small_size_readability": "must remain clear at 64x64 as pure-white separated capsules on a dark single-color field",
      "must_feel_like": ["calm", "organic", "premium", "cyclical"],
      "must_not_feel_like": ["literal daisy", "botanical illustration", "clock UI", "face", "glowing glass render"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "The center gap is a dark background-colored opaque overlay layer above or between the capsule layers. Do not create a transparent hole, mask, clipPath, alpha cutout, or shadowed recess."
    },
    "variant_axes": {
      "background_hue_family": ["solid deep moss", "monochrome pine", "monochrome charcoal", "monochrome umber", "monochrome plum"],
      "gradient_direction": ["lighter-upper-right", "lighter-top", "lighter-right-edge", "vertical-dark-to-light-same-hue"],
      "capsule_count": [5, 6, 7],
      "capsule_semantics": ["seed cycle", "breath markers", "sleep rhythm markers", "focus intervals", "care cycle", "app-specific rounded markers"],
      "center_treatment": ["opaque dark overlay", "visible dark field between separate layers", "no explicit center layer"]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.55, 0.75],
        "height_pct": [0.55, 0.76]
      },
      "safe_area": {
        "x": [120, 900],
        "y": [100, 900]
      },
      "alignment": "centered asymmetric orbit of independent pure-white or pure-black capsules with a small background-colored center gap and generous rounded-square safe area"
    },
    "background": {
      "type": "same-hue-monochrome-gradient",
      "hue_family": "deep-pine monochrome",
      "color": "#101410",
      "gradient_stops": ["#07100E", "#0C1713", "#13221C"],
      "gradient_policy": {
        "contrast_level": "low-to-medium",
        "hue_relationship": "single dark pine color family",
        "direction": "lower-left-to-upper-right",
        "must_preserve": [
          "near-black pine lower-left and left edge",
          "slightly lighter pine center and upper-right",
          "same-hue monochrome ramp",
          "smooth premium app-icon field"
        ],
        "must_not_add": [
          "bright rainbow gradient",
          "cross-hue blend",
          "brown or copper corner shift",
          "blue split",
          "neon glow",
          "radial spotlight",
          "noise texture",
          "dirty vignette",
          "baked rim shadow as a foreground layer"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          { "offset": 0, "color": "extended-srgb:0.027 0.063 0.055 1" },
          { "offset": 0.52, "color": "extended-srgb:0.047 0.090 0.075 1" },
          { "offset": 1, "color": "extended-srgb:0.075 0.133 0.110 1" }
        ]
      }
    },
    "shared_capsule_constraints": [
      "fully opaque filled path",
      "rounded organic capsule or seed shape",
      "crisp boundary",
      "pure white on dark backgrounds or pure black on light backgrounds",
      "no tinted cream, ivory, mint, or off-white foreground",
      "no stroke",
      "no shadow",
      "no blur",
      "no bevel",
      "no glow",
      "no texture"
    ],
    "layers": [
      {
        "id": "capsule-top",
        "order": 1,
        "role": "top care-cycle marker",
        "format_target": "svg",
        "shape_model": "elongated rounded capsule path",
        "description": "small vertical pure-white capsule above the center gap",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [430, 520],
          "y": [205, 355]
        },
        "geometry_constraints": ["opaque pure-white fill", "tall rounded seed shape", "no stem", "no vein", "no shadow"],
        "must_preserve": ["small top marker", "vertical orientation", "separation from other capsules"],
        "must_not_add": ["flower center", "leaf vein", "outline", "glow"]
      },
      {
        "id": "capsule-upper-right",
        "order": 2,
        "role": "largest upper-right growth marker",
        "format_target": "svg",
        "shape_model": "elongated rounded capsule path",
        "description": "large pure-white capsule angled upward to the right",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [560, 790],
          "y": [240, 390]
        },
        "geometry_constraints": ["opaque pure-white fill", "broad rounded seed shape", "no stroke", "no shadow", "no texture"],
        "must_preserve": ["largest upper-right marker", "diagonal angle", "clean rounded ends"],
        "must_not_add": ["leaf vein", "flower petal outline", "specular highlight", "bevel"]
      },
      {
        "id": "capsule-lower-right",
        "order": 3,
        "role": "large lower-right care marker",
        "format_target": "svg",
        "shape_model": "elongated rounded capsule path",
        "description": "large pure-white capsule angled down to the right, separated from the center",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [565, 805],
          "y": [505, 725]
        },
        "geometry_constraints": ["opaque pure-white fill", "broad capsule", "no stroke", "no shadow", "no blur"],
        "must_preserve": ["large lower-right marker", "pure-white contrast", "separated orbit spacing"],
        "must_not_add": ["extra leaf", "flower stem", "glow", "texture"]
      },
      {
        "id": "capsule-bottom",
        "order": 4,
        "role": "bottom return marker",
        "format_target": "svg",
        "shape_model": "elongated rounded capsule path",
        "description": "medium vertical pure-white capsule below the center gap",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [410, 515],
          "y": [600, 820]
        },
        "geometry_constraints": ["opaque pure-white fill", "vertical rounded seed", "no stroke", "no shadow", "no blur"],
        "must_preserve": ["bottom marker", "pure-white contrast", "clear gap from center"],
        "must_not_add": ["clock hand", "stem", "shadow", "bevel"]
      },
      {
        "id": "capsule-lower-left",
        "order": 5,
        "role": "small lower-left care marker",
        "format_target": "svg",
        "shape_model": "rounded seed capsule path",
        "description": "small pure-white capsule at lower-left, angled upward",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [235, 390],
          "y": [485, 610]
        },
        "geometry_constraints": ["opaque pure-white fill", "short rounded capsule", "no outline", "no shadow", "no texture"],
        "must_preserve": ["small lower-left marker", "pure-white contrast", "visible separation"],
        "must_not_add": ["leaf vein", "center pollen", "drop shadow", "rim light"]
      },
      {
        "id": "capsule-upper-left",
        "order": 6,
        "role": "small upper-left care marker",
        "format_target": "svg",
        "shape_model": "rounded seed capsule path",
        "description": "small pure-white capsule at upper-left, angled down toward the center",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [290, 410],
          "y": [335, 440]
        },
        "geometry_constraints": ["opaque pure-white fill", "short rounded capsule", "no outline", "no shadow", "no texture"],
        "must_preserve": ["small upper-left marker", "diagonal angle", "source-like asymmetry"],
        "must_not_add": ["extra dot", "flower center", "vein", "glow"]
      },
      {
        "id": "center-gap-overlay",
        "order": 7,
        "role": "background-colored center gap control",
        "format_target": "svg",
        "shape_model": "small soft oval or bean overlay",
        "description": "small dark background-colored opaque overlay that preserves the central gap between the pure-white capsules",
        "fill": "#0C1713",
        "bounds": {
          "x": [455, 560],
          "y": [455, 560]
        },
        "geometry_constraints": [
          "opaque background-colored overlay",
          "separate top layer when needed",
          "no transparency",
          "no mask",
          "no clipPath",
          "no shadowed recess"
        ],
        "must_preserve": ["small dark center gap", "non-transparent overlay behavior"],
        "must_not_add": ["center dot", "pollen", "button", "transparent hole", "inner shadow"]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "6 pure black/white capsule foreground layers plus optional center overlay and background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "ellipse", "linear gradient"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "mask",
        "clipPath",
        "drop shadow",
        "blur",
        "noise texture",
        "true transparent holes",
        "baked rounded-square rim highlight"
      ],
      "png_fallback_policy": "Use PNG fallback only for strict user-approved geometry fidelity; do not use PNG for foreground color because capsule layers must remain pure black or pure white."
    },
    "redraw_strategy": {
      "background": "author as icon fill with a solid color or smooth same-hue monochrome gradient",
      "foreground": "draw each pure-white or pure-black capsule as an independent filled path or ellipse-like path with source-like asymmetric bounds",
      "gap": "draw the center gap as an opaque background-colored overlay only when exact spacing cannot be achieved by separated capsule positions"
    }
  }
}
```
