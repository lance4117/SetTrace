# Semantic Authoring

Semantic authoring means creating a small set of meaningful SVG layers. It is not a blind full-bitmap trace; guarded component-level vectorization is allowed when it produces named, clean SVG components.

## Contents

- [Spec-Driven Icon Package](#spec-driven-icon-package)
- [Source Analysis Contract](#source-analysis-contract)
- [Authoring Judgment](#authoring-judgment)

## Spec-Driven Icon Package

Run:

```bash
delivery="${PWD}/build/my-icon"
mkdir -p "$delivery/tmp/work"
# Write the spec to "$delivery/tmp/work/spec.json" before generation.
# If source evidence exists, copy the selected source/concept to "$delivery/my-icon.origin.png" or "$delivery/my-icon.origin.svg".
npm --prefix scripts run author-icon -- --spec "$delivery/tmp/work/spec.json" --out "$delivery"
```

Required output:

```text
my-icon.preview.svg
my-icon.preview.png
my-icon.svg
my-icon.png
my-icon.origin.png or my-icon.origin.svg, when source evidence exists
layers/*.svg or *.png
MyIcon.icon/
  Assets/*.svg or *.png
  icon.json
tmp/reports/style-report.json
tmp/README.md
tmp/work/spec.json
tmp/work/<repair scratch and candidates>
```

Use platform metadata only when it is known. Generic runs need only a name and layers; Apple package requests can add an Apple target or delivery type:

```json
{
  "name": "MyIcon",
  "target_platforms": ["iOS"],
  "deliverable_type": "icon-composer-package"
}
```

`target_platforms` accepts the user's platform labels and is optional. Every run keeps reproducible source assets; it creates an `.icon` bundle only when an Apple target (`iOS`, `iPadOS`, `macOS`, or `watchOS`) or an Apple delivery request is present. Use `icon-composer-package` only when requesting that Apple adapter. Generic source output does not imply a native package for Android, Windows, Web, tvOS, or visionOS; ask before a dedicated adapter is needed.

`*.preview.*` is the rounded review/presentation output and is the default reference-comparison target. The plain root `.svg`/`.png` pair is the unrounded source/app canvas. `*.origin.*` is the selected source/reference/generated concept evidence and must stay outside `.icon/Assets`.

Delivery-layout `author-icon` reruns preserve existing `tmp/work/` contents and root `.origin.png`/`.origin.svg` source evidence so repair scratch remains available across spec regeneration. The current spec copy at `tmp/work/spec.json` is overwritten on each rerun.

The script packages an agent-authored spec. `author-icon` should not call agents, trace pixels, or embed the reference image as `<image>`. Any vectorization must happen beforehand under `tmp/work/`, with cleaned paths copied into the spec.

Write spec `layers` in bottom-to-top visual order. Use the first layer for the local background or bottom-most imported asset, and the last layer for the foremost mark. The script keeps this order for source files and local preview/app composites, then writes included layers to Icon Composer `icon.json.groups[].layers` in front-to-back display order. Local Icon Composer/Quick Look evidence shows the first JSON layer renders above later layers, so reversing the JSON order is required for overlapping layers.

Simple solid or gradient backgrounds belong in `icon.json.fill`. Keep a local square `layers/01-background.svg` and include the background in the preview and app SVG/PNG outputs for visual comparison, but do not copy simple backgrounds into `.icon/Assets`. Complex visual backgrounds may be copied into `.icon/Assets` as a bottom layer when the layer sets `composer.background_role: "complex"`.

Do not turn the `.icon` bundle into a single rendered PNG snapshot. A full-canvas reference PNG may be useful as root `*.origin.png` source evidence or comparison evidence under `tmp/work/`, but it should not be the only Icon Composer asset. If the artwork cannot be separated into fill plus foreground layers, mark the result `needs-source-vector`, `needs-repair`, or a non-composition baseline instead of calling it an Icon Composer package.

After generating the package, compare the local background layer with `<Name>.icon/icon.json.fill`. A preview-only background must not mask an accidental `automatic` or `solid` fill in the Icon Composer bundle. For simple fills, the preview background should be the same broad fill/gradient intent; do not add localized sheen bands, top bars, edge strips, rounded platform masks, or material patches that Icon Composer fill cannot reproduce.

Do not add an inner border, white highlight stroke, rounded frame, or app-store-style edge line unless it is part of the source image or the user requests it. Icon Composer and platform rendering can add edge treatment later.

For Apple/Icon Composer work, separate semantic source from material appearance. Imported SVG assets should carry the minimal editable shape and base color. Do not improve reference-diff metrics by adding Liquid Glass simulation, bevel strokes, specular glints, blur, or shadow paths to `.icon/Assets` SVGs. If the material appearance must be preserved exactly, choose a PNG import for that layer and record the editability tradeoff.

When a rendered reference contains glass, bevel, soft shadow, or subtle tonal panels, first classify where the material came from. If the reference appears to be an Icon Composer/platform-exported final icon, do not recreate the exported rim, glow, bevel, shadow, border, or Liquid Glass response in preview-only layers. Keep preview focused on clean base layers and broad fill/color alignment, and let `reference-overlay.png`/`reference-diff.png` record the deferred platform material difference. Preview-only appearance layers with `composer.include: false` are reserved for loose rendered concepts, presentation mocks, or explicit user requests for a local material approximation; they still must stay outside `.icon/Assets`.

For production `.icon` work, a flatter local preview is not automatically a defect. It is the expected base-layer proof when the source reference is already a platform-rendered final icon. Repair geometry, placement, palette, fill, and layer order; do not add preview-only rim/glow/bevel helpers merely because the clean preview looks less rendered than the reference. If the user wants both production assets and a rich rendered mock, create the rendered mock as a separate presentation artifact and keep it out of the package contract.

If the target is Liquid Glass in Icon Composer, treat rendered reference material as a guide, not an import source. A source-cut PNG foreground can match the local PNG while failing once Icon Composer applies refraction, glass, lighting, or shadows. Prefer clean semantic SVG/base-shape layers or clean authored PNG layers; reject raster fallback only when it carries source-cut residue or unaccepted baked material.

Imported foreground SVGs must pass the base-shape gate. Keep them to the source silhouette, base fill, and necessary geometric subshapes. Do not add highlight strokes, opacity overlays, bevel/glow/shadow lines, rim or edge glints, specular gradients, or Liquid Glass simulations. The verifier records these as `svg_material_warnings`, which keeps the package review-required until the imported SVG is repaired.

When refining against a reference, treat path geometry as the first-class source of truth. If one edge, endpoint, or curve is wrong, adjust the meaningful path coordinates directly. Do not compensate by changing color, opacity, glow, or highlight geometry. Keep preview-only helper layers in sync when they reuse the same silhouette, but do not include those helpers in the Icon Composer bundle.

Continuous brand contours should remain continuous. For a logo-like "F", knot, monogram, ribbon, or other connected silhouette, prefer one foreground SVG path or compound path over multiple rectangles, patches, or Icon Composer layers. Hard-splitting a connected shape creates seams, black slivers, mismatched corners, and local patch artifacts. Split only when the source itself has disconnected pieces, real overlap, or a meaningful layer relationship.

For smooth identity marks, owned source-vector substitution is a repair path when bitmap tracing produces jagged or pixel-stepped SVG edges. Use it only for user-provided, generated-in-task, project-local, or official-user-approved vectors. Use the rendered icon only as the visual reference for bbox, center, scale, color role, and material; place the clean source SVG/logo path into a single foreground layer with an explicit transform. Keep provenance and transform/alignment basis in the spec. Do not download a public SVG and treat it as the user's generated icon. If no owned vector exists, fall back to semantic redraw, guarded vectorization/polish, clean PNG fallback, `needs-source-vector`, or an explicitly accepted approximation.

Component-level bitmap vectorization is allowed when it preserves layer semantics better than hand-authored guesswork. Use it for supplied/generated/user-owned bitmaps with a few separable foreground parts, such as a colored handset plus a separate speech shape, or for one clean continuous foreground silhouette whose hand-authored contour keeps drifting. Segment the actual user/reference bitmap by color, alpha, luminance, or region; trace each meaningful component mask into one clean SVG path or compound path; then author the fill, gradient, and layer order in the JSON spec. Do not import the mask PNG, the full rendered icon, or a downloaded public SVG as the deliverable source.

Treat component-level vectorization as the required bridge between failed hand-authoring and PNG fallback for clean silhouettes. When a hand-authored SVG is visually close but fails `visual_delta_gate` because the contour, shoulder, lobe, notch, counter, or silhouette rhythm is off, and the reference foreground can be separated cleanly, build a traced SVG candidate from the normalized reference or prepared foreground mask before selecting PNG. A passing traced SVG with clean geometry is preferred over a lower-delta PNG because it keeps the Icon Composer package editable and avoids a review-required raster route.

For one continuous silhouette, an intentional internal counter or hole may remain inside a single compound SVG path when splitting it into overlay layers would create seams or shape drift. This is a conversion-time exception, not a prompt/design instruction: still ask image generation to render apparent gaps as opaque overlays, then choose the cleanest implementation after selection. Record the counter in `source_analysis.components[].must_preserve` or `spec_constraints`, inspect it in overlay/diff, and reject accidental holes caused by threshold noise, masks, clipPaths, or alpha cutouts.

Choose final geometry by shape type: organic symbols, smooth brand-like marks, and continuous silhouettes may keep a clean traced path when it preserves the source better than manual drawing. Primitive-like components should usually be redrawn from trace measurements. If a segmented component is clearly a circle, dot, rounded square, rounded rectangle, capsule, pill, basic polygon, or simple pane, read its bbox, centroid, radius/corner intent, and color from the trace or mask, then redraw it as a spec-authored SVG primitive/path with smooth `C`/`Q` curves. Do this when the trace produces pixel-stepped edges, tiny wiggles, uneven corner tangents, or unnecessary commands. Keep the measured bounds and visual role in `source_analysis.components[].spec_constraints`, regenerate with `author-icon`, and rerun `geometry-audit` plus `verify`.

For this route, keep the spec honest:

- `semantic_review.status` is usually `visually-close`, not `exact-enough`, unless a human/user/independent review accepts exact-enough identity, or the reference is a low-risk generated concept with no external brand identity and the traced SVG passes geometry, reference, and asset inspection gates.
- `semantic_review.notes` should state whether foreground paths came from locally segmented supplied/generated pixels or from simple components redrawn from segmented bounds.
- `source_analysis.components[]` should map one visual component to one SVG layer and include constraints such as "single clean path" and "no source bitmap."
- For simple redrawn components, record constraints such as "redrawn rounded rectangle from segmented bbox" or "redrawn dot from segmented center/radius"; do not describe them as raw traced paths.
- Run `geometry-audit` on traced SVG layers; reject paths with excessive commands, line-heavy stair steps, micro-segment noise, or fake split layers.
- Keep material, bevel, glow, and lighting out of `.icon/Assets`; if the reference has those effects, treat them as preview/verification evidence or Icon Composer handoff.

Use geometry polish only as an optional candidate for clean SVG/base-shape paths. It is appropriate for auto-traced masks with small wiggles, redundant micro-segments, or uneven arcs that should read as smooth curves. It is not appropriate for intentional flat sides, sharp logo terminals, text outlines, mascot features, or negative-space details that define the mark.

Run:

```bash
npm --prefix scripts run polish-svg-geometry -- --input "${PWD}/build/my-icon/layers/02-mark.svg" --out "${PWD}/build/my-icon/tmp/work/02-mark-polished.svg" --report "${PWD}/build/my-icon/tmp/reports/geometry-polish-report.json" --candidate-out "${PWD}/build/my-icon/tmp/work/geometry-polish-candidate.svg"
```

Start conservatively: use low `--tolerance` values and `--smooth none` first. Try `--smooth continuous` or `--smooth geometric` only when the visible issue is truly uneven curvature rather than a path that needs manual geometry repair.

If an intended rounded mark is still mostly straight-line `L` commands after authoring or tracing, treat it as an unfinished geometry route. Low-tolerance simplify can remove point noise, but important rounded terminals, concave joins, and black negative-space boundaries should be authored as semantic `Q` or `C` curves when polish cannot preserve the source contract.

Accept the polished path only when `geometry-polish-report.json.decision` is `"accepted"` and visual inspection confirms that the source-analysis contract still holds. Then copy the accepted path geometry back into the spec and rerun `author-icon`; do not patch only `layers/*.svg` or `.icon/Assets/*.svg` after generation. If the report rejects the candidate, or if the candidate changes the silhouette, spacing rhythm, terminal shape, or negative space, keep the original path.

Before editing a difficult path, name the shape model in plain terms: open form, closed form, compound cutout, ribbon, disconnected pieces, or overlapping plates. If the model is wrong, coordinate tuning will make the icon worse. Use overlay plus temporary row/column foreground interval sampling to verify the model, then repair the smallest path region. Compare the result against the previous best visual candidate after every repair.

Top-level spec controls:

```json
{
  "name": "MyIcon",
  "source_reference": "brief or path",
  "brief": "design intent",
  "semantic_review": {
    "status": "visually-close",
    "identity_risk": "medium",
    "basis": "bitmap reference only; no owned or approved source vector available",
    "route": "semantic-svg-approximation",
    "notes": "record what is preserved and what is approximate"
  },
  "fill": "automatic",
  "font_files": [],
  "default_font_family": "sans-serif",
  "composer": {
    "color_space": "display-p3",
    "group": { "lighting": "individual" }
  },
  "layers": []
}
```

Do not invent empty optional fields. Add `font_files`, `default_font_family`, or `composer` only when they affect the current icon.

Add `semantic_review` when the source is a brand mark, letter mark, existing app icon, typography, or other identity-sensitive symbol. This is not a numeric validator; it is the authoring agent's explicit identity judgment, not permission to self-approve completion. Identity-sensitive work still needs user, human, or independent acceptance in `visual-review.json`. Use:

- `exact-enough` when silhouette, spacing, negative space, stroke continuity, and symbol identity appear faithful enough for review; medium/high identity risk still cannot complete from the authoring agent's judgment alone
- `visually-close` when the package is useful and visually similar, but the mark is a simplified approximation
- `needs-source-vector` when exact identity matters and bitmap-only redrawing is not trustworthy
- `png-fallback-recommended` when a clean raster layer should be imported to preserve dense or renderer-sensitive identity
- `redesign-needed` when the mark has become a different concept
- `accepted-approximation` when the current task boundary explicitly accepts a useful approximation

Also set `semantic_review.route` so verification can separate route problems from pixel problems:

- `semantic-svg`: faithful editable SVG route
- `semantic-svg-approximation`: useful editable approximation that still needs identity review
- `png-fallback` or `png-fallback-recommended`: raster import is selected or recommended for fidelity
- `needs-source-vector`: exact reproduction requires an owned/approved source vector or cleaner user asset
- `style-only-approximation`: the output intentionally follows style rather than exact reproduction
- `redesign-needed`: the mark or concept drifted and should be authored again
- `accepted-approximation`: the approximation was explicitly accepted for the task boundary

For any non-`exact-enough` status, write a concrete `basis`. Do not use a vague note like "close enough"; record what is preserved, what is approximate, and what route should happen next.

## Source Analysis Contract

Before authoring layers for an identity-sensitive source, write `source_analysis`. This is the visual semantic contract that keeps the agent from optimizing a nearby but wrong symbol.

Required fields for approximate or medium/high-risk marks:

```json
{
  "source_analysis": {
    "fidelity_target": "what the generated icon must preserve",
    "identity_risk": "medium",
    "route": "semantic-svg-approximation",
    "must_preserve": [
      "distinctive silhouette",
      "negative-space relationship",
      "required missing bar or cutout"
    ],
    "must_not_add": [
      "generic substitute glyph",
      "unrequested stroke or counter",
      "unrequested platform frame"
    ],
    "components": [
      {
        "id": "primary-mark",
        "layer": "mark",
        "format": "svg",
        "source_vector": "path/asset name when an owned clean SVG/logo source is used",
        "source_provenance": "user-provided | project-local | generated-in-task | official-user-approved",
        "alignment_basis": "fitted to reference bbox and center; no bitmap trace",
        "spec_constraints": ["single continuous stroke family"]
      }
    ],
    "acceptance_checks": [
      "overlay confirms the mark is the same identity, not only similar bounds"
    ]
  }
}
```

Every Icon Composer-included layer must be represented in `source_analysis.components`. Use the contract to decide what to inspect after generation: bars, missing bars, open counters, loops, knots, mascot features, terminals, text rendering, and foreground/background separation. When an owned clean source vector replaces a jagged bitmap trace, record `source_vector`, `source_provenance`, and `alignment_basis` on the component. If the contract cannot be written confidently from a bitmap reference, mark the route as `needs-source-vector`, `png-fallback-recommended`, or `visually-close` rather than pretending exact reproduction is possible.

Do not turn `source_analysis` into a rigid template. The fields are fixed; the contents should be specific to the current icon. Omit `source_vector`, `source_provenance`, and `alignment_basis` when no clean owned source vector is used.

Use PNG `.icon/Assets` as a deliberate clean per-layer material, not as the default route:

```json
{
  "name": "word layer",
  "svg": "<text ...>APP</text>",
  "composer": { "format": "png", "reason": "text rendering must be preserved" },
  "text_rendering": {
    "font_family": "Inter",
    "render_method": "@resvg/resvg-js renders SVG text to transparent PNG"
  }
}
```

This preserves source evidence in `layers/` while pre-rendering only selected Icon Composer layer assets to PNG. If the source is an embedded image, set `png` to the source image path instead of writing a local SVG wrapper with an absolute `<image href>`.

If the spec declares `semantic_review.route` as `semantic-svg` or `semantic-svg-approximation`, the Icon Composer package must contain an SVG foreground import. A package whose foreground imports are all PNG is a PNG fallback route and must be labeled as such, kept in review, or repaired back to semantic SVG.

For non-text foreground PNG fallbacks, `reason` is not enough. Add `png_fallback_evidence` either under the layer or under `composer`:

```json
{
  "composer": {
    "format": "png",
    "reason": "dense brand geometry failed the semantic SVG route without preserving identity",
    "png_fallback_evidence": {
      "category": "dense-brand-geometry",
      "svg_route": "attempted-and-failed",
      "evidence": "SVG redraw changed stroke continuity and negative-space shape",
      "cleanliness_check": "isolated PNG was inspected on transparent and neutral backgrounds"
    }
  }
}
```

Allowed categories are `embedded-raster`, `dense-brand-geometry`, `renderer-artifact`, `custom-gradient`, `raster-art`, `strict-fidelity`, and `icon-composer-svg-artifact`. A generic reason such as "preserve source antialiasing and brand geometry" is a blocker.

For user-provided brand marks or text-heavy artwork, decide the import format before authoring the layer. Prefer SVG when the mark is simple and faithful; choose PNG when there is a concrete fidelity/material reason and the PNG is clean in isolation:

- simple mark: author and import as SVG
- flat or linear-gradient raster layer: import as PNG when it is intentionally authored and has no source-background residue
- complex logo/path stack: keep source SVG evidence, import rendered PNG if fidelity matters more than editability
- text: outline only when the outline is visually faithful; otherwise render SVG text to PNG and import the PNG layer
- embedded raster/image source: use `png: "/path/to/source.png"` so source evidence is kept locally as `layers/*.png`, and import the rendered PNG layer instead of an SVG containing `<image>`
- post-preview fallback: if Icon Composer shows SVG-specific artifacts for one layer, switch only that layer to PNG and record the reason

Do not use a low reference diff as proof that a brand mark is semantically correct. A simplified letter or logo can pass the numeric target while losing the mark's real structure. If exact brand fidelity is not achievable from the provided bitmap, record that boundary and choose source-vector request, PNG fallback, or accepted approximation instead of silently redrawing a different mark.

For benchmark or reproduction work, a PNG fallback does not excuse weak visual quality. It must still pass mean delta `< 10` against the same-size reference unless the user explicitly accepts a semantic approximation or looser style exploration.

If a user-approved, human-approved, or independently accepted semantic SVG has a higher mean delta but is visually and architecturally better for Icon Composer, freeze that SVG candidate and label it `accepted-approximation`. Do not switch it to PNG solely to improve the pixel metric. A lower-delta repair that loses editability, silhouette quality, or the accepted visual direction is a failed repair, not progress.

For Apple/Icon Composer semantic remakes from final rendered references, a mean delta in the `10-20` range can still be the better candidate when local samples pass, the main geometry aligns, and the visible mismatch is mostly baked glass, bevel, shadow, glow, or edge lighting. Keep that state explicit as review/acceptance evidence. Do not call it strict reproduction, and do not bake the material into imported SVGs just to cross the `<10` line.

When a clean base-layer package reaches the strict mean target anyway, do not let the numeric pass erase the source boundary. Bitmap-only brand or existing-icon remakes can still be `visually-close`/`review_required` because the result is an honest semantic approximation, not an owned source-vector reproduction. Record the pass as evidence of useful alignment, not proof of exact identity.

If a generated batch is mostly PNG fallback, stop and review the route before continuing. A PNG-dominant batch can be valid only when the PNGs are clean authored assets or accepted raster fallbacks; otherwise it is just a raster baseline and not evidence that the skill is producing Icon Composer-ready semantic layers.

For dark bitmap artwork on a light background, do not use simple white-to-transparent cleanup. First create a matte so edge pixels are foreground color plus alpha, not pale contaminated RGB:

```bash
npm --prefix scripts run prepare-bitmap-layer -- --input "${PWD}/path/to/source.jpg" --out "${PWD}/build/source-layer.png" --padding 8
```

Then set `png` to `build/source-layer.png` and set `composer.format: "png"`. Do not wrap the prepared PNG in a source SVG with `<image>`.

For light foreground artwork on a dark or complex rendered background, first extract the foreground as a clean same-size transparent PNG:

```bash
npm --prefix scripts run prepare-foreground-layer -- --input "${PWD}/path/to/source.png" --out "${PWD}/build/foreground-layer.png" --mode light-on-dark --preserve-rgb --min-rgb 238 --grow 2
```

Use this when a raw luminance threshold would capture background glints, gradients, or glass highlights. The script keeps only the largest light connected component by default; use `--region x,y,w,h` if unrelated bright areas are near the icon. If the desired foreground is split into multiple disconnected semantic pieces, use `--keep-components all` only when the source-analysis contract names those pieces as intentional, or author the pieces as separate layers/redraw them as SVG instead of forcing a single dirty PNG.

For colored or multi-part foregrounds on a near-flat background, use `--mode non-background --background '#000000'` or `--background '#ffffff'`. Use `--keep-components all` for intentional disconnected pieces and `--keep-components largest` for one subject. This mode is for foreground extraction only; if an edge frame or full-canvas artwork is part of the design, split it into a background-like layer rather than treating it as foreground.

For white or light foregrounds on saturated blue/cyan/colored backgrounds, use `--mode light-on-color`. Tune `--threshold`, `--alpha-low`, `--alpha-high`, `--min-rgb`, and `--region` so the PNG keeps the translucent foreground material without carrying the colored background. If only one local area keeps a rectangular source-background strip, clean that local area by pixel content or redraw it as SVG instead of accepting the strip.

Do not import a PNG fallback just because a rendered screenshot is visually close. A foreground PNG fallback must be clean when viewed by itself. If an extracted bitmap layer keeps gradient residue, glass lighting, background haze, rectangular edge pixels, or source material around the silhouette, try a matte rebuild only when the foreground and background can be separated. If separation is not reliable, use the reference as design evidence and redraw the layer as SVG, even if the SVG is a simplified approximation.

When the choice affects a user's own brand/logo/text, ask for confirmation before rasterizing the Icon Composer import asset.

For simple backgrounds, set one of the supported fill modes:

- `fill: "automatic"`
- `fill: { "automatic-gradient": "extended-srgb:..." }`
- `fill: { "solid": "extended-gray:..." }`
- `fill: { "linear-gradient": [stopA, stopB], "orientation": ... }`

Use exactly two stops for `linear-gradient`; Icon Composer can reject `.icon` bundles that use 3+ stops even when the local preview SVG/PNG renders correctly. Use `extended-srgb` stops for colored gradients and allow mixed `extended-gray`/`extended-srgb` stops when the design needs a neutral-to-color fill. If reference comparison needs a richer preview gradient, keep that as a local preview-only background and downgrade `icon.json.fill` to the nearest two-stop broad fill, or import a deliberate complex background layer.

For complex backgrounds, do not force everything into `icon.json.fill`. Use a bottom SVG/PNG asset only when the background contains texture, non-linear composition, image-like art, or multiple shapes that fill cannot represent. Mark it as `composer.background_role: "complex"` and keep it first in bottom-to-top order. It must still have separated foreground layers above it; a single full-artwork PNG asset is only a rendered baseline.

## Authoring Judgment

Use the user's input type to decide how much freedom the agent has.

For loose briefs and style references, pixel similarity is not the primary goal. Prefer an icon that is:

- editable in separated layers
- aligned with Apple app-icon and Icon Composer design language
- readable when scaled down
- compatible with Icon Composer effects
- clearly related to the requested direction without overfitting a reference image

For user-owned brand marks, text-heavy artwork, and existing app icons, recognizable identity is a hard constraint. Preserve silhouette, spacing, color role, and typography fidelity unless the user asks for redesign. Use Apple/Icon Composer adaptation for layer structure, import format, background fill, and material handoff; do not use it to invent a different mark.

When the source mark has a distinctive continuous shape, inspect continuity and negative space, not just outer bounds. A logo-like "F", "G", knot, loop, monogram, or mascot head can become semantically wrong even if overlay and mean delta look good. Record that as `visually-close` or `needs-source-vector` unless the source structure is genuinely preserved.

When an existing icon already shows system material, preserve the underlying silhouette and layer relationship first. Do not copy every lighting artifact into the editable SVG source; let Icon Composer regenerate platform material where possible.
