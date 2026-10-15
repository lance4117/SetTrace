# Source Requirements

The source is treated as design evidence, not as a full-icon trace target. Component-level tracing is allowed only for named, cleanly separable components under the vectorization rules below.

Use this skill when the user supplies:

- a style reference PNG
- an existing `.icon` bundle
- a product/app brief
- a generated concept candidate
- a request to generate, redraw, convert, or refine an app icon
- a request for a refined layered SVG/PNG icon package

## Source Discovery And Route Selection

Before asking the user, inspect available evidence:

- direct attachments and paths in the prompt
- current project metadata that can reveal app name, bundle identifier, product category, or existing icon assets
- existing SVG/logo/image files near the project when the task context points to them
- clean user-provided, generated-in-task, project-local, or explicitly user-approved official source vectors for brand marks
- supplied `.icon` bundles and their `icon.json`
- current agent capabilities, especially whether image generation is available

Then choose the lightest route that can produce a real package:

- `source-conversion`: user supplied a PNG/SVG/logo/brand mark/existing app icon; preserve identity and convert/refine into separated assets.
- `concept-to-package`: no source artwork exists and image generation is available; generate candidate reference images, get selection when needed, then package the selected candidate.
- `direct-authored-package`: no source artwork exists or image generation is unavailable; author a clean semantic icon directly from app context.
- `icon-composer-refinement`: user supplied `.icon` output, Icon Composer screenshots, or Composer-specific problems; inspect bundle/layers/fill first, then repair the spec/package.

Before authoring, state any known delivery boundary in the spec. `target_platforms` is optional metadata and accepts any non-empty platform labels. Generate generic source assets first. Add `deliverable_type: "icon-composer-package"` or an Apple target only when the user requests the Apple adapter; do not silently present its `.icon` output as an Android, Windows, Web, tvOS, or visionOS native package. Ask before a dedicated platform adapter is needed.

Do not ask a setup questionnaire just because the user says "generate app icon". Ask only when the app identity, brand direction, or concept selection cannot be inferred safely.

When a supplied reference, source vector, or generated concept drives the package, copy the selected source evidence to `<delivery>/<delivery-name>.origin.png` or `<delivery>/<delivery-name>.origin.svg`. Keep only the selected evidence file at the delivery root; keep unused candidates and repair inputs under `<delivery>/tmp/work/`. The `.origin.*` file is for provenance and review only, never an Icon Composer import asset.

If the user supplies or generates a final rendered PNG with glass, refraction, blur, shadows, gradient material, or Icon Composer lighting, do not segment it directly. Treat it as style evidence and author clean SVG layers or clean authored PNG layers that can be adjusted in Icon Composer. PNG is valid source material when it is a deliberate flat color, linear gradient, text/raster, dense brand, or custom-gradient layer with clean alpha; only reject dirty source-cut PNGs that carry background residue or baked material.

When the reference appears to be a platform/Icon Composer final render, choose the production package target by default. The local preview is then allowed to look flatter than the reference because it represents the clean base layers the user will tune in Icon Composer. Only create a local presentation mock with simulated material when the user explicitly asks for a rendered preview; keep that mock outside `.icon/Assets` and record that it is not the production source package.

For a generated icon concept or user-owned reference image, the main route is image-to-Icon-Composer-package: semantic SVG redraw, guarded vectorization/polish, and only then clean PNG fallback when SVG cannot preserve the source. Do not silently download a public/third-party SVG and substitute it for the generated/reference image. That makes the result look better while avoiding the actual conversion problem.

For smooth brand marks, monograms, knots, loop logos, and identity symbols, an owned clean source vector is usually better than tracing the rendered PNG. "Owned" means user-provided, generated in the task, project-local, or official and explicitly user-approved. Use the rendered bitmap for bbox, placement, palette, and material evidence; use the clean vector for the `.icon/Assets` foreground only when provenance is recorded. `source_analysis.components[]` must include `source_vector`, `source_provenance`, and `alignment_basis`. Generic public-web SVGs are not deliverable source vectors.

When no owned vector exists and the bitmap itself is vector-friendly, use component-level vectorization instead of guessing paths by hand:

