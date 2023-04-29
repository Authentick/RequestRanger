import Foundation
import CodeBeautifier

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
    
    static func beautifyFunction(for mimeType: String) -> ((String, [String: Any]) -> String?)? {
        let baseMimeType = mimeType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
        
        if let baseMimeType = baseMimeType {
            switch baseMimeType {
            case "text/html":
                let htmlBeautifier = HTMLBeautifier()
                return htmlBeautifier?.beautify(code:options:)
            case "text/javascript", "application/javascript":
                let jsBeautifier = JSBeautifier()
                return jsBeautifier?.beautify(code:options:)
            case "text/css":
                let cssBeautifier = CSSBeautifier()
                return cssBeautifier?.beautify(code:options:)
            default:
                return nil
            }
        }
        
        return nil
    }
}
