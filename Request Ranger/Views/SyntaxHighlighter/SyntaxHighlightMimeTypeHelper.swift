import Foundation

struct SyntaxHighlightingMimeTypeHelper {
    private static let supportedMimeTypes: Set<String> = [
        "text/plain",
        "text/html",
        "text/javascript",
        "text/css",
        "application/javascript",
        "application/json",
        "application/xml"
    ]

    static func isSupported(mimeType: String) -> Bool {
        let baseMimeType = mimeType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
        if let baseMimeType = baseMimeType {
            return supportedMimeTypes.contains(baseMimeType)
        }
        return false
    }
}
