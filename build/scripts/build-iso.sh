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

# Read one scalar from the release manifest. The key must appear exactly once at
# the requested position: at the top level when no parent block is named, or as a
# direct child of that block. Selecting a nested key by indentation alone would
# let a future same-named key in another block silently supply the live identity,
# so a missing, duplicated, or ambiguous key stops the build instead.
manifest_scalar() {
  local parent=$1
  local key=$2

  awk -v parent="$parent" -v key="$key" '
    { line = $0; sub(/\r$/, "", line); entry = "" }
    line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/ { next }
    line ~ /^[^ \t]/ {
      section = ""
      if (line ~ /^[A-Za-z0-9_.-]+:[ \t]*$/) {
        section = line
        sub(/:[ \t]*$/, "", section)
        next
      }
      if (parent != "") next
      entry = line
    }
    line ~ /^[ \t]/ {
      if (parent == "" || section != parent || line !~ /^  [^ \t]/) next
      entry = substr(line, 3)
    }
    {
      if (entry == "" || index(entry, key ":") != 1) next
      rest = substr(entry, length(key) + 2)
      if (rest !~ /^[ \t]/) next
      sub(/^[ \t]+/, "", rest)
      sub(/[ \t]+$/, "", rest)
      found++
      value = rest
    }
    END { if (found != 1) exit 1; print value }
  ' "$manifest"
}

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
config_root="$project_root/build/live-build-config"
manifest="$project_root/build/manifests/eos-release.yaml"
wallpaper_root="$project_root/assets/wallpapers"
branding_root="$project_root/assets/branding"
work_root="$project_root/build/.work/live-build"
output_root="$project_root/out"

[ -s "$manifest" ] || die "release manifest is missing or empty: $manifest"
version="$(manifest_scalar '' version)" || \
  die 'release manifest must define exactly one top-level version'
architecture="$(manifest_scalar '' architecture)" || \
  die 'release manifest must define exactly one top-level architecture'
distribution="$(manifest_scalar base distribution)" || \
  die 'release manifest must define exactly one base.distribution'
live_username="$(manifest_scalar live username)" || \
  die 'release manifest must define exactly one live.username'
live_hostname="$(manifest_scalar live hostname)" || \
  die 'release manifest must define exactly one live.hostname'
theme_id=org.eos.privet.desktop
wallpaper_name=1672x941.png
icon_theme=Papirus-Dark
iso_name="EOS-Privet-${version}-${architecture}.iso"
package_manifest_name="EOS-Privet-${version}-${architecture}.packages.tsv"
build_info_name="EOS-Privet-${version}-${architecture}.build-info.txt"
package_manifest_tmp="$work_root/$package_manifest_name"
build_info_tmp="$work_root/$build_info_name"
checksum_tmp="$work_root/$iso_name.sha256"
publish_iso_tmp="$output_root/.$iso_name.new.$$"
publish_checksum_tmp="$output_root/.$iso_name.sha256.new.$$"
publish_packages_tmp="$output_root/.$package_manifest_name.new.$$"
publish_build_info_tmp="$output_root/.$build_info_name.new.$$"

[ "$(id -u)" -eq 0 ] || \
  die 'run this build as root (for example: sudo bash build/scripts/build-iso.sh)'

for command_name in awk bash chmod chown chroot cmp cp find flock grep install lb mkdir mv node python3 readlink rm sed sh sha256sum sort stat unsquashfs xorriso; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "required build command is missing: $command_name"
done

[ -f "$manifest" ] && [ ! -L "$manifest" ] || \
  die 'the release manifest must be a regular file, not a symlink'
