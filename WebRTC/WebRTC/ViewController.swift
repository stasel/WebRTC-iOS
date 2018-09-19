//
//  ViewController.swift
//  WebRTC
//
//  Created by Stas Seldin on 20/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    let signalClient = SignalClient()
    let webRTCClient = WebRTCClient()
    
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var signalingStatusLabel: UILabel!
    @IBOutlet weak var localSdpStatusLabel: UILabel!
    @IBOutlet weak var localCandidatesLabel: UILabel!
    @IBOutlet weak var remoteSdpStatusLabel: UILabel!
    @IBOutlet weak var remoteCandidatesLabel: UILabel!
    @IBOutlet weak var muteButton: UIButton!
    
    var signalingConnected: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.signalingConnected {
                    self.signalingStatusLabel.text = "Connected"
                    self.signalingStatusLabel.textColor = UIColor.green
                }
                else {
                    self.signalingStatusLabel.text = "Not connected"
                    self.signalingStatusLabel.textColor = UIColor.red
                }
            }
        }
    }
    
    var hasLocalSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.localSdpStatusLabel.text = self.hasLocalSdp ? "✅" : "❌"
            }
        }
    }
    
    var localCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.localCandidatesLabel.text = "\(self.localCandidateCount)"
            }
        }
    }
    
    var hasRemoteSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.remoteSdpStatusLabel.text = self.hasRemoteSdp ? "✅" : "❌"
            }
        }
    }
    
    var remoteCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.remoteCandidatesLabel.text = "\(self.remoteCandidateCount)"
            }
        }
    }
    
    var speakerOn: Bool = false {
        didSet {
            let title = "Speaker: \(self.speakerOn ? "On" : "Off" )"
            self.speakerButton.setTitle(title, for: .normal)
        }
    }
    
    var mute: Bool = false {
        didSet {
            let title = "Mute: \(self.mute ? "on" : "off")"
            self.muteButton.setTitle(title, for: .normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.signalingConnected = false
        self.hasLocalSdp = false
        self.hasRemoteSdp = false
        self.localCandidateCount = 0
        self.remoteCandidateCount = 0
        self.speakerOn = false
        
        self.signalClient.connect()
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
    }
    
    @IBAction func offerDidTap(_ sender: UIButton) {
        self.webRTCClient.offer { (sdp) in
            self.hasLocalSdp = true
            self.signalClient.send(sdp: sdp)
        }
    }
    
    @IBAction func answerDidTap(_ sender: UIButton) {
        self.webRTCClient.answer { (localSdp) in
            self.hasLocalSdp = true
            self.signalClient.send(sdp: localSdp)
        }
    }
    
    @IBAction func speakerDidTouch(_ sender: UIButton) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .videoChat, options: [])
            
            if self.speakerOn {
                try session.overrideOutputAudioPort(.none)
            }
            else {
                try session.overrideOutputAudioPort(.speaker)
            }
            
            try session.setActive(true)
            self.speakerOn = !self.speakerOn
        }
        catch let error {
            print("Couldn't set audio to speaker: \(error)")
        }
    }
    
    @IBAction func videoDidTap(_ sender: UIButton) {
        let vc = VideoViewController(webRTCClient: self.webRTCClient)
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func muteDidTap(_ sender: UIButton) {
        self.mute = !self.mute
        if self.mute {
            self.webRTCClient.muteAudio()
        }
        else {
            self.webRTCClient.unmuteAudio()
        }
    }    
}

extension ViewController: SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalClient) {
        self.signalingConnected = true
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalClient) {
        self.signalingConnected = false
    }
    
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("Received remote sdp")
        self.webRTCClient.set(remoteSdp: sdp) { (error) in
            self.hasRemoteSdp = true
        }
    }
    
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate) {
        print("Received remote candidate")
        self.remoteCandidateCount += 1
        self.webRTCClient.set(remoteCandidate: candidate)
    }
}

extension ViewController: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("discovered local candidate")
        self.localCandidateCount += 1
        self.signalClient.send(candidate: candidate)

    }
}

