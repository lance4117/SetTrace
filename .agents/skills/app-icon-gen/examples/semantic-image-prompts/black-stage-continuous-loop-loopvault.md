# black-stage-continuous-loop-loopvault

Use this for a premium tool, fitness, membership, mobility, website-builder, or utility app where the result should feel like a thick rounded connected glyph: custom bracket-like geometry, controlled inner gaps, strong negative space, and one optional accent.

This is the reusable version of the thick connected-glyph style. It should not name or copy any third-party brand mark. Avoid prompting it as an infinity loop; that wording makes the image model collapse into generic infinity symbols. The legacy `black-stage` name does not mean the background must be black: black is the default premium route, while high-saturation blue, red, green, magenta, orange, or another app-specific single-hue stage is allowed when it improves the app identity.

Expected source-layer mapping:

- background -> `icon.json.fill` solid near-black by default, or a vivid single-hue solid/same-hue stage when the app calls for it
- `primary-glyph` -> one SVG filled thick rounded connected glyph path
- `inner-gap-cover` -> one background-colored SVG overlay shape
- `accent-state` -> one small high-saturation SVG rounded square

For vivid blue or similarly saturated stages, the preferred rendered product is often not a flatter local preview. Keep the source SVG assets flat, then use Icon Composer group settings for the material response: a two-stop same-hue `linear-gradient` fill, `features: ["refractivity"]`, `blur-material: 0.5`, `refractivity` enabled at `strength: 0.4` and `depth: 0.4`, `translucency` enabled at `value: 0.5`, and neutral `shadow`. Do not request these as baked shadows, bevels, glows, or rim strokes in the generated image.

## Style Family Template

```text
Square source artwork for an Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: high-contrast app icon stage with one thick pure-white rounded connected glyph; the stage can be premium black or a vivid single-hue app color.
Subject: one app-specific thick connected glyph based on {paired bracket glyph / mirrored handle glyph / single-piece double-counter connector / soft capsule bridge glyph / route connector / app-specific monoline slab mark}; use broad slab-like strokes, large smooth turns on the glyph itself, open terminals or offset inner gaps. It must not read as an infinity symbol, two separate chain links, heart, lowercase e, G, C, or copied brand mark.
Composition: {center / slightly lower-center}, with two substantial masses or passes connected by a controlled bridge; keep the glyph 52-70% of the canvas and the ribbon thickness visually heavy.
Palette/material: {solid near-black / high-saturation cobalt blue / vivid red / saturated green / hot pink / orange / app-specific solid or same-hue gradient stage}; pure-white or very pale foreground. If the stage is vivid, omit the accent by default so the background carries the color; if an accent is used, it must be small, vivid, and clean, not gray, ochre, amber, or yellowed.
Layering: any apparent cutout, counter, crossing gap, terminal gap, or inner separation should read as a separate opaque background-colored overlay shape, not a transparent carved hole.
Canvas: full square 1024x1024 source artwork with the stage extending to every edge; do not draw a rounded-square app mask, outer border, rim, frame, corner crop, or white corner artifacts. Platform rounded corners will be applied later by the packaging/preview pipeline.
Quality: premium app icon source, strong silhouette, clean negative space, readable at small size.
No text, watermark, infinity symbol, exact brand loop, chain link, heart, readable letter, thin outline, tiny UI detail, shadow, glow, bevel, outer frame, rounded-square border, or extra symbols.
```

## Variant Axes

- Glyph topology: paired bracket glyph, mirrored handle glyph, single-piece double-counter connector, soft capsule bridge glyph, route connector, monoline slab mark.
- Composition: centered for identity marks; slightly lower-center when the loop should feel grounded.
- Stage palette: solid black by default, but not fixed. High-saturation cobalt blue, vivid red, saturated green, hot pink, orange, or another app-specific solid/same-hue gradient stage is allowed when it fits the app category. Keep gradients same-hue and low-to-medium contrast; do not use rainbow or high-contrast multi-hue blends.
- Foreground material: flat pure white by default; very subtle white-to-pale tonal depth is allowed only when broad and clean.
- Accent: none by default on vivid stages; on black/dark stages, optional high-saturation state square, tiny dot, or short app-specific marker. Prefer electric red, hot pink, vivid cyan, saturated blue, or neon green over amber/orange.
- Drift guard: explicitly reject infinity, two separate chain links, heart, and readable letters in the first-pass prompt.

## Template Conversion Flow

Default route: one continuous semantic SVG path or clean-mask `potrace` retrace. This template is stable enough that the connected foreground should never be split into color patches.

