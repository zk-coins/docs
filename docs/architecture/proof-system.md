---
sidebar_position: 6
title: Proof System
---

# Proof System

zkCoins uses **Proof-Carrying Data (PCD)** — the central cryptographic abstraction of the Shielded CSV protocol. Each transaction produces a Zero-Knowledge proof that the coin is valid, without revealing any transaction details.

## What PCD provides

- Each transaction generates a computation proof
- Subsequent transactions depend on prior proofs → outputs remain trustworthy
- **Proof size is constant** — independent of the coin's transaction history
- **Verification time is constant** — a coin that changed hands 1000 times verifies as fast as a new coin
- With the Zero-Knowledge property: the proof hides transactions, balances, accounts — only the nullifier is revealed

## Plonky2 + Poseidon-Goldilocks

The proof circuit is a single in-process [Plonky2](https://github.com/0xPolygonZero/plonky2) prover written in Rust, running inside the node — no external prover service. It works over the Goldilocks field with the Poseidon hash (`PoseidonGoldilocksConfig`) and uses **cyclic recursion** to realise Proof-Carrying Data: each proof recursively verifies its predecessor inside the same circuit.

```rust
// Simplified: what the Plonky2 state-transition circuit enforces
// (program-plonky2/src/circuit/main.rs)
fn enforce() {
    // 1. Verify the previous account proof (recursive, same circuit)
    // 2. Verify all incoming coins (Schnorr signatures, Merkle inclusion)
    // 3. Check balance: sum(inputs) >= sum(outputs)
    // 4. Verify no coin is double-spent (coin_history SMT non-inclusion)
    // 5. Generate new coin commitments
    // 6. Commit to the new account state
}
```

Because recursion is **cyclic**, every proof is verified against the circuit's own verifier data, so a proof verifies in constant time regardless of how many transactions preceded it:

```rust
// Verification (script-plonky2 wraps Plonky2's verifier).
// `data` holds the proving/verifying keys and common circuit data;
// `proof` is a ProofWithPublicInputs<F, C, D> over the Goldilocks field.
data.verify(proof)?;
```

## Data structures

### Sparse Merkle Tree (SMT)

- 256-bit key space (binary tree, depth 256)
- Each node: `Poseidon(left || right)` over the Goldilocks field
- Stores commitments indexed by public key hash
- Supports both inclusion and non-inclusion proofs
- Default (empty) hashes pre-computed for efficiency

### Merkle Mountain Range (MMR)

> **Note:** the global Commitment-SMT/MMR below describes the earlier (v0) design. The current normative model uses the published-nullifier **accumulator** as the only global structure and no MMR — see [Foundations §1.6](/specification#16-trees-one-global-structure-one-per-account-structure) and the [glossary](/specification#glossary). A full rewrite of this page is tracked separately.

- Append-only accumulator for commitment history
- Stores one SMT root per block
- Proves "this commitment appeared in block N"

### Hierarchy

```
Per-account:
  Coin History SMT     — tracks which coins were already received

Global:
  Commitment SMT       — all accounts' latest state (indexed by pubkey hash)
  Commitment MMR       — history of SMT roots (one per block)
```

## Proof types

The same cyclic-recursion circuit handles two proof types:

| Type | When | What it proves |
|---|---|---|
| `InitialProof` | First transaction from an account | Account creation is valid, initial coins are legitimate |
| `AccountUpdateProof` | All subsequent transactions | Previous proof was valid + new transaction is valid (recursive) |

## Prover

The prover runs in-process as part of the node — a single Rust process, no external prover service. Every proof it produces is a real Plonky2 proof with full Zero-Knowledge guarantees. Proving is CPU-only on a single host (Apple Silicon); no GPU and no external proving network are involved.

## Implementation strategies (from the paper)

The Shielded CSV paper describes two practical PCD instantiations:

1. **Folding Schemes** — incremental proof compression, efficient for sequential proofs
2. **Recursive STARKs** — proof verification inside new proofs, more established tooling

The current implementation uses Plonky2, whose FRI-based recursive proofs fall into category 2. Cyclic recursion — one circuit that verifies proofs of itself — is what turns the recursive-STARK approach into Proof-Carrying Data.

## Performance

Proof generation runs on CPU on a single host and takes on the order of **seconds to minutes**, depending on circuit parameters and hardware. This cost is paid once per transaction, on the node, before the commitment is broadcast to Bitcoin.

Verification is **constant-time**: cyclic recursion keeps both proof size and verification cost independent of history length, so a coin that changed hands many times verifies as fast as a freshly created one.
