//
//  AttestService.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation
import DeviceCheck

private let keyGenerationLock = NSLock()

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

            callback(keyId)
        }
    }

    func getKeyId(callback: @escaping (String) -> Void, error: @escaping (Error?) -> Void) {
        guard let keyId = UserDefaults.standard.keyIds[serviceUid] else {
            // Dispatch so we don't block the main thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                keyGenerationLock.lock()
                if let keyId = UserDefaults.standard.keyIds[self.serviceUid] {
                    keyGenerationLock.unlock()
                    callback(keyId)
                    return
                }

                let unlockingErrorHandler = { (err: Error?) in
                    keyGenerationLock.unlock()
                    error(err)
                }
                // once we commit to generating a new key we want to complete the operation so we capture self strongly
                self.generateNewKey(callback: { keyId in
                    self.networkHelper.registerNewKey(keyId: keyId, uid: self.serviceUid, callback: {
                        UserDefaults.standard.keyIds[self.serviceUid] = keyId
                        keyGenerationLock.unlock()
                        callback(keyId)
                    }, error: unlockingErrorHandler)
                }, error: unlockingErrorHandler)
            }
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
