---
sidebar_position: 4
title: 3 · On-chain Layer
---

# 3 · On-chain Layer

This page specifies the Bitcoin-facing layer of zkCoins: how a transaction's `Commitment` ([Foundations §1.4](foundations)) is signed and embedded, how many commitments are aggregated and published in a single Bitcoin transaction, how any node scans the chain to rebuild the global trees ([Foundations §1.6](foundations)), and how the global **nullifier accumulator** provides trustless double-spend protection. It introduces **no** change to Bitcoin consensus and **no** native token ([Requirement 1](/requirements)).

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119. All primitives, identifiers, and domain-separation tags are those defined in [Foundations](foundations) and are used unchanged.

## 3.1 The on-chain object

The **only** object zkCoins writes to Bitcoin is the `Commitment` of [Foundations §1.4](foundations):

```
Commitment = {
  public_key : Pkᵢ                    // 32 bytes, BIP-340 x-only
  signature  : BIP-340(skᵢ, message)  // 64 bytes
  message    : ash ‖ ocr              // 64 bytes  (account_state_hash ‖ output_coins_root)
}                                      // ~177 bytes inscribed (before aggregation)
```

`Pkᵢ` is the rotating per-send spend public key ([Foundations §1.2](foundations)); `message` binds the new account state hash `ash` and the transaction's output-coins root `ocr` ([Foundations §1.4](foundations)). A `Commitment` contains only hashes and a signature; it reveals no amount, asset, sender, or receiver ([Requirement 2](/requirements)). The proof that `message` corresponds to a valid state transition is **off-chain** ([Proofs & State Transitions](proofs)); Bitcoin verifies only that the commitments were published and ordered.

## 3.2 Commitment signing (BIP-340 + sign-to-contract)

The signature in a `Commitment` is a BIP-340 Schnorr signature over `message` produced by the per-send spend key `skᵢ`. It additionally carries the transaction commitment **in its nonce** via **sign-to-contract**, so no extra bytes appear on-chain (as stated in [Foundations §1.4](foundations)).

Let `H_tx = H(message)` be the 32-byte transaction commitment (`H` = SHA-256, [Foundations §1.1](foundations)). The signer MUST construct the nonce as:

```
1. R'  = k'·G                          // k' a fresh, uniformly random 256-bit nonce scalar
2. t   = H( bytes(R') ‖ H_tx )         // sign-to-contract tweak, SHA-256, 32 bytes
3. R   = R' + t·G                      // committed nonce point  (x-only, BIP-340 even-y)
4. e   = H_BIP340( bytes(R) ‖ bytes(Pkᵢ) ‖ message )   // BIP-340 challenge
5. s   = (k' + t + e·skᵢ) mod n        // n = secp256k1 group order
6. signature = bytes(R) ‖ bytes(s)     // 64 bytes
```

The published `signature` is an ordinary, standalone BIP-340 signature: any verifier checks `s·G == R + e·Pkᵢ` with no knowledge of `t`. A party who **knows** `H_tx` and is shown `R'` can additionally recompute `t` and confirm `R = R' + t·G`, proving that this exact transaction commitment is embedded in the nonce. The signer MUST follow BIP-340 nonce hygiene (deterministic-plus-auxiliary-randomness derivation of `k'`) and MUST NOT reuse a nonce across two distinct messages. `Pkᵢ` MUST be the x-only key under which the spend is authorised; reusing `Pk₀` for a non-initial send is forbidden (keys rotate per send, [Foundations §1.2](foundations)).

## 3.3 Half-aggregation

Many independent `Commitment` signatures are compressed into one **half-aggregate** before publishing. Half-aggregation is **non-interactive**: it requires no coordination among signers and no secret keys — a publisher (§3.4) performs it on signatures it has merely collected.

Given commitments `C₁ … C_m` with signatures `(Rⱼ, sⱼ)`, keys `Pkⱼ`, and messages `mⱼ`:

