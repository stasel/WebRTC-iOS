//
//  main.swift
//  SignalingServer
//
//  Created by Stas Seldin on 15/07/2019.
//  Copyright © 2019 Stas Seldin. All rights reserved.
//

import Foundation

let server = try WebSocketServer()
server.start()
RunLoop.main.run()
