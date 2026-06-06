#set document(
  title: "zkCoins Protocol Specification",
  author: "TaprootFreak",
)
#set page(paper: "us-letter", margin: (x: 1in, y: 1in), numbering: "1")
#set par(
  justify: true,
  leading: 0.65em,
  first-line-indent: (amount: 1em, all: true),
)
#set text(font: "New Computer Modern", size: 11pt, lang: "en")

#set heading(numbering: none)
#show heading.where(level: 1): it => block(above: 1.8em, below: 1em)[
  #set text(weight: "bold", size: 16pt)
  #it.body
]
#show heading.where(level: 2): it => block(above: 1.3em, below: 0.5em)[
  #set text(weight: "bold", size: 13pt)
  #it.body
]
#show heading.where(level: 3): it => block(above: 1em, below: 0.4em)[
  #set text(weight: "bold", size: 11.5pt)
  #it.body
]

#show raw.where(block: true): it => block(
  stroke: 0.5pt,
  inset: 0.8em,
  width: 100%,
  breakable: true,
  text(font: "DejaVu Sans Mono", size: 8.5pt, it),
)
#show raw.where(block: false): it => text(font: "DejaVu Sans Mono", size: 9.5pt, it)

// Tables: generous inset + horizontal lines between rows, breakable across pages
#set table(
  inset: (x: 0.5em, y: 0.6em),
  stroke: (x, y) => if y == 0 { (bottom: 0.5pt) } else { (top: 0.3pt + luma(70%)) },
)
// Let individual cells split across pages when content exceeds remaining space
#set table.cell(breakable: true)
// Shrink everything inside tables so long monospace tokens fit cells
#show table: set text(size: 9pt)
#show table: set par(leading: 0.5em, justify: false)
// Pandoc wraps tables in `figure(#table(...)], kind: table)` —
// strip the align(center) so wide tables can expand to text width and break
#show figure.where(kind: table): it => block(width: 100%, breakable: true, it.body)

// Admonitions: plain bordered boxes (Shielded-CSV figure-box style), bold lead-in
#let admonition(label, body) = block(
  stroke: 0.5pt,
  inset: (x: 1em, y: 0.8em),
  width: 100%,
  spacing: 1em,
  breakable: true,
)[
  #text(weight: "bold")[#label.]#h(0.5em)#body
]
#let tipbox(body) = admonition("Tip", body)
#let infobox(body) = admonition("Note", body)
#let warningbox(body) = admonition("Warning", body)

// ============= TITLE =============
#align(center)[
  #v(0.5em)
  #text(size: 18pt, weight: "regular")[
    zkCoins Protocol Specification
  ]

  #v(1.2em)

  #text(size: 11pt)[TaprootFreak]

  #v(0.8em)

  June 6, 2026

  #v(0.4em)

  #text(size: 9.5pt, style: "italic")[
    Version v0.1
  ]
]

#v(2em)

#align(center, text(size: 12pt, weight: "bold")[Abstract])
#v(0.4em)

#set par(first-line-indent: 0pt)

Bitcoin is the world's most censorship-resistant settlement layer, yet
every transaction it records broadcasts who paid whom and how much. The
accepted remedy — a separate private chain like Zcash or Monero — buys
privacy by leaving Bitcoin and replacing its security model with a new
one. *Shielded CSV*, the construction of Nick, Eagen, and Linus
(ePrint 2025/068), changes the trade-off. Building on Peter Todd's
client-side validation paradigm and Robin Linus's *zkCoins* proposal,
it keeps Bitcoin as the only base, writes just *64 bytes* per
transaction onto it, and moves the entire validation — amounts, parties,
and the whole transaction graph — into a *constant-size zero-knowledge
proof* carried directly between sender and receiver.

The whitepapers describe the cryptography. They do not describe the
system. How does a sender deliver a coin proof without leaking metadata?
How does a wallet recover from a seed when its state lives off-chain?
How does an explorer reveal exactly the data the owner authorises, and
nothing else? How does a user move between nodes without losing
custody — or run several at once? This specification fills in those
layers, exactly once and exactly.

Every choice the source papers leave open is pinned to one option here:
*secp256k1 + BIP-340* on Bitcoin's surface, *Poseidon over the
Goldilocks field* inside the recursive circuit, *BIP-32 + HKDF* for the
key tree, *NIP-44 / NIP-59* for off-chain transport. Every key
derivation, identifier, and byte layout is exact; a conformance harness
of test vectors lets two independent implementations agree on the same
hex.

One principle drives every decision: *complete self-sovereignty with
zero central elements*. Settle only on Bitcoin L1. Hold the spend key
only in the wallet — no node has it, in any configuration. Deliver over
a node-as-relay mesh; recover from seed alone; switch nodes freely;
decide unilaterally who sees what. The three properties that rarely
appear together elsewhere — *Bitcoin-anchored*, *shielded*,
*trustless* — hold here as a single triad.

This is the target design. It is intentionally independent of any
current implementation, and stands as the contract any implementation
must meet.

#quote(block: true)[
  Private payments on Bitcoin — no new chain, no token, no consensus
  change, no trusted operator. Only Bitcoin, zero-knowledge proofs, and
  the user's own keys.
]

#set par(first-line-indent: (amount: 1em, all: true))

#pagebreak()

#outline(title: "Contents", indent: auto, depth: 3)

#pagebreak()
#tipbox[In one paragraph (plain language) zkCoins lets you send value on
Bitcoin without anyone seeing the amount, the asset, who paid, or who
received. Bitcoin stores only #strong[opaque markers] that a spend
happened --- #emph[not] the coin\'s contents, which travel privately
between sender and receiver as a small encrypted bundle.
#strong[Double-spend protection] is the chain\'s job: each spent coin
publishes a one-time random-looking #emph[nullifier] on Bitcoin, and any
second appearance is rejected. Your #strong[seed phrase] derives every
key, your #strong[wallet] is the only thing that can spend, #strong[any
node] can serve you, and you check every figure against Bitcoin
yourself.]

#infobox[What this is --- and what it isn\'t This is #strong[one]
concrete realization, not the only one possible: wherever the source
papers leave a choice open, this specification takes the established,
Bitcoin-consistent option and defines it exactly. It builds faithfully
on the whitepapers\' core and carries their philosophy into every layer
they did not formalize --- delivery, recovery, access, and operation. It
describes the #strong[target design] and is intentionally independent of
any current implementation.]

== One principle, carried all the way
<one-principle-carried-all-the-way>
Every decision below follows from one idea --- #strong[complete
self-sovereignty, zero central elements] --- applied without exception:

#table(
    columns: 2,
    align: (auto,auto,),
    table.header([Design decision], [follows from the principle],),
    table.hline(),
    [Settles only on Bitcoin L1 --- no own chain, token, or
    consensus], [inherit the most decentralized base; build no new one],
    [Client-side validation; constant-size ZK proofs], [each participant
    verifies for themselves, trusting no one],
    [Spend key lives only in the wallet], [the participant alone holds
    custody],
    [Off-chain delivery over a node-as-relay mesh], [no central delivery
    service],
    [Recovery from seed + Bitcoin + the network], [no central backup
    custodian],
    [Capability-gated disclosure; self-hostable, verifiable
    explorer], [the owner alone decides who sees what; no trusted
    authority],
    [Any node --- switchable, several at once], [no lock-in to any
    operator],
    [Permissionless asset creation], [anyone can create their own asset;
    each asset\'s minter is its creator],
)

These are not features bolted on. They are the same principle, followed
to its conclusion.

== The triad it guarantees
<the-triad-it-guarantees>
- #strong[Bitcoin-anchored] --- settled on Bitcoin L1, exactly as it
  exists today.
- #strong[Shielded] --- amounts, sender, receiver, and the transaction
  graph are hidden, behind a global anonymity set.
- #strong[Trustless] --- correctness is enforced by cryptography and
  Bitcoin alone.

Each is rare on its own elsewhere; here they hold #strong[together] ---
see #link("/comparisons")[Comparisons].

== How the data moves
<how-the-data-moves>
#strong[What lives where.] Bitcoin holds only opaque markers; everything
that says #emph[which coin, how much, between whom] lives off-chain and
is encrypted to the recipient:

```
    BITCOIN L1 (Public)                  OFF-CHAIN (Private — wallet + node)
    ────────────────────                 ───────────────────────────────────

    ┌──────────────────┐                 ┌───────────────────────────────┐
    │ BatchInscription │  sign-to-       │  AccountState                 │
    │ ────────────     │  contract       │   balances · keys · counters  │
    │ publisher_pubkey │  binds          │   coin_history_root           │
    │ prev_root        │ ◀ H(AggProof)── ├───────────────────────────────┤
    │ new_root         │                 │  SpendRecord(s)               │
    │ bundle_locator   │ ◀── attests ─── │   per-spender, off-chain      │
    │ block_anchor     │                 │   recursive validity proofs   │
    │ signature        │                 ├───────────────────────────────┤
    └──────────────────┘                 │  AggregateBatchProof          │
            ▲   (231 bytes,              │   (publisher's recursive PCD) │
            │    CONSTANT per batch)     ├───────────────────────────────┤
            │ inscribed in a             │  BatchBundle ── relay mesh    │
            │ Taproot reveal-tx          │   (k=3 replicated)            │
            │ envelope                   ├───────────────────────────────┤
            │                            │  CoinProof bundle  ──▶ to B   │
            │                            │   (coin + proof + envelope)   │
            └────────────────────────────┴───────────────────────────────┘
```

#strong[A payment, end to end.] A pays B; both run their own
wallet+node; only Bitcoin is shared:

```
    Alice                 Nostr relay     Publisher       Bitcoin       Bob
      │                       │              │              │           │
      │ 1. build SpendRecord  │              │              │           │
      │    + recursive proof  │              │              │           │
      │                       │              │              │           │
      │ 2. publish encrypted CoinProof bundle (NIP-44 / NIP-59)         │
      ├──────────────────────▶│              │              │           │
      │                       │              │              │           │
      │ 3. hand SpendRecord to publisher (off-chain)                    │
      ├─────────────────────────────────────▶│              │           │
      │                       │              │              │           │
      │                       │              │ 4. aggregate │           │
      │                       │              │  many SpendRecords,      │
      │                       │              │  build AggregateBatchProof
      │                       │              │              │           │
      │                       │              │ 5. push BatchBundle      │
      │                       │              │  to k=3 replicas         │
      │                       │◀─────────────┤              │           │
      │                       │              │              │           │
      │                       │              │ 6. inscribe BatchInscription
      │                       │              │   (231 bytes, constant)  │
      │                       │              ├─────────────▶│           │
      │                       │              │              │           │
      │                       │  scanners fetch BatchBundle by locator, │
      │                       │  verify AggregateBatchProof, apply      │
      │                       │  prev_root → new_root to accumulator    │
      │                       │              │              │           │
      │                       │ 7. scan CoinProof candidates · match    │
      │                       │    detect_tag (1 Poseidon hash/evt)     │
      │                       ◀──────────────────────────────────────────
      │                       │              │              │           │
      │                       │ 8. gift-wrapped bundle blob             │
      │                       ├─────────────────────────────────────────▶
      │                       │              │              │           │
      │                       │            9. decrypt with K_tx         │
      │                       │              verify recursive proof     │
      │                       │              check nf non-member.       │
      │                       │              of accumulator at tip      │
      │                       │              │              │           │
      │                       │           10. credit coin (trustless)   │
      │                       │              │              │           │
      │11. encrypted ACK · A may now drop her retained copy             │
      ◀──────────────────────────────────────────────────────────────────
      │                       │              │              │           │
```

== Scope
<scope>
The specification covers every component that will exist: the
#strong[node] (validator · prover · relay · data store), the
#strong[wallet] (thin key-holder), and the #strong[explorer] (public and
authorised views) --- together with the cryptography that binds them.
For every key, hash, and identifier it states exactly #strong[how it is
derived]\; for every requirement, #strong[how it is met].

== The ten requirements
<the-ten-requirements>
The whole specification exists to satisfy these (in full on the
#link("/requirements")[Requirements] page):

+ Bitcoin L1 as the only base · 2. Private · 3. Trustless · 4.
  Client-side validation · 5. Custody only in the wallet · 6. Recovery ·
  \7. Self-hostable · 8. Multi-asset · 9. Selective disclosure · 10.
  Node portability.

== Contents
<contents>
#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([\#], [Section], [What it gives you],),
    table.hline(),
    [1], [#link(<1--foundations-normative>)[Foundations]], [The single
    source of truth: primitives, the full key hierarchy and exact
    derivations, every identifier, the data structures and the global
    nullifier accumulator],
    [2], [#link(<2--proofs--state-transitions>)[Proofs & State Transitions]], [The
    compliance predicate, recursion, and the mint / send / receive
    algorithms],
    [3], [#link(<3--on-chain-layer>)[On-chain Layer]], [The
    `BatchInscription` (constant 231 bytes per batch), publisher
    signing, the off-chain `BatchBundle` and its `AggregateBatchProof`,
    and the nullifier accumulator],
    [4], [#link(<4--transport--recovery>)[Transport & Recovery]], [Off-chain
    delivery, note discovery, seed recovery, data availability],
    [5], [#link(<5--access--explorer>)[Access & Explorer]], [Capability-gated
    pull, view grants, and the disclosure spectrum: per-transaction
    links, balance attestations, full-account views],
    [6], [#link(<6--system-architecture>)[System Architecture]], [Node,
    wallet, explorer; portability, multi-node, issuance, threat model],
    [---], [#link(<glossary>)[Glossary]], [Every term, identifier, and
    notation, alphabetical, one line each],
    [---], [#link(<test-vectors-conformance-harness>)[Test vectors]], [Worked-example
    values and a conformance harness for implementations],
)

New here? Read #strong[Foundations] first --- everything else builds on
it. Stuck on a term? Jump to the #strong[Glossary].

== Requirements traceability
<requirements-traceability>
Where each requirement is satisfied:

#table(
    columns: 2,
    align: (auto,auto,),
    table.header([Requirement], [Satisfied by],),
    table.hline(),
    [#strong[1 · Bitcoin-only base]], [§1 (no native token;
    secp256k1/BIP-340), §3 (a single constant-size `BatchInscription`
    inscribed per publisher batch; no chain/consensus change)],
    [#strong[2 · Private]], [§1.3 (per-coin encryption), §1.4 (opaque
    `BatchInscription` carries only roots, a publisher key, a locator
    hash, and a signature --- no individual nullifiers, amounts,
    parties, or per-spender keys on chain), §2 (ZK proof hides
    amounts/parties/graph)],
    [#strong[3 · Trustless]], [§2 (proof soundness ⇒ no forgery), §3
    (nullifier accumulator ⇒ no double-spend), §1.2 (no key a node holds
    can spend), §6 (threat model)],
    [#strong[4 · Client-side validation]], [§2 (receiver re-verifies the
    full recursive proof), §4 (receive flow)],
    [#strong[5 · Custody only in wallet]], [§1.2 (SPEND branch is
    wallet-only; hardened separation)],
    [#strong[6 · Recovery]], [§1.3 (seed-derived detection/scan keys),
    §4 (seed reconstruction, replication, data availability)],
    [#strong[7 · Self-hostable]], [§6 (node ships self-contained, no
    operator-specific dependencies), §4 (node-as-relay)],
    [#strong[8 · Multi-asset]], [§1.4 (`asset_id`), §1.5 (per-asset
    balances), §2 (per-asset conservation), §6 (issuance)],
    [#strong[9 · Explorer]], [§5 (capability-gated authorised view;
    per-coin view capability; verifiable confirmation links)],
    [#strong[10 · Node portability]], [§1.2 (everything derives from the
    seed ⇒ no node-specific state), §6 (switch / multi-node)],
)

== Conventions
<conventions>
Normative keywords (#strong[MUST], #strong[MUST NOT], #strong[SHOULD],
#strong[MAY]) follow RFC 2119. All notation, primitives, and
domain-separation tags are defined once in
#link(<1--foundations-normative>)[Foundations] and used unchanged
throughout; sizes, encodings, and input orderings are exact.

== 1 · Foundations (normative)
<1--foundations-normative>
#quote(block: true)[
#emph[In one sentence: every key, hash, identifier, and byte-level rule
the rest of the spec uses, defined exactly once here.]
]

This page is the #strong[single source of truth] for the zkCoins
specification. Every other spec page builds on the primitives, keys,
identifiers, and structures defined here. It is written against the
#strong[target design] (the #link("/requirements")[Requirements]), not
against any current implementation.

Normative keywords (#strong[MUST], #strong[MUST NOT], #strong[SHOULD],
#strong[MAY]) are used per RFC 2119.

=== 1.1 Cryptographic primitives
<11-cryptographic-primitives>
The protocol fixes one concrete instantiation. Where a choice was open,
the established, Bitcoin-consistent option is taken.

#table(
    columns: 2,
    align: (auto,auto,),
    table.header([Role], [Primitive],),
    table.hline(),
    [Signature curve & scheme], [#strong[secp256k1], #strong[BIP-340
    Schnorr] (x-only public keys, 32-byte)],
    [On-chain / signature hash], [#strong[SHA-256] (BIP-340 uses tagged
    SHA-256 internally)],
    [In-circuit hash], [#strong[Poseidon] over the proof field `𝔽`
    (Goldilocks, `p = 2^64 − 2^32 + 1`); reference instance: Plonky2
    `PoseidonGoldilocksConfig` --- state width 12, rate 8, capacity 4, 8
    full + 22 partial rounds, round constants and MDS as in
    `plonky2/src/hash/poseidon.rs`. Parameters and absorption MUST match
    this instance (§1.7)],
    [General hash (addresses, off-circuit ids)], [#strong[SHA-256]],
    [Recursive proof system], [A #strong[proof-carrying-data (PCD)]
    scheme via #strong[cyclic recursion]\; reference instantiation: a
    FRI-based recursive proof (Plonky-style) over Goldilocks with
    Poseidon],
    [Key derivation], [#strong[BIP-32] (secp256k1) for the key tree;
    #strong[HKDF-SHA256] for symmetric/derived secrets],
    [Transport encryption], [#strong[NIP-44 v2] (ECDH-secp256k1 →
    HKDF-SHA256 → ChaCha20 + HMAC-SHA256)],
    [Metadata privacy], [#strong[NIP-59] gift-wrap],
    [Text encoding], [#strong[Bech32m] for the address (HRP `zk`);
    transport identifiers as `bech32m` with role HRPs],
)

Notation:

- `H(x)` --- SHA-256 of byte string `x`.
- `Hc(tag, a, b, …)` --- Poseidon over `𝔽`, #strong[domain-separated] by
  `tag`, applied to the field-encoded inputs.
- `P = k·G` --- secp256k1 scalar multiplication; `G` the generator.
- `ECDH(k, P) = x(k·P)` --- the x-coordinate of the shared point.
- `a ‖ b` --- byte concatenation.
- #strong[Secret vs. public.] A lowercase key name (`skᵢ`, `ivk`, `ovk`,
  `op`, `nk`) denotes the #strong[secret scalar]\; its public point is
  written `<name>·G` or a named pubkey (e.g. `Pkᵢ = skᵢ·G`,
  `IVPK = ivk·G`, `op_pubkey = op·G`). BIP-340 public keys are
  #strong[x-only] (32 bytes).

#strong[Domain separation.] Every `Hc`, `HKDF`, and `H` call that takes
a literal context string #strong[MUST] use the prefix form
`"zkCoins/v1/<context>"`. The contexts reserved by this spec are:

- #strong[Identifiers and per-coin derivations] --- `AssetId`, `Coin`,
  `AccountState`, `Nullifier`, `NoteKey`, `DetectKey`, `DetectTag`.
- #strong[Per-transition Merkle roots] --- `CoinsRoot`,
  `CoinsRoot/Leaf`, `CoinsRoot/Node`, `NullifiersRoot`,
  `NullifiersRoot/Leaf`, `NullifiersRoot/Node`.
- #strong[Sparse Merkle accumulators] --- `NfAcc/Leaf`, `NfAcc/Node`
  (global nullifier accumulator, §1.7.6); `CoinHist/Leaf`,
  `CoinHist/Node` (per-account coin-history SMT, §1.7.6).
