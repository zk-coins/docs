---
sidebar_position: 4
title: Transaction Flow
---

# Transaction Flow

zkCoins has three state transitions: **mint** (create account / issue an asset), **send**, and **receive** ([spec §2.3](/specification#23-state-transitions)). The wallet holds the spend key and signs each transition; its node builds the recursive validity proof, and a permissionless publisher anchors the batch on Bitcoin.

:::info Normative spec
The normative target is the batched publisher flow of the [Specification §3](/specification#3--on-chain-layer): off-chain `SpendRecord`s aggregated into `BatchBundle`s, attested by an `AggregateBatchProof`, and anchored by one constant 231-byte `BatchInscription` per batch. The *Publisher selection and fees* section below describes that target design.
:::

## Publisher selection and fees (spec design)

In the normative batched design ([spec §3.8](/specification#38-fees-and-economics)), anchoring is performed by a permissionless **publisher** the wallet chooses:

1. **Selection.** The wallet picks a publisher from the publisher's signed Nostr **publisher profile** — `{ publisher_pubkey, fee_address, fee_asset_id, fee, relays }`, signed by the publisher's node identity, so the advertised key is bound to the operator.
2. **Fee coin.** The wallet adds one ordinary output coin paying the publisher's `fee_address` to the very transition being anchored — **under the same `ocr`** (output-coins root) as the payment itself. On-chain it is indistinguishable from any other output.
3. **Atomicity.** Because the fee coin and the payment are outputs of the transition's single `SpendRecord`/`ocr`, the publisher cannot collect the fee without anchoring the payment: the fee coin of an un-anchored transition never reaches `completed`.
4. **Censorship handling.** If the chosen publisher fails to anchor within its retry window, the wallet re-builds the transition against a different publisher (with a fresh fee coin) — but it **MUST** treat the first transition as abandoned only after confirming that its nullifiers are not yet admitted at `NAV(tip)` ([spec §3.8](/specification#38-fees-and-economics)); a late-anchoring first publisher simply wins the race. Nullifier idempotence guarantees at most one of the competing transitions is ever admitted, so the spender pays exactly one fee — to whichever publisher actually anchors.