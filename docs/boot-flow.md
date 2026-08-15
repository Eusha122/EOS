# EOS Privet boot flow

Last updated: 2026-08-15

## Goal

Before the graphical desktop starts, EOS Privet should show a simple full-screen text interface with a hacker-style feel.

The user should not need Linux knowledge. They should only need to read two choices and type a number.

## Current implementation status

The text gate and option `1` are implemented and have reached Plasma in the VM. Option `2` currently shows a safe, explicit “saved storage is not configured” message and returns to the gate. It does **not** unlock or create encrypted storage yet. The flows below describe the final persistence target and must not be presented as already delivered.

## Main flow

On boot, show a quiet full-screen terminal interface. The first test ISO proved the gate appears before KDE and option `1` reaches KDE. The oversized ASCII wordmark has already been replaced by a compact fixed-width EOS Privet status box that fits the VM console.

Current compact style:

```text
  +================================================================+
  |                         E O S   P R I V E T                    |
  |                    USB LIVE PRIVACY SESSION                   |
  +================================================================+
  |  STATUS    FRESH MODE READY                                    |
  |  BUILD     <build-version>                                     |
  +----------------------------------------------------------------+
  |  [1]  EXPLORE FRESH                                            |
  |       Starts a temporary desktop. Nothing personal is unlocked.|
  |  [2]  UNLOCK SAVED STORAGE                                     |
  |       Encrypted USB storage. Not configured in this test build.|
  +================================================================+
  choose> _
```

If the user types `1`:

- start a fresh live session
- do not mount encrypted saved storage
- continue to the graphical desktop
- target discarding normal session changes on shutdown; this claim remains pending until the documented reboot and mount checks pass
- allow the EOS factory desktop transaction because the Fresh overlay is temporary

If the user types `2`:

- ask for the storage profile or username
- ask for the unlock secret
- if correct, mount encrypted USB storage
- continue to the graphical desktop with saved files and settings available
- never use a desktop schema-version change alone as permission to erase the saved user's panel customization

The current Phase 2d build does not implement option `2`, but this reset boundary is already enforced: automatic factory layout application is allowed only when `/run/eos-privet/session-mode` says `fresh`. A future saved-storage provisioning flow must request its first factory layout explicitly and then preserve the separate one-time factory marker.

## First-time setup flow

If encrypted storage does not exist yet, show:

```text
EOS PRIVET
-----------
1. Explore fresh
2. Set up saved storage

Choose: _
```

Then:

1. Ask for a profile name.
2. Ask for a passphrase.
3. Create encrypted storage on the same USB drive.
4. Save approved user folders into that encrypted area.
5. Reboot or continue into the graphical desktop.

## Security note

The user asked for a username plus PIN feel. The visual flow can support that style, but the first secure implementation should prefer a full passphrase rather than a short numeric PIN.

Safer first-release model:

- prompt for profile name
- prompt for passphrase

Possible later convenience mode:

- prompt for profile name
- prompt for PIN
- use the PIN only if it unlocks a stronger stored secret through an additional protection layer

## What should persist

When saved storage is unlocked, these are good first targets:

- `Documents`
- `Downloads`
- `Pictures`
- `Void` browser profile data
- Wi-Fi credentials
- selected user settings

## What should not happen

- The desktop must not start before the choice screen.
- Kernel or system service logs should not cover the choice screen in normal boot.
- Saved storage must not auto-unlock by default.
- Fresh mode must not silently write personal data to the internal PC disk.
- The system must not pretend that a fresh session equals perfect anonymity.

## Implementation direction

Best early implementation path:

1. Boot into a text console service before the display manager starts.
2. Run a small EOS Privet menu program on that console.
3. If `1`, continue with a normal live graphical login.
4. If `2`, unlock the encrypted USB partition using Linux disk encryption, mount it, and bind the allowed folders into the live user environment.
5. Start the display manager only after the choice is complete.

This keeps the experience simple for the user and matches the product identity.
