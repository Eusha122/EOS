# EOS feature catalogue

Last updated: 2026-08-14

Status legend: `planned` · `scaffolded` · `in progress` · `verified`

| Feature | Status | Notes |
| --- | --- | --- |
| Bootable hybrid ISO | scaffolded | Live-build script targets a Kali-compatible `amd64` ISO. |
| UEFI + legacy boot | planned | Validate both against the chosen live-build release. |
| Lightweight Plasma desktop | scaffolded | Plasma is selected; desktop defaults and visual theme are next. |
| Smooth macOS-like experience | planned | Use Wayland, hardware acceleration, restrained effects, a dock, and original EOS styling. |
| E-Browser | scaffolded | Branded launcher with a dedicated user profile and desktop entry. |
| Default security toolkit | scaffolded | Tool list is deliberately modular in the package manifest. |
| Security profiles/editions | scaffolded | `core`, `web`, `network`, `forensics`, and `wireless` are package groups. |
| Future EOS desktop app | scaffolded | Isolated package boundary and placeholder launcher exist. |
| Installer | planned | Select after the live ISO has been tested. |
| Signed update channel | planned | Requires project keys, hosting, and release policy. |
| Automated ISO testing | planned | Add virtual-machine boot tests after the first successful build. |

## Performance acceptance goals

- Responsive desktop on integrated graphics that supports the selected Plasma session.
- Animations never block input; offer a reduced-effects preset.
- No always-running heavyweight service without a user-visible purpose.
- Security tools are installed only when their selected profile needs them.

## Safety boundary

EOS may include tools used for reconnaissance, testing, analysis, and auditing. They are for systems the operator owns or has clear written authority to assess. EOS documentation and defaults must not present unauthorised access as a supported use.
