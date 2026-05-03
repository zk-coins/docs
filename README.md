# zkCoins Docs

Documentation for [docs.zkcoins.app](https://docs.zkcoins.app) — Shielded CSV protocol, architecture, wallet guide, and API reference.

## Live

| Environment | URL | Deploy |
|---|---|---|
| **PRD** | [docs.zkcoins.app](https://docs.zkcoins.app) | Cloudflare Pages (main) |
| **DEV** | [dev-docs.zkcoins.app](https://dev-docs.zkcoins.app) | Cloudflare Pages (develop) |

## Pages (15)

| Section | Pages |
|---|---|
| **Intro** | Landing page, quick links |
| **Architecture** | Overview, Privacy Model, Nullifier Design, Transaction Flow, Key Management, Signup Flow, Proof System |
| **Protocol** | Shielded CSV paper summary, cryptographic primitives |
| **Wallet** | User guide, feature status, self-hosting, API endpoints |
| **Infrastructure** | Backend (Bitcoin node setup, Docker), Deployment (domains, Docker images) |
| **Comparisons** | vs RGB, Lightning, Zcash, Monero, CoinJoin, Silent Payments |
| **Tech Decisions** | Rationale for every technology choice |
| **Risks** | 12 known risks, transparent disclosure |

## Development

```bash
npm install
npm start    # http://localhost:3092
```

## Build

```bash
npm run build
npm run serve
```

Note: webpack pinned to 5.97.1 (`overrides` in package.json) for Node 22 compatibility.

## Style Guide

- English only, present tense, active voice
- ASCII diagrams (no Mermaid, no images)
- Docusaurus admonitions (`:::warning`, `:::tip`, `:::info`)
- Dark mode default, Bitcoin orange (#f7931a)

## Related

| Repo | Purpose |
|---|---|
| [zk-coins/app](https://github.com/zk-coins/app) | Web application (frontend, PWA) |
| [zk-coins/server](https://github.com/zk-coins/server) | Rust backend (API, ZK proofs, Bitcoin scanner) |

## License

MIT
