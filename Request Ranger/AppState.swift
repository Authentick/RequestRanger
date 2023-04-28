import Foundation
import NIOHTTP1
import NIOCore
import NIOPosix
import Logging

class AppState: ObservableObject {
    @Published var proxyData = ProxyData()
    @Published var comparisonListData = ComparisonData()
    @Published var requestsPendingApproval: [RequestInterceptionHandler.PendingRequestNotification] = []
    @Published var isInterceptEnabled: Bool = false
    @Published var isProxyRunning = false
    @Published var showProxyStartError: Bool = false
    @Published var proxyStartErrorMessage: String? = nil
    
    var serverGroup: MultiThreadedEventLoopGroup? = nil
    
    static let shared = AppState()
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewHttpRequest(notification:)), name: .newHttpRequest, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleHttpReplyReceived(notification:)), name: .httpReplyReceived, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAddCompareEntry(notification:)), name: .addCompareEntry, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePendingRequest(notification:)), name: .pendingRequest, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProxyRun(notification:)), name: .proxyRunCommand, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleProxyRun(notification: Notification) {
        DispatchQueue.global(qos: .background).async {
            if(self.isProxyRunning) {
                try! self.serverGroup?.syncShutdownGracefully()
                DispatchQueue.main.async {
                    self.isProxyRunning = false
                }
            } else {
                self.startNioServer()
                DispatchQueue.main.async {
                    self.isProxyRunning = true
                }
            }
        }
    }
    
    private func startNioServer() {
        let logger = Logger(label: "net.authentick.requestranger")
        
        serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let serverGroup else {
            fatalError("Server group should be initialized but isn't")
        }
        
        let bootstrap = ServerBootstrap(group: serverGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)), name: "HTTPRequestDecoder", position: .last)
                    .flatMap {
                        channel.pipeline.addHandler(HTTPResponseEncoder(), name: "HTTPResponseEncoder", position: .last)
                    }
                    .flatMap {
                        channel.pipeline.addHandler(ProxyPipelineHandler(), name: "ProxyPipelineHandler", position: .last)
                    }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        // Define the IP address and port where the server will listen
        let ipAddress = "127.0.0.1"
        let port = 8080
        
        // Start the server
        do {
            let channel = try bootstrap.bind(host: ipAddress, port: port).wait()
            logger.info("Server started and listening on \(channel.localAddress!)")
        } catch {
            logger.error("Failed to start server: \(error)")
            try? serverGroup.syncShutdownGracefully()
            exit(1)
        }
    }
    
    @objc func handleHttpReplyReceived(notification: Notification) {
        if let proxiedHttpReply = notification.object as? HttpReplyReceivedNotificationMessage {
            if let index = self.proxyData.httpRequests.firstIndex(where: { $0.id == proxiedHttpReply.id }) {
                let response = ProxiedHttpResponse(rawResponse:proxiedHttpReply.rawHttpReply , headers: proxiedHttpReply.headers)
                DispatchQueue.main.async {
                    self.proxyData.httpRequests[index].response = response
                }
            }
        }
    }
    
    @objc func handleNewHttpRequest(notification: Notification) {
        if let proxiedHttpRequest = notification.object as? ProxiedHttpRequest {
            DispatchQueue.main.async{
                self.proxyData.httpRequests.append(proxiedHttpRequest)
            }
        }
    }
    
    @objc func handleAddCompareEntry(notification: Notification) {
        if let text = notification.object as? String {
            let count = comparisonListData.data.count
            let comparisonEntry = ComparisonData.CompareEntry(id: count + 1, value: text)
            DispatchQueue.main.async{
                self.comparisonListData.data.append(comparisonEntry)
            }
        }
    }
    
    @objc func handlePendingRequest(notification: Notification) {
        if let pendingRequestNotification = notification.object as? RequestInterceptionHandler.PendingRequestNotification {
            
            DispatchQueue.main.async{
                self.requestsPendingApproval.append(pendingRequestNotification)
            }
        }
    }
}
