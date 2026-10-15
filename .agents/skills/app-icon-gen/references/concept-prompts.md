# Concept Prompts

Use this when the user asks for an app icon but has not supplied usable artwork, or when the task needs generated concept candidates before packaging.

## Contents

- [Route](#route)
- [Semantic Icon Design](#semantic-icon-design)
- [Image Generation Prompt Shape](#image-generation-prompt-shape)
- [Style Direction Selection](#style-direction-selection)
- [Selection And Conversion](#selection-and-conversion)
- [Direct Authoring Fallback](#direct-authoring-fallback)

## Route

Do not force a setup questionnaire. First infer from the user request, repository metadata, app name, product description, existing assets, screenshots, and attached files.

Ask only when the app identity or brand direction is genuinely unknowable, or when user choice is required among visual candidates. If no reference artwork exists, write a `semantic_icon_design` from `semantic-icon-design.md` before generating or authoring. Choose one SVG-convertible style direction from `style-directions.md` inside that design. If the current agent can generate images, create 2-4 candidate reference images from short creative prompts derived from the JSON design. If image generation is unavailable or not worth the delay, directly author a semantic SVG/PNG icon package from the same JSON design.

Generated concepts are references, not final packages. After a concept is selected, run the normal spec-driven package route with `author-icon` and `verify`.

## Semantic Icon Design

Before image generation or direct authoring, write a `semantic_icon_design` that describes the app context, style direction, metaphor, background, canvas safe area, and 2-5 semantic layers. This JSON is the design contract for both routes.

The design must name each layer's role, order, target format, shape model, fill, bounds, material restrictions, and `must_preserve` / `must_not_add` constraints. The metaphor, palette, shape model, composition, and reject list must come from the actual app name, category, job-to-be-done, and tone, not from the style direction alone. Any apparent cutout, counter, notch, stripe, or negative space must be modeled as a separate opaque top layer, not as a boolean hole, mask, clipPath, alpha cutout, or carved base geometry; conversion-time compound-path exceptions are handled in `semantic-authoring.md`. Favor crisp SVG targets, but do not flatten the aesthetic unnecessarily: broad gradients, controlled translucency, and low-frequency highlights are acceptable when each effect belongs to a named layer and has an SVG or clean PNG fallback route. If the design depends on unstructured shadow, dirty glow, noisy blur, dense detail, or a full rendered snapshot, simplify it before generating.

## Image Generation Prompt Shape

A generated reference should visualize the design direction, not obey the whole conversion checklist. For the first pass, do not paste the full JSON wrapper into the image generator. Use a concise visual prompt:

```text
App icon for {app_name}, {category or job-to-be-done}.
Seed: {fresh random integer}.
Style: {one style direction in plain language}.
Subject: {one app-specific mark/object/composition}.
Composition: {center / lower-left / lower-right / diagonal cluster / other style-approved anchor}.
Palette/material: {background, foreground colors, controlled gradient/translucency if needed}.
Layering: any apparent cutout, gap, counter, stripe, or hole should read as a separate opaque overlay shape, not transparent carved geometry.
Quality: premium App Store icon, strong silhouette, clean negative space, readable at small size.
No text, watermark, tiny UI details, or extra unrelated symbols.
```

Generate a fresh integer `generation_seed` for every candidate or retry. This is a prompt-level variation and tracking field, not a guarantee of deterministic image API output.

Use the JSON design as the internal source of truth and post-selection conversion contract. If the model drifts, repair with one or two targeted sentences from the JSON, not the whole contract. Examples: "use a lower-right sticker cluster with visible gaps between stickers" or "make the counter read as a clean overlaid shape, not a carved hole."

Add domain details only when they improve the app-specific metaphor. Do not add arbitrary visual features that the user did not request.

For copyable examples, use `examples/semantic-image-prompts/README.md`, then open only the matching example file. Use the `Style Family Template` for image generation after filling its slots from the app. Treat `Example Instantiation (Not A Default)` as one demonstration, not the default subject. Use `Example Conversion Contract (Adapt After Selection)` only for conversion, repair, or direct authoring after adapting it to the selected concept.

## Style Direction Selection

Use `references/style-directions.md` when the user has no concrete artwork or only loose taste references. The direction is a field inside `semantic_icon_design` and is shared by both no-reference routes:

- for `concept-to-package`, generate candidate references from the completed JSON design
- for `direct-authored-package`, use the direction's spec bias to write the JSON spec directly

Choose one primary direction that fits the app. Do not generate a board that mixes every family at once. Prefer high-convertibility directions such as `black-stage-mark` or `organic-blob-mark` when the brief is broad; choose medium-convertibility directions such as `connected-flow`, `connected-flow-silver`, or `souvenir-decal-stickers` only when the app brief benefits from that specific topology or surface grammar.

## Selection And Conversion

After candidate generation:

- show or inspect the candidates as reference images
- choose the strongest candidate, or ask the user to choose when preference matters
- write `source_analysis` from the selected concept before authoring
- rebuild semantic source layers instead of cutting the bitmap into a full rendered PNG
- use SVG for simple foreground shapes
- use clean PNG only for text, dense logo geometry, custom gradients, renderer-sensitive layers, or a deliberately accepted raster route
- keep simple background color/gradient in `icon.json.fill`
- output both rounded preview assets and unrounded app/source assets

If a candidate relies on texture, noisy blur, unstructured shadows, dirty glow, or tiny detail to work, reject it as difficult to package and generate or author a simpler candidate. Do not reject translucency or gradients by default; reject them only when they are not assignable to named layers or clean per-layer PNG fallback.

## Direct Authoring Fallback

When no image generation is available, author directly:

1. Infer the app metaphor from name, category, and project context.
2. Write a `semantic_icon_design` with one style direction, exact background, and 2-5 semantic layers.
3. Translate the design into an `author-icon` spec.
4. Use `author-icon`, then verify and inspect.

The fallback should produce a usable first icon package, not a placeholder. Keep it simple enough that the user can iterate through the same verification loop.
