//
//  CodableRTCSessionDescription.swift
//  WebRTC
//
//  Created by Stas Seldin on 20/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import Foundation

extension RTCSessionDescription {
    
    func jsonString() -> String? {
        let dict = [
            CodingKeys.sdp.rawValue: self.sdp,
            CodingKeys.type.rawValue: self.type.rawValue,
            ] as [String : Any?]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
            let jsonString = String(data: jsonData, encoding: .utf8)  {
            return jsonString
        }
        return nil
    }
    
    class func fromJsonString(_ string: String) -> RTCSessionDescription? {
        if let data = string.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
            let jsonDictionary = jsonObject  as? [String: Any?],
            let sdp = jsonDictionary[CodingKeys.sdp.rawValue] as? String ,
            let typeNumber = jsonDictionary[CodingKeys.type.rawValue] as? Int,
            let type = RTCSdpType(rawValue: typeNumber) {
            return RTCSessionDescription(type: type, sdp: sdp)
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case sdp
        case type
    }
}
