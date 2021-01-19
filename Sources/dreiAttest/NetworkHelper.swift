//
//  NetworkHelper.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation

// TODO: make sealed if this proposal is ever accepted: https://forums.swift.org/t/sealed-protocols/19118
public protocol _NetworkHelper {
    init(baseUrl: URL)

    func registerNewKey(keyId: String, callback: @escaping () -> Void, error: (Error?) -> Void)
}

public struct DefaultNetworkHelper: _NetworkHelper {
    let baseUrl: URL

    /**
     Do not use!
     */
    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    /**
     Do not use!
     */
    // TODO: make internal when _NetworkHelper is sealed
    public func registerNewKey(keyId: String, callback: @escaping () -> Void, error: (Error?) -> Void) {
    }
}
