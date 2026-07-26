---
title: Mail Bridge
---

# Mail Bridge

:::info Optional operator service
The SMTP/email bridge is an **API-layer feature**, **off by default**, and independent of both the Lightning bridge and mandatory NIP-17 messaging. An operator enables it as `mail_bridge` in the closed `features` set of [spec §6.1](/specification#61-components-and-responsibilities). It moves messages, never zkCoins value.
:::

## One identifier, two independent message transports

Every zkCoins user carries a NIP-05 name such as `alice@example.com` ([spec §4.3](/specification#43-addressing-for-delivery)). That name always resolves to the user's standard Nostr account and remains usable for NIP-17 messaging whether or not an email bridge exists.

An operator may additionally make the same identifier a working SMTP email address:

- **NIP-17:** mandatory core messaging using kind 14, NIP-44 v2, kind 13, kind 1059, and kind 10050 ([spec §7.3](/specification#73-nostr-event-kinds-normative)).
- **SMTP:** optional plaintext email handled by the bridge.

SMTP is not a fallback protocol inside NIP-17. Enabling or disabling the email bridge **MUST NOT** change the Nostr identity, event formats, relay selection, or interoperability of native messaging.

## Discovery and outbound behavior

For a recipient entered as `bob@example.com`, the sender follows the standard §4.3 flow:

1. If Bob's `nprofile` is already retained, use its stored public key, relay hints, and IP endpoints retained after original-hostname-authenticated TLS plus a successful relay WebSocket upgrade directly without DNS or NIP-05; preserve each original relay scheme, hostname, port, path, SNI, certificate check, and WebSocket `Host`.
2. Otherwise resolve `https://example.com/.well-known/nostr.json?name=bob`, verify the matching kind-0 profile, and retain the resulting contact. Search the union of any NIP-05 relay hints and the configured standard profile/discovery relays (including bootstrap seeds) with ordinary NIP-01 author-and-kind filters.
3. If Bob has a valid kind-10050 event, send through standard NIP-17 to exactly those DM relays.
4. If Bob is not ready for NIP-17, SMTP may be offered only when the sender's operator has enabled the email bridge and the user explicitly chooses email.

A client learns whether its own operator runs the bridge from `mail_bridge` in the `features` array of `GET /v1/info` ([spec §6.1](/specification#61-components-and-responsibilities)). Absent from that array, the bridge is absent and an SMTP send is unavailable.

The absence of a `zkcoins` object does not affect NIP-17.

Before the first SMTP send to a recipient, the client **MUST** state that the message leaves as ordinary email. If the sender's operator offers no SMTP bridge, an SMTP send is unavailable; this does not make NIP-17 unavailable.

## Downgrade protection

Once a contact has successfully exchanged NIP-17 messages, a failure to fetch kind 10050 or reach its DM relays **MUST NOT** silently move the conversation to SMTP. A switch from NIP-17 to email requires an explicit warning and user confirmation.

NIP-17 and SMTP messages **MUST** remain separate conversations. Plain email content must never appear as if it were authenticated by the contact's Nostr key.

During a DNS outage, a known NIP-17 contact continues to work after a cold start only when at least one previously reached, retained relay IP endpoint still serves its original path. The client connects to that IP while preserving the original relay scheme, hostname, port, and path for TLS SNI, certificate verification, WebSocket `Host`, and the relay upgrade; it never retains an endpoint after TLS alone, disables TLS verification, or accepts an IP-address certificate instead. Relay failure or signed rotation solely to previously unknown hostnames is unavailable until DNS returns. SMTP delivery may also fail because ordinary email infrastructure depends on DNS; that is acceptable and does not trigger a Nostr downgrade.

## Inbound email

An enabled bridge accepts SMTP for its own advertised addresses, applies ordinary inbound protections such as SPF, DKIM, DMARC, spam filtering, and rate limits, and delivers mail to the user's email inbox. These checks authenticate infrastructure and sending domains, not the human author.

The UI **MUST** label every message by transport, **inbound and outbound alike**, and that label **MUST** persist in conversation history rather than appearing only at send time — an outbound-only SMTP thread is otherwise indistinguishable in history from an authenticated NIP-17 one:

- NIP-17 content is authenticated to the sender's Nostr public key.
- SMTP content is email and does not gain Nostr authentication merely because its `From` address resembles a NIP-05 identifier.

## Payment safety

Email content is display-and-reply only with respect to money. A client **MUST NOT** make a zkCoins or Lightning payment action directly executable from an email body, auto-link payment URI schemes, or pre-fill a payment form from email content. HTML email **MUST** be sanitized before rendering.

These restrictions do not apply to authenticated application UI outside the email message itself; they prevent unauthenticated SMTP content from impersonating a trusted Nostr conversation or payment instruction.

## Privacy and trust

On the SMTP path, the bridge necessarily processes message plaintext, headers, sender, recipient, timing, and volume. On the NIP-17 path, content is readable by the component holding the account's `op` key: the user's own node in a sovereign setup, or the hosting provider for a hosted account ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). The sender's identity does not appear in the public gift-wrap event, and its content remains encrypted. A relay or its operator can nevertheless learn or correlate the sender through NIP-42 AUTH, source IP and connection metadata, or the relay's own authentication and admission rules; it also sees the recipient `p` tag, timing, and volume.

The bridge holds no SPEND key and cannot move funds. Failure of SMTP delivery, mailbox storage, or the bridge itself can lose or delay email only; mandatory NIP-17 messaging and native zkCoins remain separate.
