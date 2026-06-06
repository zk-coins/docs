---
sidebar_position: 4
title: 3 · On-chain Layer
---

# 3 · On-chain Layer

> *In one sentence: the single object zkCoins writes to Bitcoin (the `SpendRecord`), how publishers batch many records into one Bitcoin transaction, and how every node rebuilds the global nullifier set from the chain alone.*

This page specifies the Bitcoin-facing layer of zkCoins: how a transition's `SpendRecord` ([Foundations §1.4](foundations)) is signed and embedded, how many records are aggregated and published in a single Bitcoin transaction, how any node rebuilds the global **nullifier accumulator** from the chain ([Foundations §1.6](foundations)), and how that accumulator provides trustless double-spend protection. It introduces **no** change to Bitcoin consensus and **no** native token ([Requirement 1](/requirements)).

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119. All primitives, identifiers, and domain-separation tags are those defined in [Foundations](foundations) and are used unchanged.

## 3.1 The on-chain object

The **only** object zkCoins writes to Bitcoin is the `SpendRecord` of [Foundations §1.4](foundations):

```
SpendRecord = {
  public_key : Pkᵢ                    // 32 bytes, BIP-340 x-only
  nullifiers : [nf]                   // 32 bytes each — the coins SPENT, published in the clear
                                       //   (empty list for a mint, which spends nothing)
  signature  : BIP-340(skᵢ, message)  // 64 bytes  (sign-to-contract binds H(ProofData), §3.2)
  message    : inr ‖ ocr              // 64 bytes  (input_nullifiers_root ‖ output_coins_root)
}                                      // ~160 + 32·|nf| bytes inscribed (before aggregation)
```

`Pkᵢ` is the rotating per-send spend public key ([Foundations §1.2](foundations)); `message` binds the spent-nullifier root `inr` and the transaction's output-coins root `ocr` ([Foundations §1.4](foundations)); `nullifiers` lists those spent `nf`s **verbatim**. A `SpendRecord` contains only hashes, nullifiers, and a signature; it reveals no amount, asset, sender, or receiver, and its rotating `Pkᵢ` and unlinkable `nf`s tie it to no account ([Requirement 2](/requirements)). The proof that the record corresponds to a valid state transition is **off-chain** ([Proofs & State Transitions](proofs)); Bitcoin verifies only that the records were published and ordered. The published `nf`s are exactly what every node folds into the global nullifier accumulator (§3.6) — so the one global structure zkCoins relies on is rebuilt from the chain alone, with no off-chain data.

## 3.2 SpendRecord signing (BIP-340 + sign-to-contract)

The signature in a `SpendRecord` is a BIP-340 Schnorr signature over `message = inr ‖ ocr` produced by the per-send spend key `skᵢ`. It additionally carries, **in its nonce** via **sign-to-contract**, a commitment to the transition's off-chain validity proof, so the proof is anchored to this exact record with no extra bytes on-chain (as stated in [Foundations §1.4](foundations)).

Let `H_tx = H(ProofData)` be the 32-byte digest of the transition's **off-chain** validity-proof public inputs (`H` = SHA-256, [Foundations §1.1, §1.4](foundations)). The canonical byte preimage is the concatenation of the four `ProofData` fields in the order listed in [Foundations §1.4](foundations), each encoded as its 32-byte canonical Poseidon digest (§1.7.1):

```
H_tx = SHA-256( new_account_state_hash  (32B)
              ‖ output_coins_root        (32B)
              ‖ input_nullifiers_root    (32B)
              ‖ coin_history_root        (32B) )
```

A conforming signer and a conforming verifier **MUST** use exactly this concatenation; any other order produces a different `H_tx` and a different on-chain signature. Because `ProofData` is **not** itself on-chain, this is a real, non-redundant binding — distinct from `message`, which carries only `inr ‖ ocr`. The signer MUST construct the nonce as:

