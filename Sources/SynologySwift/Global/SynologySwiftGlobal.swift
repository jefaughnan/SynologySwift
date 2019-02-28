//
//  SynologySwiftGlobal.swift
//  SynologySwift
//
//  Created by Thomas le Gravier on 07/01/2019.
//  Copyright © 2019 Thomas Le Gravier. All rights reserved.
//

import Foundation


class SynologySwiftGlobal {
    
    static var APIsInfo: SynologySwiftGlobalObjectMapper.APIsInfo?
    
    static func resolveAvailableAPIs(dsInfos: SynologySwiftURLResolver.DSInfos, forceDefaultCache: Bool = false, completion: @escaping (SynologySwift.Result<SynologySwiftGlobalObjectMapper.APIsInfo>) -> ()) {
        
        /* Time profiler */
        let startTime = DispatchTime.now()
        let endBlock: (SynologySwift.Result<SynologySwiftGlobalObjectMapper.APIsInfo>) -> Void = { (result: SynologySwift.Result<SynologySwiftGlobalObjectMapper.APIsInfo>) in
            let endTime = DispatchTime.now()
            SynologySwiftTools.logTimeProfileInterval(message: "Global APIs", start: startTime, end: endTime)
            completion(result)
        }
        
        /* Return existing APIs infos if already exist */
        if let apisInfos = APIsInfo {return endBlock(.success(apisInfos))}
        
        /* Return default cache value if enable */
        if forceDefaultCache {
            retrieveApisInfosFromCache()
            if let apisInfos = APIsInfo {return endBlock(.success(apisInfos))}
        }
        
        let params = [
            "api": "SYNO.API.Info",
            "method": "query",
            "query": "all",
            "version": "1"
        ]
        
        SynologySwiftTools.logMessage("Global : Resolve available APIs")
        
        SynologySwiftCoreNetwork.performRequest(with: "http://\(dsInfos.host):\(dsInfos.port)/webapi/query.cgi", for: SynologySwiftGlobalObjectMapper.APIsInfo.self, method: .POST, params: params, contentType: "application/x-www-form-urlencoded; charset=utf-8") { (result) in
            switch result {
            case .success(let apisInfos):
                /* Check data integrity */
                if apisInfos.success {
                    self.APIsInfo = apisInfos
                    endBlock(.success(apisInfos))
                } else {
                    endBlock(.failure(.other(SynologySwiftTools.errorMessage(apisInfos.error, defaultMessage: "APIs infos not reachable"))))
                }
            case .failure(let error):
                endBlock(.failure(.requestError(error)))
            }
        }
    }
    
    static func serviceInfoForName(_ name: String) -> SynologySwiftGlobalObjectMapper.APIInfo? {
        if APIsInfo == nil {retrieveApisInfosFromCache()}
        guard let apisInfos = APIsInfo else {return nil}
        return apisInfos.apiList?.filter({ $0.key == name }).first?.value
    }
    
    private static func retrieveApisInfosFromCache() {
        guard let data = SynologySwiftGlobalDefaultApis.apis.data(using: .utf8) else {return}
        do {
            let apisInfos = try JSONDecoder().decode(SynologySwiftGlobalObjectMapper.APIsInfo.self, from: data)
            APIsInfo = apisInfos
        } catch _ {/* Error, fetch infos instead */}
    }
}
