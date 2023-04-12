import SwiftUI
import HttpParser

struct ProxyHttpHistoryView: View {
    @State var selectedRequest: ProxiedHttpRequest.ID? = nil
    @State private var sortOrder = [KeyPathComparator(\ProxiedHttpRequest.id)]
    @ObservedObject var proxyData: ProxyData
    @State private var searchText = ""
    @Binding var isProxyRunning: Bool
    
    func GetRequestText() -> String {
        if(selectedRequest != nil) {
            guard let request = proxyData.httpRequests.first(where: {$0.id == selectedRequest}) else {
                return ""
            }
            
            return request.rawRequest
        }
        
        return ""
    }
    
    func GetResponseText() -> String {
        if(selectedRequest != nil) {
            guard let requestBody = proxyData.httpRequests.first(where: {$0.id == selectedRequest})?.response?.rawResponse else {
                return ""
            }
            
            return requestBody
        }
        
        return ""
    }
    
    private func GetResponseBody(request: ProxiedHttpRequest?) -> String {
        let responseBody: String = request?.response?.rawResponse ?? ""
        return (HttpParser()).parseResponse(responseBody).body
    }
    
    var historyView: some View {
        return Group {
            Table(of: ProxiedHttpRequest.self, selection: $selectedRequest, sortOrder: $sortOrder) {
                TableColumn("#", value: \.idString)
                TableColumn("Host", value: \.hostName)
                TableColumn("Method", value: \.methodString)
                TableColumn("Path", value: \.path)
            } rows: {
                ForEach(proxyData.httpRequests) { request in
                    if(searchText == "" || (request.rawRequest.contains(searchText) || (request.response != nil && request.response!.rawResponse.contains(searchText)))) {
                        TableRow(request)
                            .contextMenu {
                                Button {
                                    if let idx = proxyData.httpRequests.firstIndex(where: {$0.id == request.id}) {
                                        if(selectedRequest == request.id) {
                                            selectedRequest = nil
                                        }
                                        proxyData.httpRequests.remove(at: idx)
                                    }
                                } label: {
                                    Text("Delete")
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: sortOrder) {
                proxyData.httpRequests.sort(using: $0)
            }
            
            ConditionalSplitView({
                VStack {
                    TabView {
                        let requestText = GetRequestText()
                        
                        RawRequestTextViewerView(text: Binding.constant(requestText))
                            .tabItem {
                                Label("Raw", systemImage: "arrowshape.turn.up.right.fill")
                            }
                        
                        let headers = Binding.constant(proxyData.httpRequests.first(where: { $0.id == selectedRequest })?.headers ?? [:])
                        HeadersView(headers: headers)
                            .tabItem {
                                Label("Headers", systemImage: "pencil")
                            }
                    }
                }},{
                    VStack {
                        TabView {
                            let selectedElement = proxyData.httpRequests.first(where: {$0.id == selectedRequest})
                            RawRequestTextViewerView(text: Binding.constant(selectedElement?.response?.rawResponse ?? ""))
                                .tabItem {
                                    Label("Raw", systemImage: "arrowshape.turn.up.right.fill")
                                }
                            
                            if let response = selectedElement?.response {
                                let headers = Binding.constant(response.headers)
                                HeadersView(headers: headers)
                                    .tabItem {
                                        Label("Headers", systemImage: "pencil")
                                    }
                            }
                            
                            if let response = selectedElement?.response {
                                let contentType = response.headers["content-type"]
                                if(contentType != nil && contentType!.contains("text/html")) {
                                    var responseBody: String = GetResponseBody(request: selectedElement)
                                    
                                    SwiftUIWebView(
                                        body: Binding.constant(responseBody),
                                        requestUrl: Binding.constant("http://" + (selectedElement?.hostName ?? "") + (selectedElement?.path ?? ""))
                                    )
                                    .tabItem {
                                        Label("HTML", systemImage: "photo.on.rectangle")
                                    }
                                }
                            }
                            
                            
                        }
                    }}
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                let text = isProxyRunning ? "Stop Proxy" : "Start Proxy"
                let systemImage = isProxyRunning ? "pause" : "play"
                
                Button(action: {
                    NotificationCenter.default.post(name: .proxyRunCommand, object: !isProxyRunning)
                }, label: {
                    Label(text, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                })
            }
            
            ToolbarItem {
                Button(action: {
                    proxyData.httpRequests.removeAll()
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
        let proxyData = ProxyData()
        proxyData.httpRequests.append(proxyRequest)
        return ProxyHttpHistoryView(selectedRequest: 1, proxyData: proxyData, isProxyRunning: Binding.constant(false))
    }
}
