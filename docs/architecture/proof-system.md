---
sidebar_position: 6
title: Proof System
---

# Proof System

zkCoins uses **Proof-Carrying Data (PCD)** — the central cryptographic abstraction of the Shielded CSV protocol. Each state transition produces a Zero-Knowledge proof that the new state is valid, without revealing any transaction details.

> This page is an architecture overview. The normative source is the single-page specification: [Proofs & State Transitions §2](/specification#2--proofs--state-transitions), [Trees §1.6](/specification#16-trees-one-global-structure-one-per-account-structure), and [The nullifier accumulator §3.7](/specification#37-the-nullifier-accumulator).

## What PCD provides

- Each transition generates a computation proof that consumes its predecessor's proof.
- Because the proof carries the whole history, outputs stay trustworthy without re-checking any prior step.
- **Proof size is constant** — independent of the account's or coin's transaction history.
- **Verification time is constant** — an account that transitioned 1000 times verifies as fast as a fresh one.
- With Zero-Knowledge, the proof hides amounts, balances, accounts, and the transaction graph. What becomes public is only the spent-coin **nullifiers** (carried in the off-chain, `k = 3`-replicated [`BatchBundle`](/specification#46-data-availability--replication-factor-k), not on Bitcoin) and the **accumulator roots** anchored on Bitcoin — never senders, recipients, amounts, or account links.

## Two circuits

The protocol uses **two** PCD circuits ([Proof types §2.2](/specification#22-proof-types)):

- **`C` — the per-account compliance circuit.** Produces an account's `InitialProof` and every subsequent `AccountUpdateProof`. It uses **cyclic recursion** (one fixed circuit that verifies proofs of itself), so verifier data is constant and an account's latest proof transitively attests every predecessor.
- **`C_batch` — the publisher's batch-aggregation circuit.** Produces one `AggregateBatchProof` per published batch. It verifies many `C`-proofs and the global accumulator's SMT update inside a single recursive proof, and is **constant-size in the member count `m`** (~100 KB typical).

| Type | Circuit | When | What it proves |
|---|---|---|---|
| `InitialProof` | `C` | first transition of an account (creation, optionally an issuance) | account creation is valid against the canonical empty account for `owner = H(Pk₀)`; no `prev_proof` |
| `AccountUpdateProof` | `C` | every subsequent transition | the previous proof was valid (recursive) **and** the new transition is valid |
| `AggregateBatchProof` | `C_batch` | one per [`BatchBundle`](/specification#46-data-availability--replication-factor-k), built by the publisher | every member's per-account validity, the batch's nullifier-set integrity, and `new_root = SMT.insert_many(prev_root, nfs)` |

## Plonky2 + Poseidon-Goldilocks

Both circuits are [Plonky2](https://github.com/0xPolygonZero/plonky2) circuits over the Goldilocks field with the Poseidon hash (`PoseidonGoldilocksConfig`), realising PCD through cyclic recursion ([Cryptographic primitives §1.1](/specification#11-cryptographic-primitives)).

```rust
// Conceptual: what the per-account compliance circuit C enforces per transition
// (the normative clauses are spec §2.1)
fn enforce() {
    // 1. Recursively verify the previous account proof against C's own verifier data
    //    (absent for an InitialProof, whose prev state is the canonical empty account)
    // 2. Verify the SINGLE per-transition BIP-340 signature by current_pubkey (Pkᵢ);
    //    for each input coin: account ownership + coin-history-SMT inclusion at
    //    "received-unspent" + identifier recomputation (there is no per-coin signature)
    // 3. Per-asset balance: sum(inputs) + mint >= sum(outputs)
    // 4. Derive each input nullifier nf = Hc("Nullifier", nk ‖ coin.identifier)
    //    (global double-spend is caught later by the publisher's AggregateBatchProof
    //    and the receiver's accumulator non-membership check, not inside C)
    // 5. Construct the output coins and their identifiers; bind output_coins_root
    // 6. Rotate the spend key (current_pubkey -> Pkᵢ₊₁), increment send_counter,
    //    update the coin-history SMT (mark inputs spent, admit new coins),
    //    and commit the new account-state hash (ash)
}
```

Because recursion is **cyclic**, a proof verifies against the circuit's own verifier data in constant time, regardless of how many transitions preceded it. A conforming verifier **MUST NOT** require, fetch, or re-execute any prior transition.

### What the batch proof binds

The publisher's `AggregateBatchProof` (`C_batch`) takes `prev_root`, `new_root`, and the bundle's content address as public inputs, and attests in zero knowledge ([§2.2](/specification#22-proof-types)):

- **Per-member soundness** — each member's `C`-proof verifies and matches its `SpendRecord`.
- **Sign-to-contract binding** — each member's S2C tweak ties its per-account proof to the record that referenced it.
- **Nullifier-set integrity** — the union of every member's nullifiers equals the batch's nullifier list, with no duplicates.
- **Accumulator transition correctness** — inserting those nullifiers into the SMT from `prev_root` yields exactly `new_root`.
- **Bundle-locator binding** — the proof commits to exactly one bundle content, so a publisher cannot serve a different member set under the same `(prev_root, new_root)`.

A scanner verifies **one** `AggregateBatchProof` per inscription — never one per member — and accepts the whole batch's accumulator transition on a single check.

## Data structures

zkCoins keeps **exactly two** Merkle structures. There is **no** global, account-keyed commitment tree and **no** Merkle Mountain Range.

| Structure | Scope | Purpose |
|---|---|---|
| **Coin-history SMT** | per account (Private) | sparse Merkle tree keyed by `coin.identifier`; provides in-circuit non-inclusion for double-spend prevention; its root is folded into the account-state hash `ash` and never leaves the proving context |
| **Nullifier accumulator** | global | 256-bit-depth SMT over every admitted nullifier; supports membership and non-membership; the protocol's **only** global structure |

Why no global account-keyed tree? A structure keyed by a stable account identifier would have to be **either** rebuildable from publicly verifiable data **or** privacy-preserving — never both. zkCoins keeps [privacy (Requirement 2)](/requirements) and [node portability (Requirement 10)](/requirements) at once by removing that structure entirely and anchoring double-spend protection in the nullifier accumulator alone ([Trees §1.6](/specification#16-trees-one-global-structure-one-per-account-structure)).

The accumulator's **state transitions** are anchored on Bitcoin — each [`BatchInscription`](/specification#31-the-on-chain-object) commits `prev_root → new_root` — and each transition's **validity** is attested by the off-chain `AggregateBatchProof` carried in the content-addressed, `k = 3`-replicated [`BatchBundle`](/specification#46-data-availability--replication-factor-k). Any honest node therefore tracks the accumulator by following the inscribed roots and verifying each batch's recursive proof: a pure function of confirmed Bitcoin data plus publicly verifiable bundles, identical for every node and requiring **no** trust in any peer.

```text
Per-account (Private):
  Coin-history SMT      — received/spent coins; root folded into `ash`

Global:
  Nullifier accumulator (256-depth SMT)
    ├─ prev_root → new_root anchored by BatchInscription on Bitcoin
    └─ per-transition validity attested by AggregateBatchProof (off-chain, k = 3)
```

## Prover

Per-account proofs (`C`) are produced wallet/node-side as part of building a transition; the batch-aggregation proof (`C_batch`) is produced by the **publisher** when it assembles many `SpendRecord`s into a bundle ([State transitions §2.3](/specification#23-state-transitions)). Every proof is a real Plonky2 proof with full Zero-Knowledge guarantees.

## Performance

Verification is **constant-time** on both circuits: cyclic recursion keeps per-account proof size and verification cost independent of history length, and the `AggregateBatchProof` is constant-size in the member count `m` (asymptotic to the recursion-overhead floor of ~100 KB). A coin that changed hands many times verifies as fast as a freshly created one, and a scanner clears an entire batch with a single proof check.
