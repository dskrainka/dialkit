import Foundation

/// Native definitions for DialKit's existing web controls. Keys must not contain dots.
public indirect enum DialControl {
    case slider(Double, min: Double, max: Double, step: Double = 1)
    case toggle(Bool)
    case text(String)
    case color(String)
    case select([String], selected: String)
    case image([String], selected: String = "")
    case pad(x: Double, y: Double, xRange: ClosedRange<Double>, yRange: ClosedRange<Double>, step: Double = 0.01)
    case spring(duration: Double, bounce: Double)
    case physics(stiffness: Double, damping: Double, mass: Double = 1)
    case easing(duration: Double, x1: Double, y1: Double, x2: Double, y2: Double)
    case action(String)
    case folder([String: DialControl])

    var config: Any {
        switch self {
        case let .slider(value, min, max, step):
            precondition(value.isFinite && min.isFinite && max.isFinite && step.isFinite && min <= value && value <= max && min < max && step > 0, "Invalid slider range or step")
            return [value, min, max, step]
        case let .toggle(value): return value
        case let .text(value): return ["type": "text", "default": value]
        case let .color(value): return ["type": "color", "default": value]
        case let .select(options, selected):
            precondition(options.contains(selected), "Select default must be an option")
            return ["type": "select", "options": options, "default": selected]
        case let .image(options, selected): return ["type": "image", "options": options, "default": selected]
        case let .pad(x, y, xr, yr, step):
            return ["type": "pad", "x": [x, xr.lowerBound, xr.upperBound, step], "y": [y, yr.lowerBound, yr.upperBound, step]]
        case let .spring(duration, bounce): return ["type": "spring", "visualDuration": duration, "bounce": bounce]
        case let .physics(stiffness, damping, mass): return ["type": "spring", "stiffness": stiffness, "damping": damping, "mass": mass]
        case let .easing(duration, x1, y1, x2, y2): return ["type": "easing", "duration": duration, "ease": [x1, y1, x2, y2]]
        case let .action(label): return ["type": "action", "label": label]
        case let .folder(children): return Self.configuration(children)
        }
    }

    var initialValue: Any? {
        switch self {
        case let .slider(value, _, _, _): return value
        case let .toggle(value): return value
        case let .text(value), let .color(value): return value
        case let .select(_, value), let .image(_, value): return value
        case let .pad(x, y, _, _, _): return ["x": x, "y": y]
        case .spring, .physics, .easing: return config
        case .action: return nil
        case let .folder(children): return children.compactMapValues(\.initialValue)
        }
    }

    static func configuration(_ controls: [String: DialControl]) -> [String: Any] {
        precondition(controls.keys.allSatisfy { !$0.isEmpty && !$0.contains(".") && !$0.hasPrefix("_") && !["__proto__", "constructor", "prototype"].contains($0) }, "Use nonempty control keys without dots or reserved names")
        return controls.mapValues(\.config)
    }

    func accepts(_ value: Any) -> Bool {
        switch self {
        case let .slider(_, min, max, _):
            guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return false }
            return n.doubleValue.isFinite && (min...max).contains(n.doubleValue)
        case .toggle:
            guard let n = value as? NSNumber else { return false }
            return CFGetTypeID(n) == CFBooleanGetTypeID()
        case .text, .color, .image: return value is String
        case let .select(options, _): return (value as? String).map(options.contains) ?? false
        case let .pad(_, _, xr, yr, _):
            guard let v = value as? [String: Double], let x = v["x"], let y = v["y"] else { return false }
            return x.isFinite && y.isFinite && xr.contains(x) && yr.contains(y)
        case .spring, .physics, .easing:
            guard let v = value as? [String: Any], let type = v["type"] as? String else { return false }
            if type == "easing" {
                guard let duration = v["duration"] as? Double, let ease = v["ease"] as? [Double] else { return false }
                return duration.isFinite && duration >= 0 && ease.count == 4 && ease.allSatisfy(\.isFinite) && (0...1).contains(ease[0]) && (0...1).contains(ease[2])
            }
            guard type == "spring" else { return false }
            for key in ["stiffness", "damping", "mass", "visualDuration", "bounce"] {
                if let value = v[key] {
                    guard let n = value as? Double, n.isFinite else { return false }
                    if key == "bounce" { if !(-1...1).contains(n) { return false } }
                    else if n <= 0 { return false }
                }
            }
            return v["visualDuration"] != nil || v["stiffness"] != nil
        case .action, .folder: return false
        }
    }
}

import CoreFoundation
