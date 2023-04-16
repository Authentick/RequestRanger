import SwiftUI
import OrderedCollections

struct SiteMapView: View {
    @EnvironmentObject var appState: AppState

#if os(macOS)
    typealias PlatformListStyle = DefaultListStyle
#else
    typealias PlatformListStyle = GroupedListStyle
#endif
    
    @State private var selectedRequestIds: [Int]?
    @State private var selectedRequestDetail: ProxiedHttpRequest.ID?
    @State private var selectedRequests: [ProxiedHttpRequest] = []
    @State private var selectedUrl: URL?
    @State private var sitemapNodes: [TreeNode] = []
    
    var body: some View {
        Group {
            if(sitemapNodes.isEmpty) {
                VStack(alignment: .center) {
                    Text("No requests detected.")
                        .font(.title)
                        .padding(.bottom, 8)
                    Text("Please run the proxy or import an existing project.")
                        .font(.body)
                }
                .navigationTitle("Sitemap")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                
#if os(iOS)
                NavigationStack{
                    siteMapList
                }
#else
                HSplitView {
                    siteMapList.frame(minWidth: 200, maxWidth: .infinity)
                    selectableRequestTable.frame(minWidth: 200, maxWidth: .infinity)
                }
#endif
            }
        }
        .onAppear() {
            let groupedPaths = Set(Dictionary(grouping: appState.proxyData.httpRequests, by: { $0.hostName })
                .flatMap { _, requests in
                    requests.compactMap { URL(string: "https://\($0.hostName)\($0.path)") }
                })
            
            sitemapNodes = urlsToTree(urls: groupedPaths)
        }
        .onChange(of: appState.proxyData.httpRequests) { _ in
            let groupedPaths = Set(Dictionary(grouping: appState.proxyData.httpRequests, by: { $0.hostName })
                .flatMap { _, requests in
                    requests.compactMap { URL(string: "https://\($0.hostName)\($0.path)") }
                })
            
            sitemapNodes = urlsToTree(urls: groupedPaths)
        }
    }
    
    private var siteMapList: some View {
        List {
            OutlineGroup(sitemapNodes, id: \.id, children: \.children) { item in
                let isSelected = (item.url == selectedUrl)
#if os(iOS)
                NavigationLink(
                    destination: SelectableRequestTableView(
                        selectedRequest: $selectedRequestDetail,
                        proxyData: proxyData,
                        filteredRequestIds: $selectedRequestIds
                    ).navigationTitle("Requests for " + item.name),
                    tag: item.url,
                    selection: $selectedUrl
                ) {
                    Text(item.name)
                }
#else
                Text(item.name)
                    .fontWeight(isSelected ? .bold : nil)
                    .background(isSelected ? Color.accentColor.opacity(0.5) : nil)
                    .onTapGesture {
                        selectedUrl = item.url
                        
                        selectedRequests = appState.proxyData.httpRequests.filter { request in
                            guard let requestUrl = URL(string: "https://\(request.hostName)\(request.path)") else {
                                return false
                            }
                            return requestUrl.absoluteString.hasPrefix(selectedUrl!.absoluteString)
                        }
                        selectedRequestIds = selectedRequests.map { $0.id }
                    }
#endif
            }
        }
#if os(iOS)
        .onChange(of: selectedUrl) { url in
            if let url = url {
                selectedRequests = appState.proxyData.httpRequests.filter { request in
                    guard let requestUrl = URL(string: "https://\(request.hostName)\(request.path)") else {
                        return false
                    }
                    return requestUrl.absoluteString.hasPrefix(url.absoluteString)
                }
                selectedRequestIds = selectedRequests.map { $0.id }
            }
        }
#endif
        .listStyle(PlatformListStyle())
        .navigationTitle("Sitemap")
    }
    
    struct SelectableRequestTableView: View, Hashable {
        @Binding var selectedRequest: ProxiedHttpRequest.ID?
        @EnvironmentObject var appState: AppState
        @Binding var filteredRequestIds: [Int]?
        
        var body: some View {
            SelectableRequestTable(
                selectedRequest: $selectedRequest,
                appState: appState,
                filteredRequestIds: $filteredRequestIds
            )
        }
        
        static func == (lhs: SelectableRequestTableView, rhs: SelectableRequestTableView) -> Bool {
            return lhs.selectedRequest == rhs.selectedRequest &&
            lhs.filteredRequestIds == rhs.filteredRequestIds
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(selectedRequest)
            hasher.combine(filteredRequestIds)
        }
    }
    
    
    private var selectableRequestTable: some View {
        SelectableRequestTable(
            selectedRequest: $selectedRequestDetail,
            appState: appState,
            filteredRequestIds: $selectedRequestIds
        )
    }
    
    class TreeNode: Identifiable, Hashable {
        var id: URL
        var name: String
        var url: URL
        var children: [TreeNode]?
        
