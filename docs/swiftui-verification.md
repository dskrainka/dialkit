# SwiftUI verification

Verified on November 6, 2026, with Xcode 27.2 and the existing iPhone 18 Pro simulator
running iOS 27.2. The starting upstream commit was `1ef9fe8` (DialKit 2.1.0).

- `npm test`: 138 tests passed.
- `npm run typecheck`: no errors; 57 existing Svelte warnings.
- `npm run build`: passed for the upstream web adapters.
- `node scripts/build-swiftui-resources.mjs`: bundled the built vanilla editor and CSS.
- `swift test`: six native/WebKit tests passed on macOS.
- `swift test -c release`: verified saved Debug overrides and incoming edits are ignored.
- iOS Debug: six native/WebKit integration tests and one actual slider-drag UI test passed.
- iOS Release: UI test verified the source defaults, no DialKit button, and no WKWebView.

The Debug test changed radius from 28 to 51 by dragging the rendered web control,
then verified that the native preview's radius label changed. Integration tests verified
nested values, actions through a rendered button, CSS colors, reset, editor recreation,
Unicode, validation, and opt-in persistence.

The Release UI command uses `ENABLE_TESTABILITY=YES` so the project's unit-test targets
can compile, and selects only `DialKitDemoUITests`. The package's separate Release test
also verifies the inactive editing path.

The demo is installed on the existing simulator. No simulator or runtime was created.
Physical iPhone installation and interaction are unverified. The SwiftUI timeline editor,
Xcode window integration, arbitrary view inspection, and automatic source rewriting are
not implemented. The supported workflow is to add bindings once, tune live, then apply
the exported values to source defaults.
