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
import DogSwift

protocol KeyNetworkHelper {
    init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration)

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void)
    func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void)
}

struct DefaultKeyNetworkHelper: KeyNetworkHelper {
    let baseUrl: URL
    let service = DCAppAttestService.shared
    let sessionConfiguration: URLSessionConfiguration

    init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration) {
        self.baseUrl = baseUrl
        self.sessionConfiguration = sessionConfiguration
    }

    private func doRegisterKey(payload: [String: Any],
                               uid: String,
                               snonce: String,
                               callback: @escaping () -> Void,
                               error: @escaping (Error?) -> Void) throws {
        let headers = HTTPHeaders([.uid(value: uid), .snonce(value: snonce)])
        let session = Session(configuration: sessionConfiguration)
        let request = try session.request(baseUrl: baseUrl,
                            endpoint: Endpoints.registerKey,
                            headers: headers,
                            payload: payload)
        Log.info(request, tag: "dreiAttest")
        Log.debug("Headers:\n\(request.convertible.urlRequest?.allHTTPHeaderFields as Any)", tag: "dreiAttest")
        Log.debug("Body:\n\(request.convertible.urlRequest?.httpBody?.base64EncodedString() as Any)", tag: "dreiAttest")
        Log.debug("Body JSON:\n\(payload)", tag: "dreiAttest")
        request.response { response in
            defer {
                session.close()
            }

            switch response.result {
            case .success(let errorData):
                if response.response?.statusCode == 200 {
                    callback()
                } else if let errorData = errorData,
                          let errorKey = String(data: errorData, encoding: .utf8) {
                    error(AttestError.from(errorKey))
                } else {
                    error(AttestError.internal)
                }
            case .failure(let err):
                error(err)
            }
        }.resume()
    }

    private func registerKey(with snonce: String,
                             uid: String,
                             keyId: String,
                             callback: @escaping () -> Void,
                             error: @escaping (Error?) -> Void) {
        guard let nonce = Self.nonce(uid: uid, keyId: keyId, snonce: snonce) else {
            error(AttestError.internal)
            return
        }

        service.attestKey(keyId, clientDataHash: nonce) { attestation, err in
            guard err == nil,
                  let attestation = attestation else {
                error(err)
                return
            }

            do {
                let payload: [String: Any] = ["key_id": keyId,
                                              "attestation": attestation.base64EncodedString(),
                                              "driver": "apple"]
                try doRegisterKey(payload: payload, uid: uid, snonce: snonce, callback: callback, error: error)
            } catch let err {
                error(err)
            }
        }
    }

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        do {
            try executeWithSNonce(uid: uid, success: { snonce in
                registerKey(with: snonce, uid: uid, keyId: keyId, callback: callback, error: error)
            }, error: error)
        } catch let err {
            error(err)
        }
    }

    private func signAndSend(request: URLRequest,
                             uid: String,
                             keyId: String,
                             success: @escaping () -> Void,
                             error: @escaping (Error?) -> Void) throws {
        var request = request

        try executeWithSNonce(uid: uid, success: { snonce in
            request.addHeader(.snonce(value: snonce))

            let requestHash = ServiceRequestHelper.requestHash(request)
            let dataHash = ServiceRequestHelper.nonce(requestHash, snonce: snonce)
            service.generateAssertion(keyId, clientDataHash: dataHash) { assertion, err in
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
        }, error: error)
    }

    func deregisterKey(_ keyId: String, for uid: String, success: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        UserDefaults.standard.keyIds[uid] = nil

        do {
            let deleteHeaders = HTTPHeaders([.uid(value: uid)])
            var request = try URLRequest(url: baseUrl.appendingPathComponent(Endpoints.deleteKey.name),
                                         method: Endpoints.deleteKey.method,
                                         headers: deleteHeaders)
            request.httpBody = keyId.data(using: .utf8)
            try signAndSend(request: request, uid: uid, keyId: keyId, success: success, error: error)
        } catch let err {
            error(err)
        }
    }

    func executeWithSNonce(uid: String, success: @escaping (String) -> Void, error: @escaping (Error?) -> Void) throws {
        let session = Session(configuration: sessionConfiguration)
        let getNonceHeaders = HTTPHeaders([.uid(value: uid), .accept("text/plain")])
        let request = try session.request(baseUrl: baseUrl, endpoint: Endpoints.keyRegistrationNonce, headers: getNonceHeaders)
        Log.info(request, tag: "dreiAttest")
        Log.debug("Headers:\n\(request.convertible.urlRequest?.allHTTPHeaderFields as Any)", tag: "dreiAttest")
        Log.debug("Body:\n\(request.convertible.urlRequest?.httpBody?.base64EncodedString() as Any)", tag: "dreiAttest")
        request.responseJSON { response in
            defer {
                session.close()
            }

            switch response.result {
            case .success(let nonce) where nonce is String:
                success(nonce as! String)
            case .success(_):
//                If snonce is not a valid string, the response is not acceptable
                error(AttestError.internal)
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
