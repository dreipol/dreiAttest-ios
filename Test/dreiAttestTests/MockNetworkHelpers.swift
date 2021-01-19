//
//  MockNetworkHelpers.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 19.01.21.
//

import Foundation

class KeyCountingNetworkHelper: _NetworkHelper {
    var registerCount = 0

    required init(baseUrl: URL) {}

    func registerNewKey(keyId: String, callback: @escaping () -> Void, error: (Error?) -> Void) {
        registerCount += 1
        callback()
    }
}
