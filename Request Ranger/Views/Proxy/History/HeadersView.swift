import SwiftUI

struct HeadersView: View {
    @Binding var headers: [String: Set<String>]
    @State private var selectedHeader = Set<HeaderItem.ID>()
    @State private var headerItems: [HeaderItem] = []
    @State private var sortOrder = [KeyPathComparator(\HeaderItem.name)]
    
    struct HeaderItem: Identifiable {
        let id = UUID()
        let name: String
        let value: String
    }
    
    private func headerItems(from headers: [String: Set<String>]) -> [HeaderItem] {
        var items: [HeaderItem] = []
        
        for (key, values) in headers {
            for value in values {
                items.append(HeaderItem(name: key, value: value))
            }
        }
        
        return items
    }
    
    
    var body: some View {
        Table(headerItems, selection: $selectedHeader, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("Value", value: \.value)
        }
        .onChange(of: headers) { value in
            headerItems = headerItems(from: value)
        }
        .onChange(of: sortOrder) { value in
            headerItems.sort(using: value)
        }
    }
}

struct HeadersView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleHeaders: [String: Set<String>] = [
            "Content-Type": ["image/gif"],
            "Content-Length": ["307"],
            "Connection": ["close"],
            "Date": ["Mon, 10 Apr 2023 10:06:49 GMT"],
            "Server": ["Apache"],
            "Last-Modified": ["Wed, 03 Jan 2018 11:32:53 GMT"],
            "ETag": ["\"133-561dd9372e340\""],
            "Accept-Ranges": ["bytes"],
        ]
        
        HeadersView(headers: Binding.constant(sampleHeaders))
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

