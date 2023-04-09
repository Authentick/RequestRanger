import SwiftUI

extension Notification.Name {
    static let newHttpRequest = Notification.Name("new_http_request")
    static let newAttemptedHttpRequest = Notification.Name("new_attempted_http_request")
    static let proxyError = Notification.Name("proxy_connection_failure")
    static let proxyRunCommand = Notification.Name("proxy_run_command")
    static let cancelRequest = Notification.Name("cancel_request")
}

@main
struct SuperProxyApp: App {
    @StateObject var proxyData = ProxyData()
    @State var isProxyRunning = false
    @State var showProxyStartError: Bool = false
    @State var proxyStartErrorMessage: String? = nil
    @AppStorage("proxyPort") var proxyListenerPort: Int = AppStorageIntDefaults.proxyPort.rawValue
    let server: Server = Server.sharedInstance

    func startProxy() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try server.startListener(port: proxyListenerPort)
                isProxyRunning = true
            } catch {
                showProxyStartError = true
                proxyStartErrorMessage = error.localizedDescription
                isProxyRunning = false
            }
        }
    }
    
    func stopProxy() {
        server.stopListener()
        isProxyRunning = false
    }
    
    var body: some Scene {
        return Group {
            WindowGroup {
                ContentView(proxyData: proxyData, isProxyRunning: $isProxyRunning)
                    .onReceive(NotificationCenter.default.publisher(for: .newHttpRequest))
                { obj in
                    if let proxiedHttpRequest = obj.object as? ProxiedHttpRequest {
                        if(proxyData.httpRequests.contains(where: {$0.id == proxiedHttpRequest.id})) {
                            return
                        }
                        proxyData.httpRequests.append(proxiedHttpRequest)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .proxyRunCommand))
                { obj in
                    if let command = obj.object as? Bool {
                        if(command == true) {
                            startProxy()
                        } else {
                            stopProxy()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .proxyError))
                {
                    obj in
                    
                    if let errorMessage = obj.object as? Error {
                        proxyStartErrorMessage = errorMessage.localizedDescription
                        showProxyStartError = true
                    }
                    isProxyRunning = false
                }
                .alert(isPresented: $showProxyStartError) {
                    let errorMessageHeader = Text("You can change the proxy port in the application settings.\n\nThe error message was:\n\n")
                    var detailedErrorMessage: Text
                    
                    if(proxyStartErrorMessage == nil) {
                        detailedErrorMessage = Text("Could not determine error")
                    } else {
                        detailedErrorMessage = Text(proxyStartErrorMessage!)
                    }
                    
                    let combinedErrorMessage = errorMessageHeader + detailedErrorMessage
                    
                    
                    return Alert(title: Text("Could not start proxy server"), message: combinedErrorMessage, dismissButton: .default(Text("Ok")))
                }
            }
#if os(macOS)
            Settings {
                SettingsView()
            }
#endif
            
        }
    }
}
