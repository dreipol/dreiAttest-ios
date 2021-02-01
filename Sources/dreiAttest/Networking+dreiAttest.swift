//
//  Networking+dreiAttest.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 01.02.21.
//

import Foundation
import Alamofire

struct Endpoint {
    let name: String
    let method: HTTPMethod
}

struct Endpoints {
    static let registerKey = Endpoint(name: "dreiAttest/key", method: .post)
    static let deleteKey = Endpoint(name: "dreiAttest/key", method: .delete)
    static let keyRegistrationNonce = Endpoint(name: "dreiAttest/nonce", method: .get)
    static let requestNonce = Endpoint(name: "dreiAttest/request_nonce", method: .get)
}

extension HTTPHeader {
    static func uid(value: String) -> HTTPHeader {
        HTTPHeader(name: "dreiAttest-uid", value: value)
    }

    static func signature(value: String) -> HTTPHeader {
        HTTPHeader(name: "dreiAttest-signature", value: value)
    }
}

extension Session {
    func request(baseUrl: URL, endpoint: Endpoint, headers: HTTPHeaders, payload: [String: Any]? = nil) throws -> DataRequest {
        var request = try URLRequest(url: baseUrl.appendingPathComponent(endpoint.name), method: endpoint.method, headers: headers)
        if let payload = payload {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        }

        return self.request(request)
    }

    // Used to capture reference to session so it is only deinitialized after a request completes
    func close() {}
}

extension URLRequest {
    mutating func addHeader(_ header: HTTPHeader) {
        addValue(header.value, forHTTPHeaderField: header.name)
    }
}