# DialKit for SwiftUI in Device Hub

This fork connects DialKit's original vanilla editor to a native SwiftUI observable model.
The editor runs offline in a bundled WKWebView. The preview remains a real SwiftUI view.
Requires iOS 17+ or macOS 14+. Device Hub is Xcode's app for running simulators and viewing devices;
this is an app integration, not a plug-in for Xcode's window.

## Add it to an app

In Xcode, choose **File > Add Package Dependencies** and enter
`https://github.com/dskrainka/dialkit`. Select the `feature/swiftui-device-hub` branch.
Add the **DialKitSwiftUI** product to the app target.
For local development, add the repository folder as a local Swift package instead.

```swift
import SwiftUI
import DialKitSwiftUI

struct CardPrototype: View {
    @StateObject private var dial = DialPanel("Card", id: "card", controls: [
        "radius": .slider(24, min: 0, max: 64),
        "padding": .slider(20, min: 0, max: 40),
        "accent": .color("#a78bfa"),
        "title": .text("Make room to play."),
        "details": .toggle(true),
        "motion": .spring(duration: 0.5, bounce: 0.2),
        "shadow": .folder(["blur": .slider(12, min: 0, max: 40)])
    ])

    var body: some View {
        VStack {
            Text(dial.string("title"))
            if dial.bool("details") { Text("A native SwiftUI prototype") }
        }
        .padding(dial.number("padding"))
        .background(dial.color("accent"), in: RoundedRectangle(cornerRadius: dial.number("radius")))
        .shadow(radius: dial.number("shadow.blur"))
        .dialKit(dial)
    }
}
```

Run the Debug scheme on your chosen simulator in Device Hub. Tap **Tune with DialKit**.
The controls open below the preview. Collapse the panel to use the full app again.
The editor starts while collapsed, so all supported CSS color formats resolve before opening it.
Use hex color defaults for predictable native defaults in Release builds too.

Only properties wired to the panel can change. This package does not inspect or rewrite arbitrary
SwiftUI views, inject into installed apps, or modify source files while you drag.
Keep the `@StateObject` in the view reading the values; pass it to child views with `@ObservedObject`.
Use one `.dialKit` modifier per screen. Give each panel a stable, distinct ID.
Controls appear in alphabetical order by default. Pass `order: ["radius", "padding", "accent"]`
after `controls` to choose which controls appear first; remaining controls follow alphabetically.

## Controls and native accessors

| Control | Definition | Read in SwiftUI |
| --- | --- | --- |
| Slider | `.slider(24, min: 0, max: 64, step: 1)` | `dial.number("radius")` |
| Toggle | `.toggle(true)` | `dial.bool("visible")` |
| Text | `.text("Hello")` | `dial.string("title")` |
| Color | `.color("#a78bfa")` | `dial.color("accent")` |
| Select | `.select(["stack", "grid"], selected: "stack")` | `dial.string("layout")` |
| Image | `.image(["https://example.com/photo.png"])` | `dial.string("image")` |
| Pad | `.pad(x: 0, y: 0, xRange: -100...100, yRange: -100...100)` | `dial.point("position")` |
| Spring | `.spring(duration: 0.5, bounce: 0.2)` | `dial.animation("motion")` |
| Physics | `.physics(stiffness: 100, damping: 10)` | `dial.animation("motion")` |
| Easing | `.easing(duration: 0.4, x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)` | `dial.animation("motion")` |
| Action | `.action("Replay")` | initializer `onAction: { path in ... }` |
| Folder | `.folder(["blur": .slider(12, min: 0, max: 40)])` | `dial.number("shadow.blur")` |

Use `withAnimation(dial.animation("motion")) { ... }` to test an animation.
Spring duration/bounce maps to SwiftUI's spring; physics maps to `interpolatingSpring`.
The Motion and SwiftUI engines can feel slightly different. The timeline editor is not ported.
Color edits convert through WebKit into sRGB; wide-gamut colors are reduced to sRGB.
Image controls return a URL or data URL; the app must load/decode it. Image downloads need a network.

Control keys must be nonempty and cannot contain dots or reserved names.
Missing or mistyped accessor paths return `0`, `false`, or an empty string. Use exact paths.

## Versions, saving, and applying changes

DialKit's version menu compares value sets during a tuning session. The web panel stays alive
when collapsed. Its versions are discarded when the screen/editor is destroyed or the app quits.
Set `persist: true` on `DialPanel` to save the current values in the app's native UserDefaults
and restore them on the next Debug launch. Persistence is off by default. Each app has its own storage.
Reset in the editor restores the source defaults. Persistence never writes your Swift files.

Tap **Export** to share a source handoff, or the panel's Copy button to copy it. The handoff
names the native panel and includes the current JSON values. Give it to your coding agent to
apply those values as new defaults in the Swift source. Review the resulting source changes.
You can also read `dial.json()` or `dial.handoff()` yourself.

The modifier, WKWebView bridge, incoming edits, and saved overrides are disabled when `DEBUG`
is absent. Release builds read the source defaults, so apply any wanted tuned values before shipping.
Resources still belong to the package bundle; no editor or transport starts in Release.
The local file bridge blocks navigation and does not open a network listener.

## Run the included demo

Open `examples/swiftui/DialKitDemo.xcodeproj`, select **DialKitDemo**, choose an iPhone simulator,
then Run. No signing team is needed for a simulator.
For a physical iPhone, enable signing and choose your own development team. Physical-device
installation and interaction have not been verified in this change.

The checked-in Xcode project is generated from `examples/swiftui/project.yml` with XcodeGen.
To regenerate it: `cd examples/swiftui && xcodegen generate`.

## Develop and verify

```sh
npm ci
npm test
npm run typecheck
npm run build
node scripts/build-swiftui-resources.mjs
swift test
swift build -c release
xcodebuild -project examples/swiftui/DialKitDemo.xcodeproj -scheme DialKitDemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

The Swift package has no external dependencies. Its bundled JS/CSS are generated from this
repository, retain the upstream MIT license, and must be committed after changing web controls.
Integration tests load the actual offline editor, change values through DialKit, click its real
action button, and verify native values, CSS color conversion, reset, Unicode, and editor recreation.
