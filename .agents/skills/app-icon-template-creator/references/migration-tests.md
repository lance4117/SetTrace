# Migration Tests

Migration tests prove that the draft template can generate different app icons while preserving one design language.

## Required Test Set

Generate at least three different app concepts:

1. A productivity or utility app.
2. A consumer or lifestyle app.
3. A creative, media, health, finance, or developer-tool app that stresses a different metaphor.

If the source style is strongly domain-specific, choose three concepts inside adjacent domains and document the narrower template scope.

## Prompt Rules

Each migration prompt must use the draft template's `Style Family Template`. Change only the app name, category, job-to-be-done, subject metaphor, and approved variant axes.

Do not copy the reconstruction subject into migration tests unless one test intentionally checks same-domain reuse.

## Acceptance Standard

Accept the draft template only when all migration outputs:

- Feel like the same style family.
- Use different app-specific subjects.
- Preserve the fixed background grammar.
- Preserve the fixed material grammar.
- Preserve the topology family or allowed topology range.
- Stay readable at small size.
- Avoid forbidden drift guards.
- Look packageable as semantic SVG or clean PNG layers according to the conversion flow.

## Repair Rules

- If all outputs drift in the same way, strengthen the Style Family Template and Drift Guards.
- If one app concept fails because the metaphor is incompatible, narrow the template's use cases.
- If the style only works by naming the original subject, the source is not a reusable template yet.
- If the outputs look consistent but unpackageable, revise the Template Conversion Flow before acceptance.

## Evidence To Save

Save:

- `<delivery>/tmp/work/migration-1-prompt.txt`
- `<delivery>/tmp/work/migration-1.png`
- `<delivery>/tmp/work/migration-2-prompt.txt`
- `<delivery>/tmp/work/migration-2.png`
- `<delivery>/tmp/work/migration-3-prompt.txt`
- `<delivery>/tmp/work/migration-3.png`
- `<delivery>/tmp/work/migration-review.md`
