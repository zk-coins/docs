---
sidebar_position: 2
title: 1 · Foundations
---

# 1 · Foundations (normative)

This page is the **single source of truth** for the zkCoins specification. Every other spec page builds on the primitives, keys, identifiers, and structures defined here. It is written against the **target design** (the [Requirements](/requirements)), not against any current implementation.

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119.

## 1.1 Cryptographic primitives

The protocol fixes one concrete instantiation. Where a choice was open, the established, Bitcoin-consistent option is taken.

| Role | Primitive |
|---|---|
| Signature curve & scheme | **secp256k1**, **BIP-340 Schnorr** (x-only public keys, 32-byte) |
| On-chain / signature hash | **SHA-256** (BIP-340 uses tagged SHA-256 internally) |
| In-circuit hash | **Poseidon** over the proof field `𝔽` (Goldilocks, `p = 2^64 − 2^32 + 1`) |
| General hash (addresses, off-circuit ids) | **SHA-256** |
| Recursive proof system | A **proof-carrying-data (PCD)** scheme via **cyclic recursion**; reference instantiation: a FRI-based recursive proof (Plonky-style) over Goldilocks with Poseidon |
| Key derivation | **BIP-32** (secp256k1) for the key tree; **HKDF-SHA256** for symmetric/derived secrets |
| Transport encryption | **NIP-44 v2** (ECDH-secp256k1 → HKDF-SHA256 → ChaCha20 + HMAC-SHA256) |
| Metadata privacy | **NIP-59** gift-wrap |
| Text encoding | **Bech32m** for the address (HRP `zk`); transport identifiers as `bech32m` with role HRPs |

Notation:

- `H(x)` — SHA-256 of byte string `x`.
- `Hc(tag, a, b, …)` — Poseidon over `𝔽`, **domain-separated** by `tag`, applied to the field-encoded inputs.
- `P = k·G` — secp256k1 scalar multiplication; `G` the generator.
- `ECDH(k, P) = x(k·P)` — the x-coordinate of the shared point.
- `a ‖ b` — byte concatenation.
- **Secret vs. public.** A lowercase key name (`skᵢ`, `ivk`, `ovk`, `op`, `nk`) denotes the **secret scalar**; its public point is written `<name>·G` or a named pubkey (e.g. `Pkᵢ = skᵢ·G`, `IVPK = ivk·G`, `op_pubkey = op·G`). BIP-340 public keys are **x-only** (32 bytes).

**Domain separation.** Every domain-separated `Hc`, `HKDF`, or `H` call **MUST** use a context string of the form `"zkCoins/v1/<context>"`. The contexts used in this spec are: `Address`, `AssetId`, `Coin`, `AccountState`, `CoinsRoot`, `Nullifier`, `NullifiersRoot`, `NoteKey`, `DetectTag`, `Grant`, `IssuanceTerms`, `HalfAgg`, `BalanceProof`, `PullChallenge`, `PullHost`. Reusing a tag for two purposes is forbidden.

## 1.2 Key hierarchy

All key material descends deterministically from a single 256-bit **seed**. The seed is the only thing a user backs up ([Requirement 6](/requirements)).

```
seed  (256-bit; BIP-39 mnemonic, or Passkey PRF → HKDF)
  └─ BIP-32 ─▶ m  (master)
        └─ m / 1798' / account'                              = A   (per-account root; 1798' = zkCoins purpose)
              ├─ A / 0'        = SPEND branch   (wallet only)
              │     ├─ A/0'/0'            = sk₀   → Pk₀   (initial signing key; fixes the address)
              │     ├─ A/0'/i'            = skᵢ   → Pkᵢ   (rotating per-transition signing key)
              │     └─ A/0'/n'            = nk            (account-level nullifier key)
              ├─ A / 1'        = VIEW branch    (delegable to a node)
              │     ├─ A/1'/0'            = ivk           (incoming viewing key)
              │     └─ A/1'/1'            = ovk           (outgoing viewing key)
              └─ A / 2'        = op            (operational / Nostr identity key)
```

`1798'` is the chosen BIP-43 purpose index for zkCoins (hardened). All branch separations are **hardened**: the VIEW and `op` branches are hardened children of `A`, so a party holding them **cannot** derive the SPEND branch.

**Who holds what** (this table is the cryptographic basis of the [Trust Model](/architecture/trust-model)):

| Key | Held by | Can do | Cannot do |
|---|---|---|---|
| `skᵢ`, `nk` (SPEND branch) | wallet only | authorise spends, compute nullifiers | — |
| `ivk` | wallet, and any node the wallet delegates to | detect & decrypt **incoming** coins | spend |
| `ovk` | same | recover **outgoing** coin plaintext | spend |
| `op` | the node | publish/receive on Nostr, sign view grants & acknowledgements | spend, decrypt others' coins |
| `K_tx` (per-coin note key, §1.3) | derived per coin; shareable | decrypt **exactly one** coin | spend, see any other coin |

The **operational bundle** `{ivk, ovk, op}` is what a wallet entrusts to a node so the node can receive and serve on its behalf 24/7. None of it can spend. A *foreign* node never receives these directly; the wallet instead issues that node a scoped, `op`-signed **view grant** (§ Access model).

