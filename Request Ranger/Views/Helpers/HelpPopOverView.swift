import SwiftUI

struct HelpPopoverView: View {
    let header: LocalizedStringKey
    let content: LocalizedStringKey
    @Binding var isPresented: Bool
    
    var body: some View {
#if os(macOS)
        let maxWidth: CGFloat = 450
#else
        let maxWidth: CGFloat = .infinity
#endif
        
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    Text(header)
                        .font(.headline)
                        .padding(.bottom, 5)
#if os(iOS)
                    if(UIDevice.current.userInterfaceIdiom == .phone) {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Label("Close", systemImage: "xmark")
                        }
                    }
#endif
                }
                
                Text(content)
                    .fontWeight(.light)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: maxWidth, maxHeight: .infinity)
            .padding()
        }
    }
}

struct HelpPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        HelpPopoverView(header: "Comparer Help", content: """
This powerful tool allows you to analyze and compare multiple text strings, identifying both differences and similarities with ease.

To get started, simply follow these steps:

1. Input multiple text strings into the designated area.
2. From the list of entered texts, select the first item (Item 1) you would like to compare.
3. Choose a second item (Item 2) from the list to compare with Item 1.

The Compare Feature will then work its magic, providing you with a comprehensive comparison of the selected items.
""", isPresented: .constant(true))
    }
}
