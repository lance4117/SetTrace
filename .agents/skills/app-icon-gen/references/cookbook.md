# Cookbook

Use this after source discovery when the route is unclear. It is a pattern router, not a template library. Pick the closest recipe, write a source-specific `source_analysis`, then author the JSON spec normally.

Do not copy recipe wording into every spec. The recipe only decides the first route, the main risks, and the verification focus.

## Route Table

| Source pattern | First route | Avoid | Verify |
| --- | --- | --- | --- |
| Simple flat symbol or letter on solid background | `icon.json.fill` plus one clean SVG foreground | PNG fallback, fake material, platform frame | overlay/diff, SVG material warnings, source-analysis semantics |
| Continuous connected logo, letterform, ribbon, knot, or monogram | one foreground SVG path or compound path | splitting into rectangles, patches, or fake Icon Composer layers | seams, negative space, terminals, geometry audit |
| Geometric brand-like mark with circles, rings, stars, triangles, or hard straight edges | manual semantic SVG geometry from local measurements | public SVG substitution, auto-trace noise, unnecessary smoothing | row/column sampling, overlay, honest `review_required` if bitmap-only |
| Smooth loop, chain, handset, plate, or multi-part colored mark | component-level segmentation/vectorization or semantic curves | full-icon PNG, external vector replacement, dirty masks | component coverage, layer order, geometry audit, local samples |
| Separable foreground components on a simple or mostly separable background | one clean SVG/base layer per real component plus `icon.json.fill` or a deliberate background route | chasing rendered material with fake highlights, full-icon PNG, splitting one component into rim/interior helper layers | `shape-facts` summary, interior component/scanline drift, overlay, material boundary |
| Rendered glass, bevel, shadow, glow, or Liquid Glass reference | clean base SVG/clean authored PNG layers; preview stays clean when the reference is an Icon Composer/platform export | baking highlight strokes, bevels, shadows, glows, or source-cut material into preview or `.icon/Assets` | material provenance, `svg_material_warnings`, isolated assets, reviewed semantic delta |
| Overlapping translucent plates or stacked panels | separate semantic SVG layers in bottom-to-top spec order | wrong `icon.json` display order, flattened PNG, hidden rear layer | generated `icon.json` front-to-back order and Quick Look/preview behavior |
| Repeated slanted rounded panels, bars, or tiles | one clean semantic SVG path per real panel, with continuous corner curves | pieced-together corners, duplicated rim paths, over-smoothing hard edges | enlarged preview, tangent continuity, overlay, geometry audit |
| Text, labels, or wordmarks | faithful outlines, or render text layer to clean PNG with font/render notes | importing `<text>` in `.icon/Assets/*.svg`, hand-drawn inaccurate letters | Icon Composer text warning, font fidelity, layer PNG cleanliness |
| Dense illustration, mascot, detailed brand artwork, or inseparable raster art | request/seek owned source vector, clean per-layer PNG fallback, or accepted approximation | pretending trace SVG is semantic, over-vectorizing fragments | `png_fallback_evidence`, isolated PNG cleanliness, semantic review |
| Complex background with real artwork | imported background-like layer marked as complex | forcing 3+ stop `icon.json.fill`, treating background as foreground residue | fill/background consistency and `.icon` openability |
| Existing `.icon` bundle refinement | inspect `icon.json` and every asset before changing anything | rebuilding from screenshot first, losing existing fill/layer settings | layer order, fill, asset hygiene, package verification |

## Recipes

### Simple Flat Symbol

Use for minimal white/black symbols, utility marks, simple dots, rays, and plain letter-like marks.

- Put the background in `icon.json.fill`.
- Keep a local background layer for preview comparison with `composer.include: false`.
- Use one SVG foreground when the silhouette is editable and faithful.
- Keep `semantic_review.status` as `exact-enough` only when the mark is original or identity is not sensitive.

Failure trigger: if the foreground becomes PNG only to reduce mean delta, switch back to SVG unless there is concrete `png_fallback_evidence`.

### Continuous Connected Mark

Use for one connected silhouette, including letterforms, ribbons, knots, and monograms.

