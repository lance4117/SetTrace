# Optimization Methods

Use this reference when a generated icon is structurally close but visually rough, dirty, over-rasterized, or failing verification. Pick the method from the observed symptom. Do not start from a favorite tool.

All optimizations are candidate steps. A candidate becomes part of the package only after it is written back to the JSON spec, regenerated with `author-icon`, and rechecked with `verify`.

## Method Router

| Symptom | Use | Guardrail |
| --- | --- | --- |
| Reference and preview use different canvas, scale, or app mask | `normalize-reference`, then `verify --reference` | Normalization aligns comparison space only; it must not hide a real visual mismatch. |
| SVG quality is unclear before repair | `geometry-audit` | Audit is read-only; use it to choose a route, not to claim completion. |
| Bitmap trace remains jagged/noisy for a smooth brand mark, monogram, knot, or loop logo | Owned source-vector route when available; otherwise semantic redraw, guarded vectorization/polish, or clean PNG fallback | Do not substitute a downloaded public SVG for a generated/user-owned icon. Keep provenance, source, and transform basis in `source_analysis`; reject if identity changes or provenance is not allowed. |
| Hand-authored SVG paths are structurally close but visibly wrong for a simple multi-component colored bitmap | Component-level color/alpha segmentation, component mask vectorization, then authored SVG fills/gradients in the spec | Use only the supplied/generated/user-owned bitmap as input. Each traced component must map to a semantic layer; do not import the whole bitmap, and do not replace it with a public SVG. |
| Separable foreground components look close but strict mean stays high from glass/rim/background material | `shape-facts` with explicit background when thresholding is reasonable; inspect `comparison.summary.interior_scanline_drift` before path repair | Repair only real interior geometry drift. Do not add rim, bevel, glow, or source-cut PNG layers to chase the mean target. |
| Path is mostly `L` commands, stair-stepped, or noisy from tracing | `polish-svg-geometry` with low `--tolerance` and `--smooth none` | Accept only when the report says `accepted`, visual semantics still hold, and the polished path is written back to the spec. |
| Potrace or bitmap-derived SVG keeps soft-source stair steps, fuzzy edges, or app-mask rim artifacts | Clean bitmap retrace route | Rebuild the binary mask before tracing: remove platform rim/glow, keep only named components and holes, then compare before/after `geometry-audit`, preview, overlay, and diff. |
| Tolerance/smoothing choice is unclear | `polish-svg-candidates` | Treat the best ranked candidate as a review target, not an automatic replacement. |
| Curves, terminals, or negative space are still wrong after low-tolerance polish | Manual semantic `Q`/`C` curve repair in the spec | Do not use stronger smoothing if it makes a cleaner but different mark. |
| `geometry-audit` is clean but side-by-side looks hand-drawn or guessed | Shape-model repair from reference measurements or the previous best candidate | Do not accept lower command count as progress when curve rhythm, mass, terminals, or negative space get worse. |
| Visual review is unstable for a vector-friendly reference/candidate pair | `shape-facts` on same-canvas PNGs | Use component, hole, bbox, centroid, and scanline facts to localize drift; facts are diagnostic only and cannot prove identity or final Icon Composer rendering. |
| Repeated rounded panels, bars, or plates have kinked or doubled corners | Rewrite each real panel as a single semantic path with continuous `C`/`Q` corner transitions | Do not patch only the visible bad corner; apply the same path model to the repeated shape family and rerun verification. |
| A continuous logo, monogram, ribbon, knot, or letterform was split into patches | Rebuild as one foreground SVG path or compound path | Do not create fake Icon Composer layers when the source has no real layer boundary. |
| Foreground PNG contains source background, glow, hard matte, crop edge, or glass residue | Redraw as semantic SVG, or rebuild with `prepare-foreground-layer` only when a PNG fallback is justified | A low reference delta is not enough; inspect the isolated PNG layer. |
| `souvenir-decal-stickers` PNG foreground shows a cool gray-blue halo around otherwise clean sticker paper | `clean-sticker-matte` | Use only for this sticker template or visually equivalent gray-blue-surface decal clusters. It removes exterior shadow/background halos and preserves warm-white sticker paper, flat color, dark ink, and a thin antialias edge. |
| Dark artwork sits on a light bitmap background | `prepare-bitmap-layer` | The alpha matte must be clean on transparent/checker and neutral backgrounds. |
| Light/colored foreground sits on dark, saturated, or near-flat rendered background | `prepare-foreground-layer` with the appropriate mode and optional `--region` | Keep only intended foreground components; unrelated glints or background highlights must be removed. |
| Text in SVG imports triggers Icon Composer warnings | Convert text to paths if faithful, otherwise render that text layer to PNG with font/render metadata | Do not import `<text>` into `.icon/Assets/*.svg`. |
| SVG contains bevels, glows, highlights, shadows, opacity overlays, or Liquid Glass simulation | Remove material from imported SVG; keep it as base geometry or move review-only appearance into preview-only layers | `svg_material_warnings` is a review blocker until repaired. |
| Pixel mean passes but a local region is visibly wrong | Use `reference-side-by-side.png`, `reference-overlay.png`, `reference-diff.png`, verifier diagnostics, and temporary row/column sampling to locate geometry or fill drift | Diagnostics guide repair; they are not completion gates. |
| A batch has many PNG fallbacks or review-required rows | `summarize-run` | Use `review_required`, `route_status`, source contracts, and visual decisions; do not count plain `status: ok` as completion. |

