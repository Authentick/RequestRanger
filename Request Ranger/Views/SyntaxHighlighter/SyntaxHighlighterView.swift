import SwiftUI

struct SyntaxHighlighterView: View {
    let code: String
    @Environment(\.colorScheme) var colorScheme

    private var cssString: String {
        if let filepath = Bundle.main.path(forResource: "highlight.min", ofType: "css"),
           let cssContent = try? String(contentsOfFile: filepath) {
            return cssContent
        } else {
            return ""
        }
    }
    
    private var jsString: String {
        if let filepath = Bundle.main.path(forResource: "highlight.min", ofType: "js"),
           let jsContent = try? String(contentsOfFile: filepath) {
            return jsContent
        } else {
            return ""
        }
    }
    
    private func escapeHTML(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    var baseTemplate: String {
        let escapedCode = escapeHTML(code)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
            html {}
            @media (prefers-color-scheme: dark) {
                html{
                    filter: invert(1)  hue-rotate(.5turn);
                }
            }
            </style>
            <style>
            \(cssString)
            </style>
            <script>
            \(jsString)
            </script>
            <script>
            hljs.highlightAll();
            </script>
        </head>
        <body>
            <pre><code>\(escapedCode)</code></pre>
        </body>
        </html>
        """
    }
    
    var body: some View {
        SwiftUIWebView(body: Binding.constant(self.baseTemplate), requestUrl: Binding.constant(""))
    }
}

struct SyntaxHighlighterView_Previews: PreviewProvider {
    static var previews: some View {
        SyntaxHighlighterView(code: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello, world!\")\n        .padding()\n    }\n}\n\nstruct ContentView_Previews: PreviewProvider {\n    static var previews: some View {\n        ContentView()\n    }\n}")
    }
}
