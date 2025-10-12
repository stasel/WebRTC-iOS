import Foundation
import WebRTC
import AVFoundation

protocol WebRTCClientDelegate: AnyObject {
    func webRTCDidChangeConnectionState(_ state: RTCPeerConnectionState)
    func webRTC(didAddRemoteStream stream: RTCMediaStream)
    func webRTC(didReceiveCandidate candidate: RTCIceCandidate)
}

final class WebRTCClient: NSObject {
    private let factory: RTCPeerConnectionFactory
    private let pc: RTCPeerConnection
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoSource: RTCVideoSource?
    private var localVideoTrack: RTCVideoTrack?
    private var capturer: RTCCameraVideoCapturer?
    weak var delegate: WebRTCClientDelegate?
    private weak var remoteRenderer: RTCVideoRenderer?

    init(iceServers: [String] = ["stun:stun.l.google.com:19302"]) {
        RTCInitializeSSL()
        let enc = RTCDefaultVideoEncoderFactory()
        let dec = RTCDefaultVideoDecoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: enc, decoderFactory: dec)

        let config = RTCConfiguration()
        config.iceServers = iceServers.map { RTCIceServer(urlStrings: [$0]) }
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement":"true"])
        
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            fatalError("Failed to create RTCPeerConnection")
        }
        self.pc = pc
        
        super.init()
        pc.delegate = self
        setupTransceivers()
    }

    func close() {
        if let renderer = remoteRenderer {
            // if you kept a reference to the current remote track, remove it:
            // currentRemoteVideoTrack?.remove(renderer)
        }
        pc.close()
        RTCCleanupSSL()
    }

    private func setupTransceivers() {
        // Audio
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let track = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack = track
        _ = pc.add(track, streamIds: ["stream0"])

        // Prepare a recvonly video transceiver (remote video even if camera off)
        _ = pc.addTransceiver(of: .video)
    }

    // MARK: Camera
    func startCapture(in view: RTCMTLVideoView, position: AVCaptureDevice.Position = .front) {
        if capturer == nil {
            localVideoSource = factory.videoSource()
            capturer = RTCCameraVideoCapturer(delegate: localVideoSource!)
            localVideoTrack = factory.videoTrack(with: localVideoSource!, trackId: "video0")
            _ = pc.add(localVideoTrack!, streamIds: ["stream0"])
        }

        view.videoContentMode = .scaleAspectFit
        localVideoTrack?.add(view) // keep a weak ref to view if you want to remove it later

        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == position }) else { return }
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        guard let format = formats.sorted(by: {
            let w0 = CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
            let w1 = CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
            return w0 < w1
        }).last else { return }

        let maxFps = Int(format.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 30)
        capturer?.startCapture(with: device, format: format, fps: min(maxFps, 30))
    }

    func stopCapture() {
        // 1) Stop the camera
        guard let capturer = self.capturer else { return }
        capturer.stopCapture { [weak self] in
            guard let self = self else { return }

            // 2) Remove the local video track from the peer connection
            if let localVideoTrack = self.localVideoTrack {
                if let sender = self.pc.senders.first(where: { $0.track == localVideoTrack }) {
                    self.pc.removeTrack(sender)
                }
                // (Optional) If you kept a reference to the local preview view:
                // localVideoTrack.remove(self.localRenderView)
            }

            // 3) Clear references
            self.localVideoTrack = nil
            self.localVideoSource = nil
            self.capturer = nil
        }
    }

    // MARK: Offer/Answer
    func makeOffer(completion: @escaping (RTCSessionDescription) -> Void) {
        let cons = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio":"true","OfferToReceiveVideo":"true"],
                                       optionalConstraints: nil)
        pc.offer(for: cons) { [weak self] sdp, err in
            guard let self, let sdp else { return }
            self.pc.setLocalDescription(sdp) { _ in completion(sdp) }
        }
    }

    func applyAnswer(_ sdp: RTCSessionDescription, completion: @escaping () -> Void) {
        pc.setRemoteDescription(sdp) { error in
            if let error = error {
                print("Failed to set remote description: \(error)")
            }
            completion()
        }
    }

    func applyRemoteOffer(
        _ sdp: RTCSessionDescription,
        answer: @escaping (RTCSessionDescription) -> Void
    ) {
        pc.setRemoteDescription(sdp) { [weak self] error in
            guard let self else { return }
            if let error = error {
                print("Failed to set remote description: \(error)")
                return
            }

            let cons = RTCMediaConstraints(
                mandatoryConstraints: [
                    "OfferToReceiveAudio": "true",
                    "OfferToReceiveVideo": "true"
                ],
                optionalConstraints: nil
            )

            self.pc.answer(for: cons) { sdp, _ in
                guard let sdp else { return }
                self.pc.setLocalDescription(sdp) { _ in
                    answer(sdp)
                }
            }
        }
    }

    // MARK: ICE
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        pc.add(candidate) { error in
            if let error = error {
                print("❌ Failed to add ICE candidate: \(error)")
            } else {
                print("✅ ICE candidate added successfully")
            }
        }
    }

    // Expose local/remote rendering hookup
    func attachRemote(to view: RTCMTLVideoView) {
        view.videoContentMode = .scaleAspectFit
        remoteRenderer = view
    }
}

/// Simple adapter so we can attach RTCMTLVideoView as the remote renderer
final class RTCVideoRendererAdapter: NSObject, RTCVideoRenderer {
    private weak var view: RTCMTLVideoView?
    init(_ view: RTCMTLVideoView) { self.view = view }
    func setSize(_ size: CGSize) { /* RTCMTLVideoView handles internally */ }
    func renderFrame(_ frame: RTCVideoFrame?) { view?.renderFrame(frame) }
}


extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange stateChanged: RTCPeerConnectionState) {
        print("Peer connection state changed: \(stateChanged)")
        
        delegate?.webRTCDidChangeConnectionState(stateChanged)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didAdd stream: RTCMediaStream) {
        print("Did add stream: \(stream.streamId)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didRemove stream: RTCMediaStream) {
        print("Did remove stream: \(stream.streamId)")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange newState: RTCSignalingState) {
        print("Signaling state changed: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didGenerate candidate: RTCIceCandidate) {
        print("Generated ICE candidate: \(candidate.sdpMid ?? "")")
        
        delegate?.webRTC(didReceiveCandidate: candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didRemove candidates: [RTCIceCandidate]) {
        print("Removed ICE candidates: \(candidates.count)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened: \(dataChannel.label)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange localCandidate: RTCIceConnectionState) {
        print("ICE connection state changed: \(localCandidate)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed: \(newState)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didAdd rtpReceiver: RTCRtpReceiver,
                        streams: [RTCMediaStream]) {
        print("Did add RTP receiver: \(rtpReceiver)")
        
        if let track = rtpReceiver.track as? RTCVideoTrack,
           let renderer = remoteRenderer {
            track.add(renderer)
        }
    }
}
