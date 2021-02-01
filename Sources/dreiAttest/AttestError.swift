//
//  AttestError.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import Foundation

public enum AttestError: Error {
    case notSupported
    case `internal`
    case policyViolation
    case nonceMismatch
    case illegalHeaders

    static func from(_ key: String) -> AttestError {
        switch key {
        case "dreiAttest_policy_violation":
            return .policyViolation
        case "dreiAttest_nonce_mismatch":
            return .policyViolation
        default:
            return .internal
        }
    }
}
