# CLAUDE.md — zk-coins/docs

Documentation site for zkCoins (Shielded CSV wallet) at [docs.zkcoins.app](https://docs.zkcoins.app).

## Tech Stack

- Docusaurus 3.9.x (classic preset)
- React 18
- Node 22 (webpack pinned to 5.97.1 via overrides)

## Commands

```bash
npm install          # install dependencies
npm start            # dev server on http://localhost:3092
npm run build        # production build
npm run serve        # serve production build on :3092
```

## Content Structure

All documentation lives in `docs/`:

| Path | Content |
|---|---|
| `docs/intro.md` | Landing page (route: `/`) |
| `docs/architecture/` | Overview, Privacy Model, Nullifiers, Tx Flow, Keys, Signup, Proofs |
| `docs/protocol.md` | Shielded CSV paper summary, cryptographic primitives |
| `docs/wallet.md` | User guide, features, self-hosting, API |
| `docs/infrastructure/` | Backend setup, deployment, Docker |
| `docs/comparisons.md` | vs RGB, Lightning, Zcash, Monero, CoinJoin, Silent Payments |
| `docs/tech-decisions.md` | Technology choice rationale |
| `docs/risks.md` | Known risks and disclosure |

Config: `docusaurus.config.js`, sidebar: `sidebars.js`, styles: `src/css/custom.css`.

## Style Guide

- English only, present tense, active voice
- ASCII diagrams (no Mermaid, no images)
- Docusaurus admonitions (`:::warning`, `:::tip`, `:::info`)
- Dark mode default, Bitcoin orange (#f7931a)

## Git Workflow

- **develop** = default branch (all work goes here)
- **main** = protected, production
- Always create a feature branch from `develop`
- Always open a draft PR to `develop`: `gh pr create --draft --repo zk-coins/docs`
- Never push directly to `main` or `develop`

## Deployment

| Environment | URL | Branch |
|---|---|---|
| DEV | [dev-docs.zkcoins.app](https://dev-docs.zkcoins.app) | develop |
| PRD | [docs.zkcoins.app](https://docs.zkcoins.app) | main |

Hosted on Cloudflare Pages. Merging to `develop` deploys DEV, merging to `main` deploys PRD.

## Related Repos

| Repo | Purpose |
|---|---|
| [zk-coins/app](https://github.com/zk-coins/app) | Web application (frontend, PWA) |
| [zk-coins/server](https://github.com/zk-coins/server) | Rust backend (API, ZK proofs, Bitcoin scanner) |
| [zk-coins/marketing](https://github.com/zk-coins/marketing) | Marketing site |
| [zk-coins/research](https://github.com/zk-coins/research) | Research and protocol analysis |