```
1. R'  = k'·G                          // k' a fresh, uniformly random 256-bit nonce scalar
2. t   = H( bytes(R') ‖ H_tx )         // sign-to-contract tweak, SHA-256, 32 bytes
3. R   = R' + t·G                      // committed nonce point  (x-only, BIP-340 even-y)
4. e   = H_BIP340( bytes(R) ‖ bytes(Pkᵢ) ‖ message )   // BIP-340 challenge
5. s   = (k' + t + e·skᵢ) mod n        // n = secp256k1 group order
6. signature = bytes(R) ‖ bytes(s)     // 64 bytes
```

The published `signature` is an ordinary, standalone BIP-340 signature: any verifier checks `s·G == R + e·Pkᵢ` with no knowledge of `t`. A receiver who holds the `CoinProof` bundle — hence `ProofData` (so it can compute `H_tx`) and `R'` — can additionally recompute `t` and confirm `R = R' + t·G`, proving the on-chain record commits to **exactly that** off-chain proof. The signer MUST follow BIP-340 nonce hygiene (deterministic-plus-auxiliary-randomness derivation of `k'`) and MUST NOT reuse a nonce across two distinct messages. `Pkᵢ` MUST be the x-only key under which the spend is authorised; reusing `Pk₀` for a non-initial send is forbidden (keys rotate per send, [Foundations §1.2](foundations)).

## 3.3 Half-aggregation

Many independent `SpendRecord` signatures are compressed into one **half-aggregate** before publishing. Half-aggregation is **non-interactive**: it requires no coordination among signers and no secret keys — a publisher (§3.4) performs it on signatures it has merely collected. The published `nullifiers` of each record are carried alongside, unaggregated.

Given records `C₁ … C_m` with signatures `(Rⱼ, sⱼ)`, keys `Pkⱼ`, and messages `mⱼ`:

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

This replaces `m` independent `s` values (32 bytes each) with one, while each `Rⱼ` is retained — and each `Rⱼ` remains the sign-to-contract commitment to its transition's off-chain proof (§3.2). The coefficients `aⱼ` MUST be derived as above so the batch is non-malleable: a verifier MUST reject an `AggSig` whose multi-scalar check fails, and MUST treat every constituent `SpendRecord` of a failing batch as unconfirmed.

## 3.4 The publisher

A **publisher** is the permissionless agent that moves `SpendRecord`s from off-chain to Bitcoin. Its mapping is **many-to-one**: it collects records from many distinct zkCoins transitions — typically from many users — and inscribes them **together in a single Bitcoin transaction**.

- Running a publisher MUST be permissionless; any participant MAY run one, and a wallet/node MAY act as its own publisher.
- A publisher MUST NOT be trusted for **correctness**: it cannot forge, alter, reorder-to-steal, or drop-without-detection any record, because (a) each signature and each published `nf` is verified by every scanning node (§3.5–§3.6), and (b) the value-bearing proof and coin plaintext travel off-chain ([Transport & Recovery](transport-recovery)), never through the publisher.
- A publisher MUST NOT be trusted for **custody**: it never holds a spend key, a coin, or a proof; the worst a faulty or malicious publisher can do is **censor** (refuse to inscribe) or **delay** — both mitigated because anyone else can publish the same record.
- A publisher SHOULD batch over a bounded interval (e.g. once per Bitcoin block) and SHOULD half-aggregate (§3.3) to minimise per-record cost. Records inscribed redundantly by two publishers are idempotent: a scanner inserts each unique `nf` into the accumulator once, and a second inscription of an already-seen `nf` is a no-op (§3.6).

## 3.5 Inscription format

`SpendRecord`s are carried in a Taproot **commit/reveal** inscription. The commit transaction pays to a Taproot output whose internal key is tweaked by a script-path leaf; the reveal transaction spends it, exposing the leaf script, whose witness contains the payload inside an `OP_FALSE OP_IF … OP_ENDIF` envelope (so the data is dropped by Bitcoin script and costs only witness weight).

Every zkCoins payload MUST begin with the fixed 2-byte **marker prefix** `0x42 0x42` (`"BB"`), which identifies the envelope as a zkCoins inscription and lets scanners skip all other inscriptions cheaply. The payload layout is:

