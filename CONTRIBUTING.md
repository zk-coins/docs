# Contributing to zkCoins Docs

This guide covers how to write, build, and deploy the zkCoins documentation.

## Trust model — run your own node

zkCoins follows the **Bitcoin full-node model: your wallet trusts _your_ node, exactly as a Bitcoin wallet trusts your own `bitcoind`.** "Trusted node" means _your_ node — never a third party. Running your own node is the trustless, private path, and it is the model the whole system is designed around. The node↔wallet split is packaging (a heavy validator process vs. a thin key-holder), not a trust boundary. The only line the node never crosses is the wallet's private key — that stays in the wallet.

This is a hard project rule. It shapes every design and implementation decision:

- **Self-hosting gives you trustlessness and privacy at once.** Your own node verifies your transactions and sees your plaintext — and _you_ are the operator, so nothing leaks. The wallet must always be able to switch to a different node by changing a single configuration value.
- **Using someone else's node is a trade-off you choose, not a flaw.** A public operator can never forge a signature, double-spend, or spend your coins without your key — that is enforced cryptographically (recursive proofs + Bitcoin-anchored nullifiers). It can, however, lie about your balances and history, and — because it alone builds the proving witness for a send — it can propose the wrong outputs for your cooperative signature to sign, redirecting a payment; the thin wallet cannot independently check this (no Poseidon, no client-side proof verification, per the rule above). This is a correctness trust, not a custody break — see [specification §6.6](https://docs.zkcoins.com/specification#66-threat-model-and-trust-configurations). What a foreign operator can always see is your privacy, and it can affect liveness — the same spectrum as using an Electrum/SPV server instead of your own Bitcoin node.
- **The thin wallet and SDK are not a compromise.** No anti-node logic: no client-side proof verification, no scan loops, no view-key / spend-key splits, no consistency checks against a second node, no "node integrity" indicators in the UI. Trustlessness comes from running your own node, not from bolting verification onto a thin client. Anything that exists to reduce trust in the node belongs node-side — or the answer is self-hosting.
- **The node is built so that self-hosting is easy.** Single container, documented configuration, deterministic state, no operator-specific dependencies.
- **The SDK and wallet stay thin.** They expose seed + address + the small set of operations every familiar wallet SDK exposes. Integrators (Cake Wallet, LayerZ, BlueWallet, …) should be able to wire zkCoins up with the same effort as adding a second Bitcoin-family chain.

When in doubt about whether a feature belongs in the wallet, SDK, or node: if it exists to reduce trust in the node, build it node-side, or document self-hosting as the answer. This rule is mirrored verbatim in [`zk-coins/node`](https://github.com/zk-coins/node/blob/develop/CONTRIBUTING.md), [`zk-coins/sdk`](https://github.com/zk-coins/sdk/blob/develop/CONTRIBUTING.md), [`zk-coins/app`](https://github.com/zk-coins/app/blob/develop/CONTRIBUTING.md), and [`zk-coins/docs`](https://github.com/zk-coins/docs/blob/develop/CONTRIBUTING.md).

## Paper conformance — follow the source works, or justify every deviation

zkCoins is a concrete realization of two source works: the **zkCoins concept** (Robin Linus, 2023) and the **Shielded CSV construction** (Jonas Nick, Liam Eagen, Robin Linus, [ePrint 2025/068](https://eprint.iacr.org/2025/068)). This is a hard project rule, on the same footing as the trust model above:

**Either the specification conforms to the source papers, or it deviates — and every deviation MUST be justified in the specification itself: explicitly, completely, and rigorously, stating what the paper does, what zkCoins does instead, and precisely why the change is sound.** A deviation without a written, bombproof justification is a spec bug, not a design choice.

- **Where the papers leave a choice open**, take the Bitcoin-consistent option and say so — that is an instantiation, not a deviation.
- **A deviation that moves a load-bearing security or trust boundary** (the nullifier relation, the accumulator, the availability model, the fee construction, the reorg/no-op semantics) does not inherit the source papers' proofs. It MUST carry its own security argument; until it has one, the spec **MUST NOT** describe it as a "faithful port" or an "exact paper-model" construction.
- **Deviations are tracked, never hidden.** Every one is registered with its rationale and release gate in the [Paper-Deviation Analysis](/paper-conformance-analysis) and [Paper-Conformance Remediation](/paper-conformance-remediation), and any open contradiction is listed in [Risks](/risks) and as a GitHub issue until it is closed.
- The single-source-of-truth rule of the implementation mandate applies: if a spec claim overstates conformance, that is a spec bug — open a PR against `docs`, do not paper over it.

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
├── docs/                         # Markdown content
│   ├── intro.md                  # Landing page (slug: /)
│   ├── architecture.md           # Components, repositories, boundaries, deployments
│   ├── requirements.md           # The eleven protocol requirements
│   ├── specification.md          # The normative protocol specification (single source of truth)
│   ├── implementation-mandate.md # Standing instruction to every implementor
│   ├── protocol.md               # Shielded CSV protocol reference
│   ├── comparisons.md            # vs RGB, Lightning, Zcash, etc.
│   ├── risks.md                  # Known risks and limitations
│   ├── assurance.md              # Assurance roadmap (incentive analysis, verification staircase, gates)
│   ├── paper-conformance-analysis.md    # Living deviation register + pinned audit snapshot
│   ├── paper-conformance-remediation.md # Gates A–C
│   ├── lightning-bridge.md       # Off-by-default operator extension (Lightning)
│   └── mail-bridge.md            # Off-by-default operator extension (mail)
├── src/css/custom.css            # Theme overrides (Bitcoin orange)
├── static/img/                   # Favicon, logos
├── docusaurus.config.js          # Site config
├── sidebars.js                   # Navigation structure
└── package.json                  # Dependencies (webpack pinned to 5.97.1)
```

## Git Workflow

| Branch | Purpose | Deploy |
|---|---|---|
| `develop` | Default, active development | Cloudflare Pages preview (dev-docs.zkcoins.app) |
| `main` | Production | Cloudflare Pages production (docs.zkcoins.com) |

- **Push to `develop` via feature branch + PR** (branch ruleset active)
- **`main` is protected** — changes only via PR

## Writing Docs

### File Format

Every doc page needs frontmatter:

```markdown
---
title: Page Title
---

# Page Title

Content starts here.
```

Page order is controlled exclusively by `sidebars.js` — do not add `sidebar_position` frontmatter.

### Style Guide

- **English only** — all documentation in English
- **Present tense** — "The server scans blocks" not "The server will scan blocks"
- **Active voice** — "The user creates a wallet" not "A wallet is created by the user"
- **No marketing language** — be technical and precise
- **Code blocks** — always specify the language (`typescript`, `rust`, `bash`, `json`)

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
- Push to `main` (via PR) → builds production at `docs.zkcoins.com`

No Docker, no server — pure static hosting on Cloudflare's edge CDN.

## Theme

- **Dark mode default** — `colorMode.defaultMode: "dark"` in `docusaurus.config.js`
- **Bitcoin orange** — primary color `#f7931a` defined in `src/css/custom.css`
- **Background** — `#0a0a0a` (matches the wallet app)

## Related Repos

- [zk-coins/app](https://github.com/zk-coins/app) — Web application
- [zk-coins/node](https://github.com/zk-coins/node) — Rust backend
