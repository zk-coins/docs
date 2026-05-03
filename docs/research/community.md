---
sidebar_position: 3
title: Community Discussion
---

# Community & Diskussion — Shielded CSV



---

## Bitcoin-Dev Mailing List (September 2024)

Die wichtigste technische Diskussion fand auf der Bitcoin-Dev Mailing List statt.

### Jonas Nick — Ankündigung (24. September 2024)

Stellte das Whitepaper vor, betonte dass es auf Peter Todd (2013), RGB, Taproot Assets und zkCoins aufbaut.

> [!quote] Jonas Nick
> "Shielded CSV is the first client-side validation protocol that is private."

### Antoine Riard — Kritik (25. September 2024)

Antoine Riard erhob mehrere gewichtige Einwände:

**1. Deanonymisierungs-Risiko durch Coin-Erstellungszeit:**
> "Coin proofs reveal no information other than the validity of the coin and its creation time" — dies könnte ein "huge factor of deanonymization if cross-layer deanonymization techniques are applied."

Riard schlug **Pedersen-Commitment Range Proofs** vor, um die Erstellungszeit zu verstecken.

**2. Bandbreiten-Anforderungen:**
> "Each nullifier verification participant needs the bandwidth cost to read the whole of the blockchain."

**3. Skalierbarkeits-Flaschenhals:**
Die 64 Bytes pro TX seien immer noch ein "main scalability bottleneck."

### Jonas Nick — Antwort (26. September 2024)

**Zum Blockchain-Zugriff:** Shielded CSV Nodes brauchen Zugang zur Blockchain, ähnlich reguläre Bitcoin Nodes. Light-Client-Schema vorgeschlagen: "users don't validate blocks, but infer the best blockchain via proof-of-work (similar to SPV)" — aber:
> "There is no concrete solution yet."

**Zur Privacy-Lücke:** Fundamentales Trade-off identifiziert. Zwei Ansätze beschrieben:
- Früherer Ansatz: Leckte exakte Nullifier-Position; Outputs verknüpfbar
- Modifizierter Ansatz: 256 statt 60 Bits pro Coin; Privacy-Gains "fuzzy and difficult to understand"

> [!warning] Offenes Problem
> Jonas Nick räumte ein, die Privacy-Lücke brauche Mitigation "if possible without significant drawbacks."