- Use it for a few saturated/high-contrast foreground components, or one clean continuous foreground silhouette, on a near-flat or clearly separable background.
- Derive each component only from the supplied/generated/user-owned bitmap by local color, alpha, luminance, or region segmentation.
- Trace each component mask into one smooth SVG path or compound path, then author clean fills or simple gradients in the spec.
- Record the route as `semantic-svg-approximation` unless user/human/independent acceptance proves exact identity.
- For low-risk generated concepts with no external brand identity, `semantic_review.status: "exact-enough"` is acceptable only when the traced SVG passes `geometry-audit`, reference gates, asset inspection, and `source_analysis` records why the icon is original.
- Do not use this route for dense logos, text, complicated mascots, inseparable glass/material, or source images where segmentation would create dirty residue.

Hand-authored SVG failure is not SVG route failure. If a hand-authored path misses the reference but the supplied/generated bitmap has a clean, high-contrast, separable foreground silhouette, try component-level traced SVG from the normalized reference or a prepared foreground mask before choosing PNG fallback. This is the default repair path for one-mark icons such as white symbols on saturated gradient fields, simple dark marks on light fields, and other clean silhouettes with intentional holes/counters. Choose PNG fallback only after the traced SVG is noisy, too complex, fails `geometry-audit`, imports background residue, loses intentional negative space, or still fails reference gates after evidence-driven repair.

For Apple/Icon Composer work, default to `icon-composer-semantic`, not `strict-raster-replication`. The reference image is evidence for silhouette, proportions, palette, and layer relationships. It is not permission to source-cut the rendered icon into PNG layers just to pass a pixel diff.

Run:

```bash
delivery="${PWD}/build/my-icon"
mkdir -p "$delivery/tmp/work"
# Write the spec to "$delivery/tmp/work/spec.json" before generation.
# If source evidence exists, copy the selected source/concept to "$delivery/my-icon.origin.png" or "$delivery/my-icon.origin.svg".
npm --prefix scripts run author-icon -- --spec "$delivery/tmp/work/spec.json" --out "$delivery"
```

## Reference Analysis Checklist

Before writing the spec, make the smallest useful analysis:

