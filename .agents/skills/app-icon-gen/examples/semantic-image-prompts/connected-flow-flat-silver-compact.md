# connected-flow-flat-silver-compact

Use this for an automation, sync, handoff, or workflow icon where the result should be a premium silver field with one compact flat connector that remains easy to redraw as SVG.

This example intentionally avoids the failure modes found during testing: oversized subject, shadowed holes, separate floating dots, and gray backgrounds that do not read as silver.

Expected source-layer mapping:

- background -> `icon.json.fill` linear gradient
- `folded-handoff-path` -> one SVG filled path

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: quiet satin-silver field with one compact flat off-white connector mark.
Subject: one app-specific connector topology based on {linked capsules / folded connector / asymmetric branch / node-ribbon / compact merge path}; avoid arrowheads, terminal-dot diagrams, and copied three-node arches.
Composition: {center / lower-left / lower-right}, with generous empty silver space around the mark.
Palette/material: smooth low-contrast silver gradient background, clean white foreground, no shadows.
Layering: any apparent cutout, counter, gap, or overlap should read as a separate opaque overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, circuit details, terminal dots, or extra symbols.
```

## Variant Axes

- Topology: linked capsules, folded connector, asymmetric branch, node-ribbon, compact merge path.
- Anchor: center for neutral sync; lower-left or lower-right for tucked workflow/handoff tools.
- Foreground material: off-white, pale silver-white, or one same-palette accent layer.
- Silver field: low-contrast monochrome gradient only; no rim light, bevel, noise, or shadow.

## Template Conversion Flow

Default route: semantic SVG for the connector, with clean-mask retrace only when generated curves are stable but hard to hand-author.

- Keep the silver field as `icon.json.fill` or one simple background layer; do not trace background texture, edge darkening, or subtle surface noise.
- Rebuild the connector as one foreground component plus overlay covers for any apparent gaps or counters.
- If retracing, isolate only the connector mask, run multiple threshold candidates, and recolor the traced result to the selected high-contrast foreground color from the spec.
- Reject inner shadows, gray patch fills, glass residue, rim highlights, and any conversion that makes the connector larger or busier than the selected template composition.

## Example Instantiation (Not A Default)

```text
Apple app icon for RelayFlow, a workflow handoff utility.
Seed: 460127.
Style: quiet satin-silver field with one compact flat off-white connector mark.
Subject: a compact folded connector path for workflow handoff, centered or slightly low, with generous empty silver space and no arrowhead.
Palette/material: smooth low-contrast silver gradient background, clean white foreground, no shadows.
Layering: any apparent cutout, counter, gap, or overlap should read as a separate opaque overlay shape, not a transparent carved hole.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, circuit details, terminal dots, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 460127,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent cutouts, counters, gaps, stripes, or negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "RelayFlow",
      "category": "automation and workflow handoff utility",
      "job_to_be_done": "show a quiet controlled handoff between workflow steps",
      "tone": "premium, calm, precise, silver, restrained"
    },
    "style": {
      "direction": "connected-flow-silver",
      "svg_convertibility": "medium",
      "style_notes": "satin silver background, compact topology-first connector, one foreground SVG path, no terminal dots, no shadowed cutout"
    },
    "icon_intent": {
      "metaphor": "folded handoff connector",
      "small_size_readability": "must remain clear at 64x64",
      "must_feel_like": ["premium", "organized", "connected", "quiet"],
      "must_not_feel_like": ["circuit board", "generic network graph", "large blob", "three-node arch", "separate node diagram", "soft 3D object"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "Any apparent cutout, counter, notch, gap, or negative space is a separate opaque layer placed above the base shape. Do not request boolean holes, masks, clipPaths, alpha cutouts, or carved geometry."
    },
    "subject_topology": {
      "type": "compact folded handoff connector",
      "primary_parts": [
        "folded-handoff-path: one continuous off-white filled path with two broad horizontal terminals connected by a diagonal middle fold",
        "terminals are rounded ends inside the same path, not separate circles or dots"
      ],
      "silhouette_rejects": [
        "terminal dots",
        "separate node circles",
        "three-node arch",
        "network graph",
        "circuit traces",
        "floating pieces",
        "shadowed overlap"
      ]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.34, 0.44],
        "height_pct": [0.22, 0.30]
      },
      "safe_area": {
        "x": [280, 744],
        "y": [360, 700]
      },
      "alignment": "centered slightly below midpoint with large silver negative space"
    },
    "background": {
      "type": "linear-gradient",
      "color": "#D6D9DF",
      "gradient_stops": ["#ECEEF2", "#D1D5DD", "#9FA6B1"],
      "gradient_policy": {
        "contrast_level": "low-to-medium",
        "hue_relationship": "monochrome-silver",
        "stop_count": [2, 3],
        "must": [
          "flat vector-style icon reference",
          "smooth low-saturation silver ramp",
          "background stays quiet behind the connector",
          "foreground connector lies flat on the field with no cast, contact, or ambient shadow",
          "no hue jump"
        ],
        "avoid": [
          "blue-green-yellow palette",
          "rainbow gradient",
          "deep blue to bright yellow",
          "neon multi-color sweep",
          "high-contrast corner clash"
        ]
      },
      "composer_fill_target": {
        "linear-gradient": [
          "extended-srgb:0.925 0.933 0.949 1",
          "extended-srgb:0.820 0.835 0.867 1",
          "extended-srgb:0.624 0.651 0.694 1"
        ]
      },
      "material_note": "silver must come from broad low-saturation gradient only; no texture, no noise, no rim light, no glass"
    },
    "layers": [
      {
        "id": "folded-handoff-path",
        "order": 1,
        "role": "foreground connector",
        "format_target": "svg",
        "shape_model": "compact folded connector single filled path",
        "description": "one compact off-white rounded connector shaped like a folded handoff path, with short lower-left and upper-right terminals",
        "fill": "#FBFAF5",
        "bounds": {
          "x": [300, 724],
          "y": [400, 668]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp hard boundary",
          "single simple filled path",
          "large rounded terminals",
          "no stroke",
          "no opacity",
          "no shadow",
          "no inner shadow",
          "no contact shadow",
          "no ambient shadow",
          "no glow",
          "no bevel",
          "no hollow cutout"
        ],
        "must_preserve": [
          "compact scale",
          "single connected path",
          "large empty silver background around the subject",
          "asymmetric folded handoff topology"
        ],
        "must_not_add": [
          "hole",
          "inner cutout",
          "recessed groove",
          "drop shadow",
          "contact shadow",
          "ambient shadow",
          "soft edge",
          "terminal dots",
          "separate node circles",
          "three-node arch",
          "extra dots",
          "circuit traces",
          "large foreground blob"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "1 foreground layer plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "compound path"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "clipPath",
        "mask",
        "stroke",
        "opacity",
        "shadow",
        "inner shadow",
        "glow",
        "bevel",
        "blur",
        "soft unclear boundary",
        "hollow cutout with shading"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "priority": "small compact flat symbol, crisp separable SVG shapes, premium silver background, no shadow or floating depth",
      "avoid": [
        "photorealism",
        "drop shadow",
        "contact shadow",
        "ambient shadow",
        "inner shadow",
        "soft glow",
        "floating symbol",
        "raised material",
        "3D object rendering",
        "busy texture",
        "tiny detail",
        "existing app icon or brand mark",
        "three-node arch",
        "terminal dots",
        "separate node circles",
        "large subject",
        "shadowed holes",
        "separate floating dot"
      ]
    }
  }
}
```
