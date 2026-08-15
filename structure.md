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
|   |   |       |-- local/          # EOS boot/session programs
|   |   |       `-- share/
|   |   |           |-- applications/
|   |   |           |-- plasma/     # EOS Plasma 6 Global Theme and layout
|   |   |           `-- wallpapers/ # Valid EOS KDE wallpaper package
|   |   `-- package-lists/          # Explicit runtime and firmware packages
|   |-- manifests/                  # Version, base, identity, and profiles
|   `-- scripts/                    # Strict repeatable ISO build entry point
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

`build/manifests/eos-release.yaml` is the single source for the ISO version, Debian distribution, live username, hostname, and enabled/reserved profiles. The build injects this identity into the boot gate, SDDM, and theme metadata, then rejects mismatches.

`build/live-build-config/includes.chroot/usr/share/plasma/look-and-feel/org.eos.privet.desktop/` owns the Plasma 6 Global Theme defaults and deterministic first-session top-bar/dock layout. `/etc/xdg/kdeglobals` and `/etc/skel/.config/kdeglobals` select it before Plasma starts.

`build/live-build-config/includes.chroot/usr/share/wallpapers/EOSPrivet/` owns the valid KDE wallpaper package. The canonical default is installed as `contents/images/1672x941.png`. `eos-desktop-setup` is only a bounded, versioned repair and runtime verification path; it is not the primary theme mechanism.

Hooks under `build/live-build-config/hooks/live/` own all privileged image cleanup and cache updates. The live user must never attempt privileged cleanup. `hooks/normal/000-eos-hook-compatibility.hook.chroot` preserves the Debian 13 live-build hook-runner compatibility requirement found during Phase 2 testing.

`package-lists/eos-core.list.chroot` explicitly owns required desktop/runtime packages because APT recommendations are disabled. `eos-firmware.list.chroot` owns the reviewed common-PC firmware set. Security package lists are reserved for later opt-in profiles and are not enabled by the current manifest.

`build/scripts/build-iso.sh` owns source checks, isolated staging, live-build configuration, chroot validation, artifact naming, checksum creation, resolved package recording, and build information. It must reject an ISO when EOS theme metadata, wallpaper bytes, required packages, launcher IDs, desktop entries, user identity, or forbidden stock packages are wrong.

`.gitattributes` keeps scripts, hooks, services, desktop files, JavaScript, JSON, and manifests on Unix LF line endings even when edited on Windows.