case "$(readlink -f -- "$manifest")" in
  "$project_root"/*) ;;
  *) die 'the release manifest resolves outside the project root' ;;
esac

fs_type="$(stat -f -c %T "$project_root" 2>/dev/null || true)"
case "$fs_type" in
  vboxsf|fuseblk|fuse.vboxsf)
    die 'do not build from a VirtualBox shared folder; copy the project to ~/EOS-build first'
    ;;
esac

[ -n "$version" ] || die 'release manifest is missing version'
[ -n "$architecture" ] || die 'release manifest is missing architecture'
[ -n "$distribution" ] || die 'release manifest is missing base.distribution'
[ -n "$live_username" ] || die 'release manifest is missing live.username'
[ -n "$live_hostname" ] || die 'release manifest is missing live.hostname'
[[ "$version" =~ ^[0-9A-Za-z._-]+$ ]] || die "unsafe version value: $version"
[[ "$architecture" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "unsafe architecture value: $architecture"
[ "$architecture" = amd64 ] || die "this release pipeline currently supports only amd64, not $architecture"
[[ "$distribution" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "unsafe distribution value: $distribution"
[[ "$live_username" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "unsafe live username: $live_username"
[[ "$live_hostname" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || \
  die "unsafe live hostname: $live_hostname"

case "$work_root" in
  "$project_root"/build/.work/live-build) ;;
  *) die 'refusing to clean an unexpected build work directory' ;;
esac
case "$output_root" in
  "$project_root"/out) ;;
  *) die 'refusing to publish into an unexpected output directory' ;;
esac

# Destructive cleanup and publication paths must be physically inside this
# project, not merely strings that pass the checks above. Reject symlinked
# build/output roots before creating, deleting, or replacing anything.
[ -d "$project_root/build" ] && [ ! -L "$project_root/build" ] || \
  die 'the project build directory must be a real directory, not a symlink'
[ -d "$config_root" ] && [ ! -L "$config_root" ] || \
  die 'the live-build configuration must be a real directory, not a symlink'
[ "$(readlink -f -- "$project_root/build")" = "$project_root/build" ] || \
  die 'the physical build directory escaped the project root'
[ "$(readlink -f -- "$config_root")" = "$config_root" ] || \
  die 'the physical live-build configuration escaped the project root'

build_lock="$project_root/build/.eos-build.lock"
if [ -e "$build_lock" ] || [ -L "$build_lock" ]; then
  [ -f "$build_lock" ] && [ ! -L "$build_lock" ] || \
    die 'the build lock must be a regular file, not a symlink'
fi
exec 9>"$build_lock"
flock -n 9 || die 'another EOS ISO build is already running for this project'

mkdir -p "$project_root/build/.work"
[ -d "$project_root/build/.work" ] && [ ! -L "$project_root/build/.work" ] || \
  die 'the build work parent must be a real directory, not a symlink'
[ "$(readlink -f -- "$project_root/build/.work")" = "$project_root/build/.work" ] || \
  die 'the physical build work parent escaped the project root'
if [ -e "$work_root" ] || [ -L "$work_root" ]; then
  [ -d "$work_root" ] && [ ! -L "$work_root" ] || \
    die 'the live-build work root must be a real directory, not a symlink'
  [ "$(readlink -f -- "$work_root")" = "$work_root" ] || \
    die 'the physical live-build work root escaped the project root'
fi

if [ -e "$output_root" ] || [ -L "$output_root" ]; then
  [ -d "$output_root" ] && [ ! -L "$output_root" ] || \
    die 'the output root must be a real directory, not a symlink'
else
  mkdir "$output_root"
fi
[ "$(readlink -f -- "$output_root")" = "$output_root" ] || \
  die 'the physical output root escaped the project root'

readarray -t enabled_profiles < <(
  awk '
    $0 == "profiles:" { in_profiles=1; next }
    in_profiles && $0 == "  enabled:" { section="enabled"; next }
    in_profiles && $0 == "  reserved:" { section="reserved"; next }
    in_profiles && /^[^ ]/ { exit }
    in_profiles && section == "enabled" && /^    - / {
      sub(/^    - /, ""); print
    }
  ' "$manifest"
)
readarray -t reserved_profiles < <(
  awk '
    $0 == "profiles:" { in_profiles=1; next }
    in_profiles && $0 == "  enabled:" { section="enabled"; next }
    in_profiles && $0 == "  reserved:" { section="reserved"; next }
    in_profiles && /^[^ ]/ { exit }
    in_profiles && section == "reserved" && /^    - / {
      sub(/^    - /, ""); print
    }
  ' "$manifest"
)
[ "${#enabled_profiles[@]}" -gt 0 ] || die 'the manifest enables no package profile'
declare -A profile_state=()
for profile_name in "${enabled_profiles[@]}"; do
  [[ "$profile_name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "unsafe enabled profile: $profile_name"
  [ -z "${profile_state[$profile_name]+set}" ] || die "duplicate package profile: $profile_name"
  profile_state[$profile_name]=enabled
done
for profile_name in "${reserved_profiles[@]}"; do
  [[ "$profile_name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "unsafe reserved profile: $profile_name"
  [ -z "${profile_state[$profile_name]+set}" ] || die "package profile is both enabled and reserved: $profile_name"
  profile_state[$profile_name]=reserved
done

mounts_below_work_root() {
  python3 - "$work_root" <<'PY'
import os
import re
import sys


root = os.path.normpath(sys.argv[1])


def decode_mount_field(value: str) -> str:
    return re.sub(
        r"\\(040|011|012|134)",
        lambda match: chr(int(match.group(1), 8)),
        value,
    )


with open("/proc/self/mountinfo", encoding="utf-8") as mountinfo:
    for line in mountinfo:
        fields = line.split()
        if len(fields) < 5:
            continue
        target = os.path.normpath(decode_mount_field(fields[4]))
        if target == root or target.startswith(root + os.sep):
            print(target)
PY
}

report_interrupted_build() {
  exit_status=$?
  trap - EXIT
  rm -f -- \
    "$publish_iso_tmp" \
    "$publish_checksum_tmp" \
    "$publish_packages_tmp" \
    "$publish_build_info_tmp" 2>/dev/null || true
  if [ "$exit_status" -ne 0 ]; then
    remaining_mounts="$(mounts_below_work_root || true)"
    if [ -n "$remaining_mounts" ]; then
      printf '%s\n' 'EOS build stopped with live-build mounts still active:' >&2
      printf '%s\n' "$remaining_mounts" >&2
      printf 'Before the next build, run: sudo umount -R %q\n' \
        "$work_root/chroot" >&2
    fi
  fi
  exit "$exit_status"
}
trap report_interrupted_build EXIT

for source_file in \
  "$branding_root/eos-logo.svg" \
  "$wallpaper_root/cicada-default.png" \
  "$wallpaper_root/cicada-01.png" \
  "$wallpaper_root/cicada-02.png" \
  "$wallpaper_root/cicada-03.png" \
  "$config_root/includes.chroot/usr/lib/os-release" \
  "$config_root/includes.chroot/usr/local/lib/eos-privet/verify-plasma-layout" \
  "$project_root/build/tests/test_verify_plasma_layout.py" \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/metadata.json" \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/contents/defaults" \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/contents/layouts/org.kde.plasma.desktop-layout.js" \
  "$config_root/includes.chroot/usr/share/wallpapers/EOSPrivet/metadata.json"
do
  [ -f "$source_file" ] && [ ! -L "$source_file" ] && [ -s "$source_file" ] || \
    die "required source asset is missing, empty, or a symlink: $source_file"
  case "$(readlink -f -- "$source_file")" in
    "$project_root"/*) ;;
    *) die "required source asset resolves outside the project root: $source_file" ;;
  esac
done

unexpected_source_symlink="$(find "$config_root" -type l -print -quit)"
[ -z "$unexpected_source_symlink" ] || \
  die "live-build source configuration contains an unsupported symlink: $unexpected_source_symlink"
unexpected_python_cache="$(find "$config_root" \( -type d -name __pycache__ -o -type f -name '*.py[cod]' \) -print -quit)"
[ -z "$unexpected_python_cache" ] || \
  die "live-build source contains generated Python bytecode: $unexpected_python_cache"

for metadata_file in \
  "$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/metadata.json" \
  "$config_root/includes.chroot/usr/share/wallpapers/EOSPrivet/metadata.json"
do
  python3 -m json.tool "$metadata_file" >/dev/null || \
    die "invalid JSON metadata: $metadata_file"
done

python3 - \
  "$wallpaper_root/cicada-default.png" \
  "$wallpaper_root/cicada-01.png" \
  "$wallpaper_root/cicada-02.png" \
  "$wallpaper_root/cicada-03.png" <<'PY' || \
  die 'an EOS wallpaper is not a valid 1672x941 PNG'
import struct
import sys

for path in sys.argv[1:]:
    with open(path, "rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise SystemExit(1)
    width, height = struct.unpack(">II", header[16:24])
    if (width, height) != (1672, 941):
        raise SystemExit(1)
PY

# Catch syntax errors in known project entry points before downloading or
# unpacking packages. Parse each script with the interpreter declared by its
# shebang instead of accepting Bash syntax through a POSIX-shell check.
check_shell_syntax() {
  local shell_file=$1
  local shebang
  IFS= read -r shebang < "$shell_file" || true
  case "$shebang" in
    *bash*) bash -n -- "$shell_file" ;;
    '#!'*) sh -n -- "$shell_file" ;;
    *) die "executable script has no supported shebang: $shell_file" ;;
  esac
}

while IFS= read -r -d '' shell_file; do
  check_shell_syntax "$shell_file" || die "shell syntax check failed: $shell_file"
done < <(
  find "$config_root/hooks" -type f -name '*.hook.chroot' -print0
)

for shell_file in \
  "$config_root/includes.chroot/usr/local/lib/eos-privet/boot-gate" \
  "$config_root/includes.chroot/usr/local/bin/e-browser" \
  "$config_root/includes.chroot/usr/local/bin/eos-desktop-app" \
  "$config_root/includes.chroot/usr/local/bin/eos-desktop-setup" \
  "$config_root/includes.chroot/usr/local/bin/eos-wallpapers" \
  "$config_root/includes.chroot/usr/local/bin/eos-welcome" \
  "$config_root/includes.chroot/usr/local/bin/void-browser"
do
  check_shell_syntax "$shell_file" || die "shell syntax check failed: $shell_file"
done

layout_source="$config_root/includes.chroot/usr/share/plasma/look-and-feel/$theme_id/contents/layouts/org.kde.plasma.desktop-layout.js"
node --check "$layout_source" >/dev/null || \
  die 'EOS Plasma layout JavaScript has invalid syntax'

python3 - "$config_root/includes.chroot/usr/local/lib/eos-privet/verify-plasma-layout" <<'PY' || \
  die 'EOS Plasma layout verifier has invalid Python syntax'
from pathlib import Path
import sys

path = Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY
PYTHONDONTWRITEBYTECODE=1 python3 "$project_root/build/tests/test_verify_plasma_layout.py" || \
  die 'EOS Plasma layout verifier regression tests failed'
unexpected_python_cache="$(find "$config_root" \( -type d -name __pycache__ -o -type f -name '*.py[cod]' \) -print -quit)"
[ -z "$unexpected_python_cache" ] || \
  die "source validation generated Python bytecode inside the live image tree: $unexpected_python_cache"

active_mounts="$(mounts_below_work_root)"
[ -z "$active_mounts" ] || {
  printf '%s\n' 'Refusing to delete a live-build work tree that still contains mounts:' >&2
  printf '%s\n' "$active_mounts" >&2
  die "unmount the stale chroot first: sudo umount -R $work_root/chroot"
}
rm -rf "$work_root"
mkdir -p "$work_root/config"
cp -a "$config_root/." "$work_root/config/"
chown -R 0:0 "$work_root/config"
find "$work_root/config" -type d -exec chmod 0755 {} +
find "$work_root/config" -type f -exec chmod 0644 {} +

find "$work_root/config/hooks" -type f -name '*.hook.chroot' -exec chmod 0755 {} +

# Only manifest-enabled package profiles reach live-build. Reserved lists must
# remain comments-only so adding a package cannot silently ship an unfinished
# security-tools profile.
package_list_root="$work_root/config/package-lists"
for profile_name in "${!profile_state[@]}"; do
  profile_file="$package_list_root/eos-$profile_name.list.chroot"
  [ -f "$profile_file" ] && [ ! -L "$profile_file" ] || \
    die "manifest profile has no regular package list: $profile_name"
  if [ "${profile_state[$profile_name]}" = reserved ]; then
    if awk 'NF && $1 !~ /^#/ { found=1 } END { exit found ? 0 : 1 }' "$profile_file"; then
      die "reserved package profile contains active packages: $profile_name"
    fi
    rm -f "$profile_file"
  fi
done
while IFS= read -r -d '' profile_file; do
  [ -f "$profile_file" ] && [ ! -L "$profile_file" ] || \
    die "package-list directory contains an unsupported entry: ${profile_file##*/}"
  profile_basename="${profile_file##*/}"
  [[ "$profile_basename" =~ ^eos-([a-z0-9][a-z0-9-]*)\.list\.chroot$ ]] || \
    die "package list bypasses the EOS manifest naming policy: $profile_basename"
  profile_name="${BASH_REMATCH[1]}"
  [ "${profile_state[$profile_name]:-}" = enabled ] || \
    die "active package list is not an enabled manifest profile: $profile_basename"