```
1. For each j:  eⱼ = H_BIP340( bytes(Rⱼ) ‖ bytes(Pkⱼ) ‖ mⱼ )
2. Derive aggregation coefficients:
      z  = H( "zkCoins/v1/HalfAgg" ‖ bytes(R₁) ‖ Pk₁ ‖ m₁ ‖ … ‖ bytes(R_m) ‖ Pk_m ‖ m_m )
      aⱼ = H( z ‖ le32(j) )  mod n          // distinct per index, binds the whole batch
3. s_agg = Σⱼ ( aⱼ · sⱼ )  mod n            // single 32-byte aggregate scalar
4. AggSig = ( R₁ … R_m , s_agg )            // m nonces (32B each) + one s_agg (32B)
```

The aggregate verifies with a single multi-scalar check:

```
s_agg·G  ==  Σⱼ aⱼ·( Rⱼ + eⱼ·Pkⱼ )
```

This replaces `m` independent `s` values (32 bytes each) with one, while each `Rⱼ` is retained — and each `Rⱼ` remains the sign-to-contract commitment for its transaction (§3.2). The coefficients `aⱼ` MUST be derived as above so the batch is non-malleable: a verifier MUST reject an `AggSig` whose multi-scalar check fails, and MUST treat every constituent `Commitment` of a failing batch as unconfirmed.

## 3.4 The publisher

A **publisher** is the permissionless agent that moves commitments from off-chain to Bitcoin. Its mapping is **many-to-one**: it collects commitments from many distinct zkCoins transactions — typically from many users — and inscribes them **together in a single Bitcoin transaction**.

- Running a publisher MUST be permissionless; any participant MAY run one, and a wallet/node MAY act as its own publisher.
- A publisher MUST NOT be trusted for **correctness**: it cannot forge, alter, reorder-to-steal, or drop-without-detection any commitment, because (a) each signature is verified by every scanning node (§3.5), and (b) the value-bearing proof and coin plaintext travel off-chain ([Transport & Recovery](transport-recovery)), never through the publisher.
- A publisher MUST NOT be trusted for **custody**: it never holds a spend key, a coin, or a proof; the worst a faulty or malicious publisher can do is **censor** (refuse to inscribe) or **delay** — both mitigated because anyone else can publish the same commitment.
- A publisher SHOULD batch over a bounded interval (e.g. once per Bitcoin block) and SHOULD half-aggregate (§3.3) to minimise per-commitment cost. Identical commitments inscribed by two publishers are idempotent: a scanner records each unique `(Pkᵢ, message)` once.

## 3.5 Inscription format

Commitments are carried in a Taproot **commit/reveal** inscription. The commit transaction pays to a Taproot output whose internal key is tweaked by a script-path leaf; the reveal transaction spends it, exposing the leaf script, whose witness contains the payload inside an `OP_FALSE OP_IF … OP_ENDIF` envelope (so the data is dropped by Bitcoin script and costs only witness weight).

Every zkCoins payload MUST begin with the fixed 2-byte **marker prefix** `0x42 0x42` (`"BB"`), which identifies the envelope as a zkCoins inscription and lets scanners skip all other inscriptions cheaply. The payload layout is:

```
offset  size  field
------  ----  -----------------------------------------------------------
  0       2   marker             = 0x42 0x42             (zkCoins prefix)
  2       1   version            = 0x01
  3       1   format             0x00 = raw commitments
                                 0x01 = half-aggregated (§3.3)
  4       2   count m            big-endian u16, number of commitments
  6      32   block_anchor.block_hash   Bitcoin block hash of the tip this batch is anchored to (§3.7)
 38       4   block_anchor.height       big-endian u32, height of that block (§3.7); cross-checked on acceptance
 42      32   commitment_smt_root  updated global Commitment-SMT root after this batch (§1.6)
 74      32   commitment_mmr_root  updated global Commitment-MMR root after this batch (§1.6)
106      32   nullifier_acc_root   updated global nullifier accumulator root after this batch (§3.7)
138       …   body               depends on `format` (below)

format 0x00 — raw, body length = m × 160 bytes:
   per commitment j (160 bytes):
      32   Pkⱼ        (x-only)
      64   signatureⱼ (R ‖ s)
      64   messageⱼ   (ash ‖ ocr)      // message carries NO nullifier

format 0x01 — half-aggregated, body length = m × 128 + 32 bytes:
      m × 128  per commitment j (128 bytes):  Pkⱼ(32) ‖ messageⱼ(64) ‖ Rⱼ(32)
      32       s_agg      (single shared aggregate scalar, §3.3)
```

