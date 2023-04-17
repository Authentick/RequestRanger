import NIOCore
import NIOEmbedded
import Foundation
import NIOPosix
import NIOHTTP1
import Logging
import Atomics

final class ProxyHandler: ChannelInboundHandler, RemovableChannelHandler, Equatable {
    static func == (lhs: ProxyHandler, rhs: ProxyHandler) -> Bool {
        return false
    }
    
    typealias InboundIn = HTTPServerRequestPart
    typealias OutbountIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var loggedRequest: ProxiedHttpRequest?
    private var upgradeState: State = State.idle
    private var logger: Logger
    private var targetHost: String?
    private static let globalRequestID = ManagedAtomic<Int>(0) // FIXME: should initialize with latest saved ID
    public var requestParts: [HTTPClientRequestPart] = []
    private var waitingContext: ChannelHandlerContext?
    private var dropRequestCallback: ((ChannelHandlerContext) -> Void)?
    private var clientBootstrap: ClientBootstrap
    
    init(
        logger: Logger,
        clientBootstrap: ClientBootstrap
    ) {
        self.logger = logger
        self.clientBootstrap = clientBootstrap
    }
    
    var request: HTTPServerRequestPart?
    enum State {
        case idle
        case active(Channel)
        case connectRequested
    }
    
    private func convertToClientRequestPart(_ reqPart: HTTPServerRequestPart) -> HTTPClientRequestPart {
        switch reqPart {
        case .head(let head):
            return .head(head)
        case .body(let buffer):
            return .body(.byteBuffer(buffer))
        case .end(let headers):
            return .end(headers)
        }
    }
    
