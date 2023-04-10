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
        let response = ProxiedHttpResponse()
        response.rawResponse = """
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
        
        let proxyRequest = ProxiedHttpRequest(
            id: 1,
            hostName: "example.com",
            method: HttpMethodEnum.GET,
            path: "/test",
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
        return ProxyHttpHistoryView(proxyData: proxyData)
    }
}
