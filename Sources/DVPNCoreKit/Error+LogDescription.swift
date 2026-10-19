//
//  Error+LogDescription.swift
//  DVPNSDK
//

import Foundation

package extension Error {
    /// What a log line or a recorded reason says of this error. The SDK's errors describe themselves
    /// (`CustomStringConvertible`): they carry no user text, so their `localizedDescription` says only "The operation
    /// couldn't be completed". Any other error gives the system's words.
    var logDescription: String {
        // Through `Any`: the compiler counts a cast from an error as certain, since every error bridges to NSError,
        // and warns; at run time it fails for an error that does not describe itself.
        if !(Self.self is NSError.Type), let described = self as Any as? any CustomStringConvertible {
            return described.description
        }
        return localizedDescription
    }
}
