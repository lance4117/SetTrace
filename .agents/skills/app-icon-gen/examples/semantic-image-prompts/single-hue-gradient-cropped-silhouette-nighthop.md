# single-hue-gradient-cropped-silhouette-nighthop

Use this when the app should feel bold, mysterious, premium, and iconic through an oversized near-black silhouette cropped by the app icon canvas.

This is a style family, not a fixed black rabbit recipe. The stable grammar is the composition: one restrained single-hue gradient background, one huge cropped near-black silhouette, optional dark translucent rear silhouette, and one simple white overlay feature.

Expected source-layer mapping:

- background -> `icon.json.fill` restrained single-hue gradient, usually purple/violet or another dark-compatible hue
- `rear-silhouette` -> optional SVG or clean PNG translucent same-hue shape with crisp boundary
- `main-silhouette` -> one SVG filled near-black cropped silhouette path
- `white-feature` -> one SVG white oval/capsule overlay, not a hole

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: premium flat vector icon with a restrained single-hue {violet / blue-violet / teal / green / red} gradient and one oversized cropped near-black silhouette.
Background layer: smooth single-color-family {hue} gradient, lighter {hue} in {upper-left / top-left} blending into deeper {hue} on {right / lower-right} and darker {hue} near the lower edge; clean app-icon field, no neon, no rainbow, no multicolor split.
Subject: one huge near-black abstract {rabbit side-profile / fox side-profile / owl silhouette / bat silhouette / pet profile / signal-mask / app-specific creature mark}, intentionally cropped by {left / bottom / right / two or three canvas edges}; the crop is part of the design, not a mistake. Use broad simple curves and 1-2 sweeping appendages such as ears, wings, or antennae.
Rear layer: optional dark translucent same-hue rear silhouette behind the black shape, offset slightly, crisp and separable; use it for a second ear, wing, or echo shape, not as a blur or shadow.
Details: one simple opaque white {oval eye / capsule signal / moon dot / feature mark} overlay inside the black silhouette; keep it large and readable.
Layering: the white feature is a separate opaque overlay layer, never a transparent cutout; the rear silhouette is a separate layer with crisp boundaries, not a shadow.
Quality: premium App Store icon, dramatic asymmetrical crop, strong silhouette, clean negative space, SVG-friendly layers.
If the subject must stay abstract or non-rabbit, forbid the closest wrong reading, such as `not a complete animal portrait`, `no rabbit ears`, `no muzzle detail`, or `no anatomy`.
No text, watermark, outline, fur, whiskers, mouth, nose, paws, teeth, feathers, tiny anatomy, sticker border, drop shadow, glow, bevel, glossy material, 3D render, texture, or extra unrelated symbols.
```

## Variant Axes

- Background hue family: violet, blue-violet, teal, green, red. Keep enough brightness in one corner to frame the black silhouette.
- Gradient direction: upper-left to lower-right, left to right, top-left to right, top to bottom with lower darkening.
- Silhouette family: rabbit side-profile, fox side-profile, owl silhouette, bat silhouette, pet profile, signal-mask, app-specific creature mark.
- Crop edges: left plus bottom, bottom plus right, left plus bottom plus right, or one dominant edge plus one partial edge.
- Appendage shape: long sweeping ears, triangular ears, wing arc, antenna pair, crest, back fin.
- Rear silhouette: none, second ear, wing echo, back plate, antenna echo. Use a crisp same-hue translucent layer only.
- White feature: oval eye, tilted eye, capsule signal, moon dot, simple feature mark.
- Subject strictness: for non-rabbit variants, explicitly forbid long rabbit ears or animal-portrait details if they are not part of the app metaphor.

## Template Conversion Flow

Default route: semantic SVG or clean-mask retrace for a single oversized cropped silhouette.

- Author the single-hue background as a restrained gradient. The rear echo, if present, is a separate crisp same-hue layer, not a blur or shadow.
- Build the rear echo/second ear as a simple semantic shape from the intended bbox and curve rhythm. Do not trace it from the background gradient, shadow, or semi-transparent source region.
- Keep the main silhouette as one near-black filled path intentionally cropped by the canvas; keep the white feature as a separate opaque overlay.
- If retracing, isolate the main silhouette with multiple threshold candidates and preserve the crop, mass, and feature placement. Recolor to near-black from the spec.
- Do not use clean-mask retrace for the rear echo unless the source region is already a crisp, separable flat shape. If a traced rear echo imports the right-side field, gradient transition, shadow, opacity smear, jagged top edge, or a huge shape extending beyond the intended rear appendage, discard it and redraw the rear echo semantically.
- Reject extra facial detail, fur/feather texture, soft shadow halos, transparent holes, fragmented silhouette traces, and rear-echo trace noise.
- Before completion, run `geometry-audit` on any retraced SVG layer. A rear echo with micro-segments, bounds far outside its intended bbox, or path noise must be treated as a route failure even when reference mean/local gates pass.

## Example Instantiation (Not A Default)

```text
Apple app icon for CoveFox, a private notes and focus companion.
Seed: 586204.
Style: premium flat vector icon with a restrained teal-green single-hue gradient and one oversized cropped near-black silhouette.
Background layer: smooth single-color-family teal-green gradient, pale mint-teal in the upper-left blending into deeper jade-teal on the right and darker forest-teal near the lower edge; clean app-icon field, no neon, no rainbow, no cyan split.
Subject: one huge near-black abstract fox-signal silhouette, cropped by the bottom edge and right edge; broad rounded head mass at lower-right, one sharp triangular ear rising toward the upper center, and one sweeping back/tail curve entering from the left. Keep it iconic and minimal, not an animal portrait.
Rear layer: one dark translucent teal rear-ear or back-echo shape behind the black silhouette, offset slightly upward and left, visible as a quiet separate shape, not a blur.
Details: one simple opaque white capsule eye or signal mark inside the black head, placed on the right half; filled white shape, not a cutout.
Layering: the white feature is a separate opaque overlay layer; the rear echo is a separate semi-transparent teal shape; no transparent holes or masks.
Quality: premium App Store icon, bold crop, strong silhouette, clean negative space, SVG-friendly layers.
No text, watermark, rabbit ears, outline, fur, whiskers, mouth, nose, paws, teeth, small anatomy, drop shadow, glow, bevel, glossy material, 3D render, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 586204,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "The main silhouette must be one filled near-black shape intentionally cropped by the canvas. The white feature must be a separate opaque overlay layer; never use transparent holes, masks, clipPaths, alpha cutouts, or carved geometry. The rear silhouette must be a separate crisp same-hue layer, not a blur or shadow.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "CoveFox",
      "category": "private notes and focus companion",
      "job_to_be_done": "show a quiet, protective companion for private thoughts and focused sessions",
      "tone": "bold, calm, private, premium"
    },
    "style": {
      "direction": "single-hue-gradient-cropped-silhouette",
      "svg_convertibility": "high",
      "style_notes": "restrained single-hue gradient field, oversized cropped near-black silhouette, optional translucent rear silhouette, one white overlay feature"
    },
    "icon_intent": {
      "metaphor": "protective fox-signal companion",
      "small_size_readability": "must remain clear at 64x64 as one cropped black silhouette with one white feature on a teal-green field",
      "must_feel_like": ["bold", "quiet", "protective", "premium"],
      "must_not_feel_like": ["cute cartoon fox", "detailed pet portrait", "3D mascot", "sticker", "game creature"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "The white capsule feature is an opaque overlay above the black silhouette. The rear echo is a separate translucent teal silhouette below the main black shape. Do not create transparent holes, masks, clipPaths, alpha cutouts, blurred shadows, or carved geometry."
    },
    "variant_axes": {
      "background_hue_family": ["violet", "blue-violet", "teal", "green", "red"],
      "gradient_direction": ["upper-left-to-lower-right", "left-to-right", "top-left-to-right", "top-to-bottom-with-lower-darkening"],
      "silhouette_family": ["rabbit side-profile", "fox side-profile", "owl silhouette", "bat silhouette", "pet profile", "signal-mask", "app-specific creature mark"],
      "crop_edges": ["left-and-bottom", "bottom-and-right", "left-bottom-right", "one-dominant-edge-plus-partial-edge"],
      "rear_silhouette": ["none", "second ear", "wing echo", "back plate", "antenna echo"],
      "white_feature": ["oval eye", "tilted eye", "capsule signal", "moon dot", "simple feature mark"]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "lower-right cropped",
      "subject_scale": {
        "width_pct": [0.78, 1.12],
        "height_pct": [0.70, 1.05]
      },
      "safe_area": {
        "x": [-80, 980],
        "y": [90, 1080]
      },
      "alignment": "oversized silhouette intentionally cropped by bottom and right edges, with the head and white feature readable on the right half"
    },
    "background": {
      "type": "single-hue-gradient",
      "hue_family": "teal-green",
      "color": "#158A79",
      "gradient_stops": ["#A8F1DD", "#27B79B", "#11796E", "#102B2A"],
      "gradient_policy": {
        "contrast_level": "medium",
        "hue_relationship": "single-color-family teal-green",
        "direction": "upper-left-to-lower-right with lower darkening",
        "must_preserve": [
          "pale mint-teal upper-left",
          "deeper jade-teal right side",
          "dark forest-teal lower edge",
          "smooth single-hue transition"
        ],
        "must_not_add": [
          "neon glow",
          "cyan hotspot",
          "blue split outside the teal-green family",
          "rainbow",
          "radial glow",
          "wallpaper texture"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          { "offset": 0, "color": "extended-srgb:0.659 0.945 0.867 1" },
          { "offset": 0.50, "color": "extended-srgb:0.153 0.718 0.608 1" },
          { "offset": 0.82, "color": "extended-srgb:0.067 0.475 0.431 1" },
          { "offset": 1, "color": "extended-srgb:0.063 0.169 0.165 1" }
        ]
      }
    },
    "layers": [
      {
        "id": "rear-silhouette",
        "order": 1,
        "role": "translucent rear fox-signal echo",
        "format_target": "svg",
        "shape_model": "single filled translucent triangular ear or back-echo path",
        "description": "dark translucent teal rear ear or back echo behind the black silhouette, offset upward and left, with crisp boundary",
        "fill": "rgba(14, 73, 66, 0.52)",
        "bounds": {
          "x": [190, 760],
          "y": [105, 520]
        },
        "geometry_constraints": [
          "one filled path",
          "crisp boundary",
          "controlled opacity",
          "same hue family",
          "not a blur",
          "not a shadow",
          "not traced from the background gradient",
          "no jagged or noisy trace edge"
        ],
        "must_preserve": [
          "separate rear shape",
          "offset behind main silhouette",
          "subtle teal translucency"
        ],
        "must_not_add": [
          "blurred shadow",
          "glow",
          "texture",
          "extra rear shapes",
          "right-side field imported as foreground",
          "gradient/shadow smear",
          "bounds far outside intended rear shape"
        ]
      },
      {
        "id": "main-silhouette",
        "order": 2,
        "role": "oversized cropped black fox-signal silhouette",
        "format_target": "svg",
        "shape_model": "single filled cropped side-profile silhouette path",
        "description": "huge near-black abstract fox-signal silhouette with broad rounded head mass at lower-right, one sharp triangular ear rising toward upper center, and one sweeping back or tail curve entering from the left; intentionally cropped by the bottom and right canvas edges",
        "fill": "#010102",
        "bounds": {
          "x": [40, 1080],
          "y": [130, 1080]
        },
        "geometry_constraints": [
          "one filled path",
          "near-black opaque fill",
          "crisp boundary",
          "intentional canvas-edge crop",
          "no stroke",
          "no shadow",
          "no fur detail"
        ],
        "must_preserve": [
          "oversized cropped black mass",
          "bottom and right crop",
          "rounded lower-right head mass",
          "one sharp triangular ear",
          "one sweeping back or tail curve",
          "minimal app-specific companion identity"
        ],
        "must_not_add": [
          "complete centered animal portrait",
          "cute fox mascot",
          "muzzle detail",
          "nose",
          "mouth",
          "whiskers",
          "paws",
          "fur",
          "outline",
          "sticker border",
          "3D material"
        ]
      },
      {
        "id": "white-feature",
        "order": 3,
        "role": "white capsule eye or signal overlay",
        "format_target": "svg",
        "shape_model": "tilted capsule overlay",
        "description": "simple opaque white capsule eye or signal overlay placed inside the right half of the black head",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [690, 855],
          "y": [430, 610]
        },
        "geometry_constraints": [
          "opaque white overlay",
          "simple capsule",
          "separate top layer",
          "no transparency",
          "no mask",
          "no clipPath",
          "no shadow"
        ],
        "must_preserve": [
          "single white capsule feature",
          "large readable scale",
          "placement inside black head"
        ],
        "must_not_add": [
        "pupil",
          "eyelash",
          "highlight",
          "outline",
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
        "ellipse",
        "linear gradient"
      ],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "clipPath",
        "mask",
        "stroke",
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
        "controlled-translucent-layer",
        "renderer-artifact",
        "strict-fidelity"
      ]
    },
    "image_generation_constraints": {
      "priority": "dramatic cropped silhouette and clear separable SVG-convertible layers",
      "avoid": [
        "complete animal portrait",
        "cute fox mascot",
        "centered mascot head",
        "muzzle detail",
        "fur",
        "whiskers",
        "mouth",
        "nose",
        "paws",
        "outline",
        "sticker border",
        "drop shadow",
        "glow",
        "bevel",
        "3D render",
        "texture",
        "tiny details",
        "extra symbols"
      ]
    }
  }
}
```
