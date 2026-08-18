# SpaceShift security notes

## Release audit

- The `.app` contains no Swift/C source files, headers, debug symbols, or dSYM bundle.
- Release binaries are optimized and stripped with `strip -x`.
- Code signing enables the hardened runtime.
- The bundle contains only the executable, Info.plist, icon, code-signature seal, and required third-party license notice.
- The application has no networking code, analytics, updater, shell execution, preference-file mutation, or dynamic private-framework loading.
- The only sensitive capability is macOS Accessibility access, used for the keyboard/trackpad event tap. SpaceShift does not log or persist intercepted events.
- The DMG checksum, embedded application signature, and Applications symlink were verified after creation.

## Distribution

The local artifact is ad-hoc signed. Before public distribution, rebuild with an Apple **Developer ID Application** certificate and notarize the DMG:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh release
NOTARY_PROFILE="spaceshift-notary" ./scripts/build-dmg.sh
```

## Reverse-engineering limitation

Compiled client software cannot be made impossible to copy or reverse engineer. Stripping removes easy symbol information and the release contains no source, but a determined analyst can still study machine code and runtime behavior. Code signing and notarization protect users from modified builds; they do not provide copy protection. If SpaceShift later becomes paid software, meaningful license enforcement should use signed licenses or a server-side entitlement service.
