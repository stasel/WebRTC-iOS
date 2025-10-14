import Foundation

enum Role: String, CaseIterable {
    case stage
    case viewer // "client" normalizes to viewer on the server
}

struct Config {
    static let signalingHost = "signaling.fideliodesign.com"
    static let defaultRoomId = "euterpe"
    static let defaultPeerId = "ios-client"
    static let apiKey: String? = "supersecret123" // set if your server runs in APIKEY mode

    static func wsURL(roomId: String, peerId: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "wss"
        comps.host = signalingHost
        comps.path = "/ws/\(roomId)/\(peerId)"
        var query: [URLQueryItem] = []
        if let apiKey { query.append(URLQueryItem(name: "key", value: apiKey)) }
        comps.queryItems = query.isEmpty ? nil : query
        return comps.url!
    }
}
