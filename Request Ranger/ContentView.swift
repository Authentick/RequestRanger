import SwiftUI

struct ContentView: View {
    @ObservedObject var proxyData: ProxyData
    @State private var selectedMainMenuEntry: String? = nil
    @Binding var isProxyRunning: Bool
    @Binding var showingExporter: Bool
    @Binding var showingImporter: Bool
    
    let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMainMenuEntry) {
                Section("Proxy") {
                    NavigationLink(value: "history") {
                        Label("History", systemImage: "network")
                    }
                    NavigationLink(value: "intercept") {
                        Label("Intercept", systemImage: "pause.circle")
                    }
                }
                Section("Tools") {
                    NavigationLink(value: "decode") {
                        Label("Encoder", systemImage: "barcode")
                    }
                    NavigationLink(value: "compare") {
                        Label("Comparer", systemImage: "doc.on.doc")
                    }
                    
                }
            }
            .navigationTitle(appName)
#if os(iOS)
            .toolbar(){
                ToolbarItem() {
                    Menu {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Open", systemImage: "folder")
                        }
                        Button {
                            showingExporter = true
                        } label: {
                            Label("Save", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Import / Export", systemImage: "folder")
                    }
                }
                
                ToolbarItem() {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
#endif
            
        } detail: {
            if(selectedMainMenuEntry == nil) {
#if os(iOS)
                if(UIDevice.current.userInterfaceIdiom != .phone) {
                    DashboardView()
                }
#else
                DashboardView()
#endif
            }
            
            if(selectedMainMenuEntry == "history") {
                ProxyHttpHistoryView(proxyData: proxyData, isProxyRunning: $isProxyRunning)
            } else if(selectedMainMenuEntry == "intercept") {
                ProxyInterceptView()
            } else if(selectedMainMenuEntry == "decode") {
                DecodeView()
            } else if(selectedMainMenuEntry == "compare") {
                ComparerView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(proxyData: ProxyData(), isProxyRunning: Binding.constant(false), showingExporter: Binding.constant(false), showingImporter: Binding.constant(false))
    }
}
