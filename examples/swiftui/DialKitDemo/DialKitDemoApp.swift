import SwiftUI
import DialKitSwiftUI

@main struct DialKitDemoApp: App {
    var body: some Scene { WindowGroup { CardPrototype() } }
}

struct CardPrototype: View {
    @StateObject private var dial = DialPanel("Card", id: "swiftui-demo-card", controls: [
        "radius": .slider(28, min: 0, max: 64),
        "padding": .slider(24, min: 8, max: 40),
        "accent": .color("#a78bfa"),
        "title": .text("Make room to play."),
        "showDetail": .toggle(true),
        "layout": .select(["leading", "center"], selected: "leading"),
        "motion": .spring(duration: 0.5, bounce: 0.2),
        "shadow": .folder(["blur": .slider(16, min: 0, max: 40), "opacity": .slider(0.2, min: 0, max: 0.6, step: 0.01)])
    ], order: ["radius", "padding", "accent", "title", "showDetail", "layout", "motion", "shadow"])
    @State private var raised = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SWIFTUI × DIALKIT").font(.caption.monospaced()).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            VStack(alignment: dial.string("layout") == "center" ? .center : .leading, spacing: 12) {
                Image(systemName: "sparkles").font(.largeTitle)
                Text(dial.string("title")).font(.system(size: 30, weight: .semibold, design: .rounded))
                if dial.bool("showDetail") {
                    Text("Tune the card below. Every change updates this native SwiftUI view.")
                        .font(.subheadline).foregroundStyle(.black.opacity(0.65))
                }
                Button(raised ? "Bring it back" : "Try the spring") {
                    withAnimation(dial.animation("motion")) { raised.toggle() }
                }.buttonStyle(.borderedProminent).tint(.black).foregroundStyle(.white)
            }
            .padding(dial.number("padding"))
            .frame(maxWidth: .infinity, alignment: dial.string("layout") == "center" ? .center : .leading)
            .foregroundStyle(.black)
            .background(dial.color("accent"), in: RoundedRectangle(cornerRadius: dial.number("radius")))
            .shadow(color: .black.opacity(dial.number("shadow.opacity")), radius: dial.number("shadow.blur"), y: 8)
            .offset(y: raised ? -20 : 0)
            .accessibilityIdentifier("dialkit.preview")
            Text("Radius \(Int(dial.number("radius"))) · Padding \(Int(dial.number("padding")))")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Color(white: 0.96))
        .dialKit(dial)
    }
}
