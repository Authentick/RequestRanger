import SwiftUI

struct ContentView: View {
    @ObservedObject var proxyData: ProxyData
    @State private var selectedMainMenuEntry: MenuEntry?
    @Binding var isProxyRunning: Bool
    let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String

    
    struct MenuEntryLabel: View {
        let title: String
        let systemImageName: String
        
        var body: some View {
            Label(title: { Text(title)}, icon: { Image(systemName: systemImageName) } )
        }
    }
    
    struct MenuEntry: Identifiable, Hashable {
        static func == (lhs: ContentView.MenuEntry, rhs: ContentView.MenuEntry) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: String
        let label: MenuEntryLabel
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id.hashValue)
        }
    }
    
    
    var body: some View {
        let proxyMenu = MenuEntry(
            id: "proxy",
            label: MenuEntryLabel(title: "Proxy", systemImageName: "network")
        )
        let decodeMenu = MenuEntry(
            id: "decode",
            label: MenuEntryLabel(title: "Decode & Encode", systemImageName: "barcode")
        )
        let compareMenu = MenuEntry(
            id: "compare",
            label: MenuEntryLabel(title: "Compare", systemImageName: "doc.on.doc")
        )
        
        let menuEntries: [MenuEntry] = [
            proxyMenu,
            decodeMenu,
            compareMenu
        ]
        
        return NavigationSplitView {
            List(selection: $selectedMainMenuEntry) {
                ForEach(menuEntries) { entry in
                    NavigationLink(value: entry) {
                        entry.label
                    }
                }
            }
            .navigationTitle(appName)
#if os(iOS)
            .toolbar(){
                ToolbarItem() {
                    NavigationLink("\(Image(systemName: "gear"))", destination: SettingsView())
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
            
            if(selectedMainMenuEntry == proxyMenu) {
                ProxyView(proxyData: proxyData, isProxyRunning: $isProxyRunning)
            } else if(selectedMainMenuEntry == decodeMenu) {
                DecodeView()
            } else if(selectedMainMenuEntry == compareMenu) {
                ComparerView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(proxyData: ProxyData(), isProxyRunning: Binding.constant(false))
    }
}
