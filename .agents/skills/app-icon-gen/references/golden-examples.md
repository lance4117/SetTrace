# Golden Examples

Use these synthetic examples when a new thread needs a known-good pattern. They are not real app icons and should stay small.

## `examples/flat-linked-mark-spec.json`

Use for flat white/black marks similar to simple workout, utility, or symbol icons.

Expected route:

- `semantic_review.route`: `semantic-svg`
- `.icon/Assets`: SVG foreground only
- `icon.json.fill`: solid background
- no PNG fallback, no material warnings

## `examples/material-chain-base-spec.json`

Use when the reference shows glass, bevel, glow, or edge lighting but the Icon Composer package should contain only a clean base foreground silhouette.

Expected route:

- treat rendered material as evidence, not source geometry
- `semantic-svg` foreground
- background in `icon.json.fill`
- no highlight strokes, opacity overlays, gradients, glow, or shadow in imported SVG

## Anti-patterns

Reject these even if they look close locally:

- one full rendered PNG as the only `.icon` asset
- source-cut foreground PNG with background residue
- SVG foreground with stroke-based bevels, rim highlights, glow paths, opacity overlays, or filters
- smoothing a mark until negative space, terminals, or identity rhythm changes
- claiming completion from `status: "ok"` while `outcome.review_required` is still true
