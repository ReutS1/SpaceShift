#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_path="$project_dir/dist/SpaceShift.app"
dmg_path="$project_dir/dist/SpaceShift-2.4.dmg"
template_path="$project_dir/Resources/SpaceShiftInstallerTemplate.dmg"
background_path="$project_dir/Resources/dmg-background-v2.png"
volume_name="SpaceShift Installer 2.4"
work_dir="$(mktemp -d /private/tmp/spaceshift-dmg.XXXXXX)"
rw_path="$work_dir/SpaceShift-template-rw.dmg"
mounted_device=""

cleanup() {
    if [[ -n "$mounted_device" ]]; then
        hdiutil detach "$mounted_device" >/dev/null 2>&1 || true
    fi
    if [[ "$work_dir" == /private/tmp/spaceshift-dmg.* && -d "$work_dir" ]]; then
        rm -rf "$work_dir"
    fi
}
trap cleanup EXIT

if [[ ! -d "$app_path" ]]; then
    "$project_dir/scripts/build-app.sh" release
fi
for required_file in "$template_path" "$background_path" "$project_dir/Resources/SpaceShift.icns"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Missing DMG resource: $required_file" >&2
        exit 1
    fi
done

# The template contains a Finder-authored background alias that remains valid
# on macOS Tahoe. Converting the template preserves its HFS+ volume identity;
# replacing files in place preserves Finder's background and icon layout.
hdiutil convert "$template_path" -format UDRW -o "$rw_path" >/dev/null
attach_output="$(hdiutil attach -readwrite -nobrowse "$rw_path")"
mounted_device="$(print -r -- "$attach_output" | awk '/^\/dev\// { print $1; exit }')"
mount_dir="/Volumes/$volume_name"
if [[ -z "$mounted_device" || ! -d "$mount_dir" ]]; then
    echo "Could not mount DMG template at $mount_dir" >&2
    exit 1
fi

rm -rf "$mount_dir/SpaceShift.app"
ditto "$app_path" "$mount_dir/SpaceShift.app"
cp "$background_path" "$mount_dir/.background/background.png"
cp "$project_dir/Resources/SpaceShift.icns" "$mount_dir/.VolumeIcon.icns"
sync
hdiutil detach "$mounted_device" >/dev/null
mounted_device=""

rm -f "$dmg_path"
hdiutil convert "$rw_path" -format UDZO -imagekey zlib-level=9 -o "$dmg_path" >/dev/null

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
fi

echo "$dmg_path"
