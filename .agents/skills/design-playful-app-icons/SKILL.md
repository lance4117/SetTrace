---
name: design-playful-app-icons
description: "Create, generate, refine, or critique bold playful app icons using a text-only visual system with measurable composition rules, compact palettes, mascot and dimensional style recipes, originality safeguards, and small-size quality checks. Use for app-icon concept development, production-ready image prompts, icon reviews, visual iteration, and iOS or Android handoff when no reference images should be bundled or required."
---

# Design Playful App Icons

Create distinctive app icons from text-only design rules. Communicate one product promise through a bold object, mascot, or glyph that remains recognizable at launcher size.

## Load the references

- Read [references/style-profile.yaml](references/style-profile.yaml) for every task. Treat its numeric ranges and invariants as the source of truth.
- Read [references/design-recipes.md](references/design-recipes.md) when developing concepts, selecting a visual lane, or writing generation prompts.
- Read [references/evaluation.md](references/evaluation.md) when critiquing, refining, comparing, or preparing production assets.

Do not request or depend on bundled reference images. Ask for an image only when the user wants an existing icon critiqued or edited.

## Follow the workflow

1. Reduce the brief to `object + action + emotion`.
   - Object: the simplest concrete metaphor for the product.
   - Action: the benefit or transformation users receive.
   - Emotion: the personality the icon should convey.
2. Infer missing details from the product category when the choice is low risk. Ask one concise question only when the product metaphor would otherwise be arbitrary.
3. Choose one visual lane from `style-profile.yaml`. Do not combine all lanes.
4. Create three directions that differ in metaphor or silhouette, not merely color.
5. Score the directions for product meaning, silhouette, and originality before rendering. Select the strongest direction and state why.
6. Construct the final generation prompt with the selected recipe. Encode geometry, composition, palette roles, facial language, material, light, and exclusions explicitly.
7. Generate the icon when image tools are available. Otherwise provide the final prompt and construction specification.
8. Evaluate the result with `evaluation.md` at 1024, 180, 60, and 32 px. If the actual raster is unavailable, reason conservatively from the composition and detail count.
9. Revise the weakest scoring dimension first. Limit each pass to one or two targeted changes so the identity does not drift.
10. Deliver the final asset or prompt together with palette, lane, production notes, and a short quality report.

## Preserve the core identity

- Use one dominant subject and no more than one supporting prop.
- Fill roughly 70-85% of the square while protecting the face and signature detail.
- Build the silhouette from 2-5 broad rounded parts.
- Use a face only when it strengthens the product metaphor. Prefer two eyes and one mouth or gesture.
- Use one dominant hue, one contrast hue, and ink or soft white as neutral.
- Use either clear flat separation or coherent soft volume. Avoid ambiguous half-rendering.
- Add exactly one memorable hook: expressive gaze, shape pun, asymmetric crop, purposeful prop, or unusual proportion.
- Keep the background edge-to-edge and visually quiet.

## Prevent generic output

- Make the icon explain the app's job before adding cuteness.
- Prefer a concrete product-specific object over a generic blob, star, sparkle, or smiling face.
- Direct pupils, eyelids, tilt, or pose to create a distinct attitude.
- Use gradients only to describe volume, depth, or a deliberate warm-cool transition.
- Reject concepts that could plausibly represent several unrelated apps.

## Enforce originality and public-safety rules

- Do not name, imitate, or cite an artist, studio, existing app, logo, mascot, or copyrighted character.
- Do not use phrases such as "in the style of" or ask the model to reproduce a known icon.
- Do not reconstruct any reference-specific silhouette, face, color arrangement, or prop combination.
- Develop original metaphors from the user's product function and audience.
- Avoid visible text, brand names, watermarks, and trademark-like monograms unless the user owns and supplies the mark.

## Deliver the right response

### Concept development

Return three directions with: name, metaphor, lane, silhouette, expression or hook, palette preset, and small-size rationale. Recommend one.

### Image generation

Generate the selected direction when tools permit. Also return the exact final prompt, negative constraints, selected lane, and palette so the result is reproducible.

### Critique and refinement

Lead with the highest-impact issue. Score all rubric dimensions, propose concrete edits, then supply a revised prompt or specification.

### Production handoff

Specify canvas, safe area, layer order, palette values, light direction, depth treatment, mask behavior, and export requirements. For iOS, default to an opaque 1024 x 1024 sRGB raster without transparency or a baked corner mask. For Android adaptive icons, separate foreground and background and verify the current platform safe-zone template.

## Build prompts in this order

1. Artifact and target platform
2. Product purpose and chosen metaphor
3. Pose, crop, and silhouette
4. Visual lane and part construction
5. Expression and single signature hook
6. Palette roles and quiet background
7. Material, light, depth, and shadow
8. 32 px readability requirements
9. Negative constraints and originality guardrail

Never rely on adjectives alone. Replace "cute, modern, polished" with visible construction decisions.
