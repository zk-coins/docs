# Contributing to zkCoins Docs

This guide covers how to write, build, and deploy the zkCoins documentation.

## Quick Start

```bash
git clone https://github.com/zk-coins/docs.git
cd docs
npm install
npm start    # http://localhost:3092
```

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Node.js | 20+ | Runtime |
| npm | 10+ | Package manager |

## Project Structure

```
docs/
├── docs/                  # Markdown content
│   ├── intro.md           # Landing page (slug: /)
│   ├── architecture/      # Architecture section (6 pages)
│   ├── infrastructure/    # Backend + deployment (2 pages)
│   ├── protocol.md        # Shielded CSV protocol reference
│   ├── wallet.md          # Wallet user guide
│   ├── comparisons.md     # vs RGB, Lightning, Zcash, etc.
│   ├── tech-decisions.md  # Technology choice rationale
│   └── risks.md           # Known risks and limitations
├── src/css/custom.css     # Theme overrides (Bitcoin orange)
├── static/img/            # Favicon, logos
├── docusaurus.config.js   # Site config
├── sidebars.js            # Navigation structure
└── package.json           # Dependencies (webpack pinned to 5.97.1)
```

## Git Workflow

| Branch | Purpose | Deploy |
|---|---|---|
| `develop` | Default, active development | Cloudflare Pages preview (dev-docs.zkcoins.app) |
| `main` | Production | Cloudflare Pages production (docs.zkcoins.app) |

- **Push directly to `develop`**
- **`main` is protected** — changes only via PR

## Writing Docs

### File Format

Every doc page needs frontmatter:

```markdown
---
sidebar_position: 3
title: Page Title
---

# Page Title

Content starts here.
```

### Style Guide

- **English only** — all documentation in English
- **Present tense** — "The server scans blocks" not "The server will scan blocks"
- **Active voice** — "The user creates a wallet" not "A wallet is created by the user"
- **No marketing language** — be technical and precise
- **Code blocks** — always specify the language (`typescript`, `rust`, `bash`, `json`)

### Diagrams

Use **ASCII diagrams** — no Mermaid, no images, no external tools:

```
┌──────────┐     ┌──────────┐
│ Browser  │────▶│ Backend  │
└──────────┘     └──────────┘
```

### Callouts

Use Docusaurus admonitions:

```markdown
:::warning Title
Warning content
:::

:::tip Title
Tip content
:::

:::info Title
Info content
:::
```

### Tables

Use Markdown tables for structured comparisons:

```markdown
| Feature | Option A | Option B |
|---|---|---|
| Speed | Fast | Slow |
```

### Links

- Internal: `[Link text](/path/to/page)` or `[Link text](relative-path)`
- External: `[Link text](https://example.com)` — always include protocol

### Adding a New Page

1. Create `docs/new-page.md` with frontmatter
2. Add to `sidebars.js` in the correct position
3. Build locally: `npm run build`
4. Push to develop

## Building

```bash
npm run build    # Production build → build/ directory
npm run serve    # Serve built site locally
npm start        # Dev server with hot reload
```

### Known Issue: webpack

webpack is pinned to `5.97.1` in `package.json` (`overrides`) due to a ProgressPlugin incompatibility with webpack 5.98+ and Docusaurus 3.9 on Node 22. Do not remove this override.

## Deployment

Deployed automatically via **Cloudflare Pages**:

- Push to `develop` → builds preview at `dev-docs.zkcoins.app`
- Push to `main` (via PR) → builds production at `docs.zkcoins.app`

No Docker, no server — pure static hosting on Cloudflare's edge CDN.

## Theme

- **Dark mode default** — `colorMode.defaultMode: "dark"` in `docusaurus.config.js`
- **Bitcoin orange** — primary color `#f7931a` defined in `src/css/custom.css`
- **Background** — `#0a0a0a` (matches the wallet app)

## Related Repos

- [zk-coins/app](https://github.com/zk-coins/app) — Web application
- [zk-coins/server](https://github.com/zk-coins/server) — Rust backend
