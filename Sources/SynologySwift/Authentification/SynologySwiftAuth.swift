//
//  SynologySwiftAuth.swift
//  SynologySwift
//
//  Created by Thomas le Gravier on 24/12/2018.
//  Copyright © 2018 Thomas Le Gravier. All rights reserved.
//

import Foundation


public class SynologySwiftAuth {

    public struct DSAuthInfos {
        public var sid: String?
        public var account: String?
        public var dsInfos: SynologySwiftURLResolver.DSInfos?
        
        public init(sid: String? = nil, account: String? = nil, dsInfos: SynologySwiftURLResolver.DSInfos? = nil) {
            self.sid = sid
            self.account = account
            self.dsInfos = dsInfos
        }
    }
    
    /*
     * Auth method with encryption support.
     * Thanks to : https://github.com/openstack/cinder/blob/master/cinder/volume/drivers/synology/synology_common.py
     */
    static func login(dsInfos: SynologySwiftURLResolver.DSInfos, encryptionServicePath: String? = nil, authServicePath: String? = nil, sessionType: String, login: String, password: String, completion: @escaping (SynologySwift.Result<DSAuthInfos>) -> ()) {
        
        /* Time profiler */
        let startTime = DispatchTime.now()
        let endBlock: (SynologySwift.Result<DSAuthInfos>) -> Void = { (result: SynologySwift.Result<DSAuthInfos>) in
            let endTime = DispatchTime.now()
            SynologySwiftTools.logTimeProfileInterval(message: "Auth", start: startTime, end: endTime)
            completion(result)
        }
        
        /* Encryption service path */
        guard let encryptionServicePath = encryptionServicePath ?? SynologySwiftGlobal.serviceInfoForName("SYNO.API.Encryption")?.path else {
            return endBlock(.failure(.other("Please provide encryption service path. See SynologySwiftGlobal resolveAvailableAPIs tool if necessary.")))
        }
        
        /* Auth service path */
        guard let authServicePath = authServicePath ?? SynologySwiftGlobal.serviceInfoForName("SYNO.API.Auth")?.path else {
            return endBlock(.failure(.other("Please provide auth service path. See SynologySwiftGlobal resolveAvailableAPIs tool if necessary.")))
        }
        
        /* Save account id & dsInfos */
        var userAuthInfos = DSAuthInfos(account: login, dsInfos: dsInfos)
        
        /* Get encryption data */
        SynologySwiftTools.logMessage("Auth : Fetch encryption informations")
        
        fetchEncryptionInfos(dsInfos: dsInfos, encryptionServicePath: encryptionServicePath) { (result) in
            switch result {
            case .success(let encryptionInfos):
                
                SynologySwiftTools.logMessage("Auth : Start login process")
                
                /* Launch login */
                processLogin(dsInfos: dsInfos, encryptionInfos: encryptionInfos, authServicePath: authServicePath, sessionType: sessionType, login: login, password: password) { (result) in
                    switch result {
                    case .success(let authInfos):
                        SynologySwiftTools.logMessage("Auth : Success with sid \(authInfos.infos?.sid ?? "")")
                        userAuthInfos.sid = authInfos.infos?.sid
                        endBlock(.success(userAuthInfos))
                    case .failure(let error): endBlock(.failure(error))
                    }
                }
                
            case .failure(let error): endBlock(.failure(error))
            }
        }
    }
    
    /*
     * Get encryption infos
     */
    
    private static func fetchEncryptionInfos(dsInfos: SynologySwiftURLResolver.DSInfos, encryptionServicePath: String, completion: @escaping (SynologySwift.Result<SynologySwiftAuthObjectMapper.EncryptionInfos>) -> ()) {
        
        let params = [
            "api": "SYNO.API.Encryption",
            "method": "getinfo",
            "version": "1"
        ]
        
        SynologySwiftCoreNetwork.performRequest(with: "http://\(dsInfos.host):\(dsInfos.port)/webapi/\(encryptionServicePath)", for: SynologySwiftAuthObjectMapper.EncryptionInfos.self, method: .POST, params: params, contentType: "application/x-www-form-urlencoded; charset=utf-8") { (result) in
            switch result {
            case .success(let encryptionInfos):
                if encryptionInfos.success && encryptionInfos.infos != nil {completion(.success(encryptionInfos))}
                else {
                    let errorDescription: String
                    if let code = encryptionInfos.error?["code"], let error = SynologySwiftCoreNetwork.RequestCommonError(rawValue: code) {
                        errorDescription = "An error occured - \(error.description)"
                    } else {
                        errorDescription = "An error occured - Encryption infos not reachable"
                    }
                    completion(.failure(.other(SynologySwiftTools.errorMessage(errorDescription))))
                }
            case .failure(let error):
                completion(.failure(.requestError(error)))
            }
        }
    }
    
    /*
     * Get login infos
     */
    
