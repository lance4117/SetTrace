# Semantic Image Prompt Examples

Use these when no source artwork exists and the agent can generate image references before packaging. Each file is a style family, not a fixed icon recipe. Fill the slots from the app name, category, and job-to-be-done before generation.

Each style file has four parts:

- `Style Family Template`: reusable first-pass image prompt with variable slots
- `Variant Axes`: allowed ways to vary shape, composition, palette, and accents
- `Example Instantiation (Not A Default)`: one concrete prompt that demonstrates the fill-in level and style grammar
- `Example Conversion Contract (Adapt After Selection)`: one concrete `semantic_icon_design` JSON contract for conversion, repair, or direct authoring

Do not use the example app name, subject, seed, or bounds as defaults unless they match the user's app. Do not paste the full JSON into the image generator for the first pass unless the model repeatedly drifts. Full JSON is useful for redraw discipline, but it can over-constrain the image model and flatten the visual result.

## Case Usage Rules

- Open only the matching style file after selecting a direction; do not browse the whole library as a mood board during generation.
- Start from `Style Family Template`, then fill the app name, job-to-be-done, subject topology, composition, palette, and a fresh seed from the current app.
- Use `Variant Axes` to vary the icon so different apps in the same style family do not collapse into the example subject.
- Read `Example Instantiation (Not A Default)` only to learn prompt granularity, wording density, and what a completed first-pass prompt looks like.
- Adapt `Example Conversion Contract (Adapt After Selection)` only after a concept is selected, or when direct SVG/PNG authoring needs a strict semantic layer plan. Treat it as a layer-contract demonstration, not a locked pair with the prompt example.
- Never promote example subject, app name, seed, bounds, or layer names into defaults for unrelated apps.

## Prompting Model

Use two phases:

1. First-pass image generation: write a concise visual brief from the style family template. Emphasize app identity, chosen variant axes, subject, palette, composition, and one short negative line.
2. Conversion and repair: after a concept is selected, adapt the JSON contract to that exact image and rebuild it as semantic SVG or clean PNG layers.

Keep the first prompt style-forward and readable. Move layer counts, exact bounds, PNG fallback policy, and strict SVG conversion restrictions into the JSON contract. Still include the overlay rule in the first prompt when gaps, counters, or cutout-like details may appear.

The overlay rule is for prompting and design contracts, so generated concepts avoid transparent carved holes. Conversion-time compound-path exceptions are handled in `semantic-authoring.md`.

## Template-Guided Generation Flow

The selected template should also choose the conversion flow. Template-generated references are expected to have stable structure, so do not run them through a generic color-quantization or full-image tracing pipeline.

- Use the template's `Template Conversion Flow` as the default route unless the generated image clearly violates the template.
- For SVG-first templates, rebuild only named semantic components. Use direct semantic SVG authoring when the shape model is obvious; use clean mask plus `potrace` retrace only for a stable silhouette or component that is hard to hand-author.
- When retracing, generate multiple foreground-mask candidates under `tmp/work/`, choose the cleanest mask by visual inspection and geometry audit, then recolor the resulting SVG from the semantic palette in the JSON spec. Do not preserve sampled gradient chunks, antialiasing residue, or palette-quantized interior patches.
- Use PNG fallback only when the template says the layer is raster-appropriate or the selected image is too dense to redraw cleanly. The fallback must be an isolated clean layer, not a full rendered icon or dirty source cutout.
- If the generated image cannot follow the template's fixed flow without dirty fragments, route it back to prompt repair or semantic redraw instead of reporting the package as complete.

## Short Creative Prompt Shell

```text
Apple app icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: {one style direction in plain language}.
Subject: {one app-specific mark/object/composition chosen from the style file's variant axes}.
Composition: {center / lower-left / lower-right / diagonal cluster / other style-approved anchor}.
Palette/material: {background, foreground colors, controlled gradient/translucency if needed}.
Layering: any apparent cutout, gap, counter, stripe, or hole should read as a separate opaque overlay shape, not transparent carved geometry.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, tiny UI details, or extra unrelated symbols.
```

Do not include the entire SVG conversion policy in the creative prompt. The prompt should invite good composition and taste; the JSON should enforce redraw discipline after a direction is selected.

## SVG-First Examples

| File | Direction | Use when |
| --- | --- | --- |
| `black-stage-mark-signal-vault.md` | `black-stage-mark` | premium/security/dev-tool icon with a flat black stage, one high-contrast app-specific geometric mark, and one small palette-harmonized vivid accent |
| `black-stage-continuous-loop-loopvault.md` | `black-stage-continuous-loop` | premium utility, fitness, membership, or handoff icon with black or high-saturation single-hue stage, one thick rounded connected glyph, controlled overlay-created gaps, and no infinity drift |
| `connected-flow-flat-silver-compact.md` | `connected-flow-silver` | automation, sync, handoff, or workflow icon with a premium silver field and one compact app-specific connector topology |
| `blue-field-cutout-badge.md` | `blue-field-cutout-badge` | utility, place, security, health, or productivity icon with a saturated solid field, one centered white geometric badge, and one same-color diagonal cut overlay |
| `silver-field-black-mask-catmask.md` | `silver-field-black-mask` | premium companion, focus, privacy, or identity icon with a silver-white field, one large black abstract mask, and 1-2 white overlay features |
| `single-hue-gradient-outlined-mascot-charmbyte.md` | `single-hue-gradient-outlined-mascot` | playful mascot, avatar, pet, customization, or consumer icon with a restrained single-hue gradient, black backing shape, white inset mascot, and black overlay details |
| `single-hue-gradient-soft-white-symbol-emberlite.md` | `single-hue-gradient-soft-white-symbol` | warm, clean, friendly, or lightweight consumer icon with a restrained single-hue gradient, one soft white rounded symbol, and optional background-colored overlay details |
| `outlined-friendly-action-mark.md` | `outlined-friendly-action-mark` | friendly reminders, plant care, media, communication, and utility icons with warm full-square fields, thick rounded near-black outlines, and short motion accents |
| `single-hue-gradient-cropped-silhouette-nighthop.md` | `single-hue-gradient-cropped-silhouette` | bold, mysterious, premium, or night-themed icon with a restrained single-hue gradient, one oversized cropped near-black silhouette, optional rear echo, and one white overlay feature |
| `dark-gradient-pale-orbit-cluster-quietseed.md` | `dark-gradient-pale-orbit-cluster` | calm wellness, plant-care, sleep, focus, or cyclical utility icon with a dark organic gradient and 5-7 independent pale capsule markers around a center gap |
| `kinetic-pop-tempostride-ribbon.md` | `kinetic-pop` | energetic fitness, mobility, event, or fast-action icon with a coherent adjacent-color gradient and one bold motion symbol |
| `organic-blob-fusemap.md` | `organic-blob-mark` | clean light-field identity mark with one app-specific organic shape and optional small companion mark |
| `souvenir-decal-stickers.md` | `souvenir-decal-stickers` | playful collection, cafe, music, maker, memory, or local app icon with a pale gray-blue surface and 2-3 app-specific die-cut decal stickers |
| `glass-ribbon-filterwave.md` | `flat-color-rounded-pane-cluster` | camera, video, music, or creative icon with a black stage and separated solid-color smooth rounded curved panes |
