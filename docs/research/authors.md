---
sidebar_position: 2
title: Authors & Ecosystem
---

# Autoren — Shielded CSV



---

## Robin Linus

**Organisation:** ZeroSync Association (Schweiz)
**Rolle:** Bitcoin-Forscher, Protokolldesigner
**Ursprung:** Deutschland
**Website:** [robinlinus.com](https://robinlinus.com/)

### Projekte

**ZeroSync Foundation (~2022/2023)**
- Non-Profit, Sitz Schweiz
- Ziel: Zero-Knowledge Proofs für Bitcoin nutzbar machen
- Kernprojekt: Verifizierung der gesamten Bitcoin-Blockchain mittels eines einzigen STARK-Proofs
- Ermöglicht "instant sync" für neue Nodes
- Basiert auf Cairo (StarkWare's ZK-Sprache)
- Finanziert durch Spiral (Block/Square), Human Rights Foundation

**BitVM (Oktober 2023)**
- "BitVM: Compute Anything on Bitcoin" — revolutionäres Whitepaper
- Turing-vollständige Berechnungen auf Bitcoin ohne Soft Fork
- Fraud-Proof-System (optimistic computation)
- Basiert auf Bit Commitments in Taproot-Scripts
- Hat die gesamte Bitcoin L2/Bridge-Landschaft verändert

**BitVM2 (2024)**
- Permissionless Verifier-Modell (jeder kann falschen Claim anfechten)
- 1-of-n Trust Model (ein ehrlicher Teilnehmer genügt)
- Basis für Trust-minimized Bridges (Citrea, BOB, Alpen Labs etc.)
- Produktionsreif

**BitVM3 (2025, experimentell)**
- Weitere Vereinfachung und Effizienzsteigerung

**&#123;ideal&#125; Group (Januar 2026)**
- Team: Robin Linus, Liam Eagen, Ying Tong Lai
- Lancierte **"Argo"** mit "2000x efficiency gain over BitVM 3"
- Könnte Shielded CSV Implementierung beschleunigen

**zkCoins (2023)**
- Ursprüngliches Konzept als [GitHub Gist](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119)
- Erstes Konzept das CSV mit Zero-Knowledge Proofs kombiniert
- Wurde zu Shielded CSV weiterentwickelt

### Vision
Robin Linus verfolgt konsequent die Vision, Bitcoin **ohne Protokolländerungen** um Privacy, Skalierung und Programmierbarkeit zu erweitern:
- ZeroSync → Chain-Verifizierung
- BitVM → Berechnungen auf Bitcoin
- Shielded CSV → Privacy für Bitcoin

> [!quote] Robin Linus
> "Shielded CSV is the most interesting thing you can do with BitVM."

---

## Jonas Nick

**Organisation:** Blockstream Research
**Rolle:** Kryptograph
**GitHub:** [jonasnick](https://github.com/jonasnick)
**Twitter/X:** [@n1ckler](https://x.com/n1ckler)

### Kryptographische Beiträge

**BIP 340 — Schnorr-Signaturen für Bitcoin**
- Co-Autor (mit Tim Ruffing, Pieter Wuille)
- Definiert Schnorr-Signaturen über secp256k1
- Grundlage für Taproot (aktiviert November 2021)

**MuSig2**
- Co-Autor (mit Tim Ruffing, Yannick Seurin)
- Zwei-Runden Multi-Signatur-Schema
- n-of-n Multi-Signaturen, die on-chain wie einzelne Signatur aussehen
- BIP 327

**libsecp256k1**
- Kernentwickler der kryptographischen Bibliothek von Bitcoin Core
- Hochoptimierte, sicherheitskritische C-Bibliothek

**Weitere Beiträge**
- MuSig-DN (Deterministic Nonces)
- FROST Threshold Signatures
- Adaptor Signatures (Scriptless Scripts)
- Liquid Network / Confidential Transactions bei Blockstream

### Verbindung zu Shielded CSV
Jonas Nicks Expertise in Schnorr-Signaturen und MuSig ist direkt relevant — das Protokoll nutzt Schnorr-basierte Commitments und Signatur-Schemata. Er ist der **Hauptentwickler des Referenz-Repositories** ([ShieldedCSV/ShieldedCSV](https://github.com/ShieldedCSV/ShieldedCSV)).

### Klarstellung zum Unterschied zkCoins → Shielded CSV
> [!quote] Jonas Nick
> zkCoins repräsentiert "significant progress", aber "the proposal does not describe the complete protocol and lacks some important details." Shielded CSV füllt diese Lücken.

---

## Liam Eagen

**Organisation:** Alpen Labs
**Rolle:** Kryptograph, Mathematiker
**Standort:** Austin, TX
**GitHub:** [Liam-Eagen](https://github.com/Liam-Eagen)

### Forschung

**Alpen Labs**
- Entwickelt **Strata** — ZK-Rollup auf Bitcoin (nutzt BitVM2 als Bridge)
- Kryptographische Grundlagenforschung

**Bulletproofs++**
- Paper: "Bulletproofs++: Even Shorter Range Proofs"
- [GitHub: Liam-Eagen/BulletproofsPP](https://github.com/Liam-Eagen/BulletproofsPP) (Haskell, 32 Stars)
- Effizientere Range Proofs — potentiell relevant für Shielded CSV

**Curve Trees**
- Effizientes Membership-Proof-System
- Beweis dass Element zu Menge gehört, ohne Element zu offenbaren
- Relevant für Privacy Coins und anonyme Transaktionen

**Zero-Knowledge Proofs auf elliptischen Kurven**
- Proofs über Cycles of Elliptic Curves
- Relevant für rekursive SNARKs

### Verbindung zu Shielded CSV
Liam Eagens Expertise in ZK-Proof-Systemen und Commitment-Schemata ist zentral für den "Shielded"-Teil. Seine Arbeit an Curve Trees und effizienten Membership Proofs ermöglicht die Privacy-Garantien.

---

## Schlüsselpersonen (Implementierung)

| Person | GitHub | Rolle | Aktiv in |
|---|---|---|---|
| **Lukas ("Luckylee")** | `lucidLuckylee` | Hauptentwickler funktionaler Prototyp | ZeroSync/ZKCoins, BitVM/zkCoins |
| **stillsaiko** | `stillsaiko` | Entwickler, SMT-Tests | ZeroSync/ZKCoins |
| **josibake** | `josibake` | Silent Payments BIP-Autor, forkte Referenzrepo | ShieldedCSV Fork |

---

## Team-Synergien

| Autor | Spezialgebiet | Beitrag zu Shielded CSV |
|---|---|---|
| **Robin Linus** | Bitcoin-Protokolldesign, ZK-Proofs | Architektur, Vision, CSV-Design |
| **Jonas Nick** | Kryptographie, Signaturen | Schnorr/MuSig-Primitives, Referenzcode |
| **Liam Eagen** | ZK-Proof-Systeme, Curves | Zero-Knowledge Beweissysteme |

Shielded CSV ist die **Synthese ihrer jeweiligen Spezialgebiete**.
