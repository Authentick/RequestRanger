import XCTest
@testable import HttpParser

final class HttpParserTests: XCTestCase {
    func testParseRequestBody() throws {
        let requestBody = """
POST /test HTTP/1.1
Host: foo.example
Content-Type: application/x-www-form-urlencoded
Content-Length: 27
Server: Private
Server: CF\r
\r
field1=value1&field2=value2
"""

        let parser = HttpParser()
        let parsedRequest = parser.parseRequest(requestBody)
        
        var expectedRequest = HttpRequest()
        expectedRequest.FullRequest = requestBody
        expectedRequest.method = "POST"
        expectedRequest.target = "/test"
        expectedRequest.version = "HTTP/1.1"
        expectedRequest.body = "field1=value1&field2=value2"
        expectedRequest.headers = [
            "Content-Type": ["application/x-www-form-urlencoded"],
            "Content-Length": ["27"],
            "Host": ["foo.example"],
            "Server": ["CF", "Private"]
        ]
        
        XCTAssertEqual(parsedRequest, expectedRequest)
    }
    
    func testParseResponseBody() throws {
        let responseBody = """
HTTP/1.1 200 OK
Content-Type: text/javascript
Content-Length: 25
Connection: close
Date: Sat, 01 Apr 2023 16:51:03 GMT
Server: Apache
Last-Modified: Wed, 03 Jan 2018 11:33:17 GMT
ETag: "19-561dd94e11940"
Accept-Ranges: bytes\r
\r
$(document).foundation()
"""

        let parser = HttpParser()
        let parsedResponse = parser.parseResponse(responseBody)
        
        var expectedResponse = HttpResponse()
        expectedResponse.FullResponse = responseBody
        expectedResponse.body = "$(document).foundation()"
        
        XCTAssertEqual(parsedResponse, expectedResponse)
    }
}
