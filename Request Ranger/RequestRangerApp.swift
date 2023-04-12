import SwiftUI
import Logging
import NIOHTTP1
import NIOCore
import NIOPosix
import UniformTypeIdentifiers
import AppleArchive
import System

extension Notification.Name {
    static let newHttpRequest = Notification.Name("new_http_request")
    static let newAttemptedHttpRequest = Notification.Name("new_attempted_http_request")
    static let proxyError = Notification.Name("proxy_connection_failure")
    static let proxyRunCommand = Notification.Name("proxy_run_command")
    static let cancelRequest = Notification.Name("cancel_request")
    static let addCompareEntry = Notification.Name("add_compare_entry")
    static let pendingRequest = Notification.Name("pending_request")
}

@main
struct RequestRangerApp: App {
    @StateObject var proxyData = ProxyData()
    @StateObject var comparisonListData = ComparisonData()
    @State var isProxyRunning = false
    @State var showProxyStartError: Bool = false
    @State var proxyStartErrorMessage: String? = nil
    @AppStorage("proxyPort") var proxyListenerPort: Int = AppStorageIntDefaults.proxyPort.rawValue
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showImportAlert: Bool = false
    @State private var selectedFileURL: URL?
    @State var serverGroup: MultiThreadedEventLoopGroup? = nil
    @State var requestsPendingApproval: [ProxyHandler] = []
    @State var isInterceptEnabled: Bool = false

    func startProxy() {
        DispatchQueue.global(qos: .userInitiated).async {
            startNioServer()
            isProxyRunning = true
        }
    }
    
    func stopProxy() {
        try! serverGroup?.syncShutdownGracefully()
        isProxyRunning = false
    }
    
    private func handleFileSelection(url: URL) {
        selectedFileURL = url
        showImportAlert = true
    }
    
    private func startNioServer() {
        let logger = Logger(label: "com.example.proxy")
        
        // Initialize the event loop group for the server
        serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // Create a server bootstrap
        let bootstrap = ServerBootstrap(group: serverGroup!)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(ProxyHandler(logger: logger))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        // Define the IP address and port where the server will listen
        let ipAddress = "127.0.0.1"
        let port = 8080
        
        // Start the server
        do {
            let channel = try bootstrap.bind(host: ipAddress, port: port).wait()
            logger.info("Server started and listening on \(channel.localAddress!)")
        } catch {
            logger.error("Failed to start server: \(error)")
            try? serverGroup!.syncShutdownGracefully()
            exit(1)
        }
    }
    
    var body: some Scene {
        let utType = RequestRangerFile.readableContentTypes.first!
        
        return Group {
            WindowGroup {
                ContentView(
                    proxyData: proxyData,
                    isProxyRunning: $isProxyRunning,
                    showingExporter: $showingExporter,
                    showingImporter: $showingImporter,
                    requestsPendingApproval: $requestsPendingApproval,
                    isInterceptEnabled: $isInterceptEnabled
                )
                .environmentObject(comparisonListData)
                .onChange(of: isInterceptEnabled) { state in
                    InterceptStateManager.shared.setShouldIntercept(state: state)
                }
                .onReceive(NotificationCenter.default.publisher(for: .pendingRequest))
                { obj in
                    if let proxyHandler = obj.object as? ProxyHandler {
                        requestsPendingApproval.append(proxyHandler)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .addCompareEntry))
                { obj in
                    if let text = obj.object as? String {
                        let count = comparisonListData.data.count
                        let comparisonEntry = ComparisonData.CompareEntry(id: count + 1, value: text)
                        comparisonListData.data.append(comparisonEntry)
                    }
                }
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
                                if selectedFileURL!.startAccessingSecurityScopedResource() {
                                    let fileWrapper = try! FileWrapper(url: selectedFileURL!)
                                    let file = try! RequestRangerFile.init(data: fileWrapper.regularFileContents!)
                                    
                                    // FIXME: Properly parse incoming requests
                                    proxyData.httpRequests = file.proxyData.httpRequests
                                    comparisonListData.data = file.comparisonData.data
                                }
                                selectedFileURL!.stopAccessingSecurityScopedResource()
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
