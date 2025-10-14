import SwiftUI
import AVFoundation
import WebRTC

extension RTCMTLVideoView {
    func clearFrame() {
        renderFrame(nil)
    }
}

final class RoomsViewModel: NSObject, ObservableObject {

    // UI state
    @Published var roomId: String = Config.defaultRoomId
    @Published var peerId: String = Config.defaultPeerId
    @Published var role: Role = .viewer
    @Published var rosterText: String = "(room is empty)"
    @Published var isWSOpen: Bool = false
    @Published var hasRemotePeer: Bool = false
    @Published var cameraOn: Bool = false

    // Internals
    private let signaling = SignalingClient()
    private var rtc: WebRTCClient?

    private var roster: [String: Attendee] = [:]
    private var selfId: String { peerId }
    private var remotePeerId: String?

    // Video views (UIKit) provided by SwiftUI wrappers
    private weak var localView: RTCMTLVideoView?
    private weak var remoteView: RTCMTLVideoView?

    override init() {
        super.init()
        signaling.delegate = self
    }

    // MARK: UI bindings

    func bindLocalView(_ v: RTCMTLVideoView) {
        localView = v
        updateCameraFlag()
    }

    func bindRemoteView(_ v: RTCMTLVideoView) {
        remoteView = v
        // When the first remote track arrives, WebRTCClient will add(renderer)
    }

    // MARK: Actions

    func connectWS() {
        signaling.connect(roomId: roomId, peerId: peerId, role: role)
    }

    func hangupAll() {
        signaling.disconnect()
        rtc?.close()
        rtc = nil
        remotePeerId = nil
        roster.removeAll()
        rosterText = "(room is empty)"
        localView?.renderFrame(nil)
        remoteView?.renderFrame(nil)
        isWSOpen = false
        hasRemotePeer = false
        cameraOn = false
    }

    func startOrUpdateCall() {
        guard let remotePeerId else { return }
        ensureRTC()
        // attach remote renderer (once)
        if let remoteView { rtc?.attachRemote(to: remoteView) }

        rtc?.makeOffer { [weak self] offer in
            guard let self else { return }
            let payload: [String: Any] = [
                "type": "offer",
                "sdp": ["type":"offer", "sdp": offer.sdp]
            ]
            self.signaling.sendSignal(to: remotePeerId, signal: payload)
        }
    }

    func toggleCamera() {
        ensureRTC()
        if cameraOn {
            rtc?.stopCapture()
            localView?.renderFrame(nil)
            cameraOn = false
        } else {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                guard let self else { return }
                if ok {
                    DispatchQueue.main.async {
                        self.ensureRTC()
                        if let localView = self.localView {
                            self.rtc?.startCapture(in: localView, position: .front)
                            self.cameraOn = true
                        }
                    }
                }
            }
        }
    }

    func changeRole(_ r: Role) {
        role = r
        signaling.sendAttendeeUpdate(role: r)
    }

    // MARK: Helpers

    private func ensureRTC() {
        if rtc != nil { return }
        let client = WebRTCClient()
        client.delegate = self
        rtc = client
    }

    private func renderRoster() {
        let lines = roster.values.map { "• \($0.displayName ?? $0.peerId) (\($0.peerId)) [\($0.role ?? "-")]" }
        rosterText = lines.isEmpty ? "(room is empty)" : lines.joined(separator: "\n")
        hasRemotePeer = roster.keys.contains { $0 != selfId }
        if remotePeerId == nil {
            remotePeerId = roster.first(where: { $0.key != selfId })?.key
        }
    }

    private func updateCameraFlag() {
        // heuristic: if we have a localView and we started capture, flag true (track presence is in rtc)
        // Here we keep it driven by user toggle to avoid digging into tracks.
    }
}

// MARK: - SignalingClientDelegate

extension RoomsViewModel: SignalingClientDelegate {
    func signalingConnected() {
        DispatchQueue.main.async { self.isWSOpen = true }
    }

    func signalingClosed(code: URLSessionWebSocketTask.CloseCode?, reason: String?) {
        DispatchQueue.main.async {
            self.isWSOpen = false
            self.hasRemotePeer = false
        }
    }

    func signalingRoster(selfId: String, attendees: [Attendee]) {
        DispatchQueue.main.async {
            self.roster = Dictionary(uniqueKeysWithValues: attendees.map { ($0.peerId, $0) })
            self.renderRoster()
        }
    }

    func signalingAttendeeJoined(_ attendee: Attendee) {
        DispatchQueue.main.async {
            self.roster[attendee.peerId] = attendee
            self.renderRoster()
        }
    }

    func signalingAttendeeUpdated(_ attendee: Attendee) {
        DispatchQueue.main.async {
            self.roster[attendee.peerId] = attendee
            self.renderRoster()
        }
    }

    func signalingAttendeeLeft(peerId: String) {
        DispatchQueue.main.async {
            self.roster.removeValue(forKey: peerId)
            if self.remotePeerId == peerId { self.remotePeerId = nil }
            self.renderRoster()
        }
    }

    func signalingSignal(from: String, payload: [String : Any]) {
        ensureRTC()
        // Offer/Answer/Candidate routing
        if let type = payload["type"] as? String {
            switch type {
            case "offer":
                if let sdpObj = payload["sdp"] as? [String: Any],
                   let sdpStr = sdpObj["sdp"] as? String {
                    let desc = RTCSessionDescription(type: .offer, sdp: sdpStr)
                    rtc?.applyRemoteOffer(desc) { [weak self] answer in
                        guard let self else { return }
                        let ansPayload: [String: Any] = [
                            "type":"answer",
                            "sdp": ["type":"answer", "sdp": answer.sdp]
                        ]
                        if self.remotePeerId == nil { self.remotePeerId = from }
                        if let to = self.remotePeerId {
                            self.signaling.sendSignal(to: to, signal: ansPayload)
                        }
                    }
                }
            case "answer":
                if let sdpObj = payload["sdp"] as? [String: Any],
                   let sdpStr = sdpObj["sdp"] as? String {
                    let desc = RTCSessionDescription(type: .answer, sdp: sdpStr)
                    rtc?.applyAnswer(desc) { }
                }
            case "candidate":
                if let cand = payload["candidate"] as? [String: Any],
                   let sdp = cand["candidate"] as? String,
                   let sdpMLineIndex = cand["sdpMLineIndex"] as? Int32 {
                    let ice = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: cand["sdpMid"] as? String)
                    rtc?.addIceCandidate(ice)
                }
            default: break
            }
        }
    }

    func signalingRoomRoleError(message: String) {
        // Present however you like; for now just log
        print("Room role error: \(message)")
    }

    func signalingError(_ err: Error) {
        print("Signaling error: \(err)")
    }
}

// MARK: - WebRTCClientDelegate

extension RoomsViewModel: WebRTCClientDelegate {
    func webRTCDidChangeConnectionState(_ state: RTCPeerConnectionState) {
        // Optionally bind to UI
        print("PC state: \(state.rawValue)")
    }

    func webRTC(didAddRemoteStream stream: RTCMediaStream) {
        // If your WebRTCClient still surfaces Plan-B streams; for Unified Plan we add in the delegate below.
        if let track = stream.videoTracks.first, let remoteView = remoteView {
            track.add(remoteView)
        }
    }

    func webRTC(didReceiveCandidate candidate: RTCIceCandidate) {
        // Typical behavior: forward your local ICE candidate to the remote peer via signaling.
        // Example (adapt to your signaling layer):
        // TODO: signalingClient.send(localICE: candidate)
        // Or, if you buffer until remote description is set:
        // pendingLocalCandidates.append(candidate)
    }
}

