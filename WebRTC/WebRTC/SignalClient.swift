//
//  SignalClient.swift
//  WebRTC
//
//  Created by Stas Seldin on 20/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import Foundation
import Starscream

protocol SignalClientDelegate: class {
    func signalClientDidConnect(_ signalClient: SignalClient)
    func signalClientDidDisconnect(_ signalClient: SignalClient)
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate)
}

struct Message: Codable {
    enum PayloadType: String, Codable {
        case sdp, candidate
    }
    let type: PayloadType
    let payload: String
}

class SignalClient {
    
    private let socket = WebSocket(url: URL(string: "ws://signal.stasel.com:8080/")!)
    weak var delegate: SignalClientDelegate?
    
    func connect() {
        self.socket.delegate = self
        self.socket.connect()
    }
    
    func send(sdp: RTCSessionDescription) {
        let message = Message(type: .sdp, payload: sdp.jsonString() ?? "")
        if let dataMessage = try? JSONEncoder().encode(message),
            let stringMessage = String(data: dataMessage, encoding: .utf8) {
            self.socket.write(string: stringMessage)
        }
    }
    
    func send(candidate: RTCIceCandidate) {
        let message = Message(type: .candidate,
                              payload: candidate.jsonString() ?? "")
        if let dataMessage = try? JSONEncoder().encode(message),
            let stringMessage = String(data: dataMessage, encoding: .utf8){
            self.socket.write(string: stringMessage)
        }
    }
}


extension SignalClient: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        self.delegate?.signalClientDidConnect(self)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        self.delegate?.signalClientDidDisconnect(self)
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        if let data = text.data(using: .utf8),
            let message = try? JSONDecoder().decode(Message.self, from: data) {
            switch message.type {
            case .candidate:
                if let candidate = RTCIceCandidate.fromJsonString(message.payload) {
                    self.delegate?.signalClient(self, didReceiveCandidate: candidate)
                }
            case .sdp:
                if let sdp = RTCSessionDescription.fromJsonString(message.payload) {
                    self.delegate?.signalClient(self, didReceiveRemoteSdp: sdp)
                }
            }
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        
    }
}