    private func forwardRequest(context: ChannelHandlerContext, requestParts: [HTTPClientRequestPart]) {
        logRequest(requestParts: requestParts)
        
        switch upgradeState {
        case .idle:
            let channelFuture = ClientBootstrap(group: context.eventLoop)
                .channelInitializer { channel in
                    channel.pipeline.addHandler(HTTPRequestEncoder()).flatMap {
                        channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .forwardBytes)))
                            .flatMap {
                                return channel.pipeline.addHandler(ResponseHandler(context: context, request: self.loggedRequest!))
                            }
                    }
                }
                .connect(host: targetHost!, port: 80)
            
            channelFuture.whenSuccess { channel in
                self.upgradeState = .active(channel)
                for requestPart in requestParts {
                    self.sendData(context: context, channel: channel, reqPart: requestPart)
                }
            }
            
        case .active(let channel):
            for requestPart in requestParts {
                sendData(context: context, channel: channel, reqPart: requestPart)
            }
        case .connectRequested:
            fatalError("Connect should never call forwardRequest!")
        }
    }
    
    func getRawRequest(requestParts: [HTTPClientRequestPart]) -> String {
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
                switch buffer {
                case .byteBuffer(let buffer):
                    rawRequest += buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
                default:
                    break
                }
            case .end:
                break
            }
        }
        
        
        return rawRequest
    }
    
    private func logRequest(requestParts: [HTTPClientRequestPart]) {
        var httpMethod = ""
        var path = ""
        let rawRequest = getRawRequest(requestParts: requestParts)
        var headers: Dictionary<String, Set<String>> = [:]
        
        for reqPart in requestParts {
            switch reqPart {
            case .head(let head):
                httpMethod = head.method.rawValue
                path = head.uri
                for (name, value) in head.headers {
                    if headers[name.lowercased()] == nil {
                        headers[name.lowercased()] = Set<String>()
                    }
                    headers[name.lowercased()]?.insert(value)
                }
            default:
                break
            }
        }
        
        let newID = ProxyHandler.globalRequestID.wrappingIncrementThenLoad(ordering: .relaxed)
        let loggedRequest = ProxiedHttpRequest(
            id: newID,
            hostName: targetHost!,
            method: HttpMethodEnum(rawValue: httpMethod)!,
            path: path,
            headers: headers,
            rawRequest: rawRequest
        )
        self.loggedRequest = loggedRequest
        
        DispatchQueue.main.async { [loggedRequest] in
            NotificationCenter.default.post(name: .newHttpRequest, object: loggedRequest)
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch(upgradeState) {
        case .connectRequested:
            return
        default:
            break
        }
        
        switch(reqPart) {
        case .head(var head):
            if head.method == .CONNECT {
                let pid: Int32 = ProcessInfo.processInfo.processIdentifier
                print("pid: \(pid)")
                upgradeState = .connectRequested
                handleConnectRequest(context: context, head: &head)
            } else {
                // Handle non-CONNECT requests as before
                // Exfiltrate the request URI
                let originalURI = URL(string: head.uri)
                guard let originalURI else {
                    fatalError("Request without ")
                }
                print("Original URI: \(originalURI)")
                
                // Rewrite the host header and path
                let newHost = originalURI.host
                guard let newHost else {
                    return
                }
                targetHost = newHost
                
                head.headers.replaceOrAdd(name: "Host", value: newHost)
                head.uri = originalURI.relativePath
                
                // Remove the Accept-Encoding header
                head.headers.remove(name: "Accept-Encoding")
                
                // Forward the request with the updated headers
                let clientReqPart = HTTPClientRequestPart.head(head)
                
                requestParts.append(clientReqPart)
            }
        case .body(let buffer):
            let clientReqPart = HTTPClientRequestPart.body(.byteBuffer(buffer))
            requestParts.append(clientReqPart)
        case .end:
            if InterceptStateManager.shared.shouldIntercept() {
                waitingContext = context
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .pendingRequest, object: self)
                }
                
                dropRequestCallback = { (ctx: ChannelHandlerContext) in
                    ctx.eventLoop.execute {
                        self.sendHttpResponse(ctx: ctx, status: .serviceUnavailable)
                        ctx.close(promise: nil)
                    }
                }
            } else {
                forwardRequest(context: context, requestParts: requestParts)
            }
            
        }
    }
    
    
    private func handleConnectRequest(context: ChannelHandlerContext, head: inout HTTPRequestHead) {
        let uriComponents = head.uri.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        guard let targetHost = uriComponents.first,
              let targetPort = uriComponents.last,
              let targetPortInt = Int(targetPort) else {
            sendHttpResponse(ctx: context, status: .badRequest)
            context.close(promise: nil)
            return
        }
        
        let channelFuture = clientBootstrap
            .connect(host: String(targetHost), port: targetPortInt)
        print("Opening channel to \(targetHost)")
        
        channelFuture.whenSuccess { peerChannel in
            let (localGlue, peerGlue) = GlueHandler.matchedPair()
            
            let responseHead = HTTPResponseHead(version: .http1_1, status: .ok)
            let responsePart = HTTPServerResponsePart.head(responseHead)
            context.writeAndFlush(self.wrapOutboundOut(responsePart))
                .flatMap { _ in
                    context.pipeline.removeHandler(name: "HTTPResponseEncoder")
                }
                .flatMap { _ in
                    context.pipeline.removeHandler(name: "HTTPRequestDecoder")
                }
                .flatMap { _ in
                    context.channel.pipeline.addHandler(localGlue)
                }
                .flatMap { _ in
                    peerChannel.pipeline.addHandler(peerGlue)
                }.whenComplete { result in
                    switch(result) {
                    case .success():
                        print("Connection to \(targetHost) was successful")
                        context.pipeline.removeHandler(self)
                        
                    case .failure(let error):
                        print("Connection to \(targetHost) had error: \(error)")
                        peerChannel.close(mode: .all, promise: nil)
                        context.close(promise: nil)
                    }
                    
                }
        }
        
        channelFuture.whenFailure { error in
            print("Error encountered: \(error)")
            context.close(promise: nil)
            self.sendHttpResponse(ctx: context, status: .badGateway)
            context.fireErrorCaught(error)
        }
    }
    
    
    private func sendHttpResponse(ctx: ChannelHandlerContext, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), body: String = "") {
        var buffer = ctx.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)
        
        let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        let responseParts: [HTTPServerResponsePart] = [
            .head(responseHead),
            .body(.byteBuffer(buffer)),
            .end(nil)
        ]
        
        for part in responseParts {
            ctx.write(self.wrapOutboundOut(part), promise: nil)
        }
        ctx.flush()
    }
    
    func dropRequest() {
        if let context = waitingContext {
            dropRequestCallback?(context)
        }
    }
    
    func approveRequest(rawRequest: String) {
        // Parse the raw request and build a new request
        let updatedRequestParts = parseRawRequest(rawRequest: rawRequest)
        
        // Forward the updated request
        forwardRequest(context: waitingContext!, requestParts: updatedRequestParts)
    }
    
    private func parseRawRequest(rawRequest: String) -> [HTTPClientRequestPart] {
        let requestLines = rawRequest.split(separator: "\r\n", omittingEmptySubsequences: false)
        var requestParts: [HTTPClientRequestPart] = []
        
        var headers: HTTPHeaders = HTTPHeaders()
        var method: HTTPMethod = .GET
        var uri: String = ""
        var parsingHeaders = false
        
        for line in requestLines {
            if !parsingHeaders {
                let requestLine = line.split(separator: " ")
                if requestLine.count >= 2 {
                    method = HTTPMethod(rawValue: String(requestLine[0])) ?? .GET
                    uri = String(requestLine[1])
                    parsingHeaders = true
                }
            } else if line.isEmpty {
                requestParts.append(.head(HTTPRequestHead(version: .http1_1, method: method, uri: uri, headers: headers)))
                parsingHeaders = false
            } else {
                let headerLine = line.split(separator: ":", maxSplits: 1)
                if headerLine.count == 2 {
                    let name = headerLine[0].trimmingCharacters(in: .whitespaces)
                    let value = headerLine[1].trimmingCharacters(in: .whitespaces)
                    headers.add(name: name, value: value)
                } else {
                    let body = line.trimmingCharacters(in: .whitespaces)
                    var buffer = waitingContext!.channel.allocator.buffer(capacity: body.utf8.count)
                    buffer.writeString(body)
                    requestParts.append(.body(.byteBuffer(buffer)))
                    requestParts.append(.end(nil))
                    break
                }
            }
        }
        
        return requestParts
    }
    
    private func sendData(context: ChannelHandlerContext, channel: Channel, reqPart: HTTPClientRequestPart) {
        var close = false
        let clientReqPart: HTTPClientRequestPart
        switch reqPart {
        case .head(let head):
            clientReqPart = .head(head)
        case .body(let body):
            clientReqPart = .body(body)
        case .end(let headers):
            clientReqPart = .end(headers)
            close = true
        }
        
        channel.writeAndFlush(clientReqPart).whenComplete { result in
            switch result {
            case .success:
                if(close) {
                    channel.flush()
                    channel.close()
                }
                break
            case .failure(let error):
                fatalError("Something went wrong")
            }
        }
    }
}

