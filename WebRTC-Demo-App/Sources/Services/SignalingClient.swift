import Foundation

protocol SignalingClientDelegate: AnyObject {
    func signalingConnected()
    func signalingClosed(code: URLSessionWebSocketTask.CloseCode?, reason: String?)
    func signalingRoster(selfId: String, attendees: [Attendee])
    func signalingAttendeeJoined(_ attendee: Attendee)
    func signalingAttendeeUpdated(_ attendee: Attendee)
    func signalingAttendeeLeft(peerId: String)
    func signalingSignal(from: String, payload: [String: Any])
    func signalingRoomRoleError(message: String)
    func signalingError(_ err: Error)
}

struct Attendee: Codable {
    let peerId: String
    let displayName: String?
    let role: String?
    let avatarUrl: String?
    let capabilities: [String]?
}

final class SignalingClient: NSObject {
    private var ws: URLSessionWebSocketTask?
    private var session: URLSession!
    private var pingTimer: Timer?
    private(set) var roomId: String = ""
    private(set) var selfId: String = ""
    weak var delegate: SignalingClientDelegate?

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: OperationQueue())
    }

    var isOpen: Bool {
        guard let ws else { return false }
        return ws.state == .running
    }

    func connect(roomId: String, peerId: String, role: Role) {
        self.roomId = roomId
        self.selfId = peerId
        let url = Config.wsURL(roomId: roomId, peerId: peerId)
        let req = URLRequest(url: url)
        ws = session.webSocketTask(with: req)
        ws?.resume()
        listen()

        // Send join once .onopen is called (we don't get that in URLSession, so delay slightly)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.sendJoin(role: role)
        }

        startPing()
    }

    func disconnect() {
        stopPing()
        ws?.cancel(with: .normalClosure, reason: nil)
        ws = nil
    }

    func sendSignal(to targetPeerId: String, signal: [String: Any]) {
        let obj: [String: Any] = ["type": "signal", "to": targetPeerId, "signal": signal]
        sendJSON(obj)
    }

    func sendAttendeeUpdate(role: Role?) {
        var attendee: [String: Any] = [:]
        if let role { attendee["role"] = role.rawValue }
        let obj: [String: Any] = ["type": "attendee-update", "attendee": attendee]
        sendJSON(obj)
    }

    private func sendJoin(role: Role) {
        let attendee: [String: Any] = [
            "peerId": selfId,
            "displayName": selfId,
            "role": role.rawValue,
            "avatarUrl": "",
            "capabilities": ["cam","mic"]
        ]
        let obj: [String: Any] = ["type": "join", "attendee": attendee]
        sendJSON(obj)
    }

    private func sendJSON(_ obj: [String: Any]) {
        guard let ws else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: obj, options: [])
            ws.send(.data(data)) { [weak self] err in
                if let err { self?.delegate?.signalingError(err) }
            }
        } catch {
            delegate?.signalingError(error)
        }
    }

    private func listen() {
        ws?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let err):
                self.delegate?.signalingError(err)
            case .success(let msg):
                do {
                    let data: Data?
                    switch msg {
                    case .data(let d): data = d
                    case .string(let s): data = s.data(using: .utf8)
                    @unknown default: data = nil
                    }
                    if let data = data {
                        try self.handle(data: data)
                    }
                } catch {
                    self.delegate?.signalingError(error)
                }
                self.listen()
            }
        }
    }

    private func handle(data: Data) throws {
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
        guard let type = obj["type"] as? String else { return }

        switch type {
        case "roster":
            let selfId = obj["selfId"] as? String ?? ""
            let arr = (obj["attendees"] as? [[String: Any]] ?? [])
            let attendees = try JSONDecoder().decode([Attendee].self, from: JSONSerialization.data(withJSONObject: arr))
            delegate?.signalingRoster(selfId: selfId, attendees: attendees)

        case "attendee-joined":
            if let dict = obj["attendee"] as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: dict)
                let attendee = try JSONDecoder().decode(Attendee.self, from: data)
                delegate?.signalingAttendeeJoined(attendee)
            }

        case "attendee-updated":
            if let dict = obj["attendee"] as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: dict)
                let attendee = try JSONDecoder().decode(Attendee.self, from: data)
                delegate?.signalingAttendeeUpdated(attendee)
            }

        case "attendee-left":
            if let pid = obj["peerId"] as? String {
                delegate?.signalingAttendeeLeft(peerId: pid)
            }

        case "signal":
            guard let from = obj["from"] as? String,
                  let payload = obj["signal"] as? [String: Any] else { return }
            delegate?.signalingSignal(from: from, payload: payload)

        case "room-role-error":
            let message = obj["message"] as? String ?? "Role rejected"
            delegate?.signalingRoomRoleError(message: message)

        default:
            break
        }
    }

    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self, let ws = self.ws else { return }
            // app-level ping (server updates last_seen on any msg too)
            ws.send(.string(#"{"type":"ping"}"#)) { _ in }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

extension SignalingClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        delegate?.signalingConnected()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) }
        delegate?.signalingClosed(code: closeCode, reason: reasonStr)
    }
}
