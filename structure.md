# EOS Privet structure

Last updated: 2026-08-15

```text
EOS/
├── assets/
│   └── branding/                 # Canonical logo and future brand assets
├── apps/
│   ├── e-browser/                # Transitional browser package area; likely to become Void-related later
│   └── eos-desktop-app/          # Future website-to-desktop application boundary
├── build/
│   ├── live-build-config/        # Versioned inputs copied into an isolated build workdir
│   │   ├── includes.chroot/       # Files included inside the live filesystem
│   │   ├── hooks/                  # Image-finalisation commands
│   │   └── package-lists/         # OS package profiles
│   ├── manifests/                # Machine-readable release/component manifests
│   └── scripts/                  # Repeatable build entry points
├── docs/                          # Design, privacy, and operational documentation
│   ├── boot-flow.md               # Pre-desktop text menu and unlock flow
│   └── privacy-mode.md            # Tails-inspired privacy-mode intent and guardrails
├── out/                           # Generated ISO and build outputs (ignored)
├── context.md                     # Product decisions; update on contextual changes
├── feather's.md                   # Features/status; update on capability changes
└── structure.md                   # This map; update on layout changes
```

## Ownership

`docs/implementation-plan.md` owns the phased roadmap and its verified completion tracking.

`apps/void/` owns the active Void browser contract. `apps/e-browser/` is now a legacy compatibility layer.

`docs/build-environment.md` owns the Debian VM setup and ISO build instructions.

| Path | Owns | Must not own |
| --- | --- | --- |
| `build/` | ISO assembly and base image defaults | application source code |
| `apps/e-browser/` | legacy launcher compatibility only | new browser product work |
| `apps/void/` | Void browser branding, launcher contract, and future package | Plasma-wide configuration |
| `apps/eos-desktop-app/` | future desktop app package/integration | website source unless intentionally imported later |
| `assets/branding/` | source brand assets | generated image artifacts |
| `docs/` | human-facing product, privacy, boot, and build notes | build inputs |

Generated content belongs in `out/` and must never be committed. The current local workspace may contain the first test ISO and checksum for VM testing.

Live-build hooks under `build/live-build-config/hooks/live/` own small image cleanup steps, such as removing default live-desktop prompts until the full EOS theme exists.

`includes.chroot/usr/share/wallpapers/EOSPrivet/` owns the versioned EOS fresh-session wallpaper. `includes.chroot/usr/local/bin/eos-desktop-setup` applies it inside Plasma and removes late-generated installer shortcuts. `eos-welcome` provides the plain-language Fresh-mode guide.

`assets/wallpapers/` owns the canonical Cicada wallpaper source files. The build script copies them into the live image; `eos-wallpapers` exposes the three alternatives in the desktop menu.
