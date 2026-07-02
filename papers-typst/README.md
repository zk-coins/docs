# Papers as Typst

Typst rebuild of the zkCoins protocol specification, dressed in the
Shielded-CSV paper's design language. Source markdown and rendered
PDF sit side by side; rebuild with `typst compile`.

## Files

| Typst source | Rendered PDF | Origin |
|---|---|---|
| `spec.typ` | `spec.pdf` (~74 pp) | This repo: `docs/specification.md` |

The Typst output uses New Computer Modern, US-Letter at 1 in margins,
numbered sections + TOC, bordered figure/code/admonition boxes, and a
custom Abstract block — all matched to the
[Shielded CSV paper](https://eprint.iacr.org/2025/068) for visual
continuity across the project's reference documents. Typst rebuilds of
the Shielded CSV paper itself and Robin Linus's zkCoins gist live in
[`zk-coins/research`](https://github.com/zk-coins/research) under
`papers-typst/`.

## Build

```bash
typst compile spec.typ
```

Live preview while editing:

```bash
typst watch spec.typ
```

## Regenerating `spec.typ` from `docs/specification.md`

`spec.typ` = a fixed preamble (title block, abstract, admonition / table
/ raw show rules) concatenated with a pandoc-processed body of the
markdown source. The post-processing converts Docusaurus `:::tip` /
`:::info` blocks to bordered boxes and strips pandoc's
`figure(align(center)[#table(…)])` wrapper so tables break naturally
across pages.

The pipeline lives in this directory's git history (see commit message
of the initial import) and can be re-run when the markdown changes.

## Scope

Faithful text reproduction. Math rendered as native Typst math (not
images), tables as `#table`, ASCII figures as bordered code blocks.
Layout is not pixel-exact to the markdown's web rendering — content +
structure + math fidelity are the bar.

## Tooling

- `typst` ≥ 0.14
- `pandoc` (for the `spec.typ` regeneration pipeline)
- Default `New Computer Modern` font (bundled with Typst on most
  platforms)
