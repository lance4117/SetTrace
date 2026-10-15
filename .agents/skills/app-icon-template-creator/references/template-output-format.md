# Template Output Format

The final template is a Markdown file compatible with the installed `app-icon-gen` skill's semantic image prompt examples.

## Required Sections

The candidate template must contain these headings in order:

````markdown
# <template-slug>

Use this for ...

Expected source-layer mapping:

- background -> ...
- <layer-id> -> ...

## Style Family Template

```text
...
```

## Variant Axes

- ...

## Template Conversion Flow

...

## Example Instantiation (Not A Default)

```text
...
```

## Example Conversion Contract (Adapt After Selection)

```json
...
```
````

## Quality Rules

- The title slug must be lowercase hyphen-case.
- The first paragraph must name the intended app categories and the core visual grammar.
- Required headings and `text`/`json` fences must be real top-level Markdown structure, not text nested inside another fence, an HTML comment, or a raw HTML block; every fence must be closed.
- `Style Family Template` must use slots for app-specific content.
- `Variant Axes` must name only safe variations.
- `Template Conversion Flow` must explain the expected `app-icon-gen` route.
- Keep reconstruction and migration evidence in `<delivery>/tmp/work/`, not in the final template Markdown. The final template should stay compatible with `app-icon-gen` semantic image prompt examples.
- `Example Instantiation` must not become the default subject.
- `Example Conversion Contract` must pass `references/template-conversion-contract.schema.json` through `template-lint`.
- Negative constraints must be concrete and visual.

## Public Vs Private Templates

For public templates, remove exact brand marks, source app names, proprietary mascot identity, and exact copyrighted compositions.

For private user-owned templates, preserve the user's named design language when requested, but still separate fixed style grammar from app-specific subject slots.
