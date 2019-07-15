//
//  AppDelegate.swift
//  WebRTC
//
//  Created by Stasel on 20/05/2018.
//  Copyright © 2018 Stasel. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    internal var window: UIWindow?
    private let config = Config.default
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = self.buildMainViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    
    private func buildMainViewController() -> UIViewController {
        let signalClient = SignalingClient(serverUrl: self.config.signalingServerUrl)
        let webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers)
        let mainViewController = MainViewController(signalClient: signalClient,
                                                    webRTCClient: webRTCClient)
        let navViewController = UINavigationController(rootViewController: mainViewController)
        if #available(iOS 11.0, *) {
            navViewController.navigationBar.prefersLargeTitles = true
        }
        else {
            navViewController.navigationBar.isTranslucent = false
        }
        return navViewController
    }
}

