import Foundation

struct ComparisonData {
    var data: [CompareEntry] = []
    
    struct CompareEntry: Identifiable, Hashable {
        let id: Int
        let value: String
        var length: Int { value.lengthOfBytes(using: .utf8 ) }
    }
}
