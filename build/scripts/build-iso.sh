#!/usr/bin/env bash
set -euo pipefail

# Build EOS Privet from a Debian Linux system with live-build installed.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config_root="$project_root/build/live-build-config"
wallpaper_root="$project_root/assets/wallpapers"
work_root="$project_root/build/.work/live-build"
output_root="$project_root/out"
version="$(sed -n 's/^version: //p' "$project_root/build/manifests/eos-release.yaml" | head -n 1)"
distribution="$(sed -n 's/^  distribution: //p' "$project_root/build/manifests/eos-release.yaml" | head -n 1)"
iso_name="EOS-Privet-${version}-amd64.iso"

[ "$(id -u)" -eq 0 ] || {
  printf '%s\n' 'Run this build as root (for example: sudo bash build/scripts/build-iso.sh).' >&2
  exit 1
}

command -v lb >/dev/null 2>&1 || {
  printf '%s\n' 'live-build (lb) is required. See README.md.' >&2
  exit 1
}

fs_type="$(stat -f -c %T "$project_root" 2>/dev/null || true)"
case "$fs_type" in
  vboxsf|fuseblk|fuse.vboxsf)
    printf '%s\n' 'Do not run the ISO build from a VirtualBox shared folder.' >&2
    printf '%s\n' 'Copy the project to a native Linux folder first, for example: cp -a /media/sf_EOS "$HOME/EOS-build"' >&2
    printf '%s\n' 'Then run: cd "$HOME/EOS-build" && sudo bash build/scripts/build-iso.sh' >&2
    exit 1
    ;;
esac

[ -n "$version" ] && [ -n "$distribution" ] || {
  printf '%s\n' 'The release manifest must define version and base.distribution.' >&2
  exit 1
}

case "$work_root" in
  "$project_root"/build/.work/live-build) ;;
  *) printf '%s\n' 'Refusing to clean an unexpected build work directory.' >&2; exit 1 ;;
esac

rm -rf "$work_root"
mkdir -p "$work_root/config" "$output_root"
cp -a "$config_root/." "$work_root/config/"
find "$work_root/config/hooks" -type f -name '*.hook.chroot' -exec chmod 0755 {} +
install -Dm644 "$project_root/assets/branding/eos-logo.svg" \
  "$work_root/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/void-browser.svg"
install -Dm644 "$wallpaper_root/cicada-default.png" \
  "$work_root/config/includes.chroot/usr/share/wallpapers/EOSPrivet/contents/images/cicada-default.png"
install -Dm644 "$wallpaper_root/cicada-01.png" \
  "$work_root/config/includes.chroot/usr/share/wallpapers/EOSPrivet/contents/images/cicada-01.png"
install -Dm644 "$wallpaper_root/cicada-02.png" \
  "$work_root/config/includes.chroot/usr/share/wallpapers/EOSPrivet/contents/images/cicada-02.png"
install -Dm644 "$wallpaper_root/cicada-03.png" \
  "$work_root/config/includes.chroot/usr/share/wallpapers/EOSPrivet/contents/images/cicada-03.png"
cd "$work_root"

lb config \
  --distribution "$distribution" \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer none \
  --archive-areas 'main contrib non-free non-free-firmware' \
  --bootappend-live 'boot=live components username=eos hostname=eos-privet quiet loglevel=3 systemd.show_status=false udev.log_level=3 vt.global_cursor_default=0' \
  --iso-application 'EOS Privet' \
  --iso-publisher 'EOS Privet Project' \
  --apt-indices false

lb build

shopt -s nullglob
artifacts=( *.iso )
[ "${#artifacts[@]}" -eq 1 ] || {
  printf '%s\n' 'Expected exactly one ISO artifact from live-build.' >&2
  exit 1
}

mv "${artifacts[0]}" "$output_root/$iso_name"
(cd "$output_root" && sha256sum "$iso_name" > "$iso_name.sha256")
printf 'EOS Privet ISO written to %s\n' "$output_root/$iso_name"
printf 'Checksum written to %s\n' "$output_root/$iso_name.sha256"