The per-transaction `message` is exactly `ash ‖ ocr` and contains **no** nullifier. The spent `nf` set of a transition is bound off-chain via `input_nullifiers_root` in its proof's `ProofData` ([Foundations §1.4](foundations)); the inscription anchors only the **updated global roots** above. A publisher MUST set `commitment_smt_root`, `commitment_mmr_root`, and `nullifier_acc_root` to the values that result from applying this batch on top of `block_anchor` (§3.6, §3.7). A scanner derives the Commitment SMT and MMR roots from confirmed Bitcoin data and MUST reject a batch whose stated `commitment_smt_root` or `commitment_mmr_root` does not match; the correctness of the `nullifier_acc_root` update is attested by the batch's aggregate validity proof (§3.6 step 7), not recomputed by the scanner from foreign bundles.

The `block_anchor` is the pair `{ block_hash, height }` identifying the tip a proof is built against. An issuance validity-window height check ([System Architecture §6.5](architecture)) is evaluated **in-circuit against `block_anchor.height`** — prover-supplied and provable in-circuit, the tip the proof is built against, known at proving time — **not** against the actual (later) Bitcoin inclusion height, which is unknown when the proof is produced. A scanner cross-checks on acceptance that `block_anchor.block_hash` is at `block_anchor.height` in its own Bitcoin chain view.

**`block_anchor` bound (normative).** Let `inclusion_height` be the height of the Bitcoin block that includes this batch's reveal transaction. A scanner MUST reject the batch unless **both**: (1) `block_anchor.height` is strictly less than `inclusion_height` and `block_anchor.block_hash` is a strict ancestor of the inclusion block (the anchor MUST NOT be the inclusion block itself, a forward block, or off the inclusion block's chain), and (2) the gap is bounded by `N = 100` blocks: `inclusion_height − block_anchor.height ≤ 100`. The first condition rejects forward anchoring; the second rejects stale anchoring. A batch whose `block_anchor` is not a strict ancestor of its inclusion block, or whose gap exceeds `N = 100`, MUST be treated as carrying **zero** valid commitments.

> Note on sizes: the fixed payload header is `2+1+1+2+32+4+32+32+32 = 138` bytes (marker, version, format, count, `block_anchor.block_hash`, `block_anchor.height`, and the three updated global roots), amortised across the whole batch. A raw single commitment adds `160` bytes of body — on the order of the ~177 bytes quoted in [Foundations §1.4](foundations) per commitment once the header is shared. Half-aggregation removes one 32-byte `s` per commitment and shares a single `s_agg`, so the marginal cost of an additional commitment falls to 128 bytes (`Pkⱼ ‖ messageⱼ ‖ Rⱼ`). A payload larger than the standardness limit MUST be split across multiple reveal inputs/transactions, each carrying its own marker and header.

A scanner MUST validate the body length against the declared `format` and `count m`: for `format 0x00` (raw) the body length MUST equal `m × 160` bytes (each commitment `Pkⱼ(32) ‖ messageⱼ(64) ‖ signatureⱼ(64)`); for `format 0x01` (half-aggregated) the body length MUST equal `m × 128 + 32` bytes (each commitment `Pkⱼ(32) ‖ messageⱼ(64) ‖ Rⱼ(32)`, plus one shared 32-byte `s_agg`). The §3.6 structural check (step 2) verifies that `count == m` **and** that the body length equals the format's formula above; a scanner MUST reject a malformed or truncated payload — including one whose body length does not match its declared format and count — as carrying **zero** valid commitments.

## 3.6 Chain scanning

Any node rebuilds the global trees from Bitcoin alone, trusting no peer ([Foundations §1.6](foundations), [Requirement 3](/requirements)). For each new Bitcoin block, in canonical order, a node MUST:

