# Reference Analysis Protocol

Analyze the source icon for transferable template grammar. Do not describe it as generic art direction. Extract visual rules that another agent can use to generate different app icons in the same style.

## Required Analysis Sections

### 1. Source Role And Rights

Record whether the source is user-owned, public inspiration, generated concept, existing app icon, SVG, screenshot, or `.icon` package. If ownership is unclear, create a style abstraction and avoid exact identity copying.

### 2. Background Grammar

Classify:

- Type: solid, low-contrast gradient, high-contrast gradient, material field, black stage, light field, transparent source, photographic, or complex.
- Shape: full square canvas, rounded preview only, inset plate, border, rim, or masked object.
- Composer target: solid fill, gradient fill, or generated source layer.
- Drift risks: glow inflation, noisy gradient, fake bevel, duplicated background layer, border drift.

### 3. Subject Topology

Identify the foreground as one of these families:

- single geometric mark
- organic blob or soft identity shape
- continuous loop or ribbon
- separated pane cluster
- mascot or face-like mark
- cropped silhouette
- sticker/decal set
- orbit/capsule cluster
- letterform or monogram
- material object reduced to base silhouette
- other named topology

Record the primary parts, layer count, which parts are mandatory, which parts can vary, and which details are app-specific.

### 4. Composition And Scale

Record anchor, scale, safe area, crop behavior, negative space, visual weight, and whether the subject touches or nearly touches the app mask. Use approximate percentages, not only adjectives.

### 5. Palette Grammar

Record background colors, foreground colors, accent colors, contrast model, allowed palette variants, and whether colors are sampled exactly or semantically chosen. Separate fixed style colors from app-specific colors.

### 6. Material Grammar

Classify material as flat, subtle gradient, glass, bevel, shadowed, glowing, grainy, sticker-like, clay-like, or mixed. Decide which material effects belong in generated reference art and which must be excluded from clean `app-icon-gen` source layers.

### 7. Layer Grammar

List expected semantic layers from bottom to top. For each layer, record target format (`svg`, `svg_or_clean_png`, or `clean_png`), fill behavior, geometry constraints, and forbidden renderer residue.

### 8. Template Invariants

Write 5-12 rules that must survive every generated icon in this style family. These should be concrete, visual, and testable.

### 9. Variant Axes

Write the controlled ways the template may vary: subject metaphor, topology count, anchor, palette family, accent usage, material intensity, and scale range.

### 10. Drift Guards

Write negative constraints that prevent common failures. Include shape drift, material drift, semantic drift, renderer residue, extra symbols, tiny details, text, watermark, and brand copying risks.

## Output Shape

Save the analysis as `<delivery>/tmp/work/reference-analysis.md` with these headings:

- `Source Role And Rights`
- `Background Grammar`
- `Subject Topology`
- `Composition And Scale`
- `Palette Grammar`
- `Material Grammar`
- `Layer Grammar`
- `Template Invariants`
- `Variant Axes`
- `Drift Guards`
- `Reconstruction Prompt Hypothesis`
