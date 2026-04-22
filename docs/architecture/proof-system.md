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

## SP1 zkVM

The proof circuit runs on [SP1](https://github.com/succinctlabs/sp1) by Succinct Labs — a Zero-Knowledge virtual machine that executes standard Rust code:

```rust
// Simplified: what the SP1 circuit verifies
fn main() {
    // 1. Verify previous account proof (recursive)
    // 2. Verify all incoming coins (Schnorr signatures, Merkle inclusion)
    // 3. Check balance: sum(inputs) >= sum(outputs)
    // 4. Verify no coin is double-spent (coin_history SMT non-inclusion)
    // 5. Generate new coin commitments
    // 6. Commit to new account state
}
```

## Data structures

### Sparse Merkle Tree (SMT)

- 256-bit key space (binary tree, depth 256)
- Each node: `SHA256(left || right)`
- Stores commitments indexed by public key hash
- Supports both inclusion and non-inclusion proofs
- Default (empty) hashes pre-computed for efficiency

### Merkle Mountain Range (MMR)

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

The SP1 circuit handles two proof types:

| Type | When | What it proves |
|---|---|---|
| `InitialProof` | First transaction from an account | Account creation is valid, initial coins are legitimate |
| `AccountUpdateProof` | All subsequent transactions | Previous proof was valid + new transaction is valid (recursive) |

## Current status

:::info Mock mode
The SP1 prover currently runs in **mock mode** (`SP1_PROVER=mock`). This generates dummy proofs that pass verification but provide no actual Zero-Knowledge guarantees. It is suitable for development and testing.

Production deployment requires either:
- **Local GPU proving** — SP1 supports CUDA for fast proof generation
- **Succinct Prover Network** — outsource proving to Succinct's decentralized network
:::

## Implementation strategies (from the paper)

The Shielded CSV paper describes two practical PCD instantiations:

1. **Folding Schemes** — incremental proof compression, efficient for sequential proofs
2. **Recursive STARKs** — proof verification inside new proofs, more established tooling

The current implementation uses SP1 (STARK-based), which falls into category 2.

## Benchmark expectations

From related research (not yet benchmarked on zkCoins):

| Metric | Value |
|---|---|
| Proof generation | ~49 seconds per step (research benchmark) |
| SNARK compression | 1031 MB → 13 KB |
| Verifier time | 11–22 seconds |

These numbers will improve significantly as SP1 and the broader ZK ecosystem mature.
