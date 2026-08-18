#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/SpaceShift.app"
cache_dir="$project_dir/.cache/clang"
scratch_dir="$project_dir/.build"

mkdir -p "$cache_dir" "$scratch_dir"

# The 15.4 SDK is sufficient for our macOS 14 deployment target and also
# works around mixed beta Command Line Tools installations.
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="$cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_dir"

cd "$project_dir"
swift build -c "$configuration" --disable-sandbox --scratch-path "$scratch_dir"

binary_path="$(swift build -c "$configuration" --disable-sandbox --scratch-path "$scratch_dir" --show-bin-path)/SpaceShift"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_path" "$app_dir/Contents/MacOS/SpaceShift"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/SpaceShift.icns" "$app_dir/Contents/Resources/SpaceShift.icns"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"

strip -x "$app_dir/Contents/MacOS/SpaceShift"

sign_identity="${SIGN_IDENTITY:--}"
if [[ "$sign_identity" == "-" ]]; then
    codesign --force --deep --options runtime --sign - "$app_dir"
else
    codesign --force --deep --options runtime --timestamp --sign "$sign_identity" "$app_dir"
fi
echo "$app_dir"