- Source type: brief, reference bitmap, `.icon`, brand mark, text, or mixed input.
- Intent: subject, metaphor, visual mood, and what must remain recognizable.
- Layer plan: 2-5 semantic layers in bottom-to-top order; avoid trace fragments.
- Continuous outline route: logo-like connected marks, letterforms, ribbons, knots, and monograms should usually stay as one foreground SVG or compound path. Do not split a continuous silhouette into rectangles, patches, or multiple Icon Composer layers unless the source has real disconnected pieces, true overlap, or a meaningful layer boundary.
- Owned source-vector route: for smooth brand marks, monograms, knots, and loop logos, use a clean SVG/logo source only when it is user-provided, generated-in-task, project-local, or official-user-approved; record source provenance and whether the fit used bbox, center, scale, rotation, or manual alignment.
- Component vectorization route: for simple multi-part colored bitmap icons or one clean foreground silhouette, first detect the foreground components, bbox, holes/counters, and palette roles from the supplied bitmap. If the components are stable and map to real visual parts, trace each component mask into one SVG path or compound path, then use authored fills/gradients. Each traced component must appear in `source_analysis.components[]`; the spec notes must say it came from local segmentation of the supplied/generated image, not from an external SVG. If a hand-authored SVG candidate failed only because the contour is off, compare against a traced SVG candidate before considering PNG fallback.
- Shape facts route: when a vector-friendly bitmap reference is hard to judge by eye, run `shape-facts` to collect reproducible component, edge-artifact, bbox, centroid, hole/cutout, and scanline facts from the same-canvas reference. Use those facts to write concrete `source_analysis` constraints and guide SVG repair. Prefer `interior_scanlines` when edge highlights or canvas remnants pollute full-canvas scanlines. Do not use shape facts as a trace target, automatic SVG generator, or proof of brand/text/mascot identity.
- Palette roles: background/fill, primary mark, accent/highlight, optional shadow/glass handoff.
- Material provenance: decide whether the reference is a generated concept, a generic rendered mockup, or an Icon Composer/platform-exported final icon. Signs of an exported Icon Composer/Liquid Glass reference include a complete app-icon mask, platform-style rim lighting, soft outer glow, bevel/refraction around simple base shapes, and material effects that would naturally be regenerated by Icon Composer. For exported Icon Composer references, record those effects as deferred platform material; do not add simulated rim, glow, bevel, shadow, glass, or border layers to the local preview just to match the screenshot.
- Output intent: decide whether the user needs an Icon Composer production package or a rendered presentation mock. If the prompt is about `.icon`, Apple platform assets, Liquid Glass readiness, or Icon Composer tuning, treat it as production package work and keep preview/app outputs as clean base-layer evidence. If the user asks for a standalone marketing/rendered PNG, make that an explicit separate output and do not use it to justify material inside `.icon/Assets`.
- Background route: decide whether Icon Composer should use `automatic`, `automatic-gradient`, `solid`, 2-stop `linear-gradient`, or an imported complex background. If the local preview has a gradient, make sure the `.icon` fill carries the same broad intent unless the difference is deliberate. Do not write 3+ stop `linear-gradient` into `icon.json.fill`; local previews may render it, but Icon Composer can reject the `.icon`. If the background is too complex for fill, keep it as the bottom imported asset and mark `composer.background_role: "complex"`.
- Composition route: if the only way to match the reference is one full rendered PNG, keep that image as comparison evidence, not as the whole `.icon` bundle. Icon Composer output needs fill plus separated foreground layers, or an explicit `needs-source-vector`/`needs-repair` result.
- Import format: SVG first for simple editable geometry; PNG is allowed for clean flat color, linear gradient, text, embedded raster, dense logos, custom gradients, renderer-sensitive layers, or strict-fidelity cases where SVG has been tried or clearly cannot preserve the source identity.
- Geometry polish route: decide whether a traced or authored SVG path actually needs smoothing. Use geometry polish for visible trace wobble, stair-step curves, noisy redundant points, or arcs that should be optically smooth. If an intended rounded mark is mostly `L` commands, start with low `--tolerance` and `--smooth none`; use semantic `Q`/`C` curve repair for important rounded regions that still look mechanical. Do not use polish for intentional straight edges, sharp terminals, typography, brand-critical joins, or negative-space boundaries unless a candidate passes rendered drift checks and visual semantic inspection.
- Liquid Glass route: if Icon Composer will apply glass/refraction/material, reject foreground PNGs that contain baked lighting, bevel, glow, hard matte, rectangular crop edges, or source-background fragments even when the final composite matches the reference.
- Imported SVG material route: decide whether each foreground SVG is a base shape or a material simulation. Base-shape SVG is preferred; highlight strokes, opacity overlays, edge/rim/specular gradients, bevel/glow/shadow helpers, and Liquid Glass simulations belong to Icon Composer unless the user explicitly accepts a reviewed exception.
- Route consistency: if the plan says `semantic-svg` or `semantic-svg-approximation`, at least one foreground Icon Composer import must remain SVG; if all foreground imports are PNG, change the route to PNG fallback and keep the package in review until that tradeoff is accepted.
- Semantic fidelity: for brand marks, letter marks, existing app icons, and typography, decide whether the result is `exact-enough`, `visually-close`, `needs-source-vector`, `png-fallback-recommended`, or `redesign-needed`; record this in `semantic_review` with a route such as `semantic-svg`, `semantic-svg-approximation`, `png-fallback-recommended`, `needs-source-vector`, `style-only-approximation`, or `redesign-needed`.
- Unknowns: any user-owned brand/text tradeoff where rasterizing improves fidelity but reduces editability.
- Verification target: if a same-size reference image is available for reproduction, plan to generate `reference-side-by-side.png`, `reference-overlay.png`, and `reference-diff.png` with `verify --reference`. If the reference is a raw square/JPEG, lacks the same app-icon mask, or has a different canvas size than the generated `<Name>.preview.png`, first run `normalize-reference` so the comparison uses the same 1024px masked canvas. Strict pixel completion requires mean delta `< 10` and `local_sample_gate.status: "ok"` only when the work is actually strict pixel reproduction: same-canvas flat/source artwork, benchmark reproduction, or an explicit raster-fidelity request. For Icon Composer semantic remakes from platform-rendered references, a higher mean can be acceptable only as a reviewed/accepted approximation when geometry is close, assets are clean, `local_sample_gate` is ok, and the remaining diff is baked material that should be handled by Icon Composer.
- Shape-facts verification: if the main question is component count, required hole/cutout, rough bbox, centroid, or scanline interval drift, plan to run `shape-facts --reference ... --candidate ...`. Failed shape facts should reject or localize a repair, but passing shape facts does not replace side-by-side/overlay/diff inspection, source-analysis semantics, or Icon Composer asset hygiene.
- PNG fallback hygiene: if any foreground layer will be imported as PNG, plan to inspect the isolated PNG layer itself and record concrete `png_fallback_evidence`. Flat color and linear gradient PNG layers are acceptable when clean. Full-canvas residue, visible edge pixels, background haze, or unintended gradient/material contamination means matte rebuild with `prepare-bitmap-layer`, foreground extraction with `prepare-foreground-layer`, or SVG redraw, not completion.
- Extraction mode: use `prepare-foreground-layer --mode non-background` when the foreground is colored or sits on a near-flat black/white background. Use `--mode light-on-color` when the foreground is white/light and the source background is saturated blue/cyan/colored. Use `--mode light-on-dark` for white/light artwork on dark or complex rendered backgrounds. Add `--keep-components all` only when multiple disconnected components are intentional and named in the source-analysis contract.

