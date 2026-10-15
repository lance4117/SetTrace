# silver-field-black-mask-catmask

Use this when the app should feel premium, quiet, guarded, companion-like, or identity-led through a large black abstract mask on a silver-white field.

This style is not a generic mascot template. The reusable prompt must choose a mask topology from the app semantics first. The cat-mask topology is only the tested example instantiation; do not make cat ears, a V-shaped top valley, or paired eyes the default for unrelated apps.

Expected source-layer mapping:

- background -> `icon.json.fill` low-contrast white-to-silver gradient with subtle bottom darkening
- `black-mask` -> one large near-black SVG filled path
- `feature-1` / `feature-2` -> optional white SVG overlay shapes such as a visor, half-oval eyes, crescent, or badge slit, not holes

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: premium silver-white rounded app icon field with subtle lower charcoal translucent gradient.
Subject: one large flat near-black abstract {app-specific mask / guardian visor / privacy mask / companion badge / sleep-mask mark / rounded identity mask / soft animal-like badge} silhouette, centered, occupying about half the canvas.
Topology: choose one app-specific contour from {arched visor top / domed badge / shallow notch / flat sleep-mask top / shield-like bottom / soft animal-like peaks}; borrow animal peaks or a source-style central notch only when the app semantics explicitly select that personality.
Details: use {one white visor overlay / two white half-oval eye overlays / one small crescent overlay / one quiet badge slit} placed inside the black silhouette; all features are opaque white shapes on top, not holes.
Palette/material: smooth white-to-silver monochrome background, subtle darker gradient at the bottom edge, flat near-black foreground, pure white overlay features.
Layering: any apparent eyes, counters, gaps, or cutouts should read as separate opaque overlay shapes, not transparent carved holes.
Quality: premium App Store icon, minimal, crisp, strong silhouette, SVG-friendly shapes, large quiet background.
No text, watermark, unselected animal traits, repeated source topology, whiskers, mouth, fur, nose, outline, shadow, bevel, sticker border, plastic shine, 3D render, or extra symbols.
```

## Variant Axes

- Mask metaphor: app-specific mask, guardian visor, privacy mask, companion badge, sleep-mask mark, rounded identity mask, soft animal-like badge.
- Top contour: arched visor top, domed badge, shallow notch, flat sleep-mask top, shield-like bottom, or soft animal-like peaks.
- Feature overlays: single visor, two half-oval eyes, small crescent, quiet badge slit, or no internal feature if the silhouette is strong enough.
- Animal drift guard: do not use cat ears, V-shaped top valley, whiskers, nose, or cat-specific face cues unless the app semantics select a cat-like companion.
- Background: white-to-silver monochrome field with subtle bottom charcoal darkening; do not use colored backgrounds for this direction.
- Foreground scale: large identity mass, usually about 48-62% canvas width and 42-58% canvas height.

## Template Conversion Flow

Default route: semantic SVG or clean-mask retrace for one large black mask plus separate white overlay features.

- Keep the silver field as a simple background fill/gradient and do not trace its edge darkening.
- Rebuild the mask as one pure-black filled component. White eyes/features are separate opaque white overlay layers, not transparent holes.
- If retracing the mask, run multiple binary mask candidates and accept only a contour that stays smooth, bold, and readable without interior residue.
- Reject gray fills, semi-transparent holes, sampled background inside features, cat drift for non-cat apps, and any conversion that embeds the whole rendered icon as one image.

## Example Instantiation (Not A Default)

```text
Apple app icon for FocusVeil, a privacy screen and deep-work blocker.
Seed: 829174.
Style: premium silver-white rounded app icon field with subtle lower charcoal translucent gradient.
Subject: one large flat near-black abstract guardian-visor mask, centered, occupying about half the canvas; arched top, broad rounded lower edge, no animal ears.
Details: one clean white horizontal visor-slit overlay in the upper-middle and one tiny white privacy-dot overlay offset lower-right; both are opaque white shapes on top, not holes.
Palette/material: smooth white-to-silver monochrome background, subtle darker gradient at the bottom edge, flat near-black foreground, pure white overlay features.
Layering: any apparent eyes, counters, gaps, or cutouts should read as separate opaque overlay shapes, not transparent carved holes.
Quality: premium App Store icon, minimal, crisp, strong silhouette, SVG-friendly shapes, large quiet background.
No text, watermark, animal face, whiskers, mouth, fur, nose, outline, shadow, bevel, sticker border, plastic shine, 3D render, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 194728,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent eyes, counters, gaps, cutouts, and negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "MaskNest",
      "category": "private focus companion",
      "job_to_be_done": "show a quiet guarded companion that protects focus without looking like a security badge",
      "tone": "premium, calm, minimal, guarded"
    },
    "style": {
      "direction": "silver-field-black-mask",
      "svg_convertibility": "high",
      "style_notes": "silver-white monochrome field with subtle lower charcoal gradient, one large flat black abstract mask, two white overlay eyes"
    },
    "icon_intent": {
      "metaphor": "quiet companion mask",
      "small_size_readability": "must remain clear at 64x64 as one black mask with two white eye overlays",
      "must_feel_like": ["premium", "quiet", "guarded", "minimal"],
      "must_not_feel_like": ["cartoon cat", "emoji", "sticker", "security shield", "3D mascot"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "The eyes are white opaque overlay shapes above the black mask. Do not create transparent holes, masks, clipPaths, alpha cutouts, or carved geometry."
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.48, 0.62],
        "height_pct": [0.42, 0.58]
      },
      "safe_area": {
        "x": [150, 874],
        "y": [150, 860]
      },
      "alignment": "large centered black mask with quiet silver-white space around it"
    },
    "background": {
      "type": "low-contrast-gradient",
      "color": "#EEF0F2",
      "gradient_stops": ["#FFFFFF", "#EEF0F2", "#C7C9CC", "#9FA2A6"],
      "gradient_policy": {
        "contrast_level": "low-to-medium",
        "hue_relationship": "monochrome-white-silver",
        "must_preserve": [
          "bright upper field",
          "subtle silver mid field",
          "charcoal-tinted bottom darkening",
          "no colored cast"
        ],
        "must_not_add": [
          "blue tint",
          "warm beige field",
          "noise",
          "paper texture",
          "rim light",
          "contact shadow"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          { "offset": 0, "color": "extended-srgb:1.000 1.000 1.000 1" },
          { "offset": 0.55, "color": "extended-srgb:0.933 0.941 0.949 1" },
          { "offset": 1, "color": "extended-srgb:0.624 0.635 0.651 1" }
        ]
      }
    },
    "layers": [
      {
        "id": "black-mask",
        "order": 1,
        "role": "main abstract companion mask",
        "format_target": "svg",
        "shape_model": "single filled rounded mask path",
        "description": "large flat near-black abstract cat-mask silhouette with blocky rounded bottom, rounded lower corners, two soft ear-like upper corners, and a shallow V-shaped top valley",
        "fill": "#08090A",
        "bounds": {
          "x": [190, 835],
          "y": [230, 795]
        },
        "geometry_constraints": [
          "one filled path",
          "crisp boundary",
          "flat fill",
          "no stroke",
          "no shadow",
          "no bevel",
          "no fur detail",
          "no mouth or nose"
        ],
        "must_preserve": [
          "large black mass",
          "soft ear-like upper corners",
          "V-shaped top valley",
          "blocky rounded bottom"
        ],
        "must_not_add": [
          "whiskers",
          "mouth",
          "nose",
          "outline",
          "inner facial details",
          "sticker border",
          "3D material"
        ]
      },
      {
        "id": "eye-left",
        "order": 2,
        "role": "left white overlay eye",
        "format_target": "svg",
        "shape_model": "rounded half-oval overlay",
        "description": "small white rounded half-oval eye overlay placed low in the left half of the black mask",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [285, 415],
          "y": [565, 650]
        },
        "geometry_constraints": [
          "opaque white overlay",
          "simple rounded half-oval",
          "no transparency",
          "no mask",
          "no shadow"
        ],
        "must_preserve": ["low eye placement", "rounded half-oval silhouette"],
        "must_not_add": ["pupil", "eyelash", "outline", "glow"]
      },
      {
        "id": "eye-right",
        "order": 3,
        "role": "right white overlay eye",
        "format_target": "svg",
        "shape_model": "rounded half-oval overlay",
        "description": "small white rounded half-oval eye overlay placed low in the right half of the black mask",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [610, 740],
          "y": [565, 650]
        },
        "geometry_constraints": [
          "opaque white overlay",
          "simple rounded half-oval",
          "no transparency",
          "no mask",
          "no shadow"
        ],
        "must_preserve": ["low eye placement", "rounded half-oval silhouette", "symmetry with eye-left"],
        "must_not_add": ["pupil", "eyelash", "outline", "glow"]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "3 foreground layers plus background",
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
        "bevel",
        "blur",
        "boolean hole",
        "alpha cutout"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "must": [
        "premium silver-white field",
        "subtle lower charcoal translucent gradient",
        "one large flat near-black abstract mask",
        "two white rounded half-oval eye overlays",
        "large quiet background"
      ],
      "avoid": [
        "whiskers",
        "mouth",
        "nose",
        "fur",
        "outline",
        "shadow",
        "bevel",
        "sticker border",
        "plastic shine",
        "3D render",
        "extra symbols",
        "text",
        "watermark"
      ],
      "tested_prompt_note": "This example intentionally uses an abstract cat-mask topology. For reusable generation, select the mask topology from the app semantics first and do not reuse cat ears, a V-shaped top valley, or paired eyes unless that topology was chosen."
    }
  }
}
```
