---
sidebar_position: 9
title: Aliasing (Design)
---

# Aliasing

:::info Design document
This page describes a **proposed design**, not the current implementation. Today's behaviour is documented in [Addressing](./addressing.md). The properties described below depend on protocol-level work that is tracked separately (see [SPEC.md §15 D2/D10](https://github.com/zk-coins/node/blob/develop/SPEC.md) and [zk-coins/node#170](https://github.com/zk-coins/node/issues/170)).
:::

## Guiding principles

Two non-negotiable constraints shape this design.

**1. Aliases are the identity. Everything else is plumbing.**
Users only ever see, share, or type `name@zkcoins.app`. Raw hex strings, public keys, BIP-32 indices and commitments exist — but only inside the protocol and the node, never in the wallet UI and never on the SDK surface.

**2. The wallet SDK looks like every other wallet SDK.**
Integrators (Cake Wallet, LayerZ, BlueWallet, …) work with **seed and address** — exactly the two concepts they already know from Bitcoin, Monero, Lightning. The SDK exposes no zk-specific concepts: no view-key / spend-key split, no ECDH, no BIP-32 index management, no scan loop, no two-phase commit, no proof IDs. Everything that is not seed-or-address is delegated to the node.

**Trust model:** the node operator sees the same plaintext as today. Users who don't want to trust the public operator run their own node. This is the deliberate trade-off that keeps the SDK trivial to integrate.

## Layer model

| Layer | Visibility | Contents | Lives in |
| --- | --- | --- | --- |
| **1. Alias** | user-facing, public | `bob@zkcoins.app` | wallet UI |
| **2. SDK surface** | wallet integrator | `seed`, `address`, `balance`, `send`, `history` | SDK |
| **3. Directory + payment derivation** | node-internal | `scan_pub`/`spend_pub` lookup, per-send `payment_tag` (ECDH) | node |
| **4. State** | account owner only (authenticated) | balance, history, send counter | node |
| **5. On-chain** | anyone | 64-byte opaque nullifier (unchanged) | Bitcoin chain |

The clean separation across these five layers is the architectural change. Layers 1, 2, and 5 are what wallets and users see. Layers 3 and 4 are entirely the node's responsibility.

## Layer 1 — Alias

| Property | Definition |
| --- | --- |
| Form | `name@<directory-host>`, e.g. `bob@zkcoins.app` |
| Lifetime | permanent, no rotation |
| Uniqueness | within one directory host |
| Reservation | signed claim using the wallet's signing key |
| Recovery | deterministic from the seed (claim signature reproducible) |
| Raw hex in UI | **never** — not in settings, export, or QR captions |
| QR encoding | the alias string itself, not the underlying bytes |

Self-hosting means running an own directory host, e.g. `bob@bob.eu`. The alias scheme is host-transparent — wallets only need to resolve the host suffix.

## Layer 2 — SDK surface

The wallet SDK presents the same shape any familiar wallet SDK does. An integrator that has wired up a Bitcoin or Monero wallet recognises every method.

```ts
class ZkCoinsWallet {
  // Construction — from a BIP-39 mnemonic, like every other wallet SDK.
  static async fromMnemonic(
    mnemonic: string,
    opts?: { nodeUrl?: string; network?: "mainnet" | "testnet" },
  ): Promise<ZkCoinsWallet>;

  // Properties — synchronous, computed once from the seed.
  readonly address: string;          // "bob@zkcoins.app"

  // State — async, served by the node.
  getBalance(): Promise<{ confirmed: bigint; pending: bigint }>;
  getHistory(opts?: { limit?: number; offset?: number }): Promise<Tx[]>;
  validateAddress(s: string): boolean;

  // Transaction — single atomic call. No two-phase commit on the SDK surface.
  send(to: string, amountSats: bigint): Promise<{ txid: string }>;

  // Optional, off the hot path — upgrade default alias to a vanity name.
  claimUsername(name: string): Promise<string>;  // returns the new address
}
```

That is the entire surface. One constructor, one property, six methods.

**What the SDK does internally:**

- BIP-39 → BIP-32 derivation of a single wallet signing key.
- Schnorr signing of outgoing requests (`send`, authenticated reads, alias claim).
- HTTP transport to the node.
- Alias parsing and basic validation.

**What the SDK does NOT do:**

