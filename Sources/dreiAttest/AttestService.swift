//
//  AttestService.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation
import DeviceCheck

public final class AttestService<NetworkHelper: _NetworkHelper> {
    public let uid: String

    let networkHelper: NetworkHelper
    let service = DCAppAttestService.shared
    var serviceUid: String {
        UserDefaults.standard.serviceUid(for: uid)
    }

    init(baseAddress: URL, uid: String, config: Config<NetworkHelper>) throws {
        guard service.isSupported else {
            throw AttestError.notSupported
        }

        networkHelper = config.networkHelperType.init(baseUrl: baseAddress)
        self.uid = uid
    }

    func generateNewKey(callback: @escaping (String) -> Void, error: @escaping (Error?) -> Void) {
        service.generateKey { [serviceUid] keyId, err in
            guard let keyId = keyId, err == nil else {
                error(err)
                return
            }

            UserDefaults.standard.keyIds[serviceUid] = keyId
            callback(keyId)
        }
    }

    func getKeyId(callback: @escaping (String) -> Void, error: @escaping (Error?) -> Void) {
        guard let keyId = UserDefaults.standard.keyIds[uid] else {
            generateNewKey(callback: { keyId in
                self.networkHelper.registerNewKey(keyId: keyId, callback: { callback(keyId) }, error: error)
            }, error: error)
            return
        }

        callback(keyId)
    }
}

public extension AttestService where NetworkHelper == DefaultNetworkHelper {
    convenience init(baseAddress: URL, uid: String = "") throws {
        try self.init(baseAddress: baseAddress, uid: uid, config: Config())
    }
}
