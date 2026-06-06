# Bitcoin Bridging

zkCoins uses the Shielded CSV protocol for private off-chain transactions, but the protocol alone does not move real Bitcoin. This page documents how real BTC enters and exits the system.

## The Problem

Shielded CSV creates a separate transaction system that uses Bitcoin only for **data availability** (publishing compact commitments as Taproot inscriptions). Coins within the system are virtual — they have no direct link to on-chain BTC.

To handle real Bitcoin, a **bridge** is needed: a mechanism that locks BTC on-chain and issues equivalent shielded coins, and vice versa.

## Roadmap: Two Phases

### Phase 1: Trusted Setup (Launch)

A small, known set of signers operates a federation that bridges BTC into the shielded system.

**How it works:**

1. **Deposit (BTC → zkCoins):** User sends BTC to a federation multisig address. After confirmation, the federation mints equivalent shielded coins to the user's zkCoins account.
2. **Withdrawal (zkCoins → BTC):** User burns shielded coins and provides a Bitcoin address. The federation sends BTC from the multisig to the user.

**Trust model:** N-of-M multisig — at least M signers must be honest. Similar to Liquid (Blockstream) or early Lightning implementations.

**Why this is acceptable for launch:**
- Simple to implement and audit
- Users can verify the federation's Bitcoin reserves on-chain
- Small initial amounts limit risk exposure
- Provides immediate utility while the trustless solution is developed

**Limitations:**
- Federation members can collude to steal funds (M-of-N threshold)
- Requires operational trust in known entities
- Not censorship-resistant (federation can block withdrawals)

### Phase 2: BitVM Bridge (Target)

A trust-minimized bridge using BitVM2 for on-chain verification of Shielded CSV proofs.

**How it works:**

1. **Deposit (BTC → zkCoins):** User locks BTC in a BitVM2 contract (Taproot address with two spend paths). The shielded system verifies the deposit via a Bitcoin light client. Shielded coins are issued to the user.
2. **Withdrawal (zkCoins → BTC):** User burns shielded coins. An operator fronts BTC to the user immediately. The operator claims reimbursement through the BitVM2 contract. If the operator cheats, anyone can challenge using on-chain SNARK verification.

**Trust model:** 1-of-N honesty at setup, permissionless challenging at runtime. If ALL operators are malicious, funds are burned (not stolen). Only one honest challenger is needed to keep the system secure.

**Why this is feasible:**

- **BitVM2 is proven on Bitcoin mainnet** (June 2025: full dispute resolution in 42 blocks, ~$16k cost)
- **Groth16 SNARK verification works on Bitcoin** via BitVM2 script chunks
- **Recursive proofs can be wrapped into a Groth16 SNARK** for on-chain verification. zkCoins' Plonky2 proofs would need such a wrapping step before BitVM2 could verify them on Bitcoin — the same pattern other systems use (e.g. Citrea wraps RISC Zero). This is a forward-looking part of the bridge design and is not yet implemented
- **Robin Linus authored both Shielded CSV and BitVM** — the protocols are designed to work together
- **Live BitVM bridges exist:** Citrea (cBTC, Jan 2026), Bitlayer (YBTC, Jul 2025)
- **Glock/Argo** (Robin Linus + Liam Eagen, Jan 2026) promises 430–2000x cost reduction over BitVM2

## Current State of BitVM (May 2026)

| Milestone | Status |
|---|---|
| BitVM2 paper | Published Aug 2024 |
| Groth16 verification on Bitcoin | Working |
| Plonky2 → Groth16 wrapping | Established technique; not yet implemented for zkCoins |
| First mainnet dispute resolution | June 2025 (42 blocks) |
| Bitlayer bridge (YBTC) | Mainnet since Jul 2025 |
| Citrea bridge (cBTC) | Mainnet since Jan 2026 |
| Glock (430x cheaper) | In development (Alpen Labs) |
| Argo (2000x cheaper) | In development (Ideal Group) |
| Shielded CSV + BitVM bridge | Not yet implemented |

## Key Insight

The same researchers are behind both systems:

- **Robin Linus** — BitVM (2023), zkCoins (2023), Shielded CSV (2025), Argo (2026)
- **Liam Eagen** — Shielded CSV (2025), Glock (2026), Argo (2026)

This is not a coincidence. Shielded CSV was designed with BitVM bridging in mind. The missing piece is the concrete implementation that connects the two.

## Practical Considerations

**Costs (BitVM2, current):**
- Happy path: ~50,000 sats (~$53) per bridge transaction
- Dispute path: ~14.9M sats (~$16,000)
- With Glock/Argo: projected 100–1,600 sats per transaction

**Speed:**
- Peg-in: 6+ Bitcoin confirmations (~1 hour)
- Peg-out (happy path): Instant (operator fronts BTC)
- Dispute resolution: < 8 hours

**Structural limitations:**
- Fixed deposit sizes (e.g. 0.1, 0.5, 1, 10 BTC)
- Operators must hold ~200% collateral
- Challenge economics depend on fee market conditions

## References

- [BitVM2 Paper](https://bitvm.org/bitvm2) — Robin Linus et al.
- [BitVM Bridge Whitepaper](https://bitvm.org/bitvm_bridge.pdf)
- [SNARK Verifier in Bitcoin Script](https://bitvm.org/snark.html)
- [Citrea Clementine Bridge](https://docs.citrea.xyz/essentials/clementine-trust-minimized-bitcoin-bridge)
- [Glock: Verification on Bitcoin](https://www.alpenlabs.io/blog/glock-verification-on-bitcoin) — Alpen Labs
- [Shielded CSV Paper](https://eprint.iacr.org/2025/068) — Jonas Nick, Liam Eagen, Robin Linus