- No ECDH or per-send key derivation.
- No view-key / spend-key separation.
- No BIP-32 index management or `num_sends` tracking.
- No scan loop, no candidate-set processing.
- No proof generation, no proof verification, no proof IDs.
- No two-phase send/commit choreography.
- No on-chain access (no Bitcoin node connection from the wallet).

Everything in the second list happens behind `/api/send` and `/api/balance` on the node.

### Integration shape for popular wallets

| Wallet target | Mapping |
| --- | --- |
| **Cake Wallet** `WalletService` | `restore` → `fromMnemonic`, `address` getter → `wallet.address`, `balance` → `getBalance`, `createTransaction` + `commit` → `send`, `transactionHistory` → `getHistory` |
| **LayerZ** | same shape; `send` is single-step |
| **BlueWallet** | same shape |
| **Custom wallets** | depend only on `fromMnemonic`, `address`, `send`, `getBalance`, `getHistory` |

The integration effort is comparable to adding a second Bitcoin-family chain (Litecoin, Bitcoin Cash) — a fraction of the effort that Monero or Ethereum require, because the SDK does not own any on-chain scanning machinery.

## Layer 3 — Directory and payment derivation (node-internal)

This entire layer is invisible to the wallet and to the SDK. It lives inside the node.

When a wallet calls `wallet.send("alice@zkcoins.app", amount)`, the SDK forwards the alias as an opaque string to the node. The node:

1. Resolves the alias to Alice's account material (`scan_pub`, `spend_pub`).
2. Generates an ephemeral keypair `(e_priv, e_pub)`.
3. Computes `shared = ECDH(e_priv, scan_pub)`.
4. Derives `payment_tag = H(shared, send_index)` — distinct per send, even to the same recipient.
5. Writes `Coin.recipient_commit = payment_tag` and `Coin.scan_hint = e_pub` into the coin.
6. Runs the Plonky2 prover and publishes the nullifier as today.

Properties this preserves:

- **On-chain unlinkability** — two sends to the same alias produce two unrelated commitments. Outside observers cannot link them. (This is the direct fix for SPEC §15 D2.)
- **Cross-sender unlinkability against outside observers** — three different senders paying Alice produce three unlinkable on-chain artifacts.
- **No wallet complexity** — the SDK is unaware that any of this happens.

What this does **not** preserve, and accepts as the trust trade-off:

- The node operator sees plaintext at request time (sender, alias, amount). The same trust assumption that already holds today.
- A malicious operator could collapse the per-send derivation (e.g., reuse nonces) and reintroduce on-chain linkability. Mitigation: self-hosting, or third-party audits of the running operator binary.

## Layer 4 — State (node, authenticated reads)

`/api/balance`, `/api/history`, and the alias claim endpoint all require a Schnorr-signed request, using the wallet's single signing key derived from the seed. The node keys reads on the account hash, never on the alias.

Two capability levels, sufficient for every wallet flow:

| Capability | Held by | What it grants |
| --- | --- | --- |
| **Receive** | anyone with the alias | sending coins to the alias |
| **Account** | wallet signing key | reading state, spending coins, claiming aliases |

There is intentionally no separate view-key. View-only flows (accountant access, watching wallets, …) are out of scope for this design — they would either complicate the SDK or require a node-side delegation mechanism, both of which conflict with the integration-simplicity constraint.

## Layer 5 — On-chain

Unchanged from the current protocol: 64-byte half-aggregate Schnorr nullifier, Taproot inscription, `4242` marker prefix. Only the *contents* committed inside the coin change (from plaintext address to `payment_tag` with `scan_hint`).

## User-level operations

| User action | What happens internally |
| --- | --- |
| **Create wallet** | Seed generated → wallet signing key derived → SDK calls node to register a default alias (`<deterministic-prefix>@<host>`) → `wallet.address` is set |
| **Receive** | The user shares `bob@zkcoins.app`. Nothing else. |
| **Send** | User types `alice@zkcoins.app`; SDK signs and POSTs to the node; the node does directory lookup, ECDH, prover, broadcast |
| **Restore** | Seed entered → wallet signing key reproduced → SDK calls node, node returns the alias and the current balance |
| **Vanity name (optional)** | `wallet.claimUsername("bob")` → signed claim → node updates the alias for this account |

## Protocol operations