- Build `source_analysis.components[]` around one `primary-loop` component, overlay-created gaps/counters, and one optional vivid accent.
- If retracing, threshold the connected glyph as a single foreground mask, test multiple strengths under `tmp/work/`, and keep the candidate that preserves continuity, terminal shape, and overlay gaps.
- Recolor the main loop from the semantic contrast rule: pure white on dark/high-saturation stages or pure black on light stages. Recolor the accent to a vivid app-appropriate color.
- For the vivid cobalt-blue route, set the production `.icon` fill and group material settings in the author spec, while keeping local source layers and `.icon/Assets/*.svg` flat. Use the local preview/reference comparison for geometry and broad palette; use `ictool` Apple exports to inspect the rendered Liquid Glass product.
- Reject any conversion that turns the loop into unrelated fragments, keeps sampled cream/yellow antialiasing, creates an accidental infinity logo, or imports material highlights as SVG layers.

## Example Instantiation (Not A Default)

```text
Square source artwork for an Apple app icon for LiftLink, a workout tracker and gym log.
Seed: 628471.
Style: flat near-black stage with one thick pure-white rounded connected glyph.
Subject: a paired bracket glyph inspired by workout handles: two upright rounded rectangular masses connected by one controlled central S-bridge, centered, substantial, not an infinity symbol and not a readable letter.
Palette/material: solid black field, pure-white foreground, no accent.
Layering: any apparent cutout, counter, crossing gap, terminal gap, or inner separation should read as a separate opaque background-colored overlay shape, not a transparent carved hole.
Canvas: full square 1024x1024 source artwork with black field to every edge; no rounded-square app mask, outer border, rim, frame, corner crop, or white corner artifacts.
Quality: premium app icon source, strong silhouette, clean negative space, readable at small size.
No text, watermark, infinity symbol, exact brand loop, chain link, heart, readable letter, thin outline, shadow, glow, bevel, outer frame, rounded-square border, or extra symbols.
```

## Example Conversion Contract (Adapt After Selection)

