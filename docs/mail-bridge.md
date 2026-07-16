---
title: Mail Bridge
---

# Mail Bridge

:::info Optional operator role
The mail bridge is an **optional operator role of the API layer**, **off by default**, and **never part of the trustless core**. It layers on top of the node's core surface at the kernel/API seam ([spec §6.1](/specification#61-components-and-responsibilities)); a node **MUST** advertise it so a client treats an unadvertised bridge as absent and fails closed. It is **entirely application-layer** and **touches no zkCoins value state** — it moves messages, never coins.
:::

## Two rails, one address

The mail bridge makes a handle `alice@<domain>` ([spec §4.3](/specification#43-addressing-for-delivery)) **also a working email address**. It carries messages on two rails behind that one address:

- **Native rail (end-to-end-encrypted).** Messaging over the **same Nostr transport and `op` identity the protocol already uses** ([spec §7.3](/specification#73-nostr-event-kinds-normative)): NIP-17 private direct messages — kind 14 rumors, NIP-44 v2 encryption, NIP-59 gift wrap — addressed to the recipient's `op` key. The message is end-to-end encrypted to the recipient and the operator forwards only the gift-wrapped event.
- **Fallback rail (ordinary email).** Plain SMTP email, for any recipient that has no native handle.

The **full messaging semantics** of the native rail — threading, read state, attachments, delivery receipts, and the rest — are **application-defined and out of scope here**. This page specifies only what the bridge itself owes: **discovery**, **downgrade protection**, **labeling**, and the **SMTP edge**.

## Discovery and gating

Whether an operator runs the mail bridge is part of its advertised role set ([spec §6.4](/specification#64-external-interfaces-abstract), *Core surface vs optional roles*): the SMTP edge is a **separately-gated endpoint** on top of the core surface, not part of it. Optional roles gate **fail-closed** ([spec §6.1](/specification#61-components-and-responsibilities)), so a client that sees no advertised mail bridge treats it as absent rather than assuming SMTP interop it was never offered. The **native rail needs no such advertisement** — it is ordinary handle resolution plus NIP-17 messaging — so a recipient with a handle is reachable natively whether or not any operator fronts an email edge for them; the bridge only adds the SMTP interoperability on top.

## Outbound and discovery

To message `bob@example.com`, the client resolves the handle exactly as for a payment: an HTTPS `GET` to `https://example.com/.well-known/zkcoins/bob` ([spec §4.3](/specification#43-addressing-for-delivery)).

- If the handle **resolves and verifies**, the message goes **end-to-end** to the resolved `op_pubkey` over the resolved `relays`. Nothing extra is fetched — the §4.3 response already carries `op_pubkey` and `relays`, everything the native rail needs.
- Otherwise the operator sends **ordinary SMTP mail** to `bob@example.com`.

Before the **first** unencrypted send to a recipient, the client **MUST** indicate that the message **leaves as plain email** — the sender always knows, before committing, which rail carries their words.

Discovery is entirely a property of the **recipient's** handle: a message is native when `bob@example.com` resolves to a verified handle, regardless of which operator fronts the sender's own address. The sending user therefore reaches native recipients over the encrypted rail and everyone else over SMTP, without configuring anything per-recipient beyond the pin the client records on first contact (below).

## Downgrade protection

The mail bridge mirrors the **handle pinning** rule of the addressing layer ([spec §4.3](/specification#43-addressing-for-delivery), *Handle pinning*) applied to messaging capability:

- Once a recipient has resolved as **native**, the client **MUST** pin that capability (trust-on-first-use) and **MUST NOT** silently fall back to SMTP for that recipient.
- A downgrade to the email rail for a previously-native contact happens **only on explicit user confirmation after a warning** — never silently.

A blocked, tampered, or failing resolution therefore **warns the user** instead of quietly dropping to plaintext mail. An attacker who can suppress a recipient's native resolution cannot use that to force a silent downgrade; the worst it achieves is a visible warning.

## Inbound

The operator accepts **SMTP for its own handles**, enforces **SPF, DKIM, and DMARC** on incoming mail, and delivers each message into the user's inbox **tagged by rail** so the recipient sees which rail it arrived on.

Sender identity on the email rail is **unauthenticated beyond domain-level checks**. SPF/DKIM/DMARC attest the sending **domain**, not the person: an email that passes them proves only that the message left an authorised server for that domain, never who wrote it or that its `From` name is genuine. The native rail, by contrast, is authenticated to the sender's `op` key — a native message is provably from the holder of that key, an email is not. This difference is real and the UI **MUST NOT** hide it (below).

## UI labeling rules

These rules are **normative for clients and security-critical** — they are what keeps the authenticated native rail from being spoofed by the unauthenticated email rail:

- **(a) Separate the rails.** Email-rail and native-rail content **MUST** be **visually and structurally separated**. An unencrypted email **MUST NOT** render inside the same thread context as the end-to-end messages of the same contact — the two rails never share a conversation view.
- **(b) No money from email.** Payment requests and payment-triggering actions **MUST NOT** be actionable from email-rail content. With respect to money the email rail is **display-and-reply only**: an email may show a payment ask as inert text, but no button, link, or gesture in email-rail content may initiate a zkCoins or [Lightning-bridge](/lightning-bridge) payment.
- **(c) Rail always visible.** The rail of **every** message is **always visible** — the user can never be in doubt whether a given message came over the encrypted native rail or over plain email.

## Privacy

The disclosure the operator gets differs sharply between the rails, and clients **MUST** present it honestly:

- On the **email rail**, the operator **necessarily processes full plaintext**. This is inherent to SMTP — the operator is the mail server and cannot forward a message it cannot read. Subject, body, and headers are all in its view.
- On the **native rail**, the operator forwards only **gift-wrapped events** ([spec §7.3](/specification#73-nostr-event-kinds-normative)) and sees none of the content.

Choosing the email rail for a recipient is therefore choosing to expose that message's plaintext to the operator; choosing the native rail is not. The state that these two disclosures are different — not merely that email is "less private" — belongs in front of the user.

## Operations

Spam filtering, outbound deliverability (reputation, retries, bounce handling), and mailbox storage are **ordinary email operations** run by the operator. They are the mundane obligations of running any mail service and sit **outside protocol scope** — the protocol defines the rails, the discovery, and the labeling; how well the operator keeps its mail flowing is its own operational concern.

None of these operations reach zkCoins value. The mail bridge moves messages and stores mailboxes; it holds no keys that can spend, and a failure of any of them loses or delays **mail**, never funds. That is the sense in which the bridge is application-layer through and through: the worst an operator outage or a lost mailbox can do is impair messaging reachability, which is exactly the bound the specification already places on losing an aliasing operator.