final class ResponseHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart
    private let context: ChannelHandlerContext
    
    init(context: ChannelHandlerContext, request: ProxiedHttpRequest) {
        self.context = context
        self.request = request
    }
    
    private let request: ProxiedHttpRequest
    private var responseParts: [HTTPClientResponsePart] = []
    
    private func logResponse() {
        var statusCode: Int?
        var rawResponse = ""
        var headers: Dictionary<String, Set<String>> = [:]
        
        for responsePart in responseParts {
            switch responsePart {
            case .head(let head):
                statusCode = Int(head.status.code)
                rawResponse += "HTTP/1.1 \(head.status.code) \(head.status.reasonPhrase)\r\n"
                for (name, value) in head.headers {
                    rawResponse += "\(name): \(value)\r\n"
                    if headers[name.lowercased()] == nil {
                        headers[name.lowercased()] = Set<String>()
                    }
                    headers[name.lowercased()]?.insert(value)
                }
                rawResponse += "\r\n"
            case .body(let buffer):
                rawResponse += buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
            case .end:
                break
            }
        }
        
        guard let code = statusCode else { return }
        
        let loggedResponse = ProxiedHttpResponse(
            rawResponse: rawResponse,
            headers: headers
        )
        
        request.response = loggedResponse
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let responsePart = self.unwrapInboundIn(data)
        responseParts.append(responsePart)
        
        switch responsePart {
        case .head(let head):
            let serverHead = HTTPServerResponsePart.head(head)
            self.context.channel.write(serverHead, promise: nil)
        case .body(let buffer):
            let serverBody = HTTPServerResponsePart.body(.byteBuffer(buffer))
            self.context.channel.write(serverBody, promise: nil)
        case .end(let headers):
            let serverEnd = HTTPServerResponsePart.end(headers)
            self.context.channel.writeAndFlush(serverEnd).whenComplete { result in
                switch result {
                case .success:
                    self.logResponse()
                    self.context.channel.close(promise: nil)
                case .failure(let error):
                    print("Error when writing and flushing serverEnd: \(error)")
                    self.context.channel.close(promise: nil)
                }
            }
        }
    }
}
