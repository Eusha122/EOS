# EOS Privet structure

Last updated: 2026-08-15

```text
EOS/
|-- .gitattributes                 # LF rules for Linux build inputs
|-- assets/
|   |-- branding/                  # Canonical EOS and Void logo source
|   `-- wallpapers/                # Canonical default and alternate wallpapers
|-- apps/
|   |-- e-browser/                 # Legacy browser compatibility boundary
|   |-- void/                      # Active Void browser contract
|   `-- eos-desktop-app/           # Future website-to-desktop application
|-- build/
|   |-- live-build-config/
|   |   |-- hooks/
|   |   |   |-- normal/            # Debian 13 live-build compatibility hook
|   |   |   `-- live/              # Permissions, cleanup, and cache refresh
|   |   |-- includes.chroot/
|   |   |   |-- etc/
|   |   |   |   |-- sddm.conf.d/   # Manifest-injected Fresh autologin
|   |   |   |   |-- skel/          # New live-user KDE defaults
|   |   |   |   |-- systemd/       # Pre-desktop boot gate ordering
|   |   |   |   `-- xdg/           # Global theme, favorites, and autostart
|   |   |   `-- usr/
|   |   |       |-- lib/            # EOS os-release identity over the Debian base
|   |   |       |-- local/          # EOS boot/session programs
|   |   |       `-- share/
|   |   |           |-- applications/
|   |   |           |-- plasma/     # EOS Plasma 6 Global Theme and layout
|   |   |           `-- wallpapers/ # Valid EOS KDE wallpaper package
|   |   `-- package-lists/          # Explicit runtime and firmware packages
|   |-- manifests/                  # Version, base, identity, and profiles
|   |-- scripts/                    # Strict repeatable ISO build entry point
|   `-- tests/                      # Shipped-layout verifier regressions
|-- docs/
|   |-- boot-flow.md                # Fresh/unlock text-gate contract
|   |-- build-environment.md        # Debian builder and Phase 2d VM test workflow
|   |-- implementation-plan.md      # Phased roadmap and verified status
|   `-- privacy-mode.md              # Privacy intent and guardrails
|-- out/                            # Generated artifacts; never committed
|-- context.md                      # Product decisions and active findings
|-- feather's.md                    # Feature catalogue and status
`-- structure.md                    # This ownership map
```

## Ownership

`docs/implementation-plan.md` owns the phased roadmap. A checkbox becomes done only after its stated test passes.

`apps/void/` owns the active Void browser contract. `apps/e-browser/` is a legacy compatibility layer. `apps/eos-desktop-app/` owns only the future desktop application integration.

`assets/branding/` and `assets/wallpapers/` are canonical source assets. The build script copies them into the staged live filesystem and verifies their bytes. Generated images and ISOs belong in `out/`.

`build/manifests/eos-release.yaml` is the single source for the ISO version, architecture, Debian distribution, live username, hostname, and enabled/reserved profiles. The build injects this identity into the boot gate, SDDM, Plasma theme metadata, `/usr/lib/os-release`, and `/etc/os-release`, then rejects mismatches. EOS remains explicit about `ID_LIKE=debian`.

`build/live-build-config/includes.chroot/usr/share/plasma/look-and-feel/org.eos.privet.desktop/` owns the Plasma 6 Global Theme defaults and deterministic first-session top-bar/dock layout. `/etc/xdg/kdeglobals` and `/etc/skel/.config/kdeglobals` select it before Plasma starts.

`build/live-build-config/includes.chroot/usr/share/wallpapers/EOSPrivet/` owns the valid KDE wallpaper package. The canonical default is installed as `contents/images/1672x941.png`; `usr/local/bin/eos-wallpapers` changes only KDE ActivityManager's verified current activity. `eos-desktop-setup` is a locked, rollback-safe first-session transaction, not the primary theme mechanism. It owns separate factory-layout and migration markers so future updates cannot silently reset saved customization, and binds snapshots to that same current activity. `usr/local/lib/eos-privet/verify-plasma-layout` strictly validates live Plasma serialization, the exact activity's containment KConfig, and `plasmashellrc` panel-view state before setup can record success; `build/tests/` owns its regression suite and setup/verifier CLI contract.

Hooks under `build/live-build-config/hooks/live/` own all privileged image cleanup and cache updates. The live user must never attempt privileged cleanup. `hooks/normal/000-eos-hook-compatibility.hook.chroot` preserves the Debian 13 live-build hook-runner compatibility requirement found during Phase 2 testing.

`package-lists/eos-core.list.chroot` explicitly owns required desktop/runtime packages because APT recommendations are disabled. `eos-firmware.list.chroot` owns the reviewed common-PC firmware set. The build stages only manifest-enabled profiles. Reserved security lists must remain comments-only and cannot silently enter the image.

`build/scripts/build-iso.sh` owns source checks, a single-writer build lock, decoded mount safety, physically confined staging/publication, manifest profile selection, live-build configuration, chroot validation, completed-ISO extraction/byte-and-mode comparison, artifact naming, checksum creation, resolved package recording, and build information. It must reject an ISO when EOS JavaScript/theme metadata, any wallpaper or required-runtime bytes/modes, required packages, launcher IDs, desktop entries, trusted-file ownership/symlink targets, ISO volume identity, user identity, any normal/failsafe BIOS/UEFI boot arguments, or forbidden stock packages are wrong. The checksum covers all three release payloads and is published last as the completion marker.

`.gitattributes` keeps scripts, hooks, services, desktop files, JavaScript, Python, JSON, and manifests on Unix LF line endings even when edited on Windows.
