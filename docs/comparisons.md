---
sidebar_position: 7
title: Comparisons
---

# Comparisons

How does Shielded CSV compare to other privacy and scaling approaches?

## vs. RGB

Both use Client-Side Validation on Bitcoin, but serve different purposes.

| | Shielded CSV | RGB |
|---|---|---|
| **Focus** | Private payments | Smart contracts + tokens |
| **Privacy** | Full (ZK proofs hide everything) | Limited (history visible to participants) |
| **Proof size** | Constant (independent of history) | Grows with transaction history |
| **On-chain data** | 64 bytes per TX | Full Bitcoin transaction |
| **Smart contracts** | No | Yes (zk-AluVM, Turing-complete) |
| **DeFi/Lending** | Not possible | Possible (bilateral) |
| **Status** | Research / early prototype | Mainnet (v0.12) |

:::tip Complementary, not competing
zkCoins for the **payment layer** (privacy + scalability), RGB for **programmable logic** (lending, tokens). Both use Client-Side Validation on Bitcoin L1.
:::

## vs. Lightning Network

| | Shielded CSV | Lightning |
|---|---|---|
| **Layer** | L1 (Client-Side Validation) | L2 (payment channels) |
| **Privacy** | Full (ZK proofs) | Good (onion routing) |
| **Interactivity** | Receiver must be reachable | Routing path required |
| **Capacity** | ~100 TPS on L1 | Theoretically unlimited |
| **Offline receive** | No | No |
| **Status** | Research | Production |

Lightning and Shielded CSV are complementary. CSV assets could theoretically flow through Lightning channels.

## vs. Zcash

| | Shielded CSV | Zcash |
|---|---|---|
| **Blockchain** | Bitcoin (existing) | Own chain |
| **Consensus change** | None needed | Own consensus |
| **Privacy model** | Mandatory for CSV users | Optional (~10-20% usage) |
| **ZK system** | PCD (Folding/STARKs) | Halo2 |
| **Trusted setup** | None | Eliminated since NU5 |
| **On-chain footprint** | 64 bytes/TX | Full transaction |
| **Maturity** | Research phase | Production since 2016 |

## vs. Monero

| | Shielded CSV | Monero |
|---|---|---|
| **Blockchain** | Bitcoin | Own chain |
| **Privacy approach** | ZK proofs | Ring signatures + Stealth + RingCT |
| **Anonymity set** | **All coins ever created** | Ring of 16 decoys |
| **Scalability** | ~64 bytes on-chain | ~2-3 KB per TX |
| **Statistical attacks** | Not possible | Possible (decoy selection analysis) |
| **Maturity** | Research phase | Production since 2014 |

## vs. CoinJoin

| | Shielded CSV | CoinJoin (Wasabi/JoinMarket) |
|---|---|---|
| **Anonymity set** | All coins | Round participants only |
| **Amounts hidden** | Yes | No (equal-output) |
| **Coordinator** | None | Required |
| **On-chain analysis** | Not possible | Difficult but not impossible |
| **Cost** | 1 nullifier (cheap) | Multiple UTXOs (expensive) |
| **Regulatory risk** | Low (no coordinator) | High (coordinators prosecuted) |

## vs. Silent Payments (BIP352)

| | Shielded CSV | Silent Payments |
|---|---|---|
| **Goal** | Full transaction privacy | Receive-only privacy |
| **Amounts hidden** | Yes | No |
| **Transaction graph hidden** | Yes | No |
| **Complexity** | High | Moderate |
| **Maturity** | Research | Near production |

Silent Payments solve a different problem (reusable addresses). They could serve as a **receive mechanism** for Shielded CSV in the future.

## Bitcoin privacy landscape (2025/2026)

| Technology | Privacy level | Status |
|---|---|---|
| **Shielded CSV** | Maximum (full ZK) | Research |
| **Silent Payments (BIP352)** | Receive-only | Near production |
| **PayJoin (BIP77/78)** | Send-privacy | Production |
| **CoinJoin** | Medium (statistical) | Under regulatory pressure |
| **Lightning (BOLT12)** | Good (routing) | Production |

Shielded CSV is the most ambitious privacy solution for Bitcoin, but also the furthest from production readiness. Silent Payments are the pragmatic short-term choice.
