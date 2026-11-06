import XCTest
@testable import DialKitSwiftUI

final class DialPanelTests: XCTestCase {
    #if DEBUG
    @MainActor func testNestedUpdatesRejectWrongTypesUnknownKeysAndOutOfRangeValues() {
        let panel = DialPanel("Card", id: "test", controls: [
            "radius": .slider(24, min: 0, max: 64), "visible": .toggle(true),
            "card": .folder(["title": .text("Hello")]),
            "layout": .select(["stack", "grid"], selected: "stack")
        ])
        panel.receiveValues(["values": ["radius": 40.0, "visible": false, "card": ["title": "New"], "unknown": 9]])
        XCTAssertEqual(panel.number("radius"), 40)
        XCTAssertFalse(panel.bool("visible"))
        XCTAssertEqual(panel.string("card.title"), "New")
        XCTAssertNil(panel.value(at: "unknown"))
        panel.receiveValues(["values": ["radius": true, "visible": 1, "layout": "unknown"]])
        XCTAssertEqual(panel.number("radius"), 40)
        XCTAssertFalse(panel.bool("visible"))
        XCTAssertEqual(panel.string("layout"), "stack")
        panel.receiveValues(["values": ["radius": 1000.0]])
        XCTAssertEqual(panel.number("radius"), 40)
    }

    @MainActor func testOnlyDeclaredActionsFire() {
        var actions: [String] = []
        let panel = DialPanel("Actions", id: "actions", controls: ["motion": .folder(["replay": .action("Replay")]), "title": .text("A")], onAction: { actions.append($0) })
        panel.receiveAction("motion.replay")
        panel.receiveAction("missing")
        panel.receiveAction("title")
        XCTAssertEqual(actions, ["motion.replay"])
    }

    @MainActor func testPersistenceIsOptInAndDefaultsRemainUntouched() {
        let suite = "dialkit-test-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let config: [String: DialControl] = ["radius": .slider(24, min: 0, max: 64)]
        let first = DialPanel("Card", id: "card", controls: config, persist: true, storage: storage)
        first.receiveValues(["values": ["radius": 48.0]])
        let restored = DialPanel("Card", id: "card", controls: config, persist: true, storage: storage)
        XCTAssertEqual(restored.number("radius"), 48)
        let defaults = DialPanel("Card", id: "card", controls: config, storage: storage)
        XCTAssertEqual(defaults.number("radius"), 24)
        XCTAssertTrue(restored.handoff().contains("SwiftUI DialPanel"))
        XCTAssertTrue(restored.json().contains("48"))
    }

    @MainActor func testRejectsInvalidTransitionsAndAcceptsModeSwitch() {
        let panel = DialPanel("Motion", id: "motion", controls: ["transition": .spring(duration: 0.5, bounce: 0.2)])
        panel.receiveValues(["values": ["transition": ["type": "spring", "mass": 0, "stiffness": -1]]])
        XCTAssertEqual((panel.value(at: "transition") as? [String: Any])?["visualDuration"] as? Double, 0.5)
        panel.receiveValues(["values": ["transition": ["type": "easing", "duration": 0.4, "ease": [0.25, 0.1, 0.25, 1.0]]]])
        XCTAssertEqual((panel.value(at: "transition") as? [String: Any])?["type"] as? String, "easing")
    }
    #else
    @MainActor func testReleaseIgnoresEditsAndSavedDebugOverrides() throws {
        let suite = "dialkit-release-test-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        storage.set(try JSONSerialization.data(withJSONObject: ["values": ["radius": 60]]), forKey: "dialkit.swiftui.card")
        var actionFired = false
        let panel = DialPanel("Card", id: "card", controls: ["radius": .slider(24, min: 0, max: 64), "replay": .action("Replay")], persist: true, storage: storage, onAction: { _ in actionFired = true })
        panel.receiveValues(["values": ["radius": 48]])
        panel.receiveAction("replay")
        XCTAssertEqual(panel.number("radius"), 24)
        XCTAssertFalse(actionFired)
        XCTAssertEqual(panel.revision, 0)
    }
    #endif
}
