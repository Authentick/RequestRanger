import Foundation
import SwiftUI
import WebKit
import HttpParser

#if os(macOS)
struct SwiftUIWebView: NSViewRepresentable {
    @Binding var body: String?
    @Binding var requestUrl: String?

    func makeNSView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let body = self.body, let requestUrl = self.requestUrl {
            webView.loadHTMLString(body, baseURL: URL(string: requestUrl))
        }
    }
}
#else
struct SwiftUIWebView: UIViewRepresentable {
    @Binding var body: String?
    @Binding var requestUrl: String?

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let body = self.body, let requestUrl = self.requestUrl {
            webView.loadHTMLString(body, baseURL: URL(string: requestUrl))
        }
    }
}
#endif
