# SpaceShift developer guide

## Requirements

- macOS 14 or newer
- Apple Swift toolchain / Command Line Tools
- Apple Developer ID Application certificate for public distribution

## Local build

```sh
./scripts/build-app.sh release
open dist/SpaceShift.app
```

## DMG installer

```sh
./scripts/build-dmg.sh
```

## App icon

Prepare a transparent 1024×1024 master, then regenerate the icon set and `.icns`:

```sh
swift scripts/PrepareIcon.swift path/to/source.png Resources/SpaceShift-master.png
swift scripts/IconBuilder.swift Resources/SpaceShift-master.png .build/icon.iconset Resources/SpaceShift.icns
```

## Signed and notarized release

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh release
NOTARY_PROFILE="spaceshift-notary" ./scripts/build-dmg.sh
```

`NOTARY_PROFILE` is the name of credentials previously stored with `xcrun notarytool store-credentials`.

## Project layout

- `Sources/SpaceShift/` — SwiftUI application, menu bar UI, event interception, donation view.
- `LaunchAtLoginManager.swift` — native Login Items integration through `SMAppService.mainApp`.
- `Resources/` — Info.plist, application icon, DMG artwork, and the Tahoe-safe installer template.
- `scripts/build-app.sh` — optimized, stripped, hardened application build.
- `scripts/build-dmg.sh` — reproducible Tahoe-compatible drag-to-Applications DMG and optional notarization. It refreshes the app, icon, and background inside `SpaceShiftInstallerTemplate.dmg` while preserving Finder's native background alias.
- `scripts/DMGArrowBuilder.swift` — regenerates the transparent installer arrow.
- `scripts/vendor/create-dmg/` — vendored create-dmg 1.3.0 with its MIT license and Tahoe-safe Finder settings.
- `scripts/IconBuilder.swift` — source for regenerating the application icon.
- `THIRD_PARTY_NOTICES.md` — required license notice.
- `SECURITY.md` — release security model and limitations.

## Release checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Update the DMG filename in `scripts/build-dmg.sh`.
3. Build with the Developer ID identity.
4. Create and notarize the DMG.
5. Run `codesign --verify --deep --strict` and `hdiutil verify`.
6. Publish a fresh SHA-256 checksum.

Do not put Apple signing certificates, private keys, wallet seed phrases, or notarization credentials into the project directory.
