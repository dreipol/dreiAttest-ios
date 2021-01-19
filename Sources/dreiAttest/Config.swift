//
//  Config.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation

struct Config<NetworkHelper> {
    let networkHelperType: NetworkHelper.Type

    init(networkHelperType: NetworkHelper.Type) {
        self.networkHelperType = networkHelperType
    }
}

extension Config where NetworkHelper == DefaultNetworkHelper {
    init() {
        self.init(networkHelperType: DefaultNetworkHelper.self)
    }
}