```
offset  size  field
------  ----  -----------------------------------------------------------
  0       2   marker             = 0x42 0x42             (zkCoins prefix)
  2       1   version            = 0x01
  3       1   format             0x00 = raw records
                                 0x01 = half-aggregated (§3.3)
  4       2   count m            big-endian u16, number of records
  6      32   block_anchor.block_hash   Bitcoin block hash of the tip this batch is anchored to (§3.7)
 38       4   block_anchor.height       big-endian u32, height of that block (§3.7); cross-checked on acceptance
 42       …   body               m records, depends on `format` (below)

format 0x00 — raw, records concatenated:
   per record j:
      32      Pkⱼ          (x-only)
      64      signatureⱼ   (R ‖ s)
      64      messageⱼ     (inr ‖ ocr)
       1      kⱼ           u8, number of nullifiers spent in this record (0 for a mint)
   32·kⱼ      nullifiersⱼ  (kⱼ × 32B, each a published nf, ascending byte order)

format 0x01 — half-aggregated, records concatenated, then one shared scalar:
   per record j:
      32      Pkⱼ
      64      messageⱼ     (inr ‖ ocr)
      32      Rⱼ
       1      kⱼ
   32·kⱼ      nullifiersⱼ
      32      s_agg        (single shared aggregate scalar, §3.3 — appended once, after all m records)
```

The inscription carries the spent `nf`s **in the clear**, in the body of each record; there are **no** global tree roots in the header. The double-spend state is therefore not *asserted* by a root the publisher chose — it is *rebuilt* by every node directly from the published `nf`s (§3.6), so no off-chain data and no trust in the publisher is involved. A scanner MUST recompute each record's `inr` as the Poseidon root over its listed `nullifiersⱼ` ([Foundations §1.4](foundations)) and reject the record if that root does not equal the `inr` carried in `messageⱼ`; this binds the published nullifier list to the signed message.

The `block_anchor` is the pair `{ block_hash, height }` identifying the tip a proof is built against. An issuance validity-window height check ([System Architecture §6.5](architecture)) is evaluated **in-circuit against `block_anchor.height`** — prover-supplied and provable in-circuit, the tip the proof is built against, known at proving time — **not** against the actual (later) Bitcoin inclusion height, which is unknown when the proof is produced. A scanner cross-checks on acceptance that `block_anchor.block_hash` is at `block_anchor.height` in its own Bitcoin chain view.

**`block_anchor` bound (normative).** Let `inclusion_height` be the height of the Bitcoin block that includes this batch's reveal transaction. A scanner MUST reject the batch unless **both**: (1) `block_anchor.height` is strictly less than `inclusion_height` and `block_anchor.block_hash` is a strict ancestor of the inclusion block (the anchor MUST NOT be the inclusion block itself, a forward block, or off the inclusion block's chain), and (2) the gap is bounded by `N = 100` blocks: `inclusion_height − block_anchor.height ≤ 100`. The first condition rejects forward anchoring; the second rejects stale anchoring. A batch whose `block_anchor` is not a strict ancestor of its inclusion block, or whose gap exceeds `N = 100`, MUST be treated as carrying **zero** valid records.

> Note on sizes: the fixed payload header is `2+1+1+2+32+4 = 42` bytes (marker, version, format, count, `block_anchor.block_hash`, `block_anchor.height`), amortised across the whole batch — the three global-root fields of earlier drafts are gone. A raw record adds `160 + 1 + 32·kⱼ` bytes of body (`Pkⱼ ‖ signatureⱼ ‖ messageⱼ ‖ kⱼ ‖ nullifiersⱼ`); a typical single-input spend (`kⱼ = 1`) is `193` bytes. Half-aggregation removes one 32-byte `s` per record and shares a single `s_agg`, so the marginal cost of an additional record falls to `128 + 1 + 32·kⱼ` bytes. A payload larger than the standardness limit MUST be split across multiple reveal inputs/transactions, each carrying its own marker and header.

