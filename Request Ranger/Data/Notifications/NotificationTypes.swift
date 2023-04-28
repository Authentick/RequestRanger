import Foundation

extension Notification.Name {
    static let newHttpRequest = Notification.Name("new_http_request")
    static let httpReplyReceived = Notification.Name("http_reply_received")
    static let newAttemptedHttpRequest = Notification.Name("new_attempted_http_request")
    static let proxyError = Notification.Name("proxy_connection_failure")
    static let proxyRunCommand = Notification.Name("proxy_run_command")
    static let addCompareEntry = Notification.Name("add_compare_entry")
    static let pendingRequest = Notification.Name("pending_request")
}
