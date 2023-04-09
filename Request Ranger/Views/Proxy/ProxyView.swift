import SwiftUI

struct ProxyView: View {
    @ObservedObject var proxyData: ProxyData
    @Binding var isProxyRunning: Bool
    
    enum NavigationMenus {
        case History
        case Intercept
    }
    
    var body: some View {
        return NavigationStack() {
            List {
                NavigationLink(value: NavigationMenus.History) {
                    Label {
                        Text("HTTP history\n")
                        +
                        Text("Record and analyze HTTP requests and responses.").fontWeight(.light)

                    } icon: {
                        Image(systemName: "network")
                    }
                }
                NavigationLink(value: NavigationMenus.Intercept) {
                    Label {
                        Text("Intercept HTTP request\n")
                        +
                        Text("Intercept and edit HTTP requests before they are sent to the remote server").fontWeight(.light)

                    } icon: {
                        Image(systemName: "pause.circle")
                    }
                }
            }
            .navigationDestination(for: NavigationMenus.self) { selection in
                switch selection {
                case .History:
                    ProxyHttpHistoryView(proxyData: proxyData)
                case .Intercept:
                    ProxyInterceptView()
                }
            }
        }
        .toolbar{
            ToolbarItem(placement: .primaryAction) {
                let text = isProxyRunning ? "Stop Proxy" : "Start Proxy"
                Button(text) {
                    NotificationCenter.default.post(name: .proxyRunCommand, object: !isProxyRunning)
                }
            }
        }
        .navigationTitle("Proxy")
    }
}

struct ProxyView_Previews: PreviewProvider {
    static var previews: some View {
        ProxyView(proxyData: ProxyData(), isProxyRunning: Binding.constant(false))
    }
}
