//
//  Config.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation

struct Config<NetworkHelper> {
    let networkHelperType: NetworkHelper.Type
    let sessionConfiguration: URLSessionConfiguration
    let sharedSecret: String?

    init(networkHelperType: NetworkHelper.Type,
         sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.af.default,
         sharedSecret: String? = ProcessInfo.processInfo.environment["DREIATTEST_BYPASS_SECRET"]) {
        self.networkHelperType = networkHelperType
        self.sessionConfiguration = sessionConfiguration
        self.sharedSecret = sharedSecret
    }
}

extension Config where NetworkHelper == DefaultKeyNetworkHelper {
    init(sharedSecret: String? = ProcessInfo.processInfo.environment["DREIATTEST_BYPASS_SECRET"]) {
        self.init(networkHelperType: DefaultKeyNetworkHelper.self, sharedSecret: sharedSecret)
    }
}
