import SwiftUI

struct ComparerView: View {
    let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String

    struct CompareEntry: Identifiable, Hashable {
        let id: Int
        let value: String
        var length: Int { value.lengthOfBytes(using: .utf8 ) }
    }
    
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif
    @State private var intCount = 0
    @State private var entries: [CompareEntry] = []
    @State var item1SelectedEntry = Set<CompareEntry.ID>()
    @State var item2SelectedEntry = Set<CompareEntry.ID>()
    @State private var item1SortOrder = [KeyPathComparator(\CompareEntry.id)]
    @State private var item2SortOrder = [KeyPathComparator(\CompareEntry.id)]
    
    var body: some View {
        let isValidSelection = item1SelectedEntry.count == 1 && item2SelectedEntry.count == 1 && item1SelectedEntry.first != item2SelectedEntry.first && entries.contains(where: {$0.id == item1SelectedEntry.first}) && entries.contains(where: {$0.id == item2SelectedEntry.first})
        
        var originalText: String = ""
        var modifiedText: String = ""
        
        if let selectedItem1Id = item1SelectedEntry.first {
            if let selectedItem2Id = item2SelectedEntry.first {
                originalText = entries.first(where: {$0.id == selectedItem1Id})?.value ?? ""
                modifiedText = entries.first(where: {$0.id == selectedItem2Id})?.value ?? ""
            }
        }
        
        func appendEntry(value: String) {
            self.intCount = intCount + 1
            entries.append(CompareEntry(id: intCount, value: value))
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
                                Table(entries, selection: $item1SelectedEntry, sortOrder: $item1SortOrder) {
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
                                    entries.sort(using: $0)
                                }
                                
                                Spacer()
                                
                            }
                        }
                    }
                    
                    HStack {
                        PasteButton(payloadType: String.self, onPaste: {entry in
                            appendEntry(value: entry.first!)
                        })
#if os(macOS)
                        Button {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.prompt = "Add"
                            panel.message = "Choose file for comparison"
                            if panel.runModal() == .OK {
                                guard let path = panel.url?.path(percentEncoded: false) else {
                                    return
                                }
                                
                                guard let data = FileManager.default.contents(atPath: path) else {
                                    return
                                }
                                
                                guard let txt = NSString(data: data, encoding: NSUTF8StringEncoding) else {
                                    return
                                }
                                
                                appendEntry(value: String(txt))
                            }
                        } label: {
                            Label("File", systemImage: "text.insert")
                        }
#endif

                        Spacer()
                        
                        Button(role: .destructive) {
                            item1SelectedEntry.forEach { id in
                                entries.removeAll(where: {$0.id == id})
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
                    Table(entries, selection: $item2SelectedEntry, sortOrder: $item2SortOrder) {
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
                        entries.sort(using: $0)
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
                        entries = []
                    } label: {
                        Text("Clear")
                            .frame(maxWidth: .infinity)
                    }
                }
                
            }.navigationTitle("Compare")
        }
    }
}

struct ComparerView_Previews: PreviewProvider {
    static var previews: some View {
        ComparerView()
    }
}
