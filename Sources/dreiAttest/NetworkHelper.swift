//
//  NetworkHelper.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation
import Alamofire
import CryptoKit
import DeviceCheck

public enum ValidationLevel {
    case signOnly, withNonce
}

private let defaultRequestNonce = "00000000-0000-0000-0000-000000000000"

// TODO: make sealed if this proposal is ever accepted: https://forums.swift.org/t/sealed-protocols/19118
public protocol _NetworkHelper {
    init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration, validationLevel: ValidationLevel)

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void)
    func adapt(_ urlRequest: URLRequest, for session: Session, uid: String, keyId: String, completion: @escaping (Result<URLRequest, Error>) -> Void)
}

public struct DefaultNetworkHelper: _NetworkHelper {
    let baseUrl: URL
    let service = DCAppAttestService.shared
    let sessionConfiguration: URLSessionConfiguration
    let validationLevel: ValidationLevel

    /**
     Do not use!
     */
    public init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration, validationLevel: ValidationLevel) {
        self.baseUrl = baseUrl
        self.sessionConfiguration = sessionConfiguration
        self.validationLevel = validationLevel
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
            let session = Session(configuration: sessionConfiguration)
            let getNonceHeaders = HTTPHeaders([.uid(value: uid), .contentType("text/plain")])
            try session.request(baseUrl: baseUrl, endpoint: Endpoints.keyRegistrationNonce, headers: getNonceHeaders)
                .responseString { snonce in
                    defer {
                        session.close()
                    }

                    switch snonce.result {
                    case .success(let snonce):
                        guard let nonce = Self.nonce(uid: uid, keyId: keyId, snonce: snonce) else {
                            error(AttestError.internal)
                            return
                        }

                        registerKey(with: nonce, uid: uid, keyId: keyId, callback: callback, error: error)
                    case .failure(let err):
                        error(err)
                    }
            }.resume()
        } catch let err {
            error(err)
        }
    }

    public func adapt(_ urlRequest: URLRequest, for session: Session, uid: String, keyId: String, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // decide whether we have to handle the request before checking headers so we can have multiple AttestationServices running at the same time for different
        // baseUrls
        guard urlRequest.url?.absoluteString.hasPrefix(baseUrl.absoluteString) == true else {
            completion(.success(urlRequest))
            return
        }
        guard !urlRequest.headers.contains(where: { $0.name.starts(with: "dreiAttest-") }) else {
            completion(.failure(AttestError.illegalHeaders))
            return
        }

        var mutableRequest = urlRequest
        mutableRequest.addHeader(.uid(value: uid))

        var requestHash: Data?
        var snonce = defaultRequestNonce
        var jobsToDo: Int32 = validationLevel == .withNonce ? 2 : 1

        func finish() {
            let nonce = Self.nonce(requestHash!, snonce: snonce)
            service.generateAssertion(keyId, clientDataHash: nonce) { assertion, error in
                guard let assertion = assertion, error == nil else {
                    completion(.failure(error ?? AttestError.internal))
                    return
                }

                mutableRequest.addHeader(.signature(value: assertion.base64EncodedString()))
                completion(.success(mutableRequest))
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            requestHash = Self.requestHash(mutableRequest)
            if OSAtomicDecrement32(&jobsToDo) == 0 {
                finish()
            }
        }

        if validationLevel == .withNonce {
            getRequestNonce(completion: {
                snonce = $0

                if OSAtomicDecrement32(&jobsToDo) == 0 {
                    finish()
                }
            }, error: { completion(.failure($0 ?? AttestError.internal)) })
        }
    }

    func getRequestNonce(completion: @escaping (String) -> Void, error: @escaping (Error?) -> Void) {
        guard validationLevel == .withNonce else {
            error(AttestError.internal)
            return
        }

        // TODO: implement
    }

    static func nonce(uid: String, keyId: String, snonce: String) -> Data? {
        guard let nonceData = (uid + keyId + snonce).data(using: .utf8) else {
            return nil
        }

        return Data(SHA256.hash(data: nonceData))
    }

    static func requestHash(_ urlRequest: URLRequest) -> Data {
        let url = urlRequest.url?.absoluteString.data(using: .utf8) ?? Data()
        let method = (urlRequest.method?.rawValue ?? "").data(using: .utf8) ?? Data()
        let headers = (try? JSONSerialization.data(withJSONObject: urlRequest.allHTTPHeaderFields ?? [:], options: [.prettyPrinted, .sortedKeys])) ?? Data()

        return Data(SHA256.hash(data: url + method + headers + (urlRequest.httpBody ?? Data())))
    }

    static func nonce(_ requestHash: Data, snonce: String) -> Data {
        Data(SHA256.hash(data: requestHash + (snonce.data(using: .utf8) ?? Data())))
    }
}
