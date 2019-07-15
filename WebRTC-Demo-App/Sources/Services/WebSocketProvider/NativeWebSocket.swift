//
//  NativeSocketProvider.swift
//  WebRTC-Demo
//
//  Created by Stas Seldin on 15/07/2019.
//  Copyright © 2019 Stas Seldin. All rights reserved.
//

import Foundation

@available(iOS 13.0, *)
class NativeWebSocket: WebSocketProvider {
    
    var delegate: WebSocketProviderDelegate?
    private let url: URL
    private var socket: URLSessionWebSocketTask?

    init(url: URL) {
        self.url = url
    }

    func connect() {
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        self.socket = socket
        self.delegate?.webSocketDidConnect(self)
        self.readMessage()
    }

    func send(data: Data) {
        self.socket?.send(.data(data)) { _ in }
    }
    
    private func readMessage() {
        self.socket?.receive { [weak self] message in
            guard let self = self else { return }
            
            switch message {
            case .success(.data(let data)):
                self.delegate?.webSocket(self, didReceiveData: data)
                self.readMessage()
                
            case .success:
                debugPrint("Warning: Expected to receive data format but received a string. Check the websocket server config.")
                self.readMessage()

            case .failure:
                self.disconnect()
            }
        }
    }
    
    private func disconnect() {
        self.socket?.cancel()
        self.socket = nil
        self.delegate?.webSocketDidDisconnect(self)
    }
}