Because records are variable-length (each carries its own `kⱼ`), a scanner MUST parse the body **sequentially**: read exactly `m` records by consuming `Pkⱼ`, then `signatureⱼ` (format 0x00) or `Rⱼ` (format 0x01), then `messageⱼ`, then `kⱼ`, then `32·kⱼ` nullifier bytes; for `format 0x01` a single 32-byte `s_agg` follows the last record. The parse MUST consume the body **exactly**: a payload that ends mid-record, declares a `kⱼ` overrunning the body, or leaves trailing bytes (other than the `s_agg` of `format 0x01`) is malformed. The §3.6 structural check (step 2) verifies that exactly `count == m` records parse with no bytes left over; a scanner MUST reject a malformed or truncated payload as carrying **zero** valid records.

**Metadata (normative note).** Publishing each record's nullifiers in the clear exposes one fact a fixed-size on-chain object would not: the **input count `kⱼ`** of each spend — and in particular `kⱼ = 0` marks a **mint** (or a transition that spends nothing). This is the deliberate price of a chain-rebuildable nullifier set (§3.6–§3.7). Amounts, assets, parties, and the transaction graph remain hidden, so [Requirement 2](/requirements) holds for them; the per-spend input count, however, is an **accepted, bounded leak** *outside* that guarantee, and a deployment MUST treat it as visible. A wallet that wants to blunt it MAY split a many-input spend across several transitions or pad to a fixed `k`, at additional on-chain cost; the protocol mandates no padding.

## 3.6 Chain scanning

Any node rebuilds the global **nullifier accumulator** from Bitcoin alone, trusting no peer ([Foundations §1.6](foundations), [Requirement 3](/requirements)). For each new Bitcoin block, in canonical order, a node MUST:

1. **Discover.** Identify reveal transactions whose witness contains an inscription envelope beginning with the marker `0x42 0x42` (§3.5). All non-marker inscriptions are ignored.
2. **Parse.** Decode header and body sequentially (§3.5). Reject any payload failing the structural checks of §3.5.
3. **Verify signatures.** For `format 0x00`, verify each BIP-340 signature `signatureⱼ` against `(Pkⱼ, messageⱼ)`. For `format 0x01`, verify the single multi-scalar aggregate check of §3.3. A record whose signature does not verify MUST be discarded.
4. **Verify the nullifier binding.** For each surviving record, recompute the Poseidon root over its published `nullifiersⱼ` and check it equals the `inr` half of `messageⱼ` (§3.5). A record failing this check MUST be discarded — its published list does not match what was signed.
5. **Order.** Establish a total order over surviving records: primary key = Bitcoin block height; secondary = index of the reveal transaction within the block; tertiary = the record's position `j` within its payload. This order is a deterministic function of the public chain, so every node processes nullifiers in the same sequence.
6. **Insert nullifiers (first-spend-wins).** In that order, for each record, insert each published `nf` into the global nullifier accumulator ([Foundations §1.6](foundations)). If an `nf` is **already present**, that record is a double-spend attempt: the scanner MUST treat the whole record as **invalid** — its `nf`s are not re-inserted and its output coins are treated as never created. The first on-chain occurrence of an `nf`, in this canonical order, is the one and only spend of that coin.

Because steps 1–6 are a pure function of confirmed Bitcoin data, two honest nodes scanning the same chain MUST arrive at the **identical** nullifier accumulator — no node-supplied root, and no foreign off-chain data, is ever consulted. A wallet or explorer therefore computes the accumulator itself, or checks any served (non-)membership answer against its own copy, never by trusting the server ([Requirement 4](/requirements), [Requirement 10](/requirements)).

The operative double-spend check is **per-coin** (§3.7): a verifier checks a specific coin's `nf` for (non-)membership against the accumulator it rebuilt from the chain. There is no global root to fetch and no per-coin membership path needs to travel inside a `CoinProof` bundle, because the verifier holds the whole published `nf` set itself.

## 3.7 The nullifier accumulator

