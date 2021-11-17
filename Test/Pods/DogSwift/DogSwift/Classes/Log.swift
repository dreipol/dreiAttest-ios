//
//  Log.swift
//
//  Created by Fabian Tinsz on 04.10.18.
//  Copyright © 2018 dreipol GmbH. All rights reserved.
//

import Foundation
import os.log

public struct Log {
    public static func debug(
        _ message: Any,
        tag: TagProtocol = Tag.none,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line) {

        Log.print(.debug, tag.getTag(), message, file, function, line)
    }

    public static func info(
        _ message: Any,
        tag: TagProtocol = Tag.none,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line) {

        Log.print(.info, tag.getTag(), message, file, function, line)
    }

    public static func warning(
        _ message: Any,
        tag: TagProtocol = Tag.none,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line) {

        Log.print(.warn, tag.getTag(), message, file, function, line)
    }

    public static func error(
        _ error: Error? = nil,
        description: String? = nil,
        tag: TagProtocol = Tag.none,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line) {

        if let errorDescription = description {
            Log.print(.error, tag.getTag(), (errorDescription + ": " + error.debugDescription), file, function, line)
        } else {
            Log.print(.error, tag.getTag(), error.debugDescription, file, function, line)
        }
    }

    private static func shouldLog(with currentLoggingLevel: Level) -> Bool {
        guard let desiredLogLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"] else {
            return false
        }

        guard let logLevel = UInt8(desiredLogLevel), let maximumLoggingLevel = Level(rawValue: logLevel) else {
            return false
        }

        return currentLoggingLevel <= maximumLoggingLevel
    }

    private static func print(
        _ level: Level,
        _ tag: String,
        _ message: @autoclosure @escaping () -> Any,
        _ path: @autoclosure @escaping () -> String,
        _ function: @autoclosure @escaping () -> String,
        _ line: @autoclosure @escaping () -> Int) {

        if !shouldLog(with: level) {
            return
        }

        if #available(iOS 10.0, *) {
            let fileName = path().fileNameWithoutExtension
            os_log("[%@] [%@:%@] %@", log: OSLog.category(for: tag), type: OSLog.type(for: level),
                   level.description, fileName, String(describing: line()), String(describing: message()))
        } else {
            NSLog("[%@] [%@] %@", tag.description, level.description, String(describing: message()))
        }
    }
}

@available(iOS 10.0, *)
private extension OSLog {
    static func category(for tag: String) -> OSLog {
        return OSLog(
            subsystem: Bundle.main.bundleIdentifier!,
            category: tag.uppercased()
        )
    }

    static func type(for level: Level) -> OSLogType {
        switch level {
        case .error:
            return OSLogType.error
        case .info:
            return OSLogType.info
        case .debug:
            return OSLogType.debug
        default:
            return OSLogType.default
        }
    }
}

// MARK: - String extension
private extension String {
    private var removePathExtension: String {
        return (self as NSString).deletingPathExtension
    }

    private var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }

    var fileNameWithoutExtension: String {
        return lastPathComponent.removePathExtension
    }
}
