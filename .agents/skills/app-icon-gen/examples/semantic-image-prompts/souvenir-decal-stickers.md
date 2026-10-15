# souvenir-decal-stickers

Use this when the app should feel playful, collectible, tagged, local, or personal through a small set of sticker-like symbols. This is a style template, not a fixed travel-icon template: change the sticker subjects to match the app.

The stable style grammar is:

- pale gray-blue rounded app surface with subtle edge/bottom darkening
- 2-3 small die-cut sticker groups, together about 30-40% of the canvas
- loose triangular or diagonal cluster, usually center-right or lower-right, with stickers visually separated
- thick warm-white sticker borders
- bold flat interior colors and black detail marks
- abstract block labels instead of readable text
- no handle, title word, appliance hardware, large collage, or generic scrapbook symbols unless app-specific

Expected source-layer mapping:

- background -> `icon.json.fill` low-contrast pale gray-blue fill or gradient
- `sticker-a`, `sticker-b`, `sticker-c` -> independent SVG sticker groups
- each sticker group -> warm-white border shape plus 1-3 simple interior shapes
- optional label marks -> small opaque block overlays, not text

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: premium souvenir decal sticker icon on a calm pale gray-blue rounded surface.
Subject: a small loose cluster of {2-3 app-specific sticker subjects}, occupying about one-third of the canvas with large quiet background around it; keep stickers separated in a triangular or diagonal arrangement, not merged into one collage.
Layout: primary sticker slightly left or lower-left within the cluster, secondary sticker upper-right, small badge/ticket lower-right; slight overlap is allowed only if every warm-white sticker border remains visible.
Palette/material: pale gray-blue surface with subtle edge/bottom darkening; thick warm-white die-cut sticker borders; bold flat colors chosen for the app; black detail marks; abstract block labels only.
Layering: any apparent cutout, label block, sticker interior gap, or overlap should read as a separate opaque overlay shape, not a transparent carved hole.
Quality: premium App Store icon, playful but sparse, readable at small size, SVG-friendly sticker groups.
No readable text, watermark, handle, title word, appliance hardware, oversized collage, shadow, bevel, 3D material, or texture.
```

## Variant Axes

- Sticker subjects: choose 2-3 app-specific motifs from the content slots below, or author equivalent motifs with the same density.
- Cluster anchor: center-right, lower-right, or lower-center; keep large quiet surface around the stickers.
- Sticker relation: separated triangular cluster by default; slight overlap only when each border remains visible.
- Palette: pale gray-blue surface is stable; sticker colors should change with app category.

## Content Slot Sets

Choose one set from app semantics, or author a new set with the same density and complexity:

| App type | Sticker subject slots |
| --- | --- |
| cafe / food journal | coffee cup, pastry, receipt/ticket badge |
| music / events | vinyl record, concert ticket, guitar pick or cassette |
| maker / tools | wrench/tool badge, lightning bolt, blueprint/ticket badge |
| travel / local guide | landmark badge, taxi or transit shape, bus/ticket badge |
| wellness / habit | water drop badge, leaf capsule, calendar ticket |
| finance / savings | coin badge, receipt ticket, small vault/tag |

Do not let the model reuse these literally when the app suggests better symbols. The requirement is the sticker style, not the listed content.

## Template Conversion Flow

Default route: transparent PNG sticker-cluster foreground over an `icon.json.fill` background when the selected stickers contain dense illustration, black contour marks, tiny abstract label blocks, or baked decal shadows. Use SVG sticker groups only when the selected concept is simple enough to redraw faithfully as separate opaque shapes. This is the main template where PNG import is a first-class route rather than an exceptional fallback.

- Keep the pale gray-blue surface as `icon.json.fill` or one simple background layer; do not trace surface darkening or app-mask edge treatment.
- For simple stickers, author each sticker as an independent SVG group: warm-white border shape, flat interior color shapes, and black detail/block-label overlays.
- For dense selected stickers, isolate the whole sparse sticker cluster as one transparent PNG layer after checking clean edges on neutral/checker backgrounds. Do not import the full app icon.
- Before using the PNG layer in the spec, run `clean-sticker-matte` on the extracted sticker cluster to remove cool gray-blue exterior shadow halos while preserving warm-white decal paper, flat colors, black detail marks, and a thin clean antialias edge.
- For PNG-route `.icon` bundles, keep the sticker PNG layer optically plain: set the layer `glass` value to `false`, keep group translucency disabled, and do not add refractivity, specular-location, blur-material, or translucency specializations.
- Reject readable text, appliance/title artifacts, oversized collages, dirty matte edges, gray-blue shadow halos, and merged sticker boundaries. Preserve only clean sticker artwork and explicit app-relevant decal shadows that survive isolated PNG review.

Recommended PNG cleanup command:

```bash
npm --prefix /Users/zero/code/My/app-icon-skill/skills/app-icon-gen/scripts run clean-sticker-matte -- \
  --input "$delivery/tmp/work/foreground-stickers.raw.png" \
  --out "$delivery/tmp/work/foreground-stickers.png" \
  --preview-on-black "$delivery/tmp/work/foreground-stickers-on-black.png"
