---
title: Specification Review Remediation
---

# Specification Review Findings and Remediation

:::warning Review status

This page is a **non-normative remediation register**. It is not an implementation audit,
cryptographic audit, legal opinion, or proof of security. A proposed change becomes part of the
protocol only after it is incorporated into the normative [Specification](/specification), reviewed,
implemented, and verified at the applicable release gate.

The current release decision is **research only, with no real value at risk**. Open or partially
closed P0 findings, including the current-target receive-publication contradiction V3-P0-01, prevent
a Regtest-prototype release under the project's own release rules and prevent every Signet, testnet,
and mainnet release. The project-mandated DNS-continuity gate V3-P1-01 independently blocks the same
releases until its required design and fault-injection evidence exist.

:::

## Review baseline and current target

The first review round examined
[`zk-coins/docs@6816fc3`](https://github.com/zk-coins/docs/commit/6816fc398ea35284e640ed8e0b326fa96880cf7d)
(`specification.md` SHA-256
`61d78f5fc462b463abfda4d3b6b03f342ea92ede70f80fdac1c3b733f55d61d4`). The current
disposition in this register is evaluated against
[`zk-coins/docs@6ca36ab`](https://github.com/zk-coins/docs/commit/6ca36ab9377cb0d0ebe7eb6c3cfedeaffd25e056)
(`specification.md` SHA-256
`dfc81d5206807fc8f1cfe0e3371900e69bffdf7b2aea02b08977268397705952`).

The current target already replaces the reviewed root-chain design with the V3 paper model:
`AggregateStateNullifierV3`, NISSHAC half-aggregation, Bitcoin first-occurrence ordering, and
conditional NAV. This register therefore does not propose repairs to retired `C_batch`,
`BatchBundle`, `prev_root`, or public-bundle admission mechanisms. It carries forward only the
security requirement behind a retired finding when that requirement still applies to V3.

## Method and limits

The review used 25 structured perspectives. Each perspective read the complete pinned baseline in
an isolated first round. A second round challenged severities, assumptions, counterexamples, and
proposed remedies across perspectives. This produced 290 raw finding records. Duplicate reports of
the same root cause were merged without discarding distinct impacts, leaving the complete baseline
set of 42 consolidated findings below: 10 P0, 17 P1, 10 P2, and 5 P3.

A separate review of the current target found V3-P0-01, a normative contradiction introduced after
the pinned baseline. It is tracked explicitly because following either side of that contradiction
changes funds liveness. A subsequent project-mandated transport analysis adds V3-P1-01: established,
authenticated sessions must remain independent of DNS after connection setup. Neither delta finding
has a baseline raw ID, and neither alters the 290/290 baseline traceability result. The register
therefore contains 42 baseline workstreams plus two current-target delta findings, for 44 tracked
work items in total: 11 P0, 18 P1, 10 P2, and 5 P3.

The 25 perspectives are review lenses, not a claim that 25 external human auditors approved this
work. “Complete” means complete for this review set; undiscovered defects can still exist. The
current-status assessment is a specification delta review, not a repetition of all 25 reviews over
the current implementation.

Anything that depends on source code, generated circuits, build artefacts, Bitcoin transactions,
tests, benchmarks, operations, or deployed user interfaces is **not provable from the specification
alone**. `CLOSED IN SPEC` therefore means only that the current normative text addresses the
reviewed specification defect. It does not establish implementation conformance or release safety.

## Current system classification

| Dimension | Current classification |
|---|---|
| Proof type | A transparent, recursive Plonky2 PCD/validity-proof design with an intended zero-knowledge property. It is not a fraud-proof or optimistic challenge system. The concrete system-level ZK and knowledge-soundness claims remain unproved pending RB-P1-01. |
| Statement and witness | `C` exposes the specified `ProofData` digests and consumed state key; the witness contains prior state/proof data, coins, paths, keys, signatures, outputs, and conditional-NAV openings. Exact relation and composition work remains open. |
| Prover | The wallet's own node/kernel builds the witness and proof. The thin wallet keeps the SPEND key and produces the transition signature. |
| Verifier | The receiver's own node and other full zkCoins nodes verify proofs and reconstruct public state. A foreign-node-only client delegates correctness and liveness to that node. |
| Bitcoin enforcement | Bitcoin validates, orders, and commits the ordinary commit/reveal transactions and their bytes. Bitcoin Script does not verify a zkCoins proof, balance rule, asset rule, conditional NAV, or `CoinProof`. zkCoins software assigns those meanings off-chain. |
| Consensus changes | None. The design uses currently active Bitcoin capabilities and an application-level inscription convention; no new opcode or inactive BIP is assumed. |
| Asset and BTC scope | Core zkCoins transfers issuer-defined assets. It specifies no BTC deposit, reserve, peg-out, withdrawal, emergency exit, or enforceable BTC claim. A BTC bridge is a separate protocol and trust model. |
| Custody | The SPEND key remains in the wallet. Private `CoinProof` and account-state data are also custody-critical because their complete loss can make an internal coin permanently unspendable. The current signing handshake does not yet bind a wallet-verifiable canonical intent. |
| Public data availability | The public double-spend view is rebuilt from V3 nullifiers on Bitcoin and no longer depends on a public off-chain `BatchBundle`. |
| Private data availability | `CoinProof` bundles remain encrypted, off-chain bearer data with a target replication factor. Bitcoin cannot reconstruct a universally lost private bundle. |
| Transport and DNS continuity | Clearnet reachability, relay and blob URLs, publisher endpoints, and internal service names can depend on DNS. The current specification does not guarantee that an already-open authenticated transport remains usable when resolvers fail. DNS may block a new dial or reconnect; it must not become a continuing authority or liveness dependency for an established session. |
| Exit model | There is no BTC exit because core zkCoins does not accept BTC. An internal asset remains spendable only while its private proof/state material and spend authority remain recoverable. |
| Upgrade model | The project is greenfield and has no production lineage to migrate. Before real value, it still needs a prospective release-identity, opt-in fork or reviewed bridge, rollback, and succession model. |

## Project-native remediation constraints

Every fix in this register follows these constraints:

1. `docs/specification.md` remains the sole normative protocol source. This page records work; it
   does not silently change the protocol.
2. V3 is the only target. Retired root-chain and public-`BatchBundle` mechanisms are not restored.
3. The wallet, SDK, and app stay thin. They do not verify proofs, scan Bitcoin, compare multiple
   nodes for integrity, or implement a second zkCoins validator.
4. Wallet-side derivation, canonical serialization, hashing, human-readable intent display, and
   signing remain permitted because they are the spend-authorisation boundary, not node-validation
   logic.
5. The core protocol handles issuer-defined assets, not BTC. Any BTC bridge requires a separate
   specification, trust matrix, reserve invariant, withdrawal design, and audit.
6. The system remains greenfield until a real-value genesis. Prototype data can be reset; no repair
   may pretend that unlaunched V1 funds require migration.
7. One full node implementation remains acceptable if independent primitive parity, independent
   decoders and test harnesses where security-relevant, reproducible artefacts, formal review, and
   external audits provide a justified alternative to a second full implementation.
8. DNS is used only to discover and open a transport. Once every required networked hop is
   authenticated and established and any in-process hop is available within its operator-isolation
   boundary, resolver failure must not close, drain, rebind, redirect, or block that channel. New dials
   and reconnects may fail, but no implementation may weaken TLS, hostname, onion, mTLS, or
   peer-identity validation to hide that failure.

## Status summary

| Status | Meaning | Baseline 42 | V3 delta | All tracked |
|---|---|---:|---:|---:|
| `OPEN` | The reviewed defect, its V3 equivalent, or a current-target gap remains materially unresolved. | 11 | 2 | 13 |
| `PARTIAL` | Current text closes part of the defect, but a stated security, consistency, or evidence requirement remains. | 23 | 0 | 23 |
| `CLOSED IN SPEC` | Current normative V3 text fully addresses a surviving specification defect; implementation evidence would still be required. | 0 | 0 | 0 |
| `SUPERSEDED BY V3` | The vulnerable V1 object or mechanism no longer exists; it must not be reintroduced. | 4 | 0 | 4 |
| `CONDITIONAL` | The work becomes mandatory at the stated claim, deployment, or release boundary. | 4 | 0 | 4 |

## Current-target delta findings

### V3-P0-01 — Pure-receive publication rules contradict one another

- **Status:** `OPEN`
- **Current sections:** [§1.4](/specification#14-identifiers-and-hashes),
  [§2.1](/specification#21-the-compliance-predicate),
  [§2.3.3](/specification#233-receive),
  [§3.1](/specification#31-the-on-chain-object),
  [§3.2](/specification#32-transition-signing-bip-340--sign-to-contract),
  [§3.10](/specification#310-transaction-states)
- **Finding:** Most of V3 requires every state-advancing send, receive, and mint to publish its own
  `(Pk_i, R_i)` and reach `completed`. Section 3.2 instead says a pure receive “publishes nothing.” If
  an implementation follows that sentence, the receive advances and rotates the private account
  head without anchoring the consumed key. The next `AccountUpdateProof` cannot satisfy mandatory
  predecessor-nullifier membership for that receive, so the account lineage can become permanently
  unextendable.
- **Project-native fix:** Delete the publication exemption. Normatively require every successful
  receive transition to produce a `SpendRecord` and hand the on-chain nullifier material
  `{Pk_i, R_i, s_i}` to the selected publisher path, including a self-operated publisher. The
  pre-tweak nonce `R'_i` never travels to the publisher — it is off-chain bundle data that goes
  sender→recipient inside the `CoinProof`, where the *receiver* performs the sign-to-contract
  opening check `R_i = R'_i + H(R'_i ‖ H(ProofData))·G` (§2.3.3 step 4). The publisher
  half-aggregates only `(Pk_i, R_i)` and inscribes the canonical V3 raw or aggregate payload;
  `R'_i` is forbidden on chain. The receive remains non-creditable and non-extendable until its nullifier
  reaches the specified admissible state. Define one state machine for receive proof creation,
  private persistence, publication, first-occurrence loss, completion, retry, reorg, and abandonment;
  it must preserve the thin-wallet boundary and use the same V3 publisher path as send and mint.
- **Acceptance criteria:** A normative-reference check finds no receive-publication exemption.
  Circuit, node, SDK, and Regtest vectors cover initial receive, pure receive, receive-plus-send,
  receive→next-spend, concurrent receives, first-occurrence loss, publisher retry, crash before and
  after publication, and reorg before and after `completed`. Every accepted successor proves
  membership of the exact receive nullifier under the receive proof's exposed `consumed_pubkey`; an
  unanchored receive head can never be reported as spendable or canonical.

### V3-P1-01 — Established authenticated transports lack DNS-outage continuity

- **Status:** `OPEN`
- **Current sections:** [§4.1](/specification#41-roles-and-transport),
  [§4.2](/specification#42-bundle-delivery),
  [§4.3](/specification#43-addressing-for-delivery),
  [§4.9](/specification#49-real-time-push-delivery),
  [§6.1](/specification#61-components-and-responsibilities),
  [§7.2](/specification#72-transport-map-normative),
  [§7.5](/specification#75-node-rest-api-normative),
  [§7.8](/specification#78-kernel-rpc--the-internal-interface-normative)
- **Finding:** The specification names the network planes and defines peer or message authentication
  for only some of them, but it does not define any plane's resolver or connection-pool lifecycle.
  In particular, NIP signatures authenticate Nostr events rather than the relay socket, and the
  `bitcoind` and PostgreSQL transport/authentication profiles are not specified. An implementation
  may therefore resolve a hostname per request, drain a healthy pool after TTL expiry, or translate
  `SERVFAIL` or an empty resolver update into zero usable endpoints. It may also make DNS health part
  of session authorization. A DNS-only outage can
  then stop an already-connected wallet, node, relay, blob store, publisher, or internal service even
  though its existing socket and peer remain healthy. If this happens after a signature or
  delivery hand-off, it can stall publication, private-state delivery, replication, ACK, or recovery.
- **Severity rationale:** This is P1 because it creates a system-wide, avoidable liveness and
  censorship path but does not by itself demonstrate theft, invalid-state acceptance, or permanent
  loss. Any implementation that discards an accepted transition, bundle, change record, nonce, or
  outbox entry when DNS fails also triggers the P0 crash-atomicity defect RB-P0-10.

**Accepted fault boundary.** A *DNS-only outage* starts at time `t0`: configured resolvers time out,
return `SERVFAIL`/`NXDOMAIN`, or provide no endpoints, while the network route, peer processes,
storage, keys, application authorization, and already-open sockets remain healthy. An *established
channel* means every required networked hop is already open and authenticated under its deployment
profile, while any non-networked in-process hop is available and operator-isolated. A cached hostname
or IP, a previously used endpoint, or an open client-to-load-balancer socket whose upstream connection
is absent is not an established end-to-end channel. A new HTTP request or protocol frame on an
existing persistent transport is not a new connection. A socket reset, peer restart, route or NAT
failure, HTTP/2 `GOAWAY`, WebSocket close, expired authorization that cannot renew in-band, or a
missing upstream hop is a different fault; reconnect may then fail as explicitly accepted.
Tor v3 `.onion` routing does not use ordinary DNS; a Tor daemon or circuit failure is a different
fault, while any clearnet or internal DNS hop in the same deployment remains in scope. The optional
APNs/FCM wake signal is outside the trustless core and cannot count as evidence for this guarantee;
its loss must not block canonical delivery or an already-established core receipt path.
The resolver is trusted for new-connection reachability and necessarily learns resolution metadata;
TLS/onion/mTLS authentication or the normatively defined deployment-local authentication and
isolation mechanism, not DNS, binds the authorised peer or endpoint. The resolver has no authority
over an already-authenticated session.

**Project-native invariant.** The normative specification must define at least the transport states
`resolving`, `connecting`, `authenticating`, `established`, `reconnect_wait`, and `closed`, with these
rules:

1. DNS participates only in `resolving` for a new transport. Entering `established` binds the channel
   to its configured origin and the peer identity authenticated by TLS hostname/SNI and certificate,
   Tor v3 onion key, mTLS identity, or a deployment-profile-specific local authentication and
   isolation mechanism. The remediation must normatively define that mechanism for every networked
   pool, including `bitcoind` and PostgreSQL. For Nostr, relay endpoint authentication and signed-event
   authentication are distinct checks and neither substitutes for the other.
2. DNS timeout, `SERVFAIL`, `NXDOMAIN`, TTL expiry, cache invalidation, rebinding, or an address change
   alone must not make an `established` channel leave that state; change its peer, origin, SNI, Host,
   ALPN, authorization, or `chan_bind`; clear its healthy pool; or fail a readiness check for that
   channel.
3. Requests, new HTTP/2 streams, gRPC calls, SSE events, WebSocket/Nostr frames, keepalives, and
   in-band reauthentication or rekeying that fit on the existing channel must proceed without a
   resolver call. DNS is not on the active data path.
4. The invariant applies to every hop. A reverse proxy, load balancer, service mesh, or split
   API/kernel deployment must retain its already-established upstream pools, authenticated or
   operator-isolated as its deployment profile requires, as well as the client-facing connection. A
   frontend connection cannot be used to claim continuity when its required backend hop still needs
   a new dial.
5. DNS failure must never trigger plaintext HTTP, disabled hostname or certificate checks,
   IP-as-identity, an unverified stale-address dial, cross-origin connection coalescing, or silent
   selection of another node, relay, store, publisher, or proxy. An optional cached-address reconnect
   remains a new connection and is safe only with the original endpoint/origin, applicable SNI, and
   complete deployment-profile peer or local-endpoint validation; it is outside the continuity
   guarantee.
6. If an operation requires a missing hop or the socket actually closes, a new connection or
   reconnect may fail. Accepted work remains fail-closed in a durable transactional outbox with its
   idempotency key, cursor, target origin, authorization context, and retry state. DNS failure cannot
   produce a false `delivered`, `replicated`, `credited`, `published`, or `completed` state, and cannot
   let a sender delete its last private-data copy.
7. After resolver recovery, queued work reconnects with normal deployment-profile peer or endpoint
   validation and resumes idempotently from its durable cursor. Backoff and jitter prevent retry
   storms; queue exhaustion applies backpressure before accepting or signing new work, never eviction
   of value-bearing state.
8. The invariant lasts as long as the authenticated or operator-isolated transports and application
   authorization remain open. Each deployment also publishes and tests a minimum
   `dns_continuity_window`. Heartbeats must be shorter than every hop's idle timeout; routine
   maximum-age, drain, credential-refresh, and connection-rotation policies must exceed that window or
   renew in-band. A security revocation may close a session, but it is recorded as a security event
   rather than misreported as DNS continuity.

**Channel-by-channel effect.** A workflow continues only when every channel it needs is already
established; the failure of an unneeded or not-yet-open plane must not disturb the others.

| Channel | Must continue over an established transport | May be unavailable during DNS outage |
|---|---|---|
| Wallet/SDK ↔ node API | REST requests on an existing H1 keep-alive or H2 connection; proving handshake; job and receipt SSE/WebSocket streams; in-band pull challenge/session use | Initial node dial, node switch, reconnect, or an additional pool socket |
| API layer ↔ kernel | Existing in-process path or already-open operator-internal gRPC unary/server streams; mTLS identity where that §7.8 profile is used | New container/upstream connection after the internal hop closes |
| Kernel ↔ `bitcoind` and PostgreSQL | Chain reads, broadcasts, and durable state operations on pools already authenticated under the deployment profile added by this remediation | Initial dial, replacement pool member, or reconnect after a real socket/database failure |
| Node ↔ Nostr relay | `EVENT`, `REQ`, ACK, Ping/Pong, delivery, discovery, and receipt traffic on the open WebSocket; NIP signatures authenticate events separately from relay endpoint identity | A new relay, relay migration, or WebSocket reconnect |
| Node ↔ Blossom store/replica | `GET`, `HEAD`, and `PUT` to the same origin through an existing H1/H2 pool | A locator on an unopened origin or replacement connection; missing replication remains pending |
| Spender node/kernel ↔ remote publisher REST | The single quote-bound `POST /v1/publish/spendrecord` and its immediate response on an existing H1/H2 channel | Selecting or dialing a publisher; closure also requires the specification to add the authenticated publisher endpoint source that the current publisher profile omits |
| Local API/kernel self-publisher | Existing in-process `Publish` path, or the already-open §7.8 internal channel in a split deployment; no separate publisher DNS dial | A new internal RPC connection after that channel closes |
| Explorer/browser ↔ current origins | Existing HTTPS and relay streams, subject to the same authenticated-channel rules | A new explorer, relay, blob origin, redirect, or browser connection |
| Handle resolver | Requests on an already-open authenticated HTTPS connection may continue | First-time handle resolution, refresh requiring a new connection, or a different domain; a previously authenticated direct Invoice remains subject to its own validity rules |
| Proxy/LB/service mesh hops | Existing frontend and backend pools for the logical channel | Any missing or closed upstream connection; DNS-independent frontend health alone is insufficient |
| Optional APNs/FCM wake path | No protocol-critical continuity obligation; an opaque wake that arrives may only accelerate the existing verified fetch path | Vendor-managed delivery or reconnect may be unavailable; it cannot replace canonical Nostr delivery or core continuity evidence |

**Counterexample and attack scenario.** The wallet opens an H2 connection to its node, creates a
transition, and signs it. DNS then returns `SERVFAIL`. A TTL-coupled client pool drains the healthy H2
socket, while the reverse proxy also clears its still-healthy API→kernel endpoints. The node has
durable work but can no longer receive the signature, deliver the `CoinProof`, or hand the nullifier
to the publisher. A careless retry path reports the job failed or drops the delivery record. The
required design instead keeps every established hop usable; if any hop truly closes, it leaves the
job and private state durable and visibly pending until a secure reconnect is possible.

**Acceptance criteria.** Closure requires executable fault injection, not a configuration claim:

1. Establish and authenticate every enabled networked hop in each supported deployment profile, and
   make every non-networked in-process hop available under its operator-isolation boundary, including
   frontend and upstream proxy paths. Then blackhole DNS, inject timeout, `SERVFAIL`, `NXDOMAIN`, empty
   endpoint updates and rebinding, and run beyond all configured TTLs.
2. While rejecting every new socket and permitting only already-established flows, complete a real
   Bitcoin Core Regtest V3 funds flow with every distinct anchoring gate visible: mint proof → mint
   nullifier publisher hand-off → Bitcoin first-occurrence/finality → mint `completed` → pay/send
   proof plus durable, `k`-replicated `CoinProof` delivery → send nullifier publisher hand-off →
   Bitcoin first-occurrence/finality → send `completed` → recipient re-verification → receive proof,
   signature, fold, and durable persist → verified/pending receipt push that is explicitly not final
   or spendable → encrypted ACK → receive nullifier publisher hand-off → Bitcoin
   first-occurrence/finality → receive `completed` → spendable-status push. Use a pre-authenticated
   direct Invoice and the warmed node, kernel, database, `bitcoind`, Nostr, Blossom, publisher, proxy,
   and core SSE/WebSocket push channels; APNs/FCM cannot satisfy this step. All three publications and
   all three chain-observation/finality gates must traverse only connections established before fault
   time `t0` and complete without a reconnect. No protocol step may collapse mint, send, and receive
   into one publication or delay the initial verified receipt until receive finality.
3. Exercise H1 sequential reuse, new H2 streams, gRPC unary/server streams, SSE, WebSocket/Nostr,
   Blossom upload/download, `bitcoind` RPC, database operations, and publisher hand-off for the full
   declared `dns_continuity_window`. Where the supported profile implements them, also exercise TLS
   1.3 `KeyUpdate` and in-band application reauthentication without a resolver call. A TLS 1.2,
   non-TLS local, or long-lived-authorization profile instead keeps the same authenticated or
   operator-isolated channel usable for the full window; its configured credential lifetime must
   exceed that window when no in-band renewal exists.
4. Measure `active_channel_closures_caused_by_dns = 0`,
   `resolver_calls_on_established_channel_hot_path = 0`, and
   `false_success_after_dns_failure = 0`. Connection IDs and authenticated peer identities or
   operator-local endpoint bindings remain unchanged. A changed DNS answer must not migrate an
   established socket or alter its bound origin, SNI, Host, ALPN, authorization, or `chan_bind`.
5. In a separate rebinding case, deliberately close the channel and permit the resulting new-dial
   attempt. Enforce the configured origin's deployment-specific address policy: an endpoint outside
   its allowed or pinned address set is rejected before connect, including an unexpected
   public-origin→loopback/private/link-local rebinding. An explicitly local or self-hosted origin may
   use its configured local address class, but only with its pinned endpoint policy and required
   local/TLS/mTLS peer authentication. Test both rejection of the unauthorised rebind and acceptance
   of the authorised local target. A public attacker endpoint that passes address policy still fails
   TLS/onion/mTLS peer authentication before any authorization, secret, or application-protocol
   payload is sent. The dial retains the original origin and, where applicable, SNI, Host, and
   peer-identity policy. If last-known-good or cached-address reconnect is implemented, test it
   separately against the legitimate peer or local endpoint with the original origin/applicable SNI
   and complete certificate, onion, mTLS, or normatively specified local authentication/isolation
   validation; the cached IP is never accepted as identity and this remains outside the continuity
   guarantee.
6. Close each networked channel deliberately while DNS remains unavailable. Only that channel enters
   `reconnect_wait`; new dials and first-time handle resolution fail clearly, all accepted work and
   cursors remain durable, other established channels continue, and no insecure fallback occurs.
7. Restore DNS first to the original address and then to a legitimate new address. Normal TLS, onion,
   mTLS, or normatively specified local authentication/isolation checks run for the new connection or
   endpoint, queued work resumes exactly once from durable state, and duplicate events, ACKs,
   publishes, and credits are idempotently rejected.

## P0 findings

### RB-P0-01 — Data-availability-dependent public admission

- **Status:** `SUPERSEDED BY V3`
- **Current sections:** [§3.1](/specification#31-the-on-chain-object),
  [§3.6](/specification#36-chain-scanning), [§3.7](/specification#37-the-nullifier-accumulator),
  [§4.6](/specification#46-data-availability--replication-factor-k)
- **Finding:** In the reviewed design, two nodes on the same Bitcoin chain could admit different
  root transitions when public `BatchBundle` data arrived in a different order. A later bundle did
  not normatively heal the sticky branch.
- **Current disposition:** V3 places each state nullifier on Bitcoin, defines a chain-derived total
  order, and folds the first occurrence of each `Pk` without consulting off-chain public data. This
  removes the reviewed split mechanism. Private `CoinProof` loss remains separately tracked by
  RB-P0-04.
- **Required closure evidence:** Model-check partitions, delayed private delivery, restarts, cold
  sync, duplicate publication, and reorgs of arbitrary depth. Two independently written scanner
  harnesses must derive byte-identical V3 accumulator states from the same adversarial block corpus.

### RB-P0-02 — The wallet does not authorize a canonical user intent

- **Status:** `OPEN`
- **Current sections:** [§2.1](/specification#21-the-compliance-predicate),
  [§3.2](/specification#32-transition-signing-bip-340--sign-to-contract),
  [§7.5](/specification#75-node-rest-api-normative)
- **Finding:** The node builds the witness and `ProofData`; the wallet signs a fixed message whose
  nonce commits a node-supplied digest. The current text does not require the thin wallet to prove
  that this digest represents the complete transition the user approved. Binding only visible
  payment fields would still let a compromised prover substitute the consumed state, transition
  branch, received admissions, issuance terms, conditional NAV, next state, delivery effects, or
  freshness context. The first maliciously published transition can consume the current key and
  leave the intended lineage unspendable without taking the SPEND key.
- **Project-native fix:** Define a canonical `TransactionAuthorizationV3`, constructed by the wallet
  SDK from the user request and the authenticated state snapshot it has chosen. Its domain-separated
  commitment binds the network/genesis, release and circuit identity, account, transition kind,
  complete pre-state hash, consumed key and counter, every input and received admission, mint and
  issuance fields where present, outputs, change, publisher fee, conditional-NAV opening or
  commitment and selected Bitcoin tip, complete post-state hash and next key, required delivery and
  publication effects, idempotency key, and expiry. The circuit constrains every field to the actual
  transition and includes the authorization commitment in `ProofData`; the wallet checks that exact
  value before producing the existing S2C signature. This is SDK-level derivation, serialization,
  hashing, and authorization, not proof verification or Bitcoin scanning. Because a thin wallet
  cannot establish chain canonicality by itself, relying on a foreign node remains an explicit
  correctness and liveness trust assumption and must never be described as non-custodial or
  trustless against that node.
- **Acceptance criteria:** Malicious-node E2E tests independently mutate every authorization field,
  use stale and forked pre-state heads, substitute the NAV/tip or circuit identity, omit delivery or
  publication effects, alter the `ProofData` field order, and replay an expired authorization. No
  mutation obtains a wallet signature for the changed commitment or a valid proof under the original
  commitment. Hardware and software wallet fixtures display the same security-relevant intent;
  cross-language encoders produce the same commitment; and the UI names the selected node trust
  boundary before a foreign-node signature is possible.

### RB-P0-03 — BTC and trust claims exceed the specified funds flow

- **Status:** `OPEN`
- **Current sections:** [Introduction](/), [Requirements](/requirements),
  [§3](/specification#3--on-chain-layer), [§6.5](/specification#65-issuance--versioned-schemas-v1-minimal),
  [Known Risks](/risks)
- **Finding:** The core protocol has no user BTC deposit, reserve, withdrawal, or emergency exit,
  while prominent language can still be read as private BTC payments, Bitcoin-enforced asset
  integrity, or a native Bitcoin settlement asset. Issuer-defined assets can be valid zkCoins
  assets without representing BTC.
- **Project-native fix:** Use one precise statement across every page and product surface: zkCoins
  transfers issuer-defined assets whose state nullifiers are ordered and committed on Bitcoin; it
  has no separate chain or protocol-native gas/settlement token, and core zkCoins assets are not
  BTC. Keep every bridge outside core until a separate bridge specification defines reserves,
  custody, peg-in, peg-out, unilateral or threshold exit, insolvency, and mass-exit behavior.
- **Acceptance criteria:** A claim-to-evidence test covers documentation, API descriptions, wallet
  copy, explorer copy, and deployment configuration. No core balance is labelled BTC, backed by
  Bitcoin, non-custodial BTC, or withdrawable to a Bitcoin UTXO without a separately reviewed bridge
  identifier and enforceable funds-flow proof.

### RB-P0-04 — Seed-only recovery is impossible for universally lost private bearer data

- **Status:** `PARTIAL`
- **Current sections:** [§1.2](/specification#12-key-hierarchy),
  [§4.5](/specification#45-recovery), [§4.6](/specification#46-data-availability--replication-factor-k),
  [§4.8](/specification#48-durability--the-store-everything-invariant)
- **Finding:** A seed recovers keys, not an unavailable `CoinProof`, its value, proof, provenance,
  state metadata, or undiscoverable account history. Bitcoin cannot reconstruct those private
  objects. Replication to `k` holders is an availability target, not a cryptographic guarantee.
- **Project-native fix:** Replace every “seed is the only backup” statement with a two-part recovery
  contract: seed for keys, plus a versioned, encrypted and authenticated user-portable recovery
  archive for all custody-critical private state and account-discovery metadata. Bind the archive to
  network/genesis, account set, schema and release identity; include a content-hashed completeness
  manifest, monotonic snapshot identifier, Bitcoin reconciliation anchor, and authenticated creation
  time. Export one atomic snapshot only after all included state and outbox effects are durable.
  Import must reject truncation, substitution, mixed versions and rollback to an older snapshot unless
  an explicit recovery procedure proves that rollback safe against the canonical Bitcoin view. Define
  replica acknowledgements, independence policy, repair, retention, export, import, and the
  irreducible result of universal loss. Do not claim that seed recovery heals universal bundle loss.
- **Acceptance criteria:** A destructive restore starts from empty infrastructure after deleting the
  wallet, node database, local blob store, and all but the documented surviving recovery source. It
  authenticates and reconciles the archive against Bitcoin, reconstructs every account, owned output,
  proof, state head, and pending action, then completes a real follow-up transition. Negative restores
  reject stale, truncated, substituted, cross-network, rollback, and mixed-release archives
  without overwriting newer valid state. Concurrent export and crash injection never yield a
  self-consistent-looking partial snapshot. A universal-loss test reports permanent loss explicitly
  and never reports successful seed recovery.

### RB-P0-05 — The Bitcoin transaction graph and parser are not fully specified

- **Status:** `PARTIAL`
- **Current sections:** [§3.5](/specification#35-inscription-format),
  [§3.6](/specification#36-chain-scanning)
- **Finding:** V3 now pins the payload, strict body consumption, and block/transaction/member order,
  but it still does not pin the complete commit/reveal transactions, Taproot internal key and leaf,
  executed authorization branch, control block, sighash, input/output ownership, multiple-envelope
  order, funding, recovery, or fee-bump paths. A payload envelope alone is not a spend authorization
  policy.
- **Project-native fix:** Add a byte-exact `AggregateStateNullifierV3` transaction package: funding
  and change outputs, internal key, taptree, leaf script, witness stack, control block, sighash mode,
  RBF/CPFP anchors, safe abort/recovery paths, and a total order over block, transaction, input,
  envelope, and member. Reject every alternative or ambiguous parse explicitly.
- **Acceptance criteria:** Publish raw transaction and block vectors for valid, malformed, duplicate,
  multi-input, multi-envelope, reordered, truncated, non-standard, RBF, CPFP, restart, and reorg
  cases. Bitcoin Core Regtest plus two independent parsers must accept and order exactly the same
  objects, and no unauthorized party can spend the publisher's commit output.

### RB-P0-06 — Delegated Path B does not authenticate the canonical accumulator

- **Status:** `PARTIAL`
- **Current sections:** [§3.7](/specification#37-the-nullifier-accumulator),
  [§6.3](/specification#63-node-portability-and-multi-node-operation),
  [§7.7](/specification#77-wallet--node-bootstrapping-normative)
- **Finding:** Current V3 correctly states that no on-chain accumulator root authenticates a Path-B
  SMT response and that a dishonest server can return false absence. It still asks a thin wallet to
  query multiple nodes or fall back to Path A, contradicting the project's hard thin-client rule and
  overstating what a self-verifying path establishes.
- **Project-native fix:** Treat Path B as explicitly trusted RPC for the answering node's claimed tip
  and state. The trustless path is a self-hosted Path-A node, which scans Bitcoin and verifies proofs
  on the wallet's behalf. Remove wallet-side multi-node integrity checks, proof verification, and
  Path-A scanning; retain fail-closed network/tip mismatch handling and ordinary node switching.
- **Acceptance criteria:** Specification, SDK, wallet, and UI use the same trust language. A foreign
  node cannot be presented as trustless or Bitcoin-verified. Integration tests show that all Path-A
  validation stays in the node and the thin client contains no scan loop, proof verifier, or
  second-node integrity decision.

### RB-P0-07 — Deep reorg handling lacks a complete circuit transition

- **Status:** `PARTIAL`
- **Current sections:** [§3.7](/specification#37-the-nullifier-accumulator),
  [§3.9](/specification#39-finality-and-reorg-handling),
  [§3.10](/specification#310-transaction-states)
- **Finding:** The reviewed design treated more than five blocks of reorganization as a protocol
  failure even though Bitcoin has no consensus-level maximum reorg depth. **Resolved for v1 by
  [#107](https://github.com/zk-coins/docs/pull/107):** the current target adopts a hard
  **6-confirmation finality bound** — reorgs of ≤5 blocks are absorbed by canonical replay, and a
  reorg of ≥6 blocks is an **accepted break** with no recovery path. The conditional-NAV no-op is
  **deliberately not built** ([§3.9](/specification#39-finality-and-reorg-handling),
  [Paper-Deviation Analysis D-16](/paper-conformance-analysis)); the original demand to define a
  no-op branch is retired under this register's own carry-forward rule.
- **Project-native fix:** No no-op branch is defined. The accepted v1 reorg model is documented in
  [§3.9](/specification#39-finality-and-reorg-handling): the single **execute** branch of `C`,
  canonical replay for reorgs of ≤5 blocks, and an accepted break for reorgs of ≥6 blocks.
- **Acceptance criteria:** Model and E2E tests cover reorg depths 1, 2, and 5 (tolerated, absorbed
  by canonical replay); competing nullifiers; already-consumed descendants; crashes during rewind;
  and repeated reorgs; plus confirmation that a reorg of ≥6 blocks is surfaced as the accepted
  break boundary rather than silently mis-handled. Restored nodes converge byte-for-byte via the
  single execute branch of `C`, with no host-side state transition outside `C`.

### RB-P0-08 — Strict proof decoding and authoritative circuit identity are absent

- **Status:** `PARTIAL`
- **Current sections:** [§1.7.8](/specification#178-reference-instantiation-review-status),
  [§1.7.9](/specification#179-proof-system-parameters-normative),
  [Test vectors](/specification#test-vectors-conformance-harness)
- **Finding:** The reference backend is named, but authoritative circuit digests remain `<REGEN>`,
  the prose description of Plonky2 `to_bytes()` conflicts with the reviewed upstream layout, and a
  complete strict decoder, canonical field rules, verifier data, and release manifest are not yet
  pinned. Different implementations can identify or decode different relations as the same version.
- **Project-native fix:** Before genesis, freeze one audited backend and publish the exact source and
  lockfile, build features, public-input layout, common and verifier-only data, circuit digest per
  network, canonical proof grammar, field/scalar/point rejection rules, and content-addressed release
  manifest. Replace every `<REGEN>` value with generated evidence. Independent decoders are required
  for the security boundary; a second full node is not.
- **Acceptance criteria:** Clean builds in two environments produce identical verifier manifests and
  circuit digests. The Rust implementation and at least one independent strict decoder round-trip
  every golden vector and identically reject non-canonical fields, lengths, points, trailing bytes,
  network confusion, verifier substitution, and mutated proofs.

### RB-P0-09 — A next spend key can be committed without a circuit-level `lift_x`

- **Status:** `OPEN`
- **Current sections:** [§1.2](/specification#12-key-hierarchy),
  [§2.1](/specification#21-the-compliance-predicate),
  [§2.6](/specification#26-in-circuit-non-native-cryptography-normative)
- **Finding:** The transition commits the next 32-byte x-only key into the successor state, but the
  relation does not explicitly require those bytes to decode to the canonical non-infinity,
  even-Y BIP-340 point. An accepted successor can therefore be unspendable.
- **Project-native fix:** Constrain every current and next spend key in-circuit as canonical
  big-endian `x < p_secp256k1`, where `p_secp256k1 = 2^256 - 2^32 - 977`; require BIP-340 `lift_x`
  to the even-Y non-infinity secp256k1 point, and feed exactly those bytes into the state and intent
  commitment. Host-side validation is additional defense, not a substitute.
- **Acceptance criteria:** Negative circuit vectors for `x >= p_secp256k1`, non-residues,
  infinity/null, parity, endianness, and foreign-field limb boundaries are unprovable in the
  transition that would create the bad successor. Positive BIP-340 vectors agree across the circuit
  and two host decoders.

### RB-P0-10 — State handoff is not crash-atomic

- **Status:** `PARTIAL`
- **Current sections:** [§4.2](/specification#42-bundle-delivery),
  [§4.8](/specification#48-durability--the-store-everything-invariant),
  [§7.5](/specification#75-node-rest-api-normative),
  [§7.8](/specification#78-kernel-rpc--the-internal-interface-normative)
- **Finding:** “Persist before acting” does not define one durable commit boundary across the new
  account head, owned outputs, `CoinProof`s, intent, nonce allocation, delivery, and publisher
  submission. A crash can leave an externally anchorable nullifier while change or the continuing
  private lineage is missing.
- **Project-native fix:** Specify one durable transition record and transactional outbox. The node
  fsyncs the new head, every locally owned proof/output, recovery metadata, canonical intent,
  idempotency key, and nonce reservation before any external publication or delivery becomes
  visible. Recovery resolves to exactly the old state with no external effect or the complete new
  state with an identifiable external effect.
- **Acceptance criteria:** Kill and power-fault injection after every database write, fsync, queue,
  upload, delivery, and broadcast boundary yields no lost change, reused nonce, duplicate effect, or
  unexplained head. A clean-room restore reconciles the durable outbox against Bitcoin and completes
  a subsequent real transition.

## P1 findings

### RB-P1-01 — Formal ZK, knowledge-soundness, and composition claims are incomplete

- **Status:** `PARTIAL`
- **Current sections:** [§1.7.8](/specification#178-reference-instantiation-review-status),
  [§1.7.9](/specification#179-proof-system-parameters-normative),
  [§2.1](/specification#21-the-compliance-predicate),
  [§2.4](/specification#24-soundness-summary)
- **Finding:** The current predicate is detailed but not a formal language and security game. It does
  not define adaptive knowledge soundness, a zero-knowledge simulator, recursive Fiat-Shamir/FRI
  composition, auxiliary input, lifetime query bounds, or a system soundness budget.
- **Project-native fix:** Define the exact relation, public statement, witness, completeness,
  knowledge-soundness and ZK experiments, assumptions register, recursion model, and workload-bound
  failure budget for the frozen backend. Narrow every privacy or soundness claim to the theorem that
  can actually be supported.
- **Acceptance criteria:** Independent cryptographic review accepts the definitions and their
  applicability to the exact circuit/backend manifest. The final system budget includes every proof,
  hash, signature, commitment, and recursion term at maximum supported lifetime and load.

### RB-P1-02 — Retired record binding leaves unresolved S2C algebra and encoding

- **Status:** `PARTIAL`
- **Current sections:** [§1.7.10](/specification#1710-half-aggregation-with-commitments-nisshac-normative),
  [§2.2](/specification#22-proof-types),
  [§3.2](/specification#32-transition-signing-bip-340--sign-to-contract)
- **Finding:** The reviewed publisher circuit could accept an external record not fully bound to the
  signature checked by the account circuit. That `C_batch` substitution path is retired, but this raw
  workstream also identified S2C semantics that V3 still uses for every `(Pk, R)`: final-`R` even-Y
  normalization, the exact `R'` encoding, tweak-to-scalar rule, commitment-opening wire semantics,
  and agreement between signer, circuit, receiver, publisher, and scanner.
- **Current disposition:** V3 removes `C_batch` and publisher proof aggregation, so external record
  substitution through that circuit is superseded. V3 does not yet give one byte-exact S2C algorithm
  that says how `k'`, `R'`, `t`, and `s` change when the tweaked point has odd Y, or how every role
  encodes and rejects those values. RB-P0-02 separately binds user authorization; RB-P0-08 pins strict
  decoders and circuit identity; RB-P1-12 governs nonce lifecycle. None substitutes for this algebraic
  protocol definition.
- **Project-native fix:** Specify one canonical S2C `Commit`, `Sign`, `Verify`, and `Open` algorithm
  over secp256k1/BIP-340, including domain-separated hash inputs, byte order, `int(hash) mod n`, zero
  handling, point lifting, even-Y normalization and the corresponding scalar negation, canonical
  `R'`/`R`/`s` encodings, and fail-closed errors. Use exactly that relation in the wallet signer,
  compliance circuit, receiver opening, publisher admission, NISSHAC member handling, and scanner.
- **Acceptance criteria:** Regression tests prove that no retired `C_batch` or public-record
  substitution path remains. Cross-language golden and negative vectors cover pre- and post-tweak
  parity combinations, `t = 0`, invalid and non-canonical points/scalars, altered `R'`, altered
  `ProofData`, opening failure, member reordering, and each signer-to-circuit-to-receiver wire boundary.
  Payload versions `0x01`/`0x02` and every legacy batch-proof object remain rejected.

### RB-P1-03 — `C_batch` padding, base case, and shape were under-constrained

- **Status:** `SUPERSEDED BY V3`
- **Current sections:** [§2.2](/specification#22-proof-types),
  [§2.5](/specification#25-circuit-dimensioning-normative),
  [§3.3](/specification#33-half-aggregation), [§3.5](/specification#35-inscription-format)
- **Finding:** The reviewed recursive batch circuit had no complete `m = 0` base case, padding
  semantics, or canonical shape and could yield divergent circuit identities.
- **Current disposition:** V3 removes the publisher circuit. The remaining half-aggregate has an
  explicit count and byte grammar, while strict count bounds and standardness tests remain part of
  RB-P0-05 and RB-P0-08.
- **Required closure evidence:** No production code, API, vector, or compatibility path may accept
  the retired batch-proof format. Boundary tests cover half-aggregate counts 1, maximum, maximum+1,
  zero, malformed counts, duplicate members, repeated keys, and split transactions before expensive
  work or storage allocation.

### RB-P1-04 — Multi-device account forks lack a complete reconciliation flow

- **Status:** `PARTIAL`
- **Current sections:** [§2.4](/specification#24-soundness-summary),
  [§4.2](/specification#42-bundle-delivery),
  [§6.3](/specification#63-node-portability-and-multi-node-operation)
- **Finding:** V3 first occurrence chooses one successor for a consumed `Pk`, but the specification
  does not fully define durable reservations, losing-branch change recovery, concurrent send/receive,
  retries, or the user-visible reconciliation of two devices.
- **Project-native fix:** Add a formal account operation state machine around V3 first occurrence.
  Reserve transition counters, keys, intents, and S2C nonces durably before signing; synchronize
  pending reservations through the node; classify losing branches; and recover every still-owned
  output without merging proof lineages by host convention.
- **Acceptance criteria:** Model and E2E tests cover two devices, parallel sends and receives,
  duplicate submission, delayed delivery, crash, restore, and reorg. Exactly one successor is
  canonical and every losing branch has a deterministic, value-preserving terminal status.

### RB-P1-05 — Public bundle discovery and retention made state unrecoverable

- **Status:** `SUPERSEDED BY V3`
- **Current sections:** [§3.6](/specification#36-chain-scanning),
  [§4.6](/specification#46-data-availability--replication-factor-k)
- **Finding:** The reviewed global `bundle_locator`, public historical enumeration, and archive
  retention scheme could prevent a new node from reconstructing consensus state.
- **Current disposition:** V3 deletes the public `BatchBundle` and reconstructs the public accumulator
  from Bitcoin. Private `CoinProof` discovery and loss remain custody/recovery concerns under
  RB-P0-04, not a reason to recreate a public archive consensus layer.
- **Required closure evidence:** Regression tests show that public state reconstruction never reads a
  locator, relay, Blossom object, or private bundle. Destructive private recovery remains gated by
  RB-P0-04.

### RB-P1-06 — Commit/reveal fee management and recovery are not operationally complete

- **Status:** `PARTIAL`
- **Current sections:** [§3.5](/specification#35-inscription-format),
  [§3.8](/specification#38-fees-and-economics)
- **Finding:** Consensus validity does not guarantee relay or confirmation. The current text lacks a
  byte-exact publisher-controlled funding topology, pre-inclusion state machine, RBF/CPFP strategy,
  package policy, eviction recovery, fee ceiling, safe abandonment, and high-fee emergency behavior.
- **Project-native fix:** Couple the transaction graph from RB-P0-05 to a publisher-owned fee state
  machine with signed budgets, replaceability, CPFP anchors where needed, rebroadcast, expiry,
  cancellation, and recovery. Never depend on confirmation inside a short unbudgeted window.
- **Acceptance criteria:** Supported Bitcoin Core versions relay and confirm the package under RBF,
  CPFP, eviction, restart, competing spends, full mempools, miner delay, and extreme fee rates within
  published cost/latency ceilings or reach a safe, non-value-consuming abort.

### RB-P1-07 — Expensive public work lacks early resource admission

- **Status:** `PARTIAL`
- **Current sections:** [§2.5](/specification#25-circuit-dimensioning-normative),
  [§7.4](/specification#74-blossom-blob-store-normative),
  [§7.5](/specification#75-node-rest-api-normative),
  [§7.6](/specification#76-publisher-interface-normative)
- **Finding:** Proving jobs, parsers, discovery, uploads, persistent queues, and cryptographic
  validation do not have complete authentication, byte/depth/count, concurrency, queue, tenant,
  expiry, and cost limits before expensive work begins.
- **Project-native fix:** Define finite budgets at every external boundary. Authenticate or require an
  explicit scarce admission token before witness construction or proving; bind job capabilities to
  principal, intent, channel, network, and expiry; isolate scanner/recovery capacity; and fail closed
  without evicting custody-critical state.
- **Acceptance criteria:** Calibrated 24-hour adversarial tests at at least ten times the declared
  peak keep CPU, memory, disk, queue depth, and scanner/recovery lag within published bounds while
  rejecting malformed, abandoned, replayed, and cross-principal jobs.

### RB-P1-08 — ZBE, KDF, RNG, and key lifecycle rules are incomplete

- **Status:** `PARTIAL`
- **Current sections:** [§1.1](/specification#11-cryptographic-primitives),
  [§1.2](/specification#12-key-hierarchy),
  [§1.3](/specification#13-per-coin-keys-note-encryption--detection),
  [§4.2.1](/specification#421-bundle-blob-encryption-zbe-normative)
- **Finding:** ZBE defines chunk framing, but a re-encrypted or updated object can reuse a key/counter
  nonce pair; KDF parameter mapping, entropy requirements, key rotation, compromise response, and
  atomic nonce/version allocation are not complete across all object types and retries.
- **Project-native fix:** Make encrypted blobs immutable per key or derive a fresh per-version key
  from a persisted random object salt. Pin BIP-39/BIP-32/Passkey derivation and RFC 5869 inputs for
  every KDF; reconcile `send_counter` with the hardened BIP-32 child-index range; define approved
  entropy and DRBG behavior across process forks and VM snapshots; and specify domain separation,
  nonce allocation, versioning, rotation, erasure, compromise, constant-time, panic, FFI, and WASM
  rules. Persist version/nonce allocation before emitting ciphertext.
- **Acceptance criteria:** Stateful property tests across retries, crashes, concurrent devices,
  delayed delivery, mutation, and restore observe no repeated `(key, nonce)` pair. Independent crypto
  review accepts the exact construction and derivation vectors; side-channel tests cover secret
  branches; malformed chunks, points, and FFI inputs fail closed within resource bounds and do not
  enter logs, panic reports, or crash dumps.

### RB-P1-09 — Privacy claims lack a complete observer and collusion model

- **Status:** `PARTIAL`
- **Current sections:** [Introduction](/), [Requirement 2](/requirements#2-private),
  [§3.5](/specification#35-inscription-format),
  [§4.7](/specification#47-metadata-and-privacy-tradeoffs),
  [§6.6](/specification#66-threat-model-and-trust-configurations)
- **Finding:** ZK witness hiding does not remove transaction count, timing, co-output proof equality,
  fee-publisher knowledge, stable addresses and handles, node plaintext, relay/store access patterns,
  IP data, browser state, logs, support exports, or collusion. Current prominent privacy claims are
  broader than the analyzed leakage.
- **Project-native fix:** Define privacy goals per observer and collusion set. Publish a field-level
  data-flow and linkability matrix for chain, node, publisher, recipient, relay, store, resolver,
  browser, telemetry, support, and legal disclosure. State V3's accepted public transaction-count
  leakage and narrow claims to measured properties.
- **Acceptance criteria:** Trace-based tests with one and multiple colluding actors quantify
  linkability for common and rare amounts/timing, multi-recipient sends, self-publish, node switching,
  recovery, and disclosure. Logs, traces, dumps, analytics, and support artefacts contain no forbidden
  fields.

### RB-P1-10 — Handle first contact is TOFU

- **Status:** `OPEN`
- **Current section:** [§4.3](/specification#43-addressing-for-delivery)
- **Finding:** A compromised resolver can return its own correctly signed address on first use. The
  wallet then pins a cryptographically valid attacker identity, and later proof checks cannot recover
  the user's intended human recipient.
- **Project-native fix:** Keep handles optional and human-facing, but classify first resolution as
  unverified until a signed address document is bound through an independently obtained trust root or
  confirmation channel. Bind network, handle, address keys, endpoints, sequence, validity, rotation,
  and revocation. Block real-value payment when independent authentication is absent.
- **Acceptance criteria:** Resolver, TLS, DNS, cache, rollback, split-view, stale, rotation,
  revocation, and cross-network attacks cannot make a verified contact accept an attacker address.
  The UI never equates a resolver's self-consistent signature with verified human identity.

### RB-P1-11 — Product problem, MVP, and falsifiable success criteria are absent

- **Status:** `OPEN`
- **Current sections:** [Scope](/specification#scope),
  [The ten requirements](/specification#the-ten-requirements)
- **Finding:** The documents mix research goals, protocol properties, implementation plans, and user
  outcomes without a narrow target user, urgent problem, non-goals, measurable MVP, competitive
  baseline, capital assumptions, or stop criteria.
- **Project-native fix:** Add a non-normative product brief that names the initial issuer-defined
  asset use case, target operator and user, why ZK is necessary, explicit non-goals including native
  BTC, competitive alternatives, defensibility, staffing and capital assumptions, measurable
  usability/cost/privacy/recovery targets, and research stop/continue triggers. Keep product demand
  separate from cryptographic truth.
- **Acceptance criteria:** A bounded research milestone can fail objectively. No roadmap or funding
  gate assumes an inactive Bitcoin change, unproved privacy/soundness property, unspecified bridge,
  or production readiness.

### RB-P1-12 — S2C nonce derivation and retry persistence remain ambiguous

- **Status:** `PARTIAL`
- **Current sections:** [§1.7.10](/specification#1710-half-aggregation-with-commitments-nisshac-normative),
  [§3.2](/specification#32-transition-signing-bip-340--sign-to-contract),
  [§7.5](/specification#75-node-rest-api-normative)
- **Finding:** Fresh nonce language prevents reuse in an ideal implementation, but the base nonce is
  not explicitly commitment-bound and retry, crash, auxiliary-randomness, restore, and concurrent
  signing rules do not exclude every repeated `k'` with a different tweak. Such reuse can expose the
  spend key.
- **Project-native fix:** Pin one BIP-340-compatible transcript that binds the exact network, consumed
  key, `H(ProofData)`, intent commitment, retry identity, and fresh auxiliary randomness, or define an
  equivalent crash-atomic nonce reservation protocol. Never regenerate a different tweak under an
  already reserved base nonce.
- **Acceptance criteria:** Cross-implementation signing vectors and stateful tests cover retry,
  cancellation, crash at every boundary, device concurrency, restore, fork, null auxiliary input,
  and mutated commitment. Instrumentation proves zero base-nonce reuse; an implementation audit
  confirms secrets never enter logs or crash dumps.

### RB-P1-13 — Operations, reconciliation, restore, and incident response are underspecified

- **Status:** `PARTIAL`
- **Current sections:** [§4.8](/specification#48-durability--the-store-everything-invariant),
  [§6.1](/specification#61-components-and-responsibilities),
  [§7.5](/specification#75-node-rest-api-normative),
  [§7.8](/specification#78-kernel-rpc--the-internal-interface-normative)
- **Finding:** Component descriptions do not define SLOs, durable queue semantics, secret inventory,
  per-block reconciliation, backup/restore objectives, schema/circuit rollback, incident ownership,
  privacy-safe observability, or disaster runbooks.
- **Project-native fix:** Publish an executable operations contract: service and secret inventory,
  least privilege, idempotent queues, SLOs/SLIs, per-block chain/state reconciliation, encrypted
  backup and tested restore, migration/rollback rules, alerts independent of the primary system, and
  security/availability/privacy incident runbooks.
- **Acceptance criteria:** An unannounced recovery exercise on empty infrastructure restores canonical
  state and completes a real follow-up transition. Drills cover a compromised secret, corrupt
  database, lost region, stale node, bad circuit release, deep reorg, and privacy incident without
  relying on undocumented operator knowledge.

### RB-P1-14 — Legal, operator, privacy, and issuer perimeter is undefined

- **Status:** `CONDITIONAL`
- **Current sections:** [§6.1](/specification#61-components-and-responsibilities),
  [§6.5](/specification#65-issuance--versioned-schemas-v1-minimal),
  [§6.6](/specification#66-threat-model-and-trust-configurations)
- **Finding:** A protocol label does not determine custody, money-transmission, payments, AML/CFT,
  sanctions, data-protection, consumer, asset-issuer, licensing, patent, or export obligations. The
  concrete operator entities, jurisdictions, controlled keys/data, intervention rights, retention,
  and user redress are not specified.
- **Project-native fix:** Require each deployment to publish an actor and data matrix for wallet,
  node, prover, publisher, relay, store, resolver, explorer, bridge if any, and issuer. Add asset terms,
  privacy roles, retention, disclosure authority, user risks/costs/redress, license notices, SBOM,
  vulnerability contact, and external qualified legal review for the actual jurisdictions.
- **Acceptance criteria:** Every operated role has a named entity, jurisdiction, data set, keys,
  censorship/disclosure capability, policy owner, and counsel-reviewed classification. Public claims,
  contracts, technical controls, and incident procedures agree.

### RB-P1-15 — Prospective protocol activation and user choice are incomplete

- **Status:** `OPEN`
- **Current sections:** [§1.7.8](/specification#178-reference-instantiation-review-status),
  [§6.5](/specification#65-issuance--versioned-schemas-v1-minimal),
  [Implementation Mandate](/implementation-mandate)
- **Finding:** Version fields and a greenfield reset avoid a fictional V1 migration, but no rule yet
  defines release identity, activation authority, user rejection, incompatible forks, soundness
  compromise, rollback, emergency power, or maintainer succession after real-value genesis.
- **Project-native fix:** Before genesis, choose a prospective model: immutable lineages with explicit
  opt-in forks, or a separately reviewed bridge between versions. Sign a content-addressed release
  manifest binding specification, circuits, verifier data, schemas, networks, activation, support,
  and advisories. Define emergency scope and user consequence without silently changing old-state
  verification.
- **Acceptance criteria:** Cross-version tests cover opt-in, refusal, downgrade, replay, rollback,
  split support, compromised old verifier, maintainer disappearance, and recovery. No current V1
  prototype state is treated as production state that must be migrated.

### RB-P1-16 — Serial-root publisher ordering enabled asymmetric stale-work attacks

- **Status:** `SUPERSEDED BY V3`
- **Current sections:** [§3.4](/specification#34-the-publisher),
  [§3.6](/specification#36-chain-scanning),
  [§3.8](/specification#38-fees-and-economics)
- **Finding:** The reviewed global `prev_root` let an earlier competing publisher make an otherwise
  valid expensive batch stale and externalize proving, data, and BTC costs.
- **Current disposition:** V3 has no shared root or publisher proof. Each state key is independent,
  first occurrence selects only same-key conflicts, and redundant publication is idempotent.
- **Required closure evidence:** Adversarial multi-publisher tests confirm that unrelated V3
  nullifiers never invalidate one another and that same-key races have bounded, disclosed retry and
  fee behavior. Economic work remains for censorship and Bitcoin fee funding, not the retired serial
  writer.

### RB-P1-17 — Release-bound conformance and negative evidence are missing

- **Status:** `PARTIAL`
- **Current sections:** [Test vectors](/specification#test-vectors-conformance-harness),
  [Implementation Mandate](/implementation-mandate)
- **Finding:** `<REGEN>` constants, incomplete negative vectors, prototype tests, and unarchived build
  evidence do not prove the current specification revision. Happy-path compatibility cannot detect
  parser, constraint, nonce, reorg, or recovery regressions.
- **Project-native fix:** Create a release-bound requirements-to-test matrix. Generate and pin every
  vector from the frozen artefact; add malformed and negative proofs, constraint-mutation sensitivity,
  parser differential tests, reorgs, private-data loss, recovery, fault injection, cross-version and
  cross-network tests, and reproducible benchmark logs.
- **Acceptance criteria:** Every normative MUST/MUST NOT maps to at least one executable positive or
  negative test. Third parties can reproduce the release manifest, vectors, results, and benchmark
  environment from a clean checkout; external audits cite the exact digest.

## P2 findings

| ID | Status | Consolidated finding | Project-native fix and closure evidence |
|---|---|---|---|
| RB-P2-01 | `PARTIAL` | Supported Bitcoin Core versions, RPC/index requirements, archival/pruned profiles, network separation, snapshots, pagination, offline sync, and reorg recovery are incomplete. | Publish a node dependency matrix and deterministic sync/recovery algorithm for Regtest, Signet, testnet, and mainnet. Test every supported Core/profile combination, pruned failure mode, offline interval, snapshot boundary, and reorg depth. |
| RB-P2-02 | `PARTIAL` | REST, gRPC, Nostr, and Blossom are detailed but do not yet form complete interoperable schemas for unknown fields, canonical JSON/binary, all errors, retries, idempotency, pagination, authentication, version negotiation, and SSE resume. Member build tips are not cryptographically bound to the claimed `block_anchor`; `BalanceAttestation` and grant `record_time` edge semantics are also incomplete. | Check in machine-readable schemas and generated conformance cases. Cryptographically bind a member build tip or remove the unverifiable claim; fully specify attestation verifier/wire data and canonical grant-time boundaries. Two clients must produce byte-identical hashes and identical state/error decisions for duplicate, late, unknown, malformed, paginated, retried, and resumed messages. |
| RB-P2-03 | `PARTIAL` | Kernel/API separation reduces blast radius but does not fully define the trusted computing base, process isolation, permissions, failure domains, or architecture decisions. | Publish component ownership, least-privilege permissions, data/secret access, crash boundaries, and ADRs. Verify process compromise and dependency failure cannot cross the documented boundary; do not treat isolation as a replacement for intent or protocol fixes. |
| RB-P2-04 | `OPEN` | Exact maximum-circuit proving time, verification time, proof size, memory, p95/p99/worst case, queue behavior, hardware cost, and growth are not reproducibly benchmarked. | Benchmark the frozen maximum circuit on named CPU/GPU hardware with commands, datasets, versions, p50/p95/p99/worst case, memory, proof size, throughput, and cost. Include adversarial witnesses and sustained queues; toy circuits cannot close the gate. |
| RB-P2-05 | `PARTIAL` | Build provenance and reproducibility remain incomplete after a canonical circuit is chosen. | Pin source, toolchain, dependencies, features, environment, and deterministic build instructions; publish hashes, signed release manifests, provenance, and an SBOM. Independent clean builds must reproduce all security-critical artefacts or explain and bound every nondeterministic byte. |
| RB-P2-06 | `CONDITIONAL` | A full history-DAG knowledge extractor was requested without first showing that the intended funds-safety theorem requires that exact property. | State the concrete theorem and adversary first, then require the weakest sufficient extraction/composition evidence. Close only when cryptographic reviewers agree that the selected theorem covers funds safety without ritual or omitted assumptions. |
| RB-P2-07 | `OPEN` | Anonymity, proving, queue, private DA, database, blockspace, fee volatility, support, and operator costs are not measured as one capacity/economic model; verifier, archive, Path service, and private-availability roles lack a sustainable incentive analysis. | Publish a sensitivity and actor-payoff model over transaction rate, aggregate size, private-object retention, BTC price, fee rate, proof hardware, replication, verification/archive service, support load, and failure spikes. Reproduce predicted cost, capacity, and honest-role viability at each release gate. |
| RB-P2-08 | `PARTIAL` | Accessibility, state/finality communication, backup, passkey trade-offs, node switching, disclosure, recovery, and safe failure UX are not normative or tested. | Define a user state model and required copy/actions for irreversible operations, pending/final/reorg states, backup health, device loss, node failure, disclosure, phishing, and accessibility. Run adversarial usability and recovery tests with measurable pass criteria. |
| RB-P2-09 | `CONDITIONAL` | License compatibility, notices, patents, export/distribution constraints, and support obligations are not reviewable without a release package. | Before distributing a release, produce the exact SBOM, license/notice matrix, source-offer obligations, patent review, export/distribution assessment, and support/EOL policy. Automated release checks must reject unapproved dependencies or missing notices. |
| RB-P2-10 | `CONDITIONAL` | General governance, decision records, maintainer rights, security disclosure, bus factor, and succession remain incomplete beyond the protocol-activation issue in RB-P1-15. | Before a shared network release, publish maintainers and permissions, change process, ADR/RFC history, private vulnerability reporting, release signing, conflict handling, emergency authority, succession, and fork rights. Exercise a maintainer-loss and disclosure drill. |

## P3 findings

| ID | Status | Consolidated finding | Project-native fix and closure evidence |
|---|---|---|---|
| RB-P3-01 | `OPEN` | Bitcoin, settlement, custody, bearer data, full node, finality, trustless, self-custodial, token, and privacy terminology is inconsistent across technical and user-facing pages. | Create one claim glossary with allowed and forbidden formulations, map each term to enforcement and residual trust, then run terminology checks across every page and product string. |
| RB-P3-02 | `OPEN` | Introductions and summaries lead with absolute guarantees while evidence limits and irreversible risks appear later. | Put research status, asset scope, own-node trust, private-data backup, finality, and evidence limits before architecture and performance claims. Validate comprehension with non-expert users. |
| RB-P3-03 | `OPEN` | `<REGEN>` values and incomplete examples prevent tutorials and third-party conformance from being executable. | Generate values only from the frozen reference artefact, pin generation commands and hashes, and make every tutorial run from a clean checkout. Never invent placeholder digests. |
| RB-P3-04 | `PARTIAL` | Publisher fee/quote expiry, treasury exposure, retry budget, and user presentation are not fully bound even though a generic forced quote-replay exploit was rejected. | Sign fee asset, amount, network, publisher identity, expiry, Bitcoin-fee ceiling, and retry budget; show them before intent signing. Test stale, replayed, cross-network, and changed quotes, while preserving voluntary user acceptance. |
| RB-P3-05 | `PARTIAL` | Smaller naming, formatting, schema, SDK ergonomics, and developer examples remain inconsistent after security-critical wire issues, including protocol-V1 versus V3-payload terminology. | Normalize protocol, network, circuit, and payload version names after schemas freeze; generate SDK types/examples from those schemas; and require copy-paste integration examples plus compatibility tests. Do not spend this work before higher-severity semantics stabilize. |

## Raw review coverage

The table below preserves the first-round finding counts by review lens. Counts are historical and do
not claim that the current target still contains every original defect; the disposition above is
authoritative for the current target.

| Lens | Perspective | P0 | P1 | P2 | P3 | Raw findings |
|---:|---|---:|---:|---:|---:|---:|
| 01 | Bitcoin end user | 5 | 4 | 4 | 2 | 15 |
| 02 | Advanced user and node operator | 4 | 5 | 2 | 1 | 12 |
| 03 | Wallet, custody, and key management | 3 | 7 | 3 | 1 | 14 |
| 04 | External developer and SDK integrator | 6 | 11 | 5 | 1 | 23 |
| 05 | Product management | 3 | 5 | 3 | 0 | 11 |
| 06 | UX and human factors | 5 | 6 | 2 | 0 | 13 |
| 07 | Strategy and capital allocation | 3 | 5 | 7 | 1 | 16 |
| 08 | CTO and system architecture | 5 | 6 | 4 | 0 | 15 |
| 09 | Bitcoin consensus | 3 | 5 | 3 | 0 | 11 |
| 10 | Bitcoin Script, Taproot, and transactions | 5 | 2 | 2 | 0 | 9 |
| 11 | Mempool, relay, miner policy, and fees | 1 | 3 | 3 | 0 | 7 |
| 12 | Zero-knowledge cryptography | 3 | 8 | 0 | 0 | 11 |
| 13 | Proof system, circuit, and compiler | 2 | 8 | 4 | 0 | 14 |
| 14 | Cryptographic implementation and side channels | 3 | 6 | 4 | 0 | 13 |
| 15 | Formal methods and specification | 3 | 6 | 4 | 0 | 13 |
| 16 | Distributed systems and data availability | 2 | 5 | 4 | 0 | 11 |
| 17 | Bridge, peg, custody, and withdrawals | 4 | 3 | 1 | 0 | 8 |
| 18 | Adversarial security and red team | 2 | 6 | 0 | 0 | 8 |
| 19 | Privacy and metadata leakage | 0 | 7 | 2 | 0 | 9 |
| 20 | Economic security and mechanism design | 2 | 2 | 4 | 0 | 8 |
| 21 | Performance and proving infrastructure | 1 | 4 | 6 | 0 | 11 |
| 22 | Backend, SRE, operations, and incident response | 4 | 4 | 3 | 0 | 11 |
| 23 | QA, fuzzing, testing, and reproducibility | 2 | 5 | 1 | 0 | 8 |
| 24 | Legal, regulatory, privacy, and licensing | 1 | 5 | 3 | 0 | 9 |
| 25 | Open source, governance, ecosystem, and adoption | 0 | 5 | 5 | 0 | 10 |
| **Total** |  | **72** | **133** | **79** | **6** | **290** |

The post-challenge register consolidates those 290 records into the 42 baseline findings above.
V3-P0-01 and V3-P1-01 are additional and have no baseline raw IDs. Severity is
based on the strongest reproducible impact, not a vote. A security veto can be removed only by new
evidence, a normative specification change where required, and a focused re-review.

### Primary raw-ID traceability

The following one-to-one primary assignment accounts for all 290 raw IDs exactly once. A raw finding
can support more than one consolidated workstream; the primary assignment prevents double counting.
RB-P2-06, RB-P3-03, and RB-P3-05 are residual aspects split out during the challenge round, so they
do not own an additional exclusive raw ID.

#### P0 raw IDs

```text
RB-P0-01 (15):
R02-002 R04-001 R07-03 R08-002 R09-001 R10-06 ZK12-01 R15-F01
R16-01 R16-11 R17-04 R18-02 R21-P0-01 R22-01 R23-01

RB-P0-02 (6):
R01-002 R03-001 UX-06-02 R08-001 R15-F02 R18-01

RB-P0-03 (18):
R01-001 R02-005 R03-003 R05-P0-01 UX-06-01 UX-06-11 R07-01 R08-004
R10-01 R11-01 ZK12-02 R15-F12 R17-01 R17-02 R17-05 R19-P1-07
R20-ECO-001 R24-04

RB-P0-04 (14):
R01-003 R01-004 R02-003 R03-002 R05-P0-02 UX-06-03 R07-02 R08-005
ZK12-03 R15-F03 R16-09 R17-03 R20-ECO-002 R22-03

RB-P0-05 (7):
R04-005 R09-002 R09-005 R09-009 R10-02 R10-03 R10-09

RB-P0-06 (5):
R02-001 R05-P0-03 R08-003 R09-003 R09-007

RB-P0-07 (9):
R02-004 R02-009 UX-06-06 R08-008 R09-004 R10-07 R16-03 R17-06 R22-04

RB-P0-08 (8):
R04-004 ZK12-09 ZK12-10 R13-06 R14-01 R14-08 R15-F09 R23-02

RB-P0-09 (1):
R13-02

RB-P0-10 (2):
R15-F11 R22-02
```

#### P1 raw IDs

```text
RB-P1-01 (8):
R04-015 ZK12-04 ZK12-05 ZK12-11 R13-09 R13-10 R13-14 R15-F04

RB-P1-02 (17):
R03-005 R04-002 R04-003 R08-006 R09-006 R10-04 R10-05 ZK12-07 ZK12-08
R13-03 R13-08 R14-03 R14-05 R15-F06 R17-07 R18-03 R23-04

RB-P1-03 (10):
R04-006 R13-04 R13-05 R13-11 R13-12 R13-13 R14-06 R20-ECO-003
R21-P2-08 R23-03

RB-P1-04 (6):
R01-008 R03-010 R04-013 R15-F05 R15-F08 R16-07

RB-P1-05 (8):
R02-008 R02-011 R04-012 R04-017 R08-007 R16-02 R16-05 R16-08

RB-P1-06 (6):
R03-004 R10-08 R11-02 R11-03 R11-05 R11-06

RB-P1-07 (10):
R04-011 R04-014 R14-07 R18-05 R18-06 R20-ECO-005 R21-P1-03
R21-P1-04 R21-P1-05 R22-07

RB-P1-08 (9):
R03-006 R03-007 R03-008 R03-009 R04-008 R14-04 R14-09 R14-10 R14-11

RB-P1-09 (14):
R01-007 R05-P2-02 UX-06-08 R07-07 R07-13 ZK12-06 R19-P1-01 R19-P1-02
R19-P1-03 R19-P1-04 R19-P1-05 R19-P1-06 R19-P2-09 R23-06

RB-P1-10 (3):
R01-005 UX-06-05 R18-07

RB-P1-11 (8):
R05-P1-01 R05-P1-02 R05-P1-03 R05-P2-01 R05-P2-03 R07-09 R07-15 R07-16

RB-P1-12 (1):
R14-02

RB-P1-13 (7):
UX-06-07 R16-06 R19-P2-08 R22-06 R22-08 R22-09 R22-10

RB-P1-14 (7):
R07-11 R24-01 R24-02 R24-03 R24-05 R24-06 R24-07

RB-P1-15 (9):
R04-016 R08-009 R13-01 R15-F07 R18-08 R22-05 R25-02 R25-03 R25-04

RB-P1-16 (4):
R07-04 R08-012 R11-04 R20-ECO-004

RB-P1-17 (7):
R03-012 R04-022 R07-05 R08-011 R14-13 R15-F13 R23-07
```

#### P2 raw IDs

```text
RB-P2-01 (10):
R02-006 R02-007 R02-010 UX-06-13 R08-015 R09-008 R09-010 R16-04
R25-05 R25-07

RB-P2-02 (15):
R03-011 R03-013 R04-007 R04-009 R04-010 R04-018 R04-019 R04-020
R04-021 R09-011 R15-F10 R16-10 R18-04 R23-05 R25-06

RB-P2-03 (2):
R08-013 R22-11

RB-P2-04 (7):
R01-013 R04-023 R08-014 R17-08 R21-P2-06 R21-P2-07 R21-P2-09

RB-P2-05 (5):
R07-12 R08-010 R13-07 R14-12 R23-08

RB-P2-06 (challenge-derived residual):
Primary source aspects remain assigned under ZK12-04 and ZK12-11 in RB-P1-01.

RB-P2-07 (7):
R05-P1-05 R07-10 R11-07 R20-ECO-007 R20-ECO-008 R21-P2-10 R21-P2-11

RB-P2-08 (11):
R01-006 R01-009 R01-011 R01-012 R05-P1-04 UX-06-04 UX-06-09
UX-06-10 UX-06-12 R07-06 R21-P1-02

RB-P2-09 (2):
R24-08 R24-09

RB-P2-10 (4):
R25-01 R25-08 R25-09 R25-10
```

#### P3 raw IDs

```text
RB-P3-01 (3):
R01-014 R02-012 R03-014

RB-P3-02 (2):
R01-015 R07-14

RB-P3-03 (challenge-derived residual):
Primary source aspects remain assigned under R01-013, R04-022, ZK12-10, and R13-06.

RB-P3-04 (3):
R01-010 R07-08 R20-ECO-006

RB-P3-05 (challenge-derived residual):
Primary source aspects remain assigned under R03-013, R04-020, and R04-021.
```

### Material challenge-round decisions

The table preserves every challenge conflict that changed or materially narrowed a consolidated
disposition. It records the baseline decision; the finding entries above separately state whether V3
supersedes or retains the underlying requirement.

| Conflict | Orchestrator decision | Evidence required to revisit it |
|---|---|---|
| DA state split | P0 confirmed for the reviewed design, precisely as forward-sticky divergence on one unchanged canonical chain. A hypothetical reorg was not a recovery protocol. V3's chain-only first-occurrence rule supersedes that mechanism under RB-P0-01. | Model every DA, restart and reorg ordering; require byte-identical convergence from independent scanner harnesses. |
| Locator versus recovery | Discovery ambiguity alone was P1; permanent loss of custody-critical proof/state data plus a false seed-only promise was P0. Public locator consensus is retired in V3, while private recovery remains RB-P0-04. | Clean-room cold sync and destructive private-state restore after losing locator indexes and replicas. |
| S2C base nonce | Algebra and conflicting retry/auxiliary rules remain P1 because a conforming fresh-uniform-nonce implementation did not itself demonstrate reuse. Any conforming key-recovery trace escalates immediately to P0. | Frozen transcript and encodings, atomic nonce reservation, and crash/parallel/restore differential tests on release artefacts. |
| Formal ZK security | Missing composition evidence is a P1 release and claim gate, not evidence that the Plonky2 primitive is already broken. A separate full-history extractor demand is P2 unless funds safety is shown to require it. | Exact recursive Fiat–Shamir/FRI/ZK analysis, well-founded relation, and workload-bounded composition theorem. |
| Proof system versus circuit | Circuit binding defects remain P1 even with a sound backend: the backend proves only the relation actually constrained. | Constraint-coverage matrix, mutation test for every binding, and authenticated common/verifier data. |
| Test vectors versus circuit identity | Missing authoritative circuit/verifier identity in the required boot model was P0; ordinary known-answer coverage was P1; build provenance after a frozen artefact was P2. | Two clean-room builds, concrete digests and verifier data, cross-verification, and fail-closed drift tests. |
| Script and mempool feasibility | No intrinsic impossibility or universal third-party-pinning proof was established. Missing transaction templates, bumping, eviction, abort and recovery remain P1. | Byte-exact transactions exercised against Bitcoin Core policy under RBF, CPFP, eviction, restart and safe abort. |
| Fee economics | Miner/publisher ordering censorship and bounded-loss-versus-liveness remain P1. Forced old-quote replay was rejected; voluntary treasury/pricing exposure remains P3. | Authenticated quote/expiry/budget plus measured competing-publisher and miner runs through success or safe abort. |
| Performance versus security | Finite resource contracts for public jobs and discovery remain P1; unmeasured circuit performance alone remains P2. Caps do not close job hijacking or protocol P0s. | Calibrated adversarial load tests with caps and pool isolation, plus release-artefact maximum-size benchmarks. |
| Privacy versus operations | Both requirements survive: cross-boundary observability/backup correlation is P1, while durable custody and outbox journals are required for funds safety. Safety journals and ordinary telemetry must be separated. | Fault injection and clean-room restore plus two-user linkability testing across logs, traces, dumps, support and backups. |
| Governance versus upgrade technique | Concrete activation, state compatibility, user opt-in/opt-out and verifier-compromise handling are P1. General social governance is conditional P2 without implicit auto-upgrade; no fixed threshold is cryptographically mandatory. | Controversial version-upgrade drill covering rejection, dual support or reviewed migration, rollback and compromised old verifier. |
| Product/marketing versus technical/legal | P0 confirmed for the reviewed BTC/trust claims. Honest custom-asset, research-only positioning can close the claim defect but cannot create BTC enforcement or replace deployment-specific legal review. | Claim-to-evidence matrix over every surface, enforced no-real-value gates, and operator/jurisdiction review. |
| CEO schedule versus security | Schedule and option value cannot reduce a P0. Only a value-free, resettable research instrument with stop gates may continue while P0s remain. | Reproduce or close each P0 under a fixed research budget, then repeat the board gate before roadmap expansion. |
| Architecture isolation versus protocol binding | Ports, containers and responsibility matrices are P2 hardening, not remedies for authorization, deterministic admission or circuit-migration defects. | Malicious-node E2E, state-model checks and real version-lineage migration; deployment isolation alone is insufficient. |

## Remediation order

The work is dependency-ordered. Parallel work is appropriate inside a stage, but a later stage does
not compensate for an earlier unresolved safety property.

1. **Truth and scope:** close RB-P0-03, RB-P0-04, RB-P0-06, RB-P1-09, RB-P1-11, and RB-P3-01/02 so
   every reader sees the actual asset, enforcement, node-trust, recovery, privacy, and research model.
2. **Authorization and recoverable state:** close V3-P0-01, RB-P0-02, RB-P0-07, RB-P0-09,
   RB-P0-10, RB-P1-04, RB-P1-08, RB-P1-10, and RB-P1-12 before a value-changing implementation or
   handle-resolved payment is treated as complete. Until RB-P1-10 closes, value-changing handle
   resolution remains disabled; authenticated direct addresses may be used only under the other
   applicable gates.
3. **Bitcoin and proof determinism:** close RB-P0-05, RB-P0-08, RB-P1-01, RB-P1-02, RB-P1-06,
   and RB-P1-17; then freeze and generate the release artefacts.
4. **Bounded operation:** close V3-P1-01, RB-P1-07, RB-P1-13, and the performance, capacity,
   dependency, and UX work in RB-P2 before a shared environment accepts users. Resolver failure may
   block a new dial, but never an established authenticated channel.
5. **External assurance and launch perimeter:** complete independent cryptographic and Bitcoin
   Script reviews, operational drills, governance, legal review, and public claim verification before
   any mainnet consideration.

## Release gates

Every gate is cumulative and includes every requirement in the preceding rows. `No open` always
means neither `OPEN` nor `PARTIAL` at the named severities; a `CONDITIONAL` item must also close when
its stated deployment or claim condition is met.

| Gate | Minimum result from this register |
|---|---|
| Further research | Allowed only with no real value, explicit research status, and unproved claims labelled as such. Open findings remain visible. |
| Implementation work | One coherent V3 relation and state machine; project-native resolutions selected for every P0/P1 design gap; a transport state machine that keeps established authenticated channels DNS-independent and makes new-dial failure durable and fail-closed; no implementation may silently choose missing semantics. |
| Regtest prototype | No `OPEN` or `PARTIAL` P0, isolated environment, no real value, and every trust assumption documented; generated circuit identity and negative proof vectors; destructive recovery; real mock-free node/SDK/app flow against Bitcoin Core Regtest. The enabled transport set passes the V3-P1-01 resolver-blackout test with new sockets denied, zero DNS-induced active-channel closures, zero active-path resolver calls, and zero false success states. Every `SUPERSEDED BY V3` entry's stated rejection/regression evidence passes so retired formats cannot return unnoticed. |
| Signet/testnet | Regtest gate plus a formal ZK relation and pinned statement/witness, negative proof suite, defined state recovery and deposit/withdrawal flow where applicable, reorg and realistic fee/resource tests, monitoring and restore, documented admin/upgrade rights, privacy-observability tests, and a production-topology DNS-continuity soak spanning every declared TTL, heartbeat, credential refresh, proxy idle policy, and `dns_continuity_window`. No real-value representation. |
| Limited mainnet | Signet/testnet gate plus no `OPEN` or `PARTIAL` P0 or P1; independent cryptography/circuit and Bitcoin Script/transaction audits; recovery audit; bridge and withdrawal audit plus tested emergency exit wherever BTC is bound; realistic fee- and mempool-stress tests; reproducible maximum-size benchmarks; bounded funds at risk; public security-disclosure process; legal review of the actual deployment. |
| Production | Limited-mainnet gate plus formal funds-safety and exit-liveness invariants, long-term private-data strategy, reproducible release artefacts and complete vectors, exercised incident/governance model, two independent implementations or the documented independent-assurance alternative, and public claims matched to measured evidence. |

## Current decision

**RESEARCH ONLY — NOT REGTEST-PROTOTYPE-READY, NOT SIGNET/TESTNET-READY, AND NOT MAINNET-READY.**

The V3 cutover supersedes the original public-data admission split and three related baseline
mechanisms. It bounds finality at 6 confirmations (a reorg of ≥6 blocks is an accepted break, with
no conditional-NAV no-op relation), and its current text contradicts itself on mandatory receive publication. It does not close complete
wallet intent authorization, private bearer recovery, byte-exact Bitcoin transaction construction,
S2C algebra, circuit identity/decoding, successor-key validity, crash atomicity, formal cryptographic
composition, resolver-independent established-session liveness, or the operational and launch
perimeter. No average score can override those remaining P0 findings; V3-P1-01 is an additional
project-mandated blocker for any network gate that requires its DNS-continuity evidence.
