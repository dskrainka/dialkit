import SwiftUI

public extension View {
    /// Adds a collapsible editor below the app. The modifier is inert in Release builds.
    func dialKit(_ panel: DialPanel) -> some View {
        modifier(DialEditorModifier(panel: panel))
    }
}

private struct DialEditorModifier: ViewModifier {
    @ObservedObject var panel: DialPanel
    @State private var expanded = false

    func body(content: Content) -> some View {
        #if DEBUG
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button { expanded.toggle() } label: {
                        Label(expanded ? "Hide DialKit" : "Tune with DialKit", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("dialkit.toggle")
                    Spacer()
                    if expanded {
                        ShareLink(item: panel.handoff()) { Label("Export", systemImage: "square.and.arrow.up") }
                            .labelStyle(.iconOnly)
                    }
                }.padding(12)
                if let error = panel.editorError, expanded {
                    Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
                // Keep the editor alive while collapsed, so values and versions stay in sync.
                DialEditorWebView(panel: panel)
                    .id(ObjectIdentifier(panel))
                    .frame(height: expanded ? 300 : 0)
                    .clipped()
                    .accessibilityHidden(!expanded)
            }
            .background(.regularMaterial)
        }
        #else
        content
        #endif
    }
}

#if DEBUG
import WebKit
import Combine
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor enum DialEditorFactory {
    static func make(panel: DialPanel, coordinator: DialEditorCoordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Values are persisted by native UserDefaults, not a shared web origin.
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(coordinator, name: "dialkit")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.underPageBackgroundColor = .clear
        #if canImport(UIKit)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        #endif
        coordinator.webView = webView
        guard let url = Bundle.module.url(forResource: "editor", withExtension: "html", subdirectory: "WebAssets") else {
            panel.setError("DialKit resources are missing. Rebuild the Swift package.")
            return webView
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }
}

@MainActor final class DialEditorCoordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let panel: DialPanel
    weak var webView: WKWebView?
    var ready = false
    init(panel: DialPanel) { self.panel = panel }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            let payload: [String: Any] = ["name": panel.name, "id": panel.id,
                "config": DialControl.configuration(panel.controls), "values": panel.values, "order": panel.order]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
                let encoded = data.base64EncodedString()
                webView?.evaluateJavaScript("window.DialKitNative.initialize('\(encoded)')") { [weak self] _, error in
                    self?.ready = error == nil
                    self?.panel.setError(error.map { "DialKit could not start: \($0.localizedDescription)" })
                }
            } catch { panel.setError("DialKit configuration could not be encoded.") }
        case "values": panel.receiveValues(body)
        case "action": if let path = body["path"] as? String { panel.receiveAction(path) }
        case "copy":
            #if canImport(UIKit)
            UIPasteboard.general.string = panel.handoff()
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(panel.handoff(), forType: .string)
            #endif
        case "error": panel.setError("DialKit: \(body["message"] as? String ?? "Editor error")")
        default: break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // The editor loads only its bundled page. Links cannot turn the bridge into a browser.
        let expected = Bundle.module.url(forResource: "editor", withExtension: "html", subdirectory: "WebAssets")
        decisionHandler(navigationAction.request.url == expected ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        panel.setError("DialKit could not load: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        webView.reload()
    }

    func stop() {
        ready = false
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "dialkit")
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
    }
}

#if canImport(UIKit)
struct DialEditorWebView: UIViewRepresentable {
    let panel: DialPanel
    func makeCoordinator() -> DialEditorCoordinator { DialEditorCoordinator(panel: panel) }
    func makeUIView(context: Context) -> WKWebView { DialEditorFactory.make(panel: panel, coordinator: context.coordinator) }
    func updateUIView(_ webView: WKWebView, context: Context) {}
    static func dismantleUIView(_ webView: WKWebView, coordinator: DialEditorCoordinator) { coordinator.stop() }
}
#else
struct DialEditorWebView: NSViewRepresentable {
    let panel: DialPanel
    func makeCoordinator() -> DialEditorCoordinator { DialEditorCoordinator(panel: panel) }
    func makeNSView(context: Context) -> WKWebView { DialEditorFactory.make(panel: panel, coordinator: context.coordinator) }
    func updateNSView(_ webView: WKWebView, context: Context) {}
    static func dismantleNSView(_ webView: WKWebView, coordinator: DialEditorCoordinator) { coordinator.stop() }
}
#endif
#endif