- Treat the whole foreground as one path or compound path.
- Split only when the source has real disconnected pieces, real overlap, or true visual layers.
- If a trace creates stair steps, run `geometry-audit`; try conservative Paper.js polish only as a candidate.
- If polish changes terminals, counters, openings, or negative space, reject the candidate and repair semantic curves manually.

Failure trigger: black slivers, seams, patch corners, or local rectangle edges usually mean the mark was split incorrectly.

### Geometric Brand-Like Mark

Use for high-contrast marks built from circles, rings, straight arms, hard angles, or radial symmetry.

- Prefer manual semantic geometry over bitmap trace.
- Use compound paths for rings and holes.
- Keep hard straight edges as line commands when they are intentional; do not smooth just because `geometry-audit` reports high line ratio.
- For a star, arrow, spoke, or multi-arm center, use one continuous filled outline when arms meet; avoid overlapping subpaths that create antialiasing seams.
- If only a bitmap reference is available for a real brand-like identity, set `semantic_review.status: "visually-close"` or another review state instead of `exact-enough`.

Verification focus: use overlay/diff plus temporary row/column interval sampling around endpoints, center joins, and ring thickness. Numeric mean can pass while a center join is semantically wrong.

### Smooth Multi-Component Mark

Use for a few clean foreground pieces on a simple background, such as a curved handset plus a separate panel, two overlapping plates, or three colored shapes.

- Identify real components first; do not trace every color speck.
- Segment/vectorize only the supplied, generated, user-owned, or project-local bitmap.
- Map each component to `source_analysis.components[]`.
- Author fills/gradients in the spec rather than copying rendered material.
- Run `geometry-audit` on traced SVG components and inspect the isolated assets.
- Inspect side-by-side for whether the final curves look intentional. If the trace or hand-authored path reads as hand-drawn, repair the shape model or restore the previous best candidate instead of accepting the cleaner file.

Failure trigger: if vectorization creates many fragments, dirty edges, or ambiguous parts, switch to semantic redraw, clean PNG fallback, or `needs-source-vector`.

### Separable Foreground Components

Use when the reference has a small set of real foreground components on a simple, dark, solid, gradient, or otherwise separable background. Examples include colored pieces, ribbons, plates, swooshes, simple panels, and clean disconnected symbol parts. This is a structural route, not a style template.

- Identify real components first; do not create layers from every highlight, rim, reflection, or color speck.
- Treat each real foreground component as one semantic SVG/base layer when it has a real visual boundary.
- Keep a continuous connected mark as one path or compound path even if thresholding could split it into patches.
- Use `icon.json.fill` for a simple solid or 2-stop gradient background; import a background layer only when it is real artwork.
- Keep foreground layers as base silhouettes with base color or simple gradient only.
- Do not split one component into separate highlight, rim, interior, glow, or shadow helper layers unless the source has a real editable layer boundary.
- If the clean semantic preview looks too flat but the reference shows a real structural edge, page, plate, lip, or underlay, add one base silhouette layer for that structure. Keep it solid or simply filled; do not use strokes, opacity, filters, or glow to imitate material.
- When the reference is a platform/Icon Composer render, expect the production preview to look flatter than the reference.
- Run `shape-facts` with an explicit background color when thresholding can reasonably separate foreground from background, then inspect `comparison.summary` before over-editing path points.
- Prefer `comparison.summary.component_counts.interior_delta` and `comparison.summary.interior_scanline_drift` when app-mask rim lights or canvas-edge artifacts pollute full-canvas scanlines.
- If overlay geometry is close, `.icon/Assets` are clean, and the diff is mostly glass/material, keep the package as a reviewed semantic approximation instead of adding fake material to cross a numeric target.

Failure trigger: the agent lowers mean delta by adding edge glints, bevel strokes, opacity overlays, source-cut PNG pieces, or duplicated rim/helper paths. Remove the material, rerun verification, and record the strict-pixel tradeoff as review evidence.

### Rendered Material Reference

Use when the supplied image looks like final platform output with glass, bevel, glow, edge lighting, or shadow.

