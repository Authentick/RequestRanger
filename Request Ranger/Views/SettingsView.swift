import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("proxyPort") var proxyListenerPort: Int = AppStorageIntDefaults.proxyPort.rawValue
    
    var body: some View {
        let formatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            return formatter
        }()
        
        Form {
            Section(header: Text("Proxy configuration")) {
                LabeledContent {
                    TextField("", value: $proxyListenerPort, formatter: formatter)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                } label: {
                    Text("Port")
                }
            }
        }
    }
}

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, advanced
    }
    var body: some View {
#if os(macOS)
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
                .padding()
        }
#else
        GeneralSettingsView()
            .navigationTitle("Settings")
#endif
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
