---
sidebar_position: 3
title: 2 · Proofs & State Transitions
---

# 2 · Proofs & State Transitions

This page defines the **proof system** and the **three state transitions** (mint, send, receive) of zkCoins. It builds strictly on [Foundations](foundations): every key, identifier, hash, tree, and structure is used exactly as defined there and never redefined here. Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) follow RFC 2119.

The proof system is a **proof-carrying-data (PCD)** scheme realised by **cyclic recursion** (see [Foundations](foundations) §1.1): one circuit verifies a proof of itself. Each transition consumes the account's previous proof and emits a new one, so a coin that changed hands `N` times carries a **single constant-size proof**, verified in **constant time**, regardless of `N`.

## 2.1 The compliance predicate

Every transition is a single execution of one circuit, `C`. The circuit takes a **private witness** `w` and a set of **public inputs** equal to `ProofData` (see [Foundations](foundations) §1.4). A proof `π` is accepted only if `C(ProofData, w) = 1`, i.e. **all** of the following clauses hold. The clauses are normative: a conforming prover **MUST** enforce every one, and a conforming verifier **MUST** reject any proof for which the public inputs are not bound exactly as below.

Witness (private to the prover; never revealed):

```
w = {
  prev_proof,                 // the account's previous recursive proof (absent for InitialProof)
  prev_account_state,         // AccountState before this transition (Foundations §1.5)
  input_coins[],              // coins being spent (Foundations §1.5); empty for a pure mint
  input_auth[]   = {          // per input coin, membership evidence (NO per-coin key/signature)
    history_path,                                    // inclusion in prior coin-history SMT
    creating_ash                                     // the new_account_state_hash of the transition that
                                                     // created this coin, delivered inside its CoinProof bundle
  },
  txn_sig        = BIP-340(skᵢ, message),            // the account's single transition signature (Commitment)
  txn_pubkey     = Pkᵢ (x-only),                     // current_pubkey, authorises this whole transition
  nullifier_nonmembership[],  // per input coin, non-membership path in the nullifier accumulator
  nullifier_insertion[],      // per input coin, the post-insertion membership path
  output_templates[],         // CoinTemplate list (Foundations §1.5)
  nk,                         // nullifier key (SPEND branch, Foundations §1.2)
  next_pubkey   = Pkᵢ₊₁,      // rotated spend pubkey for the new state
  asset_issuance?             // present only for issuance: {asset_id, name_hash, amount, decimals}
}
```

**Predicate `C` — enumerated clauses.**

1. **Recursive verification (PCD).** Either this is an `InitialProof` and `w.prev_proof` is absent and `ProofData.prev_commitment_history_root` equals the canonical empty-account root; **or** `w.prev_proof` verifies under the circuit's own verifier data (cyclic recursion), and its public output `new_account_state_hash` equals the `ash` of `w.prev_account_state`, and its `coin_history_root` equals the coin-history root over which clause 3 proves inclusion. The verifier data **MUST** be fixed and identical in prover and verifier; a proof verified against any other verifier data is invalid.
   - **Lineage binding to global history.** `ProofData.prev_commitment_history_root` **MUST** equal the global Commitment-MMR root ([Foundations](foundations) §1.6) as of the account's previous committed transition, binding the account's lineage to the on-chain global history.

