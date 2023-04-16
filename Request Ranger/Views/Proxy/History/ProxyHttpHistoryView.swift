import SwiftUI

struct ProxyHttpHistoryView: View {
    @State var selectedRequest: ProxiedHttpRequest.ID? = nil
    @State private var sortOrder = [KeyPathComparator(\ProxiedHttpRequest.id)]
    @ObservedObject var appState: AppState
    @State private var searchText = ""
    
    var historyView: some View {
        SelectableRequestTable(selectedRequest: $selectedRequest, appState: appState, searchText: $searchText)
    }
    
    var body: some View {
        VStack {
#if os(macOS)
            VSplitView {
                historyView
            }
#else
            historyView
#endif
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                let text = appState.isProxyRunning ? "Stop Proxy" : "Start Proxy"
                let systemImage = appState.isProxyRunning ? "pause" : "play"
                
                Button(action: {
                    NotificationCenter.default.post(name: .proxyRunCommand, object: !appState.isProxyRunning)
                }, label: {
                    Label(text, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                })
            }
            
            ToolbarItem {
                Button(action: {
                    appState.proxyData.httpRequests.removeAll()
                }, label: {
                    Label("Delete all", systemImage: "trash")
                })
                .searchable(text: $searchText, prompt: Text("Filter requests and responses"))
            }
        }
        .navigationTitle("HTTP History")
    }
}

struct ProxyHttpHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let response = ProxiedHttpResponse(
            rawResponse: """
HTTP/1.1 200 OK
Content-Type: image/gif
Content-Length: 307
Connection: close
Date: Mon, 10 Apr 2023 10:06:49 GMT
Server: Apache
Last-Modified: Wed, 03 Jan 2018 11:32:53 GMT
ETag: "133-561dd9372e340"
Accept-Ranges: bytes

GIF89a
""",
            headers: [
                "Content-Type": ["image/gif"],
                "Content-Length": ["307"],
                "Connection": ["close"],
                "Date": ["Mon, 10 Apr 2023 10:06:49 GMT"],
                "Server": ["Apache"],
                "Last-Modified": ["Wed, 03 Jan 2018 11:32:53 GMT"],
                "ETag": ["\"133-561dd9372e340\""],
                "Accept-Ranges": ["bytes"],
            ])
        
        let proxyRequest = ProxiedHttpRequest(
            id: 1,
            hostName: "example.com",
            method: HttpMethodEnum.GET,
            path: "/test",
            headers: [:],
            rawRequest: """
GET /images/mail.gif HTTP/1.1
Host: example.de
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: image/avif,image/webp,*/*
Accept-Language: en-US,en;q=0.5
Connection: close
Referer: http://example.de/
Pragma: no-cache
Cache-Control: no-cache
""",
            response: response
        )
        var proxyData = ProxyData()
        proxyData.httpRequests.append(proxyRequest)
        let appState = AppState()
        appState.proxyData = proxyData
        
        return ProxyHttpHistoryView(selectedRequest: 1, appState: appState)
    }
}
