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

private let endpointBase = "dreiattest"

struct Endpoints {
    static let registerKey = Endpoint(name: "\(endpointBase)/key", method: .post)
    static let deleteKey = Endpoint(name: "\(endpointBase)/key", method: .delete)
    static let keyRegistrationNonce = Endpoint(name: "\(endpointBase)/nonce", method: .get)
    static let requestNonce = Endpoint(name: "\(endpointBase)/request-nonce", method: .get)
}

private let headerPrefix = "Dreiattest"

extension HTTPHeader {
    static func uid(value: String) -> HTTPHeader {
        HTTPHeader(name: "\(headerPrefix)-Uid", value: value)
    }

    static func snonce(value: String) -> HTTPHeader {
        HTTPHeader(name: "\(headerPrefix)-Nonce", value: value)
    }

    static func signature(value: String) -> HTTPHeader {
        HTTPHeader(name: "\(headerPrefix)-Signature", value: value)
    }

    static func userHeaders(value: [String]) -> HTTPHeader {
        let headerName = "\(headerPrefix)-user-headers"
        let headers = (value + [headerName]).joined(separator: ",")
        return HTTPHeader(name: headerName, value: headers)
    }

    static func bypass(value: String) -> HTTPHeader {
        HTTPHeader(name: "\(headerPrefix)-shared-secret", value: value)
    }

    static var errorHeaderName: String {
        "\(headerPrefix)-error"
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

extension URL {
    func isSubpath(of other: URL) -> Bool {
        var absolute = other.absoluteString
        if !absolute.hasSuffix("/") {
            absolute += "/"
        }

        return absoluteString.hasPrefix(absolute)
    }
}
