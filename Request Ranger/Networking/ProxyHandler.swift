import NIOCore
import CryptoKit
import X509
import SwiftASN1
import NIOSSL
import NIOTLS
import NIOEmbedded
import Foundation
import NIOPosix
import NIOHTTP1
import Logging
import Atomics

// FIXME: remove completely
final class ProxyHandler {
    public static let globalRequestID = ManagedAtomic<Int>(0) // FIXME: should initialize with latest saved ID
}

/** Determines whether a request is a unencrypted reverse proxy request or an encrypted CONNECT request. Depending on the type of request the popeline is setup differently. */
final class ProxyPipelineHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    
    var requestHead: HTTPRequestHead?
    var requestBody: [HTTPServerRequestPart] = []
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let head):
            requestHead = head
        default:
            break
        }
        requestBody.append(requestPart)
        
        if case .end(_) = requestPart {
            processRequest(context: context)
        }
    }
    
    private func processRequest(context: ChannelHandlerContext) {
        guard let head = requestHead else {
            return
        }
        
        if head.method == .CONNECT {
            handleEncryptedRequest(context: context)
        } else {
            handleUnencryptedRequest(context: context)
        }
        
        for requestPart in requestBody {
            context.fireChannelRead(self.wrapInboundOut(requestPart))
        }
    }
    
    private func setupUnencryptedSharedHandlers(context: ChannelHandlerContext) {
        _ = context.channel.pipeline.addHandler(HttpCloseConnectionHandler())
        _ = context.channel.pipeline.addHandler(HttpRemoveAcceptEncodingHeader())
        _ = context.channel.pipeline.addHandler(RequestInterceptionHandler())
        _ = context.channel.pipeline.addHandler(RequestLogHandler())
    }
    
    private func handleEncryptedRequest(context: ChannelHandlerContext) {
        print("Setting up pipeline for encrypted request")
        _ = context.channel.pipeline.addHandler(HttpsConnectRewriteHandler())
        
        setupUnencryptedSharedHandlers(context: context)
        
        _ = context.channel.pipeline.addHandlers(EncryptedProxyHandler())
    }
    
    private func handleUnencryptedRequest(context: ChannelHandlerContext) {
        print("Setting up pipeline for unencrypted request")
        _ = context.channel.pipeline.addHandler(HttpProxyUriRewriterHandler())

        setupUnencryptedSharedHandlers(context: context)

        _ = context.channel.pipeline.addHandlers(UnencryptedProxyHandler())
    }
}

/** Intercepts requests if the intercept mode is enabled*/
final class RequestInterceptionHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    
    private var context: ChannelHandlerContext? = nil
    
    struct PendingRequestNotification: Equatable {
        static func == (lhs: RequestInterceptionHandler.PendingRequestNotification, rhs: RequestInterceptionHandler.PendingRequestNotification) -> Bool {
            return false
        }
        
        let handler: RequestInterceptionHandler
        let request: [HTTPServerRequestPart]
    }
    
    private var pendingRequestParts: [HTTPServerRequestPart] = []
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.context = context
        let requestPart = unwrapInboundIn(data)
        
        if AppState.shared.isInterceptEnabled {
            pendingRequestParts.append(requestPart)
            
            if case .end(_) = requestPart {
                let notification = PendingRequestNotification(
                    handler: self,
                    request: pendingRequestParts
                )
                NotificationCenter.default.post(name: .pendingRequest, object: notification)
                return
            }
        } else {
            context.fireChannelRead(data)
        }
    }
    
    func userDidApprove(parts: [HTTPServerRequestPart]) {
        context!.eventLoop.execute {
            for requestPart in parts {
                self.context!.fireChannelRead(self.wrapInboundOut(requestPart))
            }
        }
    }
    
    func userDidDeny() {
        context!.eventLoop.execute {
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
            
            let responseHead = HTTPResponseHead(version: .http1_1, status: .serviceUnavailable, headers: headers)
            let responsePart = HTTPServerResponsePart.head(responseHead)
            
            self.context!.write(NIOAny(responsePart), promise: nil)
            let responseBody = HTTPServerResponsePart.body(.byteBuffer(self.context!.channel.allocator.buffer(string: "Request cancelled by Request Ranger")))
            self.context!.writeAndFlush(NIOAny(responseBody), promise: nil)
            self.context!.close(promise: nil)
        }
    }
}

