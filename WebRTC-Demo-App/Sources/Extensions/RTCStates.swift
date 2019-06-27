//
//  RTCConnectionState.swift
//  WebRTC
//
//  Created by Stasel on 20/05/2018.
//  Copyright © 2018 Stasel. All rights reserved.
//

import Foundation
import WebRTC

extension RTCIceConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "new"
        case .checking:     return "checking"
        case .connected:    return "connected"
        case .completed:    return "completed"
        case .failed:       return "failed"
        case .disconnected: return "disconnected"
        case .closed:       return "closed"
        case .count:        return "count"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCSignalingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stable:               return "stable"
        case .haveLocalOffer:       return "haveLocalOffer"
        case .haveLocalPrAnswer:    return "haveLocalPrAnswer"
        case .haveRemoteOffer:      return "haveRemoteOffer"
        case .haveRemotePrAnswer:   return "haveRemotePrAnswer"
        case .closed:               return "closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCIceGatheringState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "new"
        case .gathering:    return "gathering"
        case .complete:     return "complete"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCDataChannelState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connecting:   return "connecting"
        case .open:         return "open"
        case .closing:      return "closing"
        case .closed:       return "closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

