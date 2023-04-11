import SwiftUI

struct ComparerView: View {
    let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
    
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif
    @EnvironmentObject var comparisonData: ComparisonData
    @State private var intCount = 0
    @State var item1SelectedEntry = Set<ComparisonData.CompareEntry.ID>()
    @State var item2SelectedEntry = Set<ComparisonData.CompareEntry.ID>()
    @State private var item1SortOrder = [KeyPathComparator(\ComparisonData.CompareEntry.id)]
    @State private var item2SortOrder = [KeyPathComparator(\ComparisonData.CompareEntry.id)]
    @State private var showImport = false
    
    var body: some View {
        let isValidSelection = item1SelectedEntry.count == 1 && item2SelectedEntry.count == 1 && item1SelectedEntry.first != item2SelectedEntry.first && comparisonData.data.contains(where: {$0.id == item1SelectedEntry.first}) && comparisonData.data.contains(where: {$0.id == item2SelectedEntry.first})
        
        var originalText: String = ""
        var modifiedText: String = ""
        
        if let selectedItem1Id = item1SelectedEntry.first {
            if let selectedItem2Id = item2SelectedEntry.first {
                originalText = comparisonData.data.first(where: {$0.id == selectedItem1Id})?.value ?? ""
                modifiedText = comparisonData.data.first(where: {$0.id == selectedItem2Id})?.value ?? ""
            }
        }
        
        func appendEntry(value: String) {
            self.intCount = intCount + 1
            comparisonData.data.append(ComparisonData.CompareEntry(id: intCount, value: value))
        }
        
        return NavigationStack {
            Form {
                Section {
                    Text("Compare and analyze text strings to identify differences and similarities. Simply input two strings and let \(appName) do the work for you.")
                        .fontWeight(.light)
                        .padding(.bottom)
                }
                
                Section("Item 1") {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            
                            HStack(alignment: .top) {
                                Table(comparisonData.data, selection: $item1SelectedEntry, sortOrder: $item1SortOrder) {
                                    TableColumn("#", value: \.id) { element in
                                        HStack {
                                            Text(String(element.id))
                                            if isCompact {
                                                Text(element.value.prefix(30) + (element.value.count > 30 ? "..." : ""))
                                            }
                                        }
                                    }
                                    .width(isCompact ? nil : 40)
                                    TableColumn("Length", value: \.length) { element in
                                        Text(String(element.length))
                                    }
                                    .width(60)
                                    TableColumn("Value", value: \.value)
                                }
                                .frame(minHeight: 200)
                                .onChange(of: item1SortOrder) {
                                    comparisonData.data.sort(using: $0)
                                }
                                
                                Spacer()
                                
                            }
                        }
                    }
                    
                    HStack {
                        PasteButton(payloadType: String.self, onPaste: {entry in
                            appendEntry(value: entry.first!)
                        })
                        
                        Button {
                            showImport = true
                        } label: {
                            Label("File", systemImage: "text.insert")
                        }
#if os(iOS)
                        .buttonStyle(BorderlessButtonStyle())
#endif
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            item1SelectedEntry.forEach { id in
                                comparisonData.data.removeAll(where: {$0.id == id})
                                item2SelectedEntry.remove(id)
                            }
                            item1SelectedEntry = []
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(item1SelectedEntry.count == 0)
#if os(iOS)
                        .buttonStyle(BorderlessButtonStyle())
#endif
                    }
                }
                
                Section("Item 2") {
                    Table(comparisonData.data, selection: $item2SelectedEntry, sortOrder: $item2SortOrder) {
                        TableColumn("#", value: \.id) { element in
                            HStack {
                                Text(String(element.id))
                                if isCompact {
                                    Text(element.value.prefix(30) + (element.value.count > 30 ? "..." : ""))
                                }
                            }
                        }
                        .width(isCompact ? nil : 40)
                        TableColumn("Length", value: \.length) { element in
                            Text(String(element.length))
                        }.width(60)
                        TableColumn("Value", value: \.value)
                    }
                    
                    .onChange(of: item2SortOrder) {
                        comparisonData.data.sort(using: $0)
                    }
                    .frame(minHeight: 200)
                }
                
                NavigationLink(destination: CompareResultView(original: originalText, changed: modifiedText)) {
                    Label("Compare selection", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .disabled(!isValidSelection)
                .buttonStyle(.borderedProminent)
                if(!isValidSelection) {
                    Label("Select two different elements from the lists to enable the comparison mode.", systemImage: "info.circle")
                        .fontWeight(.light)
                }
                
            }
#if os(macOS)
            .padding()
#endif
            .toolbar() {
                ToolbarItem() {
                    Button(role: .destructive) {
                        comparisonData.data = []
                    } label: {
                        Text("Clear")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: true,
                onCompletion: { results in
                    switch results {
                    case .success(let fileUrls):
                        for fileUrl in fileUrls {
                            if fileUrl.startAccessingSecurityScopedResource() {
                                let text = try! String(contentsOf: fileUrl, encoding: .utf8)
                                appendEntry(value: String(text))
                            }
                            fileUrl.stopAccessingSecurityScopedResource()
                        }
                        
                    case .failure(let error):
                        fatalError("Could not paste data from file")
                    }
                }
            )
            .navigationTitle("Compare")
        }
    }
}

struct ComparerView_Previews: PreviewProvider {
    static var previews: some View {
        ComparerView().environmentObject(ComparisonData())
    }
}
