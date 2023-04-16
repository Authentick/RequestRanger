import SwiftUI
import SwiftDiff

struct CompareResultView: View {
    let original: String
    let changed: String
    
    struct DiffText: Identifiable {
        let id = UUID()
        let text: AttributedString
    }
    
    
    var body: some View {
        let diffResults = diff(
            text1: original,
            text2: changed
        )
        
        func getBackgroundColo(diff: Diff) -> Color? {
            switch(diff) {
            case .delete:
                return .red
            case .insert:
                return .green
            default:
                return nil
            }
        }
        
        func getForegroundColor(diff: Diff) -> Color? {
            switch(diff) {
            case .delete:
                return .black
            case .insert:
                return .black
            default:
                return nil
            }
        }
        
        var mergedAttributedString = AttributedString()
        
        diffResults.forEach { diff in
            var attributedString = AttributedString(diff.text)
            attributedString.backgroundColor = getBackgroundColo(diff: diff)
            attributedString.foregroundColor = getForegroundColor(diff: diff)
            mergedAttributedString.append(attributedString)
        }
        
        return VStack(alignment: .leading) {
            ScrollView {
                VStack {
                    Text(mergedAttributedString)
                        .textSelection(.enabled)
                        .padding(5.0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.background)
            
            HStack(alignment: .center) {
                Text("Added")
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.green)
                Text("Identical")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Removed")
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.red)
            }
            .frame(height: 40)
        }
        .navigationTitle("Comparison results")
    }
}

struct CompareResultView_Previews: PreviewProvider {
    static var previews: some View {
        CompareResultView(original: "This is an example sentence. I also like to break the lines.", changed: "Here is another example sentence, because examples are great. Also it is important to always test with text that break the lines.")
    }
}