- #strong[On-chain / off-chain protocol messages] --- `Grant`,
  `Invoice`, `PullChallenge`, `PullHost` (channel binding,
  #link(<51-capability-gated-pull>)[Access & Explorer §5.1]),
  `IssuanceTerms`, `HalfAgg`, `BalanceProof`, `Ack` (delivery
  acknowledgement, §4.2).

Reusing a context for two purposes is forbidden. Where a later section
writes shorthand such as `Hc("Coin", …)` or `H("Invoice" ‖ …)`, this is
equivalent to the full prefixed form `Hc("zkCoins/v1/Coin", …)` /
`H("zkCoins/v1/Invoice" ‖ …)`\; #strong[implementations MUST use the
full prefixed string], the shorthand is a notation convenience. The
address derivation `address = H(Pk₀)`
(#link(<14-identifiers-and-hashes>)[§1.4]) is the one identifier with no
context prefix --- by design, since `Pk₀` itself is its input and the
value is already SHA-256-collision-bound.

=== 1.2 Key hierarchy
<12-key-hierarchy>
All key material descends deterministically from a single 256-bit
#strong[seed]. The seed is the only thing a user backs up
(#link("/requirements")[Requirement 6]).

```
seed  (256-bit; BIP-39 mnemonic, or Passkey PRF → HKDF)
  └─ BIP-32 ─▶ m  (master)
        └─ m / 1798' / account'                              = A   (per-account root; 1798' = zkCoins purpose)
              ├─ A / 0'        = SPEND branch   (wallet only)
              │     ├─ A/0'/0'            = sk₀   → Pk₀   (initial signing key; fixes the address)
              │     ├─ A/0'/i'            = skᵢ   → Pkᵢ   (rotating per-transition signing key)
              │     └─ A/0'/n'            = nk            (account-level nullifier key)
              ├─ A / 1'        = VIEW branch    (delegable to a node)
              │     ├─ A/1'/0'            = ivk           (incoming viewing key)
              │     └─ A/1'/1'            = ovk           (outgoing viewing key)
              └─ A / 2'        = op            (operational / Nostr identity key)
```

`1798'` is the chosen BIP-43 purpose index for zkCoins (hardened). All
branch separations are #strong[hardened]: the VIEW and `op` branches are
hardened children of `A`, so a party holding them #strong[cannot] derive
the SPEND branch.

#strong[Who holds what] (this table is the cryptographic basis of the
#link("/architecture/trust-model")[Trust Model]):

#table(
    columns: 4,
    align: (auto,auto,auto,auto,),
    table.header([Key], [Held by], [Can do], [Cannot do],),
    table.hline(),
    [`skᵢ`, `nk` (SPEND branch)], [wallet only], [authorise spends,
    compute nullifiers], [---],
    [`ivk`], [wallet, and any node the wallet delegates to], [detect &
    decrypt #strong[incoming] coins], [spend],
    [`ovk`], [same], [recover #strong[outgoing] coin
    plaintext], [spend],
    [`op`], [the node], [publish/receive on Nostr, sign view grants &
    acknowledgements], [spend, decrypt others\' coins],
    [`K_tx` (per-coin note key, §1.3)], [derived per coin;
    shareable], [decrypt #strong[exactly one] coin], [spend, see any
    other coin],
)

The #strong[operational bundle] `{ivk, ovk, op}` is what a wallet
entrusts to a node so the node can receive and serve on its behalf 24/7.
None of it can spend. A #emph[foreign] node never receives these
directly; the wallet instead issues that node a scoped, `op`-signed
#strong[view grant] (§ Access model).

#strong[Spend-key model (account-level).] The keys `skᵢ` are rotating
#strong[per-transition] signing keys --- there is #strong[no] per-coin
signing key. Transition `i` (where `i = send_counter` at entry) is
authorised by `skᵢ`, whose public key `Pkᵢ` is the account\'s
`current_pubkey` and is carried in that transition\'s `SpendRecord`
(§1.4) --- the SpendRecord is handed to a publisher off-chain, so `Pkᵢ`
never appears on Bitcoin directly; it is verified in-circuit by the
publisher\'s `AggregateBatchProof` (#link(<22-proof-types>)[§2.2]). The
transition rotates `current_pubkey` to `Pk_{i+1}`. `Pk₀` fixes the
address. `nk` is account-level. Coin ownership is by the account (a
coin\'s `recipient = address`); a receiver therefore never needs a
per-coin key.

#strong[Accounts and addresses are one-to-one.] An account `A` has
#strong[exactly one] address, `address = H(Pk₀)` (§1.4). The protocol
defines #strong[no] diversified addresses, sub-addresses, or change
addresses: there is no way to derive a second, separately-disclosable or
separately-unlinkable receiving address under the same account. The
#strong[account is therefore the sole unit] of every isolation boundary
in the system --- privacy domain, selective disclosure
(#link(<5--access--explorer>)[Access & Explorer]), recovery
(#link(<4--transport--recovery>)[Transport & Recovery]), and node
portability (#link("/requirements")[Requirement 10]). A wallet derives
further accounts at `m/1798'/account'`\; it #strong[MUST NOT] present
multiple receiving addresses within one account. Consequences a wallet
#strong[MUST] surface to the user:

- To keep two activities unlinkable toward the counterparties they are
  shared with, or to disclose one independently of the other
  (#link(<58-address-view-full-history>)[Access & Explorer §5.8]), each
  #strong[MUST] live in its #strong[own account], chosen deliberately
  --- never as an implicit sub-address of a shared account.
- Each additional account is an independent scan and recovery scope (its
  own `ivk` / `detect_tag` lineage) and adds backup and scanning cost.
  This cost is the deliberate, accepted price of compartmentalisation;
  it is the reason the default is #strong[one account reused], not many
  accounts.
- Reusing one address toward many counterparties reveals nothing
  on-chain --- #link("/requirements")[Requirement 2] is unaffected ---
  but lets those counterparties correlate one another #strong[off-chain]
  through the shared address string. Per-relationship unlinkability
  therefore requires per-relationship accounts, never extra addresses on
  one account.

=== 1.3 Per-coin keys (note encryption & detection)
<13-per-coin-keys-note-encryption--detection>
Each output coin carries an ephemeral key and is individually encrypted,
so that a single per-coin capability discloses one coin and nothing
else.

```
Per output coin:
  esk           = random scalar                          (sender, fresh per coin)
  epk           = esk·G                                   (published with the coin)
  IVPK          = ivk·G                                   (recipient incoming-view pubkey)
  ss            = ECDH(esk, IVPK)  = ECDH(ivk, epk)       (shared secret; both sides derive it)
  K_tx          = HKDF("zkCoins/v1/NoteKey",  ss ‖ epk)   (per-coin symmetric note key)
  detect_tag    = Hc("zkCoins/v1/DetectTag",  dk ‖ epk)   (per-coin detection tag)
      where dk  = HKDF("zkCoins/v1/DetectKey", ivk)       (detection key, from ivk)
```

- The coin plaintext is encrypted under `K_tx` (NIP-44 v2). Only a
  holder of `ivk` (the recipient, or its node) can re-derive `K_tx` and
  decrypt.
- `detect_tag` lets a recipient/node find its own coins #strong[without
  trial-decrypting every event]. Holding `ivk` (hence `dk`), the
  recipient recomputes `Hc("zkCoins/v1/DetectTag", dk ‖ event.epk)` per
  candidate event and matches against the published `detect_tag` --- one
  cheap Poseidon hash per scanned event, in place of one AEAD attempt.
  Because every coin uses a fresh `epk`, each recipient\'s events carry
  #strong[all-distinct] tags: a tag does #strong[not] link two of one
  recipient\'s coins, and a relay that lacks `dk` can #strong[neither]
  pre-filter for the recipient #strong[nor] correlate the recipient\'s
  events. Detection is therefore cheap on the CPU but does not reduce
  the #emph[count] of candidates the recipient pulls. `dk` itself is
  #strong[seed-derivable], so detection doubles as the recovery scan key
  (#link("/requirements")[Requirement 6]).
- #strong[Fuzzy message detection (OPTIONAL).] A relay-side
  probabilistic pre-filter (tunable false-positive rate) reduces the
  candidate count the recipient downloads, at no linkability cost. It
  changes only the tag computation, leaves every other interface
  unchanged, and is a #strong[scan-efficiency upgrade] --- not a fix for
  a linkability the deterministic scheme does not have.
- The #strong[per-coin view capability] placed in an explorer link (§
  Explorer) is `K_tx` for that one coin. It decrypts that coin only.

=== 1.4 Identifiers and hashes
<14-identifiers-and-hashes>
Exact derivations. Every value here is reproducible from its inputs.

#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([Identifier], [Definition], [Size / type],),
    table.hline(),
    [#strong[Address]], [`address = H(Pk₀)` --- SHA-256 of the
    #strong[initial] spend public key; fixed at account creation; the
    protocol\'s only identity], [32 bytes (Bech32m, HRP `zk`)],
    [#strong[AssetId]], [`asset_id = Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version)`
    at asset creation, where `creator_pubkey ≜ Pk₀` of the issuing
    account (its initial spend public key --- the same key that fixes
    the account `address`), `name_hash = H(name)`, `genesis_tag` is the
    fixed constant ASCII string `zkCoins/v1/genesis`, and
    `issuance_version` is the #strong[issuance-schema version] the asset
    is created under (a `u8`\; currently `1`, see
    #link(<65-issuance--versioned-schemas-v1-minimal>)[Architecture §6.5]).
    The human-readable `name` is #strong[never] on-chain. Every input is
    derived from stated values, so `asset_id` is fully
    reproducible], [256-bit digest (32-byte canonical)],
    [#strong[Coin
    identifier]], [`coin.identifier = Hc("Coin", prev_account_state_hash ‖ asset_id ‖ coin_index)`.
    The `prev_account_state_hash` is the `ash` of the #strong[prior]
    account state --- the state #emph[before] the transition that
    creates the coin --- so the identifier is a well-defined function of
    inputs known at creation time and is #strong[not] recursively
    dependent on the transition\'s own `new_account_state_hash` (which
    itself folds in `coin_history_root`, §1.7.4--§1.7.6). A coin\'s
    identifier is fixed at creation and recomputed with that same
    `prev_ash` when later spent.], [256-bit digest (32-byte canonical)],
    [#strong[account\_state\_hash]
    (`ash`)], [`ash = Hc("AccountState", serialize(AccountState))`], [32-byte
    canonical],
    [#strong[output\_coins\_root] (`ocr`)], [Poseidon Merkle root over
    the transaction\'s output `coin.identifier`s, tag
    `CoinsRoot`], [32-byte canonical],
    [#strong[input\_nullifiers\_root] (`inr`)], [Poseidon Merkle root
    over the transition\'s spent `nf`s, tag `NullifiersRoot`], [32-byte
    canonical],
    [#strong[SpendRecord message]], [`message = inr ‖ ocr` --- binds the
    spent nullifier set and the produced output coins], [64 bytes],
    [#strong[SpendRecord]], [`{ public_key: Pkᵢ (32B x-only), signature: BIP-340(skᵢ, message) (64B), message: inr ‖ ocr (64B), k: u8 (1B, the count of input nullifiers), nullifiers: [nf]ⱼ (32B each — the coins spent in this transition; exactly `k` entries) }`
    --- an #strong[off-chain] object: a spender produces one per
    transition and hands it to a publisher. The publisher aggregates
    many `SpendRecord`s into one `BatchBundle`
    (#link(<46-data-availability--replication-factor-k>)[§4.6]), builds
    the `AggregateBatchProof` over them, and anchors the batch with one
    constant-size `BatchInscription` on Bitcoin
    (#link(<31-the-on-chain-object>)[§3.1]). A mint, which spends no
    coin, has `k = 0` and need not be batched at all --- its receiver
    verifies it directly against its `CoinProof` bundle], [161 + 32·|nf|
    bytes off-chain],
    [#strong[Nullifier]], [`nf = Hc("Nullifier", nk ‖ coin.identifier)`
    --- derived in-circuit by the spender; included in the `SpendRecord`
    handed to the publisher and folded into the global nullifier
    accumulator (§1.6) when the batch\'s `BatchInscription` is admitted;
    unlinkable to the coin without `nk`], [256-bit digest (32-byte
    canonical)],
    [#strong[ProofData] (public
    inputs)], [`{ new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root }`
    --- there is #strong[no] accumulator root here: a spender\'s
    per-account proof attests local soundness; global double-spend is
    enforced by the publisher\'s `AggregateBatchProof`
    (#link(<22-proof-types>)[§2.2]) when it inserts the batch\'s
    nullifiers into the on-chain-committed accumulator], [hashes/roots
    only],
    [#strong[BatchInscription]], [`{ publisher_pubkey: Pkₚ, prev_root, new_root, bundle_locator, block_anchor, signature }`
    --- the #strong[only] object written to Bitcoin; 231 bytes per
    batch, constant in batch size; commits the publisher\'s accumulator
    state transition `prev_root → new_root` and addresses the off-chain
    bundle by
    `bundle_locator = Hc("BatchBundle", serialize(BatchBundle))`
    (#link(<31-the-on-chain-object>)[§3.1],
    #link(<35-inscription-format>)[§3.5])], [231 bytes per batch],
    [#strong[BatchBundle]], [`{ prev_root, new_root, spend_records: [SpendRecord], aggregate_proof: AggregateBatchProof, nullifiers: [nf] (derived view) }`
    --- off-chain, content-addressed, `k = 3` replicated by the same DA
    discipline as `CoinProof` bundles
    (#link(<46-data-availability--replication-factor-k>)[§4.6]). Carries
    every member `SpendRecord` plus the recursive proof that attests the
    whole batch. The top-level `nullifiers` field is a #strong[derived
    view] equal to the canonical multi-set concatenation of every member
    `SpendRecord`\'s `nullifiers` in canonical bundle order --- provided
    as a convenience for scanners that want the flat `nf` list without
    re-parsing every record. #strong[Canonical serialisation]
    `serialize(BatchBundle)` (the preimage of
    `bundle_locator = Hc("BatchBundle", …)`,
    #link(<35-inscription-format>)[§3.5],
    #link(<22-proof-types>)[§2.2 clause 6]) is
    `prev_root ‖ new_root ‖ u32-be(m) ‖ SpendRecord₁ ‖ … ‖ SpendRecord_m`
    --- the derived `nullifiers` field and the `aggregate_proof` are
    #strong[excluded] from this preimage (the former because it is
    redundant under §2.2 clauses 3--4; the latter because a proof cannot
    commit to its own bytes, so it is bound separately by the
    publisher\'s sign-to-contract tweak,
    #link(<32-batchinscription-signing-bip-340--sign-to-contract>)[§3.2])], [grows
    with member count + recursive-proof size (typically \~100 KB)],
)

The per-spender BIP-340 signature over `message` additionally uses
#strong[sign-to-contract]: it embeds the digest of that spender\'s
off-chain validity proof (`H(ProofData)`) in the nonce, binding the
proof to the spender\'s `SpendRecord` for in-circuit verification by the
publisher\'s `AggregateBatchProof` (see
#link(<33-off-chain-signature-handling>)[On-chain §3.3]). The
publisher\'s separate signature on the `BatchInscription` (see
#link(<32-batchinscription-signing-bip-340--sign-to-contract>)[On-chain §3.2])
is similarly sign-to-contract-bound to the off-chain
`AggregateBatchProof`.

=== 1.5 Core data structures
<15-core-data-structures>
```
AccountState = {
  owner             : address,                 // fixed identity
  balances          : map<asset_id, amount>,   // private bookkeeping, multi-asset
  current_pubkey    : Pkᵢ,                      // rotates each send
  send_counter      : i,                        // monotonic
  coin_history_root : root                      // Poseidon SMT root over the account's coin history (§1.6)
}

Coin         = { identifier, recipient: address, amount, asset_id }
CoinTemplate = { recipient: address, amount, asset_id }

CoinProof    = {                            // the value-bearing off-chain bundle (bearer)
  coin,                                      // plaintext coin
  proof,                                     // recursive validity proof
  inclusion_proof,                           // membership of coin in output_coins_root
  creating_prev_ash,                         // PRIOR account_state_hash of the transition that
                                             // created this coin; needed by the spender to
                                             // recompute coin.identifier in-circuit (§1.4, §2.1)
  epk, ciphertext, detect_tag                // encryption envelope (§1.3)
}

Invoice      = { amount, recipient: address, asset_id, memo? }     // shareable, off-chain
```

=== 1.6 Trees: one global structure, one per-account structure
<16-trees-one-global-structure-one-per-account-structure>
#table(
    columns: 4,
    align: (auto,auto,auto,auto,),
    table.header([Structure], [Scope], [Contents], [Built from],),
    table.hline(),
    [#strong[Coin-history SMT]], [per account], [coins the account has
    received/spent (for in-circuit non-inclusion)], [the account\'s own
    coins; root folded into `ash` lineage (Private)],
    [#strong[Nullifier accumulator]], [global], [every admitted `nf`
    (256-bit-depth SMT, supports membership + non-membership)], [the
    `nf`s carried in every admitted `BatchBundle`, whose
    `prev_root → new_root` transitions are anchored by
    `BatchInscription`s on Bitcoin
    (#link(<37-the-nullifier-accumulator>)[§3.7])],
)

There is #strong[exactly one] global structure --- the nullifier
accumulator --- and Bitcoin is the only ordering surface the protocol
relies on. zkCoins defines #strong[no] global, account-keyed commitment
tree: an account\'s latest state is carried by its own constant-size
recursive proof (#link(<22-proof-types>)[Proofs §2.2]), never by a
global per-account on-chain index. This is deliberate. A global
structure keyed by a stable account identifier would have to be
#strong[either] rebuildable from publicly verifiable data #strong[or]
privacy-preserving --- never both. The protocol keeps privacy
(#link("/requirements")[Requirement 2]) and rebuildability
(#link("/requirements")[Requirement 10]) at once by removing that
structure entirely and anchoring double-spend protection in the
#strong[nullifier accumulator] alone.

The accumulator\'s #strong[state transitions] are anchored on Bitcoin
(each `BatchInscription` commits `prev_root → new_root`) and its
#strong[per-transition validity] is attested by the publisher\'s
`AggregateBatchProof` carried in the off-chain `BatchBundle`
(#link(<37-the-nullifier-accumulator>)[§3.7]). Any node therefore tracks
the accumulator by following the chain of inscribed roots and verifying
each batch\'s recursive proof against its content-addressed bundle --- a
pure function of confirmed Bitcoin data plus publicly verifiable,
`k = 3`-replicated bundles
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]),
identical for every honest node, requiring #strong[no] trust in any
peer. The per-account coin-history SMT is Private (its leaves are the
account\'s own coins) and never leaves the account\'s own proving
context; only its root appears, hashed, inside `ash`.

=== 1.7 Encoding, serialization, and the reference instantiation
<17-encoding-serialization-and-the-reference-instantiation>
Every value defined in §1.4 is reproducible bit-for-bit when the rules
below are followed. They pin one concrete, implementable convention for
every otherwise-ambiguous detail (sponge layout, byte→field packing,
`serialize`, Merkle and SMT constructions). They are #strong[normative
for protocol version v1] --- a conforming implementation #strong[MUST]
match them bit-for-bit --- #strong[and] the explicit #strong[reference
instantiation pending cryptographic review] before any mainnet
deployment.

==== 1.7.1 Poseidon instance and digest encoding
<171-poseidon-instance-and-digest-encoding>
The reference Poseidon instance is #strong[Plonky2\'s
`PoseidonGoldilocksConfig`] (state width 12, rate `r = 8`, capacity
`c = 4`\; 8 full + 22 partial rounds; round constants and MDS as in
`plonky2/src/hash/poseidon.rs`). All in-circuit Poseidon operations and
every use of `Hc` MUST use exactly this instance. `Hc(tag, x₁, …, xₙ)`
is computed as

```
Hc(tag, x₁, …, xₙ) := PoseidonSponge( E(tag) ‖ E(x₁) ‖ … ‖ E(xₙ) )
```

where `E(·)` is the field-encoding of §1.7.2, the concatenated sequence
of field elements is absorbed by the Plonky2 rate-8/capacity-4 sponge in
its standard `hash_n_to_hash` layout, and the result is the first 4
squeezed rate elements.

A #strong[Poseidon digest] is those 4 field elements, canonically
encoded as #strong[32 bytes]: each element is reduced mod `p` and
emitted as #strong[8 bytes big-endian], in order. Each digest element is
`< p ≤ 2^64`, so 8 bytes always suffice. SHA-256 outputs are 32 bytes
as-is.

A single 64-bit Goldilocks element #strong[MUST NOT] be used as a
nullifier, identifier, or root: 64-bit collision resistance is
insufficient.

==== 1.7.2 Field-encoding `E(·)` of `Hc` inputs
<172-field-encoding-e-of-hc-inputs>
Each input has a categorical type and is encoded as a fixed sequence of
field elements; concatenation of those sequences is what the sponge
absorbs.

- #strong[Tag.] The literal byte string `"zkCoins/v1/<context>"` (UTF-8,
  ASCII-only by construction) is encoded by the byte-string rule below.
  Distinct tags therefore prefix the absorption with distinct element
  sequences and provide the required domain separation.

- #strong[Byte-string input] (raw bytes, SHA-256 hash, secp256k1 x-only
  pubkey, secp256k1 scalar, an asset\'s `name`, a `serialize(...)`
  output, NIP-44 ciphertext, etc.): encode as

  - #strong[one length element] holding the byte length `L` as an
    unsigned integer (`L < 2^56`); then
  - the bytes packed into #strong[7-byte big-endian chunks], each
    interpreted as a 56-bit unsigned integer and emitted as one field
    element; the final chunk is right-padded with zero bytes to 7 bytes.

  Total elements: `1 + ⌈L / 7⌉`. Every chunk is `< 2^56 < p`, so every
  emitted element is a valid reduced Goldilocks element.

- #strong[Digest input] (any 256-bit value already produced by `Hc`):
  encode as its #strong[4 field elements], in order, with #strong[no]
  length prefix --- its width is fixed by type.

- #strong[Small numeric input] (a declared-width unsigned integer of
  `≤ 56` bits): encode as #strong[one field element] equal to the
  unsigned value. Because the value is `< 2^56 < p`, the element is
  canonical with no `mod p` ambiguity.

- #strong[Wide numeric input] (`u64`, `u128`): encode as the value\'s
  fixed-width #strong[big-endian byte representation] (8 bytes for
  `u64`, 16 bytes for `u128`) absorbed via the #strong[byte-string] rule
  above. This avoids the mod-`p` collision that a 64-bit numeric element
  would have (`p ≈ 2^64 − 2^32`, so distinct `u64` values can reduce to
  the same field element).

The same `x` always produces the same `E(x)`, regardless of which call
uses it. Combined with the #strong[per-tag fixed input schema] (the
§1.7.3 widths together with the input list written at every `Hc` call
site), no two distinct `Hc` invocations produce the same element
sequence: per-input length prefixes on byte strings, fixed widths on
digests and small numerics, and the prefix-tag domain together fix an
unambiguous absorption per tag.

==== 1.7.3 Fixed widths
<173-fixed-widths>
#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([Field], [Width (bits)], [Notes],),
    table.hline(),
    [`amount`], [128 (u128)], [Encoded as #strong[16-byte big-endian]
    byte-string input per §1.7.2 (1 length element + 3 limbs of 7 bytes
    \= 4 absorbed elements); same 16 bytes big-endian in `serialize`.
    Range-checked in-circuit to `[0, 2^128 − 1]`],
    [`decimals`], [8 (u8)], [One small-numeric element (value `< 2^8`,
    trivially `< p`)],
    [`issuance_version`], [8 (u8)], [One small-numeric element; bound
    into `asset_id` (§1.4) and `IssuanceTerms.terms_hash`
    (#link(<65-issuance--versioned-schemas-v1-minimal>)[Architecture §6.5])],
    [`coin_index`], [32 (u32)], [One small-numeric element],
    [`send_counter`], [64 (u64)], [Encoded as #strong[8-byte big-endian]
    byte-string input per §1.7.2 (1 length element + 2 limbs of 7 bytes
    \= 3 absorbed elements); same 8 bytes big-endian in `serialize`],
    [`block_anchor.height`], [32 (u32)], [One small-numeric element; 4
    bytes big-endian on-chain (§3.5)],
    [`name_hash`, `address`, `nk`, `epk`, `Pkᵢ`], [256], [Byte-string
    input, encoded per §1.7.2 (length prefix + 5 chunks)],
    [`Hc` digest (`asset_id`, `coin.identifier`, `nf`, `ash`, `ocr`,
    `inr`, any root)], [256 (4 limbs)], [Digest input, encoded per
    §1.7.2],
)

`amount` MUST be range-checked in-circuit to `[0, 2^128 − 1]` so balance
arithmetic never wraps the field; an out-of-range amount invalidates the
proof.

==== 1.7.4 `serialize(AccountState)`
<174-serializeaccountstate>
`AccountState` (§1.5) is canonically serialized as a fixed-format byte
string before being absorbed into
`ash = Hc("AccountState", serialize(AccountState))`:

```
serialize(AccountState) :=
   owner                       (32 bytes — the address)
‖ current_pubkey               (32 bytes — Pkᵢ, x-only)
‖ send_counter                 ( 8 bytes — u64 big-endian)
‖ coin_history_root            (32 bytes — Poseidon digest, §1.6)
‖ balances_count               ( 4 bytes — u32 big-endian, the number of non-zero entries)
‖ for each (asset_id, amount) in balances, sorted ASCENDING by asset_id (byte order):
     asset_id                  (32 bytes)
     amount                    (16 bytes — u128 big-endian)
```

Entries with `amount == 0` MUST be omitted; duplicate `asset_id`s MUST
NOT appear; the ascending sort is total over the 32-byte canonical
encoding. This fixes a canonical preimage for `ash`. (`balances` and
`coin_history_root` are the §1.5 fields; the byte string is then
absorbed by `Hc` as one byte-string input per §1.7.2.)

==== 1.7.5 Poseidon Merkle tree (used for `ocr` and `inr`)
<175-poseidon-merkle-tree-used-for-ocr-and-inr>
A Poseidon Merkle root with tag `T ∈ { "CoinsRoot", "NullifiersRoot" }`
over a list `L = (v₁, …, vₘ)` of 256-bit digest values is computed as:

+ #strong[Leaf hash.] `Lᵢ = Hc("<T>/Leaf", vᵢ)` for each `i` (each `vᵢ`
  is a digest input, so its 4 elements are absorbed directly).
+ #strong[Pad.] Extend `L` with the #strong[empty-leaf hash]
  `L_⊥ = Hc("<T>/Leaf", 0₂₅₆)` (the digest of the all-zero 256-bit
  value) until the list length is a power of two (at least 1). An empty
  list (`m = 0`) has root `L_⊥`.
+ #strong[Combine.] For each adjacent pair `(L₂ⱼ₋₁, L₂ⱼ)`, compute
  `Pⱼ = Hc("<T>/Node", L₂ⱼ₋₁, L₂ⱼ)`. Repeat the pairwise combination on
  the resulting list until one element remains: that is the
  #strong[root].

A membership proof is the standard sibling path against this
construction; verifiers re-derive the root and reject on mismatch. The
distinct `<T>/Leaf` and `<T>/Node` domain tags prevent second-preimage
collisions across levels.

==== 1.7.6 Nullifier accumulator (sparse Merkle tree)
<176-nullifier-accumulator-sparse-merkle-tree>
The global nullifier accumulator (§1.6,
#link(<37-the-nullifier-accumulator>)[On-chain §3.7]) is a
#strong[256-bit-depth sparse Merkle tree] keyed by `nf` (each `nf` is a
256-bit Poseidon digest, used as the bit-string `nf₂₅₅ nf₂₅₄ … nf₀` to
walk the tree from root to leaf). Each leaf holds either the
#strong[present marker] `1` (key in the set) or the #strong[empty
marker] `0`. Hashes:

- #strong[Leaf:] `H_leaf(b) = Hc("NfAcc/Leaf", b)` with `b ∈ {0, 1}`
  encoded as one numeric element (per §1.7.2).
- #strong[Internal node at level `i`] (level 0 = leaf, level 256 =
  root): `H_node(i, l, r) = Hc("NfAcc/Node", i, l, r)`, where the level
  index is one numeric element and `l, r` are digest inputs.
- #strong[Empty subtree at level `i`] has the precomputed hash `Eᵢ`
  defined recursively by `E₀ = H_leaf(0)` and
  `Eᵢ = H_node(i, E_{i-1}, E_{i-1})`. The 257 values `E₀, …, E₂₅₆` are
  constants of the protocol and MUST be precomputed identically by every
  implementation; `E₂₅₆` is the #strong[empty-tree root].

Insertion of `nf` flips the leaf at key `nf` from `0` to `1` and
recomputes the path of 256 internal hashes. Non-membership of `nf` at a
stated tip is a path showing `H_leaf(0)` at key `nf`\; membership is the
analogous path with `H_leaf(1)`. Implementations MAY store only the
populated subtrees (since empty subtrees collapse to their precomputed
`Eᵢ`), but MUST NOT prune populated paths (see
#link(<37-the-nullifier-accumulator>)[On-chain §3.7]).

#strong[Coin-history SMT (per account).] The per-account coin-history
(§1.5, §1.6) is a structurally identical #strong[256-bit-depth sparse
Merkle tree] with its own distinct domain tags. It is Private --- its
leaves are the account\'s own coins --- and is used in-circuit by the
compliance predicate (#link(<21-the-compliance-predicate>)[Proofs §2.1]
clause 2(b) and clause 8); only its 32-byte `coin_history_root` ever
leaves the proving context, hashed inside `ash`.

- #strong[Key:] the coin\'s `coin.identifier` (a 256-bit Poseidon
  digest, §1.4), used as the bit-string `id₂₅₅ id₂₅₄ … id₀` to walk root
  → leaf.
- #strong[Leaf state] `s ∈ {0, 1, 2}`: `0` = the account has never
  received this coin (key is absent); `1` = received-and-unspent (the
  coin is in the account\'s holdings); `2` = spent (the coin was
  received and has since been nullified by this account). Encoded as one
  numeric element.
- #strong[Leaf:] `H'_leaf(s) = Hc("CoinHist/Leaf", s)`.
- #strong[Internal node at level `i`] (level 0 = leaf, level 256 =
  root): `H'_node(i, l, r) = Hc("CoinHist/Node", i, l, r)`, level index
  as one numeric element and `l, r` as digest inputs.
- #strong[Empty subtree at level `i`] has the precomputed hash `E'ᵢ`
  defined recursively by `E'₀ = H'_leaf(0)` and
  `E'ᵢ = H'_node(i, E'_{i-1}, E'_{i-1})`. The 257 values `E'₀, …, E'₂₅₆`
  are constants of the protocol; `E'₂₅₆` is the #strong[empty
  coin-history root] (the `coin_history_root` of the canonical empty
  account, §2.2).

#strong[Operations.] A transition that spends `input_coins[j]` proves
in-circuit that `coin.identifier = input_coins[j].identifier` has leaf
state `1` against the prior `coin_history_root` (clause 2(b)); the same
transition flips that leaf from `1` to `2` (spent) and admits each newly
received output template by flipping its key from `0` to `1`
(received-unspent). `coin_history_root` after the transition is the
recomputed root over these updates and is the value bound into the new
`AccountState` (clause 8, §1.7.4). The distinct `CoinHist/Leaf` and
`CoinHist/Node` tags --- and the per-level domain separation in
`H'_node` --- make these constants distinct from the nullifier
accumulator\'s `E_i` even though the SMT skeleton is the same.

==== 1.7.7 Bech32m and Bitcoin conventions
<177-bech32m-and-bitcoin-conventions>
- Addresses, view grants, and bearer view capabilities use Bech32m with
  distinct HRPs so they are never confused: `zk` (address, 32-byte
  payload), `zkgrant` (view grant, full `ViewGrant` byte serialization),
  `zkview` (per-coin view capability, 32-byte payload), `zkavk` (bearer
  account view key, 64-byte `ivk ‖ ovk` payload; see
  #link(<58-address-view-full-history>)[Access & Explorer §5.8]),
  `zkbid` (confirmation-link bundle locator, 32-byte
  `blob_id = H(ciphertext)`\; see
  #link(<56-shareable-confirmation-links>)[Access & Explorer §5.6]). A
  node/explorer #strong[MUST] reject a value presented under the wrong
  HRP.
- Bitcoin txids are stored internal-order and #strong[displayed]
  byte-reversed (canonical Bitcoin convention).
- All multi-input hashes fix input order exactly as written in §1.4 and
  in this section; reordering changes the digest and is invalid.

==== 1.7.8 Reference-instantiation review status
<178-reference-instantiation-review-status>
This section pins one concrete, implementable convention for everything
otherwise underspecified at the cryptographic-engineering level. It is
normative for protocol version v1 --- a conforming implementation MUST
match it bit-for-bit --- and is explicitly the #strong[reference
instantiation pending cryptographic review] prior to any mainnet
deployment. Review may refine the Poseidon parameter choice, the
byte→field encoding, the sponge variant, the `serialize(AccountState)`
field ordering, and the in-circuit/out-of-circuit boundary. Any such
refinement is a version bump (the tag prefix `"zkCoins/v1/…"` reserves
the namespace).

== 2 · Proofs & State Transitions
<2--proofs--state-transitions>
#quote(block: true)[
#emph[In one sentence: what the zero-knowledge proof actually proves
about each transition (mint, send, receive), and how the sender, the
recipient, and the recursive proof plug together.]
]

This page defines the #strong[proof system] and the #strong[three state
transitions] (mint, send, receive) of zkCoins. It builds strictly on
#link(<1--foundations-normative>)[Foundations]: every key, identifier,
hash, tree, and structure is used exactly as defined there and never
redefined here. Normative keywords (#strong[MUST], #strong[MUST NOT],
#strong[SHOULD], #strong[MAY]) follow RFC 2119.

The proof system is a #strong[proof-carrying-data (PCD)] scheme realised
by #strong[cyclic recursion] (see
#link(<11-cryptographic-primitives>)[Foundations §1.1]): one circuit
verifies a proof of itself. Each transition consumes the account\'s
previous proof and emits a new one, so a coin that changed hands `N`
times carries a #strong[single constant-size proof], verified in
#strong[constant time], regardless of `N`.

=== 2.1 The compliance predicate
<21-the-compliance-predicate>
Every transition is a single execution of one circuit, `C`. The circuit
takes a #strong[private witness] `w` and a set of #strong[public inputs]
equal to `ProofData` (see
#link(<14-identifiers-and-hashes>)[Foundations §1.4]). A proof `π` is
accepted only if `C(ProofData, w) = 1`, i.e. #strong[all] of the
following clauses hold. The clauses are normative: a conforming prover
#strong[MUST] enforce every one, and a conforming verifier #strong[MUST]
reject any proof for which the public inputs are not bound exactly as
below.

Witness (private to the prover; never revealed):

```
w = {
  prev_proof,                 // the account's previous recursive proof (absent for InitialProof)
  prev_account_state,         // AccountState before this transition (Foundations §1.5)
  input_coins[],              // coins being spent (Foundations §1.5); empty for a pure mint
  input_auth[]   = {          // per input coin, membership evidence (NO per-coin key/signature)
    history_path,                                    // inclusion in prior coin-history SMT
    creating_prev_ash                                // the PRIOR account_state_hash of the transition that
                                                     // created this coin (delivered inside its CoinProof bundle);
                                                     // breaks the would-be coin.identifier ↔ new_ash recursion
  },
  txn_sig        = BIP-340(skᵢ, message),            // the account's single transition signature (SpendRecord)
  txn_pubkey     = Pkᵢ (x-only),                     // current_pubkey, authorises this whole transition
  output_templates[],         // CoinTemplate list (Foundations §1.5)
  nk,                         // nullifier key (SPEND branch, Foundations §1.2)
  next_pubkey   = Pkᵢ₊₁,      // rotated spend pubkey for the new state
  asset_issuance?             // present only for issuance: {asset_id, creator_pubkey = Pk₀, issuance_version, name_hash, amount, decimals}
}
```

#strong[Predicate `C` --- enumerated clauses.]

+ #strong[Recursive verification (PCD).] Either this is an
  `InitialProof` and `w.prev_proof` is absent and `w.prev_account_state`
  is the canonical empty account for `owner = H(Pk₀)`\; #strong[or]
  `w.prev_proof` verifies under the circuit\'s own verifier data (cyclic
  recursion), and its public output `new_account_state_hash` equals the
  `ash` of `w.prev_account_state`, and its `coin_history_root` equals
  the coin-history root over which clause 2 proves inclusion. The
  verifier data #strong[MUST] be fixed and identical in prover and
  verifier; a proof verified against any other verifier data is invalid.

  - #strong[No global lineage anchor.] An account\'s latest state is
    attested #strong[entirely] by its own constant-size recursive proof;
    the protocol defines no global, account-keyed commitment tree to
    bind to
    (#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]).
    Anchoring to Bitcoin comes instead via the #strong[publisher
    batching path]: a spend takes effect only once its `SpendRecord` is
    included in a `BatchBundle` whose `BatchInscription` is admitted
    on-chain (§2.3.3, #link(<36-chain-scanning>)[On-chain §3.6]), and
    equivocation between two forks of one account is caught because both
    forks reuse the same input-coin `nf`, which can enter the global
    nullifier accumulator only once --- the publisher\'s
    `AggregateBatchProof` (#link(<22-proof-types>)[§2.2]) attests
    `new_root` as the deterministic SMT-insertion result, so an `nf`
    already in the accumulator at `prev_root` would make the proof
    unsatisfiable.

+ #strong[Input authenticity.] The whole transition is authorised by the
  account\'s #strong[single transition signature] --- there is no
  per-coin key and no per-coin signature
  (#link(<12-key-hierarchy>)[Foundations §1.2]). The circuit
  #strong[MUST] check that `txn_sig` is a valid #strong[BIP-340]
  signature (see #link(<11-cryptographic-primitives>)[Foundations §1.1])
  over `message = inr ‖ ocr` (the `SpendRecord` message of
  #link(<14-identifiers-and-hashes>)[Foundations §1.4]:
  `input_nullifiers_root` from clause 4 ‖ `output_coins_root` from
  clause 6) by `txn_pubkey = Pkᵢ`, and that `Pkᵢ` is
  `prev_account_state.current_pubkey`. Then, for every `input_coins[j]`:
  a. `input_coins[j].recipient` equals `prev_account_state.owner`, i.e.
  the coin is owned by the spending account (`owner = address = H(Pk₀)`,
  #link(<14-identifiers-and-hashes>)[Foundations §1.4]) --- ownership is
  by the account, so a receiver never needs a per-coin key index; b.
  `input_coins[j]` is included in the prior #strong[coin-history SMT]
  (per-account,
  #link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6])
  via `input_auth[j].history_path` against the root referenced in clause
  1; c. `input_coins[j].identifier` is recomputed in-circuit as
  `Hc("Coin", input_auth[j].creating_prev_ash ‖ asset_id ‖ coin_index)`
  --- using the witnessed `creating_prev_ash` (the #strong[prior]
  `account_state_hash` of the transition that produced this coin, i.e.
  the `ash` of the creating account #emph[before] its creating
  transition, delivered to the spender inside the coin\'s `CoinProof`
  bundle) --- and #strong[MUST] match the supplied identifier. The
  per-input witness `input_auth[]` #strong[MUST] therefore include each
  input coin\'s `creating_prev_ash`. This matches
  #link(<14-identifiers-and-hashes>)[Foundations §1.4]: a coin\'s
  identifier binds the creating account\'s #strong[prior] state,
  breaking the would-be recursion between `coin.identifier` and
  `new_account_state_hash`.

+ #strong[Per-asset balance conservation.] Let
  `In(a) = Σ { input_coins[j].amount : input_coins[j].asset_id = a }`
  and
  `Out(a) = Σ { output_templates[k].amount : output_templates[k].asset_id = a }`,
  plus `Mint(a)` from any `asset_issuance` for asset `a` (zero
  otherwise). For #strong[every] `asset_id` `a` appearing in inputs or
  outputs: `In(a) + Mint(a) ≥ Out(a)`. All amounts are range-checked to
  a fixed non-negative integer width so no sum can wrap the field; any
  amount outside range invalidates the proof. The difference
  `In(a) + Mint(a) − Out(a)` is retained by the account (a change coin)
  --- funds are conserved, never created except by an explicit,
  predicate-checked `Mint(a)`. When `asset_issuance` is present, the v1
  mint clauses of
  #link(<65-issuance--versioned-schemas-v1-minimal>)[Architecture §6.5]
  #strong[MUST] all hold --- these are the normative content of the v1
  mint circuit, and they hook §6.5 into the predicate enumerated here.
  In summary:

  - \(a) `asset_issuance.issuance_version == 1` (the circuit accepts
    only v1 mints);
  - \(b) `H(asset_issuance.creator_pubkey) == prev_account_state.owner`
    (binds the issuance to the asset\'s creator account; the witness
    carries `creator_pubkey = Pk₀` because the SPEND key rotates per
    transition and `Pk₀` is otherwise irrecoverable in-circuit from its
    SHA-256 image `owner`);
  - \(c)
    `asset_issuance.asset_id == Hc("AssetId", genesis_tag ‖ asset_issuance.creator_pubkey ‖ asset_issuance.name_hash ‖ asset_issuance.decimals ‖ asset_issuance.issuance_version)`
    (the v1 `IssuanceTerms.asset_id` derivation of
    #link(<14-identifiers-and-hashes>)[Foundations §1.4]);
  - \(d)
    `terms_hash == Hc("IssuanceTerms", asset_issuance.asset_id ‖ asset_issuance.issuance_version)`
    (the v1 `IssuanceTerms.terms_hash` recomputation).

  Together with `Mint(asset_issuance.asset_id) = asset_issuance.amount`
  flowing into the `In(a) + Mint(a) ≥ Out(a)` check above, these
  complete the v1 issuance discipline.

+ #strong[Nullifier derivation.] For every `input_coins[j]`, compute
  `nf_j = Hc("Nullifier", nk ‖ input_coins[j].identifier)`
  (#link(<14-identifiers-and-hashes>)[Foundations §1.4]) in-circuit from
  the witnessed `nk`. All `nf_j` within one transition #strong[MUST] be
  pairwise distinct, and they form the leaves whose root is
  `ProofData.input_nullifiers_root`. These `nf_j` are carried into the
  spender\'s `SpendRecord` (off-chain,
  #link(<15-core-data-structures>)[§1.5]) and are bound by the
  per-spender `message = inr ‖ ocr` plus the sign-to-contract tweak. The
  per-account proof makes #strong[no] in-circuit claim of global
  non-membership. Global double-spend protection is enforced by the
  #strong[publisher\'s] `AggregateBatchProof`
  (#link(<22-proof-types>)[§2.2]) when the batch is inscribed: it
  attests every member `nf` is correctly derived and that the new
  accumulator root is the SMT-insertion of every batch member into the
  previous root (#link(<37-the-nullifier-accumulator>)[On-chain §3.7]).
  A receiver checks non-membership against the live on-chain accumulator
  (§2.3.3 step 5) via Path A or Path B
  (#link(<37-the-nullifier-accumulator>)[§3.7]). Within the account,
  clause 2(b) together with the coin-history update (clause 8) prevent
  the account from spending the same coin twice along its own lineage.

+ #strong[Output coin construction.] For each `output_templates[k]`, the
  new `coin.identifier` is computed as
  `Hc("Coin", prev_account_state_hash ‖ output_templates[k].asset_id ‖ coin_index_k)`
  (#link(<14-identifiers-and-hashes>)[Foundations §1.4]), with
  `coin_index_k` assigned monotonically within the transition. Using the
  #strong[prior] state\'s `ash` here keeps the identifier non-circular
  with respect to `new_account_state_hash` (which itself folds in the
  post-transition `coin_history_root` covering these very output coins).
  The resulting `Coin` objects
  (`{identifier, recipient, amount, asset_id}`) are the transition\'s
  outputs.

+ #strong[Output coins root.] `ProofData.output_coins_root` (`ocr`)
  #strong[MUST] equal the Poseidon Merkle root over the output
  `coin.identifier`s under tag `CoinsRoot`
  (#link(<14-identifiers-and-hashes>)[Foundations §1.4], §1.6).

+ #strong[New account state.] `new_account_state` is
  `prev_account_state` with: `balances` updated per clause 3 (debit
  spent inputs, credit change and any issuance),
  `current_pubkey = next_pubkey = Pkᵢ₊₁`, `send_counter` incremented by
  one, and `coin_history_root` set to the value produced by clause 8
  (the recomputed per-account coin-history SMT root,
  #link(<176-nullifier-accumulator-sparse-merkle-tree>)[Foundations §1.7.6]).
  `ProofData.new_account_state_hash` #strong[MUST] equal
  `ash = Hc("AccountState", serialize(new_account_state))`
  (#link(<14-identifiers-and-hashes>)[Foundations §1.4, §1.7.4]).
  `new_account_state.owner` #strong[MUST] be unchanged.

+ #strong[Coin-history update.] The per-account coin-history SMT is
  updated to mark spent inputs and admit the change/issuance coins;
  `ProofData.coin_history_root` #strong[MUST] equal the resulting root.

+ #strong[Public-input binding.] All four `ProofData` fields ---
  `new_account_state_hash`, `output_coins_root`,
  `input_nullifiers_root`, `coin_history_root` --- #strong[MUST] be the
  in-circuit-computed values above and are the proof\'s public inputs.
  Nothing else is public: amounts, asset ids, recipients, keys, and
  counts remain in the witness (zero-knowledge).

The spender\'s #strong[SpendRecord] (`message = inr ‖ ocr`,
#link(<14-identifiers-and-hashes>)[Foundations §1.4]) --- an off-chain
object --- binds this transition\'s spent nullifier set
(`input_nullifiers_root`) and its produced coins (`output_coins_root`)
via a BIP-340 signature by `Pkᵢ`, and its sign-to-contract nonce binds
`H(ProofData)` so the off-chain validity proof is anchored to this
record. The publisher then aggregates many `SpendRecord`s into a
`BatchBundle`, builds the `AggregateBatchProof` over them, and inscribes
one constant-size `BatchInscription` on Bitcoin (committing
`prev_root → new_root` and binding the bundle by content-address);
construction and publishing are specified in
#link(<3--on-chain-layer>)[On-chain Layer].

=== 2.2 Proof types
<22-proof-types>
Two PCD circuits are involved, each handling one role: the
#strong[per-account compliance circuit] `C` (which `InitialProof` and
`AccountUpdateProof` are both produced by) and the #strong[publisher\'s
batch-aggregation circuit] `C_batch` (which the `AggregateBatchProof` is
produced by, verifying many `C`-proofs and an SMT update inside one
recursive proof).

#table(
    columns: 4,
    align: (auto,auto,auto,auto,),
    table.header([Type], [Circuit], [When], [Clause 1 behaviour],),
    table.hline(),
    [`InitialProof`], [`C`], [first transition of an account (creation;
    optionally an issuance)], [`prev_proof` absent; `prev_account_state`
    is the canonical empty account for `owner = H(Pk₀)` (defined
    below)],
    [`AccountUpdateProof`], [`C`], [every subsequent
    transition], [`prev_proof` present and verified recursively against
    the circuit\'s own verifier data],
    [`AggregateBatchProof`], [`C_batch`], [one per `BatchBundle`
    (#link(<31-the-on-chain-object>)[On-chain §3.1, §3.5]) --- built by
    the publisher, not the spender], [aggregates `m` member
    `SpendRecord`s + their per-account proofs],
)

#strong[Canonical empty account (normative).] For any `address`, the
#strong[canonical empty `AccountState`] has these exact field values and
#strong[MUST] be reproducible bit-for-bit:

- `owner = address`
- `balances = {}` (the empty map; `balances_count = 0` in `serialize`,
  #link(<174-serializeaccountstate>)[§1.7.4])
- `current_pubkey = Pk₀` (the x-only initial spend pubkey whose hash is
  `address`)
- `send_counter = 0`
- `coin_history_root = E'₂₅₆` (the empty coin-history SMT root,
  #link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6])

The InitialProof\'s `prev_account_state` is exactly this state; its
`ash` (call it `ash_empty(address)`) is
`Hc("AccountState", serialize(canonical_empty_account))`.

Because recursion is #strong[cyclic] --- one fixed circuit that verifies
proofs of itself --- the verifier data of `C` is constant, so
#strong[per-account proof size and verification time are constant] and
independent of an account\'s or a coin\'s history length. A conforming
verifier #strong[MUST NOT] require, fetch, or re-execute any prior
transition: verifying the latest proof transitively attests every
predecessor.

#strong[AggregateBatchProof (normative).] The publisher\'s
batch-aggregation circuit `C_batch` takes the following inputs and
attests, in zero knowledge, the entire batch:

- #strong[Public inputs:] `prev_root` (the accumulator root before this
  batch), `new_root` (the resulting accumulator root), and
  `bundle_locator = Hc("BatchBundle", serialize(BatchBundle))` (the
  32-byte content address of the bundle, computed in-circuit over the
  canonical serialisation of every batch member --- see clause 6 below).
  Binding `bundle_locator` in the public inputs ties this proof to
  #strong[exactly one] bundle content; a publisher cannot serve two
  bundles with the same `(prev_root, new_root)` pair but different
  member sets under the same proof.
- #strong[Private witness:] the `m` member `SpendRecord`s; the `m`
  corresponding per-account proofs (`InitialProof` /
  `AccountUpdateProof` from `C`); the SMT insertion paths from
  `prev_root` to `new_root` for every member nullifier; the canonical
  serialisation of the bundle.

`C_batch` MUST enforce:

+ #strong[Per-member soundness.] For each `j ∈ [1, m]`, the spender\'s
  per-account proof verifies under `C`\'s verifier data, its public
  `ProofData` matches the member `SpendRecord`\'s `message = inr ‖ ocr`,
  and the spender\'s BIP-340 signature verifies against
  `(Pkⱼ, messageⱼ)` (half-aggregated in-circuit is permissible ---
  #link(<33-off-chain-signature-handling>)[On-chain §3.3]).
+ #strong[Per-member sign-to-contract binding.] Each member\'s S2C tweak
  `t = H(R' ‖ H(ProofDataⱼ))` checks against the on-chain `Rⱼ`, binding
  the per-account proof to the SpendRecord that referenced it.
+ #strong[Nullifier-set integrity.] The multi-set union of every member
  `SpendRecord`\'s `nullifiers` equals exactly the batch\'s
  `batch_nullifiers` list, with no duplicates introduced (every `nf`
  appears at most once across all members of this batch --- duplicates
  #emph[across] batches are caught by the global accumulator at
  admission).
+ #strong[Accumulator transition correctness.] Starting from `prev_root`
  and applying SMT-insertion of each `nf ∈ batch_nullifiers` in the
  canonical insertion order produces exactly `new_root`. The order is
  defined by the bundle\'s canonical serialisation and bound by the
  `bundle_locator` public input.
+ #strong[Network/chain separation.] The verifier data of `C_batch` (and
  of `C`) is parameterised by a fixed network tag
  (`"zkCoins/v1/mainnet"`, `"zkCoins/v1/testnet"`, …), so a proof valid
  against one network\'s verifier data is unsatisfiable against
  another\'s. A conforming verifier MUST refuse a proof whose verifier
  data does not match the network it is operating on.
+ #strong[Bundle-locator binding.] `bundle_locator` (public input)
  equals `Hc("BatchBundle", serialize(BatchBundle))` computed in-circuit
  over the witnessed canonical serialisation, where the serialisation is
  the deterministic byte concatenation
  `prev_root ‖ new_root ‖ u32-be(m) ‖ SpendRecord₁ ‖ … ‖ SpendRecord_m`
  (each `SpendRecordⱼ` per the #link(<14-identifiers-and-hashes>)[§1.4]
  byte layout). The `aggregate_proof` field of the bundle itself is
  #strong[not] part of this preimage (a proof cannot commit to its own
  bytes); it is bound separately by the sign-to-contract tweak of the
  publisher\'s BIP-340 signature
  (#link(<32-batchinscription-signing-bip-340--sign-to-contract>)[§3.2]).

Verifier data for `C_batch` is also fixed (under clause 5\'s network
tag), so the `AggregateBatchProof` is #strong[constant-size in `m`]
(asymptotic to the recursion-overhead floor of \~100 KB; the marginal
per-member contribution is in proving #emph[time], not in proof
#emph[size]). A scanner verifies one `AggregateBatchProof` per
`BatchInscription` --- never per member --- and accepts the entire
batch\'s accumulator transition on a single check.

=== 2.3 State transitions
<23-state-transitions>
The three operations are the only ways state changes. Each is one
execution of `C` producing one `SpendRecord` (off-chain, handed to a
publisher for batching unless the transition is a mint that the issuer
chooses not to anchor) and, for value delivered to a counterparty, one
or more `CoinProof` bundles (off-chain,
#link(<15-core-data-structures>)[Foundations §1.5]). The #strong[wallet]
holds the SPEND branch and signs; the #strong[node/prover] holds the
operational bundle, builds the witness, and runs the prover
(#link(<12-key-hierarchy>)[Foundations §1.2]). The spend key
#strong[MUST NOT] leave the wallet.

==== 2.3.1 Mint / issuance
<231-mint--issuance>
Creates an account and/or issues coins of a newly-created asset.
Issuance is #strong[versioned and creator-bound]: each asset is created
under a specific `IssuanceTerms` version
(#link(<65-issuance--versioned-schemas-v1-minimal>)[System Architecture §6.5]),
and the asset\'s identity binds to its creator\'s `Pk₀` #emph[and] its
`issuance_version` by construction
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]).
#emph[\"Permissionless\"] means anyone can create their own asset, not
that anyone can mint someone else\'s: only the holder of `sk₀` of the
issuing account can sign mint transitions for it. #strong[v1 imposes no
protocol-level supply cap, per-mint quantum, or time window] --- within
their own asset, the creator MAY mint any amount at any time; supply
discipline is a creator\'s commitment, not a protocol guarantee (see
#link(<65-issuance--versioned-schemas-v1-minimal>)[Architecture §6.5]).

```
Inputs (wallet → node):
  owner          = H(Pk₀)               // account identity, from the initial spend key
  name, decimals                        // human-readable; name is NEVER on-chain
  amount                                 // initial supply to emit to self

Wallet:
  1. derive Pk₀ = sk₀·G; sign the transition signature BIP-340(sk₀, message = inr ‖ ocr)
     (a mint spends no coin, so inr is the empty-set root; signed by Pk₀, i.e. sk₀; current_pubkey rotates to Pk₁)
  2. derive name_hash = H(name); asset_id = Hc("AssetId", genesis_tag ‖ Pk₀ ‖ name_hash ‖ decimals ‖ issuance_version=1)   (Foundations §1.4)
  3. provide nk and next_pubkey Pk₁ from the SPEND branch

Node / prover:
  4. build the witness with empty inputs, asset_issuance = {asset_id, creator_pubkey = Pk₀,
     issuance_version = 1, name_hash, amount, decimals}, and one output coin
     {recipient = owner, amount, asset_id}
  5. run C as an InitialProof (clause 1, InitialProof path): the v1 issuance circuit checks
     the four §6.5 mint clauses — issuance_version == 1, H(creator_pubkey) == owner,
     asset_id derivation, and terms_hash recomputation; Mint(asset_id) = amount,
     In(asset_id) = 0, so balance clause 3 admits exactly `amount` of the new asset
  6. obtain π, new ash, ocr, and ProofData

Produces an off-chain mint object:  { Pk₀ (x-only), nullifiers = [] (a mint spends nothing),
  BIP-340(sk₀, inr ‖ ocr), message = inr ‖ ocr }
  A mint contributes no nullifiers to the accumulator and therefore does NOT require a
  BatchInscription. Its validity is established off-chain: the receiver of any subsequent
  CoinProof verifies the mint's recursive proof transitively (cyclic recursion, §2.2)
  along with every later transition in the coin's lineage.

CoinProof produced:  for self-held supply, none is delivered; the node retains the coin,
  proof, and inclusion proof locally as spend credential. A mint MAY be optionally batched
  into a BatchInscription by a publisher (with kⱼ = 0 contribution to the accumulator) if
  the issuer wants a publicly anchored "first appearance" of the asset; this is a publisher
  policy choice and not protocol-required.
```

`asset_id` is globally unique because it commits to the creator pubkey,
`name_hash = H(name)`, `decimals`, and the `issuance_version`\; two
creators cannot collide, the same creator distinguishes assets by
`name_hash`/`decimals`, and two assets created under different
`IssuanceTerms` versions are also distinct. The human-readable `name`
travels only inside bundles, never on-chain
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]).

==== 2.3.2 Send
<232-send>
Spends owned input coins and produces output coins (recipient coins plus
a change coin), the corresponding nullifiers, a new account state, and a
proof.

```
Inputs (wallet → node):
  input_coins[]                          // coins the account owns and will spend
  output_templates[] = CoinTemplate[]    // {recipient, amount, asset_id} per payee

Wallet:
  1. sign the single transition signature BIP-340(skᵢ, message = inr ‖ ocr) with the
     current per-transition signing key skᵢ (whose Pkᵢ is current_pubkey; no per-coin key)
  2. supply nk (for nullifiers) and the rotated next_pubkey Pkᵢ₊₁  (SPEND branch, Foundations §1.2)

Node / prover:
  3. for each input coin, derive nf = Hc("Nullifier", nk ‖ coin.identifier)
  4. assemble the witness; per asset, add a change CoinTemplate {recipient = owner,
     amount = In(a) − Out(a), asset_id = a} so clause 3 holds with equality
  5. for each output coin (Foundations §1.3): draw esk, compute epk = esk·G,
     ss = ECDH(esk, IVPK_recipient), K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk),
     detect_tag = Hc("zkCoins/v1/DetectTag", dk ‖ epk); encrypt the coin plaintext under K_tx
  6. run C as an AccountUpdateProof: recursive verify of prev_proof (clause 1), input
     authenticity (2), per-asset conservation (3), nullifier non-membership→insertion (4),
     output construction (5–6), new state/ash (7), coin-history update (8), binding (9)
  7. obtain π, ash, ocr, ProofData

Produces the SpendRecord (off-chain, handed to a publisher):
  { Pkᵢ (x-only), nullifiers = [nf for each input coin],
    BIP-340(skᵢ, inr ‖ ocr), message = inr ‖ ocr }
  The publisher batches this SpendRecord with others into a BatchBundle, builds the
  AggregateBatchProof, and inscribes one constant-size BatchInscription on Bitcoin
  (On-chain §3.1, §3.5).

CoinProof produced (per recipient coin, delivered off-chain):
  { coin, proof = π, inclusion_proof (membership in ocr), epk, ciphertext, detect_tag }
  (Foundations §1.5). The change coin's bundle is retained locally, not delivered.
```

When the publisher\'s `BatchInscription` is admitted
(#link(<36-chain-scanning>)[On-chain §3.6]), its `AggregateBatchProof`
inserts every member\'s nullifiers into the global accumulator and the
spent coins become unspendable again
(#link(<37-the-nullifier-accumulator>)[§3.7]). The rotated
`current_pubkey` is bundle-only (the inscription itself reveals only the
publisher\'s identity, not the spender\'s), so the publisher cannot link
this `SpendRecord` to the account\'s prior records and a chain-only
observer learns nothing about the spender. Delivery of the per-recipient
`CoinProof` over Nostr is specified in
#link(<4--transport--recovery>)[Transport & Recovery]\; delivery of the
spender\'s `SpendRecord` to the publisher is specified in
#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6].

==== 2.3.3 Receive
<233-receive>
The receiver (or its node, on its behalf) credits a coin #strong[only
after independent verification] --- the trustless-receive norm
(#link("/requirements")[Requirement 4]). A conforming receiver
#strong[MUST NOT] credit a coin on the sender\'s or any third party\'s
assertion.

```
Inputs:
  CoinProof bundle (off-chain, delivered to the recipient)   (Foundations §1.5)
  the receiver's own view of Bitcoin and the global roots

Receiver / node:
  1. discovery & decrypt: match detect_tag against the receiver's dk; re-derive
     ss = ECDH(ivk, epk), K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk); decrypt the coin
     (only a holder of ivk can; Foundations §1.3)
  2. RE-VERIFY THE FULL RECURSIVE PROOF: C.verify(proof) under the canonical verifier data.
     This transitively attests the entire provenance in constant time (§2.2). MUST pass.
  3. inclusion: verify inclusion_proof places coin.identifier in the committed output_coins_root.
  4. anchoring: verify that output_coins_root is bound by a SpendRecord whose containing
     BatchInscription is in state completed (Onchain §3.10) — the spender's BIP-340 signature
     over message = inr ‖ ocr verifies, the spender's nullifiers appear in the BatchBundle that
     the inscription anchors, and the publisher's AggregateBatchProof attests the batch.
     A BatchInscription in any other state (pending or failed) MUST be treated as not anchored.
     This proves the creating spend was actually admitted on Bitcoin, not merely off-chain-signed.
     (For a mint coin whose issuer chose not to anchor it on-chain, anchoring reduces to
     verifying the mint's recursive proof directly — there is no nullifier to check, since
     a mint produces none.)
  5. nullifier non-membership: against the live accumulator at NAV(tip) (Onchain §3.7), verify
     the coin's own nf is NOT in the set. The receiver MAY use Path A (maintain the accumulator
     locally by tracking BatchInscriptions and verifying each AggregateBatchProof) or Path B
     (hold only the inscribed roots and ask a Path-A node for a self-verifying SMT inclusion
     path against the on-chain new_root). Either is trustless: the answering node cannot lie,
     because a forged absent answer would require forging a Merkle path against a root the
     receiver already knows from Bitcoin.
  6. amount/asset sanity: confirm coin.recipient = receiver's address and asset_id is well-formed.

On all of 2–5 passing: credit coin.amount of coin.asset_id to the receiver's AccountState and
admit the coin to the receiver's coin-history SMT. The bundle is now the receiver's spend
credential for a future Send. The receiver MAY return an encrypted acknowledgement so the
sender can drop its copy (Transport & Recovery).
```

Steps 2 (recursive re-verification of the spender\'s per-account proof)
and 5 (global nullifier non-membership against the accumulator anchored
on Bitcoin) are the two checks that make receipt fully trustless: the
receiver depends on #strong[Bitcoin, the spender\'s recursive proof, and
the publisher\'s AggregateBatchProof, never on the courier or any
node\'s bare claim]. A failed or malicious transport can
#strong[withhold] a bundle but can never make an invalid one verify; a
dishonest node can refuse to serve a Path-B Merkle path but cannot forge
one against the on-chain root.

=== 2.4 Soundness summary
<24-soundness-summary>
Each predicate property delivers a specific
#link("/requirements")[Requirement]:

#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([Property (clause)], [Guarantees], [Requirement],),
    table.hline(),
    [Recursive verification + input authenticity (1, 2)], [#strong[No
    forgery] --- a coin exists only as the signed, proven output of a
    valid prior transition; no party can fabricate a coin it was not
    entitled to], [3 · Trustless],
    [Per-asset balance conservation (3)], [#strong[No inflation of
    others\' assets] --- for every `asset_id`, outputs never exceed
    inputs plus an explicit, creator-bound `Mint`\; supply is auditable
    by every receiver], [3, 8],
    [Nullifier derivation (4) + receive check 5], [#strong[No
    double-spend] --- each coin\'s `nf` is admitted into the global
    accumulator via a publisher\'s `AggregateBatchProof` and can enter
    the set only once; a reused `nf` is rejected (the
    `AggregateBatchProof`\'s SMT-update would be inconsistent) and fails
    the receiver\'s non-membership check against the on-chain-anchored
    root], [3],
    [Full re-verification on receipt (§2.3.3)], [#strong[Client-side
    validation] --- correctness never depends on the sender, the node,
    or any third party], [4],
    [Public-input binding + ZK witness (9)], [#strong[Privacy] --- only
    roots/hashes are public; amounts, assets, parties, and the graph
    stay hidden], [2],
    [Constant-size cyclic recursion (§2.2)], [#strong[Scalable
    trustlessness] --- history of any length verifies in constant time,
    so re-verification is always feasible], [4],
)

=== Reading guide
<reading-guide>
- BatchInscription construction, publisher signing, batch aggregation
  via `AggregateBatchProof`, chain scanning, and the global nullifier
  accumulator: #link(<3--on-chain-layer>)[On-chain Layer].
- `CoinProof` delivery, node-as-relay, note discovery, and
  recovery/data-availability:
  #link(<4--transport--recovery>)[Transport & Recovery].
- Viewing keys, view grants, and the public/authorised explorer:
  #link(<5--access--explorer>)[Access & Explorer].
- Node/wallet/explorer components, portability, and the open-mint
  issuance terms: #link(<6--system-architecture>)[System Architecture].

== 3 · On-chain Layer
<3--on-chain-layer>
#quote(block: true)[
#emph[In one sentence: the single constant-size object zkCoins writes to
Bitcoin (the `BatchInscription`), how publishers aggregate many records
into one off-chain `BatchBundle` attested by a recursive
`AggregateBatchProof`, and how every node tracks the global nullifier
accumulator by following the chain of inscribed `prev_root → new_root`
transitions.]
]

This page specifies the Bitcoin-facing layer of zkCoins: how a
publisher\'s `BatchInscription` (#link(<31-the-on-chain-object>)[§3.1])
is signed and embedded, how the corresponding off-chain `BatchBundle`
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6])
carries the member `SpendRecord`s and the `AggregateBatchProof`, how any
node tracks the global #strong[nullifier accumulator] by verifying each
batch\'s recursive proof and applying its `prev_root → new_root`
transition
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]),
and how that accumulator provides trustless double-spend protection. It
introduces #strong[no] change to Bitcoin consensus and #strong[no]
native token (#link("/requirements")[Requirement 1]).

Normative keywords (#strong[MUST], #strong[MUST NOT], #strong[SHOULD],
#strong[MAY]) are used per RFC 2119. All primitives, identifiers, and
domain-separation tags are those defined in
#link(<1--foundations-normative>)[Foundations] and are used unchanged.

=== 3.1 The on-chain object
<31-the-on-chain-object>
The #strong[only] object zkCoins writes to Bitcoin is the
`BatchInscription` --- a constant-size commitment that anchors one
publisher batch:

```
BatchInscription = {
  publisher_pubkey : Pkₚ                    // 32 bytes, BIP-340 x-only — the publisher's identity
  prev_root        : root                   // 32 bytes — nullifier-accumulator root the batch builds on (§3.7)
  new_root         : root                   // 32 bytes — resulting accumulator root after this batch (§3.7)
  bundle_locator   : digest                 // 32 bytes — Hc("BatchBundle", serialize(BatchBundle)) (§3.5)
  block_anchor     : { block_hash, height } // 32 + 4 bytes (§3.5)
  signature        : BIP-340(skₚ, batch_message)  // 64 bytes — sign-to-contract binds the off-chain
                                                  //   AggregateBatchProof (§3.2)
}                                              // 231 bytes inscribed per batch, CONSTANT
```

The inscription is #strong[constant-size per batch], independent of the
number of `SpendRecord`s the batch carries. The records themselves ---
and the recursive #strong[`AggregateBatchProof`]
(#link(<22-proof-types>)[Proofs §2.2]) attesting them --- live off-chain
inside a `BatchBundle`
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]),
addressed by `bundle_locator`.

`prev_root` and `new_root` together commit, on-chain and ordered by
Bitcoin, to one state transition of the global nullifier accumulator
(§3.7). The `BatchBundle` carries the corresponding
`AggregateBatchProof` that attests, in zero knowledge: (a) each member
spender\'s `SpendRecord`
(#link(<15-core-data-structures>)[Foundations §1.5]) verifies under its
own per-account recursive proof, (b) `new_root` equals the SMT-insertion
of all member nullifiers into `prev_root`, and (c) the bundle\'s
nullifier set is #strong[exactly] the union of those member
SpendRecords\' nullifiers. A scanner accepts the inscription only after
fetching the bundle by `bundle_locator` and verifying the aggregate
proof against `(prev_root, new_root, batch_nullifiers)` as public inputs
(§3.6).

A `BatchInscription` contains only roots, a publisher key, a locator
hash, and a signature; it reveals no amount, asset, sender, receiver,
nor any individual nullifier. The per-batch Bitcoin footprint stays the
same whether the bundle covers 1 record or 1 000.

The bundle\'s #strong[data availability] is enforced by the same
replication discipline as `CoinProof` bundles --- `k = 3` independent
holders by default
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]).
A bundle that becomes unreachable does not break custody (the last
`completed` accumulator root remains anchored on-chain), but it blocks
any verifier from validating the corresponding `BatchInscription` until
at least one replica is reached (§3.10).

=== 3.2 BatchInscription signing (BIP-340 + sign-to-contract)
<32-batchinscription-signing-bip-340--sign-to-contract>
The signature in a `BatchInscription` is a BIP-340 Schnorr signature by
the publisher\'s identity key `skₚ`. It signs the batch\'s message and
additionally carries, #strong[in its nonce] via
#strong[sign-to-contract], a commitment to the off-chain
`AggregateBatchProof` --- anchoring the proof to this exact inscription
with no extra bytes on-chain.

Let `H_agg = H(serialize(AggregateBatchProof))` be the 32-byte SHA-256
digest of the canonically-serialised aggregate proof (the prover\'s
published bytes; the canonical serialisation is fixed by the proof
system\'s implementation under §1.7). The batch message is the fixed
concatenation of every other on-chain field in inscription order:

```
batch_message = prev_root                 (32B)
              ‖ new_root                   (32B)
              ‖ bundle_locator             (32B)
              ‖ block_anchor.block_hash    (32B)
              ‖ block_anchor.height        ( 4B)        // u32 big-endian
```

A conforming signer and a conforming verifier #strong[MUST] use exactly
this concatenation; any other order produces a different challenge and a
different on-chain signature. Because the `AggregateBatchProof` is
#strong[not] itself on-chain, the sign-to-contract tweak is a real,
non-redundant binding distinct from `batch_message` (which already
covers `bundle_locator` --- but `bundle_locator` is
`Hc("BatchBundle", …)` over the canonical serialisation of the bundle
per #link(<14-identifiers-and-hashes>)[§1.4], which excludes the
`aggregate_proof` field by construction, so the additional `H_agg` tweak
gives a second, SHA-256-based commitment covering the proof bytes
themselves for receivers that prefer to verify on standard cryptographic
primitives without the Poseidon stack). The signer MUST construct the
nonce as:

```
1. R'  = k'·G                          // k' a fresh, uniformly random 256-bit nonce scalar
2. t   = H( bytes(R') ‖ H_agg )        // sign-to-contract tweak, SHA-256, 32 bytes
3. R   = R' + t·G                      // committed nonce point  (x-only, BIP-340 even-y)
4. e   = H_BIP340( bytes(R) ‖ bytes(Pkₚ) ‖ batch_message )   // BIP-340 challenge
5. s   = (k' + t + e·skₚ) mod n        // n = secp256k1 group order
6. signature = bytes(R) ‖ bytes(s)     // 64 bytes
```

The published `signature` is an ordinary, standalone BIP-340 signature:
any verifier checks `s·G == R + e·Pkₚ` with no knowledge of `t`. A
verifier that has fetched the `BatchBundle` (hence the
`AggregateBatchProof`) additionally recomputes `t` and confirms
`R = R' + t·G`, proving the on-chain commit binds #strong[exactly that]
off-chain proof. The signer MUST follow BIP-340 nonce hygiene
(deterministic-plus-auxiliary-randomness derivation of `k'`) and MUST
NOT reuse a nonce across two distinct messages. `Pkₚ` is the
publisher\'s long-lived identity key, not a rotating per-batch key:
stable identity for fee accounting and DA peering is the design intent.
A publisher MAY rotate `Pkₚ` between batches but is not required to.

=== 3.3 Off-chain signature handling
<33-off-chain-signature-handling>
Each member `SpendRecord`
(#link(<15-core-data-structures>)[Foundations §1.5]) inside a
`BatchBundle`
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6])
carries its own spender\'s BIP-340 signature over `message = inr ‖ ocr`,
sign-to-contract-bound to that spender\'s own off-chain validity proof
(per the §1.4 record definition, with
`H_tx = SHA-256(new_account_state_hash ‖ output_coins_root ‖ input_nullifiers_root ‖ coin_history_root)`
and the standard `R = R' + t·G` tweak). The publisher\'s
`AggregateBatchProof` (#link(<22-proof-types>)[Proofs §2.2]) verifies
#emph[every] member signature #strong[in-circuit] --- so the on-chain
`BatchInscription` does not separately carry any spender signature.

Half-aggregation of those member signatures inside the aggregate-proof
witness is an implementation-level optimisation: a publisher MAY batch
`m` BIP-340 checks into one multi-scalar test, deriving aggregation
coefficients `aⱼ = H( z ‖ le32(j) )` from a per-batch transcript
`z = H("zkCoins/v1/HalfAgg" ‖ R₁ ‖ Pk₁ ‖ m₁ ‖ … ‖ R_m ‖ Pk_m ‖ m_m)`,
computing `s_agg = Σⱼ aⱼ·sⱼ`, and proving in-circuit that
`s_agg·G == Σⱼ aⱼ·(Rⱼ + eⱼ·Pkⱼ)`. This shrinks the aggregate-proof
witness without changing any on-chain field. A non-aggregating publisher
(verifying each `m` signature directly in-circuit) is equally valid and
produces the same `BatchInscription`.

No individual spender signature, message, nullifier, or rotating spend
key ever touches Bitcoin. The publisher\'s own signature and its
sign-to-contract tweak (§3.2) are the only Schnorr objects that reach
the chain. This is the principled separation: per-spender
Schnorr-and-S2C objects stay inside the verifying recursion; the chain
carries one publisher signature per batch.

=== 3.4 The publisher
<34-the-publisher>
A #strong[publisher] is the permissionless agent that aggregates many
independent `SpendRecord`s into one `BatchBundle`, builds the
`AggregateBatchProof`, and inscribes the corresponding
`BatchInscription` on Bitcoin (§3.5). Its mapping is
#strong[many-to-one]: many spenders → one publisher inscription → one
accumulator state transition.

- Running a publisher MUST be permissionless; any participant MAY run
  one, and a wallet/node MAY act as its own publisher.
- A publisher MUST NOT be trusted for #strong[correctness]: it cannot
  forge, alter, reorder-to-steal, or include-without-verifying any
  record, because the on-chain `prev_root → new_root` transition is
  attested by the `AggregateBatchProof` and verifiable by every scanning
  node (§3.6). A publisher that signs an inscription whose bundle\'s
  aggregate proof does not check is producing nothing --- the
  inscription is rejected.
- A publisher MUST NOT be trusted for #strong[custody]: it never holds a
  spend key, a coin, or a per-account proof; the worst a faulty or
  malicious publisher can do is #strong[censor] (refuse to include a
  particular SpendRecord) or #strong[delay] (sit on it). Both are
  mitigated because anyone else can publish --- and the censored spender
  can submit to a different publisher.
- A publisher SHOULD batch over a bounded interval and SHOULD fit as
  many member records into one bundle as proving cost and the
  publisher\'s own latency budget allow. Larger batches amortise the
  constant per-batch on-chain cost more aggressively (§3.8); the
  per-record on-chain footprint approaches zero as the batch grows.
- #strong[Sequential commitment.] Each `BatchInscription` MUST declare a
  `prev_root` equal to the most recently admitted `new_root` at the time
  of publication. Two publishers racing to inscribe on the same
  `prev_root` is normal; Bitcoin\'s transaction ordering decides which
  lands first, and the later inscription is rejected (its `prev_root` no
  longer matches the live state, §3.6 step 4).
- #strong[Stale-bundle handling (normative).] A publisher whose
  `BatchInscription` is rejected as stale #strong[MUST] within a bounded
  retry window (RECOMMENDED: 6 Bitcoin blocks) either (a) re-batch the
  member `SpendRecord`s onto the live tip and re-publish with a fresh
  inscription, or (b) release the member `SpendRecord`s back so each
  spender MAY submit to an alternative publisher. A spender whose
  `SpendRecord` has been with a stale publisher for longer than the
  retry window without admission #strong[MAY] re-submit to any publisher
  (a `SpendRecord` is idempotent --- admitting the same `nf` twice is
  impossible by §3.7\'s accumulator transition, so the spender\'s risk
  is duplicate effort, not double-spend). Stale `BatchBundle`s are
  #strong[not] subject to the `k = 3` DA discipline of §4.6, which only
  applies to admitted bundles.

A publisher is computationally heavier than a plain broadcaster: it must
build a recursive aggregate proof per batch (on the order of 100 KB,
with proving time that scales sub-linearly in `m` thanks to recursion)
and serve the resulting `BatchBundle` until at least `k = 3` independent
replicas hold a copy
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]).
It remains a stateless role in the cryptographic sense --- every
published artefact is publicly verifiable --- and a publisher\'s \"right
to publish\" rests entirely on its ability to (a) reach the
bitcoind-broadcast surface and (b) produce a verifying aggregate proof.

=== 3.5 Inscription format
<35-inscription-format>
A `BatchInscription` is carried in a Taproot #strong[commit/reveal]
inscription. The commit transaction pays to a Taproot output whose
internal key is tweaked by a script-path leaf; the reveal transaction
spends it, exposing the leaf script, whose witness contains the payload
inside an `OP_FALSE OP_IF … OP_ENDIF` envelope (so the data is dropped
by Bitcoin script and costs only witness weight).

Every zkCoins payload MUST begin with the fixed 2-byte #strong[marker
prefix] `0x42 0x42` (`"BB"`), identifying the envelope as a zkCoins
inscription and letting scanners skip all other inscriptions cheaply.
The payload layout is #strong[fixed-size] --- there is no record body,
no variable-length section, and no count field:

```
offset  size  field
------  ----  -----------------------------------------------------------
  0       2   marker                    = 0x42 0x42                  (zkCoins prefix)
  2       1   version                   = 0x02                        (Variant-2 batch inscription)
  3      32   publisher_pubkey          BIP-340 x-only (Pkₚ, §3.2)
 35      32   prev_root                 accumulator root the batch builds on (§3.7)
 67      32   new_root                  resulting accumulator root after this batch (§3.7)
 99      32   bundle_locator            Hc("BatchBundle", serialize(BatchBundle))
131      32   block_anchor.block_hash   Bitcoin block hash of the tip the proofs are built against
163       4   block_anchor.height       big-endian u32, height of that block
167      64   signature                 BIP-340(skₚ, batch_message) with S2C tweak (§3.2)

total: 231 bytes inscribed per batch, ENTIRELY in witness data.
```

The inscription is #strong[constant-size]: a batch covering 1
`SpendRecord` and a batch covering 1 000 `SpendRecord`s cost the same
Bitcoin footprint. The records themselves, their per-spender BIP-340
signatures, their nullifiers, and the `AggregateBatchProof` attesting
them are entirely off-chain inside the `BatchBundle`
(#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]).
The accumulator\'s state transition `prev_root → new_root` is
#emph[asserted] on-chain by the publisher\'s signed inscription and
#emph[verified] by every scanner against the bundle\'s recursive proof
(§3.6).

The `block_anchor` is the pair `{ block_hash, height }` identifying the
tip every member spender\'s CoinProof and the aggregate proof were built
against. An issuance validity-window height check
(#link(<65-issuance--versioned-schemas-v1-minimal>)[System Architecture §6.5])
is evaluated #strong[in-circuit against `block_anchor.height`] ---
prover-supplied and provable in-circuit, the tip the proofs are built
against, known at proving time --- #strong[not] against the actual
(later) Bitcoin inclusion height, which is unknown when the batch is
produced. A scanner cross-checks on acceptance that
`block_anchor.block_hash` is at `block_anchor.height` in its own Bitcoin
chain view.

#strong[`block_anchor` bound (normative).] Let `inclusion_height` be the
height of the Bitcoin block that includes this batch\'s reveal
transaction. A scanner MUST reject the inscription unless #strong[both]:
(1) `block_anchor.height` is strictly less than `inclusion_height` and
`block_anchor.block_hash` is a strict ancestor of the inclusion block
(the anchor MUST NOT be the inclusion block itself, a forward block, or
off the inclusion block\'s chain), and (2) the gap is bounded by
`N = 100` blocks: `inclusion_height − block_anchor.height ≤ 100`. The
first condition rejects forward anchoring; the second rejects stale
anchoring. A `BatchInscription` whose `block_anchor` is not a strict
ancestor of its inclusion block, or whose gap exceeds `N = 100`, MUST be
treated as carrying #strong[no admitted state transition].

#quote(block: true)[
Note on sizes. The full inscription is 231 witness bytes, or \~58 vBytes
amortised over the whole batch (Bitcoin counts witness data at 1/4
weight). Marginal per-record on-chain cost is #strong[zero] ---
additional records change nothing in the inscription, only in the
off-chain bundle. A batch carrying 100 records lands well below one US
cent of on-chain footprint per record at typical mempool conditions; the
cost equation has shifted from \"per-record bytes on Bitcoin\" to
\"per-batch publisher proving cost + bundle DA bandwidth\".
]

Because the payload is fixed-size, parsing is trivial: a scanner reads
exactly 231 bytes after the marker; any payload shorter, longer, or
otherwise structurally invalid is malformed and MUST be treated as
carrying no admitted state transition. The §3.6 structural check (step
2) verifies the length; subsequent steps verify the signature, the
`prev_root` continuity, the bundle binding, and the aggregate proof.

#strong[Metadata (normative note).] A `BatchInscription` reveals the
publisher\'s identity `Pkₚ` (so fees can be paid and reputation can
accrue), the previous and new accumulator roots, the bundle\'s
content-address, and the anchoring Bitcoin tip --- nothing more. The
#strong[record count is hidden on-chain]\; only by fetching the bundle
does a verifier learn `m`. The per-spender input count `kⱼ` is also
bundle-only. Amounts, assets, parties, the transaction graph, and even
the per-batch throughput remain invisible to a chain-only observer, so
#link("/requirements")[Requirement 2] holds for all of them; the
publisher identity is the only on-chain link, and a publisher who values
its own privacy MAY rotate `Pkₚ` per batch at a small operational cost.

=== 3.6 Chain scanning
<36-chain-scanning>
Any node tracks the global #strong[nullifier accumulator] by following
the chain of `BatchInscription`s, fetching each batch\'s `BatchBundle`,
verifying its `AggregateBatchProof`, and applying the inscribed
`prev_root → new_root` transition
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6],
#link("/requirements")[Requirement 3]). For each new Bitcoin block, in
canonical order, a node MUST:

+ #strong[Discover.] Identify reveal transactions whose witness contains
  an inscription envelope beginning with the marker `0x42 0x42` (§3.5).
  All non-marker inscriptions are ignored.
+ #strong[Parse.] Decode the 231-byte fixed-format payload (§3.5).
  Reject any payload failing the structural check.
+ #strong[Verify publisher signature.] Check the BIP-340 signature
  against `(publisher_pubkey, batch_message)` (§3.2). A failure MUST
  cause the inscription to be discarded.
+ #strong[Check `prev_root` continuity.] The inscribed `prev_root` MUST
  equal the node\'s current admitted accumulator root, ordered by
  Bitcoin canonical position (primary key = block height; secondary =
  reveal-tx index within the block). If `prev_root` does not match ---
  because a competing publisher inscribed earlier in the same or a prior
  block --- the inscription is #strong[stale] and MUST be discarded; the
  affected records MAY be re-batched into a fresh `BatchInscription`
  whose `prev_root` matches the live tip.
+ #strong[Fetch the bundle.] Query the relay mesh for the `BatchBundle`
  whose content-address equals `bundle_locator`
  (#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]).
  The node MAY retry across replicas; the `k = 3` replication target
  makes one reachable holder sufficient. If no replica is reached within
  the node\'s bundle-fetch deadline, the inscription is left in state
  `pending` (§3.10) and re-tried on a back-off schedule.
+ #strong[Verify bundle binding.] Recompute
  `Hc("BatchBundle", serialize(BatchBundle))` per the canonical preimage
  of #link(<14-identifiers-and-hashes>)[§1.4] (which excludes the
  derived `nullifiers` view and the `aggregate_proof` field --- the
  latter is bound separately via the S2C tweak, see
  #link(<22-proof-types>)[§2.2 clause 6]) and check it equals the
  inscribed `bundle_locator`. Then recompute
  `H(serialize(AggregateBatchProof))` and check it equals the
  sign-to-contract tweak input (§3.2). A binding failure MUST cause the
  inscription to be discarded.
+ #strong[Verify the aggregate proof.] Verify the `AggregateBatchProof`
  (#link(<22-proof-types>)[Proofs §2.2]) against its public inputs
  `(prev_root, new_root, bundle_locator)` --- the same `prev_root` and
  `new_root` already inscribed on chain and the same `bundle_locator`
  already inscribed. The proof is a single recursive PCD attestation
  that every member spender\'s transition is valid under its own
  per-account recursive proof, every member nullifier is correctly
  derived (`nf = Hc("Nullifier", nk ‖ coin.identifier)`), the bundle\'s
  canonical serialisation hashes to `bundle_locator`, and `new_root`
  equals the deterministic SMT-insertion of all member nullifiers into
  `prev_root`. The bundle-locator binding closes the gap a
  `(prev_root, new_root, nfs)`-only public-input would leave: a
  publisher cannot present two distinct bundles with the same
  accumulator delta under the same proof. A proof-verification failure
  MUST cause the inscription to be discarded.
+ #strong[Apply the transition.] Update the local accumulator from
  `prev_root` to `new_root`. The list of inserted nullifiers (carried in
  the bundle) is added to the node\'s per-`nf` index used to serve
  membership and non-membership queries (§3.7). The bundle\'s member
  `SpendRecord`s and `CoinProof`s are persisted to the node\'s data
  store for receiver lookup and for serving future verifiers fetching
  the same `bundle_locator`.

If any of steps 2--4, 6, or 7 fails, the inscription is
#strong[`failed`] (§3.10) and contributes no nullifiers and no root
update. Two honest nodes scanning the same chain MUST arrive at the
#strong[identical] accumulator state, because every step is a
deterministic function of confirmed Bitcoin data plus the publicly
verifiable, content-addressed bundle.

#strong[On bundle unavailability.] Step 5 may transiently return no
holder, leaving the inscription in `pending` solely because of
data-availability. The accumulator state remains at the last
fully-verified `new_root`\; the `BatchInscription` lingers in `pending`
until the bundle reappears via a different replica, the operator\'s own
backup, or --- over a long enough timeline --- via the publisher
republishing. A `pending`-due-to-DA inscription is #strong[never]
silently admitted: verifier integrity strictly requires the aggregate
proof to check. Restoring the bundle later lets the node retroactively
complete the verification --- exactly the same liveness/availability
tradeoff as `CoinProof` bundles
(#link(<46-data-availability--replication-factor-k>)[§4.5--§4.6]).

The operative double-spend check is #strong[per-coin] (§3.7): a verifier
checks a specific coin\'s `nf` for membership against the live
accumulator at `NAV(tip)`. There is no per-coin membership path inside a
`CoinProof` bundle: a verifier that has run steps 1--8 against every
admitted `BatchInscription` holds the full `nf` set itself; a verifier
that has not done so SHOULD query a node that does (§3.7) and check the
served Merkle path against the on-chain `new_root`.

=== 3.7 The nullifier accumulator
<37-the-nullifier-accumulator>
Double-spend protection is enforced #strong[on-chain and trustlessly] by
the global #strong[nullifier accumulator]
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]):
a 256-bit-depth sparse Merkle tree (SMT) over every nullifier
`nf = Hc("Nullifier", nk ‖ coin.identifier)`
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]) ever
#strong[admitted via a `BatchBundle`] anchored by an admitted
`BatchInscription`. It supports both #strong[membership] and
#strong[non-membership] proofs.

#strong[State transitions.] The accumulator advances exactly with each
admitted `BatchInscription`: each inscription names a `prev_root` (the
prior state) and a `new_root` (the resulting state), and the
`BatchBundle`\'s `AggregateBatchProof` attests in zero knowledge that
`new_root = SMT.insert_many(prev_root, batch_nullifiers)` (§3.6 step 7).
The accumulator\'s state at any Bitcoin tip is therefore
#strong[deterministically derivable] from the sequence of inscribed
roots plus the corresponding bundles, and verifiable by every honest
node --- no node-asserted root is ever accepted on its own.

#strong[Anchored value.] A non-membership answer is meaningful only
#strong[relative to a Bitcoin chain tip]: the canonical value is
`NAV(tip) = (accumulator, tip_block_hash, tip_height)`. The latest
admitted `new_root` at or before `tip` is the live accumulator root. The
`block_anchor = { block_hash, height }` field of every inscription
(§3.5) records the tip the batch\'s proofs were built against. A
verifier MUST evaluate any membership/non-membership claim
#strong[relative to a stated tip]\; an answer quoted without its
anchoring tip MUST be rejected as ambiguous.

#strong[Double-spend check (per-coin).] To confirm a specific coin is
unspent as of `tip`, a verifier compares that coin\'s `nf` against the
accumulator at `NAV(tip)`:

- `nf` #strong[absent] ⇒ the coin is #strong[unspent] at `tip`\;
- `nf` #strong[present] ⇒ the coin is #strong[already spent]\; a fresh
  spend of it MUST be rejected.

Because `nf` is unlinkable to the coin without `nk`
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]), the nullifier
set reveals that #emph[some] coin was spent without revealing which coin
or account (#link("/requirements")[Requirement 2]).

#strong[Two equally-trustless verification paths.] There is no on-chain
raw `nf` list anymore --- the accumulator state on Bitcoin is the
#strong[inscribed sequence of roots]. A verifier can establish
`(non-)membership` against `NAV(tip)` along either of two paths, both
trustless:

- #strong[Path A --- maintain the accumulator itself.] Run §3.6 against
  every admitted `BatchInscription`, fetch each `BatchBundle`, verify
  each `AggregateBatchProof`, and apply the resulting
  `prev_root → new_root` transitions. The verifier then holds the full
  nullifier set locally and answers any `nf` query by direct lookup.
  Cost: ongoing bundle fetching plus aggregate-proof verification per
  batch; storage grows with the total number of admitted nullifiers
  (\~32 bytes per `nf` plus indexing).
- #strong[Path B --- light-client: hold only the on-chain roots,
  delegate the lookup.] Follow the inscribed `new_root` sequence (231
  bytes per batch on-chain), then ask any Path-A node for an SMT path of
  `nf` against the current `new_root`. The path is \~512 bytes
  (compressed empty subtrees) and self-verifying against the root the
  light client already knows from Bitcoin. The answering node may serve
  either an #strong[inclusion path] (proving `nf` is present at the
  queried key, leaf hash `H_leaf(1)`) or a #strong[non-inclusion path]
  (proving the queried key is empty, leaf hash `H_leaf(0)`);
  #strong[both] hash up to the same on-chain `new_root` under the §1.7.6
  SMT construction, so the light client\'s verification is identical in
  either direction --- recompute the path and check equality with
  `new_root`. Forging either direction against a known root would
  require breaking the Poseidon hash assumption (second-preimage
  resistance on internal nodes plus per-level domain separation).
  Querying multiple independent nodes hardens against denial of service;
  the correctness check is single-node-honest.

A Path-B light client distinguishes the two `pending` sub-states of
#link(<310-transaction-states>)[§3.10] --- `pending` due to
confirmations vs `pending` due to bundle DA --- by querying its serving
node for the latest #emph[bundle-verified] `new_root` rather than the
latest inscribed root. On-chain ordering plus the serving node\'s
verification state yields the same
`(completed, pending-DA, pending-confs)` classification a Path-A
verifier derives directly. A light client #strong[MUST NOT] accept a
non-membership answer against an inscribed-but-not-bundle-verified root.

\(The path that earlier drafts called \"rebuild the accumulator from
on-chain nullifiers\" is retired in this design: nullifiers no longer
appear on Bitcoin. The same trustless property is preserved by Path A
--- the bundles are content-addressed, recursively verifier-checkable,
and `k = 3` replicated --- and by the on-chain root commitment.)

#strong[Reorg handling.] If Bitcoin reorganises, every admitted
`BatchInscription` published only in orphaned blocks MUST be reverted
--- its `prev_root → new_root` transition is undone --- and re-applied
(if its bundle is still available and its `prev_root` still matches in
the new canonical chain) under the new canonical tip. Because each batch
chains its `prev_root` to the immediately prior admitted `new_root`, a
revert of batch `N` invalidates every later batch whose `prev_root` was
`N.new_root`: the canonical replay re-derives the entire post-`N` chain
deterministically, and any batch whose `prev_root` no longer matches the
replayed live root is stale and MUST be re-batched by its publisher onto
the new tip (§3.4 sequential-commitment clause). The accumulator state
at the new tip is therefore the deterministic replay of admissions in
the new canonical order. Because `NAV` is explicitly tied to a tip, a
stale one is self-identifying: a verifier MUST recompute or re-fetch
`NAV` for the current canonical tip before acting on a non-membership
result, and SHOULD wait for finality (§3.9) so that the anchoring tip is
reorg-stable.

#strong[Storage.] A Path-A node MAY exploit the tree\'s sparseness ---
the never-occupied regions of the 256-bit key space are implicit default
subtrees and need not be stored --- but the accumulator #strong[cannot]
prune by age: nullifiers are uniformly distributed keys, so \"old\" does
not map to a discardable region, and every inserted `nf` must stay
represented to answer both membership and arbitrary non-membership
against the current tip. Only never-occupied key-space is free; the set
of inserted nullifiers itself is not prunable.

=== 3.8 Fees and economics
<38-fees-and-economics>
Publishing a batch costs ordinary Bitcoin transaction fees, paid in BTC
by the publisher; zkCoins has no native token
(#link("/requirements")[Requirement 1]).

- #strong[Per-batch on-chain cost is constant.] A `BatchInscription` is
  231 witness bytes (\~58 vBytes). At a fee rate of 10 sat/vB and a BTC
  price of $100 000\,t h a t i s med$0.58 per batch --- regardless of
  whether the batch covers 1 `SpendRecord` or 1 000.
- #strong[Per-record amortised cost] therefore approaches
  `(constant per-batch on-chain cost) / (records per batch)` plus the
  publisher\'s per-record proving contribution (one in-circuit signature
  check and one SMT-insertion step, both folded into the
  `AggregateBatchProof`). A 100-record batch lands well below one US
  cent of on-chain footprint per record at typical mempool conditions; a
  1 000-record batch lands an order of magnitude lower still.
- The #strong[publisher] pays the Bitcoin fee for the inscription it
  broadcasts (§3.4) and bears the cost of building and serving the
  `BatchBundle` (proving + DA). It #strong[SHOULD] be reimbursable for
  both, and spenders #strong[MAY] compensate the publisher
  #strong[without revealing a funding UTXO] --- a
  #strong[broadcaster-paid] model in which the moved value covers the
  publisher\'s costs inside an off-chain settlement, so the spender\'s
  on-chain footprint stays limited to the opaque inscription. A wallet
  #strong[MAY] include a publisher-fee allowance in the off-chain
  settlement portion of its outgoing `CoinProof` bundle
  (#link(<4--transport--recovery>)[Transport & Recovery]) that the
  publisher claims as a zkCoins-native transfer; it #strong[MUST NOT]
  require the spender to sign or expose a Bitcoin UTXO.
- Fee policy is #strong[not] consensus: a publisher #strong[MAY] set any
  fee, and a wallet that finds a publisher\'s fee unacceptable
  #strong[MAY] use another publisher or self-publish (§3.4). No
  publisher can extract rent, because publishing is permissionless
  (#link("/requirements")[Requirement 7]).

=== 3.9 Finality
<39-finality>
A `BatchInscription` is #strong[published] the instant its reveal
transaction enters a Bitcoin block. zkCoins fixes the finality threshold
at #strong[6 confirmations]: an inscription at fewer than 6
confirmations is in state `pending` (§3.10), and a receiver #strong[MUST
NOT] treat its `new_root` as anchored for receive-side use. The protocol
assumes Bitcoin has #strong[no reorgs deeper than 5 blocks]\; a deeper
reorg is treated as a protocol-failure event, not a recoverable state
transition.

- A double-spend non-membership result (§3.7) is only as final as the
  tip it is anchored to; a verifier #strong[MUST] re-evaluate it on any
  reorg that displaces the inclusion block (§3.10).
- zkCoins adds no finality assumption beyond Bitcoin\'s: there is no
  separate consensus, validator set, or checkpoint
  (#link("/requirements")[Requirement 1],
  #link("/requirements")[Requirement 3]).
- Threat-model implications of the 5-block bound: see
  #link(<66-threat-model-and-trust-configurations>)[Architecture §6.6].

=== 3.10 Transaction states
<310-transaction-states>
Every `BatchInscription` a verifier observes --- and, transitively,
every member `SpendRecord` it covers --- is classified into
#strong[exactly one] of three states. The state is a function of the
verifier\'s own §3.5+§3.6 admission scan and the inclusion block\'s
confirmation depth --- #strong[never] of any assertion by a node,
publisher, courier, or sender. Two honest verifiers at the same
canonical Bitcoin tip #strong[MUST] classify every inscription
identically.

#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([State], [Defined as], [Receiver MAY credit],),
    table.hline(),
    [#strong[`completed`]], [the inscription is #strong[admitted] under
    §3.5+§3.6 by the verifier\'s own scan (signature, `prev_root`
    continuity, bundle binding, and aggregate proof all verify)
    #strong[AND] its inclusion block has #strong[at least 6
    confirmations] (§3.9)], [#strong[yes]],
    [#strong[`failed`]], [the inscription is #strong[rejected] by the
    verifier\'s scan --- any single §3.5 or §3.6 admission rule violated
    (parser, `block_anchor` bounds, publisher signature, `prev_root`
    mismatch, bundle binding, aggregate proof) suffices], [#strong[no]
    (never)],
    [#strong[`pending`]], [the inscription is in neither state --- its
    bytes are inscribed but the inclusion block has fewer than 6
    confirmations, or the bundle has not yet been fetched and verified
    (§3.6 step 5)], [#strong[no]],
)

#strong[Per-member status.] A `SpendRecord` inherits the state of the
`BatchInscription` that anchored its batch. There is no notion of one
member admitting while its batch is rejected: the `AggregateBatchProof`
is all-or-nothing --- it attests every member, or it fails entirely.

#strong[Relationship to the nullifier accumulator.] The global nullifier
accumulator (§3.7) advances #strong[only] with inscriptions that have
reached at least state `pending`-with-bundle-verified --- i.e.,
signature, `prev_root` continuity, bundle binding, and aggregate proof
have all succeeded, but the 6-confirmation threshold may not yet be met.
Double-spend protection therefore takes effect #strong[at admission],
before final confirmation: a coin whose spend\'s bundle has verified at
the verifier\'s tip is immediately unavailable for any further spend,
even while the inscription is still `pending` purely on confirmation
depth. An inscription that is `pending` solely because of bundle DA (its
confirmations are sufficient but no replica of the bundle has been
reached) is #strong[not] treated as applied: until the aggregate proof
verifies, no state transition is admitted.

#strong[6 confirmations is a hard protocol constant], not a parameter:
zkCoins assumes Bitcoin has no reorgs deeper than 5 blocks (§3.9), and a
deeper reorg is treated as a protocol-failure event --- not a state
transition under §3.10. Under this assumption, #strong[`completed` is
absolute]: an inscription once classified `completed` stays `completed`.

#strong[`failed` is forward-sticky.] A rejection cannot become an
admission by waiting. A reorg #strong[MAY] change #emph[which] of two
inscriptions racing on the same `prev_root` is rejected (e.g. if
canonical order shifts under §3.6 step 4), but the property of being
rejected by some admission rule cannot be undone by passage of time
alone.

#strong[Receivers SHALL act only on `completed` (or `mint-verified`
where applicable).] The anchor / receive checks in
#link(<233-receive>)[Proofs §2.3.3],
#link(<45-recovery>)[Transport & Recovery §4.5], and
#link(<56-shareable-confirmation-links>)[Access & Explorer §5.6 / §5.7]
all require the relevant `BatchInscription` (and hence its member
`SpendRecord`) to be in state `completed`\; an inscription in any other
state #strong[MUST NOT] be treated as anchored. The sole exception is
the `mint-verified` status defined below for non-batched mints, which
substitutes direct re-verification of the mint\'s `InitialProof` for the
chain-anchor check. The user-facing #strong[status] rendered by an
explorer (e.g. Access & Explorer §5.6 step 3) #strong[MUST] be the §3.10
state (one of `completed`, `failed`, `pending`, or `mint-verified`), not
a node-asserted classification.

