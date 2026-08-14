# E-Browser

E-Browser is the default browser product for EOS.

## Version 0.x

The first EOS images use a small launcher around the distribution Chromium package. It creates an E-Browser-specific profile, so browser data and future EOS settings have a stable migration point.

## Package boundary

This directory will own the browser's branding, policy, packaging, release notes, and eventually its source or upstream-fork integration. The ISO only consumes the resulting package/launcher; it must not contain browser product logic.

## Planned principles

- Fast cold start and sane defaults.
- Clear privacy and update behaviour.
- Support for security research extensions without bundling unsafe defaults.
- A stable profile migration path from the 0.x launcher.
