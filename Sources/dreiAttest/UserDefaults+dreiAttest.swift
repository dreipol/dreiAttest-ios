//
//  UserDefaults+dreiAttest.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation

enum Key {
    case uid(String)

    var key: String {
        String(reflecting: self.self)
    }
}

extension UserDefaults {
    func serviceUid(for uid: String) -> String {
        if let serviceUid = string(forKey: Key.uid(uid).key) {
            return serviceUid
        }

        let serviceUid = "\(uid);\(UUID().uuidString)"
        setValue(serviceUid, forKey: Key.uid(uid).key)
        return serviceUid
    }
}
