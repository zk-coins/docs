---
title: Mail Bridge
---

# Mail Bridge

:::info Optional operator role
The mail bridge is an **optional operator role of the API layer**, **off by default**, and **never part of the trustless core**. It layers on top of the node's core surface at the kernel/API seam ([spec §6.1](/specification#61-components-and-responsibilities)); a node **MUST** advertise it so a client treats an unadvertised bridge as absent and fails closed. It is **entirely application-layer** and **touches no zkCoins value state** — it moves messages, never coins.
:::

## Two rails, one address

The mail bridge makes a handle `alice@<domain>` ([spec §4.3](/specification#43-addressing-for-delivery)) **also a working email address**. It carries messages on two rails behind that one address:

- **Native rail (encrypted to the `op` key).** Messaging over the **same Nostr transport and `op` identity the protocol already uses** ([spec §7.3](/specification#73-nostr-event-kinds-normative)): NIP-17 private direct messages — kind 14 rumors, NIP-44 v2 encryption, NIP-59 gift wrap — addressed to the recipient's `op` key. The message is encrypted **to the holder of the recipient's `op` key**: in a sovereign deployment that is the user's own node, so the encryption is end-to-end to the user; for a **hosted** account the hosting provider holds the operational bundle — `op` included ([spec §6.1](/specification#61-components-and-responsibilities)) — and **can read native-rail content**. Which of the two applies is the recipient's wallet–node trust configuration ([spec §6.6](/specification#66-threat-model-and-trust-configurations)), not a property of the rail. The mail-bridge operator itself forwards only the gift-wrapped event. A handle is a native-rail recipient only when its profile advertises **messaging capability** — bare payment resolvability never selects this rail (*Discovery and gating* below).
- **Fallback rail (ordinary email).** Plain SMTP email, for any recipient that has no native handle.

The **full messaging semantics** of the native rail — threading, read state, attachments, delivery receipts, and the rest — are **application-defined and out of scope here**. This page specifies only what the bridge itself owes: **discovery**, **downgrade protection**, **labeling**, and the **SMTP edge**.

## Discovery and gating

Whether an operator runs the mail bridge is part of its advertised role set ([spec §6.4](/specification#64-external-interfaces-abstract), *Core surface vs optional roles*): the SMTP edge is a **separately-gated endpoint** on top of the core surface, not part of it. Optional roles gate **fail-closed** ([spec §6.1](/specification#61-components-and-responsibilities)), so a client that sees no advertised mail bridge treats it as absent rather than assuming SMTP interop it was never offered. The **native rail is gated recipient-side**, and not by bare resolvability. Payment resolution ([spec §4.3](/specification#43-addressing-for-delivery)) attests payment addressing only: a node implementing only the core protocol never processes mail events — [spec §7.3](/specification#73-nostr-event-kinds-normative) defines no mail kind, and the core scan matches only the `zkdt`/`zkepk` coin tags — so a native message to a payment-only handle would sit unread on its relays, a silent total loss. This page therefore defines, **as an extension**, an optional **messaging-capability marker**: an extra field in the recipient's kind-30420 profile event content. The kind-30420 event is `op`-signed as a whole ([spec §7.3](/specification#73-nostr-event-kinds-normative)), so the marker is authenticated exactly like the rest of the profile; consumers that implement only the core protocol ignore unknown content fields ([spec §7.1](/specification#71-serialization-conventions-normative)), and §7.3 itself is unchanged by this page. A handle is a **native-rail recipient** exactly when its verified kind-30420 profile carries the marker; a handle that resolves without it is an email-rail recipient.

## Outbound and discovery

To message `bob@example.com`, the client resolves the handle exactly as for a payment: an HTTPS `GET` to `https://example.com/.well-known/zkcoins/bob` ([spec §4.3](/specification#43-addressing-for-delivery)).

- If the handle **resolves and verifies** and its kind-30420 profile carries the **messaging-capability marker** (*Discovery and gating* above), the message goes **encrypted to the resolved `op_pubkey`** over the resolved `relays` — end-to-end to the user whenever the user's own node holds `op` (*Two rails* above). The §4.3 response carries `op_pubkey` and `relays`; when it is the profile event itself, the marker is checked there, otherwise the client fetches the recipient's kind-30420 profile from the resolved relays ([spec §7.3](/specification#73-nostr-event-kinds-normative)) and checks it before selecting the rail.
- Otherwise the operator sends **ordinary SMTP mail** to `bob@example.com` — a handle that resolves for payments but carries no marker is an email-rail recipient. When the sender's operator runs no SMTP edge, the message is **undeliverable and the client says so**; a native send to a marker-less handle never happens silently.

Before the **first** unencrypted send to a recipient, the client **MUST** indicate that the message **leaves as plain email** — the sender always knows, before committing, which rail carries their words.

Discovery is entirely a property of the **recipient's** handle: a message is native when `bob@example.com` resolves to a verified profile carrying the messaging-capability marker, regardless of which operator fronts the sender's own address. The sending user therefore reaches native recipients over the encrypted rail and everyone else over SMTP, without configuring anything per-recipient beyond the pin the client records on first contact (below).

## Downgrade protection

The mail bridge mirrors the **handle pinning** rule of the addressing layer ([spec §4.3](/specification#43-addressing-for-delivery), *Handle pinning*) applied to messaging capability:

- Once a recipient's verified profile has carried the **messaging-capability marker**, the client **MUST** pin that capability (trust-on-first-use) and **MUST NOT** silently fall back to SMTP for that recipient. The pin records the marker-attested capability, not bare resolvability.
- A downgrade to the email rail for a previously-native contact — including a later resolution that verifies but **lacks the marker** — happens **only on explicit user confirmation after a warning**; never silently.

A blocked, tampered, or failing resolution — or a resolution whose marker has vanished — therefore **warns the user** instead of quietly dropping to plaintext mail. An attacker who can suppress a recipient's resolution, or serve a marker-less form of it, cannot force a silent downgrade; the worst it achieves is a visible warning.

## Inbound

The operator accepts **SMTP for its own handles**, enforces **SPF, DKIM, and DMARC** on incoming mail, and delivers each message into the user's inbox **tagged by rail** so the recipient sees which rail it arrived on.

Sender identity on the email rail is **unauthenticated beyond domain-level checks**. SPF/DKIM/DMARC attest the sending **domain**, not the person: an email that passes them proves only that the message left an authorised server for that domain, never who wrote it or that its `From` name is genuine. The native rail, by contrast, is authenticated to the sender's `op` key — a native message is provably from the holder of that key, an email is not. This difference is real and the UI **MUST NOT** hide it (below).

## UI labeling rules

These rules are **normative for clients and security-critical** — they are what keeps the authenticated native rail from being spoofed by the unauthenticated email rail:

- **(a) Separate the rails.** Email-rail and native-rail content **MUST** be **visually and structurally separated**. An unencrypted email **MUST NOT** render inside the same thread context as the native-rail messages of the same contact — the two rails never share a conversation view.
- **(b) No money from email.** Payment requests and payment-triggering actions **MUST NOT** be actionable from email-rail content. With respect to money the email rail is **display-and-reply only**: an email may show a payment ask as inert text, but no button, link, or gesture in email-rail content may initiate a zkCoins or [Lightning-bridge](/lightning-bridge) payment. "Initiate" here is broad: email-rail HTML **MUST** be sanitized before rendering (no active or script content); payment URI schemes (`lightning:`, `zkcoins:`, or app deep-links) in email-rail content **MUST NOT** be auto-linked or handed to a payment handler; and no amount, destination, or asset field of a payment UI may be **pre-filled** from email-body content. Acting on an email's payment ask always requires the user to re-enter it on the native rail.
- **(c) Rail always visible.** The rail of **every** message is **always visible** — the user can never be in doubt whether a given message came over the encrypted native rail or over plain email.

## Privacy

The disclosure the operator gets differs sharply between the rails, and clients **MUST** present it honestly:

- On the **email rail**, the operator **necessarily processes full plaintext**. This is inherent to SMTP — the operator is the mail server and cannot forward a message it cannot read. Subject, body, and headers are all in its view.
- On the **native rail**, the operator forwards only **gift-wrapped events** ([spec §7.3](/specification#73-nostr-event-kinds-normative)) and sees none of the content — **unless the same operator (or another) also hosts the account's operational bundle**, in which case it holds `op` and can read native-rail content. That disclosure is a property of the **hosting choice** ([spec §6.6](/specification#66-threat-model-and-trust-configurations)), not of the rail.

The native rail's **metadata** is also weaker than the payment path's, and the honest fix is disclosure: a standard NIP-17 gift wrap carries the recipient's `op_pubkey` as a cleartext `p` tag, so relays and the forwarding operator learn **which `op` key receives** each native message, plus its timing and volume. Coin delivery deliberately avoids exactly this — its outer events identify no recipient at all (the `zkdt`/`zkepk` scan tags, [spec §4.2](/specification#42-bundle-delivery), [§4.7](/specification#47-metadata-and-privacy-tradeoffs)). The native messaging rail does not inherit that property: content stays sealed, but the recipient identity and the traffic pattern do not.

Choosing the email rail for a recipient is therefore choosing to expose that message's plaintext to the mail operator; choosing the native rail exposes content only to whoever holds the recipient's `op` — the user's own node in the sovereign deployment, the hosting provider for a hosted account ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). The fact that these two disclosures are different — not merely that email is "less private" — belongs in front of the user.

## Operations

Spam filtering, outbound deliverability (reputation, retries, bounce handling), and mailbox storage are **ordinary email operations** run by the operator. They are the mundane obligations of running any mail service and sit **outside protocol scope** — the protocol defines the rails, the discovery, and the labeling; how well the operator keeps its mail flowing is its own operational concern.

None of these operations reach zkCoins value. The mail bridge moves messages and stores mailboxes; it holds no keys that can spend, and a failure of any of them loses or delays **mail**, never funds. That is the sense in which the bridge is application-layer through and through: the worst an operator outage or a lost mailbox can do is impair messaging reachability, which is exactly the bound the specification already places on losing an aliasing operator.