#strong[Mints not anchored on-chain.] For a mint coin whose issuer chose
not to anchor it (#link(<231-mint--issuance>)[§2.3.1]), no
`BatchInscription` exists and the three §3.10 states do not apply. Such
a coin is classified as #strong[`mint-verified`] instead: the receiver
re-verifies the mint\'s `InitialProof` directly and accepts on success;
there is no double-spend protection to anchor (a mint introduces no
nullifier) and the cryptographic safety of the credit is identical.
Explorers and receivers #strong[MUST] render the `mint-verified` status
as distinct from `completed`/`pending`/`failed` so the user understands
it has no on-chain anchor, and any subsequent spend of this mint coin is
anchored normally --- the spend\'s `SpendRecord` reaches the accumulator
through a `BatchInscription` just like any other.

== 4 · Transport & Recovery
<4--transport--recovery>
#quote(block: true)[
#emph[In one sentence: how the encrypted coin bundle gets from sender to
recipient over Nostr, how the recipient finds its own coins on a relay,
and how a wallet that lost everything rebuilds its state from seed +
Bitcoin + the network.]
]

This page specifies the #strong[off-chain layer]: how the value-bearing
`CoinProof` bundle (#link(<15-core-data-structures>)[Foundations §1.5])
travels from sender to recipient, how the spender\'s `SpendRecord`
reaches a publisher, how the publisher\'s `BatchBundle` is
`k`-replicated to peer nodes, how a recipient discovers its own incoming
coins, how a node recovers its entire state from the #strong[seed] plus
Bitcoin, and the data-availability guarantees that make recovery
possible. The on-chain layer carries only the constant-size opaque
`BatchInscription`
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]); every
value-bearing or accumulator-bearing object --- the per-coin `CoinProof`
bundle and the per-batch `BatchBundle` --- lives here and #strong[MUST]
be delivered with `k`-fold replication (§4.6).

