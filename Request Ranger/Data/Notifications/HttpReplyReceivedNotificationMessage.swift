import Foundation

struct HttpReplyReceivedNotificationMessage {
    let id: Int
    let rawHttpReply: String
    let headers: Dictionary<String, Set<String>>
}
