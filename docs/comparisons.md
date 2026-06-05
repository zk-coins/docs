---
sidebar_position: 7
title: Comparisons
---

# Comparisons

How does zkCoins compare to other privacy and scaling approaches — and what, precisely, makes it different?

## Where zkCoins sits

zkCoins is the first real-world **implementation** of two whitepapers:

- the **Shielded CSV** construction by Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), and Robin Linus (ZeroSync) — [eprint 2025/068](https://eprint.iacr.org/2025/068);
- the original **zkCoins** concept, prototyped as [ZeroSync/ZKCoins](https://github.com/ZeroSync/ZKCoins).

The project at **zkcoins.com does not compete with these papers — it realizes them.** It claims no invention of the underlying scheme; its contribution is bringing the design to a running node, wallet, and the off-chain transport/recovery layer needed to operate it. Where this page says "zkCoins", read "the Shielded CSV scheme as realized by zkCoins".

## The differentiator is a combination, not a single property

Privacy alone is not new. Decentralization alone is not new. Even *privacy + decentralization together* is not new — Monero and Zcash have shipped both for years. What is rare is a **specific triple**:

- **Bitcoin-anchored** — settles on Bitcoin L1, with no own chain, token, or consensus to bootstrap. It inherits Bitcoin's decentralization instead of building a new one.
- **Shielded** — a real anonymity set with ZK unlinkability, not merely "data kept off the public chain".
- **Trustless** — correctness enforced by cryptography and Bitcoin, with no trusted operator, mint, or federation.

Almost every related protocol nails **two of the three** and misses the third:

| Protocol(s) | Bitcoin-anchored | Shielded (anon-set) | Trustless | Misses |
|---|---|---|---|---|
| Monero, Zcash, Penumbra, Namada, Firo, Iron Fish | ✗ own chain | ✓ | ✓ | not Bitcoin — own security budget/token |
| RGB, Taproot Assets | ✓ | ✗ counterparty sees full provenance | ✓ | no anonymity set |
| Cashu, Fedimint | ✓ | ✓ (blinded) | ✗ custodial / federated | not trustless |
| Railgun, Aztec, Tornado Cash | ✗ Ethereum, on-chain data | ✓ | ~ | not Bitcoin, on-chain data |
| Liquid, Statechains / Mercury | ✓ | ~ / ✗ | ✗ federation | federated |
| Shade | ✗ Secret Network | ✓ (via TEE) | ~ | privacy via trusted hardware, not ZK |
| **zkCoins (Shielded CSV)** | ✓ | ✓ | ◐ (design today, see note) | — |

:::note Design today vs. fully shipped
The trustless corner is the design goal and the load-bearing fact is already true: the full commitment — including the signing public key — is what lands on Bitcoin, so a wallet can re-derive and verify its own history from seed + chain. But two pieces are still on the roadmap: **trustless receive** (full recursive-proof re-verification on receipt — strand S1) and a **queryable double-spend / nullifier accumulator** (strand S2). Until those land, the honest framing is *"the first design to realize the combination,"* not *"fully trustless in production."*
:::

---

## Deep dives

### vs. RGB

Both use Client-Side Validation on Bitcoin, but serve different purposes.

| | zkCoins (Shielded CSV) | RGB |
|---|---|---|
| **Focus** | Private payments | Smart contracts + tokens |
| **Privacy** | Full (ZK proofs hide everything; global anonymity set) | Limited (history revealed to counterparty) |
| **Proof size** | Constant (independent of history) | Grows with transaction history |
| **On-chain footprint** | Full commitment (~177 B, constant) in the Taproot reveal witness | Commitment in a host TX; off-chain consignment grows |
| **Smart contracts** | No | Yes (zk-AluVM, Turing-complete) |
| **DeFi/Lending** | Not yet | Possible (bilateral) |
| **Status** | Research / early implementation | Mainnet (v0.12) |

:::tip Complementary, not competing
zkCoins for the **payment layer** (privacy + scalability), RGB for **programmable logic** (lending, tokens). Both use Client-Side Validation on Bitcoin L1.
:::

### vs. Taproot Assets

The closest "assets on Bitcoin via CSV" cousin, from Lightning Labs.

| | zkCoins (Shielded CSV) | Taproot Assets |
|---|---|---|
| **Validation** | Client-Side Validation + ZK | Client-Side Validation (Merkle proofs) |
| **Privacy** | Full shield (anonymity set) | Transparent — proofs reveal asset, amount, lineage to the counterparty |
| **Data availability** | Off-chain bundle + node/relay | Universe servers (off-chain proof archives) |
| **Anchor** | Bitcoin Taproot | Bitcoin Taproot |
| **Status** | Research / early implementation | Mainnet |

Taproot Assets shares the Bitcoin anchor and the off-chain-data model, but has **no shielding** — it is the "Bitcoin + decentralized, but not private" corner of the triangle.

### vs. Lightning Network

| | zkCoins (Shielded CSV) | Lightning |
|---|---|---|
| **Layer** | L1 (Client-Side Validation) | L2 (payment channels) |
| **Privacy** | Full (ZK proofs) | Good (onion routing) |
| **Interactivity** | Receiver must be reachable | Routing path required |
| **Capacity** | Bounded by Bitcoin L1 (one compact commitment per TX) | Theoretically unlimited |
| **Offline receive** | No | No |
| **Status** | Research | Production |

Lightning and Shielded CSV are complementary; CSV assets could theoretically flow through Lightning channels.

### vs. Zcash

| | zkCoins (Shielded CSV) | Zcash |
|---|---|---|
| **Blockchain** | Bitcoin (existing) | Own chain |
| **Consensus change** | None needed | Own consensus |
| **Privacy model** | Mandatory for CSV users | Optional (~10-20% usage) |
| **ZK system** | Plonky2 (cyclic recursion, FRI) | Halo2 |
| **Trusted setup** | None | Eliminated since NU5 |
| **On-chain footprint** | Full commitment (~177 B, constant) | Full transaction |
| **Maturity** | Research phase | Production since 2016 |

Zcash is the conceptual parent of the commitment/nullifier shield. The key divergence: Zcash secures its own chain; zkCoins inherits Bitcoin's.

### vs. Monero

| | zkCoins (Shielded CSV) | Monero |
|---|---|---|
| **Blockchain** | Bitcoin | Own chain |
| **Privacy approach** | ZK proofs | Ring signatures + Stealth + RingCT |
| **Anonymity set** | **All coins ever created** | Ring of 16 decoys |
| **Scalability** | ~177 B on-chain, constant | ~2-3 KB per TX |
| **Statistical attacks** | Not possible | Possible (decoy-selection analysis) |
| **Maturity** | Research phase | Production since 2014 |

### vs. CoinJoin

| | zkCoins (Shielded CSV) | CoinJoin (Wasabi/JoinMarket) |
|---|---|---|
| **Anonymity set** | All coins | Round participants only |
| **Amounts hidden** | Yes | No (equal-output) |
| **Coordinator** | None | Required |
| **On-chain analysis** | Not possible | Difficult but not impossible |
| **Cost** | 1 commitment (constant) | Multiple UTXOs (expensive) |
| **Regulatory risk** | Low (no coordinator) | High (coordinators prosecuted) |

### vs. Silent Payments (BIP352)

| | zkCoins (Shielded CSV) | Silent Payments |
|---|---|---|
| **Goal** | Full transaction privacy | Receive-only privacy |
| **Amounts hidden** | Yes | No |
| **Transaction graph hidden** | Yes | No |
| **Complexity** | High | Moderate |
| **Maturity** | Research | Near production |

Silent Payments solve a different problem (reusable addresses) and could serve as a **receive mechanism** for Shielded CSV in the future.

---

## The wider landscape

The protocols below all rhyme with zkCoins on at least one axis. They are grouped by *how* they relate, with the one difference that matters most for each.

### Client-Side Validation on Bitcoin (the closest family)

Off-chain data, on-chain commitment, validation by the client.

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Shielded CSV** | The construction zkCoins implements | — (the basis, not a competitor) |
| **RGB** | CSV smart contracts + tokens on Bitcoin | No anonymity set; counterparty sees full provenance |
| **Taproot Assets** ([repo](https://github.com/lightninglabs/taproot-assets)) | Assets in a Taproot tree, universe servers | Transparent — no shielding |
| **Single-use seals** (Peter Todd) | The primitive RGB / TA build on | A building block, not a payment system |

### Shielded ZK value transfer (on their own chains)

Private **and** decentralized — but each runs its own chain, token, and security budget.

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Zcash** | Shielded pool, note commitments + nullifiers | Own chain (the model zkCoins borrows, on Bitcoin) |
| **Monero** | Ring signatures + RingCT + stealth addresses | Own chain; decoy-ring privacy, not a ZK anonymity set |
| **Penumbra** | Shielded Cosmos zone (private DEX/staking) | Own PoS chain |
| **Namada** | Multi-asset shielded pool (MASP), Cosmos | Own PoS chain |
| **Iron Fish** | Account-based shielded L1 | Own chain |
| **Firo** | Lelantus Spark, one-time addresses | Own chain |
| **Zano** | Confidential L1 with auditable wallets | Own chain |
| **Aleo** | Private-by-default L1, ZK execution (snarkVM) | Own chain; general computation |

### Privacy on smart-contract chains

Shielded, but on Ethereum-class chains with on-chain data.

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Railgun** ([repo](https://github.com/railgun-privacy)) | Shielded pool as an EVM smart contract | Ethereum; on-chain data; depends on that chain |
| **Aztec** | ZK privacy L2, private contracts (Noir) | Ethereum L2; not Bitcoin |
| **Tornado Cash** | Fixed-denomination mixer (commitment/nullifier) | Ethereum; mixer, not a payment system; sanctioned |

### Client-data / stateless ZK rollups

Mechanically the nearest non-Bitcoin relatives: the client holds the data, the chain holds a commitment.

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Intmax / Intmax2** | Stateless ZK-rollup, client-held data, minimal on-chain footprint | Ethereum-anchored; privacy is not the primary goal |
| **Plasma** (historical) | Off-chain state + on-chain commitments + fraud proofs | Fraud-proof model, not ZK; largely superseded |

### Bitcoin asset overlays (on-chain data, no privacy)

The historical "issue assets on Bitcoin" lineage. Data is on-chain and transparent.

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Omni Layer** (ex-Mastercoin) | OP_RETURN asset metadata; carried early USDT | On-chain data, no privacy, no CSV |
| **Counterparty (XCP)** | Assets + DEX encoded in Bitcoin transactions | On-chain, transparent |
| **Colored Coins / Open Assets** | Tag specific satoshis as assets | Earliest, fully transparent |
| **Ordinals / Runes / BRC-20** | Inscriptions and Runes for issuance | On-chain data, no privacy |

### Off-chain Bitcoin value / Chaumian ecash

Off-chain value with a Bitcoin peg; privacy via blind signatures rather than ZK.

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Cashu** | Chaumian ecash (blinded bearer tokens) | Custodial — the mint holds the funds |
| **Fedimint** | Federated Chaumian ecash | Federated custody (threshold of guardians) |
| **Ark** | Off-chain Bitcoin via shared VTXOs | Not asset/privacy focused; liquidity-provider dependent |
| **Statechains / Mercury** | Off-chain transfer of UTXO ownership | Relies on a federation/entity; weak privacy |

### Confidential, but a different trust model

| Protocol | What it is | Key difference from zkCoins |
|---|---|---|
| **Liquid** | Confidential Transactions sidechain | Federated (functionaries), not trustless |
| **MimbleWimble** (Grin / Beam) | CT + cut-through, no persistent addresses | Own chain; CoinJoin-style privacy, no anonymity set |
| **Shade** ([repo](https://github.com/shadeprotocolcom)) | Privacy DeFi on Secret Network | Privacy via TEE/SGX (trusted hardware), not ZK/CSV |

---

## Bitcoin privacy landscape (2025/2026)

| Technology | Privacy level | Status |
|---|---|---|
| **Shielded CSV** | Maximum (full ZK) | Research |
| **Silent Payments (BIP352)** | Receive-only | Near production |
| **PayJoin (BIP77/78)** | Send-privacy | Production |
| **CoinJoin** | Medium (statistical) | Under regulatory pressure |
| **Lightning (BOLT12)** | Good (routing) | Production |

Shielded CSV is the most ambitious privacy solution for Bitcoin, and also the furthest from production readiness. Silent Payments are the pragmatic short-term choice; Shielded CSV is the long game on the *Bitcoin · Shield · Trustless* triangle.
