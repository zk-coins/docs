---
title: Information Model
---

# Information Model

At its core, zkCoins is an **information system**: a small set of pieces of data, each created at a specific point, held by a specific party, and either kept private or published. This page is the complete catalog. For every piece of information it answers four questions:

1. **What is it?**
2. **How does it come into existence?** (its genesis / derivation)
3. **Who holds it?**
4. **How — and whether — may it be shared?**

It complements two neighbouring pages: the [Privacy Model](privacy-model) (what an _on-chain observer_ can see) and the [Trust Model](trust-model) (what your _node operator_ can see). Read this one first — it is the map.

> Notation: `H(...)` denotes a domain-separated hash. In-circuit hashes use **Poseidon over Goldilocks**; the Schnorr signature over the on-chain commitment uses **SHA-256** per BIP-340. The exact functions live in [Proof System](proof-system) and [Key Management](key-management); this page focuses on _what is hashed and why_, not the primitive.

:::info Protocol vs. the zkcoins.app service
This page describes the **zkCoins protocol**. The protocol's only notion of identity is the 32-byte **address** = `SHA-256(initial public key)`.

Human-readable handles such as `name@zkcoins.app`, username registration, and LNURL / Lightning-Address resolution are features of **zkcoins.app — one specific, centralized service provider** built on top of the protocol. They are **not part of the protocol**: it neither stores nor needs an `@` handle, and a different operator may offer different naming, or none at all. Wherever an `@` handle appears below, treat it as a service-layer convenience, not a protocol fact.
:::

## The four sensitivity classes

Every piece of information falls into exactly one class. The class answers "who may hold it and who may see it" in one move:

| Class | Meaning | Lives where |
|---|---|---|
| 🔴 **Secret** | Never leaves the wallet. Disclosure = total loss of funds. | The user's device only |
| 🟠 **Private** | Plaintext bookkeeping. Disclosure = loss of _privacy_ (never theft). | Wallet + the node that hosts the account |
| 🟡 **Shareable** | Handed out on purpose. | User + the payment counterparty |
| 🟢 **Public** | Written to Bitcoin, world-readable — but only opaque commitments (no amounts, no identities). | Bitcoin L1 |

The whole privacy story is the gap between **Private** (off-chain plaintext) and **Public** (on-chain commitments), and the whole trust story is the question _whose node holds the Private data_.

## The information catalog

| Information | Class | How it comes into existence (genesis) | Held by | Shared with | May it be shared? |
|---|---|---|---|---|---|
| **Seed** | 🔴 Secret | 256-bit entropy (BIP-39 mnemonic, or Passkey PRF → HKDF) generated in the wallet | User only | nobody | **Never** |
| **Master private key (Xpriv)** | 🔴 Secret | BIP-32 derivation from the seed | User only | nobody | **Never** |
| **Per-transaction private key** | 🔴 Secret | BIP-32 child derivation; a fresh key per send (forward secrecy) | User only | nobody | **Never** |
| **Address** | 🟡 Shareable | `SHA-256(initial public key)` — fixed once at account creation; the protocol's _only_ identity (see [Key Management](key-management)) | User | the payer (inside an invoice) | Yes — but it is stable, so reusing it links payments |
| **Invoice** `{amount, recipient, asset_id}` | 🟡 Shareable | Created by the recipient when requesting a payment (`recipient` is the 32-byte address) | Recipient | the chosen payer | Yes, with the payer |
| **AccountState** `{owner, balance, public_key}` | 🟠 Private | Created when the account is created; mutates on every send | User + the hosting node | only **your** node | No — the balance is private |
| **Coin** `{identifier, recipient, amount, asset_id}` | 🟠 Private | Built during a send from a `CoinTemplate` | Sender → recipient | the recipient (via the coin proof) | Recipient only (today more is visible than ideal — see [Privacy Model](privacy-model)) |
| **Coin identifier** | 🟡 Shareable | `H(account_state_hash ‖ asset_id ‖ coin_index)` | inside the coin proof | recipient + the coins tree | Yes |
| **AssetId** | 🟡 Shareable | `Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version)` at asset creation | Creator → every user of that asset | public | Yes (everyone using the token needs it) |
| **Validity proof** (Plonky2, recursive) | 🟢 Public | The node's prover produces one per state transition | The node | the recipient (inside the coin proof) | Yes — zero-knowledge, it reveals nothing beyond validity |
| **ProofData** (public inputs) `{account_state_hash, output_coins_root, commitment_history_root, coin_history_root, asset_id}` | 🟢 Public | The public outputs of the proof | public | bound on-chain | Yes — only hashes and roots |
| **CoinProof** = `coin + proof + inclusion_proof` | 🟠 Private | The sender bundles it for delivery | Sender → recipient | the recipient | Recipient only (it contains the plaintext coin) |

