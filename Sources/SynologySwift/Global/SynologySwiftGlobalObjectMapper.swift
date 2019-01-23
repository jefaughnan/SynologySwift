//
//  SynologySwiftGlobalObjectMapper.swift
//  SynologySwift
//
//  Created by Thomas le Gravier on 07/01/2019.
//  Copyright © 2019 Thomas Le Gravier. All rights reserved.
//

import Foundation


public class SynologySwiftGlobalObjectMapper {
    
    /*
     *   APIsInfo
     */
    
    public struct APIsInfo: Decodable {
        let success: Bool // Not failable, not optional
        
        public var apiList: [String: APIInfo]?
        
        var error: [String: Int]?
        
        private enum CodingKeys: String, CodingKey {
            case apiList = "data"
            case success = "success"
            case error   = "error"
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            success = try values.decode(Bool.self, forKey: .success)
            apiList = try values.decodeIfPresent([String: APIInfo].self, forKey: .apiList)
            error = try values.decodeIfPresent([String: Int].self, forKey: .error)
        }
    }
    
    public struct APIInfo: Decodable {
        public let path: String // Not failable, not optional
        
        public var maxVersion: Int?
        public var minVersion: Int?
        public var requestFormat: String?
    }
}
