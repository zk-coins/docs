---
type: resource
status: active
area: neben
tags: [crypto, bitcoin, privacy, quelle, data-availability]
updated: 2026-04-21
---

# Solving Data Availability in CSV — ePrint 2025/569

Zurück zur [[zkCoins/quellen|Quellen & Links]]

**Quelle:** [eprint.iacr.org/2025/569](https://eprint.iacr.org/2025/569)

---

## Paper-Metadaten

| | |
|---|---|
| **Titel** | Solving Data Availability Limitations in Client-Side Validation with UTxO Binding |
| **Autoren** | Yunwen Liu (Cryptape), Bo Wang (UTxO Stack), Ren Zhang (Cryptape/Nervos) |
| **Datum** | Eingereicht 2025-03-28, revidiert 2026-02-12 |
| **Publikation** | CAAW'26 (5th International Cryptoasset Analytics Workshop) |
| **Kategorie** | Cryptographic protocols |
| **Lizenz** | CC BY 4.0 |

## Abstract

Issuing tokens on Bitcoin remains a highly sought-after goal, driven by its market dominance and robust security. However, Bitcoin's limited on-chain storage and functionality pose significant challenges. Among the various approaches to token issuance on Bitcoin, client-side validation (CSV) has emerged as a prominent solution. CSV delegates data storage and functionalities beyond Bitcoin's native capabilities to off-chain clients, while leveraging the blockchain to validate tokens and prevent double-spending.

Nevertheless, these protocols require participants to maintain token ownership and transactional data, rendering them **vulnerable to data loss and malicious data withholding**.

In this paper, we propose **UTxO binding**, a novel framework that achieves both robust data availability and enhanced functionality compared to existing CSV designs. This approach securely binds a Bitcoin UTxO, which prevents double-spending, to a UTxO on an **auxiliary blockchain**, providing data storage and programmability. We formally prove its security and implement our design using **Nervos CKB** as the auxiliary blockchain.

## Relevanz für Shielded CSV

Dieses Paper adressiert eines der **grössten offenen Probleme** von CSV-Protokollen: Data Availability. Da bei Shielded CSV die gesamte TX-Historie und Coin-Proofs off-chain beim User liegen, sind CSV-Systeme anfällig für Datenverlust. Der UTxO-Binding-Ansatz schlägt eine Lösung über eine Hilfs-Blockchain vor.

> [!warning] Kernproblem
> "CSV protocols require participants to maintain token ownership and transactional data, rendering them vulnerable to data loss and malicious data withholding."

## BibTeX

```
@misc{cryptoeprint:2025/569,
      author = {Yunwen Liu and Bo Wang and Ren Zhang},
      title = {Solving Data Availability Limitations in CSV with {UTxO} Binding},
      howpublished = {Cryptology {ePrint} Archive, Paper 2025/569},
      year = {2025},
      url = {https://eprint.iacr.org/2025/569}
}
```
