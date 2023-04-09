import Foundation
import HttpParser
import Network

public class Server {
    static let sharedInstance = Server()
    private init(){}
    
    private var listener: NWListener? = nil
    
    internal func stopListener() {
        listener?.cancel()
        listener = nil
    }
    
    public var isInterceptEnabled = false
    
    internal func startListener(port: Int) throws {
        listener = try NWListener(
            using: .tcp,
            on: NWEndpoint.Port(String(port))!
        )
        
        guard let unwrappedListener = listener else {
            return
        }
        
        unwrappedListener.newConnectionHandler = { connection in
            var remoteConnection: NWConnection? = nil
            func readData() {
                
                connection.receive(minimumIncompleteLength: 0, maximumLength: 100_000_000)
                {
                    data, context, isComplete, error in
                    
                    if(error != nil) {
                        print("cancel")
                        return
                    }
                    
                    if(data == nil) {
                        print("cancel")
                        return
                    }
                    
                    let request = String(decoding: data!, as: UTF8.self)
                    
                    let httpParser: HttpParser = HttpParser()
                    let parsedRequest = httpParser.parseRequest(request)
                    
                    
                    // FIXME: error handling
                    let hostName = parsedRequest.headers!["Host"]!.first!
                    
                    
                    var fixedRequest = request
                    // Rewrite URIs to relative
                    if let range = fixedRequest.range(of:"http://" + hostName) {
                        fixedRequest = fixedRequest.replacingCharacters(in: range, with:"")
                    }
                    
                    // Remove Keep-Alive header
                    if let range = fixedRequest.range(of:"Connection: keep-alive\r\n") {
                        fixedRequest = fixedRequest.replacingCharacters(in: range, with:"")
                        // FIXME: We are closing the connection as we don't properly parse the HTTP response packets
                        fixedRequest.insert(contentsOf: "Connection: close\r\n", at: range.lowerBound)
                    }
                    
                    // Remove Accept-Encoding
                    if let range = fixedRequest.range(of:"Accept-Encoding: gzip, deflate\r\n") {
                        fixedRequest = fixedRequest.replacingCharacters(in: range, with: "")
                    }
                    
                    let loggedRequest = ProxiedHttpRequest()
                    loggedRequest.hostName = hostName
                    loggedRequest.method = HttpMethodEnum.GET
                    
                    if let range = parsedRequest.target!.range(of:"http://" + hostName) {
                        loggedRequest.path = parsedRequest.target!.replacingCharacters(in: range, with:"")
                    }
                    loggedRequest.rawRequest = fixedRequest

                    let group = DispatchGroup()
                    group.enter()
    
                    DispatchQueue.main.async {
                        if(self.isInterceptEnabled) {
                            NotificationCenter.default.post(name: .newAttemptedHttpRequest, object: (group: group, request: loggedRequest))
                        } else {
                            group.leave()
                        }
                    }

                    group.notify(queue: DispatchQueue.global()) {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .newHttpRequest, object: loggedRequest)
                        }
                        
                        let remoteHost: NWEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(hostName), port: 80)
                        
                        if(remoteConnection == nil) {
                            remoteConnection = NWConnection(to: remoteHost, using: .tcp)
                            remoteConnection!.start(queue: .main)
                        }
                        
                        let requestForUpstream = loggedRequest.rawRequest.data(using: .utf8)
                        remoteConnection!.send(content: requestForUpstream, completion: .idempotent)
                        
                        func receiveFromUpstream(request: ProxiedHttpRequest) {
                            remoteConnection!.receive(minimumIncompleteLength: 0, maximumLength: 1_000_000_000) { (data, context, isComplete, error) in
                                if(data != nil) {
                                    let fullReply = String(decoding: data!, as: UTF8.self)
                                    let response: ProxiedHttpResponse = ProxiedHttpResponse()
                                    response.rawResponse = (request.response?.rawResponse ?? "") + fullReply
                                    request.response = response
                                }
                                
                                connection.send(content: data, completion: .contentProcessed({ sendError in
                                    if(error == nil) {
                                        receiveFromUpstream(request: request)
                                    }
                                }))
                            }
                        }
                        
                        receiveFromUpstream(request: loggedRequest)
                    }
                    
                    if(error == nil) {
                        readData()
                    }
                }
            }
            
            connection.start(queue: .main)
            readData()
        }
        
        unwrappedListener.stateUpdateHandler = { newState in
            print("listener.stateUpdateHandler \(newState)")
            switch(newState) {
            case .failed(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .proxyError, object: error)
                }
                break;
            default:
                break;
            }
        }
        
        unwrappedListener.start(queue: .main)
    }
}