1. **Discover.** Identify reveal transactions whose witness contains an inscription envelope beginning with the marker `0x42 0x42` (§3.5). All non-marker inscriptions are ignored.
2. **Parse.** Decode header and body. Reject any payload failing the structural checks of §3.5.
3. **Verify signatures.** For `format 0x00`, verify each BIP-340 signature `signatureⱼ` against `(Pkⱼ, messageⱼ)`. For `format 0x01`, verify the single multi-scalar aggregate check of §3.3. A commitment whose signature does not verify MUST be discarded and MUST NOT enter any tree.
4. **Order.** Establish a total order over verified commitments: primary key = Bitcoin block height; secondary = index of the reveal transaction within the block; tertiary = the commitment's position `j` within its payload. This order is a deterministic function of the public chain, so every node derives the same trees.
5. **Update the Commitment SMT** ([Foundations §1.6](foundations)): for each verified commitment, set the leaf keyed by the spender's `address` to the new committed value derived from `message`. The address is bound to the proof's public inputs, not read from the inscription, so a commitment cannot be mis-attributed.
6. **Append to the Commitment MMR**: after processing all of a block's commitments, append that block's Commitment-SMT root as one MMR leaf (one root per Bitcoin block, [Foundations §1.6](foundations)).
7. **Record the anchored global roots.** A scanner records the three updated global roots inscribed in the payload — `commitment_smt_root`, `commitment_mmr_root`, and `nullifier_acc_root` (§3.5) — as the batch's on-chain-anchored roots. The `nullifier_acc_root` covers the spent `nf` set of every transition in the batch (each bound off-chain via `input_nullifiers_root` in its `ProofData`, [Foundations §1.4](foundations)); a scanner does **not** recompute `nullifier_acc_root` from foreign accounts' off-chain bundles, because it does not hold them. The **correctness of the root update** is attested by the batch's **aggregate validity proof** — an off-chain proof, fetchable and verifiable by anyone — that the inscribed roots are exactly the result of applying this batch on top of `block_anchor`. A **light verifier** MAY accept the most-work-chain-anchored root on the strength of confirmation depth (§3.9); a **full verifier** fetches and verifies the batch's aggregate validity proof before relying on the inscribed roots.

Because steps 1–6 are a pure function of confirmed Bitcoin data, two honest nodes scanning the same chain MUST arrive at identical SMT and MMR roots; the anchored `nullifier_acc_root` of step 7 is the same value for all, since it is read from the chain. A wallet or explorer therefore checks any served root against the on-chain-anchored value, and verifies the root update via the batch's aggregate validity proof, never by trusting the server ([Requirement 4](/requirements), [Requirement 10](/requirements)).

The operative double-spend check is **per-coin** (§3.7): a verifier checks a specific coin's `nf` for (non-)membership against the on-chain-anchored `nullifier_acc_root` using a (non-)membership proof carried in that coin's `CoinProof` bundle — not by recomputing the global root from foreign bundles.

## 3.7 The nullifier accumulator

Double-spend protection is enforced **on-chain and trustlessly** by the global **nullifier accumulator** ([Foundations §1.6](foundations)): a sorted-key sparse Merkle tree (SMT) over all published nullifiers `nf = Hc("Nullifier", nk ‖ coin.identifier)` ([Foundations §1.4](foundations)), supporting both **membership** and **non-membership** proofs.

**Insertion.** When a coin is spent, its `nf` is bound into the spending transaction's proof public inputs (`input_nullifiers_root`, [Foundations §1.4](foundations)). The published `message` (`ash ‖ ocr`) carries **no** nullifier. The publisher anchors the resulting **updated `nullifier_acc_root`** in the inscription (§3.5), and the batch's aggregate validity proof attests that this root is the correct result of inserting the batch's spent `nf` set on top of `block_anchor` (§3.6 step 7). A scanner records this on-chain-anchored root; it does **not** itself recompute the accumulator from foreign accounts' off-chain bundles. The accumulator is idempotent and order-independent across a block; the anchored root depends only on the **set** of nullifiers confirmed up to a given tip.

**Per-transition chaining into the batch root.** Within a batch, the transitions are applied in the §3.6 total order. The batch's **starting** accumulator root is the previous tip's anchored `nullifier_acc_root`. A running accumulator root is then carried through the ordered transitions: each transition's `ProofData.prev_nullifier_acc_root` ([Foundations §1.4](foundations)) **MUST** equal the running root **immediately before** that transition, and its `ProofData.nullifier_acc_root` **MUST** equal the running root **immediately after** it (i.e. after inserting that transition's spent `nf` set). The **final** running root, after the last transition in the §3.6 order, **MUST** equal the `nullifier_acc_root` inscribed for the batch (§3.5). The batch's **aggregate validity proof** (§3.6 step 7) attests exactly this chaining — that the per-transition roots compose, in order, from the starting root to the inscribed batch root; a scanner therefore relies on the inscribed root only once that proof verifies.

