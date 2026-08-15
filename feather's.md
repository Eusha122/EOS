# EOS Privet feature catalogue

Last updated: 2026-08-15

Status legend: `planned` · `scaffolded` · `in progress` · `verified`

| Feature | Status | Notes |
| --- | --- | --- |
| Bootable hybrid ISO | in progress | Debian 13 (`trixie`) UEFI boot and Fresh mode are proven through Phase 2c. Phase 2d adds strict desktop/theme/package validation and needs one clean rebuild plus VM boot before verification. |
| USB-live-first workflow | planned | The core product should boot and run cleanly from USB without depending on installation. |
| Text-mode boot gate | in progress | The Phase 2c gate-to-Fresh path passed. Phase 2d now derives the live identity from one manifest and fixes the fail-safe entry; regression testing both menu choices is pending. |
| UEFI + legacy boot | planned | Validate both against the chosen live-build release. |
| Lightweight Plasma desktop | in progress | Phase 2d selects a real EOS Plasma 6 Global Theme before first login, packages Cicada IV correctly, creates EOS top and dock panels, applies the layout through Plasma's native loader when repair is needed, restores essential runtime packages, and rejects missing desktop components. VM verification is pending. |
| Smooth macOS-like experience | in progress | The first original EOS baseline now uses a dark Breeze engine, slim top bar, centered native Plasma dock, Inter/Hack typography, dark icons, and Cicada IV. Animation/effect tuning and lower-end hardware tests remain. |
| Daily-use plug-and-use UX | in progress | Fresh session is configured to open a plain-language EOS guide after desktop verification and offer a direct Void launch; Phase 2d VM verification is pending. |
| Void browser | scaffolded | `void-browser` starts Debian's Tor Browser Launcher; first launch needs network and remains unverified until ISO testing. |
| Tails-style privacy mode | planned | Live session should start clean, leave minimal local trace, and expose privacy limits clearly. |
| Encrypted persistent storage | planned | Optional persistence should use standard Linux disk encryption on the same USB drive and require explicit unlock. |
| Tor-first browsing path | scaffolded | Void wraps Debian's Tor Browser Launcher instead of a re-skinned Chromium path; network launch and update behaviour remain unverified. |
| Default tool selection | in progress | Debian recommendation expansion is disabled so language packs, GIMP, LibreOffice, Calamares, and other unselected extras do not inflate the base image; authorised security tools remain an optional later profile. |
| Future EOS desktop app | scaffolded | Isolated package boundary and placeholder launcher exist. |
| Internal-disk installer | planned | Secondary feature after the USB-live product is solid. |
| Signed update channel | planned | Requires project keys, hosting, and release policy. |
| Automated build validation | in progress | Phase 2d adds static, package, KPackage, wallpaper-byte, launcher, desktop-entry, identity, ownership, forbidden-package, and completed-ISO SquashFS/boot gates. A clean Debian build must still pass them. |
| Automated graphical ISO testing | planned | Add repeatable VM boot, screenshot, reboot, and interaction tests; Phase 2d currently uses a documented manual VM acceptance test. |
| Phased implementation roadmap | verified | `docs/implementation-plan.md` tracks delivery phases with test-based completion checkboxes. |

## Performance acceptance goals

- Responsive desktop on integrated graphics that supports the selected Plasma session.
- Animations never block input; offer a reduced-effects preset.
- No always-running heavyweight service without a user-visible purpose.
- Privacy mode must default to ephemeral state unless the user explicitly unlocks persistence.
- Everyday tasks like Wi-Fi, browsing, files, and shutdown must work without specialist knowledge.
- Files saved by the user should remain on the encrypted USB storage and show up again when the same USB is used on another PC.
- Unlocking should happen before the graphical session so users clearly choose between a fresh or saved environment.

## Safety boundary

EOS Privet must not market itself as a guarantee of anonymity, and must not present dark-web access as inherently safe.
