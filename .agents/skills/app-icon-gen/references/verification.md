# Verification

This skill checks local SVG assets, rounded preview outputs, unrounded app outputs, and Icon Composer package structure. It does not prove final Icon Composer rendering unless the user imports the assets and provides evidence.

## Contents

- [Commands](#commands)
- [Diagnostic Metrics](#diagnostic-metrics)
- [PNG Fallback Hygiene](#png-fallback-hygiene)
- [Local Sample Diagnostics](#local-sample-diagnostics)
- [Localized Geometry Repair](#localized-geometry-repair)
- [Spec Package Verification](#spec-package-verification)

## Commands

Run from the skill directory:

```bash
npm --prefix scripts ci
npm --prefix scripts run prepare-bitmap-layer -- --input "${PWD}/path/to/source.jpg" --out "${PWD}/build/source-layer.png"
npm --prefix scripts run verify -- --out "${PWD}/build/my-icon"
```

Run `prepare-bitmap-layer` only when the icon has a bitmap fallback source that needs clean alpha extraction.

If the user provides a reference image, existing icon, or asks to reproduce/replicate a visual direction, run verification with the reference:

```bash
npm --prefix scripts run verify -- --out "${PWD}/build/my-icon" --reference "${PWD}/path/to/reference.png"
```

If the reference is a raw square/JPEG, a screenshot crop, or any image that does not share the generated icon's 1024px canvas and app-icon mask, normalize it before strict comparison:

```bash
npm --prefix scripts run normalize-reference -- --input "${PWD}/path/to/reference.jpg" --out "${PWD}/build/reference-1024.png"
npm --prefix scripts run verify -- --out "${PWD}/build/my-icon" --reference "${PWD}/build/reference-1024.png"
```

Reference normalization is only an input-alignment step. It must not be used to hide mark geometry, foreground cleanliness, fill, or semantic mismatches.

This writes `reference-side-by-side.png`, `reference-overlay.png`, `reference-diff.png`, and `package-verification.json` beside `style-report.json` when dimensions match. In delivery layout that means `tmp/reports/`.

Reference comparison uses `style-report.json.preview_png`. It intentionally compares the rounded review output, not the unrounded source canvas.

Evidence order:

1. Use `reference-side-by-side.png` only to form the first whole-icon hypothesis.
2. Use `reference-overlay.png` before changing position, scale, contour, negative space, or layer alignment.
3. Use `reference-diff.png` before changing color, background, glow, shadow, antialiasing, or material treatment.
4. Use `local_samples`, `local_sample_gate`, and `tile_heatmap` to localize a suspected issue after overlay/diff inspection.
5. Use `shape-facts` or temporary bbox/centroid/scanline checks when overlay review is ambiguous for smooth marks, mascots, ribbons, loops, or repeated panels.
6. Use `geometry-audit` after SVG repair to reject path noise, not to approve visual likeness by itself.
7. Use isolated asset inspection and `png_layer_hygiene` before accepting any PNG fallback.

Do not skip to a PNG fallback, color tweak, or broad repositioning from side-by-side plus mean delta alone. Every repair should name which evidence image/report showed the problem and what hypothesis the spec change is testing.

Interpretation:

- `reference-side-by-side.png`: primary whole-icon check, with the reference on the left and the generated preview on the right. Use it first to see overall likeness, scale, mass, and obvious style drift.
- `reference-overlay.png`: primary check for geometry, placement, proportion, and layer alignment.
- `reference-diff.png`: primary check for color, shadow, glow, background, and silhouette mismatch.
- `package-verification.json.png_layer_hygiene`: hard check for foreground PNG fallback cleanliness before Icon Composer import.
- `package-verification.json.svg_material_warnings`: imported foreground SVGs that look like they contain baked material simulation, such as highlight strokes, opacity layers, or gradient edge/rim/bevel effects. These warnings make the package review-required.
- `package-verification.json.warnings`: inspection triggers, especially hard opaque foreground PNG fallbacks with no semi-transparent edge pixels.
- `package-verification.json.reference_comparison.mean_absolute_rgb_delta`: useful trend metric during iteration and a hard completion gate for reproduction work, not a reason to damage layer semantics.
- `package-verification.json.reference_comparison.diagnostics`: global pixel percentiles, threshold counts, alpha deltas, high-delta region, and 8x8 tile hotspots for repair guidance, not a pass/fail gate.
- `package-verification.json.reference_comparison.visual_delta_gate`: hard guard for broad high-intensity diff residuals. It catches obvious contour, silhouette, or local shape drift that can pass global mean and fixed local samples because the background dominates the canvas.
- `package-verification.json.reference_comparison.local_samples`: 3x3 local window diagnostics for repair guidance.
- `package-verification.json.reference_comparison.local_sample_gate`: hard guard for severe 3x3 sample mismatches that indicate position, scale, or shape drift hidden by the full-image mean.
- `shape-facts.json`: optional read-only structure diagnostics for same-canvas reference/candidate PNGs. It reports component count, edge-touching artifacts, large holes/cutouts, bbox/centroid, scanline interval drift, and a short `comparison.summary`. Use it to reject or localize shape repairs, not to approve completion.
- `package-verification.json.outcome`: generic source-asset route and pixel evidence. A generic report does not carry publication, native-package, or platform-render completion states.
- `package-verification.json.apple_adapter`: present only for a requested Apple package. Its export evidence is checked only when it exists; absent Apple output is not a failure for generic icons.
- `geometry-polish-report.json`: optional pre-regeneration report for a polished SVG candidate. It only proves bounded rendered drift from the previous SVG; it does not replace source-analysis review, side-by-side/overlay/diff inspection, or final package verification.
- `style-report.json.semantic_review`: agent-recorded identity judgment for brand marks, letter marks, existing app icons, typography, or other semantic symbols. This is a completion boundary, not an automated pixel metric.
- `style-report.json.source_analysis`: required source contract for identity-sensitive approximations. Missing source analysis on a medium/high-risk or non-exact semantic review routes the package to `source_analysis_missing`.
- `visual-review.json`: required visual decision before completion. It must record an accepted `decision`, a non-empty `reviewer`, non-empty `evidence`, and non-empty `notes`. When Apple renders were reviewed, it must also list every generated platform in `platforms_inspected` and every exact file path in `renders_inspected`. A main-agent acceptance is sufficient only for low-risk original concepts; identity-sensitive, accepted-approximation, and PNG-fallback routes require user, human, or independent acceptance. A rejected decision overrides numeric success and routes the package to `visual_review_rejected`. Rejected spellings include `rejected`, `not-candidate`, `redesign-needed`, `needs-source-vector`, and `needs-repair`.

Reference-driven targets:

- `< 10`: required completion target for strict pixel reproduction. Use `--max-mean-delta 9.99`; this is also the verifier default when `--reference` is provided.
- `10-15`: strict pixel repair range, or a normal reviewed range for Icon Composer semantic remakes when the remaining delta is mostly rendered glass/material that should not be baked into imported assets.
- `15-20`: still failed strict pixel reproduction, but may be acceptable for a reviewed Icon Composer semantic remake when whole-icon geometry is close, assets are clean, and the user/human/independent review explicitly accepts the material tradeoff.
- `> 20`: failed strict pixel reproduction and usually failed semantic remake; revisit source analysis, route selection, geometry, or reference normalization before promoting any lesson.

Strict `<10` has preconditions. Use it as a hard completion gate only when the task is actually pixel reproduction: the reference and generated preview share the same canvas/mask intent, the reference is flat/source artwork or a benchmark target, and matching pixels does not require baking platform renderer material into source assets. Do not treat exported Icon Composer/Liquid Glass screenshots as strict pixel targets by default.

For rendered Icon Composer/platform references, stop chasing `<10` when all of these are true:

- `local_sample_gate.status` is `"ok"`
- side-by-side and overlay show the main geometry, scale, spacing, and layer order are close
- `.icon/Assets` are clean SVG/base layers or justified clean PNG layers
- `svg_material_warnings` and package `warnings` are empty; every `png_layer_hygiene` entry passes edge/residue checks (the array itself may be non-empty for clean PNG assets)
- the remaining diff is mostly glass, bevel, glow, shadow, edge lighting, or renderer shading
- the next likely "improvement" would add fake material, dirty PNG, source-cut residue, or worse semantics

At that point, classify the result with a looser semantic target such as `--max-mean-delta 15` and record the strict-pixel miss as a material handoff instead of continuing the loop.

For strict reference reproduction, iterate until mean delta is `< 10`, `visual_delta_gate.status` is `"ok"`, and `local_sample_gate.status` is `"ok"`, then inspect the side-by-side image, overlay, diff, diagnostics, and local samples before claiming visual closeness. Fix geometry/proportion drift first, then color/background, then shadow/glow/material differences. Do not chase material deltas by baking Liquid Glass highlights, bevels, blur, or shadows into `.icon/Assets` SVGs; keep source SVGs semantic or deliberately switch only the affected layer to PNG when SVG cannot preserve the required identity. For loose style exploration without a concrete reference target, reference comparison remains optional and should not become the main success criterion.

If `visual_delta_gate.status` is `"failed"`, treat the package as `needs_repair` for strict reference work. This is stricter than a manual "please review" warning: it means the interior diff contains enough high-intensity residual pixels to represent visible contour/silhouette/shape drift, even if global mean and local samples pass.

If the failing candidate is a hand-authored SVG and the reference has a clean separable foreground silhouette, repair through component-level traced SVG before PNG fallback. Use the normalized reference or prepared foreground mask to trace the real component, preserve intentional holes/counters in one SVG or compound path, run `geometry-audit`, regenerate from the spec, and rerun `verify --reference`. Only select PNG fallback after this traced SVG candidate is rejected by path noise, excessive complexity, background residue, semantic drift, material contamination, or repeated reference-gate failure. Do not treat a hand-authored path miss as proof that SVG is unsuitable.

Rounded app-mask or frame residuals are handled separately. The visual delta gate scales the outer frame gutter to the canvas size for the hard foreground-shape decision and records `frame_or_rounded_mask_residual_dominated` only when the full-canvas residual is mostly from the app-icon edge and is distributed across multiple outer edges. Treat that as frame/mask normalization evidence, not a foreground repair blocker. If the interior gate fails after the frame gutter is removed, or if the high-delta frame evidence is localized to one edge where the subject touches the canvas, repair the foreground or background geometry as usual.

If a repair makes the mean worse, inspect overlay/diff before undoing or changing route. A worse mean can still reveal that the previous hypothesis was wrong, such as mistaking scale drift for horizontal translation or background drift for foreground mismatch. Preserve the lesson in the next spec change rather than oscillating between broad tweaks.

Numeric pass is not enough for repeated rounded geometry. For bars, panes, tiles, stacked plates, or slanted rounded panels, zoom the preview and inspect corners, joins, and repeated sibling shapes after the mean/local gates pass. A kinked corner, doubled curve, tiny notch, or tangent break is a geometry failure even when the reference mean is below target. Repair the semantic path and regenerate instead of adding rim/material helpers or choosing PNG only to hide the defect.

Numeric pass is also not enough for simple explicit components. For dots, rounded squares, capsules, pills, simple panes, rear echoes, second ears, and basic polygons, inspect the isolated asset and preview at high zoom. If a traced component has pixel-stepped sides, uneven corner tangents, tiny wiggles, micro-segments, bounds far outside its intended component bbox, or many commands for a shape that should be primitive-like, redraw it in the spec from the measured bbox/center/radius/color instead of accepting the trace. If a rear echo or second-ear trace imports background gradient, shadow, or a semi-transparent renderer region as foreground, treat the route as failed even when the mean delta passes. The repaired layer should have stable bounds, clean curves, low command count, `geometry-audit.status` `"ok"`, and no material helpers.

Geometry audit is not enough for smooth symbolic marks. For loops, chain links, knots, ribbons, mascot silhouettes, and brand-like contours, inspect `reference-side-by-side.png` for curve rhythm, mass consistency, terminal shape, and negative-space likeness. A path can have low command count, no meaningful micro-segments, and still look hand-drawn because the visual shape model is wrong. Treat that as `needs_repair` even when package structure, SVG material checks, and local samples pass.

For component-level bitmap vectorization, a strict numeric pass proves only that the locally traced component paths match the supplied bitmap preview. It does not prove official/source-vector brand identity. Keep the package in `visually-close` or `review_required` unless the user, a human, or an independent reviewer accepts the semantic approximation. A low-risk generated concept with no external brand identity may be `exact-enough` when the traced SVG preserves the selected concept, passes geometry/reference/asset gates, and records that basis in `source_analysis` and `semantic_review`. Still require clean SVG assets, `geometry-audit` without meaningful path-noise warnings, `svg_material_warnings` empty, all `png_layer_hygiene` entries passing, side-by-side/overlay/diff inspection, and `source_analysis.components[]` coverage for every traced component.

If `svg_material_warnings` is non-empty, do not claim completion from a numeric pass. Remove the material expression from the imported foreground SVG. Typical repairs are removing highlight strokes, deleting opacity overlays, flattening bevel/glow/shadow helpers into the base silhouette, and leaving Liquid Glass/refraction/specular behavior to Icon Composer.

For Icon Composer semantic remakes, interpret `10-20` mean delta as a review range, not an automatic failure, when all of these are true:

- `local_sample_gate.status` is `"ok"`
- overlay inspection shows the main silhouette, spacing, and layer placement are close
- row/column edge sampling confirms any disputed shape edge is not materially misplaced
- `.icon/Assets` remains clean semantic SVG or justified clean PNG layers
- the diff is mostly baked material difference: glass, bevel, shadow, glow, edge lighting, or local renderer shading

Keep that candidate in `review_required` or record explicit accepted-approximation evidence; do not call it strict reproduction and do not rasterize it solely to lower the mean delta.

For rendered references with strong glass, bevel, glow, shadows, or edge lighting, it is acceptable to rerun verification with a looser semantic target such as `--max-mean-delta 15` after the route is already clean:

```bash
npm --prefix scripts run verify -- --out "${PWD}/build/my-icon" --reference "${PWD}/build/reference-1024.png" --max-mean-delta 15
```

Use that only to classify a semantic candidate. It does not override `svg_material_warnings`, dirty PNG hygiene, obvious geometry drift, or missing acceptance evidence.

For Icon Composer semantic remakes, a higher mean delta can still be the better product when the editable SVG preserves the intended style, proportions, and layer semantics better than a low-delta PNG fallback. If the user, a human, or a separate independent visual review accepts that semantic result, record `semantic_review.status: "accepted-approximation"` and keep the strict pixel miss as evidence rather than forcing a PNG fallback. Do not call it exact reproduction. When the reference mean delta is `> 15`, the acceptance evidence must explicitly cover whole-icon likeness and the looser material boundary; otherwise repair geometry, palette, or route selection first.

The reverse is also true: a clean semantic package can pass the strict mean target while still requiring review. If the source is bitmap-only, identity-sensitive, or a platform-rendered final icon, use the pass as evidence that geometry and palette are close, then keep `semantic_review.status` honest. Do not promote `visually-close` to `exact-enough` just because the remaining difference is mostly deferred platform material or because the mean is below `10`.

For a selected `png-fallback` route, completion requires route inspection, not only numeric success. The verifier keeps `png_fallback_selected` in `review_required` until the PNG layer hygiene is clean, the reference target passes when applicable, and `visual-review.json` records an accepted independent or human visual decision. A clean PNG fallback that passes reference gates should be reported as review-required, not as a strict failure. A self-authored main-agent or batch-harness visual pass is evidence to inspect, not acceptance. This makes the raster route explicit without encouraging PNG as the default.

Treat numeric repair as a regression if the mean delta improves but the icon looks worse, loses the user-approved visual direction, or reduces an acceptable editable SVG to an unnecessary raster layer. Compare every repair against the previous best visual candidate, not only against the reference metric.

For geometry polish, use `polish-svg-geometry` as a guardrail around candidate smoothing:

```bash
npm --prefix scripts run polish-svg-geometry -- --input "${PWD}/build/my-icon/layers/02-mark.svg" --out "${PWD}/build/my-icon/tmp/work/02-mark-polished.svg" --report "${PWD}/build/my-icon/tmp/reports/geometry-polish-report.json" --candidate-out "${PWD}/build/my-icon/tmp/work/geometry-polish-candidate.svg"
```

Accept the candidate only when all are true:

- `geometry-polish-report.json.decision` is `"accepted"`
- the candidate still satisfies `source_analysis.must_preserve` and `must_not_add`
- bbox, centroid, visible-area, and rendered mean-delta guardrails did not reject it
- the polished path was written back into the spec and the package was regenerated
- final `verify --reference` still passes the package gates, local sample gate, SVG material gate, and visual side-by-side/overlay/diff inspection

Reject or discard geometry polish when the report says `rejected_kept_original`, when it rounds off intentional corners, changes terminal shape, closes an intended opening, shifts negative space, or makes the icon a cleaner but different mark.

For Icon Composer/Liquid Glass tasks, a low reference mean delta from a source-cut PNG fallback is only a raster-fidelity result. It does not prove the `.icon` bundle is usable after Icon Composer adds glass/refraction/material. Inspect isolated foreground assets. Clean authored PNG layers are valid when they contain only the intended flat color, linear gradient, text/raster, or deliberate artwork; prefer semantic SVG/base geometry whenever the PNG contains baked lighting, hard matte, rectangular edges, or source-background fragments.

For identity-sensitive work, add a semantic review after numeric and visual checks. Ask whether the generated mark is still the same mark: stroke continuity, negative-space shape, distinctive terminals, letterform identity, mascot/subject identity, and required spacing. For letter-like marks, verify whether required bars, missing bars, open counters, joins, and terminal shapes match the reference. Adding a forbidden stroke or replacing a distinctive letterform with a generic glyph is a semantic failure, not a minor style drift. If it is only an approximation, keep the package useful but label it `visually-close`, `redesign-needed`, `needs-source-vector`, or `png-fallback-recommended` in `semantic_review`.

For any identity-sensitive package, verify that `source_analysis.must_preserve`, `must_not_add`, `components`, and `acceptance_checks` still describe the generated layers. If a known forbidden feature appears, write a rejected `visual-review.json` and rerun verification instead of relying on the mean delta:

```json
{
  "decision": "rejected",
  "reviewer": "independent_visual_review",
      "evidence": ["reference-side-by-side.png", "reference-overlay.png", "reference-diff.png"],
  "failures": ["forbidden_feature_present"],
  "notes": "numeric pass cannot override a visual semantic rejection"
}
```

Use `accepted-approximation` only after explicit acceptance evidence is recorded. User or human acceptance requires `acceptance.accepted_by`, `acceptance.evidence`, and `acceptance.scope` in the spec. Independent visual acceptance also requires a sibling `visual-review.json` with an accepted decision such as `accepted`, `approved`, `accepted-approximation`, or `complete-candidate`; the authoring/repair agent must not self-approve the approximation.

Independent visual acceptance must evaluate the whole icon, not just isolated constraints. It should explicitly compare overall silhouette, proportions, element placement, mass/weight, baseline, spacing rhythm, and required source identity. If it only proves one local rule, such as a missing crossbar or the presence of a dot, keep the package in review or reject it.

For multiple generated icons, run:

```bash
npm --prefix scripts run summarize-run -- --root "${PWD}/build/icon-run" --out "${PWD}/build/icon-run-summary.json"
```

Use `counts.route_status`, `counts.source_contract`, `counts.visual_decision`, and each row's `recommended_action` to decide the next repair batch. Do not use `counts.status.ok` as a completion count when any row has `review_required: true`, missing source contracts, or rejected visual decisions.

Also read `run_red_flags`. If it contains `png_fallback_dominates_run`, `png_assets_dominate_run`, or `pixel_ok_but_review_required`, the batch must not be reported as complete until route review proves the PNGs are clean authored assets or accepted raster fallbacks. Treat it as evidence for route decisions, SVG redraw, source-vector requests, or explicit user acceptance.

## Diagnostic Metrics

The verifier writes `reference_comparison.diagnostics` when the generated PNG and reference PNG have the same dimensions.

Use these fields to decide where to inspect next:

- `pixel_delta.p95_mean_rgb_delta` and `p99_mean_rgb_delta`: whether the error is broad or limited to small hot regions.
- `pixel_delta.pct_pixels_mean_rgb_gt_10/25/50`: how much of the canvas visibly differs.
- `pixel_delta.high_delta_region`: bounding box and centroid for pixels above the high-delta threshold.
- `alpha_delta`: whether opacity or transparent-edge differences are contributing.
- `tile_heatmap.top_tiles_by_mean`, `top_tiles_by_p95`, and `top_tiles_by_max`: 8x8 regions most worth inspecting. `top_tiles_by_max` is useful for tiny localized mistakes that are too small to affect a tile percentile.

These fields are `diagnostic_only` and `not_a_gate`. They must not replace the reference mean delta target, side-by-side/overlay/diff inspection, or layer semantics. A hot tile should lead to a concrete repair hypothesis, such as background fill, mark geometry, text/brand fidelity, transparent edge cleanup, or a documented per-layer PNG fallback.

## PNG Fallback Hygiene

PNG fallback checks are separate from reference comparison. A final composite can match the reference while an imported PNG foreground layer still contains background haze, unintended gradient residue, rectangular remnants, or material from the source screenshot. Icon Composer glass can reveal that residue later.

A clean PNG layer is allowed Icon Composer material when it is intentionally authored and remains clean in isolation: transparent outside the intended foreground, or intentionally full-canvas only for a background-like layer; no hidden source-background residue; no copied glass/shadow/glow unless the route explicitly accepts raster material; and visible content limited to the intended flat color, linear gradient, text/raster content, dense brand mark, or custom gradient.

The verifier writes `png_layer_hygiene` for every PNG `.icon/Assets` entry and fails foreground PNG fallbacks that touch the canvas edge or contain visible pixels inside the edge gutter. Background-like layers are exempt because they are allowed to cover the canvas.

For every foreground PNG fallback:

- inspect the PNG layer itself on transparent/checker or neutral backgrounds
- require concrete `png_fallback_evidence` for non-text foreground PNG fallbacks; the evidence must explain the category, SVG route, per-layer failure/unsuitability, and isolated PNG cleanliness check
- reject full-canvas bounds for foregrounds, visible edge pixels, background haze, dirty antialiasing, or material that belongs to Icon Composer
- if the source is dark artwork on a light background, rebuild the matte with `prepare-bitmap-layer`
- if the source is light artwork on a dark/complex rendered background, rebuild the foreground with `prepare-foreground-layer` so isolated highlights and background glints are excluded
- if the foreground cannot be separated cleanly from a rendered gradient, glass, shadow, or background, redraw the layer as semantic SVG instead of importing the dirty PNG

Do not treat a passing mean delta as Icon Composer readiness when `png_layer_hygiene` fails or the PNG fallback looks contaminated.

Do not treat passing edge hygiene as sufficient. A foreground PNG can avoid canvas edges while still containing baked glow, shadow, white matte, hard opaque source residue, or horizontal rectangular source-background residue inside its bounds. If `warnings` mentions no semi-transparent edge pixels or a suspicious rectangular block with opposing straight edges, inspect the isolated asset and tighten extraction, clean the local residue by pixel content, split background-like layers, or redraw as SVG. A single legitimate straight edge, flat fill, or linear gradient should not be treated as residue by itself.

When a user provides Icon Composer screenshots showing Liquid Glass artifacts, treat those screenshots as a visual rejection of the PNG fallback route. Write or preserve a rejected `visual-review.json` for the affected package, then redraw as SVG/base semantic layers or ask for acceptance of a raster-only result.

## Local Sample Diagnostics

When the reference and generated icon are the same size, the verifier writes a fixed 3x3 grid of local window samples under `reference_comparison.local_samples`.

Each sample is a 9x9 window centered at a stable normalized point:

```text
top_left, top, top_right
left, center, right
bottom_left, bottom, bottom_right
```

Use the report to locate likely repair regions:

- high corner or edge samples usually indicate background, gradient, border, or platform-frame drift
- high center or adjacent samples often indicate primary mark color, size, or placement drift
- high p95/max values with low mean can indicate an edge, cutout, antialiasing, or local hotspot

Most local sample values are diagnostics. They can miss small features and can be noisy near antialiased edges. The verifier only fails the package when a sample is severe on both mean RGB delta and p95 pixel mean RGB delta. Use non-gating samples after inspecting `reference-side-by-side.png`, `reference-overlay.png`, and `reference-diff.png`, and translate the finding into an action:

- geometry drift: edit semantic SVG path points or curves
- fill drift: adjust `icon.json.fill` or foreground base color
- material drift: hand off to Icon Composer unless identity fidelity requires a PNG fallback
- text/complex logo/raster drift: consider a per-layer PNG fallback with a recorded reason

Do not use a local sample mismatch as permission to add fake highlights, bevels, shadows, blur, or decorative strokes to imported SVG assets.

If `local_sample_gate.status` is `"failed"`, do not claim completion from the global mean. Inspect the listed `severe_samples` and repair likely position, scale, shape, or major foreground/background mismatch. This gate exists for cases where a small white-on-black or logo alignment error is visually obvious but too small to push the full-image mean above `10`.

## Shape Facts Diagnostics

Use `shape-facts` when side-by-side/overlay review is too subjective for a vector-friendly mark and you need reproducible structure facts:

```bash
npm --prefix scripts run shape-facts -- --reference "${PWD}/path/to/reference.png" --candidate "${PWD}/build/my-icon/my-icon.preview.png" --out "${PWD}/build/my-icon/tmp/reports/shape-facts.json"
```

The report is diagnostic and not a completion gate. It is useful for:

- foreground component count
- edge-touching artifact count for app-mask highlights or canvas remnants
- large hole/cutout count and bbox
- primary bbox, centroid, and area drift
- horizontal and vertical scanline interval drift
- `interior_scanlines`, which ignore edge-touching components when full-canvas scanlines are polluted by reference highlights or canvas artifacts
- `comparison.summary`, which gives the component deltas and full/interior scanline max endpoint drift before the full detailed line list

Interpretation:

- required component or hole missing: usually a blocker or wrong shape model
- large bbox/centroid drift: repair scale, placement, or primary silhouette
- full scanline endpoint drift with stable `interior_scanlines`: inspect edge artifacts before changing the foreground mark
- interior scanline endpoint drift: repair the specific SVG edge or negative-space boundary
- separable foreground components on simple backgrounds: run with an explicit background color when thresholding is reasonable, then read `comparison.summary.interior_scanline_drift`; high full-canvas drift with stable interior components usually means platform rim/material drift rather than foreground geometry drift
- facts pass but the mark still looks hand-drawn or semantically wrong: keep review open
- facts fail on Liquid Glass, glow, bevel, text, dense logos, mascots, or antialiased edges: treat the report as a hypothesis and use source-analysis judgment, clean PNG fallback, or source-vector escalation

Do not tune a candidate only to satisfy scanlines. Re-run `author-icon` and `verify --reference` after any SVG repair, then inspect side-by-side, overlay, diff, `.icon/Assets`, and `package-verification.json` again.

## Localized Geometry Repair

Use this when the overlay shows one region that is visibly wrong even though the package passes the numeric target.

Repair order:

1. Identify the visual region in `reference-overlay.png`, such as a protruding right edge, mismatched endpoint, incorrect corner angle, or misplaced inner cutout.
2. Decide whether the mismatch is geometry or material. If the reference differs mainly in highlight, bevel, shadow, blur, or Liquid Glass behavior, do not edit `.icon/Assets` SVGs to match it.
3. For real geometry drift, edit the semantic source path points or curve controls. Keep the imported SVG as a clean shape layer.
4. If a preview-only shadow/material helper layer duplicates the same silhouette, update that helper path at the same time so local preview evidence stays aligned with the source layer.
5. Regenerate, rerun `verify --reference`, and inspect the new overlay, diff, and local samples. Prefer a smaller localized shape error even when the overall delta changes only slightly.

For edge disagreements that are hard to judge by eye, use a temporary pixel-sampling check with the generated PNG and reference PNG:

- sample rows for left/right edge drift or columns for top/bottom drift
- restrict sampling to the problem region instead of the whole canvas
- use a simple alpha/luminance threshold to find foreground extents
- compare `min`, `max`, and pixel counts between reference and generated output
- translate the measured drift back into path endpoint/control-point edits

Do not turn edge sampling into a permanent report or a substitute for visual review. It is a debugging aid for path repair.

When a path repair makes the mean delta or visual result worse, treat it as a route regression. Preserve or restore the previous best candidate, then revisit the shape model before editing more path points. A common mistake is treating an open form as a compound cutout, or treating a connected ribbon as disconnected fragments; fix the visual semantics before tuning coordinates.

## Spec Package Verification

For `author-icon`, verify:

```text
<delivery-name>.preview.svg
<delivery-name>.preview.png
<delivery-name>.svg
<delivery-name>.png
<delivery-name>.origin.png or <delivery-name>.origin.svg, when source evidence exists
layers/*.svg or *.png
<Name>.icon/Assets/*.svg or *.png
<Name>.icon/icon.json
apple/<platform>/<rendition>.png, when macOS Icon Composer ictool is available
tmp/reports/style-report.json
tmp/reports/package-verification.json
tmp/README.md
tmp/work/spec.json
tmp/work/<repair scratch and candidates>
```

Each icon directory must keep preview/app outputs, source evidence, and optional rendered Apple PNG products separate from the Apple `.icon` bundle.
In delivery layout, `author-icon` preserves existing `tmp/work/` files and `<delivery-name>.origin.png`/`<delivery-name>.origin.svg` when rerun, and overwrites only the copied `spec.json`; reports under `tmp/reports/` are regenerated verification evidence.

Check:

- `.icon` bundle name is UpperCamelCase
- `style-report.json.preview_svg` and `preview_png` exist and are the rounded local visual contract
- `style-report.json.app_svg` and `app_png` exist and are unrounded app/source canvas outputs
- `generated_files_manifest_validation.status` is `valid`; `generated_files` is the normalized leaf ownership manifest, and `generated_directories` is derived from those leaves rather than trusted for recursive deletion
- `style-report.json.apple_exports` records `"generated"` with requested profiles and exact `apple/` paths, or `"skipped"` with a reason. iOS/macOS exports are six 1024px appearance variants; watchOS is one 1088px Default export. `source-package` uses the skip reason `not-requested-for-source-package` and reports `platform_render_not_requested`; other skipped exports report `platform_review_pending` without failing the structural package.
- `apple_exports_validation` confirms the reported platform/profile/rendition matrix, PNG readability, and dimensions. Missing, extra, corrupt, or wrong-size rendered files are package failures and report `platform_render_invalid`.
- when Apple exports are valid, inspect every exact file and record both `visual-review.json.platforms_inspected` and `visual-review.json.renders_inspected`; keep that evidence with the optional Apple adapter
- if a user source, reference, or generated concept drove the package, exactly one selected root `.origin.png` or `.origin.svg` exists as source evidence, while unselected candidates stay under `tmp/work/`
- app/source outputs do not contain the preview clipping mask
- source `layers/*.svg` or `layers/*.png` are in bottom-to-top visual order, while `.icon/icon.json.groups[].layers` is in front-to-back Icon Composer display order so overlapping foreground layers render correctly
- PNG fallback source layers are readable PNG files and map to PNG Icon Composer assets
- `style-report.json` records whether `.icon/Assets` uses SVG or PNG
- `style-report.json` includes a per-layer SVG/PNG decision table with source layer, reason, editability impact, and text handling
- non-text foreground PNG fallback decisions include `png_fallback_evidence`; generic reasons like "preserve antialiasing and brand geometry" are not accepted
- `style-report.json.source_analysis` exists for identity-sensitive approximations and covers every included Icon Composer layer
- if `semantic_review.route` is `semantic-svg` or `semantic-svg-approximation`, `.icon/Assets` includes an SVG foreground layer; a PNG-only foreground package is a PNG fallback route, not an SVG-first package
- component-level bitmap vectorization records local bitmap segmentation/vectorization in `semantic_review.notes` or `source_analysis.components[].spec_constraints`, and each traced layer passes `geometry-audit` without meaningful warnings
- simple backgrounds are omitted from `.icon/Assets` and represented by `icon.json.fill`
- `icon.json.fill` uses one of: `"automatic"`, `{ "automatic-gradient": ... }`, `{ "solid": ... }`, or `{ "linear-gradient": [two stops], "orientation": ... }`
- `icon.json.fill` matches the visual background route. If a local background layer is preview-only, check `.icon/icon.json.fill` directly so a correct preview PNG does not hide an incorrect Icon Composer background.
- complex backgrounds that must be imported are bottom layers and are marked with `background_role: "complex"` in the Icon Composer decision record
- a marked complex background cannot be the only imported asset; one full-canvas rendered PNG is a baseline snapshot, not a layered Icon Composer composition
- no imported `.icon/Assets/*.svg` contains `<text>`, `<image>`, filters, masks, clip paths, `foreignObject`, `script`, external hrefs, or full-canvas rounded app masks
- imported `.icon/Assets/*.svg` do not contain baked Liquid Glass/material simulation such as highlight strokes, bevel strokes, blur, shadow filters, or decorative edge glints
- `package-verification.json.svg_material_warnings` is empty; imported-SVG material risks must be repaired before completion
- any accepted geometry polish has a `geometry-polish-report.json` showing `"decision": "accepted"` and the regenerated package still passes source-analysis, side-by-side/overlay/diff, local sample, and SVG material checks
- any local source SVG that contains `<text>` maps to a PNG `.icon/Assets` entry and records `text_rendering.font_family` plus `text_rendering.render_method`
- embedded bitmap sources are emitted as `layers/*.png` and map to a PNG `.icon/Assets` entry
- no generated `layers/*.svg` wraps an embedded bitmap with an absolute `<image href>`; use a `png` source path so the package emits a `layers/*.png` source layer instead
- when a layer spec uses `composer.format: "png"`, only that layer's `.icon/Assets` entry switches to PNG; source evidence remains in `layers/` as SVG for text/vector sources or PNG for embedded bitmap sources
- bitmap fallback layers made from light-background artwork have clean alpha matte sources, not white-contaminated transparent pixels
- foreground PNG fallback assets have clean transparent bounds; `package-verification.json.png_layer_hygiene` has no failures, and the agent inspected the PNG layer itself for background residue
- `package-verification.json.warnings` is empty; hard-opaque or rectangular-residue PNG fallback warnings must be resolved before completion
- selected `png-fallback` routes have an accepted human or independent `visual-review.json` before being treated as complete
- strict reference-driven work includes `reference-side-by-side.png`, `reference-overlay.png`, `reference-diff.png`, a `reference_comparison.status` of `"compared"`, a passing `max_mean_delta` target, `visual_delta_gate.status: "ok"`, and `local_sample_gate.status: "ok"` when the reference is the same size as the generated icon
- smooth symbolic SVGs have been inspected for hand-drawn appearance, inconsistent curve rhythm, width drift, terminal drift, and wrong negative-space structure; a clean `geometry-audit` is not sufficient
- accepted Icon Composer semantic remakes explicitly record the strict pixel target as deferred/accepted, preserve the user-approved SVG/PNG route, and do not promote a lower-delta repair that looks worse
- brand/text/symbol reproduction includes `style-report.json.semantic_review` with an honest fidelity status; do not call an approximation exact just because the numeric gates pass
- `package-verification.json` reports `status: "ok"`
- `package-verification.json.outcome.review_required` is the verification gate; do not claim completion while it is `true`
- `package-verification.json.visual_review` records an accepted applicable reviewer decision; rejected or missing visual acceptance is a blocker even when pixels pass
- optional Apple renders remain export evidence, not a separate platform-completion state machine

Do not generate `preview.html` for normal output.
