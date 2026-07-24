---
title: Mail Bridge
---

# Mail Bridge

:::info Optional operator role
The SMTP/email bridge is an **optional operator service**, **off by default**, and independent of both the optional Lightning bridge and mandatory NIP-17 messaging. It moves messages, never zkCoins value.
:::

## One identifier, two independent message transports

Every zkCoins user has a mandatory NIP-05 identifier such as `alice@example.com` ([spec §4.3](/specification#43-addressing-for-delivery)). That identifier always names the user's standard Nostr account and remains usable for NIP-17 messaging whether or not an email bridge exists.

An operator may additionally make the same identifier a working SMTP email address:

- **NIP-17:** mandatory core messaging using kind 14, NIP-44 v2, kind 13, kind 1059, and kind 10050 ([spec §7.3](/specification#73-nostr-event-kinds-normative)).
- **SMTP:** optional plaintext email handled by the bridge.

SMTP is not a fallback protocol inside NIP-17. Enabling or disabling the email bridge **MUST NOT** change the Nostr identity, event formats, relay selection, or interoperability of native messaging.

## Discovery and outbound behavior

For a recipient entered as `bob@example.com`, the sender follows the standard §4.3 flow:

1. If Bob's `nprofile` is already retained, use its stored public key and relay hints directly without DNS or NIP-05.
2. Otherwise resolve `https://example.com/.well-known/nostr.json?name=bob`, verify the matching kind-0 profile, and retain the resulting contact.
3. If Bob has a valid kind-10050 event, send through standard NIP-17 to exactly those DM relays.
4. If Bob is not ready for NIP-17, SMTP may be offered only when the sender's operator has enabled the email bridge and the user explicitly chooses email.

The absence of a `zkcoins` object does not affect NIP-17.

Before the first SMTP send to a recipient, the client **MUST** state that the message leaves as ordinary email. If the sender's operator offers no SMTP bridge, an SMTP send is unavailable; this does not make NIP-17 unavailable.

## Downgrade protection

Once a contact has successfully exchanged NIP-17 messages, a failure to fetch kind 10050 or reach its DM relays **MUST NOT** silently move the conversation to SMTP. A switch from NIP-17 to email requires an explicit warning and user confirmation.

NIP-17 and SMTP messages **MUST** remain separate conversations. Plain email content must never appear as if it were authenticated by the contact's Nostr key.

During a DNS outage, known NIP-17 contacts continue to work from retained `nprofile` and DM relays. SMTP delivery may fail because ordinary email infrastructure depends on DNS; that is acceptable and does not trigger a Nostr downgrade.

## Inbound email

An enabled bridge accepts SMTP for its own advertised addresses, applies ordinary inbound protections such as SPF, DKIM, DMARC, spam filtering, and rate limits, and delivers mail to the user's email inbox. These checks authenticate infrastructure and sending domains, not the human author.

The UI **MUST** label every inbound message by transport:

- NIP-17 content is authenticated to the sender's Nostr public key.
- SMTP content is email and does not gain Nostr authentication merely because its `From` address resembles a NIP-05 identifier.

## Payment safety

Email content is display-and-reply only with respect to money. A client **MUST NOT** make a zkCoins or Lightning payment action directly executable from an email body, auto-link payment URI schemes, or pre-fill a payment form from email content. HTML email **MUST** be sanitized before rendering.

These restrictions do not apply to authenticated application UI outside the email message itself; they prevent unauthenticated SMTP content from impersonating a trusted Nostr conversation or payment instruction.

## Privacy and trust

On the SMTP path, the bridge necessarily processes message plaintext, headers, sender, recipient, timing, and volume. On the NIP-17 path, content is readable by the component holding the account's `op` key: the user's own node in a sovereign setup, or the hosting provider for a hosted account ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). External relays see the recipient `p` tag plus timing and volume, but not the sealed content or sender identity.

The bridge holds no SPEND key and cannot move funds. Failure of SMTP delivery, mailbox storage, or the bridge itself can lose or delay email only; mandatory NIP-17 messaging and native zkCoins remain separate.
