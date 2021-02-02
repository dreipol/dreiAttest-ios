//
//  AttestService.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation
import DeviceCheck
import Alamofire

private let keyGenerationLock = NSLock()

public final class AttestService<KeyNetworkHelper: _KeyNetworkHelper>: RequestInterceptor {
    public let uid: String

    let keyNetworkHelper: KeyNetworkHelper
    let serviceRequestHelper: ServiceRequestHelper
    let service = DCAppAttestService.shared
    let sharedSecret: String?
    var serviceUid: String {
        UserDefaults.standard.serviceUid(for: uid)
    }

    init(baseAddress: URL, uid: String, validationLevel: ValidationLevel, config: Config<KeyNetworkHelper>) throws {
        guard validationLevel == .signOnly else {
            fatalError("not yet implemented!")
        }

        guard service.isSupported || config.sharedSecret != nil else {
            throw AttestError.notSupported
        }

        keyNetworkHelper = config.networkHelperType.init(baseUrl: baseAddress, sessionConfiguration: config.sessionConfiguration)
        serviceRequestHelper = ServiceRequestHelper(baseUrl: baseAddress,validationLevel: validationLevel)
        self.uid = uid
        sharedSecret = config.sharedSecret
    }

    func generateNewKey(callback: @escaping (String) -> Void, error: @escaping (Error?) -> Void) {
        service.generateKey { keyId, err in
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
                    self.keyNetworkHelper.registerNewKey(keyId: keyId, uid: self.serviceUid, callback: {
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

    public func deregisterKey(callback: @escaping () -> Void) {
        guard let keyId = UserDefaults.standard.keyIds[serviceUid] else {
            return
        }

        // Server errors are ignored and key is deleted locally
        keyNetworkHelper.deregisterKey(keyId, for: serviceUid, success: {}, error: { _ in })
    }

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if let sharedSecret = sharedSecret {
            serviceRequestHelper.adapt(urlRequest, for: session, uid: serviceUid, bypass: sharedSecret, completion: completion)
        } else if serviceRequestHelper.shouldHanlde(urlRequest) {
            // decide whether we have to handle the request early on (before checking headers) so we can have multiple AttestationServices
            // running at the same time for different baseUrls

            getKeyId(callback: { keyId in
                self.serviceRequestHelper.adapt(urlRequest, for: session, uid: self.serviceUid, keyId: keyId, completion: completion)
            }, error: { completion(.failure($0 ?? AttestError.internal)) })
        } else {
            completion(.success(urlRequest))
        }
    }

    public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let urlRequest = request.request,
              serviceRequestHelper.shouldHanlde(urlRequest),
              request.response?.statusCode == 403,
              let errorKey = request.response?.value(forHTTPHeaderField: HTTPHeader.errorHeaderName),
              AttestError.from(errorKey) == .invalidKey else {
            completion(.doNotRetry)
            return
        }

        UserDefaults.standard.keyIds[serviceUid] = nil
        if request.retryCount == 0 {
            completion(.retry)
        } else {
            completion(.doNotRetryWithError(AttestError.invalidKey))
        }
    }
}

public extension AttestService where KeyNetworkHelper == DefaultKeyNetworkHelper {
    convenience init(baseAddress: URL,
                     uid: String = "",
                     validationLevel: ValidationLevel,
                     bypass sharedSecret: String? = ProcessInfo.processInfo.environment["DREIATTEST_BYPASS_SECRET"]) throws {
        try self.init(baseAddress: baseAddress, uid: uid, validationLevel: validationLevel, config: Config(sharedSecret: sharedSecret))
    }
}
