# Template Extraction

Extract a template only after a reconstruction is accepted. The template must preserve style grammar without locking the source subject.

## Extraction Decisions

### Fixed Style Constraints

Keep constraints that define the family: background grammar, topology family, material category, layer strategy, readability rules, and drift guards.

### App-Specific Slots

Turn source-specific identity into slots:

- `{app_name}`
- `{category or job-to-be-done}`
- `{subject metaphor}`
- `{composition anchor}`
- `{palette variant}`
- `{accent behavior}`

### Variant Axes

Only include axes that migration tests can safely vary. Do not offer variation that breaks packageability or style identity.

### Conversion Flow

Choose one default route:

- `direct semantic SVG`: simple topology, crisp geometric or organic paths.
- `hybrid semantic layers`: some paths can be drawn, some isolated layers may use clean PNG.
- `clean PNG per-layer`: painterly, glassy, or dense elements that are still separable.

Never set the default route to a single full rendered icon unless the template is explicitly a non-editable PNG fallback template.

### Drift Guards

Write negative constraints as concrete visual failures, not taste words. Prefer `no internal pane seams`, `no extra tiny symbols`, and `no hard clipped terminals` over vague quality language.

## Overfitting Check

Before writing the final template, ask:

- Does the template require the original app subject to work?
- Would three different app categories still look like siblings?
- Are exact brand colors required, or can the palette relationship vary?
- Are unique source shapes abstracted enough for public reuse?
- Does the conversion flow explain how to package the result?

If any answer fails, repair the draft template before migration tests.