        init(name: String, url: URL, children: [TreeNode]? = nil) {
            self.id = url
            self.name = name
            self.url = url
            self.children = children
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    func urlsToTree(urls: Set<URL>, separator: Character = "/") -> [TreeNode] {
        let rootNodesByDomain = urls
            .compactMap { $0.host }
            .sorted(by: <)
            .reduce(into: OrderedDictionary<String, TreeNode>()) { dict, host in
                if dict[host] == nil {
                    dict[host] = TreeNode(name: host, url: URL(string: "http://" + host)!)
                }
            }
        
        for url in urls {
            guard let host = url.host,
                  !url.path.isEmpty,
                  let rootNode = rootNodesByDomain[host] else {
                continue
            }
            
            var currentNode: TreeNode = rootNode
            let components = url.path.split(separator: separator)
            
            for component in components {
                if let existingNode = currentNode.children?.first(where: { $0.name == String(component) }) {
                    currentNode = existingNode
                } else {
                    let newNode = TreeNode(name: String(component), url: url)
                    currentNode.children = (currentNode.children ?? []) + [newNode]
                    currentNode.children = currentNode.children!.sorted(by: { $0.name < $1.name })
                    if currentNode.children!.count != 0 {
                        let parentUrl = newNode.url
                        let newUrl = parentUrl.deletingLastPathComponent()
                        currentNode.url = newUrl
                    }
                    currentNode = newNode
                }
            }
        }
        
        return Array(rootNodesByDomain.values)
    }
}

struct SiteMapView_Previews: PreviewProvider {
    static var previews: some View {
        var proxyData = ProxyData()
        
        let sampleRequests: [ProxiedHttpRequest] = [
            ProxiedHttpRequest(
                id: 1,
                hostName: "example.com",
                method: HttpMethodEnum.GET,
                path: "/",
                headers: [
                    "Host": ["example.com"],
                    "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0"],
                    "Accept": ["text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"],
                    "Accept-Language": ["en-US,en;q=0.5"],
                    "Connection": ["close"],
                    "Upgrade-Insecure-Requests": ["1"],
                    "Pragma": ["no-cache"],
                    "Cache-Control": ["no-cache"]
                ],
                rawRequest: """
GET / HTTP/1.1
Host: example.com
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Connection: close
Upgrade-Insecure-Requests: 1
Pragma: no-cache
Cache-Control: no-cache
""",
                response: ProxiedHttpResponse(
                    rawResponse: """
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Content-Length: 1234
Connection: close
""",
                    headers: [
                        "Content-Type": ["text/html; charset=UTF-8"],
                        "Content-Length": ["1234"],
                        "Connection": ["close"]
                    ]
                )
            ),
            ProxiedHttpRequest(
                id: 2,
                hostName: "example.com",
                method: HttpMethodEnum.GET,
                path: "/",
                headers: [
                    "Host": ["example.com"],
                    "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0"],
                    "Accept": ["text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"],
                    "Accept-Language": ["en-US,en;q=0.5"],
                    "Connection": ["close"],
                    "Upgrade-Insecure-Requests": ["1"],
                    "Pragma": ["no-cache"],
                    "Cache-Control": ["no-cache"]
                ],
                rawRequest: """
GET / HTTP/1.1
Host: example.com
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Connection: close
Upgrade-Insecure-Requests: 1
Pragma: no-cache
Cache-Control: no-cache
""",
                response: ProxiedHttpResponse(
                    rawResponse: """
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Content-Length: 1234
Connection: close
""",
                    headers: [
                        "Content-Type": ["text/html; charset=UTF-8"],
                        "Content-Length": ["1234"],
                        "Connection": ["close"]
                    ]
                )
            ),
            ProxiedHttpRequest(
                id: 3,
                hostName: "iana.org",
                method: HttpMethodEnum.POST,
                path: "/index.php",
                headers: [
                    "Host": ["iana.org"],
                    "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0"],
                    "Accept": ["application/json"],
                    "Content-Type": ["application/x-www-form-urlencoded"],
                    "Content-Length": ["32"],
                    "Connection": ["close"],
                ],
                rawRequest: """
POST /index.php HTTP/1.1
Host: iana.org
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: application/json
Content-Type: application/x-www-form-urlencoded
Content-Length: 32
Connection: close
""",
                response: ProxiedHttpResponse(
                    rawResponse: """
HTTP/1.1 201 Created
Content-Type: application/json
Content-Length: 45
Connection: close
""",
                    headers: [
                        "Content-Type": ["application/json"],
                        "Content-Length": ["45"],
                        "Connection": ["close"]
                    ]
                )
            )
        ]
        
        proxyData.httpRequests = sampleRequests
        let appState = AppState()
        appState.proxyData = proxyData
        
        return SiteMapView()
            .environmentObject(appState)
    }
}
