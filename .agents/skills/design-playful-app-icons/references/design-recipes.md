# Design Recipes

## Choose a lane

| Product need | Preferred lane | Why |
| --- | --- | --- |
| Friendly product with a concrete object | Soft 3D object-character | The object explains the product while soft volume adds polish |
| Expressive community or learning product | Flat outlined mascot | Bold contour and simple expression survive at small sizes |
| New consumer brand needing emotional identity | Gradient silhouette mascot | A distinctive outer shape carries recognition without detail |
| Professional or abstract utility | Minimal dimensional glyph | Restrained depth feels precise and avoids forced cuteness |

Choose one lane first. Borrow at most one secondary technique from another lane.

## Map products to metaphors

Start from the product's job, then select a physical noun that can perform that job.

| Product job | Useful metaphor families | Avoid first-choice cliches |
| --- | --- | --- |
| Focus and time | timer, dial, shielded flame, attentive creature | isolated clock face, generic checkmark |
| Fitness and movement | compact weight, spring, pulse object, energetic character | detailed athlete scene |
| Money and budgeting | pocket, wallet, seed, guarded coin object | currency symbol as the whole idea |
| Travel and navigation | directional creature, folded route, compact vehicle | realistic globe with many lines |
| Learning and language | talking card, curious book, speech object, mnemonic creature | graduation cap alone |
| Health and habits | growing object, balanced container, calm companion | medical cross without context |
| Creativity and media | prism, spark tool, expressive frame, transforming object | random rainbow sparkle |
| Communication | speech object, listening character, connected pair | generic chat bubble alone |

Reject a metaphor if it could represent three unrelated product categories.

## Recipe 1: Flat outlined mascot

Use broad vector-like parts, a heavy smooth contour, and an expressive face. Keep depth nearly flat.

Construction order:

1. Draw one recognizable outer silhouette from 2-4 rounded parts.
2. Add a dark contour that remains visibly heavy at 32 px.
3. Add two eyes and one mouth or gesture.
4. Offset pupils, eyelids, or pose to create attitude.
5. Apply one high-chroma background and one subject color family.
6. Add at most one short contact shadow.

Prompt frame:

```text
Square app icon for [platform] representing [product job]. A single [original mascot or
anthropomorphized object] [pose/action], built from [2-4] broad rounded vector-like
shapes and filling about [70-85]% of the frame. Heavy smooth dark contour, crisp flat
color separation, [eye construction] and [mouth/gesture] conveying [emotion]. One
signature hook: [hook]. Palette preset [preset] on a quiet edge-to-edge background.
Readable at 32 px, product-specific silhouette, no text, no tiny details, no busy scene,
no thin strokes, no existing logo, no known character, no artist imitation.
```

## Recipe 2: Soft 3D object-character

Turn a product-specific object into a tactile character. Let overlap, bevel, and light separate forms.

Construction order:

1. Choose one object that directly represents the product job.
2. Simplify it to 2-5 inflated parts.
3. Use a frontal or slight three-quarter view with a mild tilt.
4. Add a face only to the largest stable surface.
5. Use broad upper-left highlights, soft overlap occlusion, and a short diffuse shadow.
6. Keep one material family across all parts.

Prompt frame:

```text
Square app icon for [platform] representing [product job]. A single original [object]
transformed into a friendly character, [action/pose], simplified into [2-5] rounded
soft-plastic forms and filling about [70-85]% of the frame. Slight three-quarter view,
[face construction] conveying [emotion], with one product-specific hook: [hook]. Palette
preset [preset]. Broad soft light from the upper-left, wide bevels, restrained ambient
occlusion at overlaps, and one short diffuse contact shadow. Clear silhouette at 32 px,
quiet full-bleed background, no text, no micro-detail, no hard chrome, no excessive glow,
no existing logo, no known character, no artist imitation.
```

## Recipe 3: Gradient silhouette mascot

Make the outer shape carry recognition. Keep the face and interior structure minimal.

Construction order:

1. Create one asymmetric organic silhouette tied to the product metaphor.
2. Keep the subject nearly contiguous rather than assembling many pieces.
3. Use a deliberate two- or three-stop warm-cool gradient.
4. Add one or two facial marks in a high-contrast neutral.
5. Place one broad soft shadow beneath the subject.
6. Remove any internal detail that does not survive at 60 px.

Prompt frame:

```text
Square app icon for [platform] representing [product job]. One original [metaphor]
mascot with a bold asymmetric organic silhouette, [pose/action], filling about [70-85]%
of the square. A controlled [color A] to [color B] gradient describes volume across the
single contiguous form. Minimal [face construction] conveying [emotion]. One memorable
hook: [hook]. Crisp outer edge, one soft base shadow, strong grayscale separation, and a
quiet full-bleed [background]. Readable at 32 px, no text, no busy pattern, no random
gradient stops, no muddy edge, no existing logo, no known character, no artist imitation.
```

## Recipe 4: Minimal dimensional glyph

Use this lane when the product is professional or abstract and a mascot would feel forced.

Construction order:

1. Derive an original mark from the product action, not merely its initial.
2. Build one continuous or interlocking form.
3. Center it with generous optical balance.
4. Add shallow extrusion or one broad bevel family.
5. Use strong foreground/background value contrast.
6. Omit the face unless personality is explicitly required.

Prompt frame:

```text
Square app icon for [platform] representing [product job]. One original abstract glyph
derived from [product action], constructed as [continuous/interlocking form], centered
and filling about [65-78]% of the square. Restrained shallow dimensional relief, one
broad bevel family, strong value contrast, palette preset [preset], and a quiet full-bleed
background. Precise at 32 px, distinctive black silhouette, no text, no generic initial,
no decorative clutter, no excessive symmetry, no existing logo, no artist imitation.
```

## Build three genuinely different concepts

For each direction, provide:

- Concept name
- Product metaphor
- Selected lane
- Outer silhouette
- Expression or single hook
- Palette preset
- Why it remains clear at 32 px

Change at least two of metaphor, lane, silhouette, view, or hook between directions.

## Revise without identity drift

When a result is weak, change the minimum necessary variable:

- Weak meaning: replace the metaphor or functional prop.
- Weak silhouette: merge parts, enlarge the dominant mass, or remove appendages.
- Generic personality: redirect gaze, alter eyelids, change tilt, or replace the mouth.
- Muddy color: reduce to one palette preset and restore grayscale contrast.
- Incoherent depth: commit fully to flat separation or one material and light model.
- Busy output: remove all but the face and one signature hook.
- Derivative result: change metaphor, silhouette family, and palette relationship together.

Do not fix a semantic problem by adding polish.
