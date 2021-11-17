//
//  TagProtocol.swift
//  DogSwift
//
//  Created by Fabian Tinsz on 20.08.19.
//

public protocol TagProtocol {
    func getTag() -> String
}

// MARK: -
extension String: TagProtocol {
    public func getTag() -> String {
        return String(describing: self)
    }
}

extension Tag: TagProtocol {
    public func getTag() -> String {
        return String(describing: self)
    }
}
