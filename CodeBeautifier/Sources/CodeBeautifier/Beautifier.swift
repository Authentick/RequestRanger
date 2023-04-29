import Foundation
import JavaScriptCore

public protocol Beautifier {
    var context: JSContext { get }
    var beautifyFunction: JSValue { get }
    func beautify(code: String, options: [String: Any]) -> String?
}

public extension Beautifier {
    static func commonInit(beautifyFunctionType: String) -> (JSContext, JSValue)? {
        let context = JSContext()

        guard let beautifyPath = Bundle.module.path(forResource: "js_beautify", ofType: "js"),
              let beautifyScript = try? String(contentsOfFile: beautifyPath) else {
            print("Error: Unable to load js-beautify library")
            return nil
        }

        context!.evaluateScript(beautifyScript)

        guard let exports = context!.objectForKeyedSubscript("beautifier"),
              let beautifyFunction = exports.objectForKeyedSubscript(beautifyFunctionType) else {
            print("Error: js_beautify is not available in the context")
            return nil
        }

        return (context, beautifyFunction) as? (JSContext, JSValue)
    }

    public func beautify(code: String, options: [String: Any] = [:]) -> String? {
        let jsOptions = JSValue(newObjectIn: context)
        for (key, value) in options {
            jsOptions?.setObject(value, forKeyedSubscript: key as NSString)
        }

        let result = beautifyFunction.call(withArguments: [code, jsOptions!])
        let beautifiedCode = result?.toString()

        return beautifiedCode
    }
}

public struct HTMLBeautifier: Beautifier {
    public let context: JSContext
    public let beautifyFunction: JSValue

    public init?() {
        guard let (context, beautifyFunction) = Self.commonInit(beautifyFunctionType: "html") else {
            return nil
        }
        self.context = context
        self.beautifyFunction = beautifyFunction
    }
}

public struct JSBeautifier: Beautifier {
    public let context: JSContext
    public let beautifyFunction: JSValue

    public init?() {
        guard let (context, beautifyFunction) = Self.commonInit(beautifyFunctionType: "js") else {
            return nil
        }
        self.context = context
        self.beautifyFunction = beautifyFunction
    }
}

public struct CSSBeautifier: Beautifier {
    public let context: JSContext
    public let beautifyFunction: JSValue

    public init?() {
        guard let (context, beautifyFunction) = Self.commonInit(beautifyFunctionType: "css") else {
            return nil
        }
        self.context = context
        self.beautifyFunction = beautifyFunction
    }
}