struct LoggedHTTPServerRequestPart {
    let requestId: Int
    let requestPart: HTTPServerRequestPart
}

/** Log the request  */
final class RequestLogHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = LoggedHTTPServerRequestPart
    
    private var requestParts: [HTTPServerRequestPart] = []
    private var targetHost: String?
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)
        requestParts.append(requestPart)
        
        switch requestPart {
        case .head(let head):
            targetHost = head.headers["Host"].first
        case .end:
            let requestId = logRequest(requestParts: requestParts)
            
            for part in requestParts {
                let loggedRequestParts = LoggedHTTPServerRequestPart(requestId: requestId, requestPart: part)
                context.fireChannelRead(self.wrapInboundOut(loggedRequestParts))
            }
        default:
            break
        }
    }
    
    private func logRequest(requestParts: [HTTPServerRequestPart]) -> Int {
        guard let targetHost = targetHost else {
            fatalError("TargetHost isn't set in logRequest")
        }
        
        var httpMethod = ""
        var path = ""
        var headers: Dictionary<String, Set<String>> = [:]
        
        for reqPart in requestParts {
            switch reqPart {
            case .head(let head):
                httpMethod = head.method.rawValue
                path = head.uri
                for (name, value) in head.headers {
                    if headers[name] == nil {
                        headers[name] = Set<String>()
                    }
                    headers[name]?.insert(value)
                }
            default:
                break
            }
        }
        
        let rawRequest = RequestConverter.partToRaw(requestParts: requestParts)
        let newID = ProxyHandler.globalRequestID.wrappingIncrementThenLoad(ordering: .relaxed)
        let loggedRequest = ProxiedHttpRequest(
            id: newID,
            hostName: targetHost,
            method: HttpMethodEnum(rawValue: httpMethod)!,
            path: path,
            headers: headers,
            rawRequest: rawRequest
        )
        
        DispatchQueue.main.async { [loggedRequest] in
            NotificationCenter.default.post(name: .newHttpRequest, object: loggedRequest)
        }
        
        return newID
    }
}

/** Adds a connection: close header*/
final class HttpCloseConnectionHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var requestPart = self.unwrapInboundIn(data)
        switch requestPart {
        case .head(var head):
            head.headers.replaceOrAdd(name: "Connection", value: "close")
            requestPart = .head(head)
        default:
            break
        }
        
        context.fireChannelRead(self.wrapInboundOut(requestPart))
    }
}

/** Removes any potential accept-encoding header */
final class HttpRemoveAcceptEncodingHeader: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var requestPart = self.unwrapInboundIn(data)
        switch requestPart {
        case .head(var head):
            head.headers.remove(name: "Accept-Encoding")
            requestPart = .head(head)
        default:
            break
        }
        
        context.fireChannelRead(self.wrapInboundOut(requestPart))
    }
}

