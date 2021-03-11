//
//  MockKeyNetworkHelpers.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 19.01.21.
//

import Foundation
import Alamofire
import DeviceCheck
import CryptoKit

class KeyCountingNetworkHelper: KeyNetworkHelper {
    var registerCount = 0

    required init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration) {}

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        registerCount += 1
        callback()
    }

    func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        UserDefaults.standard.keyIds[uid] = nil
        success()
    }
}

class ForwardingKeyCountingNetworkHelper: KeyNetworkHelper {
    var registerCount = 0
    let target: DefaultKeyNetworkHelper

    required init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration) {
        target = DefaultKeyNetworkHelper(baseUrl: baseUrl, sessionConfiguration: sessionConfiguration)
    }

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        registerCount += 1
        target.registerNewKey(keyId: keyId, uid: uid, callback: callback, error: error)
    }

    func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        target.deregisterKey(keyId, for: uid, success: success, error: error)
    }
}

class AlwaysAcceptingKeyNetworkHelper: KeyNetworkHelper {
    required init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration) {}

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        DCAppAttestService.shared.attestKey(keyId, clientDataHash: Data(SHA256.hash(data: Data()))) { attestation, err in
            callback()
        }
    }

    func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        UserDefaults.standard.keyIds[uid] = nil
        success()
    }
}
