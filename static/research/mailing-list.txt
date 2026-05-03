---
type: resource
status: active
area: neben
tags: [crypto, bitcoin, privacy, quelle, mailing-list]
updated: 2026-04-21
---

# Bitcoin-Dev Mailing List — Shielded CSV Thread

Zurück zur [[zkCoins/quellen|Quellen & Links]]

**Quellen:**
- [Jonas Nick Ankündigung](https://gnusha.org/pi/bitcoindev/b0afc5f2-4dcc-469d-b952-03eeac6e7d1b@gmail.com/)
- [Antoine Riard Feedback](https://gnusha.org/pi/bitcoindev/14b8d064-1097-4cc5-a0f4-56bbd4f9417b@gmail.com/)
- [Google Groups Thread](https://groups.google.com/g/bitcoindev/c/tAyfaE4lZso)

**Datum:** 24.–26. September 2024

---

## Post 1: Jonas Nick — Ankündigung (24. September 2024)

**From:** Jonas Nick <jonasd.nick@gmail.com>
**To:** bitcoindev@googlegroups.com
**Subject:** [bitcoindev] Shielded CSV: Private and Efficient Client-Side Validation

Hello list,

We (Liam Eagen, Robin Linus, and I) are pleased to announce the release of the Shielded CSV whitepaper, which describes a private and efficient client-side validation (CSV) protocol. Shielded CSV builds upon previous work proposed on this mailing list, including contributions by Peter Todd [0], RGB [1], Taproot Assets [2], and zkCoins [3].

The whitepaper is available here:
https://github.com/ShieldedCSV/ShieldedCSV/releases/latest/download/shieldedcsv.pdf

Our work differs from previous approaches in two main aspects:
1. Shielded CSV is defined using the "Proof-Carrying Data" abstraction, which can be instantiated via recursive zkSNARKs or folding schemes. This provides "full" privacy (hiding of the transaction graph) and ensures that coin proofs and verification time are independent of the transaction graph.
2. Instead of using Bitcoin transactions for CSV-payments, a Shielded CSV payment only requires posting 64 bytes of data to the blockchain (regardless of the CSV-transaction size) and a small constant overhead, significantly reducing on-chain cost.

The Shielded CSV protocol is currently defined using Rust-based pseudocode. We believe that Shielded CSV is both a promising candidate for implementation and provides an extensible framework for further innovation in the CSV space. We welcome feedback and look forward to discussing and expanding upon this work.

**References:**
- [0] Peter Todd (2013): https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2013-November/003714.html
- [1] RGB: https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2023-April/021554.html
- [2] Taproot Assets: https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2022-April/020196.html
- [3] zkCoins: https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2023-May/021679.html

---

## Post 2: Antoine Riard — Kritik (25. September 2024)

**From:** Antoine Riard <antoine.riard@gmail.com>

Few remarks from a cursory reading on the abstract, contributions and technical overview sections.

As you're underscoring too in the paper, I think one of the main scalability bottleneck of the paper is the 64 byte of data to be written in the blockchain, plus a small constant overhead, that 64 byte be it a plaintext of atomic client-side validation transaction, or an aggregation in some of cryptographically efficient representation such as an accumulator.

(The 64 byte of data or whatever the size must be public in the blockchain, otherwise a distributed publication board of the pay-to-contract commitment in the blockchain must be available to make the reveal of the commitment available to CSV clients in a interactively mininized fashion).

On the nullifier itself, i.e "Thus far, our protocol lacks a mechanism to prevent double spending. To address this issue, we require that all coins spent in a transaction are "nullified" by publishing a corresponding nullifier on the blockchain". There is a point that Peter Todd made me once about his old tree chain scheme and the probabilistic validation by clients if my memory is correct, where a client does not have to verify the whole of the transactions total, where in this proposed CSV scheme it sounds **each nullifier verification participant needs the bandwidth cost to read the whole of the blockchain**.

Beyond, about the privacy claim, i.e "coin proofs reveal no information other than the validity of the coin and its creation time" there could be a way to hide the coin creation time, which can be a **huge factor of deanonymization** if you apply cross-layers deanonymization techniques, by using some range proofs like pedersen commitments where the lower and upper bound of the range value are logically ordered on sequence of chain blocks time and height (those maps themselves ordered in a discrete fashion).

Without entering in a debate about perfectly hidding versus perfectly binding cryptographic properties, which can be very quickly degenerates in a debate about axioms and corollary in mathematics, I think such cryptographic structure could have a consensus-level usage in the future, e.g if we extend it as dedicated structure in the taproot annex, where the field is accounted accordingly as witness units.

---

## Post 3: Jonas Nick — Antwort auf Riard (26. September 2024)

**From:** Jonas Nick <jonasd.nick@gmail.com>

Thank you for your comments. They are touching on some of the key aspects of the protocol.

> in this proposed CSV scheme it sounds each nullifier verification participant needs the bandwidth cost to read the whole of the blockchain.

You're correct. Shielded CSV nodes need to have access to the current best blockchain, similar to regular Bitcoin nodes. Shielded CSV nodes scan for 64-byte nullifiers, verify their half-aggregate signatures and place them in a data structure we call "nullifier accumulator".

There's potential for a **light client scheme**, where users don't validate blocks, but infer the best blockchain via proof-of-work (similar to SPV) and obtain the corresponding nullifier accumulator value from somewhere. In addition, they receive a succinct proof that the blockchain is valid and the nullifier accumulator value is correct.

This model allows the light client to receive transactions. However, to create transactions, they need to prove inclusion in the nullifier accumulator, which requires knowledge of the nullifiers in the blockchain. **There are some ideas for how to do this in a relatively light fashion, but nothing concrete yet.** It's certainly an interesting area for further exploration.

> there could be a way to hide the coin creation time

A coin (the data sent to the recipient) contains the exact location of the nullifier that created the coin. This is indeed a noteworthy issue and we discuss the implications in section 6.3 of the paper. In particular, **revealing the nullifier location implies that outputs of the same transaction are linkable**. We therefore suggest that regular wallets should just create a single output.

A fundamental limitation of the Shielded CSV model appears to be that **the sender must reveal an upper bound on when the coin has been created** ("This coin is older than the block at height..."). Otherwise, the receiver would not know how long to wait until the coin has sufficient confirmations.

In fact, a previous version of the Shielded CSV protocol did exactly that. But we moved away from that because it was incompatible with our ideas to support pruning the wallet state (i.e., removing old transaction history), which is an important aspect in holistic privacy.

We came up with a version of the protocol that supported prunable wallet state and only leaked the block in which the coin was created and not the exact nullifier. However, this version has two drawbacks:
1. The state the wallet needs to keep for the unpruned transaction history is larger: **256 bits per received coin** (one hash) instead of about **60 bits** (the blockchain location).
2. The privacy improvement is fuzzy and difficult to understand. In the extreme case, such as when there's only one nullifier in the block, there's no improvement over the current Shielded CSV version.

But I agree, **if possible without significant drawbacks, this privacy leak should be mitigated**.

---

## Post 4: Weikeng Chen — Bridging-Kommentar (26. September 2024)

**From:** Weikeng Chen <weikeng.chen@l2iterative.com>

I think the main challenge for the protocol is bridging, as the paper mentions in Page 4, because without which it might appear that **we are just using Bitcoin for data availability**.

BitVM can help with it, but if we have some upgrades that provide the necessary programmability (e.g., a full-fledged SNARK verification opcode) then this protocol can be deployed on Bitcoin in no time, and Bitcoin can finally have strong privacy.
