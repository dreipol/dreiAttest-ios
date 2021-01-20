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

extension HTTPHeader {
    static func connection(value: String) -> HTTPHeader {
        HTTPHeader(name: "Connection", value: value)
    }

    static func uid(value: String) -> HTTPHeader {
        HTTPHeader(name: "dreiAttest-uid", value: value)
    }

    static func signature(value: String) -> HTTPHeader {
        HTTPHeader(name: "dreiAttest-signature", value: value)
    }
}

extension Session {
    // Used to capture reference to session so it is only deinitialized after a request completes
    func close() {}
}

// TODO: make sealed if this proposal is ever accepted: https://forums.swift.org/t/sealed-protocols/19118
public protocol _NetworkHelper {
    init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration)

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void)
}

public struct DefaultNetworkHelper: _NetworkHelper {
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

    /**
     Do not use!
     */
    // TODO: make internal when _NetworkHelper is sealed
    public func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        let session = Session(configuration: sessionConfiguration)
        let getNonceHeaders = HTTPHeaders([.connection(value: "keep-alive"), .contentType("text/plain")])
        session.request(baseUrl.appendingPathComponent("dreiAttest/getNonce"), method: .get, headers: getNonceHeaders)
            .responseString { snonce in
                switch snonce.result {
                case .success(let snonce):
                    guard let nonceData = (uid + keyId + snonce).data(using: .utf8) else {
                        error(AttestError.internal)
                        return
                    }

                    let nonce = Data(SHA256.hash(data: nonceData))
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
                            var request = try URLRequest(url: baseUrl.appendingPathComponent("dreiAttest/publishKey"), method: .post, headers: headers)
                            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)

                            session.request(request).response { response in
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
                case .failure(let err):
                    error(err)
                }
        }.resume()
    }
}
