//
//  MockNetworkHelpers.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 19.01.21.
//

import Foundation
import Alamofire

class KeyCountingNetworkHelper: _NetworkHelper {
    var registerCount = 0

    required init(baseUrl: URL, sessionConfiguration: URLSessionConfiguration, validationLevel: ValidationLevel) {}

    func registerNewKey(keyId: String, uid: String, callback: @escaping () -> Void, error: @escaping (Error?) -> Void) {
        registerCount += 1
        callback()
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, uid: String, keyId: String, completion: @escaping (Result<URLRequest, Error>) -> Void) {}
}
