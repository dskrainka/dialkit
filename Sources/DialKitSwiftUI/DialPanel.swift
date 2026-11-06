import SwiftUI
import Combine

/// Own this object with @StateObject and read it from the SwiftUI view being tuned.
@MainActor public final class DialPanel: ObservableObject {
    public let name: String
    public let id: String
    public let controls: [String: DialControl]
    public let order: [String]
    @Published public private(set) var revision = 0
    @Published public private(set) var editorError: String?
    var values: [String: Any]
    var colors: [String: [Double]] = [:]
    var onAction: ((String) -> Void)?
    let persist: Bool
    private let storage: UserDefaults
    private var storageKey: String { "dialkit.swiftui.\(id)" }

    public init(_ name: String, id: String, controls: [String: DialControl], order: [String] = [], persist: Bool = false,
                storage: UserDefaults = .standard, onAction: ((String) -> Void)? = nil) {
        self.name = name
        self.id = id
        self.controls = controls
        precondition(Set(order).count == order.count && order.allSatisfy { controls[$0] != nil }, "Order must contain distinct control keys")
        self.order = order
        self.persist = persist
        self.storage = storage
        self.onAction = onAction
        _ = DialControl.configuration(controls)
        values = controls.compactMapValues(\.initialValue)
        #if DEBUG
        if persist, let saved = storage.data(forKey: "dialkit.swiftui.\(id)"),
           let envelope = try? JSONSerialization.jsonObject(with: saved) as? [String: Any] {
            receiveValues(envelope)
        }
        #endif
    }

    public func number(_ path: String) -> Double { value(at: path) as? Double ?? 0 }
    public func bool(_ path: String) -> Bool { value(at: path) as? Bool ?? false }
    public func string(_ path: String) -> String { value(at: path) as? String ?? "" }
    public func point(_ path: String) -> CGPoint {
        let value = value(at: path) as? [String: Double] ?? [:]
        return CGPoint(x: value["x"] ?? 0, y: value["y"] ?? 0)
    }

    /// All CSS color formats supported by WebKit become sRGB for SwiftUI.
    public func color(_ path: String) -> Color {
        if let rgba = colors[path], rgba.count == 4 {
            return Color(.sRGB, red: rgba[0], green: rgba[1], blue: rgba[2], opacity: rgba[3])
        }
        // Defaults are available before the editor loads. Use hex for native defaults.
        let hex = string(path).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let expanded = (hex.count == 3 || hex.count == 4) ? hex.map { "\($0)\($0)" }.joined() : hex
        guard (expanded.count == 6 || expanded.count == 8), let n = UInt64(expanded, radix: 16) else { return .accentColor }
        let alpha = expanded.count == 8 ? Double(n & 255) / 255 : 1
        let rgb = expanded.count == 8 ? n >> 8 : n
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, opacity: alpha)
    }

    public func animation(_ path: String) -> Animation {
        let v = value(at: path) as? [String: Any] ?? [:]
        if v["type"] as? String == "easing", let ease = v["ease"] as? [Double], ease.count == 4 {
            return .timingCurve(ease[0], ease[1], ease[2], ease[3], duration: v["duration"] as? Double ?? 0.3)
        }
        if let stiffness = v["stiffness"] as? Double {
            return .interpolatingSpring(mass: v["mass"] as? Double ?? 1, stiffness: stiffness, damping: v["damping"] as? Double ?? 10, initialVelocity: 0)
        }
        return .spring(duration: v["visualDuration"] as? Double ?? 0.5, bounce: v["bounce"] as? Double ?? 0.2)
    }

    public func json() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    public func handoff() -> String {
        "Update the defaults in the SwiftUI DialPanel named \(name.debugDescription) (id: \(id.debugDescription)) with these values. Keep the existing controls, ranges, and bindings. Values use nested paths. Map visualDuration/bounce to SwiftUI spring(duration:bounce:); map physics springs to interpolatingSpring. Preview live values do not edit source files.\n\n```json\n\(json())\n```"
    }

    func value(at path: String) -> Any? {
        var result: Any = values
        for key in path.split(separator: ".") { guard let next = (result as? [String: Any])?[String(key)] else { return nil }; result = next }
        return result
    }

    func receiveValues(_ envelope: [String: Any]) {
        #if DEBUG
        guard let incoming = envelope["values"] as? [String: Any] else { return }
        func merge(_ config: [String: DialControl], _ input: [String: Any], _ current: [String: Any]) -> [String: Any] {
            var result = current
            for (key, control) in config {
                guard let candidate = input[key] else { continue }
                if case let .folder(children) = control, let child = candidate as? [String: Any] {
                    result[key] = merge(children, child, current[key] as? [String: Any] ?? [:])
                } else if control.accepts(candidate) { result[key] = candidate }
            }
            return result
        }
        values = merge(controls, incoming, values)
        if let cssColors = envelope["colors"] as? [String: [Double]] {
            colors = cssColors.filter { $0.value.count == 4 && $0.value.allSatisfy { $0.isFinite && (0...1).contains($0) } }
        }
        revision += 1
        if persist, let data = try? JSONSerialization.data(withJSONObject: ["values": values, "colors": colors]) { storage.set(data, forKey: storageKey) }
        #endif
    }

    func receiveAction(_ path: String) {
        #if DEBUG
        var config = controls
        let keys = path.split(separator: ".").map(String.init)
        for (index, key) in keys.enumerated() {
            guard let control = config[key] else { return }
            if index == keys.count - 1, case .action = control { onAction?(path); return }
            guard case let .folder(children) = control else { return }
            config = children
        }
        #endif
    }

    func setError(_ error: String?) { editorError = error }
}
