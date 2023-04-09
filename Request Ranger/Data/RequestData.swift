import Foundation

enum HttpMethodEnum {
    case GET
}

class ProxiedHttpResponse: Identifiable, ObservableObject {
    @Published var id = UUID()
    @Published var rawResponse = ""
}

class ProxiedHttpRequest : Identifiable, ObservableObject {
    @Published var id = UUID()
    @Published var hostName: String = ""
    @Published var method: HttpMethodEnum = HttpMethodEnum.GET
    @Published var path: String = ""
    @Published var rawRequest: String = ""
    @Published var response: ProxiedHttpResponse?
}

class ProxyData: ObservableObject {
    @Published var httpRequests: Array<ProxiedHttpRequest> = []
}