## Paper.js Geometry Route

Current built-in Paper.js commands are `geometry-audit`, `polish-svg-geometry`, and `polish-svg-candidates`. Use them for:

- auditing whether a path is line-heavy, fragmented, compound, or noisy before repair
- removing redundant trace points
- turning small stair-step noise into cleaner curves
- normalizing simple path data without changing the mark
- testing `smooth none`, `smooth continuous`, or `smooth geometric` as guarded candidates

Start with:

```bash
npm --prefix scripts run polish-svg-geometry -- \
  --input /absolute/path/to/Icon/layers/02-mark.svg \
  --out /absolute/path/to/Icon/layers/02-mark-polished.svg \
  --report /absolute/path/to/Icon/geometry-polish-report.json \
  --candidate-out /absolute/path/to/Icon/geometry-polish-candidate.svg \
  --tolerance 0.2 \
  --smooth none
```

Use `--smooth continuous` or `--smooth geometric` only when the visible defect is true uneven curvature and the report plus visual inspection prove the candidate did not shift the silhouette, terminal shape, spacing rhythm, or negative space.

If you need to decide whether Paper.js is appropriate, run the read-only audit:

```bash
npm --prefix scripts run geometry-audit -- \
  --input /absolute/path/to/Icon/layers/02-mark.svg \
  --report /absolute/path/to/Icon/geometry-audit.json
```

If the route is appropriate but the tolerance is unclear, generate candidates:

```bash
npm --prefix scripts run polish-svg-candidates -- \
  --input /absolute/path/to/Icon/layers/02-mark.svg \
  --out-dir /absolute/path/to/Icon/geometry-candidates \
  --report /absolute/path/to/Icon/geometry-candidates.json
```

Paper.js is not the right tool for alpha cleanup, dirty threshold edges, material simulation, text fidelity, or Icon Composer package validation. If the stair steps come from a soft or contaminated source mask, rebuild the mask before polishing the traced path. Use pixel scripts, semantic authoring, or the verifier for those.

Automatic boolean union or compound-path repair is not currently built in. Those operations can change topology, close openings, or alter brand-critical negative space. Use `geometry-audit` to detect possible fragmentation, then rebuild the SVG semantically unless a future tested script proves the boolean route is safe for the current shape.

## Clean Bitmap Retrace Route

Use this route when a simple SVG-friendly foreground was vectorized from a rendered PNG, but the SVG edge still looks soft, jagged, stair-stepped, or contaminated by the app-icon mask/rim. This is a source-mask repair, not stronger smoothing.

1. Inspect the full-size preview and isolated SVG layer, then run `geometry-audit` on the current foreground. A low command count does not prove a clean edge if the preview still carries source-pixel steps.
2. Create scratch under `tmp/work/`. Build a fresh binary foreground mask from the supplied/generated/user-owned bitmap. If a higher-resolution original exists and contains real detail, use it; do not upscale a low-resolution PNG and treat the result as new evidence.
3. Remove platform artifacts before tracing: app-mask rim, top/bottom edge glow, bevel, shadow, background highlight bands, and canvas-edge residue. Keep only components and holes named in `source_analysis`.
4. Clean the mask before `potrace`: use conservative close/open morphology to remove pinholes and speckles, then slight blur plus re-threshold to turn anti-aliased soft edges into a stable contour. Recheck that intentional negative spaces did not close or drift.
5. Trace the cleaned mask into one SVG path or compound path per real foreground component. Author fill, background, and Icon Composer material in the spec instead of copying rendered pixels.
6. Compare the retrace against the previous best candidate: `geometry-audit` warnings, micro-segments, side-by-side, overlay, diff, and small-size preview. Accept the retrace only when the edge is visibly cleaner and the silhouette, terminals, and negative spaces still match the source contract.
7. Record the repair in `source_analysis` with the mask cleanup method, before/after audit evidence, and any accepted tradeoff. Write the candidate back to the JSON spec, regenerate with `author-icon`, and rerun `verify --reference`.