## How information comes into existence

This is the heart of the model. Everything is **born in the wallet, top-down from the seed**, and only the **opaque commitment** (no amounts, no identities) is ever written to Bitcoin:

```
Seed (entropy)
  └─BIP32─▶ Master Xpriv
              └─child(i)─▶ Private key_i ──secp256k1──▶ Public key_i
                                                          ├─ H ─▶ Address  (identity, fixed once)
                                                          └─ rotates each send

Address + AccountState{balance} ─── H ───▶ account_state_hash

Send: CoinTemplate{recipient, amount, asset_id}
        └─ + coin_index + account_state_hash ─ H ─▶ Coin.identifier
                                                      └──▶ output_coins_root (tree)

Node prover: (previous state, coins, trees) ── Plonky2 ──▶ Validity proof (+ ProofData)
Delivery to recipient: Coin + proof + inclusion_proof  =  CoinProof
```

Reading it as layers:

- **Key layer (Secret → one Public key).** The seed deterministically produces every key. Only the _public_ key of each transaction ever leaves the device, and it does so inside the on-chain commitment.
- **Identity layer (Shareable).** The address is a one-time hash of the first public key; it is the stable handle a payer needs. An [invoice](addressing) wraps it together with an amount and asset.
- **State & coins layer (Private).** Balances and coins are plaintext bookkeeping. They live off-chain. They are computed by the owner and held by whichever node hosts the account.
- **Asset layer (Shareable).** An asset is defined the moment someone hashes their creator key together with a name and decimals. The resulting `AssetId` is public — every holder of the token references it.
- **Tree layer (Public roots / Private leaves).** The node folds accounts and coins into Merkle structures. The _roots_ are committed on-chain; the _leaves_ (plaintext) are not.
- **Proof layer (Public).** A recursive zero-knowledge proof attests the whole state transition is valid without revealing any Private data. Its public inputs (`ProofData`) carry only hashes.

## Two invariants

These are the load-bearing truths of the whole design:

1. **Privacy is decided by _whose node_ holds the Private data.** Your own node ⇒ no leak. Someone else's node ⇒ that operator sees your Private (plaintext) data — a privacy trade-off — but can **never** steal, forge, or double-spend, because that is enforced by the Public layer plus cryptography. This is exactly the [Trust Model](trust-model): run your own node and you are trustless and private at once.

## Naming is a service-layer feature, not protocol

To the protocol, identity is the 32-byte address (`SHA-256(initial public key)`) and nothing else. The friendly `name@zkcoins.app` form is provided by the **zkcoins.app service**, in two variants:

- **Default handle** — the first 8 hex characters of the address, derived on the fly and resolved on request. It is **not stored anywhere**; it exists for every account automatically. Example: address `e660e4ea…` ⇒ `e660e4ea@zkcoins.app`.
- **Custom username** — an optional override (e.g. `alice@zkcoins.app`) that the user claims with a Schnorr signature over the identity key. Only custom claims are persisted (in the service's own table); a service with no claims still serves every default handle.

Because naming lives entirely in the service, it sits **outside the four protocol classes above**. A self-hosted node may implement naming differently, or not at all — the protocol is unaffected. See [Addressing](addressing) for the service's endpoints.

## Related pages

- [Trust Model](trust-model) — who you trust, and why running your own node removes it
- [Privacy Model](privacy-model) — what an on-chain observer can and cannot see
- [Key Management](key-management) — seed, BIP-32 derivation, Schnorr signing
- [Addressing](addressing) — addresses, invoices, and LNURL compatibility
- [Nullifier Design](nullifier-design) — the on-chain spent-marker
- [Proof System](proof-system) — the recursive Plonky2 circuit
- [Transaction Flow](transaction-flow) — how a send moves through the system end-to-end