/** Rewrites the connect request to the HTTP request */
final class HttpsConnectRewriteHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = ByteBuffer
    typealias OutboundOut = HTTPServerResponsePart
    
    var targetHost: String? = nil
    var hasEstablishedConnect: Bool = false
    
    var tunnelingActive: Bool = false
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)
        switch requestPart {
        case .head(var head):
            handleConnectRequest(context: context, head: &head)
        case .end:
            break
        default:
            fatalError("Should never be received by HttpsConnectRewriteHandler")
        }
    }
    
    private func handleConnectRequest(context: ChannelHandlerContext, head: inout HTTPRequestHead) {
        let uriComponents = head.uri.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        self.targetHost = String(uriComponents.first!)
        
        guard let targetHost = self.targetHost else {
            context.fireErrorCaught(HttpProxyUriRewriterError.targetHostInvalid)
            return
        }
        
        let selfSignedCertAndKey = CertificateManager.shared.certificateForDomain(String(targetHost))
        let selfSignedRootCa = try! CertificateManager.shared.loadRootCAFromKeychain()
        
        var serializer = DER.Serializer()
        try! serializer.serialize(selfSignedCertAndKey!.certificate)
        
        var selfSignedRootCaSerializer = DER.Serializer()
        try! selfSignedRootCaSerializer.serialize(selfSignedRootCa.rootCertificate)
        
        
        let certificate = try! NIOSSLCertificate(bytes: serializer.serializedBytes, format: .der)
        let privateKey = try! NIOSSLPrivateKey(bytes: [UInt8](selfSignedCertAndKey!.privateKey.derRepresentation), format: .der)
        let serverCert = NIOSSLCertificateSource.certificate(certificate)
        let rootCertificate = try! NIOSSLCertificate(bytes: selfSignedRootCaSerializer.serializedBytes, format: .der)
        let rootCert = NIOSSLCertificateSource.certificate(rootCertificate)
        let tlsConfiguration = TLSConfiguration.makeServerConfiguration(certificateChain: [serverCert, rootCert], privateKey: .privateKey(privateKey))
        let sslContext = try! NIOSSLContext(configuration: tlsConfiguration)
        
        let sslHandler = NIOSSLServerHandler(context: sslContext)
        
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
                context.pipeline.removeHandler(name: "ProxyPipelineHandler")
            }
        
            .flatMap { _ in
                context.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)), position: .first)
            }
            .flatMap { _ in
                context.pipeline.addHandler(HTTPResponseEncoder(), position: .first)
            }
            .flatMap { _ in
                context.pipeline.addHandler(sslHandler, position: .first)
            }
            .whenComplete { result in
                switch(result) {
                case .success():
                    print("Connection to \(targetHost) was successful")
                    _ = context.pipeline.removeHandler(self)
                    
                case .failure(let error):
                    print("Connection to \(targetHost) had error: \(error)")
                    context.close(promise: nil)
                }
            }
    }
    
    enum HttpProxyUriRewriterError: Error {
        case targetHostInvalid
    }
}

/** Rewrites the URI and host inside the unencrypted reverse proxy request */
final class HttpProxyUriRewriterHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    private var errorFired = false

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard !errorFired else {
            return
        }

        var requestPart = self.unwrapInboundIn(data)
        switch requestPart {
        case .head(var head):
            if let originalURI = URL(string: head.uri),
               let newHost = originalURI.host {
                head.headers.replaceOrAdd(name: "Host", value: newHost)
                head.uri = originalURI.relativePath
                requestPart = .head(head)
            } else {
                errorFired = true
                context.close(promise: nil)
                return
            }
        default:
            break
        }
        
        context.fireChannelRead(self.wrapInboundOut(requestPart))
    }
}

/** Handles the encrypted HTTP requests and responses */
final class EncryptedProxyHandler: UnencryptedProxyHandler {
    override init() {
        super.init()
        self.defaultPort = 443
    }
    
    override func clientBootstrap(context: ChannelHandlerContext, host: String, requestId: Int) -> ClientBootstrap {
        return ClientBootstrap(group: context.eventLoop).channelInitializer { channel in
            do {
                let sslContext = try NIOSSLContext(configuration: .makeClientConfiguration())
                let sslHandler = try NIOSSLClientHandler(context: sslContext, serverHostname: host)
                
                return channel.pipeline.addHandler(sslHandler).flatMap {
                    self.setupHandlers(channel: channel, context: context, requestId: requestId)
                }
            } catch {
                print("Failed to setup SSL handler:", error)
                return channel.eventLoop.makeFailedFuture(error)
            }
        }
    }
}

/** Handles the unencrypted HTTP requests and responses */
class UnencryptedProxyHandler: ChannelInboundHandler {
    typealias InboundIn = LoggedHTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    
    fileprivate var connectionEstablished = false
    fileprivate var remoteChannel: Channel?
    fileprivate var connectionPromise: EventLoopPromise<Void>?
    fileprivate var pendingData: [NIOAny] = []
    private var targetHost: String?
    private var targetPort: Int?
    internal var defaultPort = 80
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        print("\(String(describing: self)) Proxy Handler read called")
        
        let inboundIn = self.unwrapInboundIn(data)
        let requestPart = inboundIn.requestPart
        if case .head(let head) = requestPart, targetHost == nil, targetPort == nil {
            extractHostAndPort(from: head)
        }
        
        guard let targetHost = targetHost, let targetPort = targetPort else {
            print("Target host and port not found")
            return
        }
        
