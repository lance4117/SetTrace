# glass-ribbon-filterwave

Use this for a camera, video, filter, color-grading, music-visual, or creative tool where the app identity can be carried by separated curved color-panel panes on a black stage.

This is not a waveform style. The stable grammar is a black background, one large pale slender curved pane, and 5-6 smaller colored slender curved panes arranged as separate floating panes. Keep the attractive Dazz-like pane language: long leaf-like arcs, boomerang panes, smooth Bezier outer contours, soft rounded tapered ends, crisp borderless silhouettes, single continuous pane color, no internal bands or seams, and no raised edge treatment. Do not turn it into audio bands, stacked waves, equalizer strips, continuous rainbow ribbon, broad triangular tiles, hard clipped terminals, flat chopped ends, or angular polygon cuts.

Expected source-layer mapping:

- background -> `icon.json.fill` solid near-black
- `main-pale-pane` -> one large SVG/PNG curved pane path
- `color-pane-*` -> independent SVG/PNG curved pane paths

## Style Family Template

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: flat black stage with separated curved flat color-panel panes.
Subject: one app-specific cluster of {6 / 7} independent smooth rounded slender curved panes based on {camera filter panes / color grading fragments / creative lens panes / media prism panes / layered visual effects}; include one large pale main pane and 5-6 vivid colored side panes.
Composition: {diagonal rising cluster / loose orbital fan / crescent cluster / scattered lens-prism cluster}; every pane is a separate long curved leaf-like pane with a smooth Bezier outer contour, soft rounded tapered ends, and visible black gaps between panes. Avoid horizontal waveform layouts, broad triangular/kite tiles, and hard clipped terminals.
Palette/material: black background; one dominant white or pale pane; vivid yellow, green, cyan, blue, coral, magenta, or app-specific colored panes. Each pane must read as one continuous solid flat fill with no visible internal boundary; the silhouette must stay flat and borderless.
Layering: panes are independent opaque flat layers. Any apparent overlap gap or separation should be visible black background between layers, not a transparent carved hole.
Quality: premium App Store icon, creative, luminous, crisp, readable at small size, SVG-friendly pane silhouettes.
No text, watermark, audio waveform, equalizer, stacked waves, continuous ribbon, broad triangular tile, kite tile, trapezoid tile, camera lens, copied source arrangement, tiny confetti, hard clipped terminal, flat chopped end, straight cut corner, angular polygon cut, sharp pointed tip, internal seam, internal band, curved interior division, crescent-shaped interior division, two-tone section, secondary shape inside a pane, border, outline, stroke, rim, edge line, edge highlight, sidewall, glow, bright white shine streaks, plastic shine, gel bevel, or extra symbols.
```

## Variant Axes

- Pane metaphor: camera filter panes, color grading fragments, creative lens panes, media prism panes, layered visual effects.
- Dominant pane: large pale white pane, large brand-color pane, or large central solid-color pane.
- Pane count: 6 or 7 total foreground panes including the dominant pane.
- Layout: diagonal rising cluster, loose orbital fan, crescent cluster, scattered lens-prism cluster.
- Pane shape: smooth rounded slender curved leaf pane, boomerang pane, tapered crescent pane with rounded ends, curved wedge pane with no hard-clipped terminals.
- Material: luminous flat color pane with one continuous solid fill. Forbid hard clipped terminals, flat chopped ends, straight cut corners, angular polygon cuts, internal seam, internal band, curved interior division, crescent-shaped interior division, two-tone section, secondary shape inside a pane, border, outline, stroke, rim, edge line, edge highlight, sidewall, specular streaks, plastic highlights, gel bevels, glow, and blur.
- Drift guard: do not use words like `waveform`, `audio bands`, `equalizer`, `stacked waves`, or `sound spectrum` unless the user explicitly wants an audio icon.

## Template Conversion Flow

Default route: hybrid semantic pane layers. Each pane is one component; pane color is authored as a solid fill. Never vectorize internal pane color into multiple bands, secondary shapes, or dirty color patches.

- Build `source_analysis.components[]` with one entry per pane. Keep the large pale pane and each colored pane independent.
- Prefer direct SVG pane paths when the silhouettes are simple. If a pane silhouette needs tracing, isolate that pane by region/color, run clean mask candidates, trace only the smooth rounded outer pane shape, and assign a spec-authored solid fill.
- Allow PNG fallback only per pane when the isolated pane has clean transparent edges and no visible internal seam or band. Do not use one full foreground PNG or a full rendered icon.
- Reject waveform/equalizer layouts, broad triangular tiles, hard clipped terminals, flat chopped ends, angular polygon cuts, internal seam/band/division treatment, border/outline/rim/sidewall treatment, plastic highlights, glow, blur, palette-quantized interior chunks, and traced gray/green residue inside a pane.

## Example Instantiation (Not A Default)

```text
Apple app icon for FilterPane, a creative camera filter and color grading tool.
Seed: 640372.
Style: flat black stage with separated curved flat color-panel panes.
Subject: one large white smooth rounded slender curved pane sweeping upward through the center, surrounded by six independent colored smooth rounded slender curved panes: yellow upper-left, green upper-center, magenta left, teal lower-left, blue right, coral lower-right. Each pane is a long tapered curved leaf-like pane with soft rounded tapered ends, not a wave strip, hard-clipped piece, or triangular tile.
Composition: loose diagonal prism cluster with black gaps between every pane; no horizontal waveform, no equalizer, no stacked waves.
Palette/material: black background, white main pane, vivid yellow, green, magenta, teal, blue, and coral panes; each pane is one continuous solid flat fill with no visible internal boundary, with flat borderless outer silhouettes.
Layering: panes are separate opaque flat layers. Any gap or separation is visible black background between panes, not a transparent carved hole.
Quality: premium App Store icon, crisp pane silhouettes, luminous creative color, readable at 64px.
No text, watermark, audio waveform, equalizer, stacked waves, continuous ribbon, broad triangular tile, kite tile, trapezoid tile, camera lens, tiny confetti, hard clipped terminal, flat chopped end, straight cut corner, angular polygon cut, sharp pointed tip, internal seam, internal band, curved interior division, crescent-shaped interior division, two-tone section, secondary shape inside a pane, border, outline, stroke, rim, edge line, edge highlight, sidewall, glow, bright white shine streaks, plastic shine, gel bevel, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 640372,
  "priority": "produce a reference image that can be rebuilt as semantic SVG or clean PNG pane layers without pane-internal seams or hard clipped terminals",
  "conversion_policy": "All panes must be separate named layers. Any apparent gaps, separations, or negative-space details must be visible background between independent layers or separate opaque overlay layers; never as masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "FilterPane",
      "category": "creative camera filters and color grading tool",
      "job_to_be_done": "show color filters as controllable flat color panes",
      "tone": "premium, creative, vivid, precise"
    },
    "style": {
      "direction": "flat-color-rounded-pane-cluster",
      "svg_convertibility": "low",
      "style_notes": "flat black stage, separated smooth rounded slender curved flat color-panel panes, one large pale pane, six colored panes, soft rounded tapered ends, no internal seams, no waveform, audio-band, or triangular-tile layout"
    },
    "icon_intent": {
      "metaphor": "creative color panes",
      "small_size_readability": "must remain clear at 64x64 as separated curved panes on black",
      "must_feel_like": ["creative", "premium", "luminous", "controlled"],
      "must_not_feel_like": ["audio waveform", "equalizer", "stacked waves", "rainbow logo", "camera lens", "paint splash", "plastic gel icon", "segmented pane", "two-tone cutout", "hard clipped panes", "angular polygon pieces"]
    },
    "layering_policy": {
      "negative_space_strategy": "visible-background-between-layers",
      "cutouts_are_layers": true,
      "description": "Every pane is an independent layer with one continuous fill. Black gaps are the background showing between panes. Do not create masks, clipPaths, transparent holes, soft alpha cutouts, pane-internal seams, or a single continuous ribbon."
    },
    "subject_topology": {
      "type": "separated smooth rounded slender curved flat color-panel pane cluster",
      "primary_parts": [
        "main-pale-pane: largest white smooth rounded slender curved tapered pane, rising diagonally through the center",
        "color-pane-yellow: small yellow smooth rounded slender curved pane at upper-left",
        "color-pane-green: large green smooth rounded slender curved pane near upper-center",
        "color-pane-magenta: small magenta smooth rounded slender curved pane on the left",
        "color-pane-teal: medium teal smooth rounded slender curved pane near lower-left",
        "color-pane-blue: medium blue smooth rounded slender curved pane on the right",
        "color-pane-coral: small coral smooth rounded slender curved pane at lower-right"
      ],
      "silhouette_rejects": [
        "horizontal waveform",
        "audio-band stack",
        "equalizer",
        "continuous rainbow ribbon",
        "broad triangular tile",
        "kite tile",
        "trapezoid tile",
        "lens circle",
        "flower",
        "paint splatter",
        "many tiny confetti pieces",
        "pane-internal curved band",
        "pane-internal crescent division",
        "two-tone pane section",
        "hard clipped terminal",
        "flat chopped end",
        "straight cut corner",
        "angular polygon cut",
        "sharp pointed tip"
      ]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.66, 0.82],
        "height_pct": [0.66, 0.82]
      },
      "safe_area": {
        "x": [110, 900],
        "y": [110, 900]
      },
      "alignment": "loose diagonal prism cluster, centered, with black gaps between all smooth rounded slender curved panes"
    },
    "background": {
      "type": "solid",
      "color": "#050607",
      "gradient_stops": [],
      "gradient_policy": {
        "applies": false,
        "reason": "flat black stage keeps color panes separable"
      },
      "composer_fill_target": {
        "solid": "extended-srgb:0.020 0.024 0.027 1"
      }
    },
    "shared_pane_constraints": [
      "one independent smooth rounded slender curved tapered pane path",
      "long leaf-like arc or boomerang silhouette",
      "smooth Bezier leaf-like outer contour",
      "soft rounded tapered ends",
      "crisp outer boundary",
      "one continuous solid flat fill",
      "no visible internal boundary",
      "no internal seam",
      "no internal band",
      "no crescent-shaped interior division",
      "no two-tone section",
      "no secondary shape inside the pane",
      "flat borderless outer silhouette",
      "no darker edge",
      "no rim",
      "no sidewall",
      "no outline",
      "no stroke",
      "no hard clipped terminal",
      "no flat chopped end",
      "no straight cut corner",
      "no angular polygon cut",
      "no sharp pointed tip",
      "no long white specular streak",
      "no plastic shine",
      "no gel bevel",
      "no glow",
      "no drop shadow",
      "no blur",
      "no continuous waveform strip",
      "no broad triangular/kite/trapezoid tile"
    ],
    "layers": [
      {
        "id": "main-pale-pane",
        "order": 1,
        "role": "largest pale pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "large smooth rounded slender curved tapered pane path",
        "description": "largest white smooth rounded slender curved pane sweeping upward through the center with soft rounded tapered ends, broad enough to lead but still leaf-like and separate from all colored panes",
        "fill": "#F7F7F4",
        "bounds": {
          "x": [250, 675],
          "y": [180, 805]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no specular streak", "no plastic shine"],
        "must_preserve": ["largest central pale pane", "diagonal upward sweep", "separate black gaps"],
        "must_not_add": ["waveform teeth", "audio peaks", "lens circle", "continuous ribbon", "triangular tile", "kite tile"]
      },
      {
        "id": "color-pane-yellow",
        "order": 2,
        "role": "upper-left yellow pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "small smooth rounded slender curved tapered pane path",
        "description": "small yellow smooth rounded slender curved pane at upper-left with soft rounded tapered ends, separated from all other panes",
        "fill": "#F8EA00",
        "bounds": {
          "x": [180, 470],
          "y": [125, 330]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous yellow fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no shine streak", "no glow"],
        "must_preserve": ["upper-left placement", "separate small pane"],
        "must_not_add": ["sparkle", "extra yellow fragments", "text"]
      },
      {
        "id": "color-pane-green",
        "order": 3,
        "role": "upper green pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "large smooth rounded slender curved tapered pane path",
        "description": "large green smooth rounded slender curved pane near upper-center with soft rounded tapered ends, angled diagonally and separated by black gaps",
        "fill": "#26E36E",
        "bounds": {
          "x": [355, 700],
          "y": [135, 505]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous green fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no shine streak", "no glow"],
        "must_preserve": ["large green pane", "upper position", "black gap from main pane"],
        "must_not_add": ["wave strip", "triangular tile", "transparent smear", "plastic highlight"]
      },
      {
        "id": "color-pane-magenta",
        "order": 4,
        "role": "left magenta pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "small smooth rounded slender curved tapered pane path",
        "description": "small magenta smooth rounded slender curved pane on the left with soft rounded tapered ends, supporting the diagonal cluster without forming a wave",
        "fill": "#C3488B",
        "bounds": {
          "x": [120, 360],
          "y": [315, 515]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous magenta fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no shine streak", "no glow"],
        "must_preserve": ["left-side magenta pane", "separate readable silhouette"],
        "must_not_add": ["extra purple fragments", "soft transparent smear", "text"]
      },
      {
        "id": "color-pane-teal",
        "order": 5,
        "role": "lower-left teal pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "medium smooth rounded slender curved tapered pane path",
        "description": "medium teal smooth rounded slender curved pane near lower-left with soft rounded tapered ends, broad enough to read at small size but still leaf-like",
        "fill": "#00A99A",
        "bounds": {
          "x": [170, 480],
          "y": [490, 690]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous teal fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no shine streak", "no glow"],
        "must_preserve": ["lower-left teal pane", "broad simple silhouette"],
        "must_not_add": ["audio band", "waveform strip", "triangular tile", "blurred tail"]
      },
      {
        "id": "color-pane-blue",
        "order": 6,
        "role": "right blue pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "medium smooth rounded slender curved tapered pane path",
        "description": "medium blue smooth rounded slender curved pane on the right side with soft rounded tapered ends, separate from the pale pane and angled like a lens pane",
        "fill": "#1E63F0",
        "bounds": {
          "x": [605, 860],
          "y": [350, 680]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous blue fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no shine streak", "no glow"],
        "must_preserve": ["right-side blue pane", "black gap from main pane"],
        "must_not_add": ["extra blue pieces", "lens circle", "plastic highlight"]
      },
      {
        "id": "color-pane-coral",
        "order": 7,
        "role": "lower-right coral pane",
        "format_target": "svg_or_clean_png",
        "shape_model": "small smooth rounded slender curved tapered pane path",
        "description": "small coral smooth rounded slender curved pane at lower-right with soft rounded tapered ends, balancing the yellow pane",
        "fill": "#EF6256",
        "bounds": {
          "x": [705, 870],
          "y": [565, 820]
        },
        "geometry_constraints": ["crisp boundary", "smooth Bezier outer contour", "soft rounded tapered ends", "single continuous coral fill", "no visible internal boundary", "no internal seam", "no internal band", "no crescent-shaped interior division", "no two-tone section", "no secondary shape inside the pane", "flat borderless outer silhouette", "no hard clipped terminal", "no flat chopped end", "no straight cut corner", "no angular polygon cut", "no sharp pointed tip", "no darker edge", "no rim", "no sidewall", "no outline", "no stroke", "no shine streak", "no glow"],
        "must_preserve": ["lower-right coral pane", "separate silhouette"],
        "must_not_add": ["sparkle", "extra coral pieces", "text"]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "7 foreground panes plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path"],
      "forbidden_in_svg_assets": [
        "text",
        "image",
        "filter",
        "clipPath",
        "mask",
        "stroke",
        "border",
        "outline",
        "rim",
        "edge line",
        "edge highlight",
        "sidewall",
        "drop shadow",
        "glow",
        "blur",
        "long specular highlight",
        "white shine streak",
        "plastic shine",
        "gel bevel",
        "soft unclear boundary",
        "hard clipped terminal",
        "flat chopped end",
        "straight cut corner",
        "angular polygon cut",
        "sharp pointed tip",
        "boolean hole",
        "alpha cutout"
      ],
      "png_fallback_allowed_only_for": ["strict-fidelity-flat-pane"]
    },
    "image_generation_constraints": {
      "must": [
        "flat near-black stage",
        "one large pale smooth rounded slender curved pane",
        "six separated colored smooth rounded slender curved panes",
        "smooth rounded leaf-like pane silhouettes",
        "soft rounded tapered ends",
        "smooth Bezier-like outer contours",
        "flat borderless outer silhouettes",
        "single continuous fill inside each pane",
        "crisp clean boundaries",
        "clear black gaps between panes"
      ],
      "avoid": [
        "audio waveform",
        "equalizer",
        "stacked waves",
        "sound spectrum",
        "continuous rainbow ribbon",
        "broad triangular tile",
        "kite tile",
        "trapezoid tile",
        "lens",
        "camera body",
        "hard clipped terminal",
        "flat chopped end",
        "straight cut corner",
        "angular polygon cut",
        "sharp pointed tip",
        "internal seam",
        "internal band",
        "curved interior division",
        "crescent-shaped interior division",
        "two-tone section",
        "secondary shape inside a pane",
        "border",
        "outline",
        "stroke",
        "rim",
        "edge line",
        "edge highlight",
        "sidewall",
        "glow",
        "long white shine streak",
        "plastic shine",
        "gel bevel",
        "tiny confetti",
        "paint splatter",
        "drop shadow",
        "text",
        "watermark"
      ]
    }
  }
}
```
