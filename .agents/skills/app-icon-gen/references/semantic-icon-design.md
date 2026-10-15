# Semantic Icon Design

Use this before image generation or direct authoring when no owned source artwork exists, or when a loose style reference must become an Icon Composer-ready package. A semantic icon design is the upstream design contract. It is not the final `author-icon` spec, and it is not a free-form image prompt.

The same JSON design must support both routes:

- `concept-to-package`: generate reference images from the JSON, then rebuild the selected concept as separated SVG or clean PNG layers.
- `direct-authored-package`: skip bitmap generation and translate the JSON directly into an `author-icon` spec.

## Core Rule

Design the icon as layers first. A good generated reference is one that can be rebuilt as 2-5 semantic source layers with clear boundaries, not the prettiest rendered bitmap.

Use image generation to visualize the design, not to invent unstructured shadows, dirty material, text, or dense details that the package cannot preserve cleanly. Controlled glass plates, broad gradients, translucency, and low-frequency highlights are valid when the JSON names the layer relationship and the conversion route.

## Required Shape

Use this top-level shape for no-reference work:

Choose a positive integer semantic/source canvas appropriate to the requested generic deliverable. For the optional Apple Icon Composer adapter, use a 1024px source canvas; `ictool` produces the final 1088px circular watchOS render rather than requiring an 1088px source canvas.

```json
{
  "version": "semantic-icon-design/v0.1",
  "route": "concept-to-package",
  "app_context": {
    "app_name": "Example",
    "category": "privacy utility",
    "job_to_be_done": "show that private signals are protected",
    "tone": "calm, crisp, trustworthy"
  },
  "style": {
    "direction": "black-stage-mark",
    "svg_convertibility": "high",
    "style_notes": "black stage, white geometric mark, one small palette-harmonized vivid accent"
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
      "width_pct": [0.40, 0.56],
      "height_pct": [0.42, 0.62]
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
    "gradient_policy": {
      "applies": false,
      "reason": "solid background"
    },
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
      "description": "off-white angular mark that will receive a separate background-colored diamond overlay above it",
      "fill": "#F8F7F2",
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
        "bevel"
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
      "description": "small vivid accent diamond below the center",
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
    "target_layer_count": "2-5",
    "svg_first": true,
    "allowed_svg_primitives": [
      "filled path",
      "compound path",
      "rect",
      "circle",
      "ellipse",
      "polygon"
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
      "text-rendering",
      "embedded-raster",
      "dense-brand-geometry",
      "custom-gradient",
      "renderer-artifact",
      "strict-fidelity"
    ]
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
      "existing app icon or brand mark"
    ]
  }
}
```

## Field Rules

