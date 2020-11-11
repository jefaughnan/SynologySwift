//
//  AES256Crypter.swift
//  SynologySwift
//
//  Created by Thomas le Gravier on 15/01/2019.
//  Copyright © 2019 Thomas Le Gravier. All rights reserved.
//

import Foundation
import CommonCrypto
import Security


protocol Randomizer {
    static func randomIv() -> Data
    static func randomSalt() -> Data
    static func randomData(length: Int) -> Data
}

protocol Crypter {
    func encrypt(_ digest: Data) throws -> Data
    func decrypt(_ encrypted: Data) throws -> Data
}

struct AES256Crypter {
    
    private var key: Data
    private var iv: Data
    
    public init(key: Data, iv: Data) throws {
        guard key.count == kCCKeySizeAES256 else {
            throw Error.badKeyLength
        }
        guard iv.count == kCCBlockSizeAES128 else {
            throw Error.badInputVectorLength
        }
        self.key = key
        self.iv = iv
    }
    
    enum Error: Swift.Error {
        case keyGeneration(status: Int)
        case cryptoFailed(status: CCCryptorStatus)
        case badKeyLength
        case badInputVectorLength
    }
    
    private func crypt(input: Data, operation: CCOperation) throws -> Data {
        var outLength = Int(0)
        var outBytes = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)
        input.withUnsafeBytes { encryptedBytes -> Void in
            iv.withUnsafeBytes { ivBytes -> Void in
                key.withUnsafeBytes { keyBytes -> Void in
                    status = CCCrypt(operation,
                                     CCAlgorithm(kCCAlgorithmAES128),  // algorithm
                        CCOptions(kCCOptionPKCS7Padding),              // options
                        keyBytes.baseAddress!,                         // key
                        key.count,                                     // keylength
                        ivBytes.baseAddress!,                          // iv
                        encryptedBytes.baseAddress!,                   // dataIn
                        input.count,                                   // dataInLength
                        &outBytes,                                     // dataOut
                        outBytes.count,                                // dataOutAvailable
                        &outLength)                                    // dataOutMoved
                }
            }
        }
        guard status == kCCSuccess else {
            throw Error.cryptoFailed(status: status)
        }
        return Data(bytes: &outBytes, count: outLength)
    }
    
    static func createKey(password: Data, salt: Data) throws -> Data {
        let length = kCCKeySizeAES256
        var status = Int32(0)
        var derivedBytes = [UInt8](repeating: 0, count: length)
        password.withUnsafeBytes { passwordBytes -> Void in
            salt.withUnsafeBytes { saltBytes -> Void in
                status = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),                  // algorithm
                    passwordBytes.bindMemory(to: Int8.self).baseAddress!,                                // password
                    password.count,                               // passwordLen
                    saltBytes.bindMemory(to: UInt8.self).baseAddress!,                                    // salt
                    salt.count,                                   // saltLen
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),   // prf
                    10000,                                        // rounds
                    &derivedBytes,                                // derivedKey
                    length)                                       // derivedKeyLen
            }
        }
        guard status == 0 else {
            throw Error.keyGeneration(status: Int(status))
        }
        return Data(bytes: derivedBytes, count: length)
    }
    
}

extension AES256Crypter: Crypter {
    
    func encrypt(_ digest: Data) throws -> Data {
        return try crypt(input: digest, operation: CCOperation(kCCEncrypt))
    }
    
    func decrypt(_ encrypted: Data) throws -> Data {
        return try crypt(input: encrypted, operation: CCOperation(kCCDecrypt))
    }
    
}

extension AES256Crypter: Randomizer {
    
    static func randomIv() -> Data {
        return randomData(length: kCCBlockSizeAES128)
    }
    
    static func randomSalt() -> Data {
        return randomData(length: 8)
    }
    
    static func randomData(length: Int) -> Data {
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { mutableBytes -> OSStatus in
            SecRandomCopyBytes(kSecRandomDefault, length, mutableBytes.baseAddress!)
        }
        assert(status == Int32(0))
        return data
    }
    
}
