---
sidebar_position: 8
title: Glossary
---

# Glossary

A short, scannable reference for the jargon, notation, and identifier names used throughout the specification. Each entry links back to its defining section. For the full reading order start at the [specification index](.).

## Notation

- **`H(x)`** — SHA-256 of the byte string `x`. ([§1.1](foundations#11-cryptographic-primitives))
- **`Hc(tag, x₁, …)`** — Poseidon-over-Goldilocks hash, domain-separated by `tag`, of the field-encoded inputs. ([§1.1](foundations#11-cryptographic-primitives), [§1.7](foundations#17-encoding-serialization-and-the-reference-instantiation))
- **`a ‖ b`** — byte concatenation.
- **`P = k·G`** — secp256k1 scalar multiplication; `G` is the generator.
- **`ECDH(k, P) = x(k·P)`** — x-coordinate of the shared secp256k1 point.
- **Lowercase keys (`skᵢ`, `nk`, `ivk`, `ovk`, `op`)** — secret scalars; their public points are written `<name>·G` or as named pubkeys (`Pkᵢ`, `IVPK`, `op_pubkey`). BIP-340 public keys are x-only (32 bytes). ([§1.2](foundations#12-key-hierarchy))

## A–Z

- **AccountState** — `{owner, balances, current_pubkey, send_counter, coin_history_root}`; private bookkeeping, never on-chain in plaintext. Its hash `ash` is bound by every transition's proof. ([§1.5](foundations#15-core-data-structures))
- **`address`** — `H(Pk₀)`; the protocol's only identity, fixed at account creation, encoded as Bech32m `zk`. ([§1.4](foundations#14-identifiers-and-hashes))
- **AccountUpdateProof** — the proof type for any transition after the first; consumes the account's previous proof and emits a new one (PCD). ([§2.2](proofs#22-proof-types))
- **`ash` (account_state_hash)** — `Hc("AccountState", serialize(AccountState))`. ([§1.4](foundations#14-identifiers-and-hashes), [§1.7.4](foundations#174-serializeaccountstate))
- **`asset_id`** — `Hc("AssetId", genesis_tag ‖ Pk₀ ‖ H(name) ‖ decimals)`; globally unique per asset, never carries the human-readable name on-chain. ([§1.4](foundations#14-identifiers-and-hashes))
- **`balances`** — `map<asset_id, amount>` in `AccountState`; the account's multi-asset bookkeeping. ([§1.5](foundations#15-core-data-structures))
- **`block_anchor`** — `{block_hash, height}` of the Bitcoin tip a batch's proofs are built against; bounded by `N = 100` blocks behind the inclusion block. ([§3.5](onchain#35-inscription-format))
- **Bech32m** — text encoding used for addresses (`zk`), view grants (`zkgrant`), per-coin view caps (`zkview`), bearer account view keys (`zkavk`). ([§1.7.7](foundations#177-bech32m-and-bitcoin-conventions))
- **Bundle (CoinProof)** — `{coin, proof, inclusion_proof, epk, ciphertext, detect_tag}`; the off-chain object that is *simultaneously* the recipient's receipt and its spend credential. ([§1.5](foundations#15-core-data-structures))
- **Cap (per coin)** — see *capability*; the smallest is `zkview` per-coin. ([§5.3](access-explorer#53-per-coin-view-capability))
- **Capability** — a cryptographic permission to view some Private record (ownership proof, view grant, bearer view key, per-coin view cap, balance attestation). ([§5.4](access-explorer#54-capabilities-at-a-glance))
- **Capability-gated pull** — the node API serves Private records only after the requester presents a valid capability. ([§5.1](access-explorer#51-capability-gated-pull))
- **`Coin`** — `{identifier, recipient, amount, asset_id}`; the off-chain value-carrying unit. ([§1.5](foundations#15-core-data-structures))
- **`coin.identifier`** — `Hc("Coin", account_state_hash ‖ asset_id ‖ coin_index)` of the creating state; fixed at creation. ([§1.4](foundations#14-identifiers-and-hashes))
- **Coin-history SMT** — per-account, Private; tracks coins received/spent for in-circuit non-inclusion; root folded into `ash`. ([§1.6](foundations#16-trees-one-global-structure-one-per-account-structure))
- **CoinProof** — see *Bundle*.
- **CoinTemplate** — `{recipient, amount, asset_id}`; the sender's per-payee instruction inside a `Send`. ([§1.5](foundations#15-core-data-structures))
- **Cyclic recursion** — one fixed circuit verifies proofs of itself; verifier data is constant, so proof size and verification time are constant. ([§2.2](proofs#22-proof-types))
- **`detect_tag`** — `Hc("DetectTag", dk ‖ epk)`; per-coin, all-distinct, recipient-side scan only — no relay filter and no cross-coin linkability. ([§1.3](foundations#13-per-coin-keys-note-encryption--detection), [§4.4](transport-recovery#44-note-discovery))
- **`dk` (detection key)** — `HKDF("DetectTag", ivk)`; lets a holder of `ivk` recognise its own incoming coins by recomputing `detect_tag` per candidate event. ([§1.3](foundations#13-per-coin-keys-note-encryption--detection))
- **DeliveryEvent** — Nostr event carrying `{detect_tag, epk, blob_id, blob_locators}` plaintext, NIP-44 encrypted to `IVPK`, NIP-59 gift-wrapped under an ephemeral key. ([§4.2](transport-recovery#42-bundle-delivery))
- **`epk` (ephemeral pubkey)** — `esk·G`, drawn fresh per output coin; the recipient's `K_tx` and `detect_tag` are derived from it. ([§1.3](foundations#13-per-coin-keys-note-encryption--detection))
- **Field, field element** — a value in 𝔽 (Goldilocks, `p = 2^64 − 2^32 + 1`); a Poseidon digest is **four** field elements (32 bytes). ([§1.1](foundations#11-cryptographic-primitives), [§1.7.1](foundations#171-poseidon-instance-and-digest-encoding))
- **Fuzzy message detection (FMD)** — OPTIONAL probabilistic relay-side pre-filter; reduces the recipient's download volume, not its linkability (the per-coin scheme already has none). ([§1.3](foundations#13-per-coin-keys-note-encryption--detection), [§4.7](transport-recovery#47-metadata-and-privacy-tradeoffs))
- **Goldilocks** — the proof field `𝔽` with prime `p = 2^64 − 2^32 + 1`; pinned for Poseidon. ([§1.1](foundations#11-cryptographic-primitives))
- **Half-aggregation** — non-interactive compression of many BIP-340 signatures into one shared aggregate scalar `s_agg`, retaining each `Rⱼ`. ([§3.3](onchain#33-half-aggregation))
- **HKDF** — HKDF-SHA-256, used for symmetric/derived secrets (`K_tx`, `dk`). ([§1.1](foundations#11-cryptographic-primitives))
- **`Hc`** — see *Notation*.
- **InitialProof** — the first transition of an account; `prev_proof` is absent and `prev_account_state` is the canonical empty account. ([§2.2](proofs#22-proof-types))
- **`inr` (input_nullifiers_root)** — Poseidon Merkle root over a transition's spent `nf`s under tag `NullifiersRoot`. ([§1.4](foundations#14-identifiers-and-hashes), [§1.7.5](foundations#175-poseidon-merkle-tree-used-for-ocr-and-inr))
- **Inscription** — Taproot commit/reveal envelope whose witness payload starts with the 2-byte marker `0x42 0x42` and carries `SpendRecord`s. ([§3.5](onchain#35-inscription-format))
- **Invoice** — `{amount, recipient, asset_id, memo?, ivpk, op_pubkey, relays, sig}`; the off-chain payer-facing addressing object, op-signed by the recipient. ([§1.5](foundations#15-core-data-structures), [§4.3](transport-recovery#43-addressing-for-delivery))
- **`IVPK`** — `ivk·G`; the recipient's incoming-view pubkey, used to encrypt delivery events and as the ECDH counterpart. ([§1.3](foundations#13-per-coin-keys-note-encryption--detection))
- **`ivk`** — incoming viewing key (VIEW branch); detects and decrypts incoming coins; cannot spend. ([§1.2](foundations#12-key-hierarchy))
- **`K_tx`** — `HKDF("NoteKey", ss ‖ epk)`; per-coin symmetric note key; decrypts exactly one coin's ciphertext. ([§1.3](foundations#13-per-coin-keys-note-encryption--detection))
- **Lineage (account)** — the account's chain of recursive proofs, each consuming its predecessor; carried in constant size by PCD. ([§2.2](proofs#22-proof-types))
- **`message`** — `inr ‖ ocr`; the BIP-340-signed payload of a `SpendRecord` (64 bytes). ([§1.4](foundations#14-identifiers-and-hashes))
- **Mint** — the trustless, permissionless issuance transition; produces an account-owned coin under the `IssuanceTerms`; publishes an empty `nullifiers` list on-chain. ([§2.3.1](proofs#231-mint--issuance), [§6.5](architecture#65-issuance--trustless-permissionless-emission))
- **MMR** — *deprecated*; no Merkle Mountain Range is used in v1 (the v0 Commitment-MMR was removed; see [§1.6](foundations#16-trees-one-global-structure-one-per-account-structure)).
- **`NAV(tip)`** — `(accumulator, tip_block_hash, tip_height)`; the accumulator's value at a stated Bitcoin tip; a non-membership answer is meaningful only relative to a `NAV`. ([§3.7](onchain#37-the-nullifier-accumulator))
- **`nf` (nullifier)** — `Hc("Nullifier", nk ‖ coin.identifier)`; revealed in the clear when the coin is spent, unlinkable to the coin without `nk`. ([§1.4](foundations#14-identifiers-and-hashes))
- **NIP-44 v2** — encrypted message format (ECDH-secp256k1 → HKDF-SHA-256 → ChaCha20 + HMAC-SHA-256); used for the delivery payload and acknowledgements. ([§1.1](foundations#11-cryptographic-primitives), [§4.2](transport-recovery#42-bundle-delivery))
- **NIP-59** — Nostr gift-wrap; outer envelope under a fresh ephemeral key so a relay sees neither sender nor recipient. ([§1.1](foundations#11-cryptographic-primitives), [§4.2](transport-recovery#42-bundle-delivery))
- **`nk`** — nullifier key (SPEND branch, account-level); used only in-circuit to compute `nf`s. ([§1.2](foundations#12-key-hierarchy))
- **Nullifier accumulator** — global, sorted-key SMT over every published `nf`; rebuilt by every node directly from the chain; the only global structure. ([§1.6](foundations#16-trees-one-global-structure-one-per-account-structure), [§3.7](onchain#37-the-nullifier-accumulator), [§1.7.6](foundations#176-nullifier-accumulator-sparse-merkle-tree))
- **`ocr` (output_coins_root)** — Poseidon Merkle root over a transition's output `coin.identifier`s under tag `CoinsRoot`. ([§1.4](foundations#14-identifiers-and-hashes), [§1.7.5](foundations#175-poseidon-merkle-tree-used-for-ocr-and-inr))
- **`op`** — operational/Nostr identity key; held by the node; signs view grants and acknowledgements; cannot spend. ([§1.2](foundations#12-key-hierarchy))
- **Ownership proof** — a BIP-340 signature by `sk₀` over a node-issued challenge; grants the subject's full Private view. ([§5.1(a)](access-explorer#a-ownership-proof))
- **`ovk`** — outgoing viewing key (VIEW branch); recovers outgoing-coin plaintext; cannot spend. ([§1.2](foundations#12-key-hierarchy))
- **PCD (Proof-Carrying Data)** — a recursion-based proof system: each transition consumes a previous proof and emits a new one; one constant-size proof attests the entire history. ([§2](proofs))
- **`Pkᵢ`** — `skᵢ·G`; the rotating per-transition signing pubkey (x-only); `Pk₀` fixes the address. ([§1.2](foundations#12-key-hierarchy))
- **Poseidon** — algebraic hash over Goldilocks used inside the proof circuit; reference instance is Plonky2's `PoseidonGoldilocksConfig`. ([§1.1](foundations#11-cryptographic-primitives), [§1.7.1](foundations#171-poseidon-instance-and-digest-encoding))
- **`ProofData`** — `{new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root}`; the proof's public inputs. ([§1.4](foundations#14-identifiers-and-hashes), [§2.1 clause 9](proofs#21-the-compliance-predicate))
- **Publisher** — permissionless agent that batches `SpendRecord`s into Bitcoin inscriptions; cannot forge, only censor or delay. ([§3.4](onchain#34-the-publisher))
- **Recursive verification** — see *PCD*; clause 1 of the predicate. ([§2.1](proofs#21-the-compliance-predicate))
- **`send_counter`** — monotonic counter inside `AccountState`; increments per transition. ([§1.5](foundations#15-core-data-structures))
- **`serialize(AccountState)`** — canonical byte serialization; preimage for `ash`. ([§1.7.4](foundations#174-serializeaccountstate))
- **Sign-to-contract (S2C)** — the BIP-340 signature's nonce is tweaked by `t = H(R' ‖ H(ProofData))`, anchoring the off-chain proof to this exact `SpendRecord` with no extra on-chain bytes. ([§3.2](onchain#32-spendrecord-signing-bip-340--sign-to-contract))
- **`skᵢ`** — rotating per-transition signing key (SPEND branch); `sk₀` is the initial key that fixes the address. ([§1.2](foundations#12-key-hierarchy))
- **SMT (Sparse Merkle Tree)** — 256-bit-depth Merkle tree with default-hashed empty subtrees; used for the coin-history root and the global nullifier accumulator. ([§1.6](foundations#16-trees-one-global-structure-one-per-account-structure), [§1.7.6](foundations#176-nullifier-accumulator-sparse-merkle-tree))
- **SpendRecord** — `{public_key, nullifiers, signature, message}`; the **only** object zkCoins writes to Bitcoin. ([§1.4](foundations#14-identifiers-and-hashes), [§3.1](onchain#31-the-on-chain-object))
- **`ss` (shared secret)** — `ECDH(esk, IVPK) = ECDH(ivk, epk)`; the input to `K_tx`. ([§1.3](foundations#13-per-coin-keys-note-encryption--detection))
- **Tag (domain-separation tag)** — the string `"zkCoins/v1/<context>"` prefixed to every `Hc`/`HKDF` call; reusing a tag for two purposes is forbidden. ([§1.1](foundations#11-cryptographic-primitives))
- **Transition** — one execution of the compliance predicate `C` (mint, send, or receive). ([§2.3](proofs#23-state-transitions))
- **View grant** — `op`-signed delegated viewing key (Bech32m `zkgrant`), scoped by `asset_ids` and time. ([§5.2](access-explorer#52-view-grant))
- **`zkavk`** — bearer account view key (Bech32m), payload `ivk ‖ ovk`; sees the full account history; non-revocable. ([§5.8](access-explorer#58-address-view-full-history))
- **`zkgrant`** — see *View grant*.
- **`zkview`** — bearer per-coin view capability (Bech32m), payload `K_tx`; decrypts exactly one coin. ([§5.3](access-explorer#53-per-coin-view-capability))

## See also

- [Reading guide](.) — the order to read the spec pages in.
- [Requirements](/requirements) — the ten non-negotiable properties this glossary's identifiers exist to satisfy.
- [Test vectors](test-vectors) — worked-example values for the identifiers above.
