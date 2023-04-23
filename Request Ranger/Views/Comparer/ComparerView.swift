import SwiftUI

struct ComparerView: View {
    let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
    
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif
    @EnvironmentObject var appState: AppState
    @State var comparisonData: ComparisonData = ComparisonData()
    @State var item1SelectedEntry = Set<ComparisonData.CompareEntry.ID>()
    @State var item2SelectedEntry = Set<ComparisonData.CompareEntry.ID>()
    @State private var item1SortOrder = [KeyPathComparator(\ComparisonData.CompareEntry.id)]
    @State private var item2SortOrder = [KeyPathComparator(\ComparisonData.CompareEntry.id)]
    @State private var showImport = false
    @State private var showHelpPopover = false

    var body: some View {
        let isValidSelection = item1SelectedEntry.count == 1 && item2SelectedEntry.count == 1 && item1SelectedEntry.first != item2SelectedEntry.first && appState.comparisonListData.data.contains(where: {$0.id == item1SelectedEntry.first}) && appState.comparisonListData.data.contains(where: {$0.id == item2SelectedEntry.first})
        
        var originalText: String = ""
        var modifiedText: String = ""
        
        if let selectedItem1Id = item1SelectedEntry.first {
            if let selectedItem2Id = item2SelectedEntry.first {
                originalText = appState.comparisonListData.data.first(where: {$0.id == selectedItem1Id})?.value ?? ""
                modifiedText = appState.comparisonListData.data.first(where: {$0.id == selectedItem2Id})?.value ?? ""
            }
        }
        
        func appendEntry(value: String) {
            NotificationCenter.default.post(name: .addCompareEntry, object: value)
        }
        
        return NavigationStack {
            Form {
                Section("Item 1") {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            
                            HStack(alignment: .top) {
                                Table(appState.comparisonListData.data, selection: $item1SelectedEntry, sortOrder: $item1SortOrder) {
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
                                    appState.comparisonListData.data.sort(using: $0)
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
                                appState.comparisonListData.data.removeAll(where: {$0.id == id})
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
                    Table(appState.comparisonListData.data, selection: $item2SelectedEntry, sortOrder: $item2SortOrder) {
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
                        appState.comparisonListData.data.sort(using: $0)
                    }
                    .frame(minHeight: 200)
                }
                
                NavigationLink(destination: CompareResultView(original: originalText, changed: modifiedText)) {
                    Label("Compare selection", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .disabled(!isValidSelection)
                .buttonStyle(.borderedProminent)
            }
#if os(macOS)
            .padding()
#endif
            .toolbar {
                ToolbarItem {
                    Button {
                        showHelpPopover = true
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    .popover(isPresented: $showHelpPopover) {
                        HelpPopoverView(header: "Comparer Help", content: """
This powerful tool allows you to analyze and compare multiple text strings, identifying both differences and similarities with ease.

To get started, simply follow these steps:

1. Input multiple text strings into the designated area.
2. From the list of entered texts, select the first item (Item 1) you would like to compare.
3. Choose a second item (Item 2) from the list to compare with Item 1.

The Compare Feature will then work its magic, providing you with a comprehensive comparison of the selected items.
""", isPresented: $showHelpPopover)
                    }
                }
                ToolbarItem() {
                    Button(role: .destructive) {
                        appState.comparisonListData.data = []
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
        ComparerView().environmentObject(AppState.shared)
    }
}
