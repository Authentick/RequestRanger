import Foundation
import NIOHTTP1

enum HttpMethodEnum: String {
    case GET
    case PUT
    case ACL
    case HEAD
    case POST
    case COPY
    case LOCK
    case MOVE
    case BIND
    case LINK
    case PATCH
    case TRACE
    case MKCOL
    case MERGE
    case PURGE
    case NOTIFY
    case SEARCH
    case UNLOCK
    case REBIND
    case UNBIND
    case REPORT
    case DELETE
    case UNLINK
    case CONNECT
    case MSEARCH
    case OPTIONS
    case PROPFIND
    case CHECKOUT
    case PROPPATCH
    case SUBSCRIBE
    case MKCALENDAR
    case MKACTIVITY
    case UNSUBSCRIBE
    case SOURCE
}

class ProxiedHttpResponse: Identifiable, ObservableObject {
    @Published var id = UUID()
    @Published var rawResponse: String
    @Published var headers: Dictionary<String, Set<String>>

    init(rawResponse: String, headers: Dictionary<String, Set<String>>) {
        self.rawResponse = rawResponse
        self.headers = headers
    }
}

class ProxiedHttpRequest : Identifiable, ObservableObject {
    @Published var id: Int
    var idString: String { String(id) }
    @Published var hostName: String
    @Published var method: HttpMethodEnum
    var methodString: String { method.rawValue }
    @Published var path: String
    @Published var headers: Dictionary<String, Set<String>>
    @Published var rawRequest: String
    @Published var response: ProxiedHttpResponse?
    
    init(
        id: Int,
        hostName: String,
        method: HttpMethodEnum,
        path: String,
        headers: Dictionary<String, Set<String>>,
        rawRequest: String,
        response: ProxiedHttpResponse? = nil
    ) {
        self.id = id
        self.hostName = hostName
        self.method = method
        self.path = path
        self.headers = headers
        self.rawRequest = rawRequest
        self.response = response
    }
}

class ProxyData: ObservableObject {
    @Published var httpRequests: Array<ProxiedHttpRequest> = []
}
