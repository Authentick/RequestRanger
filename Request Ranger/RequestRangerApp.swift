import SwiftUI
import UniformTypeIdentifiers
import AppleArchive
import System

extension Notification.Name {
    static let newHttpRequest = Notification.Name("new_http_request")
    static let newAttemptedHttpRequest = Notification.Name("new_attempted_http_request")
    static let proxyError = Notification.Name("proxy_connection_failure")
    static let proxyRunCommand = Notification.Name("proxy_run_command")
    static let cancelRequest = Notification.Name("cancel_request")
}

@main
struct RequestRangerApp: App {
    @StateObject var proxyData = ProxyData()
    @StateObject var comparisonListData = ComparisonData()
    @State var isProxyRunning = false
    @State var showProxyStartError: Bool = false
    @State var proxyStartErrorMessage: String? = nil
    @AppStorage("proxyPort") var proxyListenerPort: Int = AppStorageIntDefaults.proxyPort.rawValue
    let server: Server = Server.sharedInstance
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showImportAlert: Bool = false
    @State private var selectedFileURL: URL?
    
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
    
    private func handleFileSelection(url: URL) {
        selectedFileURL = url
        showImportAlert = true
    }
    
    var body: some Scene {
        let utType = RequestRangerFile.readableContentTypes.first!
        
        return Group {
            WindowGroup {
                ContentView(
                    proxyData: proxyData,
                    isProxyRunning: $isProxyRunning,
                    showingExporter: $showingExporter,
                    showingImporter: $showingImporter
                )
                .environmentObject(comparisonListData)
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
                .onOpenURL { url in
                    selectedFileURL = url
                    showImportAlert = true
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
                .alert(isPresented: $showImportAlert) {
                    Alert(
                        title: Text("Confirm opening project \"\(selectedFileURL!.lastPathComponent)\""),
                        message: Text("Your currently open project will be closed. Save it first to avoid any data loss."),
                        primaryButton: .destructive(
                            Text("Open"),
                            action: {
                                let fileWrapper = try! FileWrapper(url: selectedFileURL!)
                                let file = try! RequestRangerFile.init(data: fileWrapper.regularFileContents!)
                                
                                // FIXME: Properly parse incoming requests
                                proxyData.httpRequests = file.proxyData.httpRequests
                                comparisonListData.data = file.comparisonData.data
                            }
                        ),
                        secondaryButton: .cancel(
                            Text("Cancel"),
                            action:{}
                        )
                    )
                }
                .fileImporter(isPresented: $showingImporter, allowedContentTypes: [utType]) { result in
                    switch result {
                    case .success(let url):
                        handleFileSelection(url: url)
                    case .failure(let error):
                        fatalError(error.localizedDescription)
                    }
                }
                .fileExporter(isPresented: $showingExporter, document: RequestRangerFile(proxyData: proxyData, comparisonData: comparisonListData), contentType: utType, defaultFilename: "export.requestranger") { result in
                    switch result {
                    case .success(let url):
                        print("Saved to \(url)")
                    case .failure(let error):
                        fatalError(error.localizedDescription)
                    }
                }
            }
            .commands {
                CommandGroup(after: CommandGroupPlacement.saveItem) {
                    Button("Save") {
                        showingExporter = true
                    }
                    .keyboardShortcut("s")
                }
                
                CommandGroup(after: CommandGroupPlacement.newItem) {
                    Button("Open") {
                        showingImporter = true
                    }
                    .keyboardShortcut("o")
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
