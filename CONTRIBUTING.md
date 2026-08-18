# Contributing to SpaceShift

Thank you for helping improve SpaceShift.

## Before opening an issue

- Search existing issues for the same problem or suggestion.
- Include your macOS version and Mac model for behavior-related reports.
- Never post signing certificates, private keys, notarization credentials, or other secrets.

## Development

Build and launch a release configuration with:

```sh
./scripts/build-app.sh release
open dist/SpaceShift.app
```

SpaceShift requires Accessibility permission to intercept supported keyboard and trackpad events. A rebuilt executable may need permission granted again.

## Pull requests

1. Keep each change focused.
2. Explain the user-visible behavior and how it was tested.
3. Run `swift build -c release` and `./scripts/build-app.sh release`.
4. Update documentation when behavior or requirements change.

By contributing, you confirm that you have the right to submit your work and agree to license the contribution under GPL-3.0-only.
