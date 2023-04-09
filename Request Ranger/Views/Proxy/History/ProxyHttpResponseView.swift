import SwiftUI
import HttpParser

struct ProxyHttpResponseView: View {
    public var httpRequest: ProxiedHttpRequest?
    
    var body: some View {
        let responseText = httpRequest?.response?.rawResponse ?? ""
        var responseBody: String? = nil
        responseBody = (HttpParser()).parseResponse(responseText).body
        
        return TabView {
            TextEditor(text: Binding.constant(responseText))
                .font(.body.monospaced())
                .tabItem {
                    Label("Raw", systemImage: "text.append")
                }
            
            SwiftUIWebView(
                body: Binding.constant(responseBody),
                requestUrl: Binding.constant("http://" + (httpRequest?.hostName ?? "") + (httpRequest?.path ?? ""))
            )
            .tabItem {
                Label("Rendered", systemImage: "photo.on.rectangle")
            }
        }
    }
}

struct ProxyHttpResponseView_Previews: PreviewProvider {
    static var previews: some View {
        let httpRequest: ProxiedHttpRequest = ProxiedHttpRequest()
        return ProxyHttpResponseView(httpRequest: httpRequest)
    }
}
