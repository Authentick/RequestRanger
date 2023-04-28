import Foundation
import NIOHTTP1
import NIO

struct RequestConverter {
    static func partToRaw(requestParts: [HTTPServerRequestPart]) -> String {
        var rawRequest = ""
        
        for reqPart in requestParts {
            switch reqPart {
            case .head(let head):
                rawRequest += "\(head.method.rawValue) \(head.uri) HTTP/1.1\r\n"
                for (name, value) in head.headers {
                    rawRequest += "\(name): \(value)\r\n"
                }
                rawRequest += "\r\n"
            case .body(let buffer):
                rawRequest += buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
            case .end:
                break
            }
        }
        
        return rawRequest
    }
    
    static func partToRaw(responseParts: [HTTPServerResponsePart]) -> String {
        var rawResponse = ""

        for resPart in responseParts {
            switch resPart {
            case .head(let head):
                rawResponse += "HTTP/\(head.version.major).\(head.version.minor) \(head.status.code) \(head.status.reasonPhrase)\r\n"
                for (name, value) in head.headers {
                    rawResponse += "\(name): \(value)\r\n"
                }
                rawResponse += "\r\n"
            case .body(let data):
                switch data {
                case .byteBuffer(let buffer):
                    rawResponse += buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
                case .fileRegion(let region):
                    fatalError("Handling 'fileRegion' is not supported in this implementation.")
                }
            case .end:
                break
            }
        }

        return rawResponse
    }
    
    static func rawToParts(raw: String) -> [HTTPServerRequestPart] {
        var requestParts: [HTTPServerRequestPart] = []
        let lines = raw.split(separator: "\r\n")
        var lineIndex = 0
        
        let requestLine = lines[lineIndex].split(separator: " ")
        let method = HTTPMethod(rawValue: String(requestLine[0]))
        let uri = String(requestLine[1])
        let version = HTTPVersion(major: 1, minor: 1)
        lineIndex += 1
        
        var headers: [(String, String)] = []
        while lineIndex < lines.count, !lines[lineIndex].isEmpty {
            let headerLine = lines[lineIndex].split(separator: ":")
            let headerName = headerLine[0].trimmingCharacters(in: .whitespaces)
            let headerValue = headerLine[1].trimmingCharacters(in: .whitespaces)
            headers.append((headerName, headerValue))
            lineIndex += 1
        }
        let head = HTTPRequestHead(version: version, method: method, uri: uri, headers: HTTPHeaders(headers))
        requestParts.append(.head(head))
        
        lineIndex += 1
        if lineIndex < lines.count {
            let body = lines[lineIndex...].joined(separator: "\r\n")
            var buffer = ByteBufferAllocator().buffer(capacity: body.utf8.count)
            buffer.writeString(body)
            requestParts.append(.body(buffer))
        }
        
        requestParts.append(.end(nil))
        
        return requestParts
    }
}
