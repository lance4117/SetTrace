# Reconstruction Gates

Reconstruction proves that the analysis captured the source style. It does not prove the final template is reusable.

## Prompt Shape

Use this structure for reconstruction prompts:

```text
Use case: app-icon-style-reconstruction
Reference role: Image 1 is the style and composition reference; do not copy protected identity beyond the user's permitted scope.
Asset type: Apple app icon reference image
Subject: [describe the same source subject only for reconstruction]
Background grammar: [solid/gradient/stage/material and colors]
Subject topology: [parts, layer count, topology]
Composition: [anchor, scale, safe area, crop behavior]
Palette/material: [colors and material behavior]
Layering: [opaque overlays, visible gaps, no transparent carved holes unless source truly requires it]
Quality: premium App Store icon, readable at 64px, clean silhouette.
No text, watermark, extra symbols, unrelated objects, or style drift.
```

## Acceptance Standard

Accept a reconstruction only when it is style-equivalent:

- Same background grammar.
- Same subject topology family.
- Similar composition anchor and scale.
- Similar palette grammar or documented intentional palette abstraction.
- Similar material grammar.
- Similar layer grammar and negative-space strategy.
- No major extra symbols.
- No material or renderer effects that would make `app-icon-gen` conversion impossible.

## Evidence Order

1. Inspect source and reconstruction side by side for whole-icon style.
2. Inspect overlay or diff when geometry, scale, or placement is disputed.
3. Inspect local hotspots when one region is failing repeatedly.
4. Repair analysis before repairing prompt if the prompt failure reveals a missing style rule.
5. Stop after three failed reconstructions and write the blocker: missing source clarity, conflicting style grammar, generator limitation, or package-unfriendly artwork.

## Non-Critical Differences

These may be accepted if they do not affect template extraction:

- Exact curve coordinates differ but topology and visual rhythm match.
- Exact source colors differ but palette relationship matches.
- Minor antialiasing, mask, or platform preview differences.
- A source-specific object detail is simplified for template abstraction.

## Critical Failures

Do not extract a template when reconstruction has any of these:

- Different topology family.
- Different background grammar.
- Changed material category, such as flat becoming glossy glass.
- Extra icons, text, UI details, or mascot features.
- Overfit brand mark copying when a public or inspiration source should be abstracted.
- Dirty raster fragments that cannot map to semantic layers.
