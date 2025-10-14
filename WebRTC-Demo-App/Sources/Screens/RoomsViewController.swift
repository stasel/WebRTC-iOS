import UIKit
import WebRTC
import AVFoundation

final class RoomsViewController: UIViewController {

    // UI
    private let connectBtn = UIButton(type: .system)
    private let hangupBtn = UIButton(type: .system)
    private let startCallBtn = UIButton(type: .system)
    private let toggleCamBtn = UIButton(type: .system)
    private let roleSeg = UISegmentedControl(items: ["Stage","Viewer"])
    private let roomField = UITextField()
    private let peerField = UITextField()
    private let rosterView = UITextView()
    private let localView = RTCMTLVideoView()
    private let remoteView = RTCMTLVideoView()
    
    private var cameraOn = false

    // State
    private let signaling = SignalingClient()
    private var rtc: WebRTCClient?
    private var selfId: String = Config.defaultPeerId
    private var remotePeerId: String?
    private var roster: [String: Attendee] = [:]
    private var currentRole: Role = .viewer

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebRTC Rooms (iOS)"
        view.backgroundColor = .systemBackground
        layoutUI()
        wiring()

        signaling.delegate = self
        updateButtons()
    }

    private func layoutUI() {
        func styleButton(_ b: UIButton, title: String, danger: Bool = false) {
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            b.backgroundColor = danger ? .systemRed : .secondarySystemBackground
            b.tintColor = danger ? .white : .label
            b.layer.cornerRadius = 10
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        }

        styleButton(connectBtn, title: "Connect WS")
        styleButton(hangupBtn, title: "Hang Up", danger: true)
        styleButton(startCallBtn, title: "Start/Update Call")
        styleButton(toggleCamBtn, title: "Start Camera")

        roleSeg.selectedSegmentIndex = 1 // Viewer by default
        roomField.placeholder = "Room (e.g. euterpe)"
        roomField.text = Config.defaultRoomId
        peerField.placeholder = "Peer ID"
        peerField.text = Config.defaultPeerId
        rosterView.isEditable = false
        rosterView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        rosterView.layer.borderColor = UIColor.separator.cgColor
        rosterView.layer.borderWidth = 1
        rosterView.layer.cornerRadius = 8
        rosterView.text = "(room is empty)"

        [connectBtn, hangupBtn, startCallBtn, toggleCamBtn,
         roleSeg, roomField, peerField,
         rosterView, localView, remoteView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
         }

        // Simple grid layout
        NSLayoutConstraint.activate([
            connectBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            connectBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),

            hangupBtn.centerYAnchor.constraint(equalTo: connectBtn.centerYAnchor),
            hangupBtn.leadingAnchor.constraint(equalTo: connectBtn.trailingAnchor, constant: 8),

            startCallBtn.centerYAnchor.constraint(equalTo: connectBtn.centerYAnchor),
            startCallBtn.leadingAnchor.constraint(equalTo: hangupBtn.trailingAnchor, constant: 8),

            toggleCamBtn.centerYAnchor.constraint(equalTo: connectBtn.centerYAnchor),
            toggleCamBtn.leadingAnchor.constraint(equalTo: startCallBtn.trailingAnchor, constant: 8),

            roomField.topAnchor.constraint(equalTo: connectBtn.bottomAnchor, constant: 10),
            roomField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            roomField.widthAnchor.constraint(equalToConstant: 160),

            peerField.centerYAnchor.constraint(equalTo: roomField.centerYAnchor),
            peerField.leadingAnchor.constraint(equalTo: roomField.trailingAnchor, constant: 8),
            peerField.widthAnchor.constraint(equalToConstant: 160),

            roleSeg.centerYAnchor.constraint(equalTo: roomField.centerYAnchor),
            roleSeg.leadingAnchor.constraint(equalTo: peerField.trailingAnchor, constant: 8),

            rosterView.topAnchor.constraint(equalTo: roomField.bottomAnchor, constant: 10),
            rosterView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            rosterView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            rosterView.heightAnchor.constraint(equalToConstant: 70),

            localView.topAnchor.constraint(equalTo: rosterView.bottomAnchor, constant: 12),
            localView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            localView.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -6),
            localView.heightAnchor.constraint(equalTo: localView.widthAnchor, multiplier: 3/4),

            remoteView.topAnchor.constraint(equalTo: rosterView.bottomAnchor, constant: 12),
            remoteView.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 6),
            remoteView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            remoteView.heightAnchor.constraint(equalTo: remoteView.widthAnchor, multiplier: 3/4),
        ])

        localView.videoContentMode = .scaleAspectFit
        remoteView.videoContentMode = .scaleAspectFit
    }

    private func wiring() {
        connectBtn.addTarget(self, action: #selector(onConnect), for: .touchUpInside)
        hangupBtn.addTarget(self, action: #selector(onHangup), for: .touchUpInside)
        startCallBtn.addTarget(self, action: #selector(onStartCall), for: .touchUpInside)
        toggleCamBtn.addTarget(self, action: #selector(onToggleCam), for: .touchUpInside)
        roleSeg.addTarget(self, action: #selector(onRoleChanged), for: .valueChanged)
    }

    private func ensureRTC() {
        if rtc != nil { return }
        rtc = WebRTCClient()
        rtc?.delegate = self
    }

    private func updateButtons() {
        let ws = signaling.isOpen
        hangupBtn.isEnabled = ws
        startCallBtn.isEnabled = ws && remotePeerId != nil
        toggleCamBtn.isEnabled = ws
        connectBtn.isEnabled = !ws
        toggleCamBtn.setTitle(isCameraOn() ? "Stop Camera" : "Start Camera", for: .normal)
    }

    private func isCameraOn() -> Bool {
        cameraOn
    }

    // MARK: Actions
    @objc private func onConnect() {
        view.endEditing(true)
        currentRole = (roleSeg.selectedSegmentIndex == 0) ? .stage : .viewer
        selfId = peerField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? peerField.text! : Config.defaultPeerId
        let room = roomField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? roomField.text! : Config.defaultRoomId
        signaling.connect(roomId: room, peerId: selfId, role: currentRole)
        updateButtons()
    }

    @objc private func onHangup() {
        stopAll()
    }

    @objc private func onStartCall() {
        guard let remotePeerId else { return }
        ensureRTC()
        rtc?.attachRemote(to: remoteView)
        rtc?.makeOffer { [weak self] offer in
            guard let self else { return }
            let payload: [String: Any] = [
                "type": "offer",
                "sdp": ["type":"offer", "sdp": offer.sdp]
            ]
            self.signaling.sendSignal(to: remotePeerId, signal: payload)
        }
        updateButtons()
    }

    @objc private func onToggleCam() {
        if rtc == nil { ensureRTC() }   // don't return here
        guard let rtc = rtc else { return }

        if isCameraOn() {
            rtc.stopCapture()
            // clear preview
            localView.renderFrame(nil)  // or localView.clearFrame()
            cameraOn = false
            DispatchQueue.main.async {
                self.updateButtons()
            }
            return
        } else {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                guard let self else { return }
                if ok {
                    DispatchQueue.main.async {
                        if self.rtc == nil { self.ensureRTC() }
                        self.rtc?.startCapture(in: self.localView, position: .front)
                    }
                } else {
                    // Optional: show a permission alert
                }
            }
        }
        updateButtons()
    }

    @objc private func onRoleChanged() {
        currentRole = (roleSeg.selectedSegmentIndex == 0) ? .stage : .viewer
        signaling.sendAttendeeUpdate(role: currentRole)
    }

    private func stopAll() {
        signaling.disconnect()
        rtc?.close()
        rtc = nil
        remotePeerId = nil
        roster.removeAll()
        rosterView.text = "(room is empty)"
        localView.clearFrame()
        remoteView.clearFrame()
        updateButtons()
    }

    private func renderRoster() {
        let lines = roster.values.map { "• \($0.displayName ?? $0.peerId) (\($0.peerId)) [\($0.role ?? "-")]" }
        rosterView.text = lines.isEmpty ? "(room is empty)" : lines.joined(separator: "\n")
    }
}

extension RoomsViewController: SignalingClientDelegate {
    func signalingConnected() {
        DispatchQueue.main.async {
            self.updateButtons()
        }
    }

    func signalingClosed(code: URLSessionWebSocketTask.CloseCode?, reason: String?) {
        DispatchQueue.main.async {
            self.updateButtons()
            if let reason, !reason.isEmpty { print("WS closed: \(reason)") }
        }
    }

    func signalingRoster(selfId: String, attendees: [Attendee]) {
        DispatchQueue.main.async {
            self.roster = Dictionary(uniqueKeysWithValues: attendees.map { ($0.peerId, $0) })
            self.renderRoster()
            self.remotePeerId = attendees.first(where: { $0.peerId != self.selfId })?.peerId
            self.updateButtons()
        }
    }

    func signalingAttendeeJoined(_ attendee: Attendee) {
        DispatchQueue.main.async {
            self.roster[attendee.peerId] = attendee
            self.renderRoster()
            if attendee.peerId != self.selfId, self.remotePeerId == nil {
                self.remotePeerId = attendee.peerId
            }
            self.updateButtons()
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
            self.updateButtons()
        }
    }

    func signalingSignal(from: String, payload: [String : Any]) {
        ensureRTC()
        if let type = payload["type"] as? String {
            switch type {
            case "offer":
                if let sdpObj = payload["sdp"] as? [String: Any],
                   let sdpStr = sdpObj["sdp"] as? String {
                    let desc = RTCSessionDescription(type: .offer, sdp: sdpStr)
                    rtc?.applyRemoteOffer(desc) { [weak self] answer in
                        guard let self else { return }
                        let ansPayload: [String: Any] = ["type":"answer",
                                                         "sdp": ["type":"answer", "sdp": answer.sdp]]
                        self.signaling.sendSignal(to: from, signal: ansPayload)
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
                   let sdpMid = cand["sdpMid"] as? String?,
                   let sdpMLineIndex = cand["sdpMLineIndex"] as? Int32,
                   let sdp = cand["candidate"] as? String {
                    let ice = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                    rtc?.addIceCandidate(ice)
                }
            default:
                break
            }
        }
        
        DispatchQueue.main.async {
            self.updateButtons()
        }
    }

    func signalingRoomRoleError(message: String) {
        let alert = UIAlertController(title: "Room Role Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func signalingError(_ err: Error) {
        print("Signaling error: \(err)")
    }
}

extension RoomsViewController: WebRTCClientDelegate {
    func webRTCDidChangeConnectionState(_ state: RTCPeerConnectionState) {
        print("PC state: \(state.rawValue)")
        updateButtons()
    }
    func webRTC(didAddRemoteStream stream: RTCMediaStream) {
        DispatchQueue.main.async {
            if let video = stream.videoTracks.first {
                video.add(self.remoteView)
            }
        }
    }
    func webRTC(didReceiveCandidate candidate: RTCIceCandidate) {
        guard let to = remotePeerId else { return }
        let payload: [String: Any] = [
            "type": "candidate",
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMid": candidate.sdpMid as Any,
                "sdpMLineIndex": candidate.sdpMLineIndex
            ]
        ]
        signaling.sendSignal(to: to, signal: payload)
    }
}

