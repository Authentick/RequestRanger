import SwiftUI
import HttpParser
import Combine

struct SelectableRequestTable: View {
    @Binding var selectedRequest: ProxiedHttpRequest.ID?
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\ProxiedHttpRequest.id, order: .reverse)]
    @Binding var searchText: String
    @Binding var filteredRequestIds: [Int]?
    @State private var searchTextPublisher = PassthroughSubject<String, Never>()
    @State private var debouncedSearchText: String = ""
    private var cancellables = Set<AnyCancellable>()
    
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif
    
    init(selectedRequest: Binding<ProxiedHttpRequest.ID?>,
         searchText: Binding<String> = .constant(""),
         filteredRequestIds: Binding<[Int]?> = Binding.constant(nil)) {
        self._selectedRequest = selectedRequest
        self._searchText = searchText
        self._filteredRequestIds = filteredRequestIds
    }
    
    private var filteredRequests: [ProxiedHttpRequest] {
        let requests: [ProxiedHttpRequest]
        if let filteredIds = filteredRequestIds {
            requests = appState.proxyData.httpRequests.filter { request in
                filteredIds.contains(request.id)
            }
        } else {
            requests = appState.proxyData.httpRequests
        }
        
        let filteredAndSortedRequests = requests
            .filter { request in
                debouncedSearchText == "" || request.rawRequest.contains(debouncedSearchText) || (request.response != nil && request.response!.rawResponse.contains(debouncedSearchText))
            }
            .sorted(using: sortOrder)
        
        return filteredAndSortedRequests
    }
    
    private func GetSelectedRequest() -> ProxiedHttpRequest? {
        return filteredRequests.first(where: { $0.id == selectedRequest })
    }
    
    var body: some View {
        VStack {
            Table(of: ProxiedHttpRequest.self, selection: $selectedRequest, sortOrder: $sortOrder) {
                TableColumn("#", value: \.id) { element in
                    HStack {
                        Text(String(element.id))
                        if isCompact {
                            Text(element.path)
                        }
                    }
                }
                TableColumn("Host", value: \.hostName)
                TableColumn("Method", value: \.methodString)
                TableColumn("Path", value: \.path)
            } rows: {
                ForEach(filteredRequests) { request in
                    TableRow(request)
                        .contextMenu {
                            Button {
                                if let idx = appState.proxyData.httpRequests.firstIndex(where: {$0.id == request.id}) {
                                    if(selectedRequest == request.id) {
                                        selectedRequest = nil
                                    }
                                    appState.proxyData.httpRequests.remove(at: idx)
                                }
                            } label: {
                                Text("Delete")
                            }
                        }
                }
            }
            .onReceive(searchTextPublisher.debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)) { debouncedText in
                debouncedSearchText = debouncedText
            }
            .onChange(of: searchText) { newValue in
                searchTextPublisher.send(newValue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if GetSelectedRequest() != nil {
                ConditionalSplitView({
                    VStack {
                        if let selectedRequest = GetSelectedRequest() {
                            TabView {
                                RawRequestTextViewerView(text: Binding.constant(selectedRequest.rawRequest))
                                    .tabItem {
                                        Label("Raw", systemImage: "arrowshape.turn.up.right.fill")
                                    }
                                
                                HeadersView(headers: Binding.constant(selectedRequest.headers))
                                    .tabItem {
                                        Label("Headers", systemImage: "pencil")
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }, {
                    VStack {
                        if let selectedRequest = GetSelectedRequest(),
                           let response = selectedRequest.response {
                            TabView {
                                RawRequestTextViewerView(text: Binding.constant(response.rawResponse))
                                    .tabItem {
                                        Label("Raw", systemImage: "arrowshape.turn.up.right.fill")
                                    }
                                
                                HeadersView(headers: Binding.constant(response.headers))
                                    .tabItem {
                                        Label("Headers", systemImage: "pencil")
                                    }
                                
                                if let contentType = response.headers["content-type"],
                                   contentType.contains("text/html") {
                                    let responseBody = (HttpParser()).parseResponse(response.rawResponse).body
                                    
                                    SwiftUIWebView(
                                        body: Binding.constant(responseBody),
                                        requestUrl: Binding.constant("http://" + (selectedRequest.hostName) + (selectedRequest.path))
                                    )
                                    .tabItem {
                                        Label("HTML", systemImage: "photo.on.rectangle")
                                    }
                                }
                            }
                        } else {
                            VStack {
                                Text("No response received from remote server.")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct SelectableRequestTable_Previews: PreviewProvider {
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
        let appState = AppState.shared
        appState.proxyData = proxyData
        
        return SelectableRequestTable(
            selectedRequest: .constant(proxyRequest.id)
        ).environmentObject(appState)
    }
}

