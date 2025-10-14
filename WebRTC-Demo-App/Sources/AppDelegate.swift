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
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = self.buildMainViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    
    private func buildMainViewController() -> UIViewController {
        
        //let webRTCClient = WebRTCClient(iceServers: ["stun:stun.l.google.com:19302"])
        //let signalClient = self.buildSignalingClient()
        
        //let mainViewController = MainViewController(signalClient: signalClient, webRTCClient: webRTCClient)
        
        let mainViewController = RoomsViewController()
        
        let navViewController = UINavigationController(rootViewController: mainViewController)
        navViewController.navigationBar.prefersLargeTitles = true
        
        return navViewController
    }
    
    private func buildSignalingClient() -> SignalingClient {
        return SignalingClient()
    }
}