- `app_context` must be specific to the current app. Do not leave app name, category, job-to-be-done, or tone as generic placeholders.
- `style.direction` must come from `style-directions.md` unless the user gives an explicit custom direction.
- `style.svg_convertibility` records expected packaging risk: `high`, `medium`, or `low`.
- `style.style_notes`, `icon_intent.metaphor`, palette choices, and `layers[].description` must reflect the app's actual function and tone. Do not use generic marks such as a bolt, shield, spark, graph, or mascot unless the app context makes that metaphor specific.
- `layering_policy.negative_space_strategy` should be `overlay-fill-layer` by default. Any apparent cutout, counter, notch, gap, stripe, or negative-space detail must be a separate opaque layer above the base layer, usually filled with the background or an intentional accent color.
- `canvas.composition_anchor` should be explicit when composition matters. Use `center`, `lower-left`, `lower-right`, or a named custom anchor.
- `canvas.subject_scale` is optional but recommended for generated concepts. Use `width_pct` and `height_pct` ranges when the subject must stay compact, intentionally oversized, or preserve large negative space.
- `canvas.safe_area`, `canvas.alignment`, and `layers[].bounds` must match the chosen anchor; do not rely on prose alone for subject placement.
- `background.type` should be `solid`, `linear-gradient`, or `automatic-gradient` by default.
- `background.gradient_policy` is required when `background.type` is `linear-gradient` or `automatic-gradient`. Prefer `low-to-medium` contrast, `analogous` or `monochrome` hue relationships, and 2-3 smooth stops. Avoid rainbow gradients, triadic palettes, deep-blue-to-bright-yellow jumps, neon multi-color sweeps, and corner-to-corner color clashes unless the user explicitly asks for that identity.
- `background.composer_fill_target` should be directly translatable to `spec.fill`.
- `layers` must list real semantic parts in bottom-to-top order.
- `layers[].format_target` should be `svg` unless a concrete PNG fallback reason is already known.
- `layers[].shape_model` must name the geometry model: `single filled path`, `compound path`, `mirrored shapes`, `overlapping plates`, `simple mascot silhouette`, or another concrete model.
- `layers[].description` should describe the visible shape, not the mood. If it describes a cutout-like detail, say `overlay layer`, `background-colored cover`, or `accent cover`; do not say the base layer is hollow, carved, punched out, masked, or clipped.
- `layers[].fill` should be chosen for palette harmony, app semantics, and contrast. Example accent colors are not defaults; write the actual chosen color into the JSON.
- `layers[].geometry_constraints` must include edge and material constraints when the layer is intended for SVG. For overlay cutout layers, include `fully opaque fill`, `crisp boundary`, `separate top layer`, `no mask`, `no clipPath`, and `no alpha cutout`.
- `image_generation_constraints.avoid` should repeat style-specific failure modes such as `shadowed cutout`, `large subject`, `three-node arch`, or `baked material`, not only generic `shadow` / `glow`.
- `image_generation_constraints.avoid` should repeat gradient-specific failure modes when a gradient is used: `rainbow gradient`, `high-contrast hue jump`, `deep blue to bright yellow`, `neon multi-color sweep`, or `background competes with foreground`.

## Image Generation Prompt

When generating a first-pass reference image, derive a short creative prompt from the design instead of sending the full JSON. The JSON is the conversion contract; the image prompt is the visual brief.

```text
App icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: {style.direction expressed as visual language}.
Subject: {app-specific metaphor and composition}.
Palette/material: {background, foreground colors, and any controlled glass, gradient, or translucency}.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, tiny UI details, or extra unrelated symbols.
```

Set `generation_seed` to a fresh random integer for each generated candidate or retry. It is a prompt-level variation and tracking field; do not claim it guarantees deterministic regeneration unless the image API explicitly supports that.

Use targeted repair prompts only when needed. If the generator returns shadows, soft boundaries, opaque glass, text, or dense detail, reject that concept or repair the single failure mode. Do not ask the conversion route to solve a bad reference image.

## Direct Authoring Mapping

When no image generation is used:

- `app_context`, `style`, and `icon_intent` become the basis for `brief`, `semantic_review`, and `source_analysis`.
- `background.composer_fill_target` becomes `spec.fill`.
- Each item in `layers` becomes one semantic spec layer unless the layer is intentionally preview-only.
- `layers[].id` should map to `source_analysis.components[].id`.
- `layers[].format_target` should map to the layer `composer.format`.
- `layers[].must_preserve` and `must_not_add` should become source-analysis constraints or acceptance checks.

## Reject Conditions

Reject or simplify the design before packaging if any of these are required for the icon to work:

- a foreground mark depends on unstructured blur, glow, shadow, bevel, or soft alpha that cannot be assigned to a named layer or clean PNG fallback
- a foreground mark requires true boolean cutouts, masks, clipPaths, alpha cutouts, or compound holes instead of overlay layers
- a simple background needs more than a broad fill or two-stop gradient
- a gradient needs high hue contrast, rainbow transitions, noisy color bands, or a deep-blue-to-bright-yellow jump to look interesting
- the foreground has many small independent objects
- the subject cannot be described as 2-5 semantic layers
- a mascot needs detailed facial features, fur, feathers, texture, or painterly edges
- a lettermark must match a real font or brand mark without an owned source vector
- the only faithful route is one full rendered PNG snapshot

## Completion Check

Before generating or authoring, confirm:

- one primary style direction is selected
- the background maps to Icon Composer fill or is explicitly a complex background layer
- the design has 2-5 real semantic layers
- every foreground target has crisp boundaries, named material intent, and either clean SVG geometry or a documented clean PNG fallback route
- PNG fallback is limited to a named allowed category with concrete evidence
- the design would still read at 64x64
