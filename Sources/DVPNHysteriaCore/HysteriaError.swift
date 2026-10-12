//
//  HysteriaError.swift
//  DVPNSDK
//

import Foundation

/// The SDK writes no user text: `description` is for the log.
public enum HysteriaError: Error, Equatable, Sendable, CustomStringConvertible {
    case storageUnavailable
    case noStoredConfiguration

    public var description: String {
        switch self {
        case .storageUnavailable:
            return "Hysteria config directory does not exist"
        case .noStoredConfiguration:
            return "No stored Hysteria configuration"
        }
    }
}