```json
{
  "task": "generate_app_icon_reference",
  "generation_seed": 628471,
  "priority": "produce a reference image that can be rebuilt as semantic SVG layers",
  "conversion_policy": "All apparent cutouts, counters, gaps, stripes, or negative-space details must be rendered as separate opaque overlay layers following semantic_icon_design.layering_policy; never as transparent holes, masks, clipPaths, alpha cutouts, or carved geometry.",
  "semantic_icon_design": {
    "version": "semantic-icon-design/v0.1",
    "route": "concept-to-package",
    "app_context": {
      "app_name": "LiftLink",
      "category": "workout tracker and gym log",
      "job_to_be_done": "show controlled strength tracking through a bold connected handle-like mark",
      "tone": "premium, strong, focused, technical"
    },
    "style": {
      "direction": "black-stage-continuous-loop",
      "svg_convertibility": "high",
      "style_notes": "flat near-black stage, one thick pure-white rounded connected glyph, controlled inner gaps expressed as overlays, no infinity symbol"
    },
    "icon_intent": {
      "metaphor": "connected workout handles",
      "small_size_readability": "must remain clear at 64x64",
      "must_feel_like": ["strong", "connected", "premium", "controlled"],
      "must_not_feel_like": ["infinity symbol", "chain link pair", "brand logo copy", "lowercase e", "letter G", "letter C", "single spiral", "heart logo", "3D glass badge"]
    },
    "layering_policy": {
      "negative_space_strategy": "overlay-fill-layer",
      "cutouts_are_layers": true,
      "description": "Internal gaps and counters are near-black opaque overlay shapes placed above the pure-white glyph. Do not request transparent holes or boolean subtraction."
    },
    "subject_topology": {
      "type": "single thick rounded connected-glyph emblem",
      "primary_parts": [
        "primary-glyph: thick pure-white rounded connected glyph with left upright bracket mass, right upright bracket mass, and one central S-bridge; it must not read as infinity, a chain link pair, lowercase e, G, or C",
        "inner-gap-cover: background-colored overlay shapes that create the apparent internal gaps and terminal separations, not true holes"
      ],
      "silhouette_rejects": [
        "infinity symbol",
        "chain link pair",
        "readable letter",
        "lowercase e",
        "letter G",
        "letter C",
        "single spiral curl",
        "heart logo",
        "exact brand loop",
        "thin outline",
        "multiple interlocking loops"
      ]
    },
    "canvas": {
      "size": 1024,
      "composition_anchor": "center",
      "subject_scale": {
        "width_pct": [0.52, 0.66],
        "height_pct": [0.48, 0.62]
      },
      "safe_area": {
        "x": [190, 834],
        "y": [190, 834]
      },
      "alignment": "centered, balanced, two upright masses connected by one central bridge"
    },
    "background": {
      "type": "solid_or_same_hue_gradient",
      "color": "#050609",
      "gradient_stops": [],
      "composer_fill_target": {
        "solid": "extended-srgb:0.020 0.024 0.035 1",
        "blue_liquid_glass_variant": {
          "linear-gradient": [
            "extended-srgb:0.00392,0.34902,0.99608,1.00000",
            "extended-srgb:0.00000,0.40784,0.99216,1.00000"
          ],
          "orientation": {
            "start": { "x": 0.5, "y": 1 },
            "stop": { "x": 0.5, "y": 0 }
          }
        }
      }
    },
    "icon_composer_material_target": {
      "use_when": "vivid blue or similarly saturated stage needs a richer Apple-rendered product",
      "source_asset_rule": "keep .icon/Assets SVGs as flat base geometry; do not bake shadow, glow, bevel, or refraction into source SVG paths",
      "features": ["refractivity"],
      "group": {
        "blend-mode": "normal",
        "blur-material": 0.5,
        "lighting": "individual",
        "refractivity": {
          "enabled": true,
          "strength": 0.4,
          "depth": 0.4
        },
        "shadow": {
          "kind": "neutral",
          "opacity": 0.4
        },
        "translucency": {
          "enabled": true,
          "value": 0.5
        }
      },
      "layer": {
        "blend-mode": "normal",
        "fill": "automatic"
      }
    },
    "layers": [
      {
        "id": "primary-glyph",
        "order": 1,
        "role": "main thick connected glyph",
        "format_target": "svg",
        "shape_model": "single filled thick rounded connected glyph path",
        "description": "pure-white connected glyph with thick rounded slab geometry, left upright bracket mass, right upright bracket mass, and one controlled central bridge; not an infinity symbol, chain link pair, lowercase e, G, C, or existing brand mark",
        "fill": "#FFFFFF",
        "bounds": {
          "x": [140, 880],
          "y": [210, 800]
        },
        "geometry_constraints": [
          "fully opaque fill",
          "crisp hard boundary",
          "visual ribbon thickness around 12-20 percent of canvas width",
          "large smooth radius turns",
          "paired bracket or connected-glyph topology remains visible",
          "open terminals or offset internal gaps are allowed",
          "not an infinity symbol",
          "not a chain link pair",
          "no single spiral curl",
          "no stroke",
          "no opacity",
          "no shadow",
          "no bevel",
          "no glow"
        ],
        "must_preserve": [
          "single thick connected glyph",
          "paired upright masses",
          "controlled central bridge",
          "strong internal gaps",
          "balanced black negative space",
          "rounded premium terminals"
        ],
        "must_not_add": [
          "infinity symbol",
          "chain link pair",
          "brand logo",
          "readable letter",
          "lowercase e",
          "letter G",
          "letter C",
          "single spiral",
          "heart outline",
          "extra loop",
          "thin line",
          "rim highlight"
        ]
      },
      {
        "id": "inner-gap-cover",
        "order": 2,
        "role": "background-colored gap overlay",
        "format_target": "svg",
        "shape_model": "rounded gap overlay",
        "description": "near-black rounded overlays placed above the glyph to create apparent internal gaps, counters, and terminal separations as separate opaque layers",
        "fill": "#050609",
        "bounds": {
          "x": [245, 780],
          "y": [310, 710]
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
          "gaps are overlays, not transparent holes"
        ],
        "must_not_add": [
          "inner shadow",
          "bevel",
          "soft recessed edge",
          "transparent gap"
        ]
      }
    ],
    "conversion_constraints": {
      "target_layer_count": "2-3 foreground layers plus background",
      "svg_first": true,
      "allowed_svg_primitives": ["filled path", "polygon", "rounded rectangle"],
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
      "png_fallback_allowed_only_for": ["strict-fidelity"]
    },
    "image_generation_constraints": {
      "must": [
        "flat black stage",
        "one pure-white thick connected glyph",
        "clear overlay-created internal gaps",
        "large readable silhouette"
      ],
      "avoid": [
        "infinity symbol",
        "chain link pair",
        "existing logo or brand mark",
        "readable letter",
        "lowercase e",
        "letter G",
        "letter C",
        "single spiral curl",
        "heart logo",
        "thin outline",
        "3D rendering",
        "bevel",
        "rim light",
        "drop shadow",
        "glow",
        "extra symbols",
        "text",
        "muted accent",
        "gray accent",
        "amber accent",
        "yellowed orange accent"
      ]
    }
  }
}
```