| Operation | Endpoint | Authentication |
| --- | --- | --- |
| **Resolve alias** | `GET /.well-known/zkcoins/resolve/:name` | none — pure routing, returns directory material only |
| **Claim alias** | `POST /api/alias/claim` | Schnorr signature with wallet key over `(name, account_pub)` |
| **Pay** | `POST /api/send` | sender's Schnorr signature; the alias is in the request body, the node does the rest |
| **Read state** | `GET /api/{balance,history}` | recipient's Schnorr signature |

The wallet SDK touches only `claim`, `send`, and `read state`. The `resolve` endpoint is consumed by the node itself.

## What this addresses

| Problem (current state) | After aliasing |
| --- | --- |
| Hex strings visible in the UI | Solved — only aliases appear in the UI |
| Username-resolve → address → balance / history lookup | Solved — resolve returns routing material only; reads are authenticated |
| Cross-sender linkability of payments to the same recipient (on-chain) | Solved — each send derives an independent `payment_tag` |
| On-chain coin linkability (SPEC §15 D2) | Solved — coin carries a commitment, not a plaintext address |
| `num_sends` as a public activity counter | Solved — behind authentication |
| Address rotation as a privacy workaround | Not required — the alias is permanently stable |
| Wallet SDK complexity blocking integrations | Solved — SDK collapses to seed + address + four methods |

## What this does **not** address

| Problem | Why it remains |
| --- | --- |
| Operator visibility into `/api/send` plaintext | Server-side prover still observes `(sender, alias, amount)`. This is [zk-coins/node#170 P3/P9](https://github.com/zk-coins/node/issues/170) and is the **deliberate trust trade-off** that enables the simple SDK. Users who do not want to trust the public operator self-host. |
| Operator linkability of `payment_tag` to a recipient | Implicit in operator visibility; identical mitigation (self-host). |
| Alias squatting | A UX/policy concern (first-come, reservation window, fee, …), not a privacy property. |
| Migration between directory hosts | Intentionally out of scope. Aliases are host-bound. |
| View-only / watch-only wallet access | Intentionally out of scope. Would require either SDK complexity or a node-side delegation flow; both conflict with the integration-simplicity constraint. |

## Default choices

| Question | Default | Rationale |
| --- | --- | --- |
| Where does ECDH / payment derivation run? | **Node** | Required by the SDK-simplicity constraint. Operator-trust trade-off accepted; self-host is the escape hatch. |
| Alias format | **`name@host`** (RFC 5321-compatible) | Universally shareable, copy/paste-friendly, double-click-selectable in any browser. |
| Default alias on wallet creation | **Deterministic prefix from the seed**, e.g. `<8–12 hex chars>@<host>` | No hex ever shown to the user; the alias is fully derivable on restore even without a custom name |
| Aliases per wallet | **One primary alias** | Matches the mental model of every other wallet SDK; reduces UI surface |
| View-key separation | **None** | Out of scope; see above |

## Open items before implementation

1. How `payment_tag` slots into the Plonky2 circuit. Adjacent to SPEC §15 D2/D10 which already plans the commitment-based recipient.
2. Default-alias derivation rule: prefix length, collision strategy, whether the prefix is checksummed.
3. Alias squatting policy: first-come, reservation window, burn-fee, or subdomain-style namespacing.
4. SDK packaging: does `@zkcoins/sdk` v0.2 ship the new surface as a clean replacement, or as an additive `ZkCoinsWallet` class alongside the existing lower-level `ZkCoinsClient`?

## Relationship to existing documents

- [Addressing](./addressing.md) — describes the **current** three-phase address scheme. This document supersedes it once implemented.
- [Privacy Model](./privacy-model.md) — describes what is and is not private today. Aliasing changes both the "what is hidden" and "what is visible" tables.
- [Nullifier Design](./nullifier-design.md) — unchanged. Aliasing operates on the coin contents, not the nullifier itself.
- [SPEC.md §15](https://github.com/zk-coins/node/blob/develop/SPEC.md) — circuit-level divergences D2 and D10 are the cryptographic prerequisites for aliasing.
- [zk-coins/node#170](https://github.com/zk-coins/node/issues/170) — network-layer decentralization problems. Aliasing closes the read-side privacy gap (P10) but does not address the prover-locality issues (P3, P9), which remain mitigated only by self-hosting.