## Shape Facts Route

Use this route when the model keeps making subjective visual judgments about a simple or vector-friendly reference, especially loops, chain marks, symbols with holes, simple multi-component marks, or local geometry drift.

Run:

```bash
npm --prefix scripts run shape-facts -- \
  --reference /absolute/path/to/reference.png \
  --candidate /absolute/path/to/Icon/Icon.preview.png \
  --out /absolute/path/to/Icon/shape-facts.json
```

Good inputs:

- same-canvas PNGs after any required reference normalization
- high-contrast foreground on a near-flat background
- simple connected marks, large holes/cutouts, or a few separable components
- candidate previews where bbox, centroid, hole count, or scanline intervals are disputed

Poor inputs:

- Liquid Glass, glow, shadow, bevel, blur, or material edges that cannot be separated from shape
- text, dense brand artwork, mascots, detailed illustrations, or exact official identity checks
- images where thresholding splits one real component into many fragments or closes/opens holes incorrectly

Use the report to update `source_analysis` and repair the semantic SVG. A missing required component or hole is usually a blocker; bbox/centroid or scanline drift is a repair target. If the reference contains edge glow, app-mask highlights, or canvas artifacts, compare `interior_count` and `interior_scanlines` before treating full-canvas scanline drift as foreground failure. Passing shape facts does not complete the icon, and failed facts should not be gamed with source-cut PNGs or baked material.

For separable foreground components on simple backgrounds, pass the background explicitly when thresholding is reasonable and read `comparison.summary` first. A useful pattern is: full scanline drift is large, edge-touching count differs, but interior component count is stable and interior scanline drift is modest. That means the base SVG composition is probably close and remaining strict pixel error is mostly platform rim/glass/material. Continue with overlay review and accepted-approximation evidence instead of adding material helper layers.

## Rounded Panel Path Route

Use this route when the icon uses repeated slanted panels, panes, bars, or tiles and the reference/preview shows a corner that looks doubled, kinked, notched, or pieced together.

1. Inspect the source path before smoothing. If a rounded corner is built from small line segments plus multiple curve fragments, treat it as a semantic path bug.
2. Rewrite the whole panel as one closed path with straight sides and continuous `C` or aligned `Q` corner transitions.
3. Apply the same path model to every repeated panel in the icon family so the geometry language stays consistent.
4. Regenerate with `author-icon`, rerun `verify --reference` when a reference exists, and inspect the enlarged preview plus overlay.
5. Accept a small mean-delta regression when it removes a real geometry defect and keeps the source-analysis contract. Reject the repair if panel position, width, angle, or spacing rhythm drifts.

Do not solve this by adding rim strokes, material highlights, blur, or preview-only overlays. The defect is in the base silhouette.

## Owned Source Vector Route

Use this repair path for smooth identity marks when a rendered PNG trace produces pixel stair-steps or excessive path noise and an owned clean vector exists. This is not stronger smoothing; it is a route correction. It is not permission to download a public SVG and bypass image-to-SVG conversion.

1. Look for a clean source SVG/logo only in user-provided files, generated-in-task assets, project assets, existing app assets, or official sources explicitly approved by the user.
2. Use the rendered reference to measure the intended bbox, center, scale, rotation, color role, and material direction.
3. Record `source_vector`, `source_provenance`, and `alignment_basis` in `source_analysis.components[]`.
4. Place the clean source vector into the foreground SVG layer with an explicit transform or rewritten path coordinates.
5. Keep preview-only lighting, shadow, bevel, or glass helpers outside `.icon/Assets`; the imported vector should remain base silhouette and base fill.
6. Run `geometry-audit` and `verify --reference`; compare command count, micro-segments, overlay, and diff against the traced candidate.
7. If the clean source changes the identity, reject it and use semantic redraw, clean PNG fallback, `needs-source-vector`, or an explicit accepted approximation.

Prefer this route over Paper.js only when the vector is owned/approved. Paper.js is useful for small trace noise; if no owned vector exists and the trace remains jagged, the honest choices are semantic redraw, cleaner vectorization, clean PNG fallback, or `needs-source-vector`.

