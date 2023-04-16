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
    @StateObject var appState = AppState()
    @AppStorage("proxyPort") var proxyListenerPort: Int = AppStorageIntDefaults.proxyPort.rawValue
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showImportAlert: Bool = false
    @State private var selectedFileURL: URL?
    @State var requestsPendingApproval: [ProxyHandler] = []
    @State var isInterceptEnabled: Bool = false
    
    private func handleFileSelection(url: URL) {
        selectedFileURL = url
        showImportAlert = true
    }
    
    var body: some Scene {
        let utType = RequestRangerFile.readableContentTypes.first!
        
        return Group {
            WindowGroup {
                ContentView(
                    showingExporter: $showingExporter,
                    showingImporter: $showingImporter,
                    requestsPendingApproval: $requestsPendingApproval,
                    isInterceptEnabled: $isInterceptEnabled
                )
                .environmentObject(appState)
                .onChange(of: isInterceptEnabled) { state in
                    InterceptStateManager.shared.setShouldIntercept(state: state)
                }
                .onOpenURL { url in
                    selectedFileURL = url
                    showImportAlert = true
                }
                .alert(isPresented: $appState.showProxyStartError) {
                    let errorMessageHeader = Text("You can change the proxy port in the application settings.\n\nThe error message was:\n\n")
                    var detailedErrorMessage: Text
                    
                    if(appState.proxyStartErrorMessage == nil) {
                        detailedErrorMessage = Text("Could not determine error")
                    } else {
                        detailedErrorMessage = Text(appState.proxyStartErrorMessage!)
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
                                    appState.proxyData.httpRequests = file.proxyData.httpRequests
                                    appState.comparisonListData.data = file.comparisonData.data
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
                .fileExporter(isPresented: $showingExporter, document: RequestRangerFile(proxyData: appState.proxyData, comparisonData: appState.comparisonListData), contentType: utType, defaultFilename: "export.requestranger") { result in
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
