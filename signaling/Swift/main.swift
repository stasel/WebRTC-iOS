//
//  main.swift
//  SignalingServer
//
//  Created by stasel on 15/07/2019.
//  Copyright © 2019 stasel. All rights reserved.
//

import Foundation

let server = try WebSocketServer()
server.start()
RunLoop.main.run()
