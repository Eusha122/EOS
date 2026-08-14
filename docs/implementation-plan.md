# EOS Privet implementation plan

Last updated: 2026-08-15  
Status legend: `[ ]` not started · `[-]` in progress · `[x]` verified done

## Reasoning and security posture

EOS Privet is a USB-live operating system, not a new kernel. Building on Debian stable lets the project inherit a mature kernel, hardware support, package updates, and security maintenance. The project work is then about making the safest practical defaults easy to use.

There is no such thing as an unhackable operating system or guaranteed full anonymity. A secure EOS Privet release must make fewer mistakes likely, protect saved data if a USB is lost, keep fresh sessions temporary, and clearly show the user where its protections stop.

The design separates two needs that should never be silently mixed:

| Need | EOS Privet behaviour |
| --- | --- |
| Explore fresh | Do not unlock saved storage; session changes disappear on shutdown. |
| Use saved files and settings | Unlock the encrypted storage on the EOS USB with a strong passphrase. |
| Private browsing | Void uses a Tor-native browser path; users are warned that logins, unsafe downloads, and compromised hardware can still identify them. |
| Everyday use | Wi-Fi, files, updates, and basic apps stay understandable, with clear privacy labels instead of hidden “magic.” |

Security principles for every phase:

1. Use proven components: Debian packages, LUKS2 encryption, Tor Browser technology, and standard Linux security controls.
2. Keep the default session amnesic: never automatically unlock or write personal data to an internal computer disk.
3. Minimise trust: separate the ISO build environment, sign releases, verify downloads, and document every privileged boot action.
4. Fail safely: if encrypted storage cannot be unlocked, do not start a partly-persistent desktop; offer fresh mode instead.
5. Test claims: a feature is not marked done until it works in a VM and on a USB test device.

## High-level roadmap

### Phase 0 — Product and threat-model foundation

- [x] Confirm product identity: EOS Privet, USB-live first, daily-use friendly, privacy focused.
- [x] Choose an `amd64` Debian-stable direction and KDE Plasma desktop.
- [x] Specify the Fresh / Unlock saved storage boot screen.
- [x] Define the safety boundary: no “unhackable” or “fully anonymous” claims.
- [ ] Write release versioning, licence, supported-PC policy, and privacy warning copy.

**Done when:** the project has a clear first-release scope and no security promise that cannot be tested.

### Phase 1 — Repeatable ISO foundation

- [ ] Set up a clean Linux build VM.
- [-] Convert the current transitional Kali-compatible build configuration to Debian stable `live-build` (source converted to Debian 13; build verification remains).
- [ ] Produce a bootable UEFI ISO, then test legacy BIOS support where feasible.
- [ ] Record exact build commands and package versions.
- [ ] Add an ISO checksum and verification instructions.

**Done when:** the same source creates a bootable test ISO twice, and both builds can be checked with a checksum.

### Phase 2 — Fresh live session

- [ ] Configure the live user, KDE Plasma session, networking, sound, file manager, and power controls.
- [ ] Ensure normal session data is temporary and does not use the host computer's internal disk.
- [ ] Add safe shutdown and “fresh session” explanations in the welcome screen.
- [ ] Test graphics, Wi-Fi, keyboard, touchpad, and shutdown in VirtualBox.

**Done when:** selecting Fresh starts a usable desktop and its test files disappear after restart.

### Phase 3 — Boot gate and encrypted saved storage

- [-] Add the full-screen text boot gate before the graphical desktop starts (source added; ISO test remains).
- [-] Implement option `1`: **Explore fresh** (source added; ISO test remains).
- [ ] Implement option `2`: **Unlock saved storage** with profile name and a strong passphrase.
- [ ] Build a careful first-time setup flow that creates a dedicated LUKS2-encrypted data area on the EOS USB.
- [ ] Mount only approved saved folders after successful unlock: Documents, Downloads, Pictures, selected KDE settings, and Void profile data.
- [ ] Refuse automatic unlocking; recover safely into Fresh mode if unlock fails.
- [ ] Test the same USB data area from two different VMs or PCs.

**Done when:** a file saved after unlock is available after reboot on the same USB, but never appears in a Fresh session.

### Phase 4 — Void and privacy networking

- [-] Rename the transitional browser package and launcher to **Void** (new Void package boundary added; old shortcut remains for compatibility).
- [-] Integrate a Tor-native browser path based on supported upstream technology (Debian Tor Browser Launcher configured; ISO test remains).
- [ ] Add a visible connection state and simple explanation of what Tor does and does not protect.
- [ ] Block or clearly label applications that would bypass the selected privacy path; never silently claim all traffic is anonymous.
- [ ] Add download warnings, update verification, and separate-browser-profile guidance.

**Done when:** Void opens through the intended Tor path, connection failure is visible, and normal applications cannot be mistaken for anonymous ones.

### Phase 5 — Daily-use desktop and EOS visual system

- [ ] Create an original EOS Privet Plasma theme using the supplied logo.
- [ ] Configure a smooth, restrained macOS-inspired top bar, dock, icons, login screen, and wallpaper.
- [ ] Provide a reduced-effects option for older PCs.
- [ ] Add welcome, Wi-Fi, file-saving, and privacy help screens in plain language.
- [ ] Keep the future `eos-desktop-app` isolated behind its existing package boundary.

**Done when:** a new user can boot, join Wi-Fi, browse, save an encrypted file, and shut down without needing terminal knowledge after the boot menu.

### Phase 6 — Hardening, updates, and recovery

- [ ] Enable and review standard Linux hardening: timely security updates, AppArmor profiles where available, least-privilege services, and a minimal enabled-service set.
- [ ] Add verified update and release signing policy; protect release keys offline.
- [ ] Decide Secure Boot support and document its trust model.
- [ ] Add recovery guidance for forgotten passphrases: encrypted data cannot be recovered without the passphrase.
- [ ] Run vulnerability and configuration reviews before each release candidate.

**Done when:** updates, release verification, recovery limits, and security support policy are documented and tested.

### Phase 7 — Release testing and USB delivery

- [ ] Create repeatable VirtualBox tests for Fresh mode, saved mode, reboot, Void, and failed unlock attempts.
- [ ] Test creation of a real USB drive using a spare device only.
- [ ] Test booting on a small range of UEFI PCs and record hardware issues.
- [ ] Publish installation, verification, privacy, and bug-reporting guides.
- [ ] Mark EOS Privet `0.1.0` as released only after the checks above pass.

**Done when:** the ISO, checksum, release notes, USB instructions, and test record are all published together.

## First build target

The first technical target is intentionally small: a Debian-based EOS Privet ISO that boots in VirtualBox into the Phase 3 text menu. Option `1` must reliably enter a temporary Plasma desktop. Option `2` may initially show a clearly labelled “saved storage not configured” screen until real encrypted USB setup is implemented and tested.

This avoids pretending that persistence is secure before the disk-encryption flow exists.
