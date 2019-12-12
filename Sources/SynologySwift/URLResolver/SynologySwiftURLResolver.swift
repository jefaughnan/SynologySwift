//
//  SynologySwiftURLResolver.swift
//  SynologySwift
//
//  Created by Thomas le Gravier on 20/12/2018.
//  Copyright © 2018 Thomas Le Gravier. All rights reserved.
//

import Foundation


public class SynologySwiftURLResolver {
    
    public struct DSInfos: Codable {
        public let quickId: String
        public let host: String
        public let port: Int
        
        public init(quickId: String, host: String, port: Int) {
            self.quickId = quickId
            self.host = host
            self.port = port
        }
    }
    
    static func resolve(quickConnectId: String, completion: @escaping (SynologySwift.Result<DSInfos>) -> ()) {
        
        /* Time profiler */
        let startTime = DispatchTime.now()
        let endBlock: (SynologySwift.Result<DSInfos>) -> Void = { (result: SynologySwift.Result<DSInfos>) in
            let endTime = DispatchTime.now()
            SynologySwiftTools.logTimeProfileInterval(message: "URLResolver", start: startTime, end: endTime)
            completion(result)
        }
        
        getServerInfosForId(quickConnectId) { (result) in
            switch result {
            case .success(let data):
                
                let port = data.service?.port ?? SynologySwiftConstants.defaultPort
                
                /* Create Queues */
                let pingpongQueue = OperationQueue()
                pingpongQueue.name = "Ping pong queue operation"
                
                let pingpongTunnelQueue = OperationQueue()
                pingpongTunnelQueue.name = "Ping pong existing tunnel queue operation"
                
                let newTunnelQueue = OperationQueue()
                newTunnelQueue.name = "Create new tunnel queue operation"
                
                /////
                // 1 - Ping DS directly
                /////
                
                SynologySwiftTools.logMessage("URLResolver : (Step 1) Test direct interfaces")
                
                /* Ping completion block */
                var hasSuccedCompletePing = false
                let pingpongCompletion = { (result: SynologySwift.Result<SynologySwiftURLResolverObjectMapper.PingPongInfos>?) -> Void in
                    /* Call after each pingpong call complete */
                    guard !hasSuccedCompletePing, let result = result else {return}
                    switch result {
                    case .success(let data):
                        guard data.success && !data.diskHibernation,
                            let host = data.host,
                            let port = data.port
                        else {return}
                        
                        /* Suspend queue & cancel other operations */
                        hasSuccedCompletePing = true
                        pingpongQueue.isSuspended = true
                        pingpongQueue.cancelAllOperations()
                        pingpongTunnelQueue.isSuspended = true
                        pingpongTunnelQueue.cancelAllOperations()
                        newTunnelQueue.isSuspended = true
                        newTunnelQueue.cancelAllOperations()
                        
                        let infos = self.DSInfos(quickId: quickConnectId, host: host, port: port)
                        return endBlock(SynologySwift.Result.success(infos))
                    case .failure(_): (/* Nothing to do, not reachable */)
                    }
                }
                
                /* Ping interfaces */
                if let interfaces = data.server?.interface {
                    pingPongOperationsForInterfaces(interfaces, withPortService: port, forQueue: pingpongQueue, withCompletion: { (result) in
                        pingpongCompletion(result)
                    })
                }
                
                /* Ping host address ddns */
                if let ddns = data.server?.ddns, ddns != "NULL" {
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        testPingPongHost(host: ddns, port: port, completion: { (result) in
                            operationEnded(result)
                        })
                    }
                    asyncOperation.completionBlock = {pingpongCompletion(asyncOperation.result)}
                    pingpongQueue.addOperation(asyncOperation)
                }
                
                /* Ping host address fqdn */
                if let fqdn = data.server?.fqdn, fqdn != "NULL" {
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        testPingPongHost(host: fqdn, port: port, completion: { (result) in
                            operationEnded(result)
                        })
                    }
                    asyncOperation.completionBlock = {pingpongCompletion(asyncOperation.result)}
                    pingpongQueue.addOperation(asyncOperation)
                }
                
                /* Ping external address IPV4 */
                if let ip = data.server?.external?.ip {
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        testPingPongHost(host: ip, port: data.server?.external?.port ?? port, completion: { (result) in
                            operationEnded(result)
                        })
                    }
                    asyncOperation.completionBlock = {pingpongCompletion(asyncOperation.result)}
                    pingpongQueue.addOperation(asyncOperation)
                }
                
