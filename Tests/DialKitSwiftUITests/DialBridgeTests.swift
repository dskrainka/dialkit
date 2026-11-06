#if DEBUG
import XCTest
import WebKit
@testable import DialKitSwiftUI

final class DialBridgeTests: XCTestCase {
    @MainActor func testOfflineWebEditorUpdatesNativeValuesActionsColorsAndReset() async throws {
        var actions: [String] = []
        let panel = DialPanel("Card </script> ☀️", id: "bridge-test", controls: [
            "radius": .slider(24, min: 0, max: 64), "title": .text("Hello 👋"),
            "accent": .color("#a78bfa"), "visible": .toggle(true),
            "shadow": .folder(["blur": .slider(12, min: 0, max: 40)]),
            "transition": .spring(duration: 0.5, bounce: 0.2), "replay": .action("Replay")
        ], onAction: { actions.append($0) })
        let coordinator = DialEditorCoordinator(panel: panel)
        let web = DialEditorFactory.make(panel: panel, coordinator: coordinator)
        defer { coordinator.stop() }
        try await wait { coordinator.ready && panel.revision > 0 }
        XCTAssertNil(panel.editorError)
        XCTAssertEqual(panel.string("title"), "Hello 👋")
        _ = try await web.evaluateJavaScript("window.DialKitNative.setValue('radius', 48); window.DialKitNative.setValue('shadow.blur', 20); window.DialKitNative.setValue('accent', 'rgb(255, 0, 0)');")
        try await wait { panel.number("radius") == 48 && panel.number("shadow.blur") == 20 && panel.colors["accent"]?.first == 1 }
        XCTAssertEqual(panel.colors["accent"], [1, 0, 0, 1])
        // Click the real rendered action control, rather than posting a synthetic native message.
        _ = try await web.evaluateJavaScript("Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === 'Replay').click()")
        try await wait { actions == ["replay"] }
        _ = try await web.evaluateJavaScript("window.DialKitNative.reset()")
        try await wait { panel.number("radius") == 24 && panel.number("shadow.blur") == 12 }
        XCTAssertNil(panel.editorError)
    }

    @MainActor func testTeardownStopsBridgeAndNewEditorRestoresLiveValues() async throws {
        let panel = DialPanel("Lifecycle", id: "lifecycle", controls: ["radius": .slider(24, min: 0, max: 64)])
        let first = DialEditorCoordinator(panel: panel)
        var web: WKWebView? = DialEditorFactory.make(panel: panel, coordinator: first)
        try await wait { first.ready }
        _ = try await web?.evaluateJavaScript("window.DialKitNative.setValue('radius', 36)")
        try await wait { panel.number("radius") == 36 }
        first.stop()
        web = nil
        XCTAssertNil(first.webView)
        let second = DialEditorCoordinator(panel: panel)
        let next = DialEditorFactory.make(panel: panel, coordinator: second)
        defer { second.stop(); _ = next }
        try await wait { second.ready }
        let result = try await next.evaluateJavaScript("window.DialKitNative.getValues().radius") as? Double
        XCTAssertEqual(result, 36)
    }

    @MainActor private func wait(until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(20)
        while !condition() {
            if Date() > deadline { XCTFail("Timed out waiting for the native/WebKit bridge"); throw NSError(domain: "DialKitTests", code: 1) }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
#endif
