//
//  KeyNetworkHelper.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation
import Alamofire
import CryptoKit
import DeviceCheck

// TODO: make sealed if this proposal is ever accepted: https://forums.swift.org/t/sealed-protocols/19118
public protocol _KeyNetworkHelper {
    init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration)

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void)
    func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void)
}

public struct DefaultKeyNetworkHelper: _KeyNetworkHelper {
    let baseUrl: URL
    let service = DCAppAttestService.shared
    let sessionConfiguration: URLSessionConfiguration

    /**
     Do not use!
     */
    public init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration) {
        self.baseUrl = baseUrl
        self.sessionConfiguration = sessionConfiguration
    }

    private func registerKey(with nonce: Data, uid: String, keyId: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        service.attestKey(keyId, clientDataHash: nonce) { attestation, err in
            guard err == nil,
                  let attestation = attestation else {
                error(err)
                return
            }

            do {
                let headers = HTTPHeaders([.uid(value: uid)])
                let payload: [String: Any] = ["pubkey": keyId,
                                              "attestation": attestation.base64EncodedString()]
                let session = Session(configuration: sessionConfiguration)
                try session.request(baseUrl: baseUrl, endpoint: Endpoints.registerKey, headers: headers, payload: payload).response { response in
                    defer {
                        session.close()
                    }

                    switch response.result {
                    case .success(let errorData):
                        if response.response?.statusCode == 200 {
                            callback()
                        } else if let errorData = errorData,
                                  let errorKey = String(data: errorData, encoding: .utf8){
                            error(AttestError.from(errorKey))
                        } else {
                            error(AttestError.internal)
                        }
                    case .failure(let err):
                        error(err)
                    }
                }.resume()
            } catch let err {
                error(err)
            }
        }
    }

    /**
     Do not use!
     */
    // TODO: make internal when _NetworkHelper is sealed
    public func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        do {
            try doWithSNonce(uid: uid, success: { snonce in
                guard let nonce = Self.nonce(uid: uid, keyId: keyId, snonce: snonce) else {
                    error(AttestError.internal)
                    return
                }

                registerKey(with: nonce, uid: uid, keyId: keyId, callback: callback, error: error)
            }, error: error)
        } catch let err {
            error(err)
        }
    }

    public func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        UserDefaults.standard.keyIds[uid] = nil

        do {
            try doWithSNonce(uid: uid, success: { snonce in
                do {
                    let deleteHeaders = HTTPHeaders([.uid(value: uid)])
                    var request = try URLRequest(url: baseUrl.appendingPathComponent(Endpoints.deleteKey.name), method: Endpoints.deleteKey.method, headers: deleteHeaders)
                    request.httpBody = keyId.data(using: .utf8)

                    let requestHash = ServiceRequestHelper.requestHash(request)
                    service.generateAssertion(keyId, clientDataHash: ServiceRequestHelper.nonce(requestHash, snonce: snonce)) { assertion, err in
                        guard let assertion = assertion, err == nil else {
                            error(err)
                            return
                        }

                        request.addHeader(.signature(value: assertion.base64EncodedString()))
                        let session = Session(configuration: sessionConfiguration)
                        session.request(request).response { response in
                            defer {
                                session.close()
                            }

                            if response.response?.statusCode == 200 {
                                success()
                            } else {
                                error(nil)
                            }
                        }.resume()
                    }
                } catch let err {
                    error(err)
                }
            }, error: error)
        } catch let err {
            error(err)
        }
    }

    func doWithSNonce(uid: String, success: @escaping (String) -> Void, error: @escaping (Error?) -> Void) throws {
        let session = Session(configuration: sessionConfiguration)
        let getNonceHeaders = HTTPHeaders([.uid(value: uid), .accept("text/plain")])
        try session.request(baseUrl: baseUrl, endpoint: Endpoints.keyRegistrationNonce, headers: getNonceHeaders)
            .responseString { snonce in
                defer {
                    session.close()
                }

                switch snonce.result {
                case .success(let snonce):
                    success(snonce)
                case .failure(let err):
                    error(err)
                }
            }.resume()
    }

    static func nonce(uid: String, keyId: String, snonce: String) -> Data? {
        guard let nonceData = (uid + keyId + snonce).data(using: .utf8) else {
            return nil
        }

        return Data(SHA256.hash(data: nonceData))
    }
}
