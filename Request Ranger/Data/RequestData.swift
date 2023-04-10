import Foundation

enum HttpMethodEnum: String {
    case GET = "GET"
}

class ProxiedHttpResponse: Identifiable, ObservableObject {
    @Published var id = UUID()
    @Published var rawResponse: String
    
    init(rawResponse: String) {
        self.rawResponse = rawResponse
    }
}

class ProxiedHttpRequest : Identifiable, ObservableObject {
    @Published var id: Int
    var idString: String { String(id) }
    @Published var hostName: String
    @Published var method: HttpMethodEnum
    var methodString: String { method.rawValue }
    @Published var path: String
    @Published var rawRequest: String
    @Published var response: ProxiedHttpResponse?
    
    init(
        id: Int,
        hostName: String,
        method: HttpMethodEnum,
        path: String,
        rawRequest: String,
        response: ProxiedHttpResponse? = nil
    ) {
        self.id = id
        self.hostName = hostName
        self.method = method
        self.path = path
        self.rawRequest = rawRequest
        self.response = response
    }
}

class ProxyData: ObservableObject {
    @Published var httpRequests: Array<ProxiedHttpRequest> = []
}
