import SwiftUI

struct ProxyHttpHistoryView: View {
    @State private var selectedRequest: ProxiedHttpRequest.ID? = nil
    @State private var sortOrder = [KeyPathComparator(\ProxiedHttpRequest.id)]
    @ObservedObject var proxyData: ProxyData
    @State private var searchText = ""
    
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
    
    var historyView: some View {
        return Group {
            Table(of: ProxiedHttpRequest.self, selection: $selectedRequest, sortOrder: $sortOrder) {
                TableColumn("Host", value: \.hostName)
                TableColumn("Method") { request in
                    Text(request.method.rawValue)
                }
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
            }.onChange(of: sortOrder) {
                proxyData.httpRequests.sort(using: $0)
            }
            
            TabView {
                let requestText = GetRequestText()
                
                TextEditor(text: Binding.constant(requestText))
                    .font(.body.monospaced())
                    .tabItem {
                        Label("Request", systemImage: "arrowshape.turn.up.right.fill")
                    }
                ProxyHttpResponseView(
                    httpRequest: proxyData.httpRequests.first(where: {$0.id == selectedRequest})
                )
                .font(.body.monospaced())
                .tabItem {
                    Label("Response", systemImage: "arrowshape.turn.up.left.fill")
                }
            }
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
            ToolbarItem {
                Button("Delete all", role: .destructive) {
                    proxyData.httpRequests.removeAll()
                }
                .searchable(text: $searchText)
            }
        }
        .navigationTitle("HTTP History")
    }
}

struct ProxyHttpHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let proxyRequest = ProxiedHttpRequest()
        proxyRequest.hostName = "example.com"
        proxyRequest.path = "/test"
        proxyRequest.rawRequest = """
GET /images/mail.gif HTTP/1.1
Host: example.de
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: image/avif,image/webp,*/*
Accept-Language: en-US,en;q=0.5
Connection: close
Referer: http://example.de/
Pragma: no-cache
Cache-Control: no-cache
"""
        proxyRequest.response = ProxiedHttpResponse()
        proxyRequest.response!.rawResponse = """
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
"""
        let proxyData = ProxyData()
        proxyData.httpRequests.append(proxyRequest)
        return ProxyHttpHistoryView(proxyData: proxyData)
    }
}
