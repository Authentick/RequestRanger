import SwiftUI

typealias proxyRequestAlias = (group: DispatchGroup, request: ProxiedHttpRequest)

struct ProxyInterceptEditorView: View {
    @Binding var text: String
    var request: proxyRequestAlias
    @Binding var requests: [proxyRequestAlias]
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .cornerRadius(4)
                .font(.body.monospaced())
            HStack {
                Button {
                    request.request.rawRequest = text
                    request.group.leave()
                    requests.removeFirst()
                } label: {
                    Label("Send", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
            }
        }.padding()
    }
}

struct ProxyInterceptEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ProxyInterceptEditorView(
            text: Binding.constant("""
GET /favicon.ico HTTP/1.1
Host: example.de
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Referer: http://example.de/
Connection: close
Upgrade-Insecure-Requests: 1
If-Modified-Since: Wed, 03 Jan 2018 11:37:57 GMT
If-None-Match: "d5f-561dda5918f40"


"""),
            request: (
                DispatchGroup(),
                ProxiedHttpRequest(
                    id: 1,
                    hostName: "example.com",
                    method: HttpMethodEnum.GET,
                    path: "/test",
                    rawRequest: "...",
                    response: nil
                )
            ),
            requests: Binding.constant([])
        )
    }
}


struct ProxyInterceptView: View {
    @State private var text: String = ""
    private let server = Server.sharedInstance
    @State private var isInterceptEnabled: Bool
    @State private var requests = [proxyRequestAlias]()  {
        didSet {
            if(requests.isEmpty) {
                text =  ""
            } else {
                text = requests.first!.request.rawRequest
            }
        }
    }
    
    init() {
        isInterceptEnabled = server.isInterceptEnabled
    }
    
    var body: some View {
        VStack {
            if let firstRequest = requests.first {
                ProxyInterceptEditorView(text: $text, request: firstRequest, requests: $requests)
            } else {
                Text("No intercepted request ")
            }
        }
        .toolbar {
            ToolbarItem {
                let interceptText = isInterceptEnabled ? "Stop Intercept" : "Start intercept"
                Button(interceptText) {
                    isInterceptEnabled = !isInterceptEnabled
                    self.server.isInterceptEnabled = isInterceptEnabled
                }
            }
        }
        .navigationTitle("Intercept HTTP request")
        .onReceive(NotificationCenter.default.publisher(for: .newAttemptedHttpRequest), perform: { obj in
            if let request = obj.object as? proxyRequestAlias {
                requests.append(request)
            }
        })
    }
}

struct ProxyInterceptView_Previews: PreviewProvider {
    static var previews: some View {
        ProxyInterceptView()
    }
}
