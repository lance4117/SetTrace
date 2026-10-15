# Failure Modes

Use this as a triage index after a generated package fails review, verifier output is confusing, or a repair loop starts making the icon worse.

## Contents

Source and route:

- [Reference Is Treated As A Trace Target](#reference-is-treated-as-a-trace-target)
- [Strict Raster Replication Is Used As The Default Mode](#strict-raster-replication-is-used-as-the-default-mode)
- [Source Contract Is Missing Or Ignored](#source-contract-is-missing-or-ignored)
- [Generic Skill Becomes A One-Off Fixture](#generic-skill-becomes-a-one-off-fixture)

Layer and asset hygiene:

- [Layer Package Becomes Raster-Like](#layer-package-becomes-raster-like)
- [Pixel-Perfect Source-Cut PNG Batch Fails In Icon Composer](#pixel-perfect-source-cut-png-batch-fails-in-icon-composer)
- [PNG Fallback Reason Is Generic](#png-fallback-reason-is-generic)
- [Bitmap Fallback Has Dirty Edges](#bitmap-fallback-has-dirty-edges)
- [Light Foreground Extraction Captures Background Highlights](#light-foreground-extraction-captures-background-highlights)
- [PNG Fallback Carries Background Residue](#png-fallback-carries-background-residue)
- [Whole Icon Is Imported As One PNG](#whole-icon-is-imported-as-one-png)
- [Edge Hygiene Passes But The PNG Is Still Dirty](#edge-hygiene-passes-but-the-png-is-still-dirty)

Semantics and geometry:

- [Pixel Similarity Improves But Design Quality Drops](#pixel-similarity-improves-but-design-quality-drops)
- [Pixel Similarity Passes But Identity Semantics Fail](#pixel-similarity-passes-but-identity-semantics-fail)
- [Accepted Approximation Is Self-Promoted](#accepted-approximation-is-self-promoted)
- [Accepted Approximation Proves Only One Local Constraint](#accepted-approximation-proves-only-one-local-constraint)
- [Bitmap Trace Masquerades As SVG](#bitmap-trace-masquerades-as-svg)
- [Component Vectorization Is Overused](#component-vectorization-is-overused)
- [Public SVG Substitution Hides The Real Task](#public-svg-substitution-hides-the-real-task)
- [SVG Looks Hand-Drawn Despite Clean Audit](#svg-looks-hand-drawn-despite-clean-audit)
- [Localized Geometry Drift Is Left Unfixed](#localized-geometry-drift-is-left-unfixed)
- [Rounded Panel Corners Are Pieced Together](#rounded-panel-corners-are-pieced-together)
- [Platform Style Overrides The User's Mark](#platform-style-overrides-the-users-mark)
- [Path Repair Uses The Wrong Shape Model](#path-repair-uses-the-wrong-shape-model)

Icon Composer material and fill:

- [Liquid Glass Is Baked Into Source SVG](#liquid-glass-is-baked-into-source-svg)
- [Icon Composer Shows An Extra Outline Or Duplicate Layer](#icon-composer-shows-an-extra-outline-or-duplicate-layer)
- [Preview Recreates Exported Icon Composer Material](#preview-recreates-exported-icon-composer-material)
- [Unrequested Icon Frame Appears](#unrequested-icon-frame-appears)
- [Preview Background And Icon Composer Fill Drift Apart](#preview-background-and-icon-composer-fill-drift-apart)

Verification:

- [Renderer-Specific Success](#renderer-specific-success)
- [Unsafe Output Replacement](#unsafe-output-replacement)
- [Verification Overfits The Reference](#verification-overfits-the-reference)
- [Diagnostic Metrics Become A New Score To Game](#diagnostic-metrics-become-a-new-score-to-game)
- [Shape Facts Become A Completion Gate](#shape-facts-become-a-completion-gate)
- [Reference Evidence Is Skipped](#reference-evidence-is-skipped)
- [Reference Target Is Not Enforced](#reference-target-is-not-enforced)
- [Strict Pixel Target Fails But Semantic Candidate Is Good](#strict-pixel-target-fails-but-semantic-candidate-is-good)

## Reference Is Treated As A Trace Target

Symptoms:

- generated paths mirror exact source coordinates
- output feels copied instead of inspired
- layer geometry is too detailed to edit comfortably

Action for a loose style/taste reference: simplify the forms and preserve only the transferable design language, such as folded ribbon structure, sparse geometry, calm background, and refined gradients. Do not apply this advice to a user-owned brand mark or existing app icon: there, preserve identity-defining silhouette, spacing, negative space, color role, and typography unless the user explicitly asks for redesign.

## Layer Package Becomes Raster-Like

Symptoms:

- too many layers
- many tiny fragments
- SVGs depend on visual residue instead of clear shape decisions
- source-cut PNG fallback is used before proving SVG is unsuitable for the layer
- most or all foreground layers become PNG only because it lowers reference diff
- `semantic_review.route` says `semantic-svg`, but every foreground import in `.icon/Assets` is PNG
- batch summary has `run_red_flags` such as `png_fallback_dominates_run` or `pixel_ok_but_review_required`

Action: reduce the package back to a few semantic foreground layers. Start from SVG for vector-friendly geometry. Use PNG only as a documented clean per-layer material for flat color, linear gradient, text, embedded raster, complex brand geometry, renderer artifacts, or strict fidelity that SVG cannot preserve. Do not build a tracing platform inside this workflow.

## Pixel-Perfect Source-Cut PNG Batch Fails In Icon Composer

Symptoms:

- reference mean delta is below `10` for most or all icons
- Icon Composer Liquid Glass shows rectangular crop seams, hard matte edges, doubled lighting, dirty slices, or source-background residue
- the package uses source-cut PNG foregrounds or complex background plates to match a rendered reference
- `review_required` is true, but the result was treated as complete because `status` is `ok`

Action: treat the dirty source-cut PNG route as visually rejected. Keep the pixel-perfect output only as evidence. Rebuild the affected icons in `icon-composer-semantic` mode with SVG/base foreground shapes or clean authored PNG layers, plus Icon Composer fill/material handoff. Do not continue optimizing a contaminated PNG cutout to improve diff.

## Strict Raster Replication Is Used As The Default Mode

Symptoms:

- the user asks for Icon Composer or Liquid Glass output, but the agent optimizes for strict pixel reproduction first
- generated `.icon` bundles are mostly `png_fallback_selected`
- source-rendered lighting, bevels, shadows, or glass are copied into imported assets
- the agent reports success from `reference-overlay.png` and `reference-diff.png` without checking the imported assets in Icon Composer or isolated neutral backgrounds

Action: switch back to `icon-composer-semantic` mode. Use the reference for geometry and palette decisions, not as a full-icon trace target. Guarded component-level vectorization is still allowed for named, cleanly separable foreground components. Prefer SVG and simple canvas fills for vector-friendly layers; use PNG for clean flat/linear-gradient raster layers, text, dense brand geometry, embedded raster, renderer artifacts, or an accepted raster fallback.

## PNG Fallback Reason Is Generic

Symptoms:

- the reason says only "preserve source antialiasing", "brand geometry", or "visual fidelity"
- `png_fallback_evidence` is missing for a non-text foreground PNG layer
- batch generation applies the same PNG fallback reason to many unrelated icons

Action: treat the package as unfinished. Either redraw the layer as semantic SVG, or record concrete `png_fallback_evidence` with category, SVG route, per-layer evidence, and isolated PNG cleanliness check. Do not let a generic reason or batch self-review complete the package.

## Named Output Is Blank Or Misrendered

Symptoms:

- preview PNG is missing or empty
- local icon output is missing `<delivery-name>.preview.svg`, `<delivery-name>.preview.png`, `<delivery-name>.svg`, or `<delivery-name>.png`
- gradients are not visible

Action: rerun the Node authoring command, check the output path, and verify the generated package again.

## Pixel Similarity Improves But Design Quality Drops

Symptoms:

- the icon matches a reference more closely
- silhouette, palette, or spacing gets uglier
- the mark becomes unreadable at small sizes

Action: for loose style references, prefer design quality and editability over reference closeness. For user-owned marks or existing app icons, preserve identity while simplifying only what is needed for Icon Composer.

## Pixel Similarity Passes But Identity Semantics Fail

Symptoms:

- mean delta is below `10` and `local_sample_gate.status` is `"ok"`
- the generated mark is only a generic approximation of the supplied brand, letter, mascot, knot, loop, or symbol
- continuous strokes, negative-space relationships, terminals, or letterform identity differ from the source
- `semantic_review` is missing or claims `exact-enough` without explaining the fidelity basis

Action: do not call the package an exact reproduction. Decide whether the right route is a more faithful semantic SVG redraw, a clean PNG fallback for the identity-sensitive layer, a request for an owned/official user-approved source vector, or an explicit accepted approximation. Record the result in `semantic_review` as `visually-close`, `needs-source-vector`, `png-fallback-recommended`, or `redesign-needed`.

## Bitmap Trace Masquerades As SVG

Symptoms:

- the foreground asset is technically SVG, but its edges show pixel stair-steps from the rendered bitmap source
- `geometry-audit` reports excessive path commands, many micro-segments, or line-heavy curves for a simple smooth brand mark
- stronger smoothing either leaves the edge noisy or changes the mark identity
- the preview looks worse than the reference even though the layer is editable
- a direct `potrace` result preserves anti-aliased soft edges, app-mask rim glow, or background edge residue as part of the foreground silhouette

Action: treat the bitmap trace as a route failure, not a polishing problem. For simple non-branded silhouettes, rebuild a clean binary foreground mask before retracing: remove app-mask rim/glow and background residue, keep only named components and intentional holes, use conservative morphology plus blur/re-threshold to stabilize the contour, then run `potrace` again and compare before/after `geometry-audit`, side-by-side, overlay, and diff. For smooth brand marks, monograms, knots, and loop logos, use an owned source vector only when it is user-provided, generated-in-task, project-local, or official-user-approved; record provenance and alignment. If no owned clean source is available, semantically redraw the mark, improve the vectorization, use a clean PNG fallback, or record `needs-source-vector`/`accepted-approximation`. Do not download a public SVG to replace the generated/reference image, and do not claim Icon Composer-ready SVG quality just because the file extension is `.svg`.

## Component Vectorization Is Overused

Symptoms:

- the source has many small fragments, text, mascot details, or dense brand geometry, but the agent still tries to segment/vectorize every region
- vectorization creates dozens of paths, jagged interiors, dirty component boundaries, or fake layers
- the reference mean improves, but `.icon/Assets` become hard to edit or fail semantic review
- `source_analysis.components[]` does not map traced paths to real visual components

Action: stop treating vectorization as the default. Use component-level vectorization only for a few real foreground parts, or one clean continuous silhouette, that can remain clean SVG layers. For dense or identity-critical sources, switch to owned source vector, semantic redraw, clean per-layer PNG fallback, `needs-source-vector`, or explicit accepted approximation.

## Public SVG Substitution Hides The Real Task

Symptoms:

- a generated/reference icon is replaced with a public web SVG that was not provided or approved by the user
- the result becomes smoother, but no image-to-SVG conversion or semantic redraw problem was solved
- `source_analysis.components[].source_vector` points to a generic web URL or lacks provenance
- the output is presented as the skill succeeding on the user's generated icon

Action: reject the candidate as invalid evidence. Remove the unapproved source vector from the deliverable route. Rebuild from the user's image using semantic SVG authoring, guarded vectorization/Paper.js polish, or clean PNG fallback. If exact vector identity is required and cannot be derived honestly, mark `needs-source-vector` and ask for a user-owned or approved source asset.

## SVG Looks Hand-Drawn Despite Clean Audit

Symptoms:

- `geometry-audit` is `ok`, but `reference-side-by-side.png` shows a wobbly or guessed silhouette
- the SVG uses curves, yet curve rhythm, foreground width, terminals, or negative space do not match the reference
- the path is mathematically clean but visually reads like a hand sketch rather than an intentional icon mark
- a local repair lowers command count or removes micro-segments while making whole-icon likeness worse

Action: treat this as a shape-model failure, not an audit failure. Stop tuning isolated control points. Name the source model first, such as chain link, loop, ribbon, open form, compound cutout, or overlapping plates. Compare against the previous best visual candidate and the side-by-side/overlay evidence. Use reference measurements, component vectorization from the supplied bitmap, or a semantic redraw with consistent mass and negative space. Do not promote the result to `exact-enough` until mean/local gates pass and side-by-side inspection no longer reads as hand-drawn.

## Source Contract Is Missing Or Ignored

Symptoms:

- `semantic_review` says the icon is approximate, medium/high risk, or identity-sensitive
- `source_analysis` is missing, vague, or does not cover every included foreground layer
- the generated icon adds a forbidden feature, such as an unrequested stroke, inner frame, generic glyph, or dirty foreground residue
- summary output shows `source_contract: missing`

Action: stop repairing pixels and write a source contract first. Record `must_preserve`, `must_not_add`, component-to-layer mapping, and acceptance checks. Regenerate or repair against that contract, then rerun `verify`. If a generated candidate violates the contract, write a rejected `visual-review.json` so numeric success cannot hide the failure.

## Accepted Approximation Is Self-Promoted

Symptoms:

- the agent marks `semantic_review.status` as `accepted-approximation`
- there is no explicit user/human acceptance evidence and no independent accepted `visual-review.json`
- strict pixel target is missed but the package is described as complete

Action: keep the package in review. Add `acceptance.accepted_by`, `acceptance.evidence`, and `acceptance.scope` only when acceptance actually happened. If acceptance comes from an independent visual reviewer, also write `visual-review.json` with an accepted decision and reviewer evidence. Otherwise continue repair, change the route, or report the remaining decision instead of self-approving the approximation.

## Accepted Approximation Proves Only One Local Constraint

Symptoms:

- the reviewer accepts because one rule is satisfied, such as "no crossbar", "dot exists", or "foreground is editable"
- the whole icon still looks unlike the reference
- mean delta is `> 15`, but the report says material differences are the main issue without proving whole-form likeness
- proportions, mass, baseline, element placement, spacing rhythm, or silhouette differ from the source

Action: reject the candidate or keep it in review. Repair whole-icon likeness first, or get explicit acceptance evidence for the looser boundary. Any accepted high-delta approximation must cover the whole icon, not only one local rule, and must name the material/pixel tradeoff being deferred.

## Localized Geometry Drift Is Left Unfixed

Symptoms:

- overlay shows one edge, endpoint, corner, or cutout in the wrong place
- the numeric mean delta passes, but the icon still looks visibly wrong
- the agent tries to hide the mismatch with darker fills, stronger shadows, highlights, or bevel strokes

Action: fix the semantic path. Use overlay inspection first, and use temporary row/column edge sampling when the error is hard to quantify. Update duplicated preview-only shadow silhouettes with the same path change, then rerun reference verification.

## Rounded Panel Corners Are Pieced Together

Symptoms:

- a rounded bar, pane, tile, or slanted panel corner looks like two curves are stacked
- the path uses tiny line segments plus multiple `Q`/`C` fragments where one continuous corner should exist
- reference mean delta is below target, but an enlarged preview shows a notch, kink, doubled rim, or tangent break
- only one repeated panel was repaired while sibling panels still use the old geometry language

Action: rewrite the affected shape family as clean semantic panel paths. Use straight commands for intentional straight sides and continuous `C` or aligned `Q` curves for rounded transitions. Apply the same path model to repeated panels, regenerate from the spec, rerun `verify --reference`, and inspect the enlarged preview/overlay. Do not hide the defect with material, strokes, shadows, or PNG fallback unless SVG is genuinely unsuitable.

## Platform Style Overrides The User's Mark

Symptoms:

- Apple-style background, gradient, border, or roundness changes the user's requested identity
- a brand/logo reference becomes a generic app-icon concept
- the output is "premium" but no longer matches the supplied mark, typography, or proportions

Action: restore the user-owned silhouette, spacing, color role, and text fidelity first. Apply Apple/Icon Composer adaptation only to layer structure, import format, canvas fill, and material handoff.

## Liquid Glass Is Baked Into Source SVG

Symptoms:

- `.icon/Assets/*.svg` contains white highlight strokes, bevel strokes, edge glints, blur, shadow filters, or fake refraction paths
- the local PNG gets closer to a screenshot, but the Icon Composer package becomes harder to tune
- the SVG source looks like a rendered material snapshot instead of an editable shape layer

Action: simplify imported SVG assets back to semantic base shapes and colors. Put Liquid Glass behavior in `icon.json`/Icon Composer settings where possible. If exact material fidelity is more important than editability, switch only that layer to a PNG import and record the reason.

## Icon Composer Shows An Extra Outline Or Duplicate Layer

Symptoms:

- the imported SVG asset is clean, but Icon Composer shows a blue, dark, or offset rim around the mark
- local `<Name>.preview.png` does not show the rim
- `.icon/icon.json` contains default `shadow`, `glass`, translucency, specular, or other material settings that were not requested

Action: remove default material settings from `icon.json`. Keep the imported SVG as a clean semantic shape and let the user enable Icon Composer material behavior intentionally.

## Preview Recreates Exported Icon Composer Material

Symptoms:

- the reference image already appears to be an Icon Composer/platform-exported final icon
- local preview adds rim, glow, bevel, shadow, border, or Liquid Glass-like helper layers to mimic that exported look
- the agent treats a flatter clean preview as suspicious even though geometry, fill, layer order, and assets are correct
- the `.icon` assets are clean, but preview/overlay now hide the boundary between base geometry and platform material
- reference diff improves, but the preview no longer represents the actual base package the user will tune in Icon Composer

Action: remove the preview-only material helpers. Keep local preview to the clean base shape, base fill, and broad palette/background alignment. Record the rim/glow/bevel/shadow as deferred Icon Composer material in `source_analysis`; use overlay/diff to document the expected material delta instead of simulating it.

## Renderer-Specific Success

The local renderer proves only local SVG/PNG output rendering. Do not claim Icon Composer acceptance unless the user manually imports the assets and provides evidence.

## Bitmap Fallback Has Dirty Edges

Symptoms:

- imported PNG layer shows white halos or pale pixels around dark artwork
- inner cutouts look ragged after the background is removed
- the layer seems to include rectangular residue or contaminated antialiasing

Action: do not use fuzzy white-to-transparent cleanup. Rebuild the bitmap as a matte with `prepare-bitmap-layer`, where luminance becomes alpha and the visible RGB is a clean foreground color.

## Light Foreground Extraction Captures Background Highlights

Symptoms:

- a bright logo on a dark rendered background extracts an unrelated corner glow, glass reflection, or gradient patch
- the isolated foreground PNG contains a small rectangular or soft bright remnant away from the intended mark
- reference diff improves, but the PNG fallback is not a clean foreground layer

Action: rebuild the foreground with `prepare-foreground-layer`, which keeps the largest light connected component and drops isolated highlights. Use `--region x,y,w,h` when the source has unrelated bright areas outside the mark. If the true foreground is split into multiple disconnected pieces, author separate PNG/SVG layers or redraw as SVG instead of accepting a dirty combined bitmap.

## PNG Fallback Carries Background Residue

Symptoms:

- final preview PNG matches the reference, but the isolated PNG fallback layer shows gradient haze, glass lighting, shadow, or background material
- `png_layer_hygiene` reports visible edge pixels, full-canvas bounds, or canvas-edge contact on a foreground PNG
- Icon Composer glass reveals diagonal seams, rectangular remnants, dirty corners, or source-background texture
- the agent claims success from `reference-overlay.png` and `reference-diff.png` without inspecting `.icon/Assets/*.png`

Action: treat the package as `needs-repair`. Inspect the PNG layer itself on transparent/checker and neutral backgrounds. If the foreground can be separated, rebuild a clean matte. If the contamination comes from inseparable rendered background, redraw the layer as semantic SVG or simplify the mark instead of importing the dirty PNG.

## Whole Icon Is Imported As One PNG

Symptoms:

- `.icon/Assets` contains only one full-canvas PNG
- the PNG is marked as a complex background but also includes the foreground mark
- reference diff is excellent, but Icon Composer cannot adjust background, material, or appearance modes independently
- `icon.json.fill` exists but is visually hidden by the full-artwork PNG

Action: do not call this an Icon Composer composition. Keep the selected full PNG as root `*.origin.png` source evidence, or keep extra comparison candidates under `tmp/work/`; never put it in `.icon/Assets`. Rebuild the `.icon` from `icon.json.fill` plus separated foreground SVG/PNG layers, or mark the task `needs-source-vector`/`needs-repair` when clean separation is not possible.

## Edge Hygiene Passes But The PNG Is Still Dirty

Symptoms:

- `edge_visible_pixels` is zero and the foreground does not touch the canvas edge
- reference mean delta passes, but the isolated `.icon/Assets/*.png` shows baked glow, shadow, white matte, or preview-only material inside its bounds
- the PNG is a hard opaque cutout with no semi-transparent edge pixels, so it passed structural checks but still looks wrong in Icon Composer
- the PNG has a horizontal rectangular visible edge or local strip from the source background, even though it does not touch the full canvas edge

Action: do not mark the package complete from metrics alone. Rebuild the layer with `prepare-foreground-layer --mode non-background`, `--mode light-on-color`, and tighter thresholds, split edge frames or complex backgrounds into background-like layers, clean a local residue region by pixel content only when the foreground/background separation is obvious, or redraw the layer as SVG. Re-run verification and inspect the isolated asset again.

## Unrequested Icon Frame Appears

Symptoms:

- local preview PNG has an inner rounded border or highlight line that is not in the source
- the mark looks like it sits inside a framed tile even though the reference has only a plain background

Action: remove decorative background strokes from the source spec. Keep simple backgrounds as fill-only unless the user or reference explicitly calls for a border.

## Preview Background And Icon Composer Fill Drift Apart

Symptoms:

- the preview SVG/PNG looks right because it contains a local background layer
- `.icon/icon.json.fill` is still `automatic` or `solid` even though the Icon Composer background should be a gradient
- a preview-only background uses `composer.include: false`, but no equivalent fill is written to the `.icon` bundle
- the preview SVG/PNG shows a localized top bar, sheen band, inner edge strip, or material patch that is not represented by `icon.json.fill`
- `icon.json.fill` uses a 3+ stop `linear-gradient`; the preview renders, but Icon Composer refuses to open the `.icon`

Action: set `spec.fill` to the intended `automatic`, `automatic-gradient`, `solid`, or 2-stop `linear-gradient` value, then regenerate and verify. Keep preview-only simple backgrounds aligned with that same broad fill. If local reference matching needs a richer preview background, keep the richer background out of `.icon` fill and record the deliberate difference; import a background asset only when the background is too complex for Icon Composer fill, and mark that bottom layer with `composer.background_role: "complex"` so it is not confused with a duplicated simple fill.

## App Asset Accidentally Includes Preview Mask

Symptoms:

- root source `<delivery-name>.svg` contains `<clipPath>` or `clip-path`
- root source `<delivery-name>.png` has transparent rounded corners
- a preview-only background layer contains a full-canvas rounded rectangle

Action: remove the rounded mask from source layers and regenerate. Platform masks belong only in `*.preview.*`; the app/source canvas and Icon Composer assets must stay unrounded.

## Unsafe Output Replacement

Symptoms:

- command points `--out` at an existing project folder
- previous unrelated files disappear
- generated files overwrite user-managed artifacts

Action: stop and choose a dedicated generated output directory before running generation. On a verified owned output, `author-icon` refreshes only manifest-owned leaf files and prunes only directories that become empty.

## Generic Skill Becomes A One-Off Fixture

Symptoms:

- script contains specific icon names, local image paths, or a fixed local fixture layout
- tests assert user-specific artifacts
- new users cannot generate their own icon without editing the script

Action: move concrete icon choices into the agent-authored JSON spec or task output. Keep bundled scripts generic.

## Verification Overfits The Reference

Symptoms:

- validation skips the per-package reference asset for each generated icon
- pixel diff is treated as the main success criterion for a loose style-inspired icon
- the process optimizes toward copied coordinates instead of reusable layers

Action: verify each icon directory independently. For reference-driven reproduction, use same-size side-by-side/overlay/diff to guide geometry and style corrections. For loose style exploration, keep side-by-side/overlay/diff advisory; final acceptance still depends on package structure, import safety, editability, and visual review.

## Diagnostic Metrics Become A New Score To Game

Symptoms:

- the agent treats ordinary 3x3 local samples as a pass/fail replacement for mean delta, overlay, and diff
- the agent treats p95/p99, threshold percentages, high-delta regions, or tile hotspots as separate pass/fail gates
- the agent edits colors, shadows, highlights, or blur only to improve one sample point
- a tiny antialiasing edge mismatch causes a broad redesign
- PNG fallback is chosen because it improves a sample or tile metric, not because SVG is unsuitable for that layer

Action: keep ordinary diagnostics as repair guidance only. Respect `local_sample_gate.status: "failed"` as a blocker because it requires severe mean and p95 mismatch in the same stable sample window, but do not optimize blindly to make a sample number look better. Use high samples, percentiles, threshold counts, high-delta regions, or hot tiles to decide where to inspect: background/fill, primary shape, edge/cutout, alpha matte, or material hotspot. Then apply the correct repair path: SVG geometry for shape drift, fill adjustment for color drift, Icon Composer handoff for platform material, or a documented per-layer PNG fallback for text, raster, dense brand geometry, renderer artifacts, or strict identity fidelity.

## Shape Facts Become A Completion Gate

Symptoms:

- `shape-facts.json` passes and the agent claims the icon is complete without inspecting side-by-side, overlay, diff, and `.icon/Assets`
- the agent treats component count, hole count, bbox, centroid, or scanline intervals as proof of brand identity
- the agent overfits SVG paths to scanline intervals while the whole mark looks worse
- Liquid Glass highlights, shadows, bevels, text, dense logos, or mascot details are thresholded as if they were clean shape facts
- full-canvas scanline drift from edge glow or app-mask highlights is mistaken for foreground mark drift without checking `edge_touching_count` and `interior_scanlines`
- a source-cut PNG is chosen only because it satisfies shape facts

Action: keep shape facts diagnostic. Use them to reject wrong shape models, locate geometry drift, separate edge artifacts from foreground drift, and write sharper `source_analysis` constraints. Completion still requires generated package verification, clean Icon Composer assets, semantic review, side-by-side/overlay/diff inspection, and any required user/human/independent acceptance.

## Reference Evidence Is Skipped

Symptoms:

- the user provided a reference image but only package structure was verified
- no `reference-side-by-side.png`, `reference-overlay.png`, or `reference-diff.png` exists
- visual closeness is claimed from memory or side-by-side inspection only, without overlay/diff metrics and package gates

Action: rerun `verify --reference path/to/reference.png` when the reference and generated icon have matching dimensions. Inspect both generated images before claiming the reproduction is close.

## Reference Target Is Not Enforced

Symptoms:

- `reference-side-by-side.png`, `reference-overlay.png`, and `reference-diff.png` exist, but no numeric target was set
- `mean_absolute_rgb_delta` is reported but not used to drive iteration
- `mean_absolute_rgb_delta` is below `10`, but `local_sample_gate.status` is `"failed"`
- the agent stops after a package-structure pass even though overlay/diff shows obvious drift
- the manifest says `done` while mean delta is `>= 10`

Action: rerun verification with `--reference`; the verifier enforces `9.99` by default and checks severe local sample mismatch. Reference-driven reproduction is not complete until mean delta is `< 10`, `local_sample_gate.status` is `"ok"`, and side-by-side/overlay/diff inspection does not show a blocker. If a looser result is intentionally accepted for style exploration or Icon Composer editability, mark it explicitly as deferred/accepted tradeoff, not as reproduction complete.

## Strict Pixel Target Fails But Semantic Candidate Is Good

Symptoms:

- mean delta is between `10` and `20`
- `local_sample_gate.status` is `"ok"`
- overlay shows the main silhouette, spacing, and layer placement are close
- `.icon/Assets` uses clean SVG or justified clean PNG layers
- diff is dominated by baked glass, bevel, shadow, glow, edge lighting, or renderer shading from the reference
- the candidate looks better in Icon Composer terms than a lower-delta raster fallback

Action: keep the result as an Icon Composer semantic candidate, not strict reproduction. Record `semantic_review.status` as `visually-close` or, after user/human/independent acceptance, `accepted-approximation`. Keep the strict `<10` miss as evidence. Do not switch to source-cut PNG or bake material into imported SVGs only to improve the mean delta.

## Path Repair Uses The Wrong Shape Model

Symptoms:

- a repair improves one local idea but makes the whole icon less like the source
- an open form is treated as a closed compound cutout
- a continuous ribbon is split into unrelated fragments
- a negative space relationship is filled, cut out, or disconnected incorrectly
- row/column foreground intervals get worse even though the path looks cleaner in isolation

Action: stop tuning coordinates and name the visual shape model first: open form, closed form, compound cutout, ribbon, disconnected pieces, or overlapping plates. Compare foreground intervals on the rows or columns that cross the disputed area, then repair the semantic path. Preserve or restore the previous best candidate when a path repair regresses the whole silhouette.
