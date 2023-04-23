import SwiftUI
import X509
import UniformTypeIdentifiers
import SwiftASN1

struct GeneralSettingsView: View {
    @AppStorage("proxyPort") var proxyListenerPort: Int = AppStorageIntDefaults.proxyPort.rawValue
    @State private var isExportingRootCA: Bool = false
    
    struct CertificateDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.x509Certificate] }
        var certificate: Certificate
        
        init(certificate: Certificate) {
            self.certificate = certificate
        }
        
        init(configuration: ReadConfiguration) throws {
            fatalError("No reader support")
        }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            var serializer = DER.Serializer()
            try serializer.serialize(certificate)
            
            return FileWrapper(regularFileWithContents: Data(serializer.serializedBytes))
        }
    }
    
    
    func generateNewCertificate() {
        try! CertificateManager.shared.createRootCA()
    }
    
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
                
#if os(macOS)
                HStack {
                    Button("Export Root CA") {
                        isExportingRootCA = true
                    }
                    
                    Button("Generate New Root CA") {
                        generateNewCertificate()
                    }
                }
#else
                Button("Export Root CA") {
                    isExportingRootCA = true
                }
                Button("Generate New Root CA") {
                    generateNewCertificate()
                }
#endif
            }
        }.fileExporter(isPresented: $isExportingRootCA, document: CertificateDocument(certificate: try! CertificateManager.shared.loadRootCAFromKeychain().rootCertificate), contentType: .x509Certificate, defaultFilename: "rootCA.der", onCompletion: { result in
            if case .success = result {
                print("Export success")
            } else {
                print("Export failed")
            }
        })
        
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
