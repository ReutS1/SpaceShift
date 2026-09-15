#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/SpaceShift.app"
cache_dir="$project_dir/.cache/clang"
scratch_dir="$project_dir/.build"

mkdir -p "$cache_dir" "$scratch_dir"

# A pre-27 SDK is sufficient for our macOS 14 deployment target and avoids a
# SwiftUI macro-plugin mismatch in the standalone macOS 27 Command Line Tools.
if [[ -z "${SDKROOT:-}" ]]; then
    for compatible_sdk in \
        /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
        /Library/Developer/CommandLineTools/SDKs/MacOSX26.7.sdk \
        /Library/Developer/CommandLineTools/SDKs/MacOSX26.6.sdk \
        /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk; do
        if [[ -d "$compatible_sdk" ]]; then
            export SDKROOT="$compatible_sdk"
            break
        fi
    done
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
cp "$project_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"

strip -x "$app_dir/Contents/MacOS/SpaceShift"

sign_identity="${SIGN_IDENTITY:--}"
if [[ "$sign_identity" == "-" ]]; then
    codesign --force --deep --options runtime --sign - "$app_dir"
else
    codesign --force --deep --options runtime --timestamp --sign "$sign_identity" "$app_dir"
fi
echo "$app_dir"
