//
//  UserDefaults+dreiAttest.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation

enum Key {
    case uid(String)
    case keyId(uid: String)

    var key: String {
        String(reflecting: self.self)
    }
}

struct SimulatedDictionary {
    let userDefaults: UserDefaults
    let keyGenerator: (String) -> Key

    subscript(key: String) -> String? {
        get {
            userDefaults.string(forKey: keyGenerator(key).key)
        }
        nonmutating set {
            userDefaults.setValue(newValue, forKey: keyGenerator(key).key)
        }
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

    var keyIds: SimulatedDictionary {
        SimulatedDictionary(userDefaults: self, keyGenerator: Key.keyId(uid:))
    }
}
