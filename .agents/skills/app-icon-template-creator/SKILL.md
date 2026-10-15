---
name: app-icon-template-creator
description: Use when one or more Apple app icon references, generated concepts, screenshots, SVGs, or icon packages need to become a reusable app-icon-gen style template.
---

# App Icon Template Creator

Create a reusable `app-icon-gen` style template from reference icon artwork. The goal is not to copy a source icon. The goal is to extract a transferable design language that can generate different app icons with a consistent style and then package cleanly through `app-icon-gen`.

**REQUIRED SUB-SKILLS:** Use `app-icon-gen` and an available raster image-generation skill such as `imagegen` or `codex-image-gen`. If either capability is unavailable before the workflow can run, report `dependency_blocked`; do not call the template complete. Use `needs_package_verification` only when those capabilities are available but the selected migration candidate has not yet passed the package flow.

## Hard Contract

- Inspect supplied references before asking questions: image files, SVGs, existing `.icon` bundles, generated concepts, screenshots, or project assets.
- Use one working root for each template creation run: `<delivery>/tmp/work/`.
- Preserve the selected source reference as `<delivery>/<template-name>.origin.png` or `<delivery>/<template-name>.origin.svg`.
- Record the current analysis in `<delivery>/tmp/work/reference-analysis.md`.
- Record each reconstruction prompt in `<delivery>/tmp/work/reconstruction-prompt-<n>.txt`.
- Save reconstruction outputs under `<delivery>/tmp/work/reconstruction-<n>.png`.
- Record each migration-test prompt in `<delivery>/tmp/work/migration-<n>-prompt.txt`.
- Save migration-test outputs under `<delivery>/tmp/work/migration-<n>.png`.
- Record reconstruction and migration decisions in `<delivery>/tmp/work/reconstruction-review.md` and `<delivery>/tmp/work/migration-review.md`.
- Write the final candidate template to `<delivery>/<template-name>.md`.
- Keep the final candidate template compatible with `app-icon-gen/examples/semantic-image-prompts/`: do not embed reconstruction or migration evidence sections in the final template.
- Do not call the template complete until reconstruction, migration, and package-readiness gates have all been checked.
- Do not create a template that preserves a proprietary logo, exact mascot identity, unique brand mark, or exact source arrangement unless the user explicitly owns it and asks for a private template.

## Workflow

1. Choose a delivery folder and template slug. Use a short lowercase hyphenated slug such as `black-stage-pane-cluster`.
2. Read `references/reference-analysis-protocol.md` and analyze the source icon through that lens.
3. Read `references/reconstruction-gates.md`, then write a reconstruction prompt that should reproduce the source style without naming a reusable template yet.
4. Use the available raster image-generation skill to generate one or more reconstruction images from the prompt. When a source image is supplied, pass it as a style/reference image and label its role in the prompt.
5. Compare source and reconstruction with visual inspection and, when useful, `app-icon-gen` reference comparison reports. Repair the analysis and prompt until the reconstruction is style-equivalent or the limitation is documented in `tmp/work/reconstruction-review.md`.
6. Before extracting the template, show the reconstruction candidates to the user when the user is actively reviewing the run. Continue with the selected/accepted reconstruction; if no live review is available, record the agent's acceptance basis in `tmp/work/reconstruction-review.md`.
7. Read `references/template-extraction.md` and extract the reusable style grammar from the successful reconstruction: fixed style constraints, variant axes, app-specific subject slots, conversion flow, and drift guards.
8. Read `references/migration-tests.md`, then generate at least three migration tests for different app contexts. Use contexts that change the app metaphor while keeping the style family.
9. Show migration outputs to the user when the user is actively reviewing the run. Continue with selected/accepted candidates; if no live review is available, record the agent's acceptance basis in `tmp/work/migration-review.md`.
10. Judge whether the migration outputs still feel like the same template. If they diverge, repair the template constraints before continuing.
11. Read `references/template-output-format.md`, then write the final candidate template Markdown file.
12. Run `npm --prefix <skill-dir>/scripts ci`, then `npm --prefix <skill-dir>/scripts run template-lint -- <candidate-template.md>`, resolving `<skill-dir>` to this skill's installed directory.
13. For at least one user-selected or accepted migration output, run the `app-icon-gen` package flow and verification. Use the candidate template's conversion flow as the route. If the package cannot become a complete candidate, revise the template.

## Reference Routing

- `references/reference-analysis-protocol.md`: always read first; defines the image-analysis lens.
- `references/reconstruction-gates.md`: read before using the available raster image-generation skill to reproduce the source style.
- `references/template-extraction.md`: read after a reconstruction is accepted.
- `references/migration-tests.md`: read before testing the draft template across multiple app concepts.
- `references/template-output-format.md`: read before writing or linting the final template.

## Completion Gate

Complete only when all applicable checks are true:

- A source evidence file exists at the delivery root.
- `tmp/work/reference-analysis.md` exists and names the style invariants and drift risks.
- At least one reconstruction output was generated and inspected.
- `tmp/work/reconstruction-review.md` documents the accepted reconstruction, reviewer basis, and any non-template-critical differences.
- At least three migration outputs were generated and inspected.
- `tmp/work/migration-review.md` documents at least three migration concepts and whether each preserved the same design language while changing app-specific subject semantics.
- The final template contains all required sections from `template-output-format.md`.
- `template-lint` passes.
- At least one generated migration candidate has been packaged through `app-icon-gen` and reached `complete_candidate`. If packaging cannot run, return `needs_package_verification` instead of completing the template.

Final response must include the delivery path, final template path, source evidence path, reconstruction outputs inspected, migration outputs inspected, template-lint result, package verification result, and any accepted limitations.