Double-spend protection is enforced **on-chain and trustlessly** by the global **nullifier accumulator** ([Foundations §1.6](foundations)): a sorted-key sparse Merkle tree (SMT) over every nullifier `nf = Hc("Nullifier", nk ‖ coin.identifier)` ([Foundations §1.4](foundations)) ever **published in a `SpendRecord`**, supporting both **membership** and **non-membership** proofs.

**Insertion.** When a coin is spent, its `nf` is published in the clear in the spending transition's `SpendRecord` (§3.1, §3.5). Every node folds the published `nf`s into the accumulator in the §3.6 canonical order (step 6, first-spend-wins). There is **no** inscribed accumulator root and **no** off-chain attestation of one: the accumulator is a deterministic function of the published `nf`s, so every honest node computes the same one directly from the chain. It is idempotent and order-independent across the *set* of confirmed nullifiers; the canonical order matters only to decide, between two records publishing the **same** `nf`, which is the valid spend (the earlier) and which the rejected double-spend (the later).

**Anchored value.** A non-membership answer is meaningful only **relative to a Bitcoin chain tip**: the canonical value is `NAV(tip) = (accumulator, tip_block_hash, tip_height)`. The `block_anchor = { block_hash, height }` field of every inscription (§3.5) records the tip the proof was built against. A verifier MUST evaluate any membership/non-membership claim **relative to a stated tip**; an answer quoted without its anchoring tip MUST be rejected as ambiguous.

**Double-spend check (per-coin).** To confirm a specific coin is unspent as of `tip`, a verifier checks that coin's `nf` against the accumulator it **rebuilt itself** from the chain at `NAV(tip)` (§3.6) — never against a root supplied by a node:

- `nf` **absent** ⇒ the coin is **unspent** at `tip`;
- `nf` **present** ⇒ the coin is **already spent**; a fresh spend of it MUST be rejected.

Because `nf` is unlinkable to the coin without `nk` ([Foundations §1.4](foundations)), the published nullifiers reveal that *some* coin was spent without revealing which coin or account ([Requirement 2](/requirements)).

**Light clients (cost of trustless non-membership).** Non-membership is checked against the accumulator, so a verifier that does not hold it has **no free shortcut** — this is the standing cost of nullifier-based double-spend protection, shared with the Shielded CSV paper and with Zcash, not specific to zkCoins. There is no compact on-chain root to verify against in 32 bytes; that earlier-draft shortcut was only ever as trustworthy as an off-chain attestation that this design removes. Two honest options remain:

- **(i) Maintain the accumulator itself**, by scanning only the marker inscriptions (§3.5) — far cheaper than full Bitcoin validation (on the order of tens of bytes per spend), but its state grows with the total number of spends ever made.
- **(ii) Delegate** the check to one or more nodes. Delegation has a sharp edge a membership check lacks: a dishonest node can falsely answer *unspent* for an already-spent coin and so trick a receiver into accepting a double-spend. A delegating wallet therefore **SHOULD** query several independent nodes — correctness holds as long as ≥1 is honest ([System Architecture §6.3](architecture)) — and **SHOULD** fall back to (i) for high-value receipts.

A node **MAY** serve a **checkpoint accumulator root** to help an option-(i) client cross-check its own scan. Because that root is a **deterministic function of the on-chain nullifiers**, anyone who reconstructs the set recomputes and rejects a wrong one — unlike the publisher-asserted root of earlier drafts it carries **no** authority, and it does **not**, by itself, grant a zero-state client trustless non-membership. The protocol therefore inscribes no root and mandates none.

**Reorg handling.** If Bitcoin reorganises, every `nf` published only in orphaned blocks MUST be removed and the accumulator recomputed for the new canonical tip, yielding a fresh `NAV(tip')`. Because `NAV` is explicitly tied to a tip, a stale one is self-identifying: a verifier MUST recompute or re-fetch `NAV` for the current canonical tip before acting on a non-membership result, and SHOULD wait for finality (§3.9) so that the anchoring tip is reorg-stable. Storage MAY exploit the tree's sparseness — the never-occupied regions of the 256-bit key space are implicit default subtrees and need not be stored — but the accumulator **cannot** prune by age: nullifiers are uniformly distributed keys, so "old" does not map to a discardable region, and every inserted `nf` must stay represented to answer both membership and arbitrary non-membership against the current tip. Only never-occupied key-space is free; the set of inserted nullifiers itself is not prunable.

