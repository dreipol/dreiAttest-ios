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

    init(networkHelperType: NetworkHelper.Type,
         sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.af.default) {
        self.networkHelperType = networkHelperType
        self.sessionConfiguration = sessionConfiguration
    }
}

extension Config where NetworkHelper == DefaultKeyNetworkHelper {
    init() {
        self.init(networkHelperType: DefaultKeyNetworkHelper.self)
    }
}