- First decide material provenance: generated concept/mockup, or Icon Composer/platform-exported final icon.
- Decide output intent: production `.icon` package by default for Apple/Icon Composer work, rendered presentation mock only when the user explicitly asks for one.
- Treat material as style evidence and verification context.
- Put only clean base geometry and base color in `.icon/Assets`.
- For Icon Composer/platform-exported references, do not recreate the exported rim, glow, bevel, shadow, or Liquid Glass response in preview-only layers. Keep preview focused on clean base shapes and broad fill/color alignment; let overlay/diff show the deferred platform material.
- Accept that the production preview may look flatter than the reference. It should prove base geometry, fill, layer order, and asset cleanliness; it should not become a screenshot replica.
- Use preview-only appearance layers only for loose rendered concepts or presentation mocks where the user asks to see a local rendered approximation; set `composer.include: false`.
- A mean delta in the review range can be acceptable only with explicit semantic acceptance; do not bake material into imported SVGs to cross a numeric target.

Failure trigger: a clean Icon Composer-exported reference causes the agent to add preview-only border/rim/glow layers. Remove those layers and record the material as a deferred platform effect. `svg_material_warnings` means the imported SVG is acting like a rendered screenshot; remove the material before completion.

### Overlapping Plates

Use for translucent panels, offset tiles, cards, or stacked geometric pieces.

- Write spec layers in bottom-to-top visual order.
- Let `author-icon` write `icon.json.groups[].layers` in front-to-back display order.
- Verify that the foremost visual piece appears first in `icon.json`.
- Use opacity only when it is part of the base shape relationship, not as a fake highlight.

Failure trigger: Quick Look or Icon Composer showing the rear layer over the front layer means the generated `.icon` layer order must be checked, not the spec order manually reversed.

### Slanted Rounded Panels

Use for repeated bars, tiles, panes, or panel-like glyph segments with rounded corners and a shared angle.

- Model each real panel as one closed SVG path.
- Use continuous `C` or carefully aligned `Q` curves at rounded corners; avoid tiny straight segments plus multiple curve fragments that create doubled corners.
- Keep intentional straight sides as straight commands. Smooth only the corner transitions that are visibly rough.
- Apply the same geometry rule to all repeated panels in the family; do not repair only the one corner that was noticed first.
- Inspect an enlarged preview before completion. A strict mean pass can still hide kinked corners, tangent breaks, or local doubled rims.

Failure trigger: a panel corner looks like two rounded shapes are stacked, or a slanted bar has a tiny notch/kink at the transition. Rewrite the path as a continuous panel silhouette, then regenerate and verify.

### Text Or Wordmark

Use when the icon contains letters, labels, or a wordmark.

- Do not import live `<text>` into `.icon/Assets/*.svg`.
- Use outlines only when the outline is visually faithful.
- Otherwise render the text layer to a clean PNG and record font family, render method, and why PNG is the right tradeoff.
- Keep text as its own layer unless it is inseparable from a dense raster mark.

Failure trigger: hand-drawn letter approximations that pass mean delta locally but lose the real wordmark shape are semantic failures.

### Clean PNG Fallback

Use only when SVG is unsuitable for that layer or the user accepts a raster tradeoff.

- A clean PNG layer may contain flat color, a linear gradient, text/raster content, a dense brand mark, or deliberate artwork.
- It must not contain source-background residue, hard matte, crop edges, baked glass, glow, shadow, or unrelated highlights.
- Add concrete `png_fallback_evidence` for every non-text foreground PNG fallback.
- Inspect the isolated PNG, not only the final composite.

Failure trigger: a low reference mean with dirty isolated PNG is still a failed Icon Composer package.

### Generated Concept With No Reference

Use when the user asks for an app icon but supplies no artwork.

- Infer app identity from project metadata and prompt before asking.
- If image generation is available, generate a small set of Icon Composer-friendly concepts and package the selected candidate.
- If image generation is unavailable, directly author a simple semantic icon from the app brief.
- Keep the generated concept prompt biased toward few large shapes, clean layers, restrained palette, and no baked platform effects.

Failure trigger: asking a setup questionnaire before checking available app context.

## Governance

- Use cookbook recipes to choose a route; use `source_analysis` to control the actual icon.
- If two recipes conflict, choose the one with the higher identity or Icon Composer risk.
- Never let a recipe override user-provided source, explicit acceptance, or verifier failures.
- Keep new recipes generic. Do not name one-off real apps, brand fixtures, or evidence directories.
- Add a recipe only after a real run showed a repeatable failure mode and the corrected route passed `author-icon`, `verify`, and visual inspection.
