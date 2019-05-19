//
//  SynologySwiftTests.swift
//  SynologySwiftTests
//
//  Created by Thomas le Gravier on 19/01/2019.
//  Copyright © 2019 Thomas Le Gravier. All rights reserved.
//

import XCTest
@testable import SynologySwift


class SynologySwiftTests: XCTestCase {

    func testWrongQuickConnectID() {
        
        let delayExpectation = expectation(description: "Waiting SynologySwiftURLResolver")
        
        SynologySwiftURLResolver.resolve(quickConnectId: "unknown-quickConnect-id") { (result) in
            switch result {
            case .success(_): XCTAssertTrue(false)
            case .failure(let error):
                switch error {
                case .other(let errorInfo): XCTAssertTrue(errorInfo == "[Alias not found]")
                case .requestError(_):      XCTAssertTrue(false)
                }
            }
            delayExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testLogin() {
        
        let delayExpectation = expectation(description: "Waiting SynologySwiftAuth")
        
        SynologySwift.login(quickConnectid: "your-quick-id", sessionType: "DownloadStation", login: "dsdownload", password: "your-password", useDefaultCacheApis: true) { (result) in
            switch result {
            case .success(_): XCTAssertTrue(true)
            case .failure(let error): print(error); XCTAssertTrue(false)
            }
            delayExpectation.fulfill()
        }

        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testPing() {
        let delayExpectation = expectation(description: "Waiting ping")
        
        let dsInfos = SynologySwiftURLResolver.DSInfos(quickId: "your-quick-id", host: "your-quick-id.synology.me", port: 5000)
        SynologySwift.ping(dsInfos: dsInfos) { (result) in
            switch result {
            case .success(_): XCTAssertTrue(true)
            case .failure(let error): print(error); XCTAssertTrue(false)
            }
            delayExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testlogout() {
        let delayExpectation = expectation(description: "Waiting logout")
        
        let dsAuthInfos = SynologySwiftAuth.DSAuthInfos(sid: "your-sid", account: "your-account", dsInfos: SynologySwiftURLResolver.DSInfos(quickId: "your-quick-id", host: "host", port: 5000))
        SynologySwift.logout(dsAuthInfos: dsAuthInfos, sessionType: "DownloadStation") { (result) in
            switch result {
            case .success(_): XCTAssertTrue(true)
            case .failure(let error): print(error); XCTAssertTrue(false)
            }
            delayExpectation.fulfill()
        }
        waitForExpectations(timeout: 15.0, handler: nil)
    }
}
