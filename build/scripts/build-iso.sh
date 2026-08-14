#!/usr/bin/env bash
set -euo pipefail

# Build EOS from a Debian/Kali-compatible Linux system with live-build installed.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config_root="$project_root/build/live-build-config"
work_root="$project_root/build/.work/live-build"
output_root="$project_root/out"
version="$(sed -n 's/^version: //p' "$project_root/build/manifests/eos-release.yaml" | head -n 1)"

command -v lb >/dev/null 2>&1 || {
  printf '%s\n' 'live-build (lb) is required. See README.md.' >&2
  exit 1
}

rm -rf "$work_root"
mkdir -p "$work_root/config" "$output_root"
cp -a "$config_root/." "$work_root/config/"
install -Dm644 "$project_root/assets/branding/eos-logo.svg" \
  "$work_root/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/e-browser.svg"
cd "$work_root"

lb config \
  --distribution kali-rolling \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer live \
  --archive-areas 'main contrib non-free non-free-firmware' \
  --bootappend-live 'boot=live components username=eos hostname=eos' \
  --apt-indices false

lb build
mv live-image-amd64.hybrid.iso "$output_root/EOS-${version}-amd64.iso"
printf 'EOS ISO written to %s\n' "$output_root/EOS-${version}-amd64.iso"
