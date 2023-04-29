import XCTest
@testable import CodeBeautifier

protocol BeautifierTests: XCTestCase {
    var beautifier: Beautifier! { get set }
    var uglyCode: String! { get set }
    var expectedBeautifiedCode: String! { get set }
    
    func testBeautification()
}

extension BeautifierTests {
    func testBeautification() {
        let options: [String: Any] = ["indent_size": 2, "indent_char": " "]
        if let beautifiedCode = beautifier.beautify(code: uglyCode, options: options) {
            XCTAssertEqual(beautifiedCode, expectedBeautifiedCode, "Beautified code did not match the expected result")
        } else {
            XCTFail("Unable to beautify the code")
        }
    }
}

class HTMLBeautifierTests: XCTestCase, BeautifierTests {
    var beautifier: Beautifier!
    var uglyCode: String!
    var expectedBeautifiedCode: String!
    
    override func setUp() {
        super.setUp()
        beautifier = HTMLBeautifier()
        uglyCode = "<html><head></head><body><h1>Title</h1><p>Content</p></body></html>"
        expectedBeautifiedCode = """
        <html>
        
        <head></head>
        
        <body>
          <h1>Title</h1>
          <p>Content</p>
        </body>
        
        </html>
        """
    }
}

class CSSBeautifierTests: XCTestCase, BeautifierTests {
    var beautifier: Beautifier!
    var uglyCode: String!
    var expectedBeautifiedCode: String!
    
    override func setUp() {
        super.setUp()
        beautifier = CSSBeautifier()
        uglyCode = "body{margin:0;padding:0;}h1{font-size:24px;}"
        expectedBeautifiedCode = """
        body {
          margin: 0;
          padding: 0;
        }
        h1 {
          font-size: 24px;
        }
        """
    }
}

class JSBeautifierTests: XCTestCase, BeautifierTests {
    var beautifier: Beautifier!
    var uglyCode: String!
    var expectedBeautifiedCode: String!
    
    override func setUp() {
        super.setUp()
        beautifier = JSBeautifier()
        uglyCode = "function hello(name){console.log('Hello, '+name);}hello('World');"
        expectedBeautifiedCode = """
        function hello(name) {
          console.log('Hello, ' + name);
        }
        hello('World');
        """
    }
}
