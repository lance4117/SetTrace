# organic-blob-fusemap

Use this for a lightweight identity mark, mapping app, connection tool, or playful utility where a minimal organic form is enough.

Expected source-layer mapping:

- background -> `icon.json.fill` solid light field
- `connected-blob` -> one SVG filled organic path
- `satellite-dot` -> one SVG circle

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: minimal single-color identity field with one high-contrast organic connected shape.
Subject: one app-specific organic identity mark based on {fused idea blob / soft map cell / living connector / flexible workspace knot / playful utility mark}; optional satellite dot only if it helps the metaphor.
Composition: {center / lower-right / lower-left}, with a simple crisp silhouette and large quiet field.
Palette/material: solid color or same-hue subtle gradient background; choose pure black foreground on light backgrounds or pure white foreground on dark backgrounds, with crisp flat fills.
Layering: any apparent inner gap or separation should read as a separate opaque background-colored overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, graph lines, paw print, splatter, or extra symbols.
```

## Variant Axes

- Organic topology: fused idea blob, soft map cell, living connector, flexible workspace knot, playful utility mark.
- Satellite usage: none, one dot, or one small same-color companion shape.
- Anchor: center for identity marks; lower corners when the app wants more quiet space.
- Palette: any single-color background family; foreground must be pure black `#000000` or pure white `#FFFFFF` based on contrast. One vivid accent is allowed only when explicitly named.

## Template Conversion Flow

Default route: direct semantic SVG, with clean-mask retrace as a fallback for the main blob contour.

- Author the background as a clean solid or low-contrast gradient.
- Keep the primary organic blob as one filled SVG path and the companion mark as one optional separate SVG path.
- If retracing, isolate the primary blob only, test multiple mask thresholds, and recolor the result to the semantic foreground color from the spec.
- Reject sampled shadows, texture, extra blobs not named by the template, face/mascot drift, and palette-quantized edge fragments.

## Example Instantiation (Not A Default)

```text
Apple app icon for FuseMap, an idea mapping tool.
Seed: 503812.
Style: minimal light-field identity mark with one pure-black organic connected shape.
Subject: a soft fused blob mark with one small satellite dot, centered, clever, not literal.
Palette/material: solid warm light background, pure-black foreground, crisp flat fills.
Layering: any apparent inner gap or separation should read as a separate opaque background-colored overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, graph lines, paw print, splatter, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 503812,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent cutouts, counters, gaps, stripes, or negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "FuseMap",
      "category": "idea mapping and lightweight connection tool",
      "job_to_be_done": "show small ideas fusing into one flexible map",
      "tone": "simple, clever, playful, clean"
    },
    "style": {
      "direction": "organic-blob-mark",
      "svg_convertibility": "high",
      "style_notes": "single-color light field, one pure-black connected organic blob, one separate pure-black dot"
    },
    "icon_intent": {
      "metaphor": "ideas fusing into a map",
      "small_size_readability": "must remain clear at 64x64",
      "must_feel_like": ["minimal", "clever", "connected", "soft"],
      "must_not_feel_like": ["molecule diagram", "paw print", "splat", "loading spinner"]
    },
    "layering_policy": {
      "negative_space_strategy": "not-needed",
      "cutouts_are_layers": true,
      "description": "This mark should not use cutouts. Keep all forms as filled positive shapes."
    },
    "subject_topology": {
      "type": "connected organic blob plus satellite dot",
      "primary_parts": [
        "connected-blob: one pure-black filled Bezier path made of three rounded lobes connected by smooth necks",
        "satellite-dot: one separate pure-black circle near lower-right"
      ],
      "silhouette_rejects": [
        "more than four lobes",
        "thin line connectors",
        "network graph nodes",
        "face",
        "paw print",
        "paint splatter"
      ]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.48, 0.62],
        "height_pct": [0.40, 0.56]
      },
      "safe_area": {
        "x": [210, 820],
        "y": [260, 760]
      },
      "alignment": "centered with satellite dot lower-right"
    },
    "background": {
      "type": "solid",
      "color": "#F4F5F2",
      "gradient_stops": [],
      "composer_fill_target": {
        "solid": "extended-srgb:0.957 0.961 0.949 1"
      }
    },
    "layers": [
      {
        "id": "connected-blob",
        "order": 1,
        "role": "main organic mark",
        "format_target": "svg",
        "shape_model": "single filled connected organic Bezier path",
        "description": "pure-black organic mark with three rounded lobes joined by smooth necks: upper-left lobe, upper-right lobe, and lower lobe",
        "fill": "#000000",
        "bounds": {
          "x": [210, 680],
          "y": [300, 710]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp boundary",
          "smooth Bezier contour",
          "neck width remains readable at small size",
          "no stroke",
          "no shadow",
          "no blur"
        ],
        "must_preserve": [
          "three-lobe connected topology",
          "soft organic contour",
          "large whitespace"
        ],
        "must_not_add": [
          "line connectors",
          "extra nodes",
          "eyes",
          "shadow",
          "texture"
        ]
      },
      {
        "id": "satellite-dot",
        "order": 2,
        "role": "separate satellite point",
        "format_target": "svg",
        "shape_model": "circle",
        "description": "one pure-black circular dot near the lower-right of the connected blob",
        "fill": "#000000",
        "bounds": {
          "x": [700, 800],
          "y": [640, 740]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp circular boundary",
          "no shadow"
        ],
        "must_preserve": [
          "separate dot relationship",
          "smaller than each blob lobe"
        ],
        "must_not_add": [
          "second dot",
          "tail",
          "glow"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "2 foreground layers plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "circle"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "stroke",
        "opacity",
        "shadow",
        "glow",
        "blur",
        "soft unclear boundary",
        "texture"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "must": [
        "single-color clean field",
        "one pure-black or pure-white connected organic blob chosen by contrast",
        "one separate same-color dot",
        "large whitespace",
        "flat vector-friendly shapes"
      ],
      "avoid": [
        "network graph",
        "line diagram",
        "many dots",
        "3D blob",
        "shadow",
        "face",
        "text"
      ]
    }
  }
}
```
