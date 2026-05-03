---
type: resource
status: active
area: neben
tags: [crypto, bitcoin, privacy, quelle, optech]
updated: 2026-04-21
---

# Bitcoin Optech — Client-side Validation

Zurück zur [[zkCoins/quellen|Quellen & Links]]

**Quelle:** [bitcoinops.org/en/topics/client-side-validation/](https://bitcoinops.org/en/topics/client-side-validation/)

---

*Also covering RGB, Taro, Taproot Assets, and Shielded CSV*

**Client-side validation protocols** allow a Bitcoin transaction to commit to some data whose validity is determined separate from the validity of the transaction under Bitcoin's consensus rules. The client-side validation can take advantage of consensus rules, such as only allowing an output to be spent once within a valid block chain, but it may also impose additional rules known only to those interested in the validation.

A conceptually simple client-side validation protocol might assign an off-chain state (like an amount of owned tokens) with a particular UTXO. Only the set of validators needs to know about that assignment; it does not need to be published anywhere public, such as the blockchain. When the UTXO is spent, the user can update the state and use spending transactions to assign the new state to a new UTXO. This mechanism is known as **single-use seals**, and it leverages anti-double-spending property of bitcoin.

As an example, if Alice currently controls the UTXO associated with the token and Bob wants to buy it from her, she can provide him with evidence of the original assignment and then he can use his validated copy of the block chain plus client-side validation to verify the history of every transfer of the token leading up to Alice. He can also verify that a transaction created by Alice is correctly formatted to assign the token to a UTXO that Bob controls.

## RGB

[rgb.tech](https://rgb.tech/) — A client-side validation protocol for working with arbitrary reachable state and Turing-complete state evolution rules. Uses taproot-embedded OP_RETURN commitments (named **tapret**) to allow transactions to commit to smart contract state.

## Taproot Assets

[docs.lightning.engineering](https://docs.lightning.engineering/the-lightning-network/taproot-assets/) — Formerly **Taro**. Protocol inspired by RGB using taproot's commitment structure for token commitments. Unlike RGB, no Turing completeness. Focused on asset transfer.

Both protocols are designed to be compatible with offchain transactions (LN payments). Only wallets that support RGB/Taproot Assets need to understand the protocol.

## Optech Newsletter Mentions

### 2026
- **Client-side validation and coinjoins** — January 30: [Can one do a coinjoin in Shielded CSV?](https://bitcoinops.org/en/newsletters/2026/01/30/#can-one-do-a-coinjoin-in-shielded-csv)

### 2025
- **RGB v0.12 announced** — July 18

### 2024
- **Shielded client-side validation proposed** — September 27
- **Taproot Assets v0.4.0-alpha released** — August 23
- **LND #8960** custom channel functionality for taproot assets — October 11

### 2023
- Specifications published for taproot assets — September 13
- Update on RGB — April 19

### 2022
- Taro transferrable token scheme — April 13

## Primary Code & Documentation
- [Shielded CSV Paper (PDF)](https://github.com/ShieldedCSV/ShieldedCSV/releases/latest/download/shieldedcsv.pdf)
- [RGB I.0 Yellow Paper](https://yellowpaper.rgb.tech/)