    private static func processLogin(dsInfos: SynologySwiftURLResolver.DSInfos, encryptionInfos: SynologySwiftAuthObjectMapper.EncryptionInfos, authServicePath: String, sessionType: String, login: String, password: String, completion: @escaping (SynologySwift.Result<SynologySwiftAuthObjectMapper.AuthInfos>) -> ()) {
        
        guard let encryptionInfo = encryptionInfos.infos else {return completion(.failure(.other("An error occured - Encryption info not found")))}
        
        var params = [
            "api": "SYNO.API.Auth",
            "method": "login",
            "version": "6",
            "session": sessionType,
        ]
        
        let data = [
            "account": login,
            "passwd": password,
            "session": sessionType,
            "format": "sid",
            encryptionInfo.cipherToken: String(encryptionInfo.serverTime)
        ]
        
        /* Generate RSA */
        let passphrase = SynologySwiftTools.generateRandomString(length: 501)
        
        guard let publicKeyDER = try? SwKeyConvert.PublicKey.pemToPKCS1DER(encryptionInfo.publicKey) else {
            return completion(.failure(.other("An error occured - Failed to generate encrypt auth RSA public key")))
        }
        
        let tag = "PUBLIC-" + String(encryptionInfo.publicKey.hashValue)
        
        guard let rsa = (try? CC.RSA.encrypt(passphrase.data(using: .utf8)!, derKey: publicKeyDER, tag:tag.data(using: .utf8)!, padding: .pkcs1, digest: .none)) else {
            return completion(.failure(.other("An error occured - Failed to generate encrypt auth RSA params")))
        }
        
        /* Generate AES */
        guard let paramsStr = SynologySwiftTools.queryStringForParams(data),
              let aes = try? synologyAuthAES(str: paramsStr, password: passphrase)
        else {
            return completion(.failure(.other("An error occured - Failed to generate encrypt auth AES params")))
        }
        
        let cipherData = [
            "rsa": rsa.base64EncodedString(),
            "aes": aes.base64EncodedString()
        ]
        guard let cipherJSONData = try? JSONSerialization.data(withJSONObject: cipherData, options: []) else {
            return completion(.failure(.other("An error occured - Failed to generate encrypt auth cypher json params params")))
        }
        
        params[encryptionInfo.cipherKey] = String(data: cipherJSONData, encoding: .utf8)!
        
        SynologySwiftCoreNetwork.performRequest(with: "http://\(dsInfos.host):\(dsInfos.port)/webapi/\(authServicePath)", for: SynologySwiftAuthObjectMapper.AuthInfos.self, method: .POST, params: params, contentType: "application/x-www-form-urlencoded; charset=utf-8") { (result) in
            switch result {
            case .success(let authInfos):
                /* Check data integrity */
                if authInfos.success && authInfos.infos?.sid != nil {
                    completion(.success(authInfos))
                } else {
                    let errorDescription: String
                    if let code = authInfos.error?["code"], let error = SynologySwiftCoreNetwork.RequestAuthError(rawValue: code) {
                        errorDescription = "An error occured - \(error.description)"
                    } else if let code = authInfos.error?["code"], let error = SynologySwiftCoreNetwork.RequestCommonError(rawValue: code) {
                        errorDescription = "An error occured - \(error.description)"
                    } else {
                        errorDescription = "An error occured - Unknown auth error"
                    }
                    completion(.failure(.other(SynologySwiftTools.errorMessage(errorDescription))))
                }
            case .failure(let error):
                completion(.failure(.requestError(error)))
            }
        }
    }
    
    private static func synologyAuthAES(str: String, password: String) throws -> Data {
        func paddedString(_ str: String, alignment: Int) -> Data {
            assert(alignment <= 255)
            let data = Data(str.utf8)
            let sizeAdded = alignment - data.count%alignment
            return data + Data(repeating: UInt8(sizeAdded), count: sizeAdded)
        }
        func deriveKeyAndIV(password: Data, salt: Data, keyLength: Int, ivLength: Int) throws -> (key: Data, iv: Data) {
            var d = Data(), di = Data()
            while d.count < keyLength + ivLength {
                let data = di + password + salt
                di = SynologySwiftTools.dataToMD5(data)
                d += di
            }
            return (key: d[..<keyLength], iv: d[keyLength..<keyLength+ivLength])
        }
        
        let keyLength = 32
        let alignmentSize = 16
        let saltMagic = Data("Salted__".utf8)
        let saltData = AES256Crypter.randomData(length: alignmentSize - saltMagic.count)
        let fullSalt = saltMagic + saltData
        
        let (key, iv) = try deriveKeyAndIV(password: Data(password.utf8), salt: saltData, keyLength: keyLength, ivLength: alignmentSize)
        let paddedStr = paddedString(str, alignment: alignmentSize)
        
        let aes = try AES256Crypter(key: key, iv: iv)
        let encryptedData = try aes.encrypt(paddedStr)
        return fullSalt + encryptedData
    }
}
