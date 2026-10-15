# outlined-friendly-action-mark

Use this for friendly reminders, lightweight utilities, plant care, creative actions, communication helpers, audio tools, and approachable consumer apps where one cheerful flat object with a heavy rounded near-black outline can carry the identity on a warm quiet field.

Expected source-layer mapping:

- background -> `icon.json.fill` solid warm off-white field
- main-action-outline -> one near-black SVG contour/base shape
- main-action-fill -> one saturated SVG filled symbolic object
- interior-detail -> optional near-black SVG detail shape
- motion-mark-* -> 2-4 separate near-black SVG rounded accent marks

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: warm off-white solid field filling the entire square canvas edge to edge, with one friendly flat outlined action mark.
Subject: one app-specific {simple action object / cheerful utility symbol / friendly signal mark / reminder object / sprout or nature mark / play or media tab / creative tool cue} with a saturated flat fill and a thick rounded near-black outline; add 2-4 separate short near-black motion or attention marks only if they clarify the action.
Composition: {center-right / centered / slightly lower-right} large main mark, about 58-68% of canvas, with generous quiet background and accents placed on {left / upper-left / lower-right}.
Palette/material: solid warm off-white background, near-black outline and accents, one saturated flat fill chosen from {mint / yellow / coral / sky blue / lavender}; crisp SVG-friendly shapes.
Layering: foreground pieces are independent opaque flat layers. Any apparent interior detail should be a separate near-black opaque shape, not a transparent carved hole.
Quality: premium App Store icon, friendly, readable at 64px, strong silhouette, clean negative space.
Canvas: full square icon image; the warm off-white background must reach all four edges with no black corners and no visible app mask clipping.
No black corners, rounded app-mask preview, floating rounded card, border frame, text, watermark, brand logo, copied reference contour, face, UI details, sticker border, gradient, shadow, bevel, glow, 3D, thin outline, many tiny accents, complex multi-color interior, or photographic detail.
```

## Variant Axes

- Subject metaphor: reminder object, checkmark object, sprout, leaf, spark, note, cursor, chat bubble, play tab, waveform tab, or simple tool object.
- Fill color: mint, yellow, coral, sky blue, or lavender as one saturated flat fill.
- Accent placement: left, upper-left, or lower-right.
- Accent count: 2-4 short rounded marks.
- Anchor: center-right for action emphasis, centered for identity marks, lower-right for quiet-field variants.
- Interior detail: optional near-black check, vein, pulse, or simple action stroke, but never a face or tiny UI detail.

## Template Conversion Flow

Default route: direct semantic SVG. Author the background as a solid composer fill. Build the main object as a near-black filled contour/base shape plus a saturated interior fill above it. Use separate filled rounded paths for interior details and motion marks. Reject dirty PNG cutouts, gradients, shadows, bevels, texture, rounded preview masks, black corner artifacts, and thin stroked outlines that will not survive app-icon packaging.

## Example Instantiation (Not A Default)

```text
Apple app icon for LeafCue, a gentle plant-care and reminder app.
Seed: 592418.
Style: warm off-white solid field filling the entire square canvas edge to edge with one friendly flat outlined action mark.
Subject: one cheerful green leaf cue with a thick rounded near-black outline, one simple near-black curved vein, and three separate short near-black attention marks on the upper-left.
Composition: center-right large main mark, about 64% of canvas, with generous quiet warm background.
Palette/material: solid warm off-white background, near-black outline and accents, saturated mint-green flat fill; crisp SVG-friendly shapes.
Layering: foreground pieces are independent opaque flat layers. Interior detail is a separate near-black opaque shape, not a transparent carved hole.
Quality: premium App Store icon, friendly, readable at 64px, strong silhouette, clean negative space.
Canvas: full square icon image; the warm off-white background must reach all four edges with no black corners and no visible app mask clipping.
No black corners, rounded app-mask preview, floating rounded card, border frame, text, watermark, brand logo, copied reference contour, face, UI details, sticker border, gradient, shadow, bevel, glow, 3D, thin outline, many tiny accents, complex multi-color interior, or photographic detail.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 592418,
  "priority": "produce a friendly flat outlined action mark that can be rebuilt as semantic SVG layers when feasible",
  "conversion_policy": "Prefer independent opaque SVG layers for the outer contour, saturated fill, optional interior detail, and motion marks. If generated geometry drifts during SVG redraw, keep iterating on the semantic geometry and use overlay/diff evidence before accepting the package.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "LeafCue",
      "category": "gentle plant-care and reminder app",
      "job_to_be_done": "make care reminders feel fresh, friendly, and quick",
      "tone": "friendly, simple, cheerful, clear"
    },
    "style": {
      "direction": "outlined-friendly-action-mark",
      "svg_convertibility": "high",
      "style_notes": "warm off-white full-square field, one saturated flat action symbol, thick rounded near-black outline, 2-4 separate motion marks"
    },
    "icon_intent": {
      "metaphor": "a lively leaf cue as a friendly reminder signal",
      "small_size_readability": "must remain clear at 64x64",
      "must_feel_like": ["friendly", "simple", "active", "approachable"],
      "must_not_feel_like": ["brand copy", "sticker", "3D", "glossy", "busy UI", "mascot face"]
    },
    "layering_policy": {
      "negative_space_strategy": "opaque-detail-layers",
      "cutouts_are_layers": true,
      "description": "Use a solid background, one near-black contour/base shape, one saturated filled object, optional near-black interior detail, and separate motion marks. Do not carve transparent holes."
    },
    "subject_topology": {
      "type": "single friendly outlined action mark with motion accents",
      "primary_parts": [
        "main-action-outline: one thick rounded near-black contour/base shape",
        "main-action-fill: one saturated mint-green leaf interior",
        "interior-detail: one simple near-black curved vein",
        "motion-mark-1..3: three separate short near-black rounded marks on the upper-left"
      ],
      "silhouette_rejects": ["copied reference contour without user approval", "brand logo", "face", "thin outline", "many tiny marks", "complex multi-color interior", "black corner preview mask"]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center-right",
      "subject_scale": { "width_pct": [0.58, 0.68], "height_pct": [0.58, 0.68] },
      "safe_area": { "x": [90, 930], "y": [90, 930] },
      "alignment": "large friendly leaf cue with attention accents on the upper-left"
    },
    "background": {
      "type": "solid",
      "color": "#F4F0E5",
      "gradient_stops": [],
      "composer_fill_target": { "solid": "extended-srgb:0.957 0.941 0.898 1" }
    },
    "layers": [
      {
        "id": "main-action-outline",
        "order": 1,
        "role": "thick near-black contour",
        "format_target": "svg",
        "shape_model": "filled rounded contour/base path",
        "description": "large near-black rounded leaf-cue contour/base shape",
        "fill": "#202124",
        "bounds": { "x": [250, 900], "y": [150, 900] },
        "geometry_constraints": ["heavy rounded contour", "flat fill", "no stroke", "no shadow", "no bevel"],
        "must_preserve": ["friendly heavy outline", "large readable symbol"],
        "must_not_add": ["face", "brand logo", "extra tiny detail"]
      },
      {
        "id": "main-action-fill",
        "order": 2,
        "role": "saturated symbol interior",
        "format_target": "svg",
        "shape_model": "filled rounded leaf interior path",
        "description": "large saturated mint-green leaf interior",
        "fill": "#5BD889",
        "bounds": { "x": [310, 840], "y": [190, 780] },
        "geometry_constraints": ["crisp boundary", "flat fill", "rounded friendly silhouette", "no gradient", "no shadow"],
        "must_preserve": ["saturated fill", "simple leaf-cue identity"],
        "must_not_add": ["face", "brand logo", "extra tiny detail"]
      },
      {
        "id": "interior-detail",
        "order": 3,
        "role": "simple vein detail",
        "format_target": "svg",
        "shape_model": "filled rounded curved detail path",
        "description": "near-black rounded curved vein detail inside the leaf",
        "fill": "#202124",
        "bounds": { "x": [420, 720], "y": [420, 780] },
        "geometry_constraints": ["opaque fill", "rounded terminals", "no stroke", "no transparency"],
        "must_preserve": ["clear single-detail rhythm"],
        "must_not_add": ["text", "face", "extra check"]
      },
      {
        "id": "motion-marks",
        "order": 4,
        "role": "attention accents",
        "format_target": "svg",
        "shape_model": "2-4 filled rounded short marks",
        "description": "three separate short near-black rounded marks on the upper-left",
        "fill": "#202124",
        "bounds": { "x": [110, 360], "y": [180, 560] },
        "geometry_constraints": ["separate opaque marks", "rounded terminals", "no extra clutter"],
        "must_preserve": ["upper-left action signal"],
        "must_not_add": ["text", "sparkle cluster", "waveform bands"]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "4 foreground layer groups plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "compound path"],
      "forbidden_in_svg_assets": ["text", "image", "filter", "gradient", "opacity", "shadow", "glow", "blur", "texture", "mask", "clipPath"],
      "png_fallback_allowed_only_for": ["strict-fidelity private reference where repeated semantic SVG redraw fails after overlay/diff inspection"]
    }
  }
}
```
