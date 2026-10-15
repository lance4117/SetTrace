# blue-field-cutout-badge

Use this for productivity utilities, travel/place apps, security products, health note apps, developer tools, route tools, or other simple utilities where the app identity can be carried by a centered white geometric badge on a saturated color field, cut by one same-color diagonal action gesture.

Expected source-layer mapping:

- background -> `icon.json.fill` solid saturated field
- white-badge -> one centered SVG filled geometric badge
- color-cut-overlay -> one same-background-color SVG opaque diagonal cut/check overlay
- white-visible-badge -> acceptable conversion-time compound SVG when the selected generated cut reaches the badge edge and is cleaner as negative space

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: saturated solid color field with one centered white geometric badge and one same-color diagonal cut/check gesture.
Subject: one app-specific {badge silhouette / utility plate / shield / map marker plate / cloud plate / abstract shelter mark / route marker} in white, crossed by a bold same-field-color {check-slash / route stripe / folded ribbon / action stroke / lightning slash}; do not use a copied reference silhouette or a letter.
Composition: centered badge, about 54-64% of canvas width and height, generous field margin, diagonal cut/check spans most of the badge width with one simple bend.
Palette/material: two-color flat vector style; saturated {blue / green / violet / red / charcoal} field, pure white badge, opaque cut/check matching the field color exactly; crisp SVG-friendly geometry.
Layering: all pieces are independent opaque flat layers where feasible. The cut/check is same-color geometry, not transparency, alpha cutout, mask, or clipPath.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at 64px.
No text, watermark, brand logo, copied reference contour, alphabet letter, real-estate brand identity, complex zigzag, gradients, shadows, bevels, glass, glow, stroke outlines, tiny details, UI elements, extra symbols, or photographic detail.
```

## Variant Axes

- Badge silhouette: shield, rounded utility badge, cloud plate, map marker plate, abstract shelter, circular badge, or simple app-specific plate.
- Cut gesture: check-slash, route stripe, folded ribbon, pulse slash, action stroke, or lightning slash.
- Field color: saturated blue, emerald green, violet, red, charcoal, or another single high-contrast brand color.
- Composition: centered by default; slightly lower or higher only when the badge silhouette needs balance.
- Badge geometry: peaked, tabbed, shield-like, rounded-rect, circular shield, or soft geometric plate, but always one large white component.

## Template Conversion Flow

Default route: direct semantic SVG. Author the field as a solid composer fill. Build the main white badge as one clean filled SVG path. Build the same-color cut/check as a separate opaque SVG path above the badge, matching the background fill exactly.

If the selected generated concept has a cut/check that touches the badge edge and the white visible region is cleaner than a manually authored overlay, use component-level vectorization for one white compound SVG path. Record this as a conversion-time negative-space exception, run overlay/diff verification, and keep it SVG-only. Do not use masks, clipPaths, alpha cutouts, strokes, gradients, shadows, bevels, or PNG fallback for the normal route.

## Example Instantiation (Not A Default)

```text
Apple app icon for RouteGuard, a secure route-checking utility.
Seed: 830271.
Style: saturated royal-blue full square field with one centered white shield-like badge and one same-blue clean check-cut.
Subject: a white rounded shield badge with a bold same-blue rounded check-cut across the center, preserving the broad badge-and-cut rhythm without adding document tabs, page folds, letters, complex route glyphs, or extra symbols.
Composition: centered badge, about 60 percent of canvas width and height, generous blue margin, check-cut travels from lower-left toward upper-right with one simple bend.
Palette/material: two-color flat vector style; royal-blue field, pure white badge, same-blue cut matching the background exactly; crisp SVG-friendly geometry.
Layering: background plus clean SVG badge/cut geometry. No transparent holes, masks, clipPaths, carved alpha, or raster fallback.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at 64px.
No text, watermark, brand logo, document tab, folded page corner, alphabet letter, copied reference contour, complex zigzag, gradients, shadows, bevels, glass, glow, stroke outlines, tiny details, UI elements, or photographic detail.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 830271,
  "priority": "produce a two-color flat badge icon with a simple check-cut that can be rebuilt as semantic SVG",
  "conversion_policy": "The normal route is separate opaque SVG layers for the badge and same-color cut/check. If the selected generated cut touches the badge edge and a component-level trace is cleaner, preserve the white visible badge as one compound SVG path. Do not use PNG fallback for this style.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "RouteGuard",
      "category": "secure route-checking utility",
      "job_to_be_done": "make route checks feel fast, clear, and protected",
      "tone": "clean, confident, simple, iconic"
    },
    "style": {
      "direction": "blue-field-cutout-badge",
      "svg_convertibility": "high",
      "style_notes": "saturated solid field, centered white geometric badge, one same-color diagonal check-cut, strict two-color flat vector grammar"
    },
    "icon_intent": {
      "metaphor": "a protected badge confirmed by a simple check-cut gesture",
      "small_size_readability": "must remain clear at 64x64 as one white badge and one diagonal check-cut",
      "must_feel_like": ["minimal", "confident", "utility", "protected"],
      "must_not_feel_like": ["document app", "brand copy", "lettermark", "glossy", "3D", "busy UI"]
    },
    "layering_policy": {
      "negative_space_strategy": "same-color geometry; separate overlay by default, compound white path allowed after selection",
      "cutouts_are_layers": true,
      "description": "The blue check-cut should match the field color. Prefer an opaque overlay; when the selected concept is cleaner as one white visible badge path, keep the negative space as a compound SVG conversion exception."
    },
    "subject_topology": {
      "type": "single centered white badge with same-color diagonal check-cut",
      "primary_parts": [
        "white-visible-badge: one centered shield-like white SVG component with a simple same-blue check-cut negative space",
        "or white-badge + color-cut-overlay: separate SVG layers when the cut/check can be authored cleanly without drifting"
      ],
      "silhouette_rejects": [
        "copied reference contour",
        "document tab",
        "folded page corner",
        "alphabet letter",
        "complex zigzag",
        "window details",
        "multiple small symbols",
        "thin strokes"
      ]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": { "width_pct": [0.54, 0.64], "height_pct": [0.52, 0.64] },
      "safe_area": { "x": [120, 900], "y": [120, 900] },
      "alignment": "centered shield-like badge with a simple check-cut spanning most of the badge width"
    },
    "background": {
      "type": "solid",
      "color": "#023CEC",
      "gradient_stops": [],
      "composer_fill_target": { "solid": "extended-srgb:0.008 0.235 0.925 1" }
    },
    "layers": [
      {
        "id": "white-visible-badge",
        "order": 1,
        "role": "main badge with check-cut negative space",
        "format_target": "svg",
        "shape_model": "single filled compound shield-like badge path",
        "description": "one centered white shield-like badge whose visible shape preserves a simple same-blue check-cut",
        "fill": "#FFFFFF",
        "bounds": { "x": [190, 835], "y": [125, 890] },
        "geometry_constraints": ["crisp boundary", "flat fill", "simple shield-like silhouette", "simple check-cut negative space", "no stroke", "no gradient", "no shadow"],
        "must_preserve": ["one large white badge", "simple check-cut", "centered composition", "readable at 64px"],
        "must_not_add": ["document tab", "folded page corner", "window", "letter", "extra symbol", "bevel"]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "1-2 foreground SVG layer groups plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "compound path"],
      "forbidden_in_svg_assets": ["text", "image", "filter", "gradient", "opacity", "mask", "clipPath", "shadow", "glow", "blur", "texture"],
      "png_fallback_allowed_only_for": ["none in normal route"]
    }
  }
}
```
