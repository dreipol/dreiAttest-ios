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

class KeyCountingNetworkHelper: _KeyNetworkHelper {
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

class AlwaysAcceptingKeyNetworkHelper: _KeyNetworkHelper {
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