//
//  AttestService.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation
import DeviceCheck

public final class AttestService {
    public let baseAddress: URL
    public let uid: String

    let service = DCAppAttestService.shared
    var serviceUid: String {
        UserDefaults.standard.serviceUid(for: uid)
    }

    public init(baseAddress: URL, uid: String) throws {
        guard service.isSupported else {
            throw AttestError.notSupported
        }

        self.baseAddress = baseAddress
        self.uid = uid
    }

    
}
