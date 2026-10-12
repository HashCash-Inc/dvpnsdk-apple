//
//  XModel+Build.swift
//  DVPNSDK
//

import Foundation

extension XModel {
    mutating func build() throws -> Any {
        rules = rules.filter(\.__enabled__)
        return try JSONSerialization.jsonObject(with: try JSONEncoder().encode(self))
    }
}
