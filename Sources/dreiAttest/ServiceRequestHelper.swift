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
        guard !urlRequest.headers.contains(where: { $0.name.starts(with: "dreiAttest-") }) else {
            completion(.failure(AttestError.illegalHeaders))
            return
        }

        var mutableRequest = urlRequest
        mutableRequest.addHeader(.uid(value: uid))
        mutableRequest.addHeader(.bypass(value: sharedSecret))

        completion(.success(mutableRequest))
    }

    func adapt(_ urlRequest: URLRequest,
               for session: Session,
               uid: String,
               keyId: String,
               completion: @escaping (Result<URLRequest, Error>) -> Void) {
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
            // swiftlint:disable:next force_unwrapping
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

    static func requestHash(_ urlRequest: URLRequest) -> Data {
        let url = urlRequest.url?.absoluteString.data(using: .utf8) ?? Data()
        let method = (urlRequest.method?.rawValue ?? "").data(using: .utf8) ?? Data()
        let headers = (try? JSONSerialization.data(withJSONObject: urlRequest.allHTTPHeaderFields ?? [:],
                                                   options: [.prettyPrinted, .sortedKeys])) ?? Data()

        return Data(SHA256.hash(data: url + method + headers + (urlRequest.httpBody ?? Data())))
    }

    static func nonce(_ requestHash: Data, snonce: String) -> Data {
        Data(SHA256.hash(data: requestHash + (snonce.data(using: .utf8) ?? Data())))
    }
}
