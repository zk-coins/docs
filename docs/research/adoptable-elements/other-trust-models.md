---
title: Learnings — Other Trust Models
---

# Learnings — Confidential & Other Trust Models

This cluster covers three protocols that achieve confidentiality through trust models zkCoins deliberately does **not** copy: Liquid is **federated** (a fixed set of functionaries), Shade runs on Secret Network where privacy rests on **Intel SGX / TEE (trusted hardware)** rather than cryptography, and MimbleWimble (Grin / Beam) runs its **own chain**. The goal here is to extract the *cryptographic mechanism* — amount/asset hiding, state cut-through, no-address interaction, viewing-key auditability — while leaving the trust model behind. Each mechanism is evaluated against the *Bitcoin · Shield · Trustless* triple: it must strengthen one corner without abandoning Bitcoin-anchoring or introducing a trusted operator/federation/enclave.

## Liquid (Blockstream)

**How it works** — Every Liquid transaction is a Confidential Transaction. Amounts are hidden behind **Pedersen commitments** of the form `commitment = xG + aH` (committing to amount `a` with secret blinding factor `x`); a transaction is valid when input and output commitments balance to zero, which any verifier can check without learning the amounts ([blog.liquid.net](https://blog.liquid.net/guide-to-confidential-transactions/), [Blockstream glossary](https://glossary.blockstream.com/pedersen-commitments/)). **Confidential Assets** extends this by making the asset generator variable — the asset tag is itself blinded as `A = H + rG`, so the asset *type* is hidden too — and adds an **asset surjection proof** (a ring signature proving each output asset matches *some* input asset, without revealing which) so assets cannot be forged or transmuted ([Blockstream: Confidential Assets release](https://blog.blockstream.com/en-blockstream-releases-elements-confidential-assets/)). Each output also carries a **range proof** so the hidden amount cannot wrap around into a negative/overflow value; **Bulletproofs** (and the newer **Bulletproofs++**) shrink these from kilobytes to hundreds of bytes with no trusted setup ([Bulletproofs++ blog](https://blog.blockstream.com/bulletproofs-a-step-towards-fully-anonymous-transactions-with-multiple-asset-types/)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Blinded asset tags (`A = H + rG`) | Hiding the asset *type* by blinding the asset generator, not just the amount | zkCoins is going multi-asset; its `AssetId` is currently a shareable/public value. Blinding the asset type so an observer (or hostile node) can't tell *which* asset moved is the natural next privacy layer for multi-asset confidentiality | Multi-asset-confidentiality | High | Research |
| Asset surjection / balance-by-asset-type argument | Proof that outputs map onto input assets and that *each asset type independently sums to zero* in a transaction | zkCoins already hides amounts inside its ZK proof; the missing piece for multi-asset is an in-circuit constraint that each asset balances separately so assets can't be minted/transmuted. The *concept* (per-asset balance) ports directly into the Plonky2 circuit even if the surjection-proof construction itself does not | Multi-asset-confidentiality | High | Med |
| Per-asset range / overflow check | Constraining each hidden amount to a valid non-negative range so it can't overflow the field/modulus | zkCoins hides amounts in-proof; an explicit range constraint per asset prevents overflow forgery once multiple assets and arithmetic share a circuit. In a SNARK this is a standard range-check gadget — cheaper than Liquid's standalone Bulletproof because it folds into the existing recursive proof | Multi-asset-confidentiality | Med | Med |

**Doesn't transfer**

- **Federation is the dealbreaker.** Liquid is operated by a fixed membership of *functionaries* who run consensus and the two-way Bitcoin peg. That is exactly the "misses Trustless" corner. zkCoins must take the *commitment/surjection/range* math and keep its Bitcoin-anchored, no-federation settlement.
- **Standalone Bulletproofs as a separate artifact.** zkCoins already produces a constant-size recursive Plonky2 proof; bolting on per-output Bulletproofs would *add* on-chain/off-chain data and break the constant-footprint story. Borrow the *range-check and per-asset-balance constraints* as circuit gadgets, not the Bulletproof transport.
- **Account/UTXO model differences.** Liquid is UTXO-with-commitments; zkCoins commits to account/coin state hashes. The asset-blinding *idea* transfers; the exact commitment plumbing does not.

## MimbleWimble (Grin / Beam)

**How it works** — MimbleWimble has no scripts and **no persistent addresses**; every output is a unique Pedersen commitment with no reusable identifier ([Grin docs](https://docs.grin.mw/wiki/introduction/mimblewimble/mimblewimble/)). Because every transaction sums to zero, an output that is created and later spent within the chain's history is a pure intermediate: **cut-through** removes these spent intermediate outputs entirely, so a fully-validated node only needs the *unspent* output set plus headers and kernels ([Grin pruning doc](https://github.com/mimblewimble/grin/blob/master/doc/pruning.md)). Grin's own figures: a hypothetical chain that is ~130 GB full collapses to ~1.8 GB after cut-through, and ~520 MB as UTXO-only ([Grin pruning doc](https://github.com/mimblewimble/grin/blob/master/doc/pruning.md)). Because there are no addresses, transactions are **interactive**: sender and receiver exchange a partial transaction ("slate"), each adding inputs/outputs and a partial signature, before it can be broadcast ([Grin transactions doc](https://github.com/mimblewimble/docs/blob/master/docs/about-grin/transactions.md)). **Slatepacks** make that interaction async — the slate is packed into a compact encrypted text blob that can travel over email, chat, a forum, or paper ([Grin transactions doc](https://github.com/mimblewimble/docs/blob/master/docs/about-grin/transactions.md), [Slatepack integration](https://github.com/mimblewimble/docs/blob/master/docs/wiki/services/slatepack-integration.md)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Cut-through (drop spent intermediate state) | Permanently removing outputs that were created and then spent, keeping only the unspent set | zkCoins' S2 strand worries about accumulator/storage growth (SMT + MMR). The cut-through *principle* — historical spent leaves need not be retained for new validation, only the current commitment/nullifier frontier plus what's needed to verify pruned data — is directly relevant to bounding node/accumulator state | State-size | High | Research |
| Slatepack-style encrypted slate transport | A self-contained, encrypted, channel-agnostic blob carrying the in-progress transaction between two parties | zkCoins already needs off-chain delivery of `CoinProof` (coin + proof + inclusion proof) to the recipient and is considering Nostr. A Slatepack-like encoding (encrypted to the recipient, transport-agnostic: Nostr, email, QR, paper) is a clean format for that delivery/interaction payload | Delivery / Addressing | Med | Low |
| No-address interactive build (as an *option*) | Building a transaction via direct sender↔receiver exchange, eliminating a reusable on-chain address | zkCoins' stable address links payments when reused; an *optional* interactive flow (recipient supplies fresh per-payment data in a slate) could remove that linkage for parties who can interact, complementing the existing invoice model | Addressing | Med | Research |

**Doesn't transfer**

- **It runs its own chain.** All MimbleWimble figures assume a dedicated PoW chain whose entire block history is the prunable object. zkCoins anchors on Bitcoin and prunes *its own off-chain accumulator/state*, not Bitcoin. Borrow the cut-through *principle*, applied to the SMT/MMR and nullifier set — not MimbleWimble's chain layout.
- **No anonymity set.** MimbleWimble privacy is CoinJoin-by-default aggregation, *not* a global anonymity set; its unlinkability is statistical and weaker than zkCoins' ZK shield. Do not adopt its privacy *model*, only its state-shrinking and transport ergonomics.
- **Mandatory interactivity.** Forcing every payment to be interactive is a UX regression versus zkCoins' invoice/async model. Treat the interactive/no-address flow as an opt-in privacy upgrade, never the only path. Cut-through itself also must preserve whatever leaves a *recursive* proof needs to re-verify (zkCoins keeps coin history for trustless receive), so naive deletion is unsafe — hence "Research."

## Shade (Secret Network)

**How it works** — Shade is privacy DeFi built on **Secret Network**, where contract state and computation are kept private inside **Intel SGX trusted-execution enclaves**: a node's enclave is a black box whose inputs/outputs may be seen but whose internal state is not, and nodes prove they run genuine patched SGX via **remote attestation** before joining ([Secret Network: Intel SGX](https://docs.scrt.network/secret-network-documentation/introduction/secret-network-techstack/privacy-technology/intel-sgx)). Because Cosmos queries can't cryptographically authenticate the caller, Secret introduces **viewing keys**: the user signs a transaction that generates a random key, stored on-chain paired with their address; afterwards anyone presenting the correct `(address, viewing key)` pair can *read* that account's private data (balance, history) without holding the account's private key ([Secret viewing keys](https://docs.scrt.network/secret-network-documentation/development/development-concepts/secret-contract-fundamentals/access-control/viewing-keys), [SNIP-20 spec](https://github.com/SecretFoundation/SNIPs/blob/master/SNIP-20.md)). This is the auditability/selective-disclosure UX: hand the viewing key to an auditor, accountant, or counterparty and they see exactly what you grant — nothing more.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Viewing-key / read-grant UX | A separate, revocable read credential that opens *only* the holder's data to a chosen third party, with no spend power | zkCoins already has a view-grant idea and the structural ingredient: the `account_state_hash` is a public fingerprint the owner can *open* to the full private balance. A first-class, derive-on-demand read key that lets a user selectively disclose balance/history to an auditor (without exposing the seed or spend keys) is a clean fit for the auditability gap | View-keys | High | Low |
| Selective per-scope disclosure | Granting visibility scoped to one account/asset/time-range rather than all-or-nothing | Maps onto zkCoins' class model (🟠 Private off-chain plaintext): the owner can choose which Coins/accounts to reveal, since each is already openable from its hash. Lets compliance/audit happen without weakening the on-chain shield | View-keys / Recovery | Med | Med |

**Doesn't transfer**

- **TEE is the privacy boundary — and that is the weaker, different trust model.** On Secret, your data is private only because Intel's enclave (and the attestation chain) is trusted; SGX has a track record of side-channel and attestation breaks ([TEE.fail](https://tee.fail/files/paper.pdf)). zkCoins' privacy is cryptographic (ZK), not hardware. **Copy the viewing-key *UX*, never the enclave that backs it.**
- **On-chain key storage.** Secret stores the viewing key on-chain in contract state; zkCoins should *derive* a read grant from the wallet (e.g. a key separate from spend authority) and share it off-chain, keeping nothing extra on Bitcoin.
- **Smart-contract platform scope.** Shade is general private DeFi on its own chain; zkCoins is a Bitcoin-anchored payment layer. Only the read-grant pattern is relevant, not the contract/VM model.

## Top candidates from this cluster

1. **Cut-through principle (MimbleWimble)** — bound node/accumulator state by dropping spent intermediate leaves while preserving what recursive re-verification needs. Gap: State-size. Fit High / Effort Research.
2. **Blinded asset tags + per-asset balance constraint (Liquid Confidential Assets)** — hide asset *type* and prove each asset balances independently, ported as in-circuit constraints (no federation, no standalone Bulletproof). Gap: Multi-asset-confidentiality. Fit High / Effort Med–Research.
3. **Viewing-key / read-grant UX (Shade / Secret)** — first-class selective-disclosure read credential opening the owner's already-openable `account_state_hash` to an auditor, derived in-wallet, with no TEE and nothing extra on-chain. Gap: View-keys. Fit High / Effort Low.