## 3.8 Fees and economics

Publishing a batch costs ordinary Bitcoin transaction fees, paid in BTC; zkCoins has no native token ([Requirement 1](/requirements)). Fee policy is **not** consensus — a publisher **MAY** set any rate, and a wallet **MAY** pick another publisher or self-publish — but the economic model has structure the spec pins so implementations compose deterministically and so that the obvious risk asymmetries (publisher's BTC paid up front, settlement of any zkCoins-native reimbursement on a later confirmation clock) cannot be glossed over.

**The publisher pays the Bitcoin fee.** A publisher (§3.4) bears the on-chain fee of the inscription it broadcasts, paid from its own Bitcoin UTXOs, before the contained `SpendRecord`s ever reach state `completed` (§3.10).

**The publisher carries the failed-record risk.** A `SpendRecord` whose admission fails (rejected by §3.5 or §3.6, state `failed` per §3.10) was still inscribed — the publisher's BTC fee is spent regardless of the record's fate. Publishers therefore **SHOULD** admission-verify each record they accept before broadcasting (proof verifies, every `nf` non-member of their accumulator at the proving tip, `block_anchor` within bound, message and nullifier-binding intact). The expected residual loss across that filter enters the fee they quote; there is **no** in-band "refund on failure" mechanism, and one would not be sound — the Bitcoin fee is already burned.

**Reimbursement is a zkCoins-native transfer, never a Bitcoin UTXO.** A spender **MAY** compensate a publisher by including a fee-allowance `CoinTemplate` (§1.5) in the same transition's off-chain bundle ([Transport & Recovery](transport-recovery)): `recipient = publisher.address`, `asset_id` one of the publisher's advertised accepted fee assets. The fee coin is created by the same `SpendRecord` as the rest of the spend, so it becomes `completed` precisely when the rest does — and never if the spend is `failed`. A spender **MUST NOT** sign or expose a Bitcoin UTXO; the spender's on-chain footprint stays limited to the opaque `SpendRecord`.

**Settlement timing.** The fee coin pays the publisher *after* the publisher has paid its BTC fee, on the same finality clock as every other recipient — at six confirmations (§3.9). The publisher's BTC outlay is therefore working capital it floats across the 6-confirmation window; the fee it quotes covers that time-value-of-money and the failed-record risk premium. A publisher **MAY** quote a higher rate for high-value or unfamiliar spends; this is a market signal, not a protocol parameter.

**Fee asset (no canonical token).** Each publisher advertises its **accepted fee assets** and per-asset rates (e.g. a BTC-pegged asset, a stablecoin asset, or the asset being moved itself) alongside its `op_pubkey` and relay set. A wallet picks a publisher whose accepted set intersects the assets the wallet holds; if no intersection exists, the wallet **MUST** swap into an accepted asset first or self-publish. The advertisement format and discovery mechanism are **out of scope of v1** — implementations advertise out-of-band (a publisher's HTTPS profile, a Nostr replaceable event under `op_pubkey`, a directory) — but the rule that the publisher names its accepted assets and rates publicly is normative, so wallets can shop and so no publisher can demand undisclosed terms after the fact.

**Self-publishing trade-off (normative note).** A wallet **MAY** publish its own `SpendRecord`, sidestepping the reimbursement loop and any publisher risk premium. The price is a **Bitcoin-layer linkage**: the funding UTXO that pays the reveal-transaction fee, and any change output, are visible to a Bitcoin-side observer and link the broadcaster's identity to that exact reveal transaction. The opaque on-chain `SpendRecord` itself stays opaque, but the *broadcaster* of the reveal becomes identifiable. Wallets that require maximum on-chain unlinkability **SHOULD** prefer a third-party publisher; wallets that must self-publish **SHOULD** use a fresh, unrelated funding UTXO per spend (Bitcoin-layer mechanisms such as CoinJoin or PayJoin are out of scope of zkCoins but compose) so a Bitcoin-side observer cannot link successive self-publishes to one identity.

**Permissionless market, no rent extraction.** Because publishing is permissionless ([Requirement 7](/requirements)) and the fee-asset and rate are advertised, no publisher can extract rent above the competitive rate; the wallet's alternative is always to pick another publisher or to self-publish at the privacy cost above.

## 3.9 Finality

A `SpendRecord` is **published** the instant its reveal transaction enters a Bitcoin block. zkCoins fixes the finality threshold at **6 confirmations**: a record at fewer than 6 confirmations is in state `pending` (§3.10), and a receiver **MUST NOT** treat it as anchored. The protocol assumes Bitcoin has **no reorgs deeper than 5 blocks**; a deeper reorg is treated as a protocol-failure event, not a recoverable state transition.

- A double-spend non-membership result (§3.7) is only as final as the tip it is anchored to; a verifier **MUST** re-evaluate it on any reorg that displaces the inclusion block (§3.10).
- zkCoins adds no finality assumption beyond Bitcoin's: there is no separate consensus, validator set, or checkpoint ([Requirement 1](/requirements), [Requirement 3](/requirements)).
- Threat-model implications of the 5-block bound: see [Architecture §6.6](architecture#66-threat-model-and-trust-configurations).

## 3.10 Transaction states

Every `SpendRecord` a verifier observes is classified into **exactly one** of three states. The state is a function of the verifier's own §3.5+§3.6 admission scan and the inclusion block's confirmation depth — **never** of any assertion by a node, courier, or sender. Two honest verifiers at the same canonical Bitcoin tip **MUST** classify every record identically.

| State | Defined as | Receiver MAY credit |
|---|---|---|
| **`completed`** | the record is **admitted** under §3.5+§3.6 by the verifier's own scan **AND** its inclusion block has **at least 6 confirmations** (§3.9) | **yes** |
| **`failed`** | the record is **rejected** by the verifier's scan — any single §3.5 or §3.6 admission rule violated (parser, `block_anchor` bounds, signature, nullifier-`inr` binding, canonical order, first-spend-wins) suffices | **no** (never) |
| **`pending`** | the record is in neither state — its bytes are inscribed but the inclusion block has fewer than 6 confirmations, or the record is still off-chain | **no** |

**Relationship to the nullifier accumulator.** The global nullifier accumulator (§3.7) absorbs the `nf`s of every **admitted** record (= `pending` ∪ `completed`), not only of `completed` records. Double-spend protection therefore takes effect **at admission**; the 6-confirmation threshold gates only the receiver's credit behaviour, not the accumulator update. Receive-side non-membership ([Proofs §2.3.3](proofs) step 5) runs against this live accumulator, so a coin whose spend has been admitted at the verifier's tip is immediately unavailable for any further spend — even while that spending record is still `pending`.

**6 confirmations is a hard protocol constant**, not a parameter: zkCoins assumes Bitcoin has no reorgs deeper than 5 blocks (§3.9), and a deeper reorg is treated as a protocol-failure event — not a state transition under §3.10. Under this assumption, **`completed` is absolute**: a record once classified `completed` stays `completed`.

**`failed` is forward-sticky.** A rejection cannot become an admission by waiting. A reorg **MAY** change *which* of two conflicting records is rejected (e.g. if the canonical order shifts under first-spend-wins, §3.6 step 6), but the property of being rejected by some admission rule cannot be undone by passage of time alone.

**Receivers SHALL act only on `completed`.** The anchor / receive checks in [Proofs §2.3.3](proofs), [Transport & Recovery §4.5](transport-recovery), and [Access & Explorer §5.6 / §5.7](access-explorer) all require the relevant `SpendRecord` to be in state `completed`; a record in any other state **MUST NOT** be treated as anchored. The user-facing **status** rendered by an explorer (e.g. Access & Explorer §5.6 step 3) **MUST** be the §3.10 state, not a node-asserted classification.
