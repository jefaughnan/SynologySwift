[![Platform](https://img.shields.io/badge/Platforms-iOS%20%7CmacOS%20%7C%20watchOS%20%7C%20tvOS-4E4E4E.svg?colorA=28a745)](#installation)

[![CocoaPods compatible](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/Thomaslegravier/SynologySwift)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/Thomaslegravier/SynologySwift)
[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/Thomaslegravier/SynologySwift)

[![Twitter](https://img.shields.io/badge/Twitter-@lebasalte-blue.svg?style=flat)](https://twitter.com/lebasalte)

# SynologySwift
Swift library for accessing Synology NAS and use DiskStation APIs.

Tools :
- Resolve NAS host/ip base on QuickConnectId
- List available APIs
- Login with encryption

Installation
------------

### Swift 5

With Cocoapods:

```
pod 'SynologySwift'
```

With Carthage:

```
github "Thomaslegravier/SynologySwift"
```

Usage
-----
```
import SynologySwift
```

Resolve DS reachable interface for a specific QuickConnectId :

```swift
SynologySwift.resolveURL(quickConnectId: "your-quick-id") { (result) in
    switch result {
    case .success(let data):
        let dsPort = data.port
        let dsHost = data.host
    case .failure(let error): break
    }
}
```

List available APIs on your DS :

```swift
SynologySwift.resolveAvailableAPIs { (result) in
    switch result {
    case .success(let data):
        for service in data.apiList! {
            let serviceName = service.key        // Example : SYNO.API.Auth
            let servicePath = service.value.path // Example : auth.cgi
        }
    case .failure(let error): break
    }
}
```

Auth connection with encryption :

```swift
SynologySwift.login(quickConnectid: "your-quick-id", sessionType: "DownloadStation", login: "login", password: "password", useDefaultCacheApis: false) { (result) in
    switch result {
    case .success(let data):
        let accountName = data.account // Account name
        let sessionId = data.sid       // Sid param for futher connected calls
    case .failure(let error): break
    }
}
/* NB : Set 'useDefaultCacheApis' for faster login. If true, we use default auth and encryption APIs paths, instead fetch all available APIs on your DS. Use at your own risk. */
```

Get info for a specific service

```swift
let dlService = SynologySwift.serviceInfos(serviceName: "SYNO.DownloadStation.Info")
let path = dlService.path
```

Logout :

```swift
let dsAuthInfos = SynologySwiftAuth.DSAuthInfos(sid: "XXXXXXXXX", account: "account-name", dsInfos: SynologySwiftURLResolver.DSInfos(quickId: "your-quick-id", host: "XXXXXXX", port: 5000))
SynologySwift.logout(dsAuthInfos: dsAuthInfos, sessionType: "DownloadStation") { (result) in
    switch result {
    case .success(_):         print("Success logout")
    case .failure(let error): print(error)
    }
}
/* NB : Use auth infos from your last login session to perform logout. */
```

Details
-------

Login helper: 
- Resolve automatically your DS host base on the quickConnectId
- List available APIs on your DS
- Fetch encryption details
- Login with your account informations.
- Get specific service info path
- Logout from a specific session

Your login and password are encrypted and not stored.

Credits
-------

- Thanks to @Frizlab fro RSA/AES encryption part.
- Thanks to @soyersoyer for SwCrypt implementation RSA part
