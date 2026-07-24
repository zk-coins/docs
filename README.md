# zkCoins

**Private Bitcoin payments via Shielded CSV** — no new chain, no token, no consensus change, no trusted operator. Only Bitcoin, zero-knowledge proofs, and the user's own keys.

This is the **documentation repository** and the single place that describes the whole system end to end. New here? Start with the **[Specification](https://docs.zkcoins.com/specification)** (the full A-to-Z technical design) or the **[Requirements](https://docs.zkcoins.com/requirements)**.

| | Production | Dev |
|---|---|---|
| **Docs** | [docs.zkcoins.com](https://docs.zkcoins.com) | [dev-docs.zkcoins.app](https://dev-docs.zkcoins.app) |
| **Wallet app** | [zkcoins.app](https://zkcoins.app) | [dev.zkcoins.app](https://dev.zkcoins.app) |
| **Bitcoin network** | mainnet | Bitcoin Signet |

The Bitcoin network is a per-deployment **env variable** — production runs on **mainnet**, dev against **Bitcoin Signet** — so every node operator chooses their own.

## What zkCoins is

zkCoins lets you send value on Bitcoin without anyone seeing the amount, the asset, who paid, or who received. Coin contents never touch the chain — they travel privately between sender and receiver as encrypted bundles; only the nullifier is public, carrying no amount, asset, sender, or recipient. Every send, receive, and mint publishes its own small on-chain nullifier `(Pkᵢ, Rᵢ)` (~64 bytes); a permissionless **publisher** only NISSHAC half-aggregates the BIP-340 signatures into one inscription — it runs no circuit, holds no keys, and produces no proof. Every **node** rebuilds the global nullifier accumulator itself as a pure first-occurrence function of the on-chain nullifiers, keyed by `Pkᵢ`; a given key can be admitted only once, so any second spend is rejected. Your **seed** derives every key, your **wallet** is the only thing that can spend, **any node** can serve you, and you verify every figure against Bitcoin yourself.

Built on the zkCoins concept (Robin Linus) and the Shielded CSV construction (Jonas Nick, Liam Eagen, Robin Linus).

## The system, end to end

zkCoins spans several repositories; the specification in this repo covers all of it — hardware to app. The layers, top to bottom:

| Layer | What it is | Repo |
|---|---|---|
| **App · Explorer** | end-user wallet (NIP-05 `user@domain` receive identity) · public explorer web-app | [`zk-coins/app`](https://github.com/zk-coins/app) · `zk-coins/explorer` *(planned)* |
| **SDK** | thin TypeScript client — on-device keys, signing, node/API calls | [`zk-coins/sdk`](https://github.com/zk-coins/sdk) |
| **zkCoins API** | public REST + optional operator-hosted NIP-05 names, hosted-wallet service (optional) | currently in [`zk-coins/node`](https://github.com/zk-coins/node); a separate API layer is the target design |
| **zkCoins node** | trustless kernel — scan · accumulator · verify · prove · store · publisher | [`zk-coins/node`](https://github.com/zk-coins/node) |
| **bitcoind · Nostr relay** | Bitcoin L1 settlement and ordering · off-chain transport and data availability | upstream (own or external) |

Supporting repos: [`zk-coins/research`](https://github.com/zk-coins/research) (protocol research, upstream references), [`zk-coins/plonky2`](https://github.com/zk-coins/plonky2) (Plonky2 proving stack), and **`zk-coins/docs`** (this repo). See the spec's **full system stack** section for the complete picture, including the operational layers (Docker, OS, hardware).

## This repository (docs)

A Docusaurus site published to Cloudflare Pages. Sections: Introduction, Requirements, **Specification**, Implementation Mandate, Protocol, Comparisons, Risks, Assurance Roadmap.

### Development

```bash
npm install
npm start    # http://localhost:3092
```

### Build

```bash
npm run build
npm run serve
```

Note: webpack is pinned to 5.97.1 (`overrides` in `package.json`) for Node 22 compatibility.

### Style

- English only, present tense, active voice
- Mermaid diagrams supported; Docusaurus admonitions (`:::warning`, `:::tip`, `:::info`)
- Dark mode default, Bitcoin orange (`#f7931a`)

## License

MIT