                /* Ping external address IPV6 */
                if let ip = data.server?.external?.ipv6, ip != "::" {
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        testPingPongHost(host: ip, port: data.server?.external?.port ?? port, completion: { (result) in
                            operationEnded(result)
                        })
                    }
                    asyncOperation.completionBlock = {pingpongCompletion(asyncOperation.result)}
                    pingpongQueue.addOperation(asyncOperation)
                }
                
                /////
                // 2 - Ping DS through existing tunnel
                /////
                
                pingpongTunnelQueue.addOperation({
                    pingpongQueue.waitUntilAllOperationsAreFinished()
                    
                    /* Check if tunnel existing */
                    guard let service = data.service,
                        let relayIp = service.relayIp,
                        let relayPort = service.relayPort,
                        port != 0
                    else {return}
                    
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        SynologySwiftTools.logMessage("URLResolver : (Step 2) Test existing tunnel")
                        
                        testPingPongHost(host: relayIp, port: relayPort, timeout: 10, completion: { (result) in
                            operationEnded(result)
                        })
                    }
                    asyncOperation.completionBlock = {pingpongCompletion(asyncOperation.result)}
                    pingpongTunnelQueue.addOperation(asyncOperation)
                })
                
                /////
                // 3 - Request tunnel
                /////
                
                newTunnelQueue.addOperation({
                    pingpongTunnelQueue.waitUntilAllOperationsAreFinished()
                    
                    guard let controlHost = data.environment?.host else {
                        return endBlock(.failure(.other("No valid url resolved - Control host missing")))
                    }
                    
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.ServerInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        SynologySwiftTools.logMessage("URLResolver : (Step 3) Start tunnel creation")
                        
                        let params = [
                            "id": "dsm",
                            "serverID": quickConnectId,
                            "command": "request_tunnel",
                            "version": "1"
                        ]
                        SynologySwiftCoreNetwork.performRequest(with: "https://\(controlHost)/Serv.php", for: SynologySwiftURLResolverObjectMapper.ServerInfos.self, method: .POST, params: params, timeout: 60) { (result) in
                            switch result {
                            case .success(let serverInfos): operationEnded(.success(serverInfos))
                            case .failure(let error):       operationEnded(.failure(.requestError(error)))
                            }
                        }
                    }
                    asyncOperation.completionBlock = {
                        guard let result = asyncOperation.result else {
                            return endBlock(.failure(.other("No valid url resolved - No valid result")))
                        }
                        switch result {
                        case .success(let data):
                            guard let ip = data.service?.relayIp, let port = data.service?.relayPort else {
                                return endBlock(.failure(.other("No valid url resolved - Relay informations missing")))
                            }
                            let infos = DSInfos(quickId: quickConnectId, host: ip, port: port)
                            return endBlock(.success(infos))
                        case .failure(let error):
                            return endBlock(.failure(error))
                        }
                    }
                    newTunnelQueue.addOperation(asyncOperation)
                })
                
            case .failure(let error): endBlock(.failure(error))
            }
        }
    }
    
    static func ping(dsInfos: SynologySwiftURLResolver.DSInfos, completion: @escaping (SynologySwift.Result<DSInfos>) -> ()) {
        /* Test dsInfos interface */
        testPingPongHost(host: dsInfos.host, port: dsInfos.port, timeout: 10, completion: { (result) in
            switch result {
            case .success(let data):
                if data.success && !data.diskHibernation {
                    completion(.success(dsInfos))
                } else {
                    completion(.failure(.other("Ping error. Disk maybe under hibernation but host is reachable.")))
                }
            case .failure(let error): completion(.failure(error))
            }
        })
    }
    
    /*
     * Get server infos
     */
    
    private static func getServerInfosForId(_ quickConnectId: String, completion: @escaping (SynologySwift.Result<SynologySwiftURLResolverObjectMapper.ServerInfos>) -> ()) {
        let params = [
            "id": "dsm",
            "serverID": quickConnectId,
            "command": "get_server_info",
            "version": "1"
        ]
        SynologySwiftCoreNetwork.performRequest(with: "https://global.QuickConnect.to/Serv.php", for: SynologySwiftURLResolverObjectMapper.ServerInfos.self, method: .POST, params: params) { (result) in
            switch result {
            case .success(let serverInfos):
                /* Check data integrity */
                if serverInfos.error == 0 {completion(.success(serverInfos))}
                else {
                    let errorDescription = serverInfos.errorInfo ?? "An error occured - Server infos not reachable"
                    completion(.failure(.other(SynologySwiftTools.parseErrorMessage(errorDescription))))
                }
            case .failure(let error):
                completion(.failure(.requestError(error)))
            }
        }
    }

}

private typealias SynologySwiftURLResolverPingPong = SynologySwiftURLResolver
extension SynologySwiftURLResolverPingPong {
    
    private static func pingPongOperationsForInterfaces(_ interfaces: [SynologySwiftURLResolverObjectMapper.ServerInfosServerInterface], withPortService port: Int, forQueue queue: OperationQueue, withCompletion handler: ((SynologySwift.Result<SynologySwiftURLResolverObjectMapper.PingPongInfos>?)->())? = nil) {
        
        var operations: [Operation] = []
        
        for interface in interfaces {
            /* IPV4 interface */
            if let ip = interface.ip {
                let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                asyncOperation.setBlockOperation { (operationEnded) in
                    testPingPongHost(host: ip, port: port, completion: { (result) in
                        operationEnded(result)
                    })
                }
                asyncOperation.completionBlock = {handler?(asyncOperation.result)}
                operations.append(asyncOperation)
            }
            
            
            /* IPV6 interfaces */
            if let ipv6 = interface.ipv6 {
                for ip in ipv6 {
                    guard ip.address != "::" else {continue}
                    let asyncOperation = SynologySwiftAsyncOperation<SynologySwiftURLResolverObjectMapper.PingPongInfos>()
                    asyncOperation.setBlockOperation { (operationEnded) in
                        testPingPongHost(host: "[\(ip.address)]", port: port, completion: { (result) in
                            operationEnded(result)
                        })
                    }
                    asyncOperation.completionBlock = {handler?(asyncOperation.result)}
                    operations.append(asyncOperation)
                }
            }
        }
        
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
    private static func testPingPongHost(host: String, port: Int? = nil, timeout: TimeInterval = 5, completion: @escaping (SynologySwift.Result<SynologySwiftURLResolverObjectMapper.PingPongInfos>) -> ()) {
        var url = "http://\(host)"
        if let port = port {url = url + ":\(String(port))"}
        SynologySwiftCoreNetwork.performRequest(with: url + "/webman/pingpong.cgi", for: SynologySwiftURLResolverObjectMapper.PingPongInfos.self, timeout: timeout) { (result) in
            switch result {
            case .success(var success): success.host = host; success.port = port; completion(.success(success))
            case .failure(let error):   completion(.failure(.requestError(error)))
            }
        }
    }

}
