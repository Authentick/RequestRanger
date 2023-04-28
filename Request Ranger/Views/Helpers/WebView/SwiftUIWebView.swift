import Foundation
import SwiftUI
import WebKit
import HttpParser

#if os(macOS)
struct SwiftUIWebView: NSViewRepresentable {
    @Binding var body: String?
    @Binding var requestUrl: String?
    @State private var isLoading = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // Disable default background drawing
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let body = self.body, let requestUrl = self.requestUrl {
            webView.loadHTMLString(body, baseURL: URL(string: requestUrl))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SwiftUIWebView

        init(_ parent: SwiftUIWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}
#else
struct SwiftUIWebView: UIViewRepresentable {
    @Binding var body: String?
    @Binding var requestUrl: String?
    @State private var isLoading = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.clear // Set background color to clear
        webView.scrollView.backgroundColor = UIColor.clear // Set scrollView background color to clear
        webView.isOpaque = false // Make the WebView transparent
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let body = self.body, let requestUrl = self.requestUrl {
            webView.loadHTMLString(body, baseURL: URL(string: requestUrl))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SwiftUIWebView

        init(_ parent: SwiftUIWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}
#endif
