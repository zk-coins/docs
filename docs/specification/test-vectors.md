---
sidebar_position: 9
title: Test vectors
---

# Test vectors (conformance harness)

> *In one sentence: a fixed worked example with concrete hex values for every identifier defined by SHA-256/Bech32m (computed and pinned here) and an explicit conformance harness for the Poseidon-derived values, to be filled in by the reference implementation once §1.7 is implemented.*

This page exists so that two independent implementations can **bit-for-bit verify** they implement the spec identically. Where a value depends only on SHA-256 / Bech32m / byte serialization (per [§1.4](foundations#14-identifiers-and-hashes) and [§1.7](foundations#17-encoding-serialization-and-the-reference-instantiation)), it is pinned here. Where a value depends on Poseidon over Goldilocks ([§1.1](foundations#11-cryptographic-primitives), [§1.7.1](foundations#171-poseidon-instance-and-digest-encoding)) — and therefore on the reference instantiation pending cryptographic review — its **formula** is pinned but its **bytes** are marked **`<REGEN>`** and MUST be filled in by the reference implementation. No Poseidon byte values are guessed or fabricated here.

## V.1 Sample inputs

The sample keys are **illustrative**, not derived from a real BIP-32 path. Real wallets derive `Pk₀`, `Pk₁`, `nk` from the seed via [§1.2](foundations#12-key-hierarchy); for the purpose of exercising the byte-level identifier derivations on this page, they are fixed deterministically as `SHA-256` of fixed ASCII strings:

| Symbol | Definition | Hex (32 bytes) |
|---|---|---|
| `Pk₀_sample` | `H("zkCoins/v1/test-vector/Pk0")` | `5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746` |
| `Pk₁_sample` | `H("zkCoins/v1/test-vector/Pk1")` | `fba3ea150382de6f39a07348d327b1efa8c120da1ee599148ff6fed7803465fb` |
| `nk_sample` | `H("zkCoins/v1/test-vector/nk")` | `2dc00b27c0d2991514b1b997af97b0e12c5da159b5726481124032c1578115b2` |

Asset definition:

| Field | Value |
|---|---|
| `name` (UTF-8) | `USD-Demo` |
| `H(name)` | `aff024cf2705e0450bfb51b461a1ed90c125efe0e43554191380b69a6a6be313` |
| `decimals` | `0x02` (2) |
| `genesis_tag` | ASCII `zkCoins/v1/genesis` (18 bytes: `7a6b436f696e732f76312f67656e65736973`) |

`Pk₀_sample` is treated as an x-only 32-byte string for the purpose of `address = H(Pk₀)`; a real BIP-340 key must be a valid x-coordinate on secp256k1. This caveat does not affect the `address`/Bech32m derivation, which depends only on the 32-byte input.

## V.2 Address derivation (SHA-256 + Bech32m — pinned)

```
Pk₀_sample (32B) = 5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746
address          = H(Pk₀_sample)
                 = fd201c457bddb7571cca1f8d63ad0a5630ceec4f77e238bbd61cc8bc26a03298
zk-bech32m       = zk1l5spc3tmmkm4w8x2r7xk8tg22ccvamz0wl3r3w7krnytcf4qx2vqujc5px
```

A conforming implementation **MUST** produce exactly these bytes and exactly this Bech32m string from the inputs above. The Bech32m HRP is `zk`; the encoding is per [§1.7.7](foundations#177-bech32m-and-bitcoin-conventions). The Bech32m checksum constant is the BIP-350 value `0x2BC830A3`.

## V.3 `serialize(AccountState)` byte layout (pinned for the SHA-256 parts)

A worked example: an account holding 1 000 000 000 base units of `USD-Demo` after one transition, with an empty coin history.

```
Fixed fields  (pinned bytes):
   owner               (32B): fd201c457bddb7571cca1f8d63ad0a5630ceec4f77e238bbd61cc8bc26a03298
   current_pubkey      (32B): fba3ea150382de6f39a07348d327b1efa8c120da1ee599148ff6fed7803465fb
   send_counter        ( 8B): 0000000000000001
   coin_history_root   (32B): <REGEN — equals E'₂₅₆, the empty coin-history SMT root, see V.4>
   balances_count      ( 4B): 00000001
   [balances entry, sorted ascending by asset_id]:
       asset_id        (32B): <REGEN — see V.4>
       amount          (16B): 0000000000000000000000003b9aca00   ← u128 big-endian, 1 000 000 000

Sizes:
   prefix (without asset_id+amount): 108 bytes
   with one balance entry:           156 bytes
```

The conformance harness MUST construct the byte string in exactly this order and re-derive `ash = Hc("AccountState", <these bytes as a byte-string input>)` per [§1.7.2](foundations#172-field-encoding-e-of-hc-inputs) and [§1.7.4](foundations#174-serializeaccountstate).

`coin_history_root` for an empty account equals **`E'₂₅₆`**, the empty-tree root of the per-account coin-history SMT (distinct from the nullifier accumulator's `E₂₅₆` because the coin-history SMT uses different domain tags `CoinHist/Leaf`, `CoinHist/Node`; see [§1.7.6](foundations#176-nullifier-accumulator-sparse-merkle-tree)). Both values are Poseidon-dependent and listed in V.4 as `<REGEN>`.

## V.4 Poseidon-derived values — `<REGEN>` table

For each value below, the formula is fixed; the bytes MUST be produced by the reference implementation conforming to [§1.7.1](foundations#171-poseidon-instance-and-digest-encoding) and [§1.7.2](foundations#172-field-encoding-e-of-hc-inputs), then pasted into the rightmost column.

| Symbol | Formula | Bytes (`<REGEN>`) |
|---|---|---|
| `E₂₅₆` (nullifier-accumulator empty root) | recursion from `E₀ = Hc("NfAcc/Leaf", 0)` and `Eᵢ = Hc("NfAcc/Node", i, E_{i-1}, E_{i-1})`; the empty root is `E₂₅₆ = Hc("NfAcc/Node", 256, E₂₅₅, E₂₅₅)` — [§1.7.6](foundations#176-nullifier-accumulator-sparse-merkle-tree) | `<REGEN>` |
| `E'₂₅₆` (coin-history-SMT empty root) | same structure with the per-account tags: `E'₀ = Hc("CoinHist/Leaf", 0)` and `E'ᵢ = Hc("CoinHist/Node", i, E'_{i-1}, E'_{i-1})`; empty root `E'₂₅₆ = Hc("CoinHist/Node", 256, E'₂₅₅, E'₂₅₅)` — [§1.7.6](foundations#176-nullifier-accumulator-sparse-merkle-tree) | `<REGEN>` |
| `asset_id` | `Hc("AssetId", "zkCoins/v1/genesis" ‖ Pk₀_sample ‖ H("USD-Demo") ‖ decimals=0x02)` | `<REGEN>` |
| `ash_empty` | `Hc("AccountState", serialize(canonical_empty_account_for(address)))` per [§2.2](proofs#22-proof-types) — the InitialProof's `prev_account_state` digest; uses `coin_history_root = E'₂₅₆` | `<REGEN>` |
| `coin.identifier@0` | a coin minted to `address`, first output of the InitialProof: `Hc("Coin", ash_empty ‖ asset_id ‖ coin_index=0)` | `<REGEN>` |
| `coin_history_root@0` | the per-account coin-history SMT root after admitting `coin.identifier@0` as leaf state `1` (received-unspent), starting from `E'₂₅₆`; the result is a single populated path through 256 levels | `<REGEN>` |
| `ash@0` | `Hc("AccountState", serialize(<V.3 byte string with the regenerated asset_id and coin_history_root@0 substituted>))` | `<REGEN>` |
| `nf_sample` | `Hc("Nullifier", nk_sample ‖ coin.identifier@0)` | `<REGEN>` |
| `ocr@0` | Poseidon Merkle root over `[coin.identifier@0]`, tag `CoinsRoot` (one leaf, padded to one) per [§1.7.5](foundations#175-poseidon-merkle-tree-used-for-ocr-and-inr) | `<REGEN>` |
| `inr@0` | Poseidon Merkle root over the empty list of nullifiers (a mint), tag `NullifiersRoot` — equals the `L_⊥` leaf-hash | `<REGEN>` |
| `message@0` | `inr@0 ‖ ocr@0` (concatenation of the two 32-byte values above) | derived from the two above |
| `H(ProofData@0)` | per [On-chain §3.2](onchain#32-spendrecord-signing-bip-340--sign-to-contract): `SHA-256(ash@0 ‖ ocr@0 ‖ inr@0 ‖ coin_history_root@0)` | derived from the four above |

## V.5 `SpendRecord` byte layout (pinned for the SHA-256 / structural parts)

For the InitialProof (mint) using the values above, the on-chain `SpendRecord` (format `0x00`, raw, per [§3.5](onchain#35-inscription-format)) per record:

```
Pkⱼ          (32B): 5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746   ← Pk₀_sample
                                                                                     (initial transition signs with Pk₀)
signatureⱼ   (64B): <REGEN — BIP-340(skᵢ, message@0) with S2C tweak t = H(R' ‖ H(ProofData@0))>
messageⱼ     (64B): <message@0 = inr@0 ‖ ocr@0, both <REGEN>>
kⱼ           ( 1B): 00                                                                ← a mint spends 0 coins
nullifiersⱼ  ( 0B): (empty)                                                            ← kⱼ = 0
                                                                                     
Record size: 161 bytes for a raw mint (32 + 64 + 64 + 1 + 0).
```

For a send that spends one input coin (`kⱼ = 1`), the record additionally carries that single 32-byte `nf` after `kⱼ`, for **193 bytes** raw — consistent with [§3.5](onchain#35-inscription-format).

## V.6 Inscription header (pinned)

A batch carrying `m = 1` raw record, anchored at Bitcoin block height `0x000A1234` (illustrative) with a fixed sample block hash:

```
Header (42 bytes):
   marker                    ( 2B): 4242
   version                   ( 1B): 01
   format                    ( 1B): 00
   count m                   ( 2B): 0001
   block_anchor.block_hash   (32B): <Bitcoin chain-specific; pinned per deployment, not by this spec>
   block_anchor.height       ( 4B): 000a1234

Body follows: m × <SpendRecord bytes> as in §V.5.
Total inscription = 42 + 161 = 203 bytes for a mint with one record.
```

This matches the size note in [§3.5](onchain#35-inscription-format).

## V.7 How to use these vectors

1. Implement [§1.7.1](foundations#171-poseidon-instance-and-digest-encoding) (Poseidon over Goldilocks, Plonky2 `PoseidonGoldilocksConfig`) and [§1.7.2](foundations#172-field-encoding-e-of-hc-inputs) (`E(·)` byte-to-field encoding).
2. Compute each `<REGEN>` row of V.4, in order (later rows depend on earlier).
3. Substitute the regenerated values into V.3 (`asset_id`, `coin_history_root`) and V.5 (`message@0`).
4. Compute `ash@0` from the resulting `serialize(AccountState)` per [§1.7.4](foundations#174-serializeaccountstate) and verify it matches the V.4 entry.
5. Compute the BIP-340 signature with sign-to-contract per [§3.2](onchain#32-spendrecord-signing-bip-340--sign-to-contract) and fill in V.5's `signature`. The signing key is a real secp256k1 key derived from a real BIP-32 path; a separate test-key fixture is needed because the V.1 illustrative `Pk₀_sample` is a raw 32-byte string, not a curve point.
6. Submit the completed vectors back to the spec as a PR; once two independent implementations agree on the same hex, the reference is locked.

Until V.4 is filled in by a reference implementation, no `<REGEN>` row should be treated as authoritative. **Do not invent Poseidon digests.** A wrong vector is worse than no vector: it would lead two implementations to validate against each other's mistakes.
