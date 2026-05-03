---
sidebar_position: 1
title: Protocol Analysis
---

# Shielded CSV Protocol Analysis

Deep dive into the protocol that zkCoins implements. Derived from the [ePrint paper](https://eprint.iacr.org/2025/068) and the [ZeroSync prototype](https://github.com/ZeroSync/ZKCoins).

# Technische Architektur — Shielded CSV



---

## 1. Grundprinzip: Client-Side Validation

Shielded CSV baut auf der Arbeit von **Peter Todd** (Single-Use Seals, 2016/2017), **RGB**, **Taproot Assets** und **zkCoins** auf. Es ist das **erste CSV-Protokoll mit echter Privacy**.

```
Traditionell:  TX → Blockchain → ALLE Nodes validieren
Shielded CSV:  TX → Sender schickt Proof an Empfänger → Empfänger validiert
               Blockchain speichert nur 64-Byte-Nullifier (Anti-Double-Spend)
```

## 2. Datenstrukturen

### Coin-Struktur
```
Coin        = Transaction Output (Betrag + Public Key)
CoinID      = Transaction Hash + Coin Index
Coin Proof  = Transaktionshistorie zurück bis zur Ausgabe (Issuance)
Transaction = (AcctState, Coins, NewAcctState, NewCoins)
```

### Account-Modell
- **Nicht** das traditionelle Account-Modell — ähnlicher zum Bitcoin UTXO-Modell
- Jeder User hat zu jedem Zeitpunkt **einen einzelnen Seal**
- Account-Updates aggregieren empfangene Inputs in einen History Proof
- Reduziert Nullifier von **einem pro ausgegebenem Coin** auf **einen pro Account-State-Update**

## 3. Nullifier-Design (Evolution in 5 Stufen)

Das Paper beschreibt die schrittweise Komprimierung:

| Stufe | Grösse | Mechanismus |
|-------|--------|-------------|
| 1 (unsicher) | pro Coin | `Nullifier = (CoinID, TxHash)` — kein Signaturschutz |
| 2 (unsicher) | pro TX | `Nullifier = (Nullifier_PubKey, TxHash)` — PubKey statt CoinID |
| 3 | 96 Bytes | `+ Schnorr-Signatur` — Schutz gegen unautorisierte Updates |
| 4 | 128 Bytes | `Aggregierte Signaturen` |
| **5 (final)** | **64 Bytes** | **Accounts + Sign-to-Contract + Schnorr Half-Aggregation** |

### Sign-to-Contract Mechanik
Der Sender zieht einen zufälligen Skalar `k`, berechnet:
- `R' = kG`
- `R = R' + H_SigComm(R', h)G`

Dadurch wird der **Transaktionshash in die Schnorr-Signatur committed**. Nach Aggregation bleibt `R_i` das Transaktionscommitment des i-ten Nullifier Public Key.

### Half-Aggregation
Erlaubt es, **n Schnorr-Signaturen nicht-interaktiv** in eine Signatur zu aggregieren, die etwa **halb so gross** ist. Publisher sammeln Nullifier und erstellen aggregierte Nullifier.

## 4. Proof-Carrying Data (PCD)

PCD ist die **zentrale kryptographische Abstraktion**:

- Jede Transaktion erzeugt einen Berechnungsbeweis
- Nachfolgende Transaktionen hängen von vorherigen Beweisen ab → Outputs bleiben vertrauenswürdig
- **Grösse und Verifikationszeit des Coin Proofs sind unabhängig von der Transaktionshistorie**
- Ein PCD-Schema mit Zero-Knowledge-Eigenschaft bietet **nahezu perfekte Privacy**: Der Coin Proof verbirgt Transaktionen, Bilanzen, Accounts — nur der Nullifier wird offengelegt

### Benchmark (aus verwandter Forschung)
Bei r=2 und Berechnungsgrösse 2^24:
- ~49 Sekunden Proof-Generierung pro Schritt
- SNARK-Komprimierung: 1031 MB → 13 KB
- Verifier-Zeit: 11 → 22 Sekunden

### Zwei Implementierungsstrategien
1. **Folding Schemes** — inkrementelle Proof-Komprimierung
2. **Recursive STARKs** — rekursive Proof-Verifikation innerhalb neuer Proofs

## 5. TS-Accumulator (Nullifier Accumulator)

- Users pflegen einen lokalen Nullifier-Accumulator mit **allen publizierten Nullifiern**
- Beim Empfang eines neuen Blocks: Scan nach Nullifiers, Einfügen falls CoinID noch nicht vorhanden
- Implementiert als **sortierter Merkle-Baum**
- **Alte Subtrees können vergessen werden** ohne die Fähigkeit zu verlieren, Non-Membership-and-Insert-Beweise durchzuführen
- Reduziert Wallet-Speicherbedarf und Daten bei Wallet-Kompromittierung

## 6. Non-Inclusion Proofs

- Monatliche Merkle-Bäume sortierter Seals aus Blöcken liefern Non-Inclusion-Beweise
- Users aggregieren monatlich einen Merkle-Pfad in ihren Account-History-Proof
- **Kein global wachsender UTXO-Set nötig**
- Konstanter Speicherbedarf für die Basisschicht

## 7. Publisher-Rolle

- **Jeder kann Publisher werden** (permissionless)
- Publisher sammeln Nullifier und posten sie **gebatcht in einer einzigen On-Chain-Transaktion**
- Verlangen typischerweise eine Gebühr als Kompensation
- Viel effizienter als eine dedizierte Transaktion pro Nullifier

## 8. Blockchain-Reorganisation

- Nullifier in Blöcken, die in der neuen Chain fehlen, müssen entfernt werden
- Gelöst durch **"Conditional Nullifier Accumulator Value" (NAV)**

## 9. Kryptographische Primitive

| Primitiv | Verwendung |
|---|---|
| **Schnorr-Signaturen** | Nullifier-Autorisierung |
| **Sign-to-Contract** | Commitment des TX-Hash in die Signatur |
| **Schnorr Half-Aggregation** | Komprimierung mehrerer Nullifier-Signaturen |
| **Proof-Carrying Data (PCD)** | Sukzessiv komprimierte ZK-Beweise der TX-Historie |
| **Recursive zkSNARKs** | PCD-Instanziierung |
| **Folding Schemes** | Alternative PCD-Instanziierung |
| **Recursive STARKs** | Proof-Komprimierung |
| **Sortierte Merkle-Bäume** | Nullifier-Accumulator, Non-Inclusion-Proofs |

## 10. Zukünftige Entwicklungsfelder (aus dem Paper)

- Payment Channels und Timelocks
- Light-Client-Unterstützung (noch keine konkrete Lösung)
- BitVM-Bridging für Bitcoin-Integration
- Scriptable Spending Policies
- Atomic Swaps
- Shared Account Schemes (t-of-n)
- Post-Quantum-Sicherheit (erwähnt aber nicht ausführlich)
- Trustless Publishing-Mechanismen

---

*Quelle: [ePrint 2025/068](https://eprint.iacr.org/2025/068)*
