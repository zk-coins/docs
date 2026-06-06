# Papers as Typst

Typst rebuilds of the three documents that anchor zkCoins. Sources and
prebuilt PDFs sit side by side; rebuild with `typst compile`.

## Files

| Typst source | Rendered PDF | Origin |
|---|---|---|
| `spec.typ` | `spec.pdf` (~74 pp) | This repo: `docs/specification.md` |
| `shielded-csv.typ` | `shielded-csv.pdf` (~42 pp) | [ePrint 2025/068](https://eprint.iacr.org/2025/068) — Nick / Eagen / Linus, Sept 2024 |
| `zkcoins.typ` | `zkcoins.pdf` (~3 pp) | [Robin Linus gist](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119) (2023) |

`spec.typ` is a single-source build of the protocol spec dressed in the
Shielded-CSV paper's design language (New Computer Modern, bordered
figure boxes, plain bordered admonition boxes, exact section
numbering). It is regenerated from `docs/specification.md` via the
pipeline below.

## Build

```bash
typst compile spec.typ
typst compile shielded-csv.typ
typst compile zkcoins.typ
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
images), tables as `#table`, ASCII figures as bordered code blocks,
numbered references where the source has them. Layout is not pixel-exact
to the originals — content + structure + math fidelity are the bar.

## Tooling

- `typst` ≥ 0.14
- `pandoc` (for the `spec.typ` regeneration pipeline)
- Default `New Computer Modern` font (system-installed via Typst's
  bundled fonts on most platforms)