## Component-Level Vectorization Route

Use this route when a reference PNG is simple enough that the real design components can be recovered from the user's pixels, but hand-authored coordinates are drifting. It is a semantic SVG route, not a raster fallback.

Good candidates:

- two to five separated foreground components
- one clean continuous foreground silhouette with intentional counters/holes
- saturated, high-contrast, or alpha-separated foreground on a near-flat background
- simple silhouettes with smooth curves
- SVG-friendly foregrounds whose material can be handled by Icon Composer

Poor candidates:

- text, dense brand artwork, mascots, knots, or detailed illustrations
- foreground and background that are inseparable because of glass, glow, shadow, or blur
- source images where segmentation creates halos, dirty residue, or many fragments
- cases where exact brand identity requires an owned source vector

Process:

1. Detect foreground components, bbox, holes/counters, and palette roles from the supplied/generated/user-owned bitmap.
2. Keep only real visual components named in `source_analysis`; discard speckles, shadows, and background material.
3. Trace each component mask into one SVG path or compound path using available local vectorization tooling.
4. Author fills/gradients in the JSON spec rather than copying rendered material.
5. Generate with `author-icon`, then run `geometry-audit` on each traced layer and `verify --reference`.
6. Inspect `reference-side-by-side.png`, `reference-overlay.png`, `reference-diff.png`, `.icon/Assets`, `svg_material_warnings`, and `package-verification.json.outcome`.

Accept the route when the traced component version improves the whole-icon silhouette, the SVG assets remain clean, and the reference mean/local gates pass or the semantic tradeoff is explicitly accepted. Keep `semantic_review.status` as `visually-close` unless exact source-vector fidelity is proven or accepted, or the source is a low-risk generated concept whose original silhouette is preserved by a clean traced SVG and documented in `source_analysis`.

## Bitmap And Foreground Routes

Use PNG helpers only when a layer is deliberately raster:

- `prepare-bitmap-layer`: dark artwork from a light bitmap source.
- `prepare-foreground-layer --mode light-on-dark`: light artwork from dark or complex backgrounds.
- `prepare-foreground-layer --mode light-on-color`: light artwork from saturated colored backgrounds.
- `prepare-foreground-layer --mode non-background`: colored foreground from a near-flat known background.
- `clean-sticker-matte`: souvenir decal sticker cluster cleanup after foreground extraction, before writing the PNG into the spec.

Use `--region x,y,w,h` when unrelated highlights or marks are near the target. Use `--keep-components all` only when the source-analysis contract names multiple disconnected components as intentional.

Clean authored PNG layers are valid. Dirty source-cut PNG layers are not. If isolated PNG inspection shows haze, matte, rectangular residue, baked material, or background fragments, redraw as semantic SVG or keep the package in review.

For the `souvenir-decal-stickers` template, generated concepts often contain a soft gray-blue exterior shadow that belongs to the reference background, not the reusable foreground PNG layer. After extracting the sticker cluster, run:

```bash
npm --prefix /absolute/path/to/skills/app-icon-gen/scripts run clean-sticker-matte -- \
  --input /absolute/path/to/Icon/tmp/work/foreground-stickers.raw.png \
  --out /absolute/path/to/Icon/tmp/work/foreground-stickers.png \
  --preview-on-black /absolute/path/to/Icon/tmp/work/foreground-stickers-on-black.png
```

Inspect the black preview and isolated PNG before accepting it. The desired result has no gray-blue halo, no rectangular residue, no canvas-edge visibility, and only a small antialias band around warm-white sticker paper. Record the cleanup in `source_analysis.components[].alignment_basis` and in the PNG fallback cleanliness check, then regenerate with `author-icon` and run `verify --reference`.

## Candidate Acceptance

Before accepting any optimization, check:

- the original source-analysis contract still describes the output
- the candidate was written back to the spec, not only patched in `layers/` or `.icon/Assets`
- `author-icon` regenerated the package
- `verify --reference` passes when a reference exists
- `package-verification.json.outcome.review_required` is false after an applicable accepted `visual-review.json` has been recorded
- `svg_material_warnings` and package `warnings` are empty, and every `png_layer_hygiene` entry passes edge/residue checks
- overlay, diff, and isolated assets were inspected after the change

If an optimization improves the metric but makes the icon less correct, restore the previous best candidate and change the route.

For smooth symbolic marks, "less correct" includes a hand-drawn feel: inconsistent foreground mass, wandering curves, terminals that do not match the reference, or negative space that no longer describes the same mark.