done < <(find "$package_list_root" -mindepth 1 -maxdepth 1 -print0)

for path in \
  "$work_root/config/includes.chroot/usr/local/lib/eos-privet/boot-gate" \
  "$work_root/config/includes.chroot/usr/local/lib/eos-privet/verify-plasma-layout" \
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
sed -i \
  -e "s/@EOS_VERSION@/$version/g" \
  -e "s/@EOS_BASE_CODENAME@/$distribution/g" \
  "$work_root/config/includes.chroot/usr/lib/os-release"

if grep -R -n -F '@EOS_' \
  "$work_root/config/includes.chroot/usr/local/lib/eos-privet/boot-gate" \
  "$work_root/config/includes.chroot/etc/sddm.conf.d/eos-live.conf" \
  "$work_root/config/includes.chroot/usr/lib/os-release" \
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
  --architectures "$architecture" \
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
  --iso-volume 'EOS_PRIVET' \
  --apt-indices false

lb build

active_mounts="$(mounts_below_work_root)"
[ -z "$active_mounts" ] || {
  printf '%s\n' 'live-build returned while mounts were still active:' >&2
  printf '%s\n' "$active_mounts" >&2
  die 'refusing to validate or publish an ISO from a mounted work tree'
}

shopt -s nullglob
artifacts=( "$work_root"/*.iso )
[ "${#artifacts[@]}" -eq 1 ] || \
  die "expected exactly one ISO artifact from live-build; found ${#artifacts[@]}"
iso_artifact="${artifacts[0]}"

chroot_root="$work_root/chroot"
required_live_files=(
  usr/lib/eos-privet/build-hooks-applied
  usr/bin/live-config
  usr/lib/live/config/0030-user-setup
  usr/lib/live/config/0085-sddm
  usr/lib/systemd/system/live-config.service
  usr/lib/user-setup/user-setup-apply
  usr/local/lib/eos-privet/boot-gate
  usr/local/lib/eos-privet/verify-plasma-layout
  usr/local/bin/e-browser
  usr/local/bin/eos-desktop-app
  usr/local/bin/eos-desktop-setup
  usr/local/bin/eos-wallpapers
  usr/local/bin/eos-welcome
  usr/local/bin/void-browser
  usr/lib/os-release
  etc/os-release
  var/lib/dpkg/status
  etc/sddm.conf.d/eos-live.conf
  etc/systemd/system/eos-boot-gate.service
  etc/systemd/system/display-manager.service.d/eos-boot-gate.conf
  usr/lib/systemd/user/plasma-plasmashell.service
  usr/share/dbus-1/services/org.kde.ActivityManager.service
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
  usr/share/wallpapers/EOSPrivet/contents/images/cicada-01.png
  usr/share/wallpapers/EOSPrivet/contents/images/cicada-02.png
  usr/share/wallpapers/EOSPrivet/contents/images/cicada-03.png
  usr/share/icons/hicolor/scalable/apps/void-browser.svg
  usr/share/icons/hicolor/scalable/apps/eos-privet.svg
  usr/share/icons/breeze-dark/index.theme
  "usr/share/icons/$icon_theme/index.theme"
  usr/share/color-schemes/BreezeDark.colors
  usr/share/plasma/desktoptheme/breeze-dark/metadata.json
  usr/share/applications/void-browser.desktop
  usr/share/applications/e-browser.desktop
  usr/share/applications/eos-desktop-app.desktop
  usr/share/applications/eos-wallpapers.desktop
  usr/share/applications/eos-welcome.desktop
  usr/share/applications/org.kde.dolphin.desktop
  usr/share/applications/org.kde.konsole.desktop
  usr/share/wayland-sessions/plasma.desktop
  usr/bin/bash
  usr/bin/cmp
  usr/bin/env
  usr/bin/qdbus6
  usr/bin/flock
  usr/bin/grep
  usr/bin/kdialog
  usr/bin/kreadconfig6
  usr/bin/kwriteconfig6
  usr/bin/kpackagetool6
  usr/bin/mktemp
  usr/bin/desktop-file-validate
  usr/bin/systemctl
  usr/bin/timeout
  usr/bin/torbrowser-launcher
  usr/bin/systemsettings
  usr/bin/dolphin
  usr/bin/konsole
  usr/bin/kinfocenter
  usr/bin/python3
)

required_symlink_map="$work_root/required-live-symlinks.tsv"

verify_required_tree() {
  local tree_root=$1
  local tree_label=$2
  local verification_mode=$3
  local byte_exempt=${4:-}

  EOS_BYTE_EXEMPT="$byte_exempt" \
  python3 - "$tree_root" "$tree_label" "$verification_mode" \
    "$required_symlink_map" "$chroot_root" "${required_live_files[@]}" <<'PY' || \
    die "$tree_label failed trusted-path verification"
from __future__ import annotations

import os
import stat
import sys
from collections import deque
from pathlib import Path


root = Path(sys.argv[1])
label = sys.argv[2]
mode = sys.argv[3]
map_path = Path(sys.argv[4])
reference_root = Path(sys.argv[5])
required = sys.argv[6:]

# Paths whose bytes legitimately differ between the validated chroot and the
# shipped image. Ownership, mode, symlink safety, and presence are still
# enforced; only the byte comparison is waived, and the caller must validate
# such a file's contents by another route.
byte_exempt = set(os.environ.get("EOS_BYTE_EXEMPT", "").split())


def reject(message: str) -> None:
    raise SystemExit(f"EOS build error: {label}: {message}")


if mode not in {"record", "verify"}:
    reject(f"unknown verification mode: {mode}")
if root.is_symlink() or not root.is_dir():
    reject(f"filesystem root is missing or is a symlink: {root}")
root_stat = os.lstat(root)
if root_stat.st_uid != 0 or root_stat.st_gid != 0 or root_stat.st_mode & 0o022:
    reject(f"filesystem root is not root-owned and non-writable: {root}")
if mode == "verify" and (reference_root.is_symlink() or not reference_root.is_dir()):
    reject(f"trusted reference root is missing or is a symlink: {reference_root}")
if mode == "verify":
    reference_root_stat = os.lstat(reference_root)
    if stat.S_IMODE(root_stat.st_mode) != stat.S_IMODE(reference_root_stat.st_mode):
        reject("filesystem-root mode differs from the validated live filesystem")


def validate_metadata(path: Path, relative: str, item_stat: os.stat_result) -> None:
    if item_stat.st_uid != 0 or item_stat.st_gid != 0:
        reject(f"non-root ownership on /{relative}")
    if not stat.S_ISLNK(item_stat.st_mode) and item_stat.st_mode & 0o022:
        reject(f"group/world-writable trusted path: /{relative}")
    if mode == "verify" and not stat.S_ISLNK(item_stat.st_mode):
        try:
            reference_stat = os.lstat(reference_root / relative)
        except OSError as error:
            reject(f"cannot inspect trusted reference /{relative}: {error}")
        if stat.S_IFMT(item_stat.st_mode) != stat.S_IFMT(reference_stat.st_mode):
            reject(f"final ISO file type differs from its reference: /{relative}")
        if stat.S_IMODE(item_stat.st_mode) != stat.S_IMODE(reference_stat.st_mode):
            reject(f"final ISO mode differs from its reference: /{relative}")


def validate_direct_parents(relative: str) -> Path:
    parts = relative.split("/")
    if not parts or any(part in {"", ".", ".."} for part in parts):
        reject(f"unsafe required path: {relative!r}")
    current = root
    for index, part in enumerate(parts[:-1]):
        current = current / part
        try:
            item_stat = os.lstat(current)
        except OSError as error:
            reject(f"cannot inspect /{'/'.join(parts[:index + 1])}: {error}")
        if stat.S_ISLNK(item_stat.st_mode) or not stat.S_ISDIR(item_stat.st_mode):
            reject(f"required path has a symlink/non-directory parent: /{relative}")
        validate_metadata(current, "/".join(parts[: index + 1]), item_stat)
    return current / parts[-1]


def resolve_image_path(relative: str) -> tuple[str, os.stat_result]:
    pending: deque[str] = deque(relative.split("/"))
    resolved: list[str] = []
    followed = 0
    while pending:
        part = pending.popleft()
        if part in {"", "."}:
            continue
        if part == "..":
            if not resolved:
                reject(f"symlink escapes the image root: /{relative}")
            resolved.pop()
            continue
        candidate = root.joinpath(*resolved, part)
        try:
            item_stat = os.lstat(candidate)
        except OSError as error:
            reject(f"broken required path /{relative}: {error}")
        validate_metadata(candidate, "/".join([*resolved, part]), item_stat)
        if stat.S_ISLNK(item_stat.st_mode):
            followed += 1
            if followed > 40:
                reject(f"symlink loop while resolving /{relative}")
            target = os.readlink(candidate)
            if any(character in target for character in "\t\r\n\0"):
                reject(f"unsafe symlink text on /{relative}")
            if target.startswith("/"):
                resolved.clear()
            pending.extendleft(reversed(target.split("/")))
            continue
        resolved.append(part)
    if not resolved:
        reject(f"required path resolves to the image root: /{relative}")
    target = root.joinpath(*resolved)
    target_stat = os.lstat(target)
    if not stat.S_ISREG(target_stat.st_mode):
        reject(f"required path does not resolve to a regular file: /{relative}")
    validate_metadata(target, "/".join(resolved), target_stat)
    return "/".join(resolved), target_stat


def files_equal(first: Path, second: Path) -> bool:
    try:
        first_stat = os.stat(first)
        second_stat = os.stat(second)
        if first_stat.st_size != second_stat.st_size:
            return False
        with first.open("rb") as first_stream, second.open("rb") as second_stream:
            while True:
                first_chunk = first_stream.read(1024 * 1024)
                second_chunk = second_stream.read(1024 * 1024)
                if first_chunk != second_chunk:
                    return False
                if not first_chunk:
                    return True
    except OSError as error:
        reject(f"could not compare a final ISO file with its reference: {error}")


reference: dict[str, tuple[str, str]] = {}
if mode == "verify":
    try:
        for raw_line in map_path.read_text(encoding="utf-8").splitlines():
            relative, link_text, target = raw_line.split("\t", 2)
            reference[relative] = (link_text, target)
    except (OSError, ValueError) as error:
        reject(f"cannot read trusted symlink map: {error}")

recorded: dict[str, tuple[str, str]] = {}
for relative in required:
    requested = validate_direct_parents(relative)
    try:
        requested_stat = os.lstat(requested)
    except OSError as error:
        reject(f"missing /{relative}: {error}")
    validate_metadata(requested, relative, requested_stat)

    if stat.S_ISLNK(requested_stat.st_mode):
        if not relative.startswith("usr/bin/"):
            reject(f"unexpected symlink at /{relative}")
        link_text = os.readlink(requested)
        if any(character in link_text for character in "\t\r\n\0"):
            reject(f"unsafe symlink text at /{relative}")
        target, _ = resolve_image_path(relative)
        if mode == "record":
            recorded[relative] = (link_text, target)
        elif reference.get(relative) != (link_text, target):
            reject(f"symlink changed from the validated live filesystem: /{relative}")
        comparison_target = target
    elif stat.S_ISREG(requested_stat.st_mode):
        if relative in reference:
            reject(f"validated symlink became a regular file: /{relative}")
        comparison_target = relative
    else:
        reject(f"required path is not a regular file or approved executable symlink: /{relative}")

    if mode == "verify":
        reference_path = reference_root / comparison_target
        final_path = root / comparison_target
        try:
            reference_mode = stat.S_IMODE(os.stat(reference_path).st_mode)
            final_mode = stat.S_IMODE(os.stat(final_path).st_mode)
        except OSError as error:
            reject(f"could not compare final ISO metadata with its reference: {error}")
        if final_mode != reference_mode:
            reject(
                "final ISO mode differs from the validated live filesystem: "
                f"/{relative} ({final_mode:04o} != {reference_mode:04o})"
            )
        if relative not in byte_exempt and not files_equal(reference_path, final_path):
            reject(
                f"final ISO bytes differ from the validated live filesystem: /{relative}"
            )

if mode == "record":
    lines = [
        f"{relative}\t{link_text}\t{target}\n"
        for relative, (link_text, target) in sorted(recorded.items())
    ]
    map_path.write_text("".join(lines), encoding="utf-8")
elif set(reference) != {
    relative for relative in required if os.path.islink(root / relative)
}:
    reject("final filesystem symlink set differs from the validated live filesystem")
PY
}

verify_required_tree "$chroot_root" 'built live filesystem' record

required_executable_files=(
  usr/local/lib/eos-privet/boot-gate
  usr/local/lib/eos-privet/verify-plasma-layout
  usr/local/bin/e-browser
  usr/local/bin/eos-desktop-app
  usr/local/bin/eos-desktop-setup
  usr/local/bin/eos-wallpapers
  usr/local/bin/eos-welcome
  usr/local/bin/void-browser
  usr/bin/bash
  usr/bin/cmp
  usr/bin/env
  usr/bin/live-config
  usr/bin/qdbus6
  usr/bin/flock
  usr/bin/grep
  usr/bin/kdialog
  usr/bin/kreadconfig6
  usr/bin/kwriteconfig6
  usr/bin/kpackagetool6
  usr/bin/mktemp
  usr/bin/desktop-file-validate
  usr/bin/systemctl
  usr/bin/timeout
  usr/bin/torbrowser-launcher
  usr/bin/systemsettings
  usr/bin/dolphin
  usr/bin/konsole
  usr/bin/kinfocenter
  usr/bin/python3
)

verify_required_executables() {
  local tree_root=$1
  local tree_label=$2
  local executable_path executable_target

  for executable_path in "${required_executable_files[@]}"; do
    executable_target="$(awk -F '\t' -v path="$executable_path" \
      '$1 == path { print $3; found=1; exit } END { if (!found) print path }' \
      "$required_symlink_map")"
    [ -f "$tree_root/$executable_target" ] && \
      [ ! -L "$tree_root/$executable_target" ] && \
      [ -x "$tree_root/$executable_target" ] || \
      die "$tree_label has a non-executable runtime file: /$executable_path"
  done
}

verify_required_executables "$chroot_root" 'built live filesystem'

required_packages=(
  breeze
  breeze-cursor-theme
  bash
  coreutils
  diffutils
  desktop-file-utils
  fonts-hack
  fonts-inter
  fonts-noto-color-emoji
  grep
  hicolor-icon-theme
  kde-style-breeze
  kf6-breeze-icon-theme
  kscreen
  kdialog
  kinfocenter
  kactivitymanagerd
  kpackagetool6
  libkf6config-bin
  papirus-icon-theme
  plasma-desktop
  plasma-desktoptheme
  plasma-pa
  plasma-workspace
  polkit-kde-agent-1
  powerdevil
  qdbus-qt6
  python3
  python3-minimal
  systemd
  systemsettings
  torbrowser-launcher
  util-linux
  xdg-desktop-portal-kde
)
for package_name in "${required_packages[@]}"; do
  package_status="$(chroot "$chroot_root" dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null || true)"
  [ "$package_status" = installed ] || \
    die "required runtime package is not installed: $package_name"
done

PYTHONDONTWRITEBYTECODE=1 chroot "$chroot_root" \
  /usr/local/lib/eos-privet/verify-plasma-layout \
  --help >/dev/null || \
  die 'EOS Plasma verifier cannot import or start with the live Python runtime'

cmp -s "$wallpaper_root/cicada-default.png" \
  "$chroot_root/usr/share/wallpapers/EOSPrivet/contents/images/$wallpaper_name" || \
  die 'installed default wallpaper does not match the source asset'
for alternate_wallpaper in cicada-01.png cicada-02.png cicada-03.png; do
  cmp -s "$wallpaper_root/$alternate_wallpaper" \
    "$chroot_root/usr/share/wallpapers/EOSPrivet/contents/images/$alternate_wallpaper" || \
    die "installed alternate wallpaper does not match the source asset: $alternate_wallpaper"
done
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
grep -Fxq "Theme=$icon_theme" "$chroot_root/etc/xdg/kdeglobals" || \
  die 'system KDE defaults do not select the EOS icon theme'
grep -Fxq "Theme=$icon_theme" "$chroot_root/etc/skel/.config/kdeglobals" || \
  die 'new-user KDE defaults do not select the EOS icon theme'
grep -Fxq "Theme=$icon_theme" \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/contents/defaults" || \
  die 'the EOS Global Theme does not default to the EOS icon theme'
grep -Fq "Theme $icon_theme" "$chroot_root/usr/local/bin/eos-desktop-setup" || \
  die 'the first-session setup does not apply the EOS icon theme'
grep -Fq "\"Version\": \"$version\"" \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/metadata.json" || \
  die 'EOS Global Theme version does not match the release manifest'
grep -Fq 'Image=EOSPrivet' \
  "$chroot_root/usr/share/plasma/look-and-feel/$theme_id/contents/defaults" || \
  die 'EOS Global Theme does not select the EOS wallpaper package'
grep -Fxq 'ID=eos-privet' "$chroot_root/usr/lib/os-release" || \
  die 'live system identity is not EOS Privet'
cmp -s "$chroot_root/usr/lib/os-release" "$chroot_root/etc/os-release" || \
  die '/etc/os-release does not match the canonical EOS system identity'
grep -Fxq 'ID_LIKE=debian' "$chroot_root/usr/lib/os-release" || \
  die 'live system identity does not disclose its Debian base'
grep -Fxq "BUILD_ID=\"$version\"" "$chroot_root/usr/lib/os-release" || \
  die 'live system identity version does not match the release manifest'
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
printf '%s\n' "$theme_list" | \
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
  grep -Fxq "$theme_id" || \
  die 'KPackage does not recognize the EOS Plasma Global Theme'

expected_user_line="User=$live_username"
grep -Fxq "$expected_user_line" "$chroot_root/etc/sddm.conf.d/eos-live.conf" || \
  die 'SDDM autologin identity does not match the release manifest'
grep -Fq "id $live_username" "$chroot_root/usr/local/lib/eos-privet/boot-gate" || \
  die 'boot-gate identity does not match the release manifest'

forbidden_paths=(
  usr/bin/plasma-welcome
  usr/share/applications/org.kde.plasma-welcome.desktop
  usr/share/applications/debian-installer-launcher.desktop
  usr/share/applications/install-debian.desktop
  etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
  usr/share/wallpapers/EOSPrivet/contents/images/cicada-default.png
  usr/share/wallpapers/EOSPrivet/contents/images/1920x1080.svg
)
for forbidden_path in "${forbidden_paths[@]}"; do
  [ ! -e "$chroot_root/$forbidden_path" ] || \
    die "stock or stale desktop item remains: /$forbidden_path"
done

forbidden_packages=(
  calamares
  firmware-b43-installer
  firmware-b43legacy-installer
  gimp
  libreoffice-core
)
for forbidden_package in "${forbidden_packages[@]}"; do
  forbidden_status="$(chroot "$chroot_root" dpkg-query -W -f='${db:Status-Status}' "$forbidden_package" 2>/dev/null || true)"
  [ "$forbidden_status" != installed ] || \
    die "forbidden package remains in the live system: $forbidden_package"
done

live_build_version="$(lb --version 2>&1)"
live_build_version="${live_build_version%%$'\n'*}"
{
  printf 'name=EOS Privet\n'
  printf 'version=%s\n' "$version"
  printf 'distribution=%s\n' "$distribution"
  printf 'architecture=%s\n' "$architecture"
  printf 'live_username=%s\n' "$live_username"
  printf 'live_hostname=%s\n' "$live_hostname"
  printf 'theme=%s\n' "$theme_id"
  printf 'wallpaper_sha256='
  sha256sum "$wallpaper_root/cicada-default.png" | awk '{print $1}'
  printf 'enabled_profiles=%s\n' "$(IFS=,; printf '%s' "${enabled_profiles[*]}")"
  printf 'live_build_version=%s\n' "$live_build_version"
} > "$build_info_tmp"

# Do not trust only live-build's mutable chroot: open the completed ISO and
# validate the actual SquashFS and both BIOS/UEFI boot configurations that will
# reach users. This turns missing branding into a build failure, not a surprise
# seen after a slow VM reboot.
final_squashfs="$work_root/final-filesystem.squashfs"
final_root="$work_root/final-root"
final_listing="$work_root/final-squashfs.list"
iso_grub_config="$work_root/final-grub.cfg"
iso_isolinux_config="$work_root/final-isolinux-live.cfg"

for validation_path in \
  "$final_squashfs" \
  "$final_root" \
  "$final_listing" \
  "$iso_grub_config" \
  "$iso_isolinux_config"
do
  [ ! -e "$validation_path" ] || \
    die "unexpected stale final-ISO validation path: $validation_path"
done

xorriso -osirrox on -indev "$iso_artifact" \
  -extract /live/filesystem.squashfs "$final_squashfs" >/dev/null 2>&1 || \
  die 'the completed ISO does not contain /live/filesystem.squashfs'
xorriso -assert_volid 'EOS_PRIVET' FATAL \
  -indev "$iso_artifact" -end >/dev/null 2>&1 || \
  die 'completed ISO does not have the exact EOS_PRIVET volume ID'
unsquashfs -lln "$final_squashfs" > "$final_listing" || \
  die 'could not list the completed ISO SquashFS'

# Selective extraction keeps validation fast and disk usage bounded. `-match`
# rejects a missing requested path, while `-follow` also extracts everything
# needed to resolve a requested symlink inside the image.
unsquashfs -no-progress -match -follow -d "$final_root" "$final_squashfs" \
  "${required_live_files[@]}" >/dev/null || \
  die 'could not extract required files from the completed ISO SquashFS'

# live-build installs its own boot-menu tooling into the chroot after the
# SquashFS is frozen, so the chroot's package database is no longer the database
# that ships. Its bytes cannot match, but its ownership, mode, and symlink safety
# still must; the shipped contents are validated against the ISO further below.
verify_required_tree "$final_root" 'final ISO filesystem' verify 'var/lib/dpkg/status'
verify_required_executables "$final_root" 'final ISO filesystem'

cmp -s "$wallpaper_root/cicada-default.png" \
  "$final_root/usr/share/wallpapers/EOSPrivet/contents/images/$wallpaper_name" || \
  die 'final ISO wallpaper does not match the selected source asset'
for alternate_wallpaper in cicada-01.png cicada-02.png cicada-03.png; do
  cmp -s "$wallpaper_root/$alternate_wallpaper" \
    "$final_root/usr/share/wallpapers/EOSPrivet/contents/images/$alternate_wallpaper" || \
    die "final ISO alternate wallpaper differs from its source asset: $alternate_wallpaper"
done
cmp -s "$branding_root/eos-logo.svg" \
  "$final_root/usr/share/icons/hicolor/scalable/apps/void-browser.svg" || \
  die 'final ISO Void icon does not match the selected source asset'
# The shipped database is the release record, so validate it directly rather than
# trusting a chroot that live-build keeps modifying after the SquashFS is frozen.
# Only var/lib/dpkg/status is extracted from the ISO, so read that file instead
# of depending on dpkg-query opening a partial admin directory.
shipped_package_status() {
  awk -v want="$1" '
    /^Package:[ \t]/ { pkg = $2; next }
    /^Status:[ \t]/ { if (pkg == want) { print $4; exit } }
  ' "$final_root/var/lib/dpkg/status"
}

for package_name in "${required_packages[@]}"; do
  [ "$(shipped_package_status "$package_name")" = installed ] || \
    die "final ISO is missing a required runtime package: $package_name"
done
for forbidden_package in "${forbidden_packages[@]}"; do
  [ "$(shipped_package_status "$forbidden_package")" != installed ] || \
    die "final ISO still contains a forbidden package: $forbidden_package"
done

awk '
  /^Package:[ \t]/ { pkg = $2; ver = ""; st = ""; next }
  /^Version:[ \t]/ { ver = $2; next }
  /^Status:[ \t]/ { st = $4; next }
  /^[ \t]*$/ {
    if (pkg != "" && st == "installed") printf "%s\t%s\n", pkg, ver
    pkg = ""; ver = ""; st = ""
  }
  END { if (pkg != "" && st == "installed") printf "%s\t%s\n", pkg, ver }
' "$final_root/var/lib/dpkg/status" | \
  LC_ALL=C sort > "$package_manifest_tmp"
[ -s "$package_manifest_tmp" ] || \
  die 'could not read the shipped package database from the completed ISO'

grep -Fxq "LookAndFeelPackage=$theme_id" "$final_root/etc/xdg/kdeglobals" || \
  die 'final ISO does not select the EOS Global Theme system-wide'
grep -Fxq "Theme=$icon_theme" "$final_root/etc/xdg/kdeglobals" || \
  die 'final ISO does not select the EOS icon theme system-wide'
grep -Fxq "Theme=$icon_theme" "$final_root/etc/skel/.config/kdeglobals" || \
  die 'final ISO new-user defaults do not select the EOS icon theme'
grep -Fxq 'ID=eos-privet' "$final_root/usr/lib/os-release" || \
  die 'final ISO system identity is not EOS Privet'
cmp -s "$final_root/usr/lib/os-release" "$final_root/etc/os-release" || \
  die 'final ISO /etc/os-release differs from its EOS identity'
grep -Fxq "BUILD_ID=\"$version\"" "$final_root/usr/lib/os-release" || \
  die 'final ISO system identity version does not match the release manifest'
grep -Fq "$wallpaper_name" \
  "$final_root/usr/share/plasma/look-and-feel/$theme_id/contents/layouts/org.kde.plasma.desktop-layout.js" || \
  die 'final ISO layout does not reference the installed EOS wallpaper'
python3 -m json.tool \
  "$final_root/usr/share/plasma/look-and-feel/$theme_id/metadata.json" >/dev/null || \
  die 'final ISO contains invalid EOS Global Theme metadata'

for forbidden_path in "${forbidden_paths[@]}"; do
  if grep -Fq "squashfs-root/$forbidden_path" "$final_listing"; then
    die "final ISO still contains a stock or stale desktop item: /$forbidden_path"
  fi
done

xorriso -osirrox on -indev "$iso_artifact" \
  -extract /boot/grub/grub.cfg "$iso_grub_config" >/dev/null 2>&1 || \
  die 'the completed ISO does not contain the UEFI GRUB configuration'
xorriso -osirrox on -indev "$iso_artifact" \
  -extract /isolinux/live.cfg "$iso_isolinux_config" >/dev/null 2>&1 || \
  die 'the completed ISO does not contain the BIOS live configuration'

awk -v username="username=$live_username" -v hostname="hostname=$live_hostname" '
  /^[[:space:]]*linux[[:space:]]/ && /boot=live/ {
    entries++
    if (index($0, username) == 0 || index($0, hostname) == 0) bad=1
  }
  END { exit entries >= 2 && !bad ? 0 : 1 }
' "$iso_grub_config" || \
  die 'a normal or failsafe UEFI boot entry has the wrong EOS live identity'
awk -v username="username=$live_username" -v hostname="hostname=$live_hostname" '
  /^[[:space:]]*append[[:space:]]/ && /boot=live/ {
    entries++
    if (index($0, username) == 0 || index($0, hostname) == 0) bad=1
  }
  END { exit entries >= 2 && !bad ? 0 : 1 }
' "$iso_isolinux_config" || \
  die 'a normal or failsafe BIOS boot entry has the wrong EOS live identity'

iso_digest="$(sha256sum "$iso_artifact" | awk '{print $1}')"
[ "${#iso_digest}" -eq 64 ] || die 'could not calculate the completed ISO SHA-256 digest'
package_digest="$(sha256sum "$package_manifest_tmp" | awk '{print $1}')"
build_info_digest="$(sha256sum "$build_info_tmp" | awk '{print $1}')"
[ "${#package_digest}" -eq 64 ] || die 'could not calculate the package-manifest SHA-256 digest'
[ "${#build_info_digest}" -eq 64 ] || die 'could not calculate the build-information SHA-256 digest'
{
  printf '%s  %s\n' "$iso_digest" "$iso_name"
  printf '%s  %s\n' "$package_digest" "$package_manifest_name"
  printf '%s  %s\n' "$build_info_digest" "$build_info_name"
} > "$checksum_tmp"

# Stage every publication file first. The checksum is renamed last and acts as
# the completion marker, so a failed build cannot be mistaken for a release.
mv "$iso_artifact" "$publish_iso_tmp"
mv "$package_manifest_tmp" "$publish_packages_tmp"
mv "$build_info_tmp" "$publish_build_info_tmp"
mv "$checksum_tmp" "$publish_checksum_tmp"

staged_digest="$(sha256sum "$publish_iso_tmp" | awk '{print $1}')"
[ "$staged_digest" = "$iso_digest" ] || \
  die 'staged publication ISO differs from the validated ISO'
staged_package_digest="$(sha256sum "$publish_packages_tmp" | awk '{print $1}')"
[ "$staged_package_digest" = "$package_digest" ] || \
  die 'staged package manifest differs from the validated package manifest'
staged_build_info_digest="$(sha256sum "$publish_build_info_tmp" | awk '{print $1}')"
[ "$staged_build_info_digest" = "$build_info_digest" ] || \
  die 'staged build information differs from the validated build information'

# Remove the old completion marker immediately before replacing same-version
# development artifacts. If publication is interrupted, no checksum remains to
# make the partial set look complete.
rm -f "$output_root/$iso_name.sha256"
mv -f "$publish_packages_tmp" "$output_root/$package_manifest_name"
mv -f "$publish_build_info_tmp" "$output_root/$build_info_name"
mv -f "$publish_iso_tmp" "$output_root/$iso_name"
mv -f "$publish_checksum_tmp" "$output_root/$iso_name.sha256"
if ! (cd "$output_root" && sha256sum --check --strict "$iso_name.sha256"); then
  rm -f "$output_root/$iso_name.sha256"
  die 'published ISO failed its final checksum verification'
fi

printf 'EOS Privet ISO written to %s\n' "$output_root/$iso_name"
printf 'Checksum written to %s\n' "$output_root/$iso_name.sha256"
printf 'Package manifest written to %s\n' "$output_root/$package_manifest_name"
printf 'Build information written to %s\n' "$output_root/$build_info_name"