**Spend-key model (account-level).** The keys `skᵢ` are rotating **per-transition** signing keys — there is **no** per-coin signing key. Transition `i` (where `i = send_counter` at entry) is authorised by `skᵢ`, whose public key `Pkᵢ` is the account's `current_pubkey` and is published in that transition's `SpendRecord` (§1.4); the transition rotates `current_pubkey` to `Pk_{i+1}`. `Pk₀` fixes the address and appears on-chain only in the **first** transition. `nk` is account-level. Coin ownership is by the account (a coin's `recipient = address`); a receiver therefore never needs a per-coin key.

**Accounts and addresses are one-to-one.** An account `A` has **exactly one** address, `address = H(Pk₀)` (§1.4). The protocol defines **no** diversified addresses, sub-addresses, or change addresses: there is no way to derive a second, separately-disclosable or separately-unlinkable receiving address under the same account. The **account is therefore the sole unit** of every isolation boundary in the system — privacy domain, selective disclosure ([Access & Explorer](access-explorer)), recovery ([Transport & Recovery](transport-recovery)), and node portability ([Requirement 10](/requirements)). A wallet derives further accounts at `m/1798'/account'`; it **MUST NOT** present multiple receiving addresses within one account. Consequences a wallet **MUST** surface to the user:

- To keep two activities unlinkable toward the counterparties they are shared with, or to disclose one independently of the other ([Access & Explorer §5.8](access-explorer)), each **MUST** live in its **own account**, chosen deliberately — never as an implicit sub-address of a shared account.
- Each additional account is an independent scan and recovery scope (its own `ivk` / `detect_tag` lineage) and adds backup and scanning cost. This cost is the deliberate, accepted price of compartmentalisation; it is the reason the default is **one account reused**, not many accounts.
- Reusing one address toward many counterparties reveals nothing on-chain — [Requirement 2](/requirements) is unaffected — but lets those counterparties correlate one another **off-chain** through the shared address string. Per-relationship unlinkability therefore requires per-relationship accounts, never extra addresses on one account.

## 1.3 Per-coin keys (note encryption & detection)

Each output coin carries an ephemeral key and is individually encrypted, so that a single per-coin capability discloses one coin and nothing else.

```
Per output coin:
  esk           = random scalar                          (sender, fresh per coin)
  epk           = esk·G                                   (published with the coin)
  IVPK          = ivk·G                                   (recipient incoming-view pubkey)
  ss            = ECDH(esk, IVPK)  = ECDH(ivk, epk)       (shared secret; both sides derive it)
  K_tx          = HKDF("zkCoins/v1/NoteKey",  ss ‖ epk)   (per-coin symmetric note key)
  detect_tag    = Hc("zkCoins/v1/DetectTag",  dk ‖ epk)   (per-coin detection tag)
      where dk  = HKDF("zkCoins/v1/DetectTag", ivk)       (detection key, from ivk)
```

- The coin plaintext is encrypted under `K_tx` (NIP-44 v2). Only a holder of `ivk` (the recipient, or its node) can re-derive `K_tx` and decrypt.
- `detect_tag` lets a recipient/node find its own coins on relays **without** trial-decrypting everything, and is **seed-derivable** (so it doubles as the recovery scan key, [Requirement 6](/requirements)). Deterministic tags are linkable by a relay that stores them; a fuzzy-message-detection layer is an **OPTIONAL** privacy upgrade and does not change the interfaces.
- The **per-coin view capability** placed in an explorer link (§ Explorer) is `K_tx` for that one coin. It decrypts that coin only.

## 1.4 Identifiers and hashes

Exact derivations. Every value here is reproducible from its inputs.

| Identifier | Definition | Size / type |
|---|---|---|
| **Address** | `address = H(Pk₀)` — SHA-256 of the **initial** spend public key; fixed at account creation; the protocol's only identity | 32 bytes (Bech32m, HRP `zk`) |
| **AssetId** | `asset_id = Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals)` at asset creation, where `creator_pubkey ≜ Pk₀` of the issuing account (its initial spend public key — the same key that fixes the account `address`), `name_hash = H(name)`, and `genesis_tag` is the fixed constant ASCII string `zkCoins/v1/genesis`; the human-readable `name` is **never** on-chain. Every input is thus derived from stated values, so `asset_id` is fully reproducible | 256-bit digest (32-byte canonical) |
| **Coin identifier** | `coin.identifier = Hc("Coin", account_state_hash ‖ asset_id ‖ coin_index)`. The `account_state_hash` in this formula is the `ash` of the state that **created** the coin (the transition that produced it as an output); a coin's identifier is fixed at creation and recomputed with that same `ash` when later spent. | 256-bit digest (32-byte canonical) |
| **account_state_hash** (`ash`) | `ash = Hc("AccountState", serialize(AccountState))` | 32-byte canonical |
| **output_coins_root** (`ocr`) | Poseidon Merkle root over the transaction's output `coin.identifier`s, tag `CoinsRoot` | 32-byte canonical |
| **input_nullifiers_root** (`inr`) | Poseidon Merkle root over the transition's spent `nf`s, tag `NullifiersRoot` | 32-byte canonical |
| **SpendRecord message** | `message = inr ‖ ocr` — binds the spent nullifier set and the produced output coins | 64 bytes |
| **SpendRecord** | `{ public_key: Pkᵢ (32B x-only), nullifiers: [nf]ⱼ (32B each — the coins spent in this transition, **published in the clear**), signature: BIP-340(skᵢ, message) (64B), message (64B) }` — the **only** object written to Bitcoin. The published `nf`s are exactly what every node folds into the global nullifier accumulator (§1.6); a mint, which spends no coin, publishes an empty `nullifiers` list | `~160 + 32·\|nf\|` bytes inscribed |
| **Nullifier** | `nf = Hc("Nullifier", nk ‖ coin.identifier)` — revealed (in the `SpendRecord`) when a coin is spent; unlinkable to the coin without `nk` | 256-bit digest (32-byte canonical) |
| **ProofData** (public inputs) | `{ new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root }` — note there is **no** accumulator root here: global double-spend is enforced by the published `nf`s on-chain (§1.6), not by an in-circuit membership proof against a global root | hashes/roots only |

The BIP-340 signature over `message` additionally uses **sign-to-contract**: it embeds the digest of the transition's off-chain validity proof (`H(ProofData)`) in the nonce, anchoring that proof to this exact on-chain `SpendRecord` without spending any extra bytes on-chain (see [On-chain layer §3.2](onchain)). This is a real binding to data that is **not** otherwise on-chain — the message itself carries only `inr ‖ ocr`.

## 1.5 Core data structures

```
AccountState = {
  owner          : address,                 // fixed identity
  balances       : map<asset_id, amount>,   // private bookkeeping, multi-asset
  current_pubkey : Pkᵢ,                      // rotates each send
  send_counter   : i                         // monotonic
}

Coin         = { identifier, recipient: address, amount, asset_id }
CoinTemplate = { recipient: address, amount, asset_id }

CoinProof    = {                            // the value-bearing off-chain bundle (bearer)
  coin,                                      // plaintext coin
  proof,                                     // recursive validity proof
  inclusion_proof,                           // membership of coin in output_coins_root
  epk, ciphertext, detect_tag                // encryption envelope (§1.3)
}

Invoice      = { amount, recipient: address, asset_id, memo? }     // shareable, off-chain
```

## 1.6 Trees: one global structure, one per-account structure

| Structure | Scope | Contents | Built from |
|---|---|---|---|
| **Coin-history SMT** | per account | coins the account has received/spent (for in-circuit non-inclusion) | the account's own coins; root folded into `ash` lineage (Private) |
| **Nullifier accumulator** | global | every published `nf` (sorted Merkle / SMT, supports membership + non-membership) | the `nf`s **published in the clear** in every on-chain `SpendRecord` (§1.4) |

There is **exactly one** global structure — the nullifier accumulator — and it is the only thing the protocol relies on Bitcoin to order. zkCoins defines **no** global, account-keyed commitment tree: an account's latest state is carried by its own constant-size recursive proof ([Proofs §2.2](proofs)), never by a global per-account on-chain index. This is deliberate. A global structure keyed by a stable account identifier would have to be **either** rebuildable by every node from the chain (which requires the identifier on-chain) **or** privacy-preserving (which requires it hidden) — never both. The protocol keeps privacy ([Requirement 2](/requirements)) and rebuildability ([Requirement 10](/requirements)) at once by removing that structure entirely and anchoring double-spend protection in the **nullifier accumulator** alone.

Because the spent `nf`s are published verbatim on Bitcoin, **any node rebuilds the nullifier accumulator directly from the chain** — a pure function of confirmed Bitcoin data, identical for every honest node, requiring **no** trust in any peer and **no** foreign off-chain data ([On-chain §3.6](onchain)). The per-account coin-history SMT is Private (its leaves are the account's own coins) and never leaves the account's own proving context; only its root appears, hashed, inside `ash`.

## 1.7 Encoding rules

- Every `Hc` value used as an **identifier, nullifier, or Merkle root** is a full **256-bit Poseidon digest** — four Goldilocks field elements — canonically encoded as 32 bytes (each limb 8 bytes big-endian, limbs in order). A single 64-bit Goldilocks element **MUST NOT** be used as a nullifier, identifier, or root: 64-bit collision resistance is insufficient. SHA-256 outputs are 32 bytes as-is.
- Bitcoin txids are stored internal-order and **displayed** byte-reversed (canonical Bitcoin convention).
- Addresses, view grants, and explorer view capabilities are Bech32m with distinct HRPs so they are never confused: `zk` (address), `zkgrant` (view grant), `zkview` (per-coin view capability), `zkavk` (bearer account view key, `ivk ‖ ovk`; see [Access & Explorer §5.8](access-explorer)). A node/explorer **MUST** reject a value presented under the wrong HRP.
- All multi-input hashes fix input order exactly as written in §1.4; reordering changes the digest and is invalid.
