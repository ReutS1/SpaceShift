# Changelog

All notable changes to SpaceShift are documented here.

## [2.5] - 2026-09-15

### Fixed

- Restored keyboard and trackpad Space switching on macOS 27 by attaching the
  IOHID gesture payload now required by Dock.
- Corrected the physical trackpad swipe direction on macOS 27.
- Kept the pre-macOS 27 gesture path unchanged for backward compatibility.

### Changed

- Allowed release builds to use the bundled macOS 26.5 SDK when the standalone
  macOS 27 Command Line Tools cannot load SwiftUI macro implementations.

## [2.4] - 2026-08-18

### Added

- Adjustable native Space-switching speed from 1× to 2.5×.
- Support for `Control + Left/Right Arrow` and physical three-finger swipes.
- Menu bar controls, speed presets, and transition testing.
- Native Launch at Login integration through `SMAppService`.
- Drag-to-Applications DMG installer and release build tooling.
- Optional donation window with a locally generated QR code.
- About SpaceShift command in the menu bar menu.

### Changed

- Replaced the application and installer artwork with the new SpaceShift icon.
- Licensed the SpaceShift source code under GNU GPL v3.0.

### Security

- No networking, analytics, updater, or event logging.
- Optimized and stripped release binary with hardened runtime enabled.

[2.5]: https://github.com/ReutS1/SpaceShift/releases/tag/v2.5
[2.4]: https://github.com/ReutS1/SpaceShift/releases/tag/v2.4
