//
//  WebSocketClient.swift
//  SignalingServer
//
//  Created by stasel on 15/07/2019.
//  Copyright © 2019 stasel. All rights reserved.
//

import Foundation
import Network

final class WebSocketClient: Hashable, Equatable {
    
    let id: String
    let connection: NWConnection
    
    init(connection: NWConnection) {
        self.connection = connection
        self.id = UUID().uuidString
    }
    
    static func == (lhs: WebSocketClient, rhs: WebSocketClient) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
