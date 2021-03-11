//
//  Closure+Composition.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 11.03.21.
//

import Foundation

infix operator ++

func ++<T, R>(first: @escaping (T) -> Void, second: @escaping () -> R) -> (T) -> R {
    return {
        first($0)
        return second()
    }
}
