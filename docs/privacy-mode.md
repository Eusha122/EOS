# EOS Privet privacy mode

Last updated: 2026-08-14

## Goal

EOS Privet should support a privacy-focused operating mode inspired by Tails:

- start from a clean live session by default
- minimise local traces after shutdown
- offer optional encrypted persistent storage on the USB drive
- route privacy-mode browsing through Tor-first tooling

The goal is to reduce operator mistakes and local data leakage while still feeling practical for daily use. The goal is not to promise perfect anonymity.

## Guardrails

EOS Privet privacy mode must not:

- claim that any OS can make dark-web activity "safe"
- claim to defeat all surveillance or all forensic recovery
- frame unauthorised access as a supported use case
- reuse a normal Chromium-branded browser as the sole anonymity story

## First implementation target

For the first privacy-capable EOS Privet milestone, prefer:

1. Live boot with amnesic defaults.
2. Optional encrypted persistent storage using standard Linux disk encryption.
3. A Tor-native browsing path for privacy mode.
4. A pre-desktop text gate where the user chooses a fresh session or unlocks saved storage.
5. A first-run flow that keeps everyday tasks understandable for non-expert users.
6. Saved files should follow the USB, so the user can boot the same drive on another PC and still access their encrypted data.

## Threat-model notes

- Local traces can be reduced, not universally eliminated.
- Tor improves network privacy, but does not hide all facts from all observers.
- Malicious firmware, compromised hardware, unsafe downloads, and user login correlation can still break anonymity.
- Privacy mode should separate identities and tasks rather than encouraging one always-on browser profile.
