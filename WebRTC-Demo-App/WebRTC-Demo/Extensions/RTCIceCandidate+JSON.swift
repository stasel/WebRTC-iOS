//
//  CodableRTCIceCandidate.swift
//  WebRTC
//
//  Created by Stas Seldin on 20/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import Foundation

extension RTCIceCandidate {
   
    func jsonString() -> String? {
        let dict = [
                CodingKeys.sdp.rawValue: self.sdp,
                CodingKeys.sdpMid.rawValue: self.sdpMid,
                CodingKeys.sdpMLineIndex.rawValue: self.sdpMLineIndex
            ] as [String : Any?]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
            let jsonString = String(data: jsonData, encoding: .utf8)  {
                return jsonString
        }
        return nil
    }
    
    class func fromJsonString(_ string: String) -> RTCIceCandidate? {
        if let data = string.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
            let jsonDictionary = jsonObject  as? [String: Any?],
            let sdp = jsonDictionary[CodingKeys.sdp.rawValue] as? String ,
            let sdpMid = jsonDictionary[CodingKeys.sdpMid.rawValue] as? String?,
            let sdpMLineIndex = jsonDictionary[CodingKeys.sdpMLineIndex.rawValue] as? Int32{
            return RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case sdp
        case sdpMLineIndex
        case sdpMid
    }
}
