//
//  VideoViewController.swift
//  WebRTC
//
//  Created by Stas Seldin on 21/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import UIKit

class VideoViewController: UIViewController {

    @IBOutlet weak var localVideoView: UIView!
    private let webRTCClient: WebRTCClient
    
    init(webRTCClient: WebRTCClient) {
        self.webRTCClient = webRTCClient
        super.init(nibName: String(describing: VideoViewController.self), bundle: Bundle.main)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if arch(arm64)
            // Using metal (arm64 only)
            let localRenderer = RTCMTLVideoView(frame: self.localVideoView.frame)
            localRenderer.videoContentMode = .scaleAspectFill
            let remoteRenderer = RTCMTLVideoView(frame: self.view.frame)
            remoteRenderer.videoContentMode = .scaleAspectFill

        #else
            // Using OpenGLES for the rest
            let localRenderer = RTCEAGLVideoView(frame: self.localVideoView.frame)
            let remoteRenderer = RTCEAGLVideoView(frame: self.view.frame)
        #endif

        
        self.webRTCClient.startCaptureLocalVideo(renderer: localRenderer)
        self.webRTCClient.renderRemoteVideo(to: remoteRenderer)
        
        self.embedView(localRenderer, into: self.localVideoView)
        self.embedView(remoteRenderer, into: self.view)
        self.view.sendSubview(toBack: remoteRenderer)
    }
    
    func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view":view]))
        
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view":view]))
        containerView.layoutIfNeeded()
    }
    
    @IBAction func backDidTap(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