2. **Input authenticity.** The whole transition is authorised by the account's **single transition signature** — there is no per-coin key and no per-coin signature ([Foundations](foundations) §1.2). The circuit **MUST** check that `txn_sig` is a valid **BIP-340** signature (see [Foundations](foundations) §1.1) over `message = ash ‖ ocr` by `txn_pubkey = Pkᵢ`, and that `Pkᵢ` is `prev_account_state.current_pubkey`. Then, for every `input_coins[j]`:
   a. `input_coins[j].recipient` equals `prev_account_state.owner`, i.e. the coin is owned by the spending account (`owner = address = H(Pk₀)`, [Foundations](foundations) §1.4) — ownership is by the account, so a receiver never needs a per-coin key index;
   b. `input_coins[j]` is included in the prior **coin-history SMT** (per-account, [Foundations](foundations) §1.6) via `input_auth[j].history_path` against the root referenced in clause 1;
   c. `input_coins[j].identifier` is recomputed in-circuit as `Hc("Coin", input_auth[j].creating_ash ‖ asset_id ‖ coin_index)` — using the witnessed `creating_ash` (the `new_account_state_hash` of the transition that produced this coin, delivered to the spender inside the coin's `CoinProof` bundle), **not** the hash of `prev_account_state` — and **MUST** match the supplied identifier. The per-input witness `input_auth[]` **MUST** therefore include each input coin's `creating_ash`. This matches [Foundations](foundations) §1.4: a coin's identifier binds its creating state's `ash`.

3. **Per-asset balance conservation.** Let `In(a) = Σ { input_coins[j].amount : input_coins[j].asset_id = a }` and `Out(a) = Σ { output_templates[k].amount : output_templates[k].asset_id = a }`, plus `Mint(a)` from any `asset_issuance` for asset `a` (zero otherwise). For **every** `asset_id` `a` appearing in inputs or outputs: `In(a) + Mint(a) ≥ Out(a)`. All amounts are range-checked to a fixed non-negative integer width so no sum can wrap the field; any amount outside range invalidates the proof. The difference `In(a) + Mint(a) − Out(a)` is retained by the account (a change coin) — funds are conserved, never created except by an explicit, predicate-checked `Mint(a)`.

4. **Nullifier freshness (no double-spend).** For every `input_coins[j]`:
   a. compute `nf_j = Hc("Nullifier", nk ‖ input_coins[j].identifier)` (see [Foundations](foundations) §1.4) in-circuit from the witnessed `nk`;
   b. prove **non-membership** of `nf_j` in the global **nullifier accumulator** at root `ProofData.prev_nullifier_acc_root` via `nullifier_nonmembership[j]`;
   c. prove **membership** of `nf_j` in the updated accumulator via `nullifier_insertion[j]`; inserting the full set of `nf_j` into `prev_nullifier_acc_root` yields the new root `ProofData.nullifier_acc_root`. All `nf_j` within one transition **MUST** be pairwise distinct. The set of `nf_j` forms the leaves whose root is `ProofData.input_nullifiers_root`. When batched on-chain, these per-transition roots **chain**: in the [On-chain §3.6](onchain) total order each transition's `prev_nullifier_acc_root` equals the running accumulator root before it and its `nullifier_acc_root` the running root after it, the first starting from the previous tip's anchored root and the last equalling the inscribed batch `nullifier_acc_root` ([On-chain §3.7](onchain)).

5. **Output coin construction.** For each `output_templates[k]`, the new `coin.identifier` is computed as `Hc("Coin", new_account_state_hash ‖ output_templates[k].asset_id ‖ coin_index_k)` ([Foundations](foundations) §1.4), with `coin_index_k` assigned monotonically within the transition. The resulting `Coin` objects (`{identifier, recipient, amount, asset_id}`) are the transition's outputs.

6. **Output coins root.** `ProofData.output_coins_root` (`ocr`) **MUST** equal the Poseidon Merkle root over the output `coin.identifier`s under tag `CoinsRoot` ([Foundations](foundations) §1.4, §1.6).

7. **New account state.** `new_account_state` is `prev_account_state` with: `balances` updated per clause 3 (debit spent inputs, credit change and any issuance), `current_pubkey = next_pubkey = Pkᵢ₊₁`, and `send_counter` incremented by one. `ProofData.new_account_state_hash` **MUST** equal `ash = Hc("AccountState", serialize(new_account_state))` ([Foundations](foundations) §1.4). `new_account_state.owner` **MUST** be unchanged.

8. **Coin-history update.** The per-account coin-history SMT is updated to mark spent inputs and admit the change/issuance coins; `ProofData.coin_history_root` **MUST** equal the resulting root.

9. **Public-input binding.** All seven `ProofData` fields — `prev_commitment_history_root`, `new_account_state_hash`, `output_coins_root`, `input_nullifiers_root`, `prev_nullifier_acc_root`, `nullifier_acc_root`, `coin_history_root` — **MUST** be the in-circuit-computed values above and are the proof's public inputs. Nothing else is public: amounts, asset ids, recipients, keys, and counts remain in the witness (zero-knowledge).

The signed on-chain **Commitment** (`message = ash ‖ ocr`, [Foundations](foundations) §1.4) binds the two state-defining outputs of this predicate (`new_account_state_hash` and `output_coins_root`) to Bitcoin via a BIP-340 signature by `Pkᵢ`; construction and publishing are specified in [On-chain Layer](onchain).

## 2.2 Proof types

The **same** circuit `C` handles both proof types; they differ only in clause 1.

| Type | When | Clause 1 behaviour |
|---|---|---|
| `InitialProof` | first transition of an account (creation; optionally an issuance) | `prev_proof` absent; `prev_account_state` is the canonical empty account for `owner = H(Pk₀)`; `prev_commitment_history_root` is the empty-account root |
| `AccountUpdateProof` | every subsequent transition | `prev_proof` present and verified recursively against the circuit's own verifier data |

Because recursion is **cyclic** — one fixed circuit that verifies proofs of itself — the verifier data is constant, so **proof size and verification time are constant** and independent of an account's or a coin's history length. A conforming verifier **MUST NOT** require, fetch, or re-execute any prior transition: verifying the latest proof transitively attests every predecessor.

## 2.3 State transitions

The three operations are the only ways state changes. Each is one execution of `C` producing one `Commitment` (on-chain) and, for value delivered to a counterparty, one or more `CoinProof` bundles (off-chain, [Foundations](foundations) §1.5). The **wallet** holds the SPEND branch and signs; the **node/prover** holds the operational bundle, builds the witness, and runs the prover ([Foundations](foundations) §1.2). The spend key **MUST NOT** leave the wallet.

### 2.3.1 Mint / issuance

Creates an account and/or issues a new asset's first coins. Issuance is **permissionless and trustless**: no privileged signer exists; the asset's identity is bound to its creator by construction, and supply rules are enforced by the predicate and by every future receiver re-verifying the chain. The open-mint terms (who may mint, supply caps, and ongoing emission policy) are detailed in [System Architecture](architecture).

```
Inputs (wallet → node):
  owner          = H(Pk₀)               // account identity, from the initial spend key
  name, decimals                        // human-readable; name is NEVER on-chain
  amount                                 // initial supply to emit to self

Wallet:
  1. derive Pk₀ = sk₀·G; sign the transition signature BIP-340(sk₀, message = ash ‖ ocr)
     (the initial transition is signed by Pk₀, i.e. sk₀; current_pubkey rotates to Pk₁)
  2. derive name_hash = H(name); asset_id = Hc("AssetId", genesis_tag ‖ Pk₀ ‖ name_hash ‖ decimals)   (Foundations §1.4)
  3. provide nk and next_pubkey Pk₁ from the SPEND branch

Node / prover:
  4. build the witness with empty inputs, asset_issuance = {asset_id, name_hash, amount, decimals},
     and one output coin {recipient = owner, amount, asset_id}
  5. run C as an InitialProof (clause 1, InitialProof path): Mint(asset_id) = amount,
     In(asset_id) = 0, so balance clause 3 admits exactly `amount` of the new asset
  6. obtain π, new ash, ocr, and ProofData

Becomes the Commitment (on-chain):  { Pk₀ (x-only), BIP-340(sk₀, ash ‖ ocr), message = ash ‖ ocr }
CoinProof produced:  for self-held supply, none is delivered; the node retains the coin,
  proof, and inclusion proof locally as spend credential.
```

`asset_id` is globally unique because it commits to the creator pubkey; two creators cannot collide, and the same creator distinguishes assets by `name_hash = H(name)`/`decimals`. The human-readable `name` travels only inside bundles, never on-chain ([Foundations](foundations) §1.4).

### 2.3.2 Send

Spends owned input coins and produces output coins (recipient coins plus a change coin), the corresponding nullifiers, a new account state, and a proof.

```
Inputs (wallet → node):
  input_coins[]                          // coins the account owns and will spend
  output_templates[] = CoinTemplate[]    // {recipient, amount, asset_id} per payee

Wallet:
  1. sign the single transition signature BIP-340(skᵢ, message = ash ‖ ocr) with the
     current per-transition signing key skᵢ (whose Pkᵢ is current_pubkey; no per-coin key)
  2. supply nk (for nullifiers) and the rotated next_pubkey Pkᵢ₊₁  (SPEND branch, Foundations §1.2)

Node / prover:
  3. for each input coin, derive nf = Hc("Nullifier", nk ‖ coin.identifier)
  4. assemble the witness; per asset, add a change CoinTemplate {recipient = owner,
     amount = In(a) − Out(a), asset_id = a} so clause 3 holds with equality
  5. for each output coin (Foundations §1.3): draw esk, compute epk = esk·G,
     ss = ECDH(esk, IVPK_recipient), K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk),
     detect_tag = Hc("zkCoins/v1/DetectTag", dk ‖ epk); encrypt the coin plaintext under K_tx
  6. run C as an AccountUpdateProof: recursive verify of prev_proof (clause 1), input
     authenticity (2), per-asset conservation (3), nullifier non-membership→insertion (4),
     output construction (5–6), new state/ash (7), coin-history update (8), binding (9)
  7. obtain π, ash, ocr, ProofData

Becomes the Commitment (on-chain):  { Pkᵢ (x-only), BIP-340(skᵢ, ash ‖ ocr), message = ash ‖ ocr }

CoinProof produced (per recipient coin, delivered off-chain):
  { coin, proof = π, inclusion_proof (membership in ocr), epk, ciphertext, detect_tag }
  (Foundations §1.5). The change coin's bundle is retained locally, not delivered.
```

The published nullifiers (their root `input_nullifiers_root`, folded into the global accumulator) make the spent coins unspendable again; the rotated `current_pubkey` unlinks this commitment from the account's prior commitments to any on-chain observer. Delivery of the `CoinProof` over Nostr is specified in [Transport & Recovery](transport-recovery).

### 2.3.3 Receive

The receiver (or its node, on its behalf) credits a coin **only after independent verification** — the trustless-receive norm ([Requirement 4](/requirements)). A conforming receiver **MUST NOT** credit a coin on the sender's or any third party's assertion.

```
Inputs:
  CoinProof bundle (off-chain, delivered to the recipient)   (Foundations §1.5)
  the receiver's own view of Bitcoin and the global roots

Receiver / node:
  1. discovery & decrypt: match detect_tag against the receiver's dk; re-derive
     ss = ECDH(ivk, epk), K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk); decrypt the coin
     (only a holder of ivk can; Foundations §1.3)
  2. RE-VERIFY THE FULL RECURSIVE PROOF: C.verify(proof) under the canonical verifier data.
     This transitively attests the entire provenance in constant time (§2.2). MUST pass.
  3. inclusion: verify inclusion_proof places coin.identifier in the committed output_coins_root.
  4. anchoring: verify that output_coins_root (with the matching ash) is bound by a real on-chain
     Commitment — a BIP-340 signature over message = ash ‖ ocr present in Bitcoin (see Onchain).
  5. nullifier non-membership: verify the coin's nf is NOT in the global nullifier accumulator
     at the latest on-chain root — i.e. the coin is unspent — checked against Bitcoin, not asserted.
  6. amount/asset sanity: confirm coin.recipient = receiver's address and asset_id is well-formed.

On all of 2–5 passing: credit coin.amount of coin.asset_id to the receiver's AccountState and
admit the coin to the receiver's coin-history SMT. The bundle is now the receiver's spend
credential for a future Send. The receiver MAY return an encrypted acknowledgement so the
sender can drop its copy (Transport & Recovery).
```

Steps 2 (recursive re-verification) and 5 (global nullifier non-membership against Bitcoin) are the two checks that make receipt fully trustless: the receiver depends on **Bitcoin and the proof, never on the courier**. A failed or malicious transport can **withhold** a bundle but can never make an invalid one verify.

## 2.4 Soundness summary

Each predicate property delivers a specific [Requirement](/requirements):

| Property (clause) | Guarantees | Requirement |
|---|---|---|
| Recursive verification + input authenticity (1, 2) | **No forgery** — a coin exists only as the signed, proven output of a valid prior transition; no party can fabricate a coin it was not entitled to | 3 · Trustless |
| Per-asset balance conservation (3) | **No inflation of others' assets** — for every `asset_id`, outputs never exceed inputs plus an explicit, creator-bound `Mint`; supply is auditable by every receiver | 3, 8 |
| Nullifier freshness (4) + receive check 5 | **No double-spend** — each coin's `nf` enters the global accumulator exactly once; reuse is provably rejected, verified against Bitcoin on receipt | 3 |
| Full re-verification on receipt (§2.3.3) | **Client-side validation** — correctness never depends on the sender, the node, or any third party | 4 |
| Public-input binding + ZK witness (9) | **Privacy** — only roots/hashes are public; amounts, assets, parties, and the graph stay hidden | 2 |
| Constant-size cyclic recursion (§2.2) | **Scalable trustlessness** — history of any length verifies in constant time, so re-verification is always feasible | 4 |

## Reading guide

- Commitment construction, signing, aggregation, publishing, scanning, and the global nullifier accumulator: [On-chain Layer](onchain).
- `CoinProof` delivery, node-as-relay, note discovery, and recovery/data-availability: [Transport & Recovery](transport-recovery).
- Viewing keys, view grants, and the public/authorised explorer: [Access & Explorer](access-explorer).
- Node/wallet/explorer components, portability, and the open-mint issuance terms: [System Architecture](architecture).
