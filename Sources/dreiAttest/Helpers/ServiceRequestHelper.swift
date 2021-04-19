//
//  ServiceRequestHelper.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 01.02.21.
//

import Foundation
import Alamofire
import DeviceCheck
import CryptoKit
import DogSwift

public enum ValidationLevel {
    case signOnly, withNonce
}

private let defaultRequestNonce = "00000000-0000-0000-0000-000000000000"

struct ServiceRequestHelper {
    let baseUrl: URL
    let service = DCAppAttestService.shared
    let validationLevel: ValidationLevel

    func shouldHanlde(_ urlRequest: URLRequest) -> Bool {
        urlRequest.url?.isSubpath(of: baseUrl) == true
    }

    func adapt(_ urlRequest: URLRequest,
               for session: Session,
               uid: String,
               bypass sharedSecret: String,
               completion: (Result<URLRequest, Error>) -> Void) {
        // decide whether we have to handle the request before checking headers so we can have multiple AttestationServices running at the same time for different
        // baseUrls
        guard shouldHanlde(urlRequest) else {
            completion(.success(urlRequest))
            return
        }
        guard !urlRequest.headers.contains(where: { $0.name.starts(with: "Dreiattest-") }) else {
            completion(.failure(AttestError.illegalHeaders))
            return
        }

        var mutableRequest = urlRequest
        mutableRequest.addHeader(.uid(value: uid))
        mutableRequest.addHeader(.bypass(value: sharedSecret))

        completion(.success(mutableRequest))
    }

    private func sign(request: URLRequest,
                      requestHash: Data,
                      snonce: String,
                      keyId: String,
                      completion: @escaping (Result<URLRequest, Error>) -> Void) {

        var mutableRequest = request
        let nonce = Self.nonce(requestHash, snonce: snonce)

        Log.debug("Request hash:\n\(requestHash.base64EncodedString())", tag: "dreiAttest")
        Log.debug("Snonce:\n\(snonce)", tag: "dreiAttest")
        Log.debug("Nonce:\n\(nonce.base64EncodedString())", tag: "dreiAttest")

        service.generateAssertion(keyId, clientDataHash: nonce) { assertion, error in
            guard let assertion = assertion, error == nil else {
                completion(.failure(error ?? AttestError.internal))
                return
            }

            mutableRequest.addHeader(.signature(value: assertion.base64EncodedString()))
            mutableRequest.addHeader(.snonce(value: snonce))

            Log.info(mutableRequest, tag: "dreiAttest")
            Log.debug("Headers:\n\(mutableRequest.allHTTPHeaderFields as Any)", tag: "dreiAttest")
            Log.debug("Body:\n\(mutableRequest.httpBody?.base64EncodedString() as Any)", tag: "dreiAttest")

            completion(.success(mutableRequest))
        }
    }

    func adapt(_ urlRequest: URLRequest,
               for session: Session,
               uid: String,
               keyId: String,
               completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard !urlRequest.headers.contains(where: { $0.name.starts(with: "Dreiattest-") }) else {
            completion(.failure(AttestError.illegalHeaders))
            return
        }

        var mutableRequest = urlRequest
        mutableRequest.addHeader(.uid(value: uid))
        mutableRequest.addHeader(.userHeaders(value: Array((mutableRequest.allHTTPHeaderFields ?? [:]).keys)))

        var requestHash: Data?
        var snonce = defaultRequestNonce
        var jobsToDo: Int32 = validationLevel == .withNonce ? 2 : 1

        DispatchQueue.global(qos: .userInitiated).async {
            let hash = Self.requestHash(mutableRequest)
            requestHash = hash
            if OSAtomicDecrement32(&jobsToDo) == 0 {

                sign(request: mutableRequest, requestHash: hash, snonce: snonce, keyId: keyId, completion: completion)
            }
        }

        if validationLevel == .withNonce {
            getRequestNonce(completion: {
                snonce = $0

                if OSAtomicDecrement32(&jobsToDo) == 0 {
                    // swiftlint:disable:next force_unwrapping
                    sign(request: mutableRequest, requestHash: requestHash!, snonce: snonce, keyId: keyId, completion: completion)
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

    static func requestHash(_ urlRequest: URLRequest) -> Data {
        let url = urlRequest.url?.absoluteString.data(using: .utf8) ?? Data()
        let method = (urlRequest.method?.rawValue ?? "").data(using: .utf8) ?? Data()

//        TODO: Filter for userHeaders
        let headers = (try? JSONSerialization.data(withJSONObject: urlRequest.allHTTPHeaderFields ?? [:],
                                                   options: [.sortedKeys])) ?? Data()
        let requestData: Data = url + method
//            + headers
            + (urlRequest.httpBody ?? Data())
        Log.debug("RequestHashData: \(String(data: requestData, encoding: .utf8) ?? "")", tag: "dreiAttest")
        return Data(SHA256.hash(data: requestData))
    }

    static func nonce(_ requestHash: Data, snonce: String) -> Data {
        Data(SHA256.hash(data: requestHash + (snonce.data(using: .utf8) ?? Data())))
    }
}
