//
//  WebSocketServer.swift
//  SignalingServer
//
//  Created by stasel on 15/07/2019.
//  Copyright © 2019 stasel. All rights reserved.
//

import Foundation
import Network

final class WebSocketServer {
    
    private let queue = DispatchQueue.global()
    private let port: NWEndpoint.Port = 8080
    private let listener: NWListener
    private var connectedClients = Set<WebSocketClient>()
    
    init() throws {
        let parameters = NWParameters.tcp
        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.append(webSocketOptions)
        self.listener = try NWListener(using: parameters, on: self.port)
    }
    
    func start() {
        self.listener.newConnectionHandler = self.newConnectionHandler
        self.listener.start(queue: queue)
        print("Signaling server started listening on port \(self.port)")
    }
    
    private func newConnectionHandler(_ connection: NWConnection) {
        let client = WebSocketClient(connection: connection)
        self.connectedClients.insert(client)
        client.connection.start(queue: self.queue)
        client.connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            self?.didReceiveMessage(from: client, data: data, context: context, error: error)
        }
        print("A client has connected. Total connected clients: \(self.connectedClients.count)")
    }
    
    private func didDisconnect(client: WebSocketClient) {
        self.connectedClients.remove(client)
        print("A client has disconnected. Total connected clients: \(self.connectedClients.count)")
    }
    
    private func didReceiveMessage(from client: WebSocketClient,
                                   data: Data?,
                                   context: NWConnection.ContentContext?,
                                   error: NWError?) {
        
        if let context = context, context.isFinal {
            client.connection.cancel()
            self.didDisconnect(client: client)
            return
        }
        
        if let data = data {
            let otherClients = self.connectedClients.filter { $0 != client }
            self.broadcast(data: data, to: otherClients)
            
            if let str = String(data: data, encoding: .utf8) {
                print("------------------------------------ Incoming Message ------------------------------------")
                print(str + "\n")
            }
        }
        
        client.connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            self?.didReceiveMessage(from: client, data: data, context: context, error: error)
        }
    }
    
    private func broadcast(data: Data, to clients: Set<WebSocketClient>) {
        clients.forEach {
            let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
            let context = NWConnection.ContentContext(identifier: "context", metadata: [metadata])

            $0.connection.send(content: data,
                               contentContext: context,
                               isComplete: true,
                               completion: .contentProcessed({ _ in }))
        }
    }
}
