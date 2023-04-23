import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMainMenuEntry: String?
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
                Section("Analysis") {
                    NavigationLink(value: "sitemap") {
                        Label("Sitemap", systemImage: "list.bullet.indent")
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
            if(selectedMainMenuEntry == "history") {
                ProxyHttpHistoryView()
            } else if(selectedMainMenuEntry == "intercept") {
                ProxyInterceptView()
            } else if(selectedMainMenuEntry == "decode") {
                DecodeView()
            } else if(selectedMainMenuEntry == "compare") {
                ComparerView()
            } else if(selectedMainMenuEntry == "sitemap") {
                SiteMapView()
            }
        }.onAppear() {
#if os(iOS)
            if(UIDevice.current.userInterfaceIdiom != .phone) {
                selectedMainMenuEntry = "history"
            }
#else
            selectedMainMenuEntry = "history"
#endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            showingExporter: Binding.constant(false),
            showingImporter: Binding.constant(false)
        ).environmentObject(AppState.shared)
    }
}
