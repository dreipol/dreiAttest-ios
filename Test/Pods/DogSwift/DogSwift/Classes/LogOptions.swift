//
//  LogOptions.swift
//
//  Created by Fabian Tinsz on 22.01.19.
//  Copyright © 2019 dreipol GmbH. All rights reserved.
//

import Foundation

/// Available logging levels are: `error`, `warn`, `info`, `debug`.
public enum Level: UInt8, CaseIterable {
    case debug = 1
    case info  = 2
    case warn  = 3
    case error = 4

    var description: String {
        return String(describing: self).uppercased()
    }
}

extension Level: Comparable {
    public static func < (lhs: Level, rhs: Level) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public static func == (lhs: Level, rhs: Level) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// MARK: -
public enum Tag: String {
    case none
    case network
    case database
    case system
    case ui
}