If the source is an existing `.icon` bundle:

- read `icon.json` first, then inspect every referenced `Assets/*` file
- preserve the intended fill route (`automatic`, `automatic-gradient`, `solid`, or 2-stop `linear-gradient`) instead of copying a preview background blindly
- record group and layer order before authoring; keep the local preview spec and source `layers/` bottom-to-top, then verify generated `icon.json.groups[].layers` is front-to-back for Icon Composer display
- note per-layer position, glass, lighting, shadow, and translucency settings as source evidence, even when the generated package does not need all of them
- verify imported assets with the same SVG/PNG hygiene rules as newly authored assets

Style source rules:

- preserve the user's brand mark, subject, and required proportions before applying platform styling
- for loose style references, match the design language rather than exact path coordinates
- for user-owned marks or existing app icons, keep the recognizable silhouette and spacing unless the user asks for redesign
- for identity-sensitive marks, verify continuous strokes, distinctive terminals, negative space, spacing rhythm, and letterform/logo semantics; do not treat low mean delta as proof of identity
- preserve the idea of few large layers and platform-neutral background treatment
- keep SVG paths editable and simple
- if a bitmap trace leaves visible stair-step edges, excessive commands, or many micro-segments on a smooth identity mark, treat it as a route failure and switch to owned source vector, semantic redraw, clean PNG fallback, or explicit accepted approximation
- if a hand-authored SVG path fails `visual_delta_gate` but the reference has a clean separable silhouette, do not switch directly to PNG; run the component-level traced SVG route first, then compare geometry audit plus side-by-side/overlay/diff evidence
- treat smoothing as a candidate, not a default rewrite; if geometry polish changes the silhouette, negative space, terminal shape, or identity rhythm, keep the original path even if the candidate looks cleaner
- keep continuous brand contours continuous; do not manufacture seams by splitting one logo shape into local patches just to satisfy "layering"
- leave glass and lighting to Icon Composer
- when the reference is already an Icon Composer/platform export, keep the local preview focused on clean base layers and broad fill/color alignment; do not recreate the exported material rim/glow as preview-only geometry unless the user explicitly asks for a rendered presentation mock
- do not put baked material into imported foreground SVGs; `svg_material_warnings` is a review blocker, not a cosmetic hint
- do not switch to PNG just because it is easier to pass a diff; PNG fallback needs a per-layer fidelity/material reason and a clean isolated asset
- do not use generic PNG fallback language. The spec must record the category, SVG route, concrete evidence, and isolated cleanliness check for every non-text foreground PNG fallback.
- do not accept a PNG fallback that carries source-background residue; Icon Composer glass can reveal contamination that reference diff hides
- do not let a batch become dirty source-cut PNG-only because the reference has strong rendered material; clean authored PNG layers are allowed, but rendered-material leftovers require semantic SVG/base shapes or explicit raster acceptance
- do not trust edge hygiene alone; a PNG fallback can avoid canvas edges while still carrying baked glow, shadow, hard opaque matte, or horizontal rectangular source-background residue inside its bounds
- convert text to outlines only when faithful, otherwise render the text layer to PNG for Icon Composer import
- record font family and render method when a text layer is rasterized
- do not include rounded-rectangle or circle masks in Icon Composer layer exports
- use the reference to guide proportion, rhythm, and palette restraint
- for component-level vectorization, compare the traced component route against any hand-authored path candidate; prefer the traced route only when it improves whole-icon silhouette while keeping editable, clean SVG layers
- when overlay shows a localized shape issue, sample rows or columns through that region to compare foreground intervals before editing the SVG path; do not keep a path repair that improves a local idea while worsening the whole silhouette
- use shape facts for simple high-contrast or vector-friendly references when model-only visual judgment is unstable; treat Liquid Glass highlights, glow, shadow, bevel, small text, dense logos, and mascot details as failure-prone inputs for this route

Reject source interpretation that would require copying the original asset exactly, unless the user explicitly owns that asset and asks for direct reproduction.