```

## Example Instantiation (Not A Default)

```text
Apple app icon for CafePin, a neighborhood cafe collection app.
Seed: 845219.
Style: premium souvenir decal sticker icon on a calm pale gray-blue rounded surface.
Subject: a small loose cluster of coffee cup, pastry, and receipt badge stickers, occupying about one-third of the canvas with large quiet background around it; keep stickers separated in a triangular arrangement, not merged into one collage.
Layout: coffee cup sticker slightly lower-left within the cluster, pastry sticker upper-right, receipt badge lower-right; slight overlap is allowed only if every warm-white sticker border remains visible.
Palette/material: pale gray-blue surface with subtle edge/bottom darkening; thick warm-white die-cut sticker borders; coffee brown, cream, amber, and muted red sticker interiors; black detail marks; abstract block labels only.
Layering: any apparent cutout, label block, sticker interior gap, or overlap should read as a separate opaque overlay shape, not a transparent carved hole.
Quality: premium App Store icon, playful but sparse, readable at small size, SVG-friendly sticker groups.
No readable text, watermark, handle, title word, appliance hardware, oversized collage, shadow, bevel, 3D material, or texture.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": "{fresh random integer}",
  "priority": "produce a reference image that can be rebuilt as semantic SVG sticker groups",
  "conversion_policy": "All apparent cutouts, label marks, stripes, counters, and negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, text, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "{app_name}",
      "category": "{category}",
      "job_to_be_done": "{job_to_be_done}",
      "tone": "{playful / curated / personal / local / creative}"
    },
    "style": {
      "direction": "souvenir-decal-stickers",
      "svg_convertibility": "medium",
      "style_notes": "small cluster of app-specific die-cut decals on a pale gray-blue rounded surface; content slots change by app"
    },
    "icon_intent": {
      "metaphor": "{app-specific collectible/tag/pin/sticker metaphor}",
      "small_size_readability": "must remain clear at 64x64 as a quiet surface with 2-3 distinct sticker silhouettes",
      "must_feel_like": ["curated", "playful", "personal", "polished"],
      "must_not_feel_like": ["generic emoji pack", "busy scrapbook", "tourist poster unless travel app", "real appliance"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "Sticker borders, windows, stripes, label blocks, counters, and gaps are positive opaque shapes inside each sticker group. Do not use masks, clipPaths, transparent holes, text, or shadowed recesses."
    },
    "content_slots": [
      {
        "id": "sticker-a",
        "subject": "{primary app-specific symbol}",
        "role": "largest or tallest sticker",
        "complexity": "simple silhouette plus at most two interior shapes"
      },
      {
        "id": "sticker-b",
        "subject": "{secondary app-specific symbol}",
        "role": "bright color accent sticker",
        "complexity": "simple silhouette plus black detail marks"
      },
      {
        "id": "sticker-c",
        "subject": "{supporting app-specific badge or ticket}",
        "role": "small supporting sticker",
        "complexity": "simple badge shape plus abstract label blocks"
      }
    ],
    "canvas": {
      "size": 1024,
      "composition_anchor": "center-right or lower-right",
      "subject_scale": {
        "cluster_width_pct": [0.30, 0.42],
        "cluster_height_pct": [0.26, 0.40]
      },
      "safe_area": {
        "x": [150, 900],
        "y": [150, 870]
      },
      "alignment": "small sticker cluster with large quiet background; usually center-right or lower-right; primary sticker slightly left/lower-left, secondary sticker upper-right, small badge/ticket lower-right; keep visible gaps or only slight overlap so each sticker boundary remains separate; avoid filling the whole icon or making a straight row"
    },
    "background": {
      "type": "low-contrast-gradient",
      "color": "#C7D2D4",
      "gradient_stops": ["#DDE8EA", "#C6D1D3", "#AAB3B2"],
      "gradient_policy": {
        "contrast_level": "low",
        "hue_relationship": "monochrome-cool-gray-blue",
        "must": [
          "source-like pale gray-blue surface",
          "subtle edge or bottom darkening",
          "background remains quiet and spacious"
        ],
        "avoid": [
          "flat saturated blue card",
          "dirty charcoal field",
          "realistic metal texture",
          "handle or hardware",
          "title word"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          "extended-srgb:0.867 0.910 0.918 1",
          "extended-srgb:0.776 0.820 0.827 1"
        ]
      }
    },
    "layers": [
      {
        "id": "sticker-a",
        "order": 1,
        "role": "primary decal",
        "format_target": "svg",
        "shape_model": "die-cut sticker group",
        "description": "largest app-specific sticker with thick warm-white border and simple flat interior",
        "fill": ["#FFF4DE", "{primary_fill}", "{detail_fill}"],
        "bounds": {
          "x": [360, 580],
          "y": [360, 620]
        },
        "geometry_constraints": [
          "border is a positive warm-white shape",
          "interior uses 1-3 simple filled shapes",
          "crisp boundary",
          "slight rotation allowed",
          "visually separated from the other stickers",
          "no readable text",
          "no shadow"
        ],
        "must_preserve": [
          "independent die-cut sticker silhouette",
          "simple app-specific subject",
          "small scale relative to canvas"
        ],
        "must_not_add": [
          "tiny labels",
          "dense linework",
          "dirty edge",
          "drop shadow"
        ]
      },
      {
        "id": "sticker-b",
        "order": 2,
        "role": "secondary decal",
        "format_target": "svg",
        "shape_model": "die-cut sticker group",
        "description": "bright supporting sticker with thick warm-white border and black detail marks",
        "fill": ["#FFF4DE", "{secondary_fill}", "#111111"],
        "bounds": {
          "x": [535, 750],
          "y": [345, 540]
        },
        "geometry_constraints": [
          "border is a positive warm-white shape",
          "large flat interior shapes",
          "black marks stay simple",
          "visually separated from the other stickers",
          "no readable text",
          "no shadow"
        ],
        "must_preserve": [
          "bold supporting color",
          "separate sticker boundary",
          "simple readable silhouette"
        ],
        "must_not_add": [
          "tiny texture",
          "extra mini symbols",
          "fake sticker shadow"
        ]
      },
      {
        "id": "sticker-c",
        "order": 3,
        "role": "small badge or ticket decal",
        "format_target": "svg",
        "shape_model": "die-cut badge group",
        "description": "small supporting badge/ticket sticker with abstract block label marks",
        "fill": ["#FFF4DE", "{accent_fill}", "#151515"],
        "bounds": {
          "x": [560, 770],
          "y": [555, 730]
        },
        "geometry_constraints": [
          "border is a positive warm-white shape",
          "label blocks are opaque rectangles or simple marks",
          "visually separated from the other stickers",
          "no real text",
          "no shadow"
        ],
        "must_preserve": [
          "small supporting scale",
          "abstract label detail",
          "visual separation from other stickers"
        ],
        "must_not_add": [
          "readable words",
          "numbers",
          "QR codes",
          "dense ticket perforations"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "background fill plus one transparent PNG sticker cluster, or background plus 2-3 SVG sticker groups when simple",
      "png_route_preferred_for_dense_selected_concepts": true,
      "svg_first": false,
      "allowed_svg_primitives": ["filled path", "compound path", "polygon", "rounded rectangle", "circle"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "clipPath",
        "mask",
        "shadow",
        "glow",
        "bevel",
        "blur",
        "soft unclear boundary",
        "alpha cutout"
      ],
      "png_route_allowed_for": ["strict-fidelity", "sticker too dense after user acceptance", "selected sticker artwork is materially better than SVG approximation"],
      "png_icon_composer_settings": {
        "layer_glass": false,
        "group_translucency": {
          "enabled": false,
          "value": 0
        },
        "forbid_features": ["refractivity", "specular-location", "blur-material", "translucency-specializations"]
      },
      "png_matte_cleanup": {
        "script": "clean-sticker-matte",
        "purpose": "remove cool gray-blue exterior shadow halos from extracted sticker-cluster PNGs",
        "must_preserve": ["warm-white sticker border", "flat interior color", "black detail marks", "thin clean antialias edge"],
        "must_remove": ["gray-blue shadow halo", "dirty matte edge", "background surface residue"]
      }
    },
    "image_generation_constraints": {
      "priority": "preserve style grammar and scale while letting content slots change by app",
      "avoid": [
        "fixed travel subjects when not a travel app",
        "handle",
        "title word",
        "large central collage",
        "straight row of equal-size stickers",
        "merged sticker mass",
        "generic scrapbook symbols unless app-specific",
        "readable text",
        "photorealism",
        "drop shadow",
        "3D object rendering",
        "busy texture",
        "tiny detail"
      ]
    }
  }
}
```