        if !connectionEstablished {
            pendingData.append(data)
            setupConnection(context: context, host: targetHost, port: targetPort, requestId: inboundIn.requestId)
        } else {
            writeToRemoteChannel(context: context, data: data)
        }
    }
    
    private func extractHostAndPort(from head: HTTPRequestHead) {
        if let hostHeader = head.headers["Host"].first {
            let hostAndPort = hostHeader.split(separator: ":", maxSplits: 1)
            targetHost = String(hostAndPort[0])
            if hostAndPort.count > 1, let port = Int(hostAndPort[1]) {
                targetPort = port
            } else {
                targetPort = defaultPort
            }
        }
    }
    
    private func setupConnection(context: ChannelHandlerContext, host: String, port: Int, requestId: Int) {
        guard connectionPromise == nil else { return }
        
        connectionPromise = context.eventLoop.makePromise(of: Void.self)
        connectionPromise!.futureResult.whenSuccess {
            self.connectionEstablished = true
            self.pendingData.forEach { data in
                self.writeToRemoteChannel(context: context, data: data)
            }
            self.pendingData.removeAll()
        }
        
        let channelFuture = clientBootstrap(context: context, host: host, requestId: requestId).connect(host: host, port: port)
        
        channelFuture.whenSuccess { channel in
            print("\(String(describing: self)): Channel to client has been established")
            self.remoteChannel = channel
            self.connectionPromise?.succeed(())
        }
    }
    
    fileprivate func clientBootstrap(context: ChannelHandlerContext, host: String, requestId: Int) -> ClientBootstrap {
        return ClientBootstrap(group: context.eventLoop).channelInitializer { channel in
            self.setupHandlers(channel: channel, context: context, requestId: requestId)
        }
    }
    
    fileprivate func setupHandlers(channel: Channel, context: ChannelHandlerContext, requestId: Int) -> EventLoopFuture<Void> {
        return channel.pipeline.addHandlers([
            HTTPRequestEncoder(),
            ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .forwardBytes)),
            ResponseForwarder(originalChannel: context.channel, requestId: requestId)
        ])
    }
    
    fileprivate func writeToRemoteChannel(context: ChannelHandlerContext, data: NIOAny) {
        guard let remoteChannel = remoteChannel else {
            print("Remote channel is not available")
            return
        }
        
        let inboundIn = self.unwrapInboundIn(data)
        let originalRequest = inboundIn.requestPart
        var clientReqPart: HTTPClientRequestPart
        switch(originalRequest) {
        case .head(let head):
            clientReqPart = HTTPClientRequestPart.head(head)
        case .body(let buffer):
            clientReqPart = HTTPClientRequestPart.body(.byteBuffer(buffer))
        case .end(let headers):
            clientReqPart = HTTPClientRequestPart.end(headers)
        }
        
        remoteChannel.writeAndFlush(clientReqPart, promise: nil)
    }
}

/** Forwards the response back to the client */
final class ResponseForwarder: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias InboundOut = ProxiedHttpResponse
    
    private let originalChannel: Channel
    private var endSent: Bool = false
    private let requestId: Int
    private var responseParts: [HTTPServerResponsePart] = []
    private var headers: Dictionary<String, Set<String>> = [:]
    
    init(
        originalChannel: Channel,
        requestId: Int
    ) {
        self.originalChannel = originalChannel
        self.requestId = requestId
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        if endSent {
            let httpReply = RequestConverter.partToRaw(responseParts: responseParts)
            let replyNotification = HttpReplyReceivedNotificationMessage(
                id: self.requestId,
                rawHttpReply: httpReply,
                headers: self.headers
            )
            NotificationCenter.default.post(name: .httpReplyReceived, object: replyNotification)
            
            context.fireChannelReadComplete()
            context.close(promise: nil)
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let responsePart = unwrapInboundIn(data)
        let httpServerResponsePart: HTTPServerResponsePart
        
        switch responsePart {
        case .head(let head):
            httpServerResponsePart = .head(head)
            for header in head.headers {
                let key = header.name
                let value = header.value
                
                if headers[key] == nil {
                    headers[key] = Set<String>()
                }
                headers[key]?.insert(value)
            }
        case .body(let buffer):
            httpServerResponsePart = .body(.byteBuffer(buffer))
        case .end(let headers):
            httpServerResponsePart = .end(headers)
            endSent = true
        }
        
        self.responseParts.append(httpServerResponsePart)
        originalChannel.writeAndFlush(httpServerResponsePart, promise: nil)
    }
}
