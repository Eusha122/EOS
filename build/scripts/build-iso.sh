#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

# Build and verify EOS Privet from a native Debian filesystem. The script is
# intentionally strict: a missing theme component must stop the build rather
# than produce an ISO that silently falls back to Debian's desktop defaults.

die() {
  printf 'EOS build error: %s\n' "$*" >&2
  exit 1
}

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config_root="$project_root/build/live-build-config"
manifest="$project_root/build/manifests/eos-release.yaml"
wallpaper_root="$project_root/assets/wallpapers"
branding_root="$project_root/assets/branding"
work_root="$project_root/build/.work/live-build"
output_root="$project_root/out"

version="$(sed -n 's/^version: //{p;q;}' "$manifest")"
distribution="$(sed -n 's/^  distribution: //{p;q;}' "$manifest")"
live_username="$(sed -n 's/^  username: //{p;q;}' "$manifest")"
live_hostname="$(sed -n 's/^  hostname: //{p;q;}' "$manifest")"
theme_id=org.eos.privet.desktop
wallpaper_name=1672x941.png
iso_name="EOS-Privet-${version}-amd64.iso"
package_manifest_name="EOS-Privet-${version}-amd64.packages.tsv"
build_info_name="EOS-Privet-${version}-amd64.build-info.txt"
package_manifest_tmp="$work_root/$package_manifest_name"
build_info_tmp="$work_root/$build_info_name"

[ "$(id -u)" -eq 0 ] || \
  die 'run this build as root (for example: sudo bash build/scripts/build-iso.sh)'

for command_name in awk chroot cmp cp find grep install lb mv python3 rm sed sh sha256sum sort stat; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "required build command is missing: $command_name"
done

fs_type="$(stat -f -c %T "$project_root" 2>/dev/null || true)"
case "$fs_type" in
  vboxsf|fuseblk|fuse.vboxsf)
    die 'do not build from a VirtualBox shared folder; copy the project to ~/EOS-build first'
    ;;
esac

