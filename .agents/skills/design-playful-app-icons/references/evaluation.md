# Evaluation and Revision

## Score the icon

Use a 100-point rubric. Target at least 82 points, with no gate failure.

| Dimension | Weight | Pass condition |
| --- | ---: | --- |
| Product meaning | 20 | The metaphor communicates the product's primary job without explanation |
| Silhouette | 20 | The subject remains recognizable as a solid black shape |
| Small-size clarity | 20 | The face and one signature detail survive at 32-60 px |
| Color and contrast | 15 | Foreground separates from background in color and grayscale |
| Style coherence | 10 | Geometry, outline, material, light, and depth follow one lane |
| Originality | 10 | The design does not resemble a known logo, icon, mascot, or character |
| Platform readiness | 5 | Mask, opacity, safe area, and export match the target platform |

## Enforce gate conditions

Reject or revise before delivery when any condition is true:

- The icon needs text to explain the product.
- The silhouette is ambiguous at 32 px.
- More than one subject competes for attention.
- Critical facial features or the signature hook are clipped.
- The concept resembles an existing brand or recognizable character.
- The production asset contains a baked iOS corner mask or unintended transparency.

## Review at four scales

### 1024 px

Check material consistency, edge quality, lighting logic, gradient transitions, and unwanted generation artifacts.

### 180 px

Check overall balance, attitude, prop clarity, and foreground/background separation.

### 60 px

Check that the product metaphor and expression still read. Remove decorative details that begin to merge.

### 32 px

Check only silhouette, face, and signature hook. If more than these are needed, simplify.

## Diagnose and revise

| Symptom | Likely cause | Targeted revision |
| --- | --- | --- |
| Reads as cute but not useful | Generic mascot | Replace the body or prop with a product-specific object |
| Looks polished but interchangeable | No signature hook | Add one shape pun, unusual proportion, gaze, or purposeful crop |
| Face disappears | Features too small or low contrast | Enlarge the eyes or mouth and simplify to one expression system |
| Subject feels cramped | Occupancy or crop is too aggressive | Protect 8-15% around critical features and crop only appendages |
| Icon looks muddy | Too many hues or weak value separation | Use one palette preset and test in grayscale |
| 3D feels artificial | Multiple materials or light sources | Use one material family and one upper-left or top light |
| Flat icon feels fragile | Thin contour or fragmented parts | Merge shapes and use a visibly heavy smooth contour |
| Gradient feels arbitrary | Stops do not describe form | Align the gradient with volume or a deliberate warm-cool path |
| Resembles another app | Shared metaphor and silhouette | Change metaphor, outer contour, and palette relationship together |

## Run the refinement loop

1. Score the first result without defending it.
2. Identify the lowest scoring dimension.
3. Make one semantic or structural change and at most one polish change.
4. Recheck the four scales and grayscale contrast.
5. Stop when the icon reaches 82 points and all gates pass, or explain the remaining limitation.

Do not perform endless aesthetic variation after the icon passes. Preserve the strongest identity.

## Final quality report

Return this compact report with a generated or revised icon:

```text
Lane: [lane]
Metaphor: [object + action + emotion]
Palette: [preset and values]
Signature hook: [one hook]
Score: [total]/100
Small-size result: [32 px observation]
Production status: [ready or remaining issue]
```

## Production preflight

- Confirm a full-bleed square background.
- Confirm no visible text, watermark, or accidental border.
- Confirm one dominant subject and no more than one supporting prop.
- Confirm critical features remain inside the safe area.
- Confirm grayscale contrast and a readable black silhouette.
- Confirm both light and dark launcher previews.
- For iOS, use an opaque 1024 x 1024 sRGB raster without a baked corner mask.
- For Android adaptive icons, separate foreground and background and verify the current safe-zone template.