**Anchored root.** The accumulator root is **conditional on a specific Bitcoin chain tip**: the canonical value is `NAV(tip) = (root, tip_block_hash, tip_height)`. The `block_anchor = { block_hash, height }` field of every inscription (§3.5) records the tip the publisher built against, with `block_anchor.block_hash` and `block_anchor.height` identifying that tip. A verifier MUST evaluate any membership/non-membership claim **relative to a stated tip**; a root quoted without its anchoring tip MUST be rejected as ambiguous.

**Double-spend check (per-coin).** The operative double-spend check is **per-coin**, evaluated against the **on-chain-anchored** `nullifier_acc_root` at `NAV(tip)` (§3.6 step 7), never by recomputing the global root from foreign bundles. To confirm a specific coin is unspent as of `tip`, a verifier takes that coin's `nf` together with the (non-)membership proof carried in the coin's `CoinProof` bundle ([Foundations §1.5](foundations)) and checks it against the anchored root:

- a **non-membership** proof of `nf` ⇒ the coin is **unspent** at `tip`;
- a **membership** proof of `nf` ⇒ the coin is **already spent**; the spend MUST be rejected.

Because `nf` is unlinkable to the coin without `nk` ([Foundations §1.4](foundations)), the accumulator reveals spends without revealing which coin or account they belong to ([Requirement 2](/requirements)).

**Reorg handling.** If Bitcoin reorganises, every `nf` inscribed only in orphaned blocks MUST be removed and the accumulator recomputed for the new canonical tip, yielding a fresh `NAV(tip')`. Because `NAV` is explicitly tied to a tip, a stale `NAV(tip)` is self-identifying: a verifier MUST recompute or re-fetch `NAV` for the current canonical tip before acting on a non-membership result, and SHOULD wait for finality (§3.8) so that the anchoring tip is reorg-stable. A pruned accumulator MAY discard old subtrees provided it retains enough frontier to still produce non-membership proofs against the current tip.

## 3.8 Fees and economics (brief)

Publishing a batch costs ordinary Bitcoin transaction fees, paid in BTC; zkCoins has no native token ([Requirement 1](/requirements)).

- The **publisher** pays the Bitcoin fee for the inscription it broadcasts (§3.4).
- A publisher **SHOULD** be reimbursable for that cost, and the spender **MAY** compensate the publisher **without revealing a funding UTXO** — a **broadcaster-paid** model in which the moved value covers the fee inside the off-chain settlement, so the spender's on-chain footprint stays limited to the opaque `Commitment`. Concretely, a wallet **MAY** include a publisher fee allowance in the off-chain bundle ([Transport & Recovery](transport-recovery)) that the publisher claims as a zkCoins-native transfer; it **MUST NOT** require the spender to sign or expose a Bitcoin UTXO.
- Fee policy is **not** consensus: a publisher **MAY** set any fee, and a wallet that finds a publisher's fee unacceptable **MAY** use another publisher or self-publish (§3.4). No publisher can extract rent, because publishing is permissionless ([Requirement 7](/requirements)).

## 3.9 Finality

A `Commitment` is **published** the instant its reveal transaction enters a Bitcoin block, and **final** under the same assumptions as any Bitcoin payment of comparable value.

- A receiver **MUST** treat a commitment as merely *seen* (zero-confirmation) until its reveal transaction has at least **one** confirmation, and **SHOULD** require **six** confirmations before treating the associated `NAV` (§3.7) and Commitment-MMR position as reorg-stable for high-value transfers.
- A double-spend non-membership result (§3.7) is only as final as the tip it is anchored to; a verifier **MUST** re-evaluate it if a reorg displaces that tip below the required confirmation depth.
- zkCoins adds no finality assumption beyond Bitcoin's: there is no separate consensus, validator set, or checkpoint ([Requirement 1](/requirements), [Requirement 3](/requirements)). Confirmation depth is the receiver's risk choice, exactly as for a native Bitcoin payment.
