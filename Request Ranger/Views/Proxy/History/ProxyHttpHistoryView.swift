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
        let proxyData = ProxyData()
        proxyData.httpRequests.append(proxyRequest)
        return ProxyHttpHistoryView(proxyData: proxyData)
    }
}