Normative keywords (#strong[MUST], #strong[MUST NOT], #strong[SHOULD],
#strong[MAY]) are used per RFC 2119. All primitives, keys, and
identifiers are defined in
#link(<1--foundations-normative>)[Foundations] and used unchanged.

=== 4.1 Roles and transport
<41-roles-and-transport>
Every zkCoins #strong[node is itself a full Nostr relay]. One process
performs Bitcoin validation, proof verification, state storage, the
encrypted bundle relay/store, and the capability-gated pull endpoint
(#link(<5--access--explorer>)[Access & Explorer]). There is no separate,
mandatory courier.

The transport key is `op`, the operational / Nostr identity key
(#link(<12-key-hierarchy>)[Foundations §1.2]). It is a secp256k1 /
BIP-340 key --- the same family Nostr uses --- so it doubles as the
wallet\'s Nostr key with no separate keypair. The node holds `op` and
runs the relay on the wallet\'s behalf; `op` #strong[MUST NOT] be able
to spend (it is a hardened sibling of the SPEND branch).

The transport is trusted only for #strong[availability] and for
#strong[metadata minimisation] --- never for correctness. A relay can
#strong[withhold] a bundle but can neither #strong[forge] nor
#strong[alter] one, because the recipient verifies every bundle
cryptographically (§4.5). This is the same trust spectrum as the node
model: a compromised relay is a privacy/availability problem, never
theft.

=== 4.2 Bundle delivery
<42-bundle-delivery>
A bundle is delivered as a small Nostr control event that
#strong[references] the encrypted bundle, plus the bundle blob itself in
content-addressed storage.

#strong[Why split.] A recursive proof is large (on the order of 100 KB
or more) --- too big for an ordinary relay event. Therefore:

+ The sender encrypts the serialised `CoinProof` bundle under the
  per-coin note key `K_tx`
  (#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3])
  using #strong[NIP-44 v2], producing `ciphertext`. (`K_tx` is
  re-derivable by the recipient from `ivk` and the coin\'s `epk`\; no
  relay can derive it.)

+ The sender stores `ciphertext` in a content-addressed blob store (a
  Blossom-style store co-located with each node\'s relay). The store
  returns a content hash `blob_id = H(ciphertext)`.

+ The sender constructs a #strong[delivery event], an
  application-specific Nostr event whose plaintext payload is:

  ```
  DeliveryEvent.payload = {
    detect_tag,                 // per-coin detection tag (Foundations §1.3)
    epk,                        // ephemeral pubkey for the coin (Foundations §1.3)
    blob_id,                    // content hash of the encrypted bundle
    blob_locators,              // ordered hints to nodes/stores holding the blob
    ack_nonce                   // 32 random bytes, sender-chosen; binds the ACK to this
                                //   delivery attempt (§4.2 ACK rule). Fresh per retry.
  }
  ```

  The payload carries #strong[no] amount, asset, recipient address, or
  sender --- those live only inside `ciphertext`. Note that `K_tx`
  itself is #strong[never] placed in the delivery event; the recipient
  re-derives it from `ivk` and `epk`. The `ack_nonce` is generated fresh
  per delivery attempt and is what the recipient signs in the ACK
  (below); the sender therefore knows that a returned ACK corresponds to
  #strong[this] delivery, not a captured-and-replayed ACK from an
  earlier round.

+ The sender encrypts the delivery event to the recipient\'s
  #strong[incoming-view public key] `IVPK = ivk·G`
  (#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3])
  with #strong[NIP-44 v2], then #strong[NIP-59] gift-wraps the result
  under a fresh ephemeral key. The outer wrapped event is addressed to
  that ephemeral key, so a relay sees neither sender nor recipient ---
  only an opaque blob stored at some time.

+ The sender publishes the gift-wrapped event to the recipient\'s
  advertised relay set (§4.3) and replicates per §4.6.

#strong[Store-and-forward.] The recipient #strong[MAY] be offline.
Relays #strong[MUST] retain a delivery event and its blob until either
an explicit deletion is authorised or a relay\'s retention policy
expires it; retention #strong[MUST] be at least long enough to satisfy
the acknowledgement rule below. Receiving therefore requires only that
#strong[one] holding relay is reachable when the recipient comes online
--- hence the multi-relay advertisement of §4.3.

#strong[ACK + retry (normative).] Delivery is reliable, not best-effort:

- The sender #strong[MUST] retain its own copy of the bundle (and
  `K_tx`) until it receives a valid acknowledgement.
- On successful receipt and verification (§4.5), the recipient\'s node
  #strong[MUST] return an #strong[acknowledgement]: a NIP-44-encrypted,
  NIP-59 gift-wrapped event addressed back to the sender, carrying
  `{detect_tag, blob_id, ack_nonce}` (echoing the `ack_nonce` from the
  delivery event\'s plaintext payload) and a BIP-340 signature by the
  recipient\'s `op` over
  `ack_message = H("zkCoins/v1/Ack" ‖ detect_tag ‖ blob_id ‖ ack_nonce)`.
  The sender verifies (i) the `op` signature against the recipient\'s
  published `op` pubkey #strong[and] (ii) that the echoed `ack_nonce`
  matches the nonce the sender chose for this delivery attempt. The
  nonce binding ensures a captured ACK cannot be replayed against a
  later retry (a fresh attempt uses a fresh `ack_nonce`, so a stale ACK
  fails verification (ii)).
- Until a valid ACK arrives, the sender #strong[MUST] re-publish the
  delivery event on an exponential-backoff schedule (RECOMMENDED:
  initial 30 s, doubling, capped at 1 h) to every relay in the
  recipient\'s set.
- After a valid ACK the sender #strong[MAY] drop its retained copy. The
  sender #strong[MUST NOT] drop the copy before both a valid ACK and the
  replication target `k` (§4.6) are confirmed.

#strong[Self-delivery of change and account state (normative).] A
transition almost always produces a #strong[change coin] that returns
value to the spender\'s #emph[own] account, and it advances the account
to a new state whose recursive proof is the credential the #strong[next]
spend must extend. The spender\'s node #strong[MUST] deliver this
self-addressed bundle to the spender\'s #strong[own] advertised relay
set under the identical rules above --- encrypted to the spender\'s own
`IVPK`, carrying its own `detect_tag` (§4.2), ACK-tracked where
applicable, and replicated to `k` independent holders (§4.6).
Self-delivery is not optional bookkeeping; it is what makes two
situations work, and #strong[without it neither does]:

- #strong[Multiple devices / nodes on one seed.] The Bitcoin chain
  reveals only `BatchInscription`s --- publisher identities and
  accumulator roots --- never anything per-spender; even the per-spender
  `SpendRecord` lives in the publisher\'s `BatchBundle` off-chain, and
  even there the spender\'s rotating key only privately ties back to its
  own account via the owner\'s seed. The chain reveals nothing about the
  resulting state of any individual account: not the new `ash`, not the
  #strong[balance] (`AccountState.balances` is off-chain), and not the
  #strong[recursive proof] the next spend must extend. A second device
  therefore learns of a spend made elsewhere #strong[only] by
  discovering this self-addressed bundle on a shared relay (§4.4) and
  pulling its blob. Consequently, devices that must stay in sync
  #strong[MUST] share at least one advertised relay, or one node
  #strong[MUST] be reachable through the other\'s pull endpoint
  (#link(<51-capability-gated-pull>)[Access & Explorer §5.1]); otherwise
  a second device can detect that an accumulator transition occurred but
  #strong[cannot reconstruct the spendable state], and must fall back to
  emergency reconstruction (§4.5).
- #strong[Emergency recovery.] Step 5 of §4.5 rebuilds `balances`,
  `current_pubkey`, and `send_counter` from exactly these self-addressed
  change/outgoing bundles; they are retrievable only because they were
  self-delivered and replicated here.

The chain guarantees the #strong[integrity] of the head; self-delivery
is what guarantees the #strong[availability] of the content behind it.
As with all transport, a relay can withhold this bundle but can never
forge or alter it (§4.1) --- so self-delivery is a liveness
precondition, never a trust assumption.

=== 4.3 Addressing for delivery
<43-addressing-for-delivery>
A sender starts from the recipient\'s `address`
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]) --- the
protocol\'s only public identity --- and must obtain two things: the
recipient\'s `IVPK` and a relay set to post to.

Addresses are minimal by design and carry no network routing, so
resolution is explicit. The supported source, in order of preference, is
the #strong[`Invoice`]
(#link(<15-core-data-structures>)[Foundations §1.5]), extended for
transport with the recipient-published, `op`-signed fields:

```
Invoice = {
  amount, recipient: address, asset_id, memo?,   // Foundations §1.5
  pk0           : Pk₀,                             // recipient initial spend pubkey (x-only, 32B);
                                                   //   the preimage of `recipient`: H(pk0) == recipient
  ivpk          : IVPK,                            // recipient incoming-view pubkey = ivk·G
  op_pubkey     : op·G,                            // recipient operational/Nostr identity
  relays        : [relay_url, …],                  // recipient's advertised relay set (≥ 1)
  addr_sig      : BIP-340(sk₀, invoice_message),   // 64B; chains the address-holder to every field below
  sig           : BIP-340(op,  invoice_message)    // 64B; carries the per-issuance op authorisation
}

invoice_message = H( "zkCoins/v1/Invoice" ‖ amount ‖ recipient ‖ pk0 ‖ asset_id ‖ memo
                   ‖ ivpk ‖ op_pubkey ‖ relays )
```

The two signatures\' preimage is a #strong[fixed concatenation] in
exactly the field order above (mirroring `grant_message`,
#link(<52-view-grant>)[Access & Explorer §5.2]); `H` and the input
ordering are per
#link(<14-identifiers-and-hashes>)[Foundations §1.4, §1.7]. The optional
`memo` contributes the empty byte string when absent, and `relays` is
concatenated in its listed order. Reordering any field changes the
digest and #strong[MUST] be rejected. `serialize(fields)` is
#strong[not] used; only this explicit order is signed and verified.

The sender #strong[MUST] verify, in order: (i) `H(pk0) == recipient` (so
the named `pk0` is the actual address preimage); (ii) `addr_sig` valid
under `pk0` over `invoice_message` (proves the address-holder authorised
these exact contents --- `ivpk`, `op_pubkey`, `relays`, amount, asset,
memo); (iii) `sig` valid under `op_pubkey` over `invoice_message`
(carries the per-issuance authorisation by the recipient\'s online
`op`). Any of these checks failing #strong[MUST] reject the `Invoice`.
Check (ii) is the #strong[address ↔ rest binding]: without it, a party
that observes `Pk₀` from a publicly-served member `SpendRecord` inside a
`BatchBundle` (bundles are content-addressed and `k = 3`-replicated by
§4.6, so `Pk₀` is publicly observable to anyone fetching them) could
publish a malicious `Invoice` claiming the legitimate `recipient`/`pk0`
but with #strong[their own] `ivpk`/`op_pubkey`, and the sender would
encrypt the bundle to the attacker. `addr_sig` makes that forgery
infeasible under BIP-340 EUF-CMA. The operational consequence is that
#strong[issuing an `Invoice` requires the wallet] (`sk₀` is
SPEND-branch, wallet-only) --- the same custody boundary that already
governs sending. The per-issuance `sig` remains because the recipient\'s
`op` is the online actor that signs the wire-format event the relay
sees; it is not redundant with `addr_sig` operationally (one offline,
one online).

When no `Invoice` is available, a recipient #strong[MAY] publish the
same `{pk0, ivpk, op_pubkey, relays}` tuple as a #strong[profile] event
(a replaceable Nostr event) carrying the same `addr_sig` over an
`invoice_message` computed with the #strong[profile-fixed values]
`amount = 0`, `asset_id` = the all-zero 32-byte value, and `memo` =
empty --- so the sender and recipient derive a #strong[bit-identical]
preimage and the signature verifies; any other values for these three
fields #strong[MUST NOT] be used in a profile event --- discoverable on
well-known relays by `op_pubkey`. The sender verifies the profile by the
same three-check rule above. Resolution by `address` alone, with
#strong[no] recipient-published record carrying `addr_sig`, is
#strong[not] supported.

Each published delivery event carries the per-coin `detect_tag` (§4.2,
#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3])
in its plaintext payload so the recipient can locate it by scan rather
than by trial-decrypting every event.

=== 4.4 Note discovery
<44-note-discovery>
A recipient (or its always-on node, holding `ivk`) finds its own
incoming bundles as follows:

+ Derive the detection key `dk = HKDF("zkCoins/v1/DetectKey", ivk)`
  (#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3]).
+ Pull candidate delivery events from its relay set. The relay
  #strong[cannot] pre-filter for the recipient (it lacks `dk`), so the
  recipient --- having `dk` --- performs the match itself: for each
  candidate\'s published `epk` it recomputes
  `Hc("zkCoins/v1/DetectTag", dk ‖ epk)` and checks it against the
  event\'s `detect_tag`. A match selects the event as the recipient\'s;
  a non-match is discarded after one Poseidon hash, with no AEAD
  attempt.
+ For each matched candidate, derive
  `K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk)` where
  `ss = ECDH(ivk, epk)`
  (#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3]),
  fetch the blob by `blob_id`, and #strong[trial-decrypt] with `K_tx`.
  Successful NIP-44 authentication confirms the coin is the
  recipient\'s.
+ Verify the decrypted bundle against Bitcoin (§4.5) before accepting
  it.

#strong[Privacy tradeoff (normative note).] Because every coin uses a
fresh `epk`, each recipient\'s events carry #strong[all-distinct]
`detect_tag`s
(#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3]):
a tag does not link two of one recipient\'s coins, and a relay that
lacks `dk` can #strong[neither] filter for the recipient #strong[nor]
correlate the recipient\'s events. The residual cost is therefore not
linkability but #strong[bandwidth]: detection is not server-side
filterable, so the recipient pulls the candidate set in full and pays
one cheap Poseidon hash per scanned event. #strong[Fuzzy message
detection] (probabilistic per-coin tags with tunable false-positive
rate) is an #strong[OPTIONAL scan-efficiency upgrade] that lets a relay
return a smaller candidate set without learning who the recipient is; it
changes only the tag computation and the scan filter and #strong[MUST]
leave every other interface in this page unchanged. It does #strong[not]
repair a linkability the deterministic scheme does not introduce.

=== 4.5 Recovery
<45-recovery>
The seed is the #strong[only] required backup
(#link("/requirements")[Requirement 6]). Recovery has two paths, in
strict priority order:

- #strong[Primary --- the node operator\'s own backup.] A node
  #strong[SHOULD] maintain its own durable backup of its local state and
  bundle store; restoring from it is the normal path and requires no
  network and no re-verification beyond integrity checks.
- #strong[Emergency fallback --- network reconstruction.] After total
  loss of local data, the complete spendable state is rebuilt from the
  seed, the public Bitcoin chain, and the bundles replicated across
  other nodes (§4.6).

The fallback procedure is fully deterministic and trustless:

+ #strong[Re-derive keys.] From the seed, re-derive the account root `A`
  and thereby `ivk`, `dk`, `ovk`, `op`, the nullifier key `nk`, and the
  spend keys (#link(<12-key-hierarchy>)[Foundations §1.2]). This alone
  restores the address/identity, decryption ability, and the
  deterministic detection tags.
+ #strong[Rebuild the public index from Bitcoin + bundles.] Scan Bitcoin
  for zkCoins `BatchInscription`s, fetch each batch\'s `BatchBundle`
  from the relay mesh
  (#link(<46-data-availability--replication-factor-k>)[§4.6]) by its
  `bundle_locator`, verify the publisher\'s `AggregateBatchProof`, and
  apply the inscribed `prev_root → new_root` transition. The resulting
  global #strong[nullifier accumulator]
  (#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6])
  is derived from confirmed Bitcoin data plus content-addressed,
  recursively verifier-checkable bundles, and requires no trust in any
  peer. Because each member `SpendRecord` inside a bundle carries the
  spender\'s rotating public key `Pkᵢ` and the operator\'s seed
  re-derives the spender side of all its own past transitions, the
  operator can privately recognise its #strong[own] member SpendRecords
  (the publisher and any third party cannot link them --- they see only
  the publisher\'s identity on-chain) and so reconstruct the skeleton of
  its own activity. Recovery is therefore conditional on bundle DA: if
  every replica of a past `BatchBundle` has been lost, the operator can
  still verify the on-chain root continuity but cannot reconstruct the
  member set of that batch on its own --- in practice the `k = 3`
  replication and operator backups
  (#link(<46-data-availability--replication-factor-k>)[§4.6]) make this
  a rare degraded case.
+ #strong[Pull candidate bundles.] Query the network\'s capability-gated
  pull endpoints (#link(<5--access--explorer>)[Access & Explorer]) by
  proving ownership (sign a challenge with the identity key) or by
  presenting the deterministic `detect_tag` set from `dk`. Cooperating
  nodes return every bundle matching the proof/tags. The network here is
  an #strong[untrusted blob cache].
+ #strong[Verify each bundle against Bitcoin.] For every returned
  bundle, the node #strong[MUST] independently verify the recursive
  per-account proof, the coin\'s inclusion in the committed
  `output_coins_root`, that the root is anchored in a `SpendRecord`
  whose containing `BatchInscription` is in state `completed`
  (#link(<310-transaction-states>)[On-chain §3.10]) (for a non-batched
  mint, that the mint\'s recursive proof verifies directly), and that
  the coin is unspent against the nullifier accumulator at `NAV(tip)`
  per #link(<37-the-nullifier-accumulator>)[On-chain §3.7]
  (#link(<14-identifiers-and-hashes>)[Foundations §1.4],
  #link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]).
  A bundle failing any check #strong[MUST] be discarded. A node can only
  #strong[withhold], never forge --- correctness is guaranteed by the
  chain, the per-spender recursive proofs, and the publisher\'s
  `AggregateBatchProof`s.
+ #strong[Rebuild `AccountState` and balances.] From the accepted
  incoming and outgoing coins, reconstruct the per-asset `balances`, the
  coin-history SMT, `current_pubkey`, and `send_counter`
  (#link(<15-core-data-structures>)[Foundations §1.5],
  #link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]).

The coin #strong[values] of incoming coins are choices others made; they
exist only in the `CoinProof` bundles and cannot be derived from the
seed or a hash. They come back solely through step 3 --- which is why
the data-availability guarantee of §4.6 is a precondition for the
emergency path. Likewise, the #strong[member identity] of a past batch
(which spenders\' SpendRecords were aggregated) exists only inside the
`BatchBundle`, so accumulator reconstruction beyond the on-chain root
chain depends on the same DA guarantee. Asset ids fall out of the coins
themselves; only the human-readable asset `name` is external and never
recoverable from the chain.

=== 4.6 Data availability --- replication factor `k`
<46-data-availability--replication-factor-k>
Two off-chain object classes carry the bulk of zkCoins data ---
`CoinProof` bundles (per coin, value-bearing) and `BatchBundle`s (per
publisher batch, accumulator-update-bearing) --- and both are protected
by the #strong[same] replication discipline.

==== CoinProof bundles
<coinproof-bundles>
A `CoinProof` bundle is custody. If every holder drops it before the
recipient (or a recovering owner) fetches it, the coin becomes
unspendable.

==== BatchBundles
<batchbundles>
A `BatchBundle` carries the publisher\'s `AggregateBatchProof` and the
member `SpendRecord`s for one inscribed batch. The on-chain
`BatchInscription`\'s `prev_root → new_root` transition is unverifiable
without the bundle: a scanner that cannot reach any replica cannot admit
the batch and the inscription lingers in state `pending`
(#link(<310-transaction-states>)[On-chain §3.10]). Universal long-term
unavailability of a `BatchBundle` would leave its accumulator transition
forever unconfirmable --- a soft fork of the network into \"nodes that
admitted it before DA loss\" and \"nodes that never could\". The
replication regime below makes that outcome economically and
operationally unlikely.

==== Replication factor `k` (normative)
<replication-factor-k-normative>
- Before a delivery is considered #strong[complete], the relevant blob
  (encrypted `CoinProof` bundle and its delivery event, or a
  `BatchBundle` and its serialised `AggregateBatchProof`) #strong[MUST]
  be replicated to at least `k` #strong[independent] nodes/relays.
  \"Independent\" means distinct operators/hosts; `k` copies on one
  operator do not count.
- The default is #strong[`k = 3`]. Rationale: `k = 3` survives the
  simultaneous loss of any two replicas --- covering single-disk failure
  plus one node being offline during recovery --- without imposing the
  storage and bandwidth cost of higher fan-out. It mirrors the de-facto
  three-way replication used by durable distributed stores. Deployments
  #strong[MAY] raise `k` for higher durability; `k` #strong[MUST NOT] be
  less than 2.
- #strong[For `CoinProof` bundles], the recommended replica set is: the
  recipient\'s own node, the sender\'s own node (retained until ACK,
  §4.2), and at least one additional relay from the recipient\'s
  advertised set --- yielding `k = 3` from parties that each have an
  incentive to retain. A sender #strong[MUST NOT] drop its retained copy
  until #strong[both] a valid ACK (§4.2) and confirmation that the blob
  is held by at least `k` independent replicas.
- #strong[For `BatchBundle`s], the publisher acts as the original holder
  and is responsible for distributing the bundle to at least `k − 1`
  independent replicas before broadcasting the `BatchInscription`. The
  recommended replica set is: the publisher\'s own node, the
  publisher\'s advertised peer-publisher set (at least one peer), and at
  least one well-known relay or archival service --- yielding `k = 3`. A
  publisher SHOULD use a `dispersal` push pattern (broadcast the bundle
  to all `k − 1` peers in parallel, await acknowledgement from at least
  `k − 2` before broadcasting the inscription) so that admission
  liveness is decoupled from any single replica\'s reachability. A
  publisher #strong[MUST NOT] broadcast the `BatchInscription` until at
  least `k` independent holders (including itself) confirm they hold the
  bundle; broadcasting earlier leaves the inscription unverifiable and
  risks `failed` admission once the bundle-fetch deadline elapses at
  scanning nodes.
- #strong[Long-term retention by scanners (normative).] A `CoinProof`
  bundle has a natural long-term holder (the recipient --- it is the
  recipient\'s custody), but a `BatchBundle` does not, so this rule
  supplies one: every node that admits a `BatchInscription` and verifies
  its `BatchBundle` (§3.6 steps 5--8) #strong[MUST] retain that bundle
  as part of its own data store, and #strong[SHOULD] serve it on
  request, indefinitely (or until protocol-defined pruning rules become
  available in a future version). A node that prunes an admitted bundle
  #strong[MUST] first verify that at least `k = 3` independent peer
  nodes still hold it. The practical replica count of any admitted
  `BatchBundle` therefore grows monotonically with the size of the
  scanning-node network, so universal long-term unavailability of an
  admitted bundle requires the simultaneous loss of every honest scanner
  that ever processed it --- a failure mode far stronger than a single
  publisher dropping a bundle after broadcast.

==== Safety invariant (normative)
<safety-invariant-normative>
Custody safety #strong[MUST NOT] depend on availability. Losing
availability impairs #strong[recovery] (a bundle may be unrecoverable)
but can #strong[never] cause #strong[theft]: an unavailable `CoinProof`
bundle cannot be spent by anyone else, an unavailable `BatchBundle`
cannot retroactively credit a forged spend, and a returned bundle is
only accepted after verification against Bitcoin (§4.5,
#link(<36-chain-scanning>)[On-chain §3.6]). Availability is a liveness
property, never a safety property.

=== 4.7 Metadata and privacy tradeoffs
<47-metadata-and-privacy-tradeoffs>
- #strong[What a relay learns.] Only that an opaque, gift-wrapped,
  NIP-44-encrypted event was stored at some time --- not sender,
  recipient, amount, asset, or proof (§4.1--§4.2). Because each node is
  a full relay, coin-delivery events blend into ordinary Nostr traffic
  (cover traffic).
- #strong[Detection scan vs. linkability.] Per-coin `detect_tag`s are
  all-distinct (fresh `epk` per coin, §4.4), so a relay cannot link or
  filter for the recipient. The genuine residual cost is
  #strong[bandwidth]: detection runs recipient-side over the candidate
  set. The OPTIONAL fuzzy-message-detection upgrade reduces that
  bandwidth.
- #strong[Network presence.] Operating a relay exposes the operator\'s
  network address (IP) to peers. Operators that require location privacy
  #strong[SHOULD] run the relay behind an anonymity network (e.g. a Tor
  hidden service).
- #strong[Recovery disclosure.] Pulling by `detect_tag` reveals the
  tag-set to the serving node; pulling by ownership proof reveals the
  requester\'s identity to that node. Both are consensual, scoped to the
  requester\'s own data, and never expose spend authority.

Continue to #link(<5--access--explorer>)[Access & Explorer] for the
capability-gated pull endpoint, view grants, and the shareable
confirmation links that build on this transport layer.

== 5 · Access & Explorer
<5--access--explorer>
#quote(block: true)[
#emph[In one sentence: the three ways an account can disclose its data
on purpose --- one transaction, a balance, or the whole history --- and
the self-hostable explorer that renders each, always cryptographically
verifiable against Bitcoin, never trust-based.]
]

This page specifies how Private data
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6])
is released by a node, the structure of viewing capabilities, and the
explorer that renders them. All primitives, keys, identifiers, and tags
are defined in #link(<1--foundations-normative>)[Foundations] and used
here unchanged. Normative keywords follow RFC 2119.

Recall the relevant key material from
#link(<12-key-hierarchy>)[Foundations §1.2]: a subject\'s identity is
its `address = H(Pk₀)` (#link(<14-identifiers-and-hashes>)[§1.4]); the
#strong[operational key] `op` is the node-held Nostr/identity key that
signs grants and acknowledgements but cannot spend; `ivk`/`ovk` are the
viewing keys; and `K_tx`
(#link(<13-per-coin-keys-note-encryption--detection>)[§1.3]) is the
per-coin note key that decrypts exactly one coin. The on-chain
`BatchInscription` (#link(<14-identifiers-and-hashes>)[§1.4],
#link(<31-the-on-chain-object>)[§3.1]) is the only object written to
Bitcoin and the integrity anchor for everything below; the per-spender
`SpendRecord` lives inside the publisher\'s off-chain `BatchBundle`
(#link(<46-data-availability--replication-factor-k>)[§4.6]).

#strong[Disclosure is holder-initiated and account-granular.] All
disclosure is opt-in: absent one, #link("/requirements")[Requirement 2]
holds in full. Because accounts and addresses are one-to-one
(#link(<12-key-hierarchy>)[Foundations §1.2]), every account-level
disclosure covers the #strong[whole] account; there is no \"one address
out of many.\" To keep some activity outside a disclosure, it must live
in a #strong[separate account]. This page specifies the disclosure
spectrum, narrowest first (#link("/requirements")[Requirement 9]):

#table(
    columns: 4,
    align: (auto,auto,auto,auto,),
    table.header([Tier], [Reveals], [Mechanism], [Section],),
    table.hline(),
    [One transaction], [exactly 1 payment], [bearer per-coin capability
    `zkview`], [#link(<53-per-coin-view-capability>)[§5.3],
    #link(<56-shareable-confirmation-links>)[§5.6]],
    [Balance (history-private)], [one asset\'s balance, no history], [ZK
    balance attestation (a proof, no
    key)], [#link(<57-balance-attestation-history-private>)[§5.7]],
    [Full account history], [every transaction of the account], [view
    grant `zkgrant` (revocable) #strong[or] bearer account view key
    `zkavk`], [#link(<58-address-view-full-history>)[§5.8]],
)

Every disclosure is #strong[read-only] (never the spend branch) and
every disclosed fact is #strong[verifiable against Bitcoin], never
asserted by a node or explorer.

=== 5.1 Capability-gated pull
<51-capability-gated-pull>
Every node exposes exactly one endpoint for Private data --- the
#strong[pull endpoint] --- and it serves a record only after the
requester demonstrates a cryptographic capability. The endpoint
#strong[MUST NOT] release any Private payload (coin plaintext, amounts,
parties, balances, proofs, ciphertext) on an unauthenticated request,
and #strong[MUST] restrict the response to the data covered by the
presented capability. The pull endpoint recognises exactly two
#strong[authorisation] capabilities --- the #strong[ownership proof] and
the #strong[view grant] --- and #strong[no others].

The bearer view capabilities (`zkview`,
#link(<53-per-coin-view-capability>)[§5.3]\; `zkavk`,
#link(<58-address-view-full-history>)[§5.8]) and the balance attestation
(#link(<57-balance-attestation-history-private>)[§5.7]) are #strong[not]
server authorisations: they are client-side decryption secrets, or a
self-contained proof, that an explorer applies to bundles it obtains
from the relay mesh
(#link(<4--transport--recovery>)[Transport & Recovery]) or by
self-hosted scanning. They never cause a node to release a Private
record it would not otherwise serve; they widen what the #emph[holder of
the secret] can read from already-public, encrypted material.

The endpoint #strong[MUST] be unauthenticated only for the Public
projection of #link(<55-two-explorer-modes>)[§5.5] (on-chain
`BatchInscription`s with their `prev_root → new_root` transitions and
publisher identities), which carry no Private data by construction.

A request proceeds as a challenge--response so that captured transcripts
cannot be replayed:

```
1. Requester → Node :  PullRequest { subject: address, scope }
2. Node → Requester :  Challenge   { nonce: 32 random bytes,
                                     expiry: unix_seconds, // node MUST reject after expiry
                                     domain: "zkCoins/v1/PullChallenge" }
3. Requester → Node :  PullProof   { one of (a) OwnershipProof | (b) GrantProof }
4. Node → Requester :  the Private records matching `subject` within `scope`,
                       or an error (capability invalid / scope exceeded / challenge expired).
```

The signed challenge message is
`chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry)` (`H` and input
ordering per
#link(<14-identifiers-and-hashes>)[Foundations §1.4, §1.7]). `nonce`,
`chan_bind`, and `subject` are #strong[32 bytes] each, `expiry` is an
#strong[8-byte big-endian] Unix timestamp, and `domain` is the constant
tag above --- so the concatenation is unambiguous. A node #strong[MUST]
reject a `PullProof` whose `nonce` it did not issue or has already
consumed, whose `expiry` has passed, or whose recomputed `chal` does not
match, and it #strong[MUST] compare `chal` in #strong[constant time].

#strong[`chan_bind` --- binding the proof to one server (normative).]
`chan_bind` records #emph[which server the requester authenticated], so
a captured proof cannot be replayed against a different node. It is a
#strong[fixed 32-byte] value the requester derives from the connection
#strong[it] established --- #strong[never] a value the node sends:

- #strong[Clearnet (TLS):]
  `chan_bind = H("zkCoins/v1/PullHost" ‖ host)`. `host` is the
  #strong[canonical authority] the requester connected to and whose TLS
  certificate it validated: lowercase ASCII, an internationalised name
  in its #strong[A-label (punycode)] form, any trailing dot removed, and
  `":"port` appended #strong[only] when the port is not the default 443.
  Requester and node #strong[MUST] canonicalise identically.
- #strong[Tor:] `chan_bind` is the #strong[32-byte Ed25519 public key]
  of the node\'s #strong[v3] onion service (the key the `.onion` address
  encodes, #strong[not] the Base32 string). v2 onion services are
  insecure and #strong[MUST NOT] be used.

To accept a proof, the node recomputes `chan_bind` for #strong[each
hostname it authoritatively serves] on that endpoint --- the public
names under which requesters reach it (and its onion key, if any) ---
and accepts only if the requester\'s `chan_bind` matches one of them. It
#strong[MUST NOT] derive `host` from attacker-influenceable request
metadata such as a forwarded `Host` header. Because the binding is the
#strong[host the requester already verifies], the protocol needs
#strong[no] node-specific key material and no node identity beyond the
URL itself; node portability (#link("/requirements")[Requirement 10]) is
unaffected.

This is what lets a requester safely query a #strong[foreign or public]
node: a malicious node `X` cannot relay a requester\'s `OwnershipProof`
to another node `Y` (a proof-forwarding / man-in-the-middle attack),
because the requester binds to the host it dialed (`X`) and `Y`
recomputes a different `chan_bind`. The only residual case --- `X` and
`Y` behind #strong[one] hostname and certificate --- is a single TLS
terminator already serving both and already seeing their plaintext; a
finer binding would not change that trust boundary.

#strong[Transport (normative).] The pull endpoint #strong[MUST] be
served only over #strong[TLS 1.3 or TLS 1.2] on a hostname the requester
can verify, #strong[or] as a #strong[Tor v3 onion service]. Plain HTTP,
and any transport that does not authenticate the host, #strong[MUST NOT]
be accepted, because `chan_bind` would then bind to nothing.

#strong[Deployment note (non-normative).] Binding to the host rather
than to a TLS session secret is deliberate: it survives
#strong[TLS-terminating reverse proxies and CDNs] --- the node
recomputes `chan_bind` from its own hostname regardless of who
terminates TLS --- and it is computable by #strong[browser-based
wallets], which cannot read TLS session material such as an RFC 9266
`tls-exporter` value. A node that terminates TLS itself #strong[MAY]
additionally bind to the `tls-exporter` value (RFC 9266; TLS exporter
label `EXPORTER-Channel-Binding`, empty context, 32 bytes) for a
tighter, per-session binding; over TLS 1.2 it #strong[MUST] negotiate
the Extended Master Secret extension (RFC 7627), without which
`tls-exporter` is unsound. This binding is an #strong[optional]
hardening and #strong[MUST NOT] be required, because it is unavailable
behind a TLS-terminating intermediary or to a browser client.

==== \(a) Ownership proof
<a-ownership-proof>
The requester proves it controls the subject\'s identity by signing the
challenge with the subject\'s #strong[initial spend key] `sk₀` (the key
that fixes `address`,
#link(<14-identifiers-and-hashes>)[Foundations §1.4]):

```
OwnershipProof = {
  subject    : address,
  public_key : Pk₀,                          // x-only, 32B
  signature  : BIP-340(sk₀, chal)            // 64B
}
```

The node #strong[MUST] verify both `H(Pk₀) == subject` and the BIP-340
signature over `chal`, and only then release every Private record whose
recipient is `subject`. This is also the #strong[recovery] path; the
requester #strong[MAY] instead present its seed-derived `detect_tag` set
(#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3])
to enumerate its own coins without revealing `Pk₀` (see
#link(<4--transport--recovery>)[Transport & Recovery]). Ownership grants
the #strong[subject\'s full] Private view; it is the one self-disclosure
that requires the spend branch.

==== \(b) Delegated view grant
<b-delegated-view-grant>
The requester presents an `op`-signed grant (the #strong[view grant] of
#link(<52-view-grant>)[§5.2]) authorising some grantee key `D`, and
signs the challenge with `D`:

```
GrantProof = {
  grant      : ViewGrant,                     // Bech32m `zkgrant`, see §5.2
  grantee_pk : D,                             // x-only, 32B; equals grant.grantee
  signature  : BIP-340(d, chal)              // proves possession of D's secret d
}
```

The node #strong[MUST] (1) verify the grant\'s `op` signature against
the subject\'s published `op` pubkey, (2) verify
`grantee_pk == grant.grantee` and the BIP-340 signature over `chal`, (3)
confirm the grant has not expired and is not revoked, and (4) release
#strong[only] records inside the grant\'s scope. The node makes
#strong[no] policy decision: it enforces the subject\'s signed grant,
which it verifies cryptographically, and #strong[MUST NOT] broaden the
disclosure beyond `scope`.

=== 5.2 View grant
<52-view-grant>
A view grant is a #strong[delegated viewing key]: it permits
#emph[seeing, not spending]. It binds a grantee key to a scope and is
signed by the subject\'s operational key `op`. The grant #strong[MUST
NOT] contain, and a node #strong[MUST NOT] accept it as authority over,
any spend key.

```
ViewGrant = {
  version    : 1,
  subject    : address,                       // whose data is disclosed
  grantee    : D,                             // x-only pubkey authorised to view (32B)
  scope      : {
    asset_ids  : [asset_id] | "*",            // exact AssetId set ([Foundations §1.4]); "*" = all assets
    not_before : unix_seconds,                // 0 = no lower bound
    not_after  : unix_seconds,                // inclusive upper bound on the data window
    expiry     : unix_seconds                 // grant unusable after this instant
  },
  nonce      : 16 random bytes,               // makes grant_id unique
  signature  : BIP-340(op, grant_message)     // 64B; binds all fields above
}

grant_message = H( "zkCoins/v1/Grant" ‖ version ‖ subject ‖ grantee
                 ‖ asset_ids ‖ not_before ‖ not_after ‖ expiry ‖ nonce )
grant_id      = H( grant_message )            // stable handle for revocation
```

The signing tag `"zkCoins/v1/Grant"` is the reserved `Grant` context
from #link(<11-cryptographic-primitives>)[Foundations §1.1]\; `H` and
the input ordering are per
#link(<14-identifiers-and-hashes>)[Foundations §1.4, §1.7].

#strong[Encoding.] A `ViewGrant` is serialised in the field order above
and encoded as #strong[Bech32m] with HRP #strong[`zkgrant`]
(#link(<17-encoding-serialization-and-the-reference-instantiation>)[Foundations §1.7]),
so it is never confused with an `address` (`zk`) or a per-coin
capability (`zkview`). A node #strong[MUST] reject a grant under any
other HRP.

#strong[Revocation is forward-only.] A subject revokes a grant by
instructing the node(s) it controls to refuse any `GrantProof` carrying
that `grant_id`. Each node #strong[MUST] maintain a revocation set and
#strong[MUST] reject a revoked grant at step (3) of
#link(<b-delegated-view-grant>)[§5.1(b)]. Revocation #strong[MUST NOT]
be claimed to undo prior disclosure: data already released under the
grant, and any independent copy the grantee retained, is permanently
outside the subject\'s control --- #strong[already-disclosed data cannot
be un-seen]. A node a subject does not control cannot be compelled to
honour a revocation; therefore grants #strong[SHOULD] carry a short
`expiry` rather than relying on revocation.

=== 5.3 Per-coin view capability
<53-per-coin-view-capability>
The narrowest capability discloses a single coin. It is the per-coin
note key `K_tx` from
#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3],
scoped to exactly one coin: it decrypts that coin\'s `ciphertext` and
#strong[nothing else], and confers no spend authority and no view of any
other coin, balance, or transaction.

A per-coin view capability is encoded as #strong[Bech32m] with HRP
#strong[`zkview`]
(#link(<17-encoding-serialization-and-the-reference-instantiation>)[Foundations §1.7]):

```
zkview = Bech32m( HRP = "zkview", data = K_tx )      // 32-byte symmetric note key
```

Unlike a `ViewGrant`, a `zkview` carries no signature: it is a
#strong[bearer] secret whose mere possession authorises decryption of
its one coin. It is the capability embedded in a shareable confirmation
link (#link(<56-shareable-confirmation-links>)[§5.6]).

=== 5.4 Capabilities at a glance
<54-capabilities-at-a-glance>
#table(
    columns: 6,
    align: (auto,auto,auto,auto,auto,auto,),
    table.header([Capability], [Encoding
      (HRP)], [Authorises], [Scope], [Bearer?], [Revocable],),
    table.hline(),
    [Ownership proof], [--- (signed challenge)], [full Private view of
    the subject], [whole account], [no --- needs `sk₀`], [n/a],
    [View grant], [Bech32m `zkgrant`], [delegated viewing], [`asset_ids`
    × time window], [no --- needs grantee key `D`], [forward-only],
    [Per-coin capability], [Bech32m `zkview`], [decrypt one
    coin], [exactly one coin], [#strong[yes] --- `K_tx` is the
    secret], [no (forward-only by nature)],
    [Account view key], [Bech32m `zkavk`], [read full history], [whole
    account], [#strong[yes] --- `ivk‖ovk` is the secret], [no
    (forward-only by nature)],
    [Balance attestation], [--- (self-contained proof)], [confirm one
    balance], [one asset, point-in-time], [n/a --- a proof, not a
    key], [n/a],
)

The two #strong[account-wide] capabilities --- ownership proof and
account view key --- cover the whole account by construction
(#link(<12-key-hierarchy>)[Foundations §1.2]); there is no narrower
address-level form. For an account-wide disclosure that is
#strong[retractable], use a scoped `zkgrant`
(#link(<52-view-grant>)[§5.2]) rather than the irrevocable bearer
`zkavk`.

=== 5.5 Two explorer modes
<55-two-explorer-modes>
The same node data
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]:
plaintext leaves Private, roots Public) is presented in two modes that
differ #strong[only] in the capability supplied.

#strong[Public mode.] No capability is presented. The explorer renders
#strong[only] Public on-chain data: the stream of `BatchInscription`s
with their `prev_root → new_root` transitions and publisher identities,
the global nullifier accumulator tracked through them
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6],
#link(<37-the-nullifier-accumulator>)[On-chain §3.7]), and aggregate
counts (number of batches, batch admission rate, accumulator size), with
signature- and aggregate-proof-checks against Bitcoin and the relay-mesh
`BatchBundle`s. It #strong[MUST NOT] display amounts, `asset_id`s or
asset names, balances, addresses, senders, recipients, individual member
SpendRecords\' counts, or anything sourced from a `CoinProof` bundle ---
none of which are derivable from Public data. (A publisher\'s identity
is the only on-chain link; per-spender activity remains hidden behind
the bundle boundary.)

#strong[Authorised mode.] The viewer supplies the subject\'s signed
#strong[view grant] (#link(<52-view-grant>)[§5.2]) (or, for self-view,
an ownership proof). The explorer then drives the pull endpoint of
#link(<51-capability-gated-pull>)[§5.1] on the viewer\'s behalf and
renders that subject\'s real transactions #strong[within the grant\'s
scope] --- and nothing beyond it. Disclosure stays under the subject\'s
control: the subject chooses the grantee, the asset set, and the time
window. The explorer is a client of the capability model; it gains
#strong[no] privilege the presented capability does not already confer.

=== 5.6 Shareable confirmation links
<56-shareable-confirmation-links>
This is the case of #link("/requirements")[Requirement 9]: a sender (A)
who paid a recipient (B) hands B --- or a third party --- a link that
confirms exactly that one payment, #emph[\"here is verifiable proof I
sent it.\"] The link carries just two things: #strong[where to fetch]
the one coin\'s bundle, and #strong[the key to read it]. Everything else
--- which on-chain record, the amount, the proof --- is recovered from
the bundle and verified against Bitcoin.

#strong[Carrying the link secret (normative --- governs the shareable
links of §5.6--§5.8).] Each shareable link carries a #strong[bearer
secret] (a `zkview` `K_tx`, a `zkavk`, or a balance proof). It
#strong[MUST] be transported so the secret never reaches a server:

- #strong[Custom-scheme form (canonical, preferred):] a `zkcoins:…` URI
  is dispatched #strong[locally] by a registered handler
  (wallet/explorer app); the secret never enters a network request.
  Carrying it in the URI path is therefore safe.
- #strong[HTTPS fallback:] the secret --- and #strong[every] other link
  component after the app route (in §5.6 the bundle locator; in §5.7 the
  address, `asset_id` and proof; in §5.8 the address; plus any optional
  holder hint) --- #strong[MUST] be placed in the URL #strong[fragment]
  (`#…`); the HTTPS path is only the app route (e.g. `/tx`) and the link
  #strong[MUST] carry #strong[no query string]. A browser never
  transmits the fragment to the server, so the secret appears in
  #strong[no] server log, #strong[no] proxy --- including a
  TLS-terminating one --- and #strong[no] `Referer` header. The explorer
  #strong[MUST] be a #strong[client-side] application that reads the
  fragment, fetches the bundle from the relay mesh, and #strong[decrypts
  and verifies entirely on the client]. The routes that serve shareable
  links #strong[MUST NOT] be server-rendered from the link\'s contents;
  static assets plus client-side hydration is the conforming shape (the
  server cannot receive the fragment in any case). A conforming explorer
  #strong[MUST NOT] transmit a `K_tx`, `zkavk`, or balance proof to any
  server. A conforming explorer #strong[MUST] apply
  `Referrer-Policy: no-referrer` --- via the HTTP response header, or
  the `<meta name="referrer" content="no-referrer">` fallback where
  header control is unavailable. Because the secret travels in the
  fragment --- which is never included in a `Referer` regardless ---
  this is defense-in-depth, not the primary protection.
- #strong[Holder-hint parse rule (normative).] An optional holder hint,
  if present, is the #strong[final] fragment component, written
  `;h=<locator>`\; its `<locator>` value #strong[MUST] be
  percent-encoded so it contains no `/`, `:`, or `;`. A parser splits
  the fragment on the first literal `;h=`: everything before is the
  link\'s components, everything after is the percent-encoded locator.
  The hint is an optimisation only and carries no secret.
- #strong[Scope of \"never reaches a server\" (normative).] The fragment
  keeps the secret and all link components from the #strong[explorer
  (app) host] and every HTTP intermediary (server logs, proxies,
  `Referer`). It does #strong[not] hide (a) that the #strong[relay
  serving the bundle learns `blob_id`] when the bundle is fetched, nor
  (b) the #strong[DNS/SNI metadata] revealing which explorer host was
  contacted. Both are addressed only by self-hosting the explorer/relay
  or using Tor --- so the \"never reaches a server\" guarantee is scoped
  to the #strong[explorer/app host and HTTP intermediaries], not the
  relay.
- An explorer #strong[SHOULD] be self-hostable and #strong[MAY] be
  served as a Tor onion service, so even the host metadata (DNS/SNI) is
  the operator\'s own.

#strong[Residual (non-normative).] On an untrusted device the fragment
still persists in local browser history and memory; no link scheme
protects a compromised endpoint. A bearer link #strong[SHOULD NOT] be
opened on a device the holder does not trust; if unavoidable, use a
private/ephemeral session and clear history afterward.

#strong[Link grammar.] A confirmation link is two Bech32m values --- a
content #strong[locator] and a per-coin #strong[view capability] ---
under a host-independent URI:

```
zkcoins:tx/<bundle>/<view>

  <bundle> = Bech32m( HRP "zkbid",  blob_id )    ; blob_id = H(ciphertext) of the CoinProof bundle
                                                 ; ([Transport & Recovery §4.2](#42-bundle-delivery));
                                                 ; content-addressed, so ANY relay holding the blob
                                                 ; serves it — no node-specific locator is needed
  <view>   = Bech32m( HRP "zkview", K_tx )       ; the per-coin note key ([§5.3](#53-per-coin-view-capability));
                                                 ; decrypts exactly one coin; the bearer secret of the link
```

The `/` delimiter is unambiguous: a Bech32m string contains neither `/`
nor `:`. The two HRPs `zkbid` and `zkview`
(#link(<177-bech32m-and-bitcoin-conventions>)[Foundations §1.7.7]) are
distinct, so a viewer #strong[MUST] reject a value presented under the
wrong HRP and can never confuse the locator for the key.

An explorer #strong[MAY] render the same pair as a clickable web URL ---
`https://<explorer-host>/tx#<bundle>/<view>` --- where `/tx` is only the
app route and the `<bundle>`/`<view>` pair lives in the URL
#strong[fragment] (per the link-transport rules above, so the secret
never reaches the server). The host is only a renderer: any instance is
equivalent and self-hostable, and a viewer #strong[MUST] treat the
`<bundle>`/`<view>` pair, not the host, as authoritative. A holder hint
#strong[MAY] be appended #strong[inside the fragment] as
`…#<bundle>/<view>;h=<locator>` (`op:<op-pubkey>` or `@<relay-url>`) to
speed resolution, parsed per the holder-hint parse rule above; it
travels in the fragment, #strong[never] as a query or path component, so
it is never sent to any server. It is an optimisation only and is never
required.

#strong[Flow.] The viewer (an explorer that is neither A nor B, or one
the viewer self-hosts):

+ #strong[Fetch] the `CoinProof` bundle by `blob_id` from the relay mesh
  (#link(<42-bundle-delivery>)[Transport & Recovery §4.2, §4.6]) --- any
  of the `k` replicas holding the blob answers --- and verify
  `H(ciphertext) == blob_id` (content-addressed self-check).
+ #strong[Decrypt] the coin with `<view>` (`K_tx`); render the single
  transaction --- #strong[amount, asset, time, status] (the
  #link(<310-transaction-states>)[On-chain §3.10] transaction state).
+ #strong[Verify against Bitcoin.] Check the coin\'s inclusion in
  `output_coins_root`\; locate the spender\'s `SpendRecord` carrying
  that `ocr` inside the publisher `BatchBundle` it was batched into,
  fetch the corresponding `BatchInscription` (via the bundle\'s
  `bundle_locator`), and confirm the inscription is in state
  #strong[`completed`]
  (#link(<310-transaction-states>)[On-chain §3.10]); verify the
  spender\'s recursive validity proof
  (#link(<14-identifiers-and-hashes>)[Foundations §1.4, §1.5]) and
  (optionally, for full chain-anchor verification) the publisher\'s
  `AggregateBatchProof` (#link(<22-proof-types>)[§2.2]). For a coin
  produced by a #strong[non-batched mint]
  (#link(<231-mint--issuance>)[§2.3.1]), there is no `BatchInscription`
  to anchor against; the explorer instead verifies the mint\'s
  `InitialProof` directly and renders the #strong[`mint-verified`]
  status (#link(<310-transaction-states>)[§3.10]) --- the user MUST be
  shown this status as distinct from `completed`, so they understand the
  coin has no on-chain anchor. The viewer trusts #strong[Bitcoin and the
  proofs --- never the explorer\'s assertion].

#strong[Properties.]

- #strong[Bearer.] Whoever holds the link can view that one transaction;
  `K_tx` is the secret. `blob_id` is a public locator that reveals
  nothing without `K_tx`. The link #strong[MUST] travel over a channel
  the sender trusts.
- #strong[Scoped.] It discloses that single transaction in full and
  #strong[nothing else] --- no other transactions, no balances, no
  counterparties beyond that payment, and no spend authority. It does
  reveal `coin.recipient` (B\'s address) for #emph[this] payment;
  per-relationship unlinkability is an account choice
  (#link(<12-key-hierarchy>)[Foundations §1.2]).
- #strong[Availability.] Because the locator is
  `blob_id = H(ciphertext)`, #strong[every] replica that holds the blob
  can serve it
  (#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]);
  confirmation never hinges on A --- or any specific node --- being
  online.
- #strong[On-chain privacy intact.] Neither `blob_id` nor `K_tx` ever
  appears on Bitcoin; #link("/requirements")[Requirement 2] is
  unaffected.
- #strong[Length.] Two 32-byte values in Bech32m make a fixed, compact
  link; the floor is the 256-bit `K_tx`, which is the access secret and
  cannot be shortened.

The explorer is a #strong[self-hostable presentation layer] and
#strong[MUST NOT] be a trusted authority: every figure it shows is
independently verifiable against Bitcoin and the proof by the viewer.

=== 5.7 Balance attestation (history-private)
<57-balance-attestation-history-private>
The narrowest #emph[account-level] disclosure proves a balance
#strong[without exposing a single transaction]. The subject produces a
zero-knowledge proof that its on-chain-committed account state holds a
given balance of one asset, and hands over only that proof. It reveals
the address, the asset, and the number --- never any coin, counterparty,
amount-flow, or history.

It re-uses the account\'s own recursive validity proof
(#link(<22-proof-types>)[Proofs §2.2]) as the anchor --- there is no
global account-keyed tree to point at
(#link(<16-trees-one-global-structure-one-per-account-structure>)[Foundations §1.6]).
That proof\'s public input `new_account_state_hash` is the hash of the
very `AccountState` being attested. The proof was bound --- by the
spender\'s sign-to-contract nonce --- into a `SpendRecord` carried
inside a publisher `BatchBundle` whose `BatchInscription` is on Bitcoin
in state `completed`. The attestation therefore stands on the
#strong[real, Bitcoin-anchored] state via the bundle and its
inscription; it cannot assert a false one.

```
BalanceAttestation:
  public inputs (revealed):
    { subject : address,
      asset_id,
      balance : B,
      anchor  : { txid, j, block_hash, height,
                  bundle_locator } }                 // BatchInscription + position j of the
                                                     //   SpendRecord inside its BatchBundle

  witness (hidden):
    { AccountState S,
      pi,                                             // the account's recursive validity proof for S
      SpendRecordⱼ,                                   // member j of the BatchBundle at bundle_locator
      R_prime }                                       // sign-to-contract opening of SpendRecordⱼ.signature

  statement (domain tag "zkCoins/v1/BalanceProof"):
    1. S.owner == subject
    2. S.balances[asset_id] == B
    3. pi verifies under the canonical verifier data, and pi.ProofData.new_account_state_hash == ash(S)
    4. SpendRecordⱼ.signature opens, with R_prime, to t = H(R_prime ‖ H(pi.ProofData))
                                                                              (per-spender S2C, On-chain §3.2)
    5. SpendRecordⱼ is the j-th member in serialize(BatchBundle) for which
       Hc("BatchBundle", serialize(BatchBundle)) == bundle_locator
    6. the BatchInscription at (txid, block_hash, height) carries this bundle_locator and is in state
       completed  (Onchain §3.10)
```

The verifier checks the proof and that the `BatchInscription` at
`anchor` (`txid`) --- which contains the `bundle_locator` whose
`BatchBundle` carries `SpendRecordⱼ` at position `j` --- is in state
`completed` (#link(<310-transaction-states>)[On-chain §3.10]) at
`{block_hash, height}`. No node, relay, or explorer is trusted.

#strong[Reference link] (any self-hostable instance is equivalent):

```
zkcoins:balance/<address>/<asset_id>?proof=<attestation>
  — an explorer MAY render it as https://<explorer-host>/balance#<address>/<asset_id>/<proof>
  — the <proof> (attestation) MAY instead be referenced by a content handle when too large for a URL
```

The secret/proof travels in the fragment per the link-transport rules in
#link(<56-shareable-confirmation-links>)[§5.6].

#strong[Properties.]

- #strong[Reveals only the number.] No transaction, coin, counterparty,
  or history --- by construction, the witness never leaves the proof.
- #strong[Point-in-time.] It attests to the balance #emph[as of
  `anchor`]. A later spend does not make the proof false (it remains
  true about that anchor) but no longer reflects the current balance; a
  fresh proof re-attests.
- #strong[Unforgeable for a third party.] Producing it requires the
  account\'s Private `AccountState` (hence its view data); no one can
  attest a balance for an address whose state they cannot see, and the
  statement can only ever prove the true committed value.
- #strong[Read-only.] It carries no key and no spend authority.

=== 5.8 Address view (full history)
<58-address-view-full-history>
The broadest disclosure renders an account\'s #strong[entire]
transaction history. Because accounts and addresses are one-to-one
(#link(<12-key-hierarchy>)[Foundations §1.2]), this #emph[is] an
account-wide view --- there is no \"one address out of many.\" To keep
some activity out of such a view, it must live in a separate account.

There are two forms, with the #strong[same result] but different
control. A subject #strong[SHOULD] prefer (a) when the disclosure should
be retractable or time-boxed, and use (b) only when a simple paste-able
link outweighs irrevocability.

#strong[\(a) Revocable --- view grant.] The subject issues a `ViewGrant`
(#link(<52-view-grant>)[§5.2]) with `scope.asset_ids = "*"` and the
desired time window to a grantee key `D`, and the viewer drives the
Authorised explorer mode (#link(<55-two-explorer-modes>)[§5.5]). It is
#strong[non-bearer] (the viewer must hold `D`\'s secret), scoped, and
#strong[forward-only revocable].

#strong[\(b) Bearer --- account view key.] The subject hands over a
bearer link carrying the account viewing keys themselves:

```
zkavk = Bech32m( HRP = "zkavk", data = ivk ‖ ovk )    // 64B; ivk = incoming, ovk = outgoing
                                                       ; ivk alone (32B) = incoming-only variant

zkcoins:addr/<address>/<zkavk>
  <address> = Bech32m( HRP "zk", H(Pk₀) )   ; the account whose full history is disclosed
  — an explorer MAY render it as https://<explorer-host>/addr#<address>/<zkavk>
  — a holder hint MAY be appended INSIDE the fragment as …#<address>/<zkavk>;h=<locator>, parsed
    per the holder-hint parse rule in §5.6; it travels in the fragment, never as a query or path
    component, so it is never sent to any server. It is an optimisation only. The account's coins
    are found by deriving detect_tags from ivk and scanning the mesh, so no locator is required.
```

The secret travels in the fragment per the link-transport rules in
#link(<56-shareable-confirmation-links>)[§5.6].

#strong[Flow.] The explorer derives the detection key from `ivk`
(#link(<13-per-coin-keys-note-encryption--detection>)[Foundations §1.3]),
finds the account\'s coins by scanning the relay mesh
(#link(<4--transport--recovery>)[Transport & Recovery]) for the derived
`detect_tags` (a `;h=<locator>` fragment hint, if present, only speeds
resolution), decrypts incoming coins with `ivk` and recovers
outgoing-coin plaintext with `ovk`, and renders the full history ---
checking every transaction against Bitcoin (coin inclusion → containing
`BatchBundle` → `completed` `BatchInscription`
(#link(<310-transaction-states>)[On-chain §3.10]) → recursive proof, as
in #link(<56-shareable-confirmation-links>)[§5.6]). For non-batched mint
coins, the chain step is replaced by direct re-verification of the
`InitialProof` and the entry is rendered with `mint-verified` status, as
in §5.6. The explorer is never trusted.

#strong[Properties.]

- #strong[Bearer & irrevocable.] Whoever holds the link sees everything
  `ivk`/`ovk` unlock --- past #strong[and future] --- until the account
  is abandoned. The viewing keys cannot be rotated without moving to a
  new account; there is no revocation. Use form (a) when retractability
  matters.
- #strong[Account-granular.] It reveals the whole account, never a
  subset (#link(<12-key-hierarchy>)[Foundations §1.2]).
  Compartmentalisation = separate accounts.
- #strong[Read-only.] It carries no spend authority: the SPEND branch is
  a hardened sibling of the VIEW branch
  (#link(<12-key-hierarchy>)[Foundations §1.2]) and cannot be derived
  from `ivk`/`ovk`.
- #strong[Verifiable.] Every figure is independently checked against
  Bitcoin and the proof.

== 6 · System Architecture
<6--system-architecture>
#quote(block: true)[
#emph[In one sentence: how node, wallet, and explorer fit together, why
running your own node is the trustless default, and how permissionless
asset creation and node portability come out of the same design.]
]

This page specifies #strong[how the parts fit together]: the three
components (node, wallet, explorer), the wallet↔node relationship, node
portability and multi-node operation
(#link("/requirements")[Requirement 10]), the node\'s external
interfaces, versioned issuance (#link("/requirements")[Requirement 8]),
and the threat model. It builds strictly on
#link(<1--foundations-normative>)[Foundations] --- the key hierarchy
(§1.2), per-coin keys (§1.3), identifiers (§1.4), and the nullifier
accumulator (§1.6) --- and references the sibling sections for the
mechanisms they own rather than re-specifying them.

Normative keywords (#strong[MUST], #strong[MUST NOT], #strong[SHOULD],
#strong[MAY]) are used per RFC 2119.

=== 6.1 Components and responsibilities
<61-components-and-responsibilities>
zkCoins is exactly three components. The split between them is
#strong[packaging, not a trust boundary]: it mirrors the Bitcoin
full-node model (a validator plus a thin key-holder). The one line never
crossed is the SPEND branch --- it lives only in the wallet.

==== The node --- validator, prover, relay, store
<the-node--validator-prover-relay-store>
The node is the always-on workhorse. It #strong[MUST] be runnable as a
single self-contained container with no operator-specific dependencies
(#link("/requirements")[Requirement 7]). Its responsibilities:

- #strong[Bitcoin scanner.] Reads Bitcoin L1, extracts inscribed
  `BatchInscription`s (Foundations §1.4), fetches each batch\'s
  `BatchBundle` from the relay mesh, verifies the publisher\'s
  `AggregateBatchProof`, and applies the inscribed
  `prev_root → new_root` transitions to maintain the global nullifier
  accumulator (Foundations §1.6). Verification is recursively trustless
  --- every artefact is publicly checkable --- and `BatchBundle` data
  availability is the only liveness dependency, mitigated by `k = 3`
  replication. See #link(<3--on-chain-layer>)[On-chain Layer].
- #strong[Prover.] Builds the per-account recursive validity proofs for
  transactions it is asked to construct. A node that #emph[also] acts as
  a publisher additionally builds `AggregateBatchProof`s over collected
  member `SpendRecord`s. See
  #link(<2--proofs--state-transitions>)[Proofs & State Transitions].
- #strong[Nostr relay.] Stores and serves the off-chain `CoinProof`
  bundles and `BatchBundle`s, performs `detect_tag` discovery for coin
  bundles, and carries gift-wrapped transport. See
  #link(<4--transport--recovery>)[Transport & Recovery].
- #strong[Data store.] Persists bundles and rebuilt tree state; provides
  the operator\'s own backup (#link("/requirements")[Requirement 6]).
- #strong[Capability-gated API.] Answers reads only against a valid
  ownership proof or view grant, and accepts transaction submissions.
  See #link(<5--access--explorer>)[Access & Explorer] and §6.4 below.

#strong[Keys it holds.] For accounts that delegate to it, the node holds
the #strong[operational bundle] `{ivk, ovk, op}` (Foundations §1.2):
`ivk` to detect and decrypt incoming coins, `ovk` to recover
outgoing-coin plaintext, and `op` to act as the account\'s Nostr
identity and to sign view grants and acknowledgements. For a
#emph[foreign] account it holds only an `op`-signed #strong[view grant],
never the bundle directly.

#strong[What it cannot do.] A node #strong[MUST NOT] be able to spend,
forge, or double-spend: it never holds any SPEND-branch key (`skᵢ`,
`nk`), and value integrity is enforced by proof soundness and the
nullifier accumulator, not by the node\'s honesty. A node #strong[MAY]
lie or withhold data, but it cannot make the wallet accept an
unverifiable answer (§6.3).

==== The wallet --- thin key-holder
<the-wallet--thin-key-holder>
The wallet holds the #strong[seed] and is the sole custodian of the
SPEND branch (`A/0'`, i.e. `skᵢ` and `nk`\; Foundations §1.2). Its
responsibilities:

- Derive all keys deterministically from the seed (Foundations §1.2);
  hold #strong[no] node-specific state.
- Sign each transition --- produce `BIP-340(skᵢ, message)` over
  `message = inr ‖ ocr` (Foundations §1.4) with the sign-to-contract
  tweak that binds the spender\'s off-chain `ProofData` --- and compute
  nullifiers `nf = Hc("Nullifier", nk ‖ coin.identifier)`. The resulting
  `SpendRecord` is handed to a publisher off-chain
  (#link(<46-data-availability--replication-factor-k>)[Transport & Recovery §4.6]);
  the wallet does #strong[not] itself touch Bitcoin.
- Delegate the operational bundle to its #strong[own] node, or issue a
  scoped view grant to a #strong[foreign] node (§6.2).
- Fetch authoritative state from its node(s) and #strong[independently
  verify] it against Bitcoin before signing or accepting a received coin
  (#link("/requirements")[Requirement 4]).

#strong[What it cannot do.] The wallet #strong[MUST NOT] be required to
be online continuously: detection, decryption, and serving are delegated
to the node so that liveness does not depend on the wallet. The wallet
performs no relay duty itself.

==== The explorer --- stateless presentation
<the-explorer--stateless-presentation>
The explorer is a #strong[stateless] read surface over one or more
nodes. It holds #strong[no keys] and no private state of its own. Given
a per-coin view capability `K_tx` (Foundations §1.3) --- carried in a
shareable link --- it decrypts and presents exactly one transaction and
verifies that confirmation against Bitcoin
(#link("/requirements")[Requirement 9]). It #strong[MUST] be
self-hostable and #strong[MUST NOT] assert any fact it cannot derive
verifiably from a node\'s data and the chain. See
#link(<5--access--explorer>)[Access & Explorer].

==== Running a node --- what an operator deploys
<running-a-node--what-an-operator-deploys>
The logical roles above map onto a small, fully #strong[self-hosted]
stack. Every part is the operator\'s own; using a third party for any of
them would reintroduce a central element and is therefore out of scope
for a sovereign node.

```mermaid
flowchart TB
  wallet["Wallet — SPEND keys only<br/>(user device, not in Docker)"]
  domain["Domain + TLS  ·  or Tor onion"]

  subgraph docker["Docker host — self-hosted by the operator"]
    direction TB
    explorer["Explorer — stateless"]
    znode["zkCoins node<br/>scanner · prover · store · capability-gated API"]
    bitcoind["Bitcoin full node — bitcoind (own)"]
    relay["Nostr relay (own)"]
    pg[("PostgreSQL<br/>node state · bundles")]
  end

  chain(["Bitcoin network"])
  mesh(["Nostr network"])

  wallet -->|"submit · verify vs Bitcoin"| domain
  domain --> znode
  domain --> explorer
  explorer -->|"read"| znode
  znode --- bitcoind
  znode --- relay
  znode --- pg
  bitcoind <-->|"read · broadcast"| chain
  relay <-->|"deliver · replicate"| mesh
```

- #strong[Container runtime] (Docker or compatible) --- the base; each
  part ships as a container.
- #strong[Bitcoin full node] (`bitcoind`, the operator\'s own) --- the
  source of truth for #strong[reading] the chain (the scanner) and for
  #strong[broadcasting] the publisher\'s Taproot reveal transactions. A
  third-party chain source (Electrum/Esplora/etc.) would reintroduce a
  trusted dependency and eclipse risk, and is not used.
- #strong[Nostr relay] --- stores and serves the off-chain `CoinProof`
  bundles and carries gift-wrapped transport. It #strong[MAY] be
  embedded in the zkCoins-node image or run as a separate relay
  container; either way it is the operator\'s #strong[own] relay.
- #strong[Reachable address] --- an internet domain with TLS so wallets,
  explorers, and peer nodes can reach the node\'s API and relay. A Tor
  onion service #strong[MAY] be used instead for IP privacy.
- #strong[zkCoins node] --- the core software: Bitcoin scanner, prover,
  data store, and capability-gated API (and the relay role, if
  embedded).
- #strong[PostgreSQL] --- the node\'s database; persists the rebuilt
  nullifier set and the off-chain `CoinProof` bundles (the concrete
  backing of the data-store role).
- #strong[Explorer] --- the stateless presentation surface
  (#link(<5--access--explorer>)[Access & Explorer]), typically co-hosted
  as its own container reading the node; it holds no keys.

The only thing that is #strong[never] part of a node deployment is the
SPEND branch --- those keys live solely in the wallet, on the user\'s
device (#link(<12-key-hierarchy>)[Foundations §1.2]).

=== 6.2 Wallet ↔ node
<62-wallet--node>
The wallet is a #strong[thin client]. It never delegates spend
authority; it delegates only viewing and serving:

- #strong[Own node.] The wallet entrusts its node with the full
  operational bundle `{ivk, ovk, op}` (Foundations §1.2) over an
  authenticated, encrypted channel. The node can then receive, decrypt,
  discover, and serve on the account\'s behalf 24/7. None of the bundle
  can spend.
- #strong[Foreign node.] The wallet #strong[MUST NOT] hand a foreign
  operator the bundle. Instead it issues that node a scoped, `op`-signed
  #strong[view grant] (Bech32m HRP `zkgrant`, Foundations §1.7) that
  authorises a bounded read --- defined in
  #link(<5--access--explorer>)[Access & Explorer].

Before it signs, the wallet #strong[MUST] fetch the current
authoritative state (the account\'s latest `AccountState`, the relevant
nullifier-set state, and the input bundles) from its node(s) and verify
it against Bitcoin. The wallet treats node-supplied data as #emph[claims
to be checked], never as trusted truth.

=== 6.3 Node portability and multi-node operation
<63-node-portability-and-multi-node-operation>
#link("/requirements")[Requirement 10] is met structurally: #strong[a
wallet depends on no node-specific state.] Every key, identifier,
nullifier, and detection tag is derived from the seed (Foundations
§1.2--§1.4), and the one global structure --- the nullifier accumulator
--- is reconstructable by any node from the chain of `BatchInscription`
roots plus the content-addressed `BatchBundle`s served by the relay mesh
(Foundations §1.6, #link(<36-chain-scanning>)[On-chain §3.6--§3.7]). The
bundles are publicly verifiable (every `AggregateBatchProof` is a
recursive PCD proof) and `k = 3` replicated, so the requirement reduces
to reaching at least one honest replica per past batch --- never
trusting one.

- A wallet #strong[MAY] switch nodes at any time, by configuration
  alone, with no migration step. No node can lock a wallet in.
- A wallet #strong[MAY] use #strong[multiple nodes simultaneously] ---
  querying several, submitting through one or more.

#strong[Why multi-node is safe.] The wallet verifies every answer
against Bitcoin (§6.2, #link("/requirements")[Requirement 4]). An honest
node returns verifiable truth; a dishonest one cannot forge a valid
recursive proof, a valid `AggregateBatchProof`, or a valid on-chain
`BatchInscription`. So when the wallet fans a query out to several
nodes, it #strong[MUST] keep the answer that verifies and #strong[MAY]
ignore all others. This is the #strong[\"at least one honest node\"]
property: correctness holds as long as ≥1 queried node is honest. It
depends on client-side verification --- without it, more nodes would not
help. The configurations this yields are tabulated in the
#link("/architecture/trust-model")[Trust Model].

#strong[Selecting the latest state under multiple verifying answers.]
Multi-node fan-out can return #strong[more than one] answer that
verifies --- typically because the queried nodes are at different sync
states (each holds a valid snapshot of the lineage at a different
`send_counter`). The wallet #strong[MUST] select as authoritative
\"latest\" the answer with the #strong[highest `send_counter`] among
those whose anchoring `BatchInscription` is in state `completed`
(#link(<310-transaction-states>)[§3.10]) before signing the next
transition. Two verifying answers with the #strong[same] `send_counter`
but #strong[different] `new_account_state_hash` are an account-level
fork --- the SPEND-key holder signed two parallel transitions at the
same counter. A wallet that detects this #strong[MUST NOT] sign a
further transition until the user resolves it, because sole legitimate
control of `sk₀` and `skᵢ` never produces equivocation; detection here
means either operator error (the same seed driven from two wallet
instances against stale state) or a custody breach of the SPEND branch.
The protocol does #strong[not] automatically pick a fork-winner; the
choice is the holder\'s. When #strong[no] candidate has a `completed`
anchor (e.g. every recent spend is still within finality), the wallet
#strong[MAY] build the next transition against the highest-counter
`pending` candidate, accepting the reorg risk that the inclusion block
of the chosen prev state could be displaced before the §3.9 finality
bound; deployments handling extreme value #strong[SHOULD] wait for
`completed` before extending.

=== 6.4 External interfaces (abstract)
<64-external-interfaces-abstract>
The node exposes four interface families, specified here at an
implementation-neutral level; the owning sections define their exact
payloads.

#table(
    columns: 5,
    align: (auto,auto,auto,auto,auto,),
    table.header([Interface], [Direction], [Capability
      required], [Purpose], [Specified in],),
    table.hline(),
    [#strong[read.account]], [wallet/node → node (pull)], [an
    #strong[ownership proof] (sign the challenge with `sk₀`) #strong[or]
    an `op`-signed #strong[view grant]], [fetch `AccountState`,
    balances, owned coins, and their
    bundles], [#link(<5--access--explorer>)[Access & Explorer]],
    [#strong[read.proof]], [wallet → node (pull)], [ownership
    proof], [fetch a `CoinProof` and its `inclusion_proof` for
    re-verification], [#link(<5--access--explorer>)[Access & Explorer] ·
    #link(<2--proofs--state-transitions>)[Proofs]],
    [#strong[submit.tx]], [wallet → node (push)], [none (proof is
    self-authenticating)], [submit a transition for proving and on-chain
    publication], [#link(<3--on-chain-layer>)[On-chain Layer]],
    [#strong[relay.\*]], [any ↔ node (Nostr)], [NIP-44 / NIP-59
    envelope; `detect_tag` for `CoinProof` discovery; content-address
    (`bundle_locator`) for `BatchBundle` fetch], [publish/fetch
    off-chain bundles (per-coin and per-batch), gift-wrapped delivery,
    note discovery,
    k-replication], [#link(<4--transport--recovery>)[Transport & Recovery]],
    [#strong[explorer.read]], [explorer → mesh / node], [a bearer view
    secret (`zkview` per coin, `zkavk` for full history) or a balance
    attestation, applied #strong[client-side]], [render a disclosed
    view: one transaction, full account history, or a
    balance], [#link(<5--access--explorer>)[Access & Explorer]],
)

The `read.account` path is #strong[capability-gated]: a node
#strong[MUST] reject a request that does not present a valid ownership
proof or `op`-signed view grant. Bearer view secrets (`zkview`/`zkavk`)
and balance attestations are #strong[not] node authorisations --- the
explorer applies them client-side to bundles obtained from the relay
mesh or a holder, so `explorer.read` widens only what the secret-holder
can decrypt from already-public material
(#link(<51-capability-gated-pull>)[Access & Explorer §5.1]). The
`submit.tx` path needs no capability because the submitted transition
carries its own validity proof and self-authenticating `SpendRecord`\; a
node #strong[MUST] verify that proof before publishing.

=== 6.5 Issuance --- versioned schemas, v1 (minimal)
<65-issuance--versioned-schemas-v1-minimal>
A new asset is created by fixing its `asset_id`
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]) and binding
#strong[versioned issuance terms] into the mint circuit. Issuance is
#strong[schema-versioned]: each asset is created under one
`IssuanceTerms` version, the version is bound into `asset_id` itself,
and every coin minted under that asset inherits its version through
`asset_id`. Versions are added over time; a coin\'s version determines
which rule set governs its mints, and a coin minted under one version
can never be misinterpreted under another.

#strong[Single-issuer model (v1).] The asset\'s `asset_id` commits to
`creator_pubkey = Pk₀` of the issuing account (Foundations §1.4). Only
the holder of `sk₀` of that account can sign a transition for it; mint
authority is therefore #strong[monopolised on the creator] by
construction. #emph[\"Permissionless issuance\"] in this spec means
#strong[anyone can create their own asset] --- not that anyone can mint
someone else\'s. Within their own asset, the creator #strong[MAY] mint
any amount at any time; v1 imposes no protocol-level cap. Supply
discipline is a #strong[creator\'s commitment], not a protocol guarantee
--- holders trust the creator the way they would any single-issuer
asset. Account-level forks (a creator signing two parallel histories
with the same `Pk₀`) are publicly observable on Bitcoin because the
rotating per-transition pubkey `Pkᵢ` would appear in two distinct
`SpendRecord`s, and that observability is the holders\' detection point
if a creator over-issues against an off-chain promise.

==== v1 issuance terms
<v1-issuance-terms>
```
IssuanceTerms_v1 = {
  asset_id          : field,        // = Hc("AssetId", genesis_tag ‖ creator_pubkey
                                    //         ‖ H(name) ‖ decimals ‖ issuance_version)
                                    //   (Foundations §1.4)
  creator_pubkey    : 32 bytes,     // = Pk₀ of the issuing account (x-only); the circuit
                                    //   verifies H(creator_pubkey) == prev_account_state.owner
                                    //   because the SPEND key rotates per transition and Pk₀
                                    //   is otherwise irrecoverable in-circuit from owner = H(Pk₀)
  issuance_version  : u8 = 1,       // the schema version this asset is created under
  name_hash         : digest,       // = H(name); the human-readable name is NEVER on-chain
  decimals          : u8,           // display precision; bound into asset_id, no in-circuit effect
  terms_hash        : field         // = Hc("IssuanceTerms", asset_id ‖ issuance_version)
                                    //   (v1 has no fields beyond what asset_id already binds;
                                    //   issuance_version is re-absorbed here as belt-and-
                                    //   suspenders explicit version-binding — redundant with
                                    //   asset_id but harmless; later versions extend this list)
}
```

The v1 mint proof (see
#link(<2--proofs--state-transitions>)[Proofs & State Transitions])
#strong[MUST] verify, in-circuit, that:

- \(a) `issuance_version == 1` --- this circuit accepts only v1 mints;
- \(b) `H(creator_pubkey) == prev_account_state.owner` --- binds the
  issuance to the asset\'s creator account (only the holder of `sk₀` can
  produce a witnessed `creator_pubkey` whose SHA-256 image matches
  `owner`, since SHA-256 is preimage-resistant in-circuit);
- \(c)
  `asset_id == Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version)`
  --- the v1 `asset_id` derivation of
  #link(<14-identifiers-and-hashes>)[Foundations §1.4]\;
- \(d) `terms_hash == Hc("IssuanceTerms", asset_id ‖ issuance_version)`
  --- the `terms_hash` recomputation.

Mint clauses (a)--(d) are the entire v1 mint circuit: no
protocol-enforced cap, no per-mint quantum, no time window, no signer
set beyond the creator. Those are deliberately deferred to later
versions. The `Mint(asset_id) = amount` flow into
#link(<21-the-compliance-predicate>)[Proofs §2.1 clause 3] (per-asset
balance conservation) is the only other constraint a v1 mint
participates in.

==== Forward compatibility: future versions
<forward-compatibility-future-versions>
Later issuance schemas --- `IssuanceTerms_v2`, `v3`, … --- #strong[MAY]
introduce protocol-enforced supply rules (cap\_total, per-mint quantum,
time windows, multi-signer mint authority, redemption mechanisms, etc.).
Each new version is a separate `IssuanceTerms` schema with its own
circuit-enforced rules; the version-binding through `asset_id`
(#link(<14-identifiers-and-hashes>)[Foundations §1.4]) guarantees that a
coin minted under one version cannot be misinterpreted under another.

The dispatch model is #strong[fixed by the cyclic-recursion constraint]
of #link(<21-the-compliance-predicate>)[Proofs §2.1 clause 1]: the
verifier data #strong[MUST] be fixed and identical in prover and
verifier, so a single account\'s recursive lineage cannot cross
verifier-data boundaries. Adding a v2 schema therefore #strong[MUST]
take the form of an #strong[in-circuit version branch within the same
circuit] `C` --- extending `C` to accept both `issuance_version == 1`
and `issuance_version == 2` mints --- #emph[not] a separate per-version
circuit, which would break cyclic recursion the moment an account that
minted v1 attempts to mint v2 in the same lineage. The
single-circuit-with-version-branching dispatch is therefore the only
PCD-compatible option; the open question for v2 is the #emph[contents]
of the version branch (which protocol-enforced rules to add), not the
dispatch.

The human-readable `name` is #strong[never] placed on-chain (Foundations
§1.4).

=== 6.6 Threat model and trust configurations
<66-threat-model-and-trust-configurations>
Custody is #strong[cryptographically safe in every configuration]: no
node holds a SPEND-branch key (Foundations §1.2), value integrity is
enforced by proof soundness and the nullifier accumulator, and every
spend\'s nullifier reaches the accumulator only via a publisher
`AggregateBatchProof` anchored by an immutable on-chain
`BatchInscription`. The three wallet--node configurations differ only in
#strong[privacy] and in #strong[whom you trust for correctness and
availability] --- never in custody. The authoritative matrix lives in
the #link("/architecture/trust-model")[Trust Model]\; summarised:

- #strong[Own wallet + own node.] Full privacy, trustless correctness,
  safe custody. The node sees your plaintext, but you are the operator,
  so nothing leaks.
- #strong[Own wallet + multiple foreign nodes.] Plaintext is disclosed
  to all of them; correctness is safe #strong[as long as ≥1 is honest]
  (§6.3); custody safe.
- #strong[Own wallet + a single foreign node.] Plaintext disclosed to
  it; you trust it for correctness and liveness (it can lie or omit),
  but it #strong[cannot] steal, forge, or double-spend; custody safe.

#strong[Inherited assumption.] zkCoins anchors on Bitcoin and therefore
inherits Bitcoin\'s network-liveness assumption: if #strong[all] of a
node\'s peers lie (an eclipse attack), even a self-hosted node can be
fed a false view of the chain. zkCoins adds no new consensus and so
neither weakens nor strengthens this \"≥1 honest peer\" assumption.

#strong[Bitcoin reorg bound.] zkCoins assumes Bitcoin produces no
canonical reorganisations deeper than #strong[5 blocks]
(#link(<39-finality>)[On-chain §3.9],
#link(<310-transaction-states>)[§3.10]). A reorg of 6 blocks or more is
treated as a #strong[protocol-failure event] --- outside the spec\'s
guaranteed state machine. Under this assumption, a `SpendRecord` once
classified `completed` stays `completed`. This is consistent with the
Bitcoin-industry default of treating 6 confirmations as practical
finality; deployments handling extreme value #strong[MAY] adopt
additional out-of-band confirmation policies, but the on-chain
`completed` state remains defined at 6 confirmations.

=== 6.7 Security-properties summary
<67-security-properties-summary>
How this architecture maps to the #link("/requirements")[Requirements]
at a glance:

#table(
    columns: 2,
    align: (auto,auto,),
    table.header([Requirement], [How the architecture meets it],),
    table.hline(),
    [#strong[1 · Bitcoin-only base]], [One node component scans and
    inscribes to Bitcoin L1; no separate chain, token, or consensus.],
    [#strong[2 · Private]], [Node serves only opaque `SpendRecord`s
    publicly; per-coin encryption (Foundations §1.3) gates plaintext to
    capability holders.],
    [#strong[3 · Trustless]], [No component holds a spending key (§6.1);
    integrity from proofs + nullifier accumulator, not node honesty
    (§6.6).],
    [#strong[4 · Client-side validation]], [Wallet re-verifies every
    node answer against Bitcoin before accepting (§6.2--§6.3).],
    [#strong[5 · Custody only in wallet]], [SPEND branch never leaves
    the wallet; only the operational bundle / view grants are delegated
    (§6.2).],
    [#strong[6 · Recovery]], [Node store is the normal backup; seed +
    chain + replicated bundles are the emergency fallback (§6.1).],
    [#strong[7 · Self-hostable]], [Node ships as one self-contained
    container with no operator-specific dependencies (§6.1).],
    [#strong[8 · Multi-asset]], [`asset_id` plus
    `issuance_version`-bound `IssuanceTerms_v1` lets anyone create their
    own asset; the creator is the sole minter of their asset (§6.5).],
    [#strong[9 · Explorer]], [Stateless explorer resolves one
    transaction from a per-coin `K_tx`, verified against Bitcoin
    (§6.1).],
    [#strong[10 · Node portability]], [No node-specific wallet state;
    switch and multi-node by configuration alone (§6.3).],
)

== Glossary
<glossary>
A short, scannable reference for the jargon, notation, and identifier
names used throughout the specification. Each entry links back to its
defining section. For the full reading order start at the
#link(<contents>)[Contents].

=== Notation
<notation>
- #strong[`H(x)`] --- SHA-256 of the byte string `x`.
  (#link(<11-cryptographic-primitives>)[§1.1])
- #strong[`Hc(tag, x₁, …)`] --- Poseidon-over-Goldilocks hash,
  domain-separated by `tag`, of the field-encoded inputs.
  (#link(<11-cryptographic-primitives>)[§1.1],
  #link(<17-encoding-serialization-and-the-reference-instantiation>)[§1.7])
- #strong[`a ‖ b`] --- byte concatenation.
- #strong[`P = k·G`] --- secp256k1 scalar multiplication; `G` is the
  generator.
- #strong[`ECDH(k, P) = x(k·P)`] --- x-coordinate of the shared
  secp256k1 point.
- #strong[Lowercase keys (`skᵢ`, `nk`, `ivk`, `ovk`, `op`)] --- secret
  scalars; their public points are written `<name>·G` or as named
  pubkeys (`Pkᵢ`, `IVPK`, `op_pubkey`). BIP-340 public keys are x-only
  (32 bytes). (#link(<12-key-hierarchy>)[§1.2])

=== A--Z
<az>
- #strong[AccountState] ---
  `{owner, balances, current_pubkey, send_counter, coin_history_root}`\;
  private bookkeeping, never on-chain in plaintext. Its hash `ash` is
  bound by every transition\'s proof.
  (#link(<15-core-data-structures>)[§1.5])
- #strong[AccountUpdateProof] --- the proof type for any transition
  after the first; consumes the account\'s previous proof and emits a
  new one (PCD). (#link(<22-proof-types>)[§2.2])
- #strong[`address`] --- `H(Pk₀)`\; the protocol\'s only identity, fixed
  at account creation, encoded as Bech32m `zk`.
  (#link(<14-identifiers-and-hashes>)[§1.4])
- #strong[AggregateBatchProof] --- recursive PCD proof produced by a
  publisher\'s batch-aggregation circuit `C_batch` that attests, in zero
  knowledge, every member `SpendRecord`\'s per-account validity, the
  integrity of the batch\'s nullifier set, the binding to the bundle\'s
  `bundle_locator`, and that
  `new_root = SMT.insert_many(prev_root, batch_nullifiers)`\;
  constant-size in member count `m`, \~100 KB typical.
  (#link(<22-proof-types>)[§2.2], #link(<31-the-on-chain-object>)[§3.1])
- #strong[`ash` (account\_state\_hash)] ---
  `Hc("AccountState", serialize(AccountState))`.
  (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<174-serializeaccountstate>)[§1.7.4])
- #strong[`asset_id`] ---
  `Hc("AssetId", genesis_tag ‖ Pk₀ ‖ H(name) ‖ decimals ‖ issuance_version)`\;
  globally unique per asset, binds the creator\'s `Pk₀` and the
  issuance-schema version, never carries the human-readable name
  on-chain. (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<65-issuance--versioned-schemas-v1-minimal>)[§6.5])
- #strong[`balances`] --- `map<asset_id, amount>` in `AccountState`\;
  the account\'s multi-asset bookkeeping.
  (#link(<15-core-data-structures>)[§1.5])
- #strong[BatchBundle] ---
  `{prev_root, new_root, spend_records, aggregate_proof, nullifiers (derived view)}`\;
  off-chain, content-addressed
  (`bundle_locator = Hc("BatchBundle", serialize(BatchBundle))` with
  canonical preimage
  `prev_root ‖ new_root ‖ u32-be(m) ‖ SpendRecord₁ ‖ … ‖ SpendRecord_m`
  --- the derived `nullifiers` view and the `aggregate_proof` are
  excluded from the preimage; see
  #link(<14-identifiers-and-hashes>)[§1.4]), `k = 3` replicated; carries
  every member `SpendRecord` plus the `AggregateBatchProof`.
  (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<31-the-on-chain-object>)[§3.1],
  #link(<46-data-availability--replication-factor-k>)[§4.6])
- #strong[BatchInscription] ---
  `{publisher_pubkey, prev_root, new_root, bundle_locator, block_anchor, signature}`\;
  the #strong[only] object zkCoins writes to Bitcoin; constant 231 bytes
  per batch; anchors the publisher\'s accumulator state transition.
  (#link(<31-the-on-chain-object>)[§3.1],
  #link(<35-inscription-format>)[§3.5])
- #strong[Bech32m] --- text encoding used for addresses (`zk`), view
  grants (`zkgrant`), per-coin view caps (`zkview`), bearer account view
  keys (`zkavk`). (#link(<177-bech32m-and-bitcoin-conventions>)[§1.7.7])
- #strong[`block_anchor`] --- `{block_hash, height}` of the Bitcoin tip
  a batch\'s proofs are built against; bounded by `N = 100` blocks
  behind the inclusion block. (#link(<35-inscription-format>)[§3.5])
- #strong[Bundle (BatchBundle)] --- see #emph[BatchBundle].
- #strong[Bundle (CoinProof)] ---
  `{coin, proof, inclusion_proof, creating_prev_ash, epk, ciphertext, detect_tag}`\;
  the off-chain object that is #emph[simultaneously] the recipient\'s
  receipt and its spend credential.
  (#link(<15-core-data-structures>)[§1.5])
- #strong[`bundle_locator`] ---
  `Hc("BatchBundle", serialize(BatchBundle))`\; the 32-byte content
  address of a `BatchBundle`, inscribed in every `BatchInscription` so
  any scanner can fetch and verify the bundle.
  (#link(<31-the-on-chain-object>)[§3.1],
  #link(<35-inscription-format>)[§3.5])
- #strong[`C_batch`] --- the publisher\'s batch-aggregation circuit;
  produces the `AggregateBatchProof` over `m` member `SpendRecord`s and
  their per-account proofs. Verifier data is fixed (network-tagged for
  chain separation). (#link(<22-proof-types>)[§2.2])
- #strong[Cap (per coin)] --- see #emph[capability]\; the smallest is
  `zkview` per-coin. (#link(<53-per-coin-view-capability>)[§5.3])
- #strong[Capability] --- a cryptographic permission to view some
  Private record (ownership proof, view grant, bearer view key, per-coin
  view cap, balance attestation).
  (#link(<54-capabilities-at-a-glance>)[§5.4])
- #strong[Capability-gated pull] --- the node API serves Private records
  only after the requester presents a valid capability.
  (#link(<51-capability-gated-pull>)[§5.1])
- #strong[`Coin`] --- `{identifier, recipient, amount, asset_id}`\; the
  off-chain value-carrying unit.
  (#link(<15-core-data-structures>)[§1.5])
- #strong[Coin-history SMT] --- per-account, Private; sparse Merkle tree
  keyed by `coin.identifier`, leaf state
  `{0=absent, 1=received-unspent, 2=spent}`\; root folded into `ash`.
  (#link(<16-trees-one-global-structure-one-per-account-structure>)[§1.6],
  #link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6])
- #strong[`coin.identifier`] ---
  `Hc("Coin", prev_account_state_hash ‖ asset_id ‖ coin_index)`\; the
  `prev_account_state_hash` is the #strong[prior] `ash` of the
  transition that creates the coin (breaks the would-be recursion with
  `new_ash`, see #link(<14-identifiers-and-hashes>)[§1.4]). Fixed at
  creation. (#link(<14-identifiers-and-hashes>)[§1.4])
- #strong[CoinProof] --- see #emph[Bundle].
- #strong[CoinTemplate] --- `{recipient, amount, asset_id}`\; the
  sender\'s per-payee instruction inside a `Send`.
  (#link(<15-core-data-structures>)[§1.5])
- #strong[`completed` (transaction state)] --- `BatchInscription` is
  admitted under §3.5+§3.6 (publisher signature + `prev_root` continuity
  \+ bundle binding + aggregate proof all verify) AND its inclusion
  block has ≥ 6 confirmations; member `SpendRecord`s inherit this state;
  the only state in which a receiver MAY credit; absolute under the \"no
  reorgs deeper than 5 blocks\" assumption.
  (#link(<310-transaction-states>)[§3.10])
- #strong[Cyclic recursion] --- one fixed circuit verifies proofs of
  itself; verifier data is constant, so proof size and verification time
  are constant. (#link(<22-proof-types>)[§2.2])
- #strong[DeliveryEvent] --- Nostr event carrying
  `{detect_tag, epk, blob_id, blob_locators, ack_nonce}` plaintext,
  NIP-44 encrypted to `IVPK`, NIP-59 gift-wrapped under an ephemeral
  key. The `ack_nonce` is a fresh sender-chosen 32-byte value the
  recipient echoes in the ACK signature, binding the ACK to this
  delivery attempt. (#link(<42-bundle-delivery>)[§4.2])
- #strong[`detect_tag`] --- `Hc("DetectTag", dk ‖ epk)`\; per-coin,
  all-distinct, recipient-side scan only --- no relay filter and no
  cross-coin linkability.
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3],
  #link(<44-note-discovery>)[§4.4])
- #strong[`dk` (detection key)] --- `HKDF("DetectKey", ivk)`\; lets a
  holder of `ivk` recognise its own incoming coins by recomputing
  `detect_tag` per candidate event.
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3])
- #strong[`epk` (ephemeral pubkey)] --- `esk·G`, drawn fresh per output
  coin; the recipient\'s `K_tx` and `detect_tag` are derived from it.
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3])
- #strong[`failed` (transaction state)] --- `BatchInscription` rejected
  by the scan (parser, `block_anchor` bounds, publisher signature,
  `prev_root` mismatch, bundle binding, or aggregate proof violated);
  member `SpendRecord`s inherit this state; receiver MUST NOT credit;
  forward-sticky in time, can only flip via reorg.
  (#link(<310-transaction-states>)[§3.10])
- #strong[Field, field element] --- a value in 𝔽 (Goldilocks,
  `p = 2^64 − 2^32 + 1`); a Poseidon digest is #strong[four] field
  elements (32 bytes). (#link(<11-cryptographic-primitives>)[§1.1],
  #link(<171-poseidon-instance-and-digest-encoding>)[§1.7.1])
- #strong[Fuzzy message detection (FMD)] --- OPTIONAL probabilistic
  relay-side pre-filter; reduces the recipient\'s download volume, not
  its linkability (the per-coin scheme already has none).
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3],
  #link(<47-metadata-and-privacy-tradeoffs>)[§4.7])
- #strong[Goldilocks] --- the proof field `𝔽` with prime
  `p = 2^64 − 2^32 + 1`\; pinned for Poseidon.
  (#link(<11-cryptographic-primitives>)[§1.1])
- #strong[Half-aggregation] --- non-interactive compression of many
  BIP-340 signatures into one shared aggregate scalar `s_agg`, retaining
  each `Rⱼ`\; used #strong[off-chain] inside the publisher\'s
  `AggregateBatchProof` witness as a proving-cost optimisation.
  (#link(<33-off-chain-signature-handling>)[§3.3])
- #strong[`Hc`] --- see #emph[Notation].
- #strong[HKDF] --- HKDF-SHA-256, used for symmetric/derived secrets
  (`K_tx`, `dk`). (#link(<11-cryptographic-primitives>)[§1.1])
- #strong[InitialProof] --- the first transition of an account;
  `prev_proof` is absent and `prev_account_state` is the canonical empty
  account. (#link(<22-proof-types>)[§2.2])
- #strong[`inr` (input\_nullifiers\_root)] --- Poseidon Merkle root over
  a transition\'s spent `nf`s under tag `NullifiersRoot`.
  (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<175-poseidon-merkle-tree-used-for-ocr-and-inr>)[§1.7.5])
- #strong[Inscription] --- Taproot commit/reveal envelope whose witness
  payload starts with the 2-byte marker `0x42 0x42` and carries one
  constant-size `BatchInscription`.
  (#link(<35-inscription-format>)[§3.5])
- #strong[Invoice] ---
  `{amount, recipient, asset_id, memo?, pk0, ivpk, op_pubkey, relays, addr_sig, sig}`\;
  the off-chain payer-facing addressing object. `addr_sig` is a BIP-340
  signature by `sk₀` that chains the address-holder to every field,
  including the choice of `ivpk` and `op_pubkey`\; `sig` is the
  per-issuance BIP-340 signature by `op` that the recipient\'s online
  relay applies. Both are required.
  (#link(<15-core-data-structures>)[§1.5],
  #link(<43-addressing-for-delivery>)[§4.3])
- #strong[`IssuanceTerms`] --- the versioned record bound to an
  `asset_id` that fixes its mint rules. v1 is creator-only with no
  protocol-enforced cap, quantum, or time window ---
  `{asset_id, issuance_version=1, name_hash, decimals, terms_hash}`.
  Later versions MAY add protocol-enforced supply rules.
  (#link(<65-issuance--versioned-schemas-v1-minimal>)[§6.5])
- #strong[`issuance_version`] --- `u8` schema version under which an
  asset is created (`1` in this spec); bound into `asset_id` so coins
  minted under different versions are distinct.
  (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<65-issuance--versioned-schemas-v1-minimal>)[§6.5])
- #strong[`ivk`] --- incoming viewing key (VIEW branch); detects and
  decrypts incoming coins; cannot spend.
  (#link(<12-key-hierarchy>)[§1.2])
- #strong[`IVPK`] --- `ivk·G`\; the recipient\'s incoming-view pubkey,
  used to encrypt delivery events and as the ECDH counterpart.
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3])
- #strong[`K_tx`] --- `HKDF("NoteKey", ss ‖ epk)`\; per-coin symmetric
  note key; decrypts exactly one coin\'s ciphertext.
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3])
- #strong[Lineage (account)] --- the account\'s chain of recursive
  proofs, each consuming its predecessor; carried in constant size by
  PCD. (#link(<22-proof-types>)[§2.2])
- #strong[`message`] --- `inr ‖ ocr`\; the BIP-340-signed payload of a
  `SpendRecord` (64 bytes). (#link(<14-identifiers-and-hashes>)[§1.4])
- #strong[Mint] --- the issuance transition; produces a creator-owned
  coin under the asset\'s `IssuanceTerms_v1` (the creator of the asset
  is its sole minter; anyone can create their own asset, no one can mint
  someone else\'s); spends no coin, has an empty `nullifiers` list, and
  does not require a `BatchInscription` --- its receiver verifies it
  directly against the recursive `InitialProof`. A creator MAY
  optionally batch a mint into a `BatchInscription` for a publicly
  anchored \"first appearance\"; this is publisher policy, not
  protocol-required. (#link(<231-mint--issuance>)[§2.3.1],
  #link(<65-issuance--versioned-schemas-v1-minimal>)[§6.5])
- #strong[`mint-verified` (transaction state)] --- a coin produced by a
  non-batched mint (#link(<231-mint--issuance>)[§2.3.1]) whose
  `InitialProof` has been re-verified by the receiver. No
  `BatchInscription` exists; cryptographic safety is identical to
  `completed` but there is no on-chain anchor. Explorers MUST render
  `mint-verified` distinct from `completed`/`pending`/`failed` so the
  user understands the absence of a chain anchor. Any subsequent spend
  of the mint coin is anchored normally.
  (#link(<310-transaction-states>)[§3.10])
- #strong[MMR] --- #emph[deprecated]\; no Merkle Mountain Range is used
  in v1 (the v0 Commitment-MMR was removed; see
  #link(<16-trees-one-global-structure-one-per-account-structure>)[§1.6]).
- #strong[`NAV(tip)`] --- `(accumulator, tip_block_hash, tip_height)`\;
  the accumulator\'s value at a stated Bitcoin tip; a non-membership
  answer is meaningful only relative to a `NAV`.
  (#link(<37-the-nullifier-accumulator>)[§3.7])
- #strong[`nf` (nullifier)] ---
  `Hc("Nullifier", nk ‖ coin.identifier)`\; revealed in the clear when
  the coin is spent, unlinkable to the coin without `nk`.
  (#link(<14-identifiers-and-hashes>)[§1.4])
- #strong[NIP-44 v2] --- encrypted message format (ECDH-secp256k1 →
  HKDF-SHA-256 → ChaCha20 + HMAC-SHA-256); used for the delivery payload
  and acknowledgements. (#link(<11-cryptographic-primitives>)[§1.1],
  #link(<42-bundle-delivery>)[§4.2])
- #strong[NIP-59] --- Nostr gift-wrap; outer envelope under a fresh
  ephemeral key so a relay sees neither sender nor recipient.
  (#link(<11-cryptographic-primitives>)[§1.1],
  #link(<42-bundle-delivery>)[§4.2])
- #strong[`nk`] --- nullifier key (SPEND branch, account-level); used
  only in-circuit to compute `nf`s. (#link(<12-key-hierarchy>)[§1.2])
- #strong[Nullifier accumulator] --- global, 256-bit-depth SMT over
  every admitted `nf`\; advanced by inscribed `prev_root → new_root`
  transitions whose validity is attested by each batch\'s
  `AggregateBatchProof`\; the only global structure.
  (#link(<16-trees-one-global-structure-one-per-account-structure>)[§1.6],
  #link(<37-the-nullifier-accumulator>)[§3.7],
  #link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6])
- #strong[`ocr` (output\_coins\_root)] --- Poseidon Merkle root over a
  transition\'s output `coin.identifier`s under tag `CoinsRoot`.
  (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<175-poseidon-merkle-tree-used-for-ocr-and-inr>)[§1.7.5])
- #strong[`op`] --- operational/Nostr identity key; held by the node;
  signs view grants and acknowledgements; cannot spend.
  (#link(<12-key-hierarchy>)[§1.2])
- #strong[`ovk`] --- outgoing viewing key (VIEW branch); recovers
  outgoing-coin plaintext; cannot spend.
  (#link(<12-key-hierarchy>)[§1.2])
- #strong[Ownership proof] --- a BIP-340 signature by `sk₀` over a
  node-issued challenge; grants the subject\'s full Private view.
  (#link(<a-ownership-proof>)[§5.1(a)])
- #strong[Path A (verifier path)] --- a verifier that maintains the full
  nullifier accumulator itself by running §3.6 against every admitted
  `BatchInscription`, fetching each `BatchBundle`, verifying each
  `AggregateBatchProof`, and applying the resulting
  `prev_root → new_root` transition. Answers `(non-)membership` queries
  by direct local lookup. Storage grows with admitted nullifiers.
  (#link(<37-the-nullifier-accumulator>)[§3.7])
- #strong[Path B (verifier path)] --- a light-client verifier that holds
  only the on-chain inscribed `new_root` sequence and asks any Path-A
  node for a self-verifying SMT inclusion or non-inclusion path; the
  answering node cannot forge a path against the on-chain root, so
  correctness holds against any honest answering node.
  (#link(<37-the-nullifier-accumulator>)[§3.7])
- #strong[PCD (Proof-Carrying Data)] --- a recursion-based proof system:
  each transition consumes a previous proof and emits a new one; one
  constant-size proof attests the entire history.
  (#link(<2--proofs--state-transitions>)[§2])
- #strong[`pending` (transaction state)] --- `BatchInscription`
  classified as neither `completed` nor `failed`: either inclusion block
  has \< 6 confirmations, or its `BatchBundle` has not yet been fetched
  and verified; member `SpendRecord`s inherit this state; receiver MUST
  NOT credit. If the bundle has verified (only confirmations are
  missing), the batch\'s `nf`s are already in the nullifier accumulator
  and double-spend protection applies.
  (#link(<310-transaction-states>)[§3.10])
- #strong[`Pkᵢ`] --- `skᵢ·G`\; the rotating per-transition signing
  pubkey (x-only); `Pk₀` fixes the address.
  (#link(<12-key-hierarchy>)[§1.2])
- #strong[`Pkₚ`] --- `skₚ·G`\; the publisher\'s long-lived BIP-340
  x-only identity key; signs each `BatchInscription` (sign-to-contract
  bound to the off-chain `AggregateBatchProof`); MAY rotate per batch
  for publisher privacy.
  (#link(<32-batchinscription-signing-bip-340--sign-to-contract>)[§3.2])
- #strong[Poseidon] --- algebraic hash over Goldilocks used inside the
  proof circuit; reference instance is Plonky2\'s
  `PoseidonGoldilocksConfig`.
  (#link(<11-cryptographic-primitives>)[§1.1],
  #link(<171-poseidon-instance-and-digest-encoding>)[§1.7.1])
- #strong[`ProofData`] ---
  `{new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root}`\;
  the proof\'s public inputs. (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<21-the-compliance-predicate>)[§2.1 clause 9])
- #strong[Publisher] --- permissionless agent that aggregates off-chain
  `SpendRecord`s into a `BatchBundle`, builds the `AggregateBatchProof`,
  and inscribes the constant-size `BatchInscription` on Bitcoin; cannot
  forge (the aggregate proof must verify), only censor or delay.
  (#link(<34-the-publisher>)[§3.4])
- #strong[Recursive verification] --- see #emph[PCD]\; clause 1 of the
  predicate. (#link(<21-the-compliance-predicate>)[§2.1])
- #strong[`send_counter`] --- monotonic counter inside `AccountState`\;
  increments per transition. (#link(<15-core-data-structures>)[§1.5])
- #strong[`serialize(AccountState)`] --- canonical byte serialization;
  preimage for `ash`. (#link(<174-serializeaccountstate>)[§1.7.4])
- #strong[Sign-to-contract (S2C)] --- a BIP-340 signature\'s nonce is
  tweaked by `t = H(R' ‖ digest)`, anchoring an off-chain object to that
  signature with no extra on-chain bytes. Used twice in zkCoins: by each
  spender to bind their off-chain `ProofData` into the `SpendRecord`
  signature (verified in-circuit by the publisher\'s
  `AggregateBatchProof`), and by the publisher to bind the off-chain
  `AggregateBatchProof` into the `BatchInscription` signature
  (#link(<32-batchinscription-signing-bip-340--sign-to-contract>)[§3.2]).
  (#link(<32-batchinscription-signing-bip-340--sign-to-contract>)[§3.2])
- #strong[`skᵢ`] --- rotating per-transition signing key (SPEND branch);
  `sk₀` is the initial key that fixes the address.
  (#link(<12-key-hierarchy>)[§1.2])
- #strong[SMT (Sparse Merkle Tree)] --- 256-bit-depth Merkle tree with
  default-hashed empty subtrees; used for the coin-history root and the
  global nullifier accumulator.
  (#link(<16-trees-one-global-structure-one-per-account-structure>)[§1.6],
  #link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6])
- #strong[SpendRecord] ---
  `{public_key, nullifiers, signature, message}`\; an #strong[off-chain]
  object: a spender produces one per transition and hands it to a
  publisher; the publisher aggregates many into a `BatchBundle` whose
  `AggregateBatchProof` is the actual artefact that anchors them to
  Bitcoin via a `BatchInscription`.
  (#link(<14-identifiers-and-hashes>)[§1.4],
  #link(<34-the-publisher>)[§3.4])
- #strong[`ss` (shared secret)] --- `ECDH(esk, IVPK) = ECDH(ivk, epk)`\;
  the input to `K_tx`.
  (#link(<13-per-coin-keys-note-encryption--detection>)[§1.3])
- #strong[Tag (domain-separation tag)] --- the string
  `"zkCoins/v1/<context>"` prefixed to every `Hc`/`HKDF` call; reusing a
  tag for two purposes is forbidden.
  (#link(<11-cryptographic-primitives>)[§1.1])
- #strong[Transaction state] --- see `completed`, `failed`, `pending`,
  and `mint-verified` (#link(<310-transaction-states>)[§3.10]).
- #strong[Transition] --- one execution of the compliance predicate `C`
  (mint, send, or receive). (#link(<23-state-transitions>)[§2.3])
- #strong[View grant] --- `op`-signed delegated viewing key (Bech32m
  `zkgrant`), scoped by `asset_ids` and time.
  (#link(<52-view-grant>)[§5.2])
- #strong[`zkavk`] --- bearer account view key (Bech32m), payload
  `ivk ‖ ovk`\; sees the full account history; non-revocable.
  (#link(<58-address-view-full-history>)[§5.8])
- #strong[`zkbid`] --- bearer confirmation-link locator (Bech32m),
  payload `blob_id = H(ciphertext)`\; content-addresses the one coin\'s
  bundle so any replica can serve it.
  (#link(<56-shareable-confirmation-links>)[§5.6])
- #strong[`zkgrant`] --- see #emph[View grant].
- #strong[`zkview`] --- bearer per-coin view capability (Bech32m),
  payload `K_tx`\; decrypts exactly one coin.
  (#link(<53-per-coin-view-capability>)[§5.3])

=== See also
<see-also>
- #link(<contents>)[Contents] --- the order to read the spec sections
  in.
- #link("/requirements")[Requirements] --- the ten non-negotiable
  properties this glossary\'s identifiers exist to satisfy.
- #link(<test-vectors-conformance-harness>)[Test vectors] ---
  worked-example values for the identifiers above.

== Test vectors (conformance harness)
<test-vectors-conformance-harness>
#quote(block: true)[
#emph[In one sentence: a fixed worked example with concrete hex values
for every identifier defined by SHA-256/Bech32m (computed and pinned
here) and an explicit conformance harness for the Poseidon-derived
values, to be filled in by the reference implementation once §1.7 is
implemented.]
]

This page exists so that two independent implementations can
#strong[bit-for-bit verify] they implement the spec identically. Where a
value depends only on SHA-256 / Bech32m / byte serialization (per
#link(<14-identifiers-and-hashes>)[§1.4] and
#link(<17-encoding-serialization-and-the-reference-instantiation>)[§1.7]),
it is pinned here. Where a value depends on Poseidon over Goldilocks
(#link(<11-cryptographic-primitives>)[§1.1],
#link(<171-poseidon-instance-and-digest-encoding>)[§1.7.1]) --- and
therefore on the reference instantiation pending cryptographic review
--- its #strong[formula] is pinned but its #strong[bytes] are marked
#strong[`<REGEN>`] and MUST be filled in by the reference
implementation. No Poseidon byte values are guessed or fabricated here.

=== V.1 Sample inputs
<v1-sample-inputs>
The sample keys are #strong[illustrative], not derived from a real
BIP-32 path. Real wallets derive `Pk₀`, `Pk₁`, `nk` from the seed via
#link(<12-key-hierarchy>)[§1.2]\; for the purpose of exercising the
byte-level identifier derivations on this page, they are fixed
deterministically as `SHA-256` of fixed ASCII strings:

#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([Symbol], [Definition], [Hex (32 bytes)],),
    table.hline(),
    [`Pk₀_sample`], [`H("zkCoins/v1/test-vector/Pk0")`], [`5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746`],
    [`Pk₁_sample`], [`H("zkCoins/v1/test-vector/Pk1")`], [`fba3ea150382de6f39a07348d327b1efa8c120da1ee599148ff6fed7803465fb`],
    [`nk_sample`], [`H("zkCoins/v1/test-vector/nk")`], [`2dc00b27c0d2991514b1b997af97b0e12c5da159b5726481124032c1578115b2`],
)

Asset definition:

#table(
    columns: 2,
    align: (auto,auto,),
    table.header([Field], [Value],),
    table.hline(),
    [`name` (UTF-8)], [`USD-Demo`],
    [`H(name)`], [`aff024cf2705e0450bfb51b461a1ed90c125efe0e43554191380b69a6a6be313`],
    [`decimals`], [`0x02` (2)],
    [`genesis_tag`], [ASCII `zkCoins/v1/genesis` (18 bytes:
    `7a6b436f696e732f76312f67656e65736973`)],
)

`Pk₀_sample` is treated as an x-only 32-byte string for the purpose of
`address = H(Pk₀)`\; a real BIP-340 key must be a valid x-coordinate on
secp256k1. This caveat does not affect the `address`/Bech32m derivation,
which depends only on the 32-byte input.

=== V.2 Address derivation (SHA-256 + Bech32m --- pinned)
<v2-address-derivation-sha-256--bech32m--pinned>
```
Pk₀_sample (32B) = 5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746
address          = H(Pk₀_sample)
                 = fd201c457bddb7571cca1f8d63ad0a5630ceec4f77e238bbd61cc8bc26a03298
zk-bech32m       = zk1l5spc3tmmkm4w8x2r7xk8tg22ccvamz0wl3r3w7krnytcf4qx2vqujc5px
```

A conforming implementation #strong[MUST] produce exactly these bytes
and exactly this Bech32m string from the inputs above. The Bech32m HRP
is `zk`\; the encoding is per
#link(<177-bech32m-and-bitcoin-conventions>)[§1.7.7]. The Bech32m
checksum constant is the BIP-350 value `0x2BC830A3`.

=== V.3 `serialize(AccountState)` byte layout (pinned for the SHA-256 parts)
<v3-serializeaccountstate-byte-layout-pinned-for-the-sha-256-parts>
A worked example: an account holding 1 000 000 000 base units of
`USD-Demo` after one transition, with an empty coin history.

```
Fixed fields  (pinned bytes):
   owner               (32B): fd201c457bddb7571cca1f8d63ad0a5630ceec4f77e238bbd61cc8bc26a03298
   current_pubkey      (32B): fba3ea150382de6f39a07348d327b1efa8c120da1ee599148ff6fed7803465fb
   send_counter        ( 8B): 0000000000000001
   coin_history_root   (32B): <REGEN — equals E'₂₅₆, the empty coin-history SMT root, see V.4>
   balances_count      ( 4B): 00000001
   [balances entry, sorted ascending by asset_id]:
       asset_id        (32B): <REGEN — see V.4>
       amount          (16B): 0000000000000000000000003b9aca00   ← u128 big-endian, 1 000 000 000

Sizes:
   prefix (without asset_id+amount): 108 bytes
   with one balance entry:           156 bytes
```

The conformance harness MUST construct the byte string in exactly this
order and re-derive
`ash = Hc("AccountState", <these bytes as a byte-string input>)` per
#link(<172-field-encoding-e-of-hc-inputs>)[§1.7.2] and
#link(<174-serializeaccountstate>)[§1.7.4].

`coin_history_root` for an empty account equals #strong[`E'₂₅₆`], the
empty-tree root of the per-account coin-history SMT (distinct from the
nullifier accumulator\'s `E₂₅₆` because the coin-history SMT uses
different domain tags `CoinHist/Leaf`, `CoinHist/Node`\; see
#link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6]). Both
values are Poseidon-dependent and listed in V.4 as `<REGEN>`.

=== V.4 Poseidon-derived values --- `<REGEN>` table
<v4-poseidon-derived-values--regen-table>
For each value below, the formula is fixed; the bytes MUST be produced
by the reference implementation conforming to
#link(<171-poseidon-instance-and-digest-encoding>)[§1.7.1] and
#link(<172-field-encoding-e-of-hc-inputs>)[§1.7.2], then pasted into the
rightmost column.

#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([Symbol], [Formula], [Bytes (`<REGEN>`)],),
    table.hline(),
    [`E₂₅₆` (nullifier-accumulator empty root)], [recursion from
    `E₀ = Hc("NfAcc/Leaf", 0)` and
    `Eᵢ = Hc("NfAcc/Node", i, E_{i-1}, E_{i-1})`\; the empty root is
    `E₂₅₆ = Hc("NfAcc/Node", 256, E₂₅₅, E₂₅₅)` ---
    #link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6]], [`<REGEN>`],
    [`E'₂₅₆` (coin-history-SMT empty root)], [same structure with the
    per-account tags: `E'₀ = Hc("CoinHist/Leaf", 0)` and
    `E'ᵢ = Hc("CoinHist/Node", i, E'_{i-1}, E'_{i-1})`\; empty root
    `E'₂₅₆ = Hc("CoinHist/Node", 256, E'₂₅₅, E'₂₅₅)` ---
    #link(<176-nullifier-accumulator-sparse-merkle-tree>)[§1.7.6]], [`<REGEN>`],
    [`asset_id`], [`Hc("AssetId", "zkCoins/v1/genesis" ‖ Pk₀_sample ‖ H("USD-Demo") ‖ decimals=0x02 ‖ issuance_version=0x01)`], [`<REGEN>`],
    [`ash_empty`], [`Hc("AccountState", serialize(canonical_empty_account_for(address)))`
    per #link(<22-proof-types>)[§2.2] --- the InitialProof\'s
    `prev_account_state` digest; uses
    `coin_history_root = E'₂₅₆`], [`<REGEN>`],
    [`coin.identifier@0`], [a coin minted to `address`, first output of
    the InitialProof:
    `Hc("Coin", ash_empty ‖ asset_id ‖ coin_index=0)`], [`<REGEN>`],
    [`coin_history_root@0`], [the per-account coin-history SMT root
    after admitting `coin.identifier@0` as leaf state `1`
    (received-unspent), starting from `E'₂₅₆`\; the result is a single
    populated path through 256 levels], [`<REGEN>`],
    [`ash@0`], [`Hc("AccountState", serialize(<V.3 byte string with the regenerated asset_id and coin_history_root@0 substituted>))`], [`<REGEN>`],
    [`nf_sample`], [`Hc("Nullifier", nk_sample ‖ coin.identifier@0)`], [`<REGEN>`],
    [`ocr@0`], [Poseidon Merkle root over `[coin.identifier@0]`, tag
    `CoinsRoot` (one leaf, padded to one) per
    #link(<175-poseidon-merkle-tree-used-for-ocr-and-inr>)[§1.7.5]], [`<REGEN>`],
    [`inr@0`], [Poseidon Merkle root over the empty list of nullifiers
    (a mint), tag `NullifiersRoot` --- equals the `L_⊥`
    leaf-hash], [`<REGEN>`],
    [`message@0`], [`inr@0 ‖ ocr@0` (concatenation of the two 32-byte
    values above)], [derived from the two above],
    [`H(ProofData@0)`], [per
    #link(<32-batchinscription-signing-bip-340--sign-to-contract>)[On-chain §3.2]:
    `SHA-256(ash@0 ‖ ocr@0 ‖ inr@0 ‖ coin_history_root@0)`], [derived
    from the four above],
)

=== V.5 `SpendRecord` byte layout (pinned for the SHA-256 / structural parts)
<v5-spendrecord-byte-layout-pinned-for-the-sha-256--structural-parts>
The `SpendRecord` is an #strong[off-chain] object: a spender produces it
and hands it to a publisher (see #link(<34-the-publisher>)[§3.4],
#link(<46-data-availability--replication-factor-k>)[§4.6]). It does not
appear on Bitcoin directly. Its canonical byte serialisation matters
because the publisher\'s `AggregateBatchProof`
(#link(<22-proof-types>)[§2.2]) binds each member SpendRecord into the
proof transcript, and the `BatchBundle` (whose `bundle_locator` is
inscribed) serialises every member SpendRecord deterministically.

For a send that spends one input coin, the per-record byte layout inside
a `BatchBundle` is:

```
Pkᵢ          (32B): <Pkᵢ — spender's current per-transition signing pubkey, x-only>
signature    (64B): <REGEN — BIP-340(skᵢ, message) with S2C tweak t = H(R' ‖ H(ProofData))>
message      (64B): <message = inr ‖ ocr>
k            ( 1B): 01                                                                ← one input coin
nullifiers   (32B): <nf = Hc("Nullifier", nk ‖ coin.identifier)>

Record size: 193 bytes for a typical single-input spend (32 + 64 + 64 + 1 + 32·k = 32 + 64 + 64 + 1 + 32).
```

The mint InitialProof case has `k = 0` (an empty nullifier list, 161
bytes total) and need not be batched at all: a creator who chooses not
to anchor a mint hands the receiver only the `CoinProof` bundle, and the
mint\'s validity is checked by direct recursive verification of the
`InitialProof` (#link(<231-mint--issuance>)[§2.3.1]).

=== V.6 `BatchInscription` byte layout (pinned for the structural parts)
<v6-batchinscription-byte-layout-pinned-for-the-structural-parts>
A `BatchInscription` carries a constant-size 231-byte payload regardless
of the number of member SpendRecords in the batch. Sample values are
illustrative; the publisher\'s identity key and S2C-tweaked signature
are produced by the publisher and `<REGEN>`:

```
Payload (231 bytes):
   marker                    ( 2B): 4242
   version                   ( 1B): 02                                ← Variant-2 batch inscription
   publisher_pubkey          (32B): <Pkₚ — publisher's BIP-340 x-only identity key>
   prev_root                 (32B): <accumulator root the batch builds on, §3.7>
   new_root                  (32B): <resulting accumulator root after this batch, §3.7>
   bundle_locator            (32B): <Hc("BatchBundle", serialize(BatchBundle)) — content address>
   block_anchor.block_hash   (32B): <REGEN — Bitcoin chain-specific; pinned per deployment, not by this spec>
   block_anchor.height       ( 4B): <REGEN — illustrative u32 big-endian Bitcoin block height>
   signature                 (64B): <REGEN — BIP-340(skₚ, batch_message) with S2C tweak t = H(R' ‖ H_agg)>

Total inscription: 231 bytes inscribed, ENTIRELY in witness data, ~58 vBytes amortised.
```

The `batch_message` preimage (covered by the BIP-340 challenge) is the
fixed concatenation
`prev_root ‖ new_root ‖ bundle_locator ‖ block_anchor.block_hash ‖ block_anchor.height`
(160 bytes total). The S2C input
`H_agg = H(serialize(AggregateBatchProof))` is computed once over the
canonical serialisation of the publisher\'s recursive proof carried in
the `BatchBundle`. This matches the size note in
#link(<35-inscription-format>)[§3.5].

=== V.7 How to use these vectors
<v7-how-to-use-these-vectors>
+ Implement #link(<171-poseidon-instance-and-digest-encoding>)[§1.7.1]
  (Poseidon over Goldilocks, Plonky2 `PoseidonGoldilocksConfig`) and
  #link(<172-field-encoding-e-of-hc-inputs>)[§1.7.2] (`E(·)`
  byte-to-field encoding).
+ Compute each `<REGEN>` row of V.4, in order (later rows depend on
  earlier).
+ Substitute the regenerated values into V.3 (`asset_id`,
  `coin_history_root`) and V.5 (`message@0`).
+ Compute `ash@0` from the resulting `serialize(AccountState)` per
  #link(<174-serializeaccountstate>)[§1.7.4] and verify it matches the
  V.4 entry.
+ Compute the BIP-340 signature with sign-to-contract per
  #link(<32-batchinscription-signing-bip-340--sign-to-contract>)[§3.2]
  and fill in V.5\'s `signature`. The signing key is a real secp256k1
  key derived from a real BIP-32 path; a separate test-key fixture is
  needed because the V.1 illustrative `Pk₀_sample` is a raw 32-byte
  string, not a curve point.
+ Submit the completed vectors back to the spec as a PR; once two
  independent implementations agree on the same hex, the reference is
  locked.

Until V.4 is filled in by a reference implementation, no `<REGEN>` row
should be treated as authoritative. #strong[Do not invent Poseidon
digests.] A wrong vector is worse than no vector: it would lead two
implementations to validate against each other\'s mistakes.