[ -n "$version" ] || die 'release manifest is missing version'
[ -n "$distribution" ] || die 'release manifest is missing base.distribution'
[ -n "$live_username" ] || die 'release manifest is missing live.username'
[ -n "$live_hostname" ] || die 'release manifest is missing live.hostname'
[[ "$version" =~ ^[0-9A-Za-z._-]+$ ]] || die "unsafe version value: $version"
[[ "$distribution" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "unsafe distribution value: $distribution"
[[ "$live_username" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "unsafe live username: $live_username"
[[ "$live_hostname" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || \
  die "unsafe live hostname: $live_hostname"

case "$work_root" in
  "$project_root"/build/.work/live-build) ;;
  *) die 'refusing to clean an unexpected build work directory' ;;
esac

for source_file in \
  "$branding_root/eos-logo.svg" \
  "$wallpaper_root/cicada-default.png" \
  "$wallpaper_root/cicada-01.png" \
  "$wallpaper_root/cicada-02.png" \
  "$wallpaper_root/cicada-03.png" \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/metadata.json" \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/contents/defaults" \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/contents/layouts/org.kde.plasma.desktop-layout.js" \
  "$config_root/includes.chroot/usr/share/wallpapers/EOSPrivet/metadata.json"
do
  [ -s "$source_file" ] || die "required source asset is missing or empty: $source_file"
done

for metadata_file in \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/metadata.json" \
  "$config_root/includes.chroot/usr/share/wallpapers/EOSPrivet/metadata.json"
do
  python3 -m json.tool "$metadata_file" >/dev/null || \
    die "invalid JSON metadata: $metadata_file"
done

python3 - "$wallpaper_root/cicada-default.png" <<'PY' || \
  die 'the default wallpaper is not a valid 1672x941 PNG'
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as stream:
    header = stream.read(24)
if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
    raise SystemExit(1)
width, height = struct.unpack(">II", header[16:24])
if (width, height) != (1672, 941):
    raise SystemExit(1)
PY

# Catch syntax errors in project shell entry points before downloading or
# unpacking packages. The files are POSIX sh unless this build script says bash.
while IFS= read -r -d '' shell_file; do
  sh -n "$shell_file" || die "shell syntax check failed: $shell_file"
done < <(
  find "$config_root" -type f \( \
    -name '*.hook.chroot' -o \
    -path '*/usr/local/bin/*' -o \
    -path '*/usr/local/lib/eos-privet/*' \
  \) -print0
)

rm -rf "$work_root"
mkdir -p "$work_root/config" "$output_root"
cp -a "$config_root/." "$work_root/config/"

find "$work_root/config/hooks" -type f -name '*.hook.chroot' -exec chmod 0755 {} +
for path in \
  "$work_root/config/includes.chroot/usr/local/lib/eos-privet/boot-gate" \
  "$work_root/config/includes.chroot/usr/local/bin/eos-desktop-setup" \
  "$work_root/config/includes.chroot/usr/local/bin/eos-desktop-app" \
  "$work_root/config/includes.chroot/usr/local/bin/eos-welcome" \
  "$work_root/config/includes.chroot/usr/local/bin/eos-wallpapers" \
  "$work_root/config/includes.chroot/usr/local/bin/void-browser" \
  "$work_root/config/includes.chroot/usr/local/bin/e-browser"
do
  [ -e "$path" ] && chmod 0755 "$path"
done

sed -i \
  -e "s/@EOS_VERSION@/$version/g" \
  -e "s/@EOS_LIVE_USER@/$live_username/g" \
  "$work_root/config/includes.chroot/usr/local/lib/eos-privet/boot-gate"
sed -i \
  -e "s/@EOS_LIVE_USER@/$live_username/g" \
  "$work_root/config/includes.chroot/etc/sddm.conf.d/eos-live.conf"
sed -i \
  -e "s/@EOS_VERSION@/$version/g" \
  "$work_root/config/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/metadata.json"

if grep -R -n -F '@EOS_' \
  "$work_root/config/includes.chroot/usr/local/lib/eos-privet/boot-gate" \
  "$work_root/config/includes.chroot/etc/sddm.conf.d/eos-live.conf" \
  "$work_root/config/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/metadata.json"
then
  die 'an unresolved EOS build placeholder remains'
fi

install -Dm644 "$branding_root/eos-logo.svg" \
  "$work_root/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/void-browser.svg"
install -Dm644 "$branding_root/eos-logo.svg" \
  "$work_root/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/eos-privet.svg"

image_dir="$work_root/config/includes.chroot/usr/share/wallpapers/EOSPrivet/contents/images"
rm -f "$image_dir/cicada-default.png" "$image_dir/1920x1080.svg"
install -Dm644 "$wallpaper_root/cicada-default.png" "$image_dir/$wallpaper_name"
install -Dm644 "$wallpaper_root/cicada-01.png" "$image_dir/cicada-01.png"
install -Dm644 "$wallpaper_root/cicada-02.png" "$image_dir/cicada-02.png"
install -Dm644 "$wallpaper_root/cicada-03.png" "$image_dir/cicada-03.png"

cd "$work_root"

lb config \
  --ignore-system-defaults \
  --distribution "$distribution" \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer none \
  --apt-recommends false \
  --firmware-chroot false \
  --archive-areas 'main contrib non-free non-free-firmware' \
  --checksums sha256 \
  --bootappend-live "boot=live components username=$live_username hostname=$live_hostname quiet loglevel=3 systemd.show_status=false udev.log_level=3 vt.global_cursor_default=0" \
  --bootappend-live-failsafe "boot=live components username=$live_username hostname=$live_hostname memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal" \
  --iso-application 'EOS Privet' \
  --iso-publisher 'EOS Privet Project' \
  --apt-indices false

lb build

chroot_root="$work_root/chroot"
required_live_files=(
  usr/lib/eos-privet/build-hooks-applied
  usr/bin/live-config
  usr/lib/live/config/0030-user-setup
  usr/lib/live/config/0085-sddm
  usr/lib/systemd/system/live-config.service
  usr/lib/user-setup/user-setup-apply
  usr/local/lib/eos-privet/boot-gate
  usr/local/bin/eos-desktop-setup
  usr/local/bin/eos-welcome
  usr/local/bin/void-browser
  etc/sddm.conf.d/eos-live.conf
  etc/xdg/kdeglobals
  etc/xdg/kicker-extra-favoritesrc
  etc/xdg/autostart/eos-desktop-setup.desktop
  etc/xdg/autostart/eos-welcome.desktop
  etc/skel/.config/kdeglobals
  etc/skel/.config/plasmarc
  usr/share/plasma/look-and-feel/org.eos.privet.desktop/metadata.json
  usr/share/plasma/look-and-feel/org.eos.privet.desktop/contents/defaults
  usr/share/plasma/look-and-feel/org.eos.privet.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
  usr/share/plasma/plasmoids/org.kde.plasma.digitalclock/metadata.json
  usr/share/plasma/plasmoids/org.kde.plasma.icontasks/metadata.json
  usr/share/plasma/plasmoids/org.kde.plasma.kickoff/metadata.json
  usr/share/plasma/plasmoids/org.kde.plasma.panelspacer/metadata.json
  usr/share/plasma/plasmoids/org.kde.plasma.showdesktop/metadata.json
  usr/share/plasma/plasmoids/org.kde.plasma.systemtray/metadata.json
  usr/share/wallpapers/EOSPrivet/metadata.json
  usr/share/wallpapers/EOSPrivet/contents/images/1672x941.png
  usr/share/icons/hicolor/scalable/apps/void-browser.svg
  usr/share/icons/hicolor/scalable/apps/eos-privet.svg
  usr/share/icons/breeze-dark/index.theme
  usr/share/color-schemes/BreezeDark.colors
  usr/share/plasma/desktoptheme/breeze-dark/metadata.json
  usr/share/applications/void-browser.desktop
  usr/share/applications/eos-welcome.desktop
  usr/share/applications/org.kde.dolphin.desktop
  usr/share/applications/org.kde.konsole.desktop
  usr/share/wayland-sessions/plasma.desktop
  usr/bin/qdbus6
  usr/bin/kwriteconfig6
  usr/bin/kpackagetool6
  usr/bin/desktop-file-validate
  usr/bin/plasma-apply-wallpaperimage
  usr/bin/systemsettings
  usr/bin/dolphin
  usr/bin/konsole
)
for relative_path in "${required_live_files[@]}"; do
  [ -e "$chroot_root/$relative_path" ] || \
    die "built live filesystem is missing: /$relative_path"
done

for executable_path in \
  usr/local/lib/eos-privet/boot-gate \
  usr/local/bin/eos-desktop-setup \
  usr/local/bin/eos-welcome \
  usr/local/bin/void-browser \
  usr/bin/qdbus6 \
  usr/bin/kwriteconfig6 \
  usr/bin/kpackagetool6 \
  usr/bin/plasma-apply-wallpaperimage
do
  [ -x "$chroot_root/$executable_path" ] || \
    die "required executable is not executable: /$executable_path"
done

required_packages=(
  breeze
  breeze-cursor-theme
  desktop-file-utils
  fonts-hack
  fonts-inter
  fonts-noto-color-emoji
  hicolor-icon-theme
  kde-style-breeze
  kf6-breeze-icon-theme
  kscreen
  kpackagetool6
  libkf6config-bin
  plasma-desktop
  plasma-desktoptheme
  plasma-pa
  polkit-kde-agent-1
  powerdevil
  qdbus-qt6
  systemsettings
  xdg-desktop-portal-kde
)
for package_name in "${required_packages[@]}"; do
  package_status="$(chroot "$chroot_root" dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null || true)"
  [ "$package_status" = installed ] || \
    die "required runtime package is not installed: $package_name"
done

cmp -s "$wallpaper_root/cicada-default.png" \
  "$chroot_root/usr/share/wallpapers/EOSPrivet/contents/images/$wallpaper_name" || \
  die 'installed default wallpaper does not match the source asset'
cmp -s "$branding_root/eos-logo.svg" \
  "$chroot_root/usr/share/icons/hicolor/scalable/apps/void-browser.svg" || \
  die 'installed Void icon does not match the source logo'
cmp -s "$branding_root/eos-logo.svg" \
  "$chroot_root/usr/share/icons/hicolor/scalable/apps/eos-privet.svg" || \
  die 'installed EOS icon does not match the source logo'

for metadata_file in \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/metadata.json" \
  "$chroot_root/usr/share/wallpapers/EOSPrivet/metadata.json"
do
  python3 -m json.tool "$metadata_file" >/dev/null || \
    die "installed theme metadata is invalid: $metadata_file"
done

grep -Fxq "LookAndFeelPackage=$theme_id" "$chroot_root/etc/xdg/kdeglobals" || \
  die 'system KDE defaults do not select the EOS Global Theme'
grep -Fxq "LookAndFeelPackage=$theme_id" "$chroot_root/etc/skel/.config/kdeglobals" || \
  die 'new-user KDE defaults do not select the EOS Global Theme'
grep -Fq "\"Version\": \"$version\"" \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/metadata.json" || \
  die 'EOS Global Theme version does not match the release manifest'
grep -Fq 'Image=EOSPrivet' \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/contents/defaults" || \
  die 'EOS Global Theme does not select the EOS wallpaper package'
grep -Fq "file:///usr/share/wallpapers/EOSPrivet/contents/images/$wallpaper_name" \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/contents/layouts/org.kde.plasma.desktop-layout.js" || \
  die 'EOS layout does not select the exact installed wallpaper'

if grep -R -E -q 'org\.debian\.desktop|DebianTheme' \
  "$chroot_root/etc/xdg/kdeglobals" \
  "$chroot_root/etc/skel/.config/kdeglobals" \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id"
then
  die 'Debian desktop identity leaked into the EOS desktop defaults'
fi

layout_file="$chroot_root/usr/share/plasma/look-and-feel/$theme_id/contents/layouts/org.kde.plasma.desktop-layout.js"
for launcher_id in \
  void-browser.desktop \
  org.kde.dolphin.desktop \
  org.kde.konsole.desktop \
  eos-welcome.desktop
do
  grep -Fq "applications:$launcher_id" "$layout_file" || \
    die "EOS dock layout is missing launcher: $launcher_id"
  [ -e "$chroot_root/usr/share/applications/$launcher_id" ] || \
    die "EOS dock references an unavailable launcher: $launcher_id"
done

desktop_files=(
  usr/share/applications/e-browser.desktop
  usr/share/applications/eos-desktop-app.desktop
  usr/share/applications/eos-wallpapers.desktop
  usr/share/applications/eos-welcome.desktop
  usr/share/applications/void-browser.desktop
  etc/xdg/autostart/eos-desktop-setup.desktop
  etc/xdg/autostart/eos-welcome.desktop
)
for desktop_file in "${desktop_files[@]}"; do
  [ -e "$chroot_root/$desktop_file" ] || \
    die "desktop entry is missing: /$desktop_file"
  chroot "$chroot_root" /usr/bin/desktop-file-validate "/$desktop_file" || \
    die "desktop entry validation failed: /$desktop_file"
done

theme_list="$(chroot "$chroot_root" /usr/bin/kpackagetool6 \
  --global --type=Plasma/LookAndFeel --list 2>&1)" || {
  printf '%s\n' "$theme_list" >&2
  die 'KPackage could not enumerate Plasma Global Themes'
}
printf '%s\n' "$theme_list" | grep -Fq "$theme_id" || \
  die 'KPackage does not recognize the EOS Plasma Global Theme'

expected_user_line="User=$live_username"
grep -Fxq "$expected_user_line" "$chroot_root/etc/sddm.conf.d/eos-live.conf" || \
  die 'SDDM autologin identity does not match the release manifest'
grep -Fq "id $live_username" "$chroot_root/usr/local/lib/eos-privet/boot-gate" || \
  die 'boot-gate identity does not match the release manifest'

for forbidden_path in \
  usr/bin/plasma-welcome \
  usr/share/applications/org.kde.plasma-welcome.desktop \
  usr/share/applications/debian-installer-launcher.desktop \
  usr/share/applications/install-debian.desktop \
  etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc \
  usr/share/wallpapers/EOSPrivet/contents/images/cicada-default.png \
  usr/share/wallpapers/EOSPrivet/contents/images/1920x1080.svg
do
  [ ! -e "$chroot_root/$forbidden_path" ] || \
    die "stock or stale desktop item remains: /$forbidden_path"
done

for forbidden_package in \
  calamares \
  firmware-b43-installer \
  firmware-b43legacy-installer \
  gimp \
  libreoffice-core
do
  forbidden_status="$(chroot "$chroot_root" dpkg-query -W -f='${db:Status-Status}' "$forbidden_package" 2>/dev/null || true)"
  [ "$forbidden_status" != installed ] || \
    die "download-at-install firmware package remains: $forbidden_package"
done

chroot "$chroot_root" dpkg-query -W -f='${binary:Package}\t${Version}\n' | \
  LC_ALL=C sort > "$package_manifest_tmp"
live_build_version="$(lb --version 2>&1)"
live_build_version="${live_build_version%%$'\n'*}"
{
  printf 'name=EOS Privet\n'
  printf 'version=%s\n' "$version"
  printf 'distribution=%s\n' "$distribution"
  printf 'architecture=amd64\n'
  printf 'live_username=%s\n' "$live_username"
  printf 'live_hostname=%s\n' "$live_hostname"
  printf 'theme=%s\n' "$theme_id"
  printf 'wallpaper_sha256='
  sha256sum "$wallpaper_root/cicada-default.png" | awk '{print $1}'
  printf 'live_build_version=%s\n' "$live_build_version"
} > "$build_info_tmp"

shopt -s nullglob
artifacts=( *.iso )
[ "${#artifacts[@]}" -eq 1 ] || \
  die "expected exactly one ISO artifact from live-build; found ${#artifacts[@]}"

rm -f \
  "$output_root/$iso_name" \
  "$output_root/$iso_name.sha256" \
  "$output_root/$package_manifest_name" \
  "$output_root/$build_info_name"
mv "${artifacts[0]}" "$output_root/$iso_name"
mv "$package_manifest_tmp" "$output_root/$package_manifest_name"
mv "$build_info_tmp" "$output_root/$build_info_name"
(cd "$output_root" && sha256sum "$iso_name" > "$iso_name.sha256")
(cd "$output_root" && sha256sum --check "$iso_name.sha256")

printf 'EOS Privet ISO written to %s\n' "$output_root/$iso_name"
printf 'Checksum written to %s\n' "$output_root/$iso_name.sha256"
printf 'Package manifest written to %s\n' "$output_root/$package_manifest_name"
printf 'Build information written to %s\n' "$output_root/$build_info_name"