**Links:**
- [Ankündigung](https://gnusha.org/pi/bitcoindev/b0afc5f2-4dcc-469d-b952-03eeac6e7d1b@gmail.com/)
- [Riard Feedback](https://gnusha.org/pi/bitcoindev/14b8d064-1097-4cc5-a0f4-56bbd4f9417b@gmail.com/)
- [Google Groups Thread](https://groups.google.com/g/bitcoindev/c/tAyfaE4lZso)

---

## Talks & Präsentationen

### Konferenzen

| Event | Sprecher | Inhalt | Link |
|---|---|---|---|
| **TABConf 6** (Okt 2024) | Jonas Nick | "Shielded CSV: Private & Efficient Client Side Validation" | [Slides](https://slides.com/iamjon/deck-d58045) |
| **BRD Socratic** | Jonas Nick | "Clearest explanation of Shielded CSV yet" (Dez 2024) | [Slides](https://slides.com/iamjon/shielded-csv-socratic) |
| **Bitcoin Research Week** (Nov 2024) | — | Deep Dive Shielded CSV | — |
| **ZeroSync Event** (Jul 2025) | Robin Linus | "Make Bitcoin Cypherpunk Again with zkCoins" | [YouTube](https://www.youtube.com/watch?v=XIZ3bTZ4VpE) |

### Podcasts

| Podcast | Gäste | Thema | Link |
|---|---|---|---|
| **Bitcoin Takeover S15 E58** | Liam Eagen, Robin Linus, Jonas Nick | Shielded CSV & Bitcoin Privacy | [Podtail](https://podtail.com/en/podcast/bitcoin-takeover-podcast/s15-e58-liam-eagen-robin-linus-jonas-nick-on-shiel/) |
| **Bitcoin Takeover S17 E4** (Jan 2026) | Robin Linus, Liam Eagen, Ying Tong Lai | &#123;ideal&#125; on BitVM Optimizations | [bitcoin-takeover.com](https://bitcoin-takeover.com/s17-e4-ideal-on-bitvm-optimizations-robin-linus-liam-eagen-ying-tong-lai/) |

### YouTube

| Video | Sprecher | Link |
|---|---|---|
| Blockstream: "A New Era of Bitcoin Privacy" | Jonas Nick | [YouTube](https://www.youtube.com/watch?v=aZa2zXp1Q2A) |
| "Make Bitcoin Cypherpunk Again" | Robin Linus | [YouTube](https://www.youtube.com/watch?v=XIZ3bTZ4VpE) |
| "Client Side Validation (zkcoins)" | Liam Eagen | [YouTube](https://www.youtube.com/watch?v=39LN6aTqx9s) |

---

## Community-Stimmung

### Positiv

**Robin Linus (Co-Autor):**
> "The most interesting thing you can do with BitVM."

**Eliel (SoloSafe-Entwickler):**
> "A game-changer for projects like SoloSafe. I strongly believe that bringing trust to the edge is the future, especially as internet access remains unreliable for many and blockchain consensus becomes a bottleneck."

[Blog-Analyse](https://eliel.nfinic.com/2025/04/07/my-thoughts-on-the-shielded-csv-protocol/)

**Vlad Costea (Bitcoin Takeover Podcast):**
Die Diskussion über BitVM und Shielded CSV "restored optimism about Bitcoin development."

**SignalPlus-Analyse:**
Bewertung als "bullish" — könnte "spur positive market sentiment, appeal to privacy-conscious users, and attract developers."

**Fairgate Newsletter:**
[Detaillierte Analyse](https://www.fairgate.io/newsletter/06/01-a-new-paper-by-nick-eagen-and-linus-on-shielded-csv)

### Neutral / Abwartend

**Zcash Community Forum:**
Nur ein Post von "kranzj": "it seems absolutely cool" mit Bitte um technische Einschätzung — keine substantielle Diskussion folgte.

**fiatjaf (Stacker News):**
Fragte direkt: "Is zkCoins really possible or is it just an idea under research?" — Robin Linus fokussierte auf BitVM als Priorität.
[Stacker News AMA](https://stacker.news/items/316211)

### Kritisch

**Antoine Riard:**
Substantielle technische Bedenken zur Deanonymisierung und Bandbreite (siehe oben).

**Jonas Nick selbst:**
Räumte ein, dass Privacy-Modell Schwächen hat und Light-Client-Lösung nicht existiert.

**Data Availability Problem:**
CSV-Protokolle sind "vulnerable to data loss and malicious data withholding" — Custody von Proofs muss off-chain gelöst werden.

---

## Regulatorischer Kontext

### Struktureller Vorteil gegenüber Tornado Cash / CoinJoin
- **Kein Koordinator** — kein zentraler Service, der sanktioniert werden könnte
- **Peer-to-Peer-Protokoll** — ähnlich wie Bitcoin selbst
- **Kein Smart Contract** mit klarem Entry/Exit-Point
- Generische 32-Byte-Nullifier sind **schwer zu filtern**

### Risiken
- Regulatoren könnten versuchen, OP_RETURN-basierte Nullifier zu blacklisten
- Exchanges könnten Coins mit Shielded-CSV-Verbindung ablehnen
- GENIUS Act (Juli 2025) verschärft Stablecoin-Regulierung — indirekte Auswirkungen auf Privacy-Layer

### Kontext
- Samourai Wallet Gründer verhaftet (April 2024)
- zkSNACKs/Wasabi CoinJoin-Koordinator eingestellt (Juni 2024)
- Tornado Cash Verurteilung (Pertsev, Mai 2024, Niederlande)
- EU MiCA + Travel Rule erschweren Privacy bei regulierten Exchanges

---

## Verwandtes Paper

**"Solving Data Availability in Client-Side Validation"**
[ePrint 2025/569](https://eprint.iacr.org/2025/569)
Adressiert das DA-Problem, das eines der grössten offenen Probleme von CSV-Protokollen ist.
