import Foundation

public struct HttpRequest: Equatable {
    public let FullRequest: String
    public let method: String
    public let target: String
    public let version: String
    public let headers: Dictionary<String, Set<String>>
    public let body: String
}

public struct HttpResponse: Equatable {
    public let FullResponse: String
    public let headers: Dictionary<String, Set<String>>
    public let body: String
}

public struct HttpParser {
    public init() {}
    
    private func extractHeaders(_ httpMessage: String) -> Dictionary<String, Set<String>> {
        let firstLineCutOff = httpMessage.split(maxSplits: 1, whereSeparator: \.isNewline)
        let otherLines = String(firstLineCutOff[1])
        let doubleNewLineRange = otherLines.range(of: "\r\n\r\n")
        
        guard let headersEnd = doubleNewLineRange?.lowerBound else {
            return [:]
        }

        let headersText = otherLines[..<headersEnd]

        var headersDictionary: Dictionary<String, Set<String>> = [:]
        headersText.enumerateLines { (line, _) in
            let splittedHeaderLine = line.split(separator: ":", maxSplits: 1)
            let key = String(splittedHeaderLine[0])
            var value = String(splittedHeaderLine[1])
            value.remove(at: value.startIndex)
            
            if(headersDictionary[key] != nil) {
                headersDictionary[key]?.insert(value)
            } else {
                headersDictionary[key] = [value]
            }
        }

        return headersDictionary
    }
    
    public func parseRequest(_ httpMessage: String) -> HttpRequest {
        let firstLineCutOff = httpMessage.split(maxSplits: 1, whereSeparator: \.isNewline)
        let requestLine = String(firstLineCutOff[0])
        let requestLineSplitted = requestLine.split(whereSeparator: \.isWhitespace)


        let otherLines = String(firstLineCutOff[1])
        let doubleNewLineRange = otherLines.range(of: "\r\n\r\n")
        let headersDictionary = extractHeaders(httpMessage)

        let request = HttpRequest(
            FullRequest: httpMessage,
            method: String(requestLineSplitted[0]),
            target: String(requestLineSplitted[1]),
            version: String(requestLineSplitted[2]),
            headers: headersDictionary,
            body: doubleNewLineRange != nil ? otherLines.substring(from: doubleNewLineRange!.upperBound) : ""
        )

        return request
    }
    
    public func parseResponse(_ httpMessage: String) -> HttpResponse {
        var responseBody = ""
        if let range = httpMessage.range(of: "\r\n\r\n") {
            responseBody = String(httpMessage[range.upperBound...])
        }
        
        let headers = extractHeaders(httpMessage)

        let response = HttpResponse(
            FullResponse: httpMessage,
            headers: headers,
            body: responseBody
        )
        

        return response
    }
}
