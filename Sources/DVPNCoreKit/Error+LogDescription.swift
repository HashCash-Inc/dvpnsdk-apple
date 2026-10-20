//
//  Error+LogDescription.swift
//  DVPNSDK
//

import Foundation

package extension Error {
    /// What a log line or a recorded reason says of this error, never the error whole: printed whole, an error carries
    /// its user info (a file's full path) or a Swift error's values (a key, an address).
    ///
    /// - The SDK's errors describe themselves (`CustomStringConvertible`): they carry no user text, so their
    ///   `localizedDescription` says only "The operation couldn't be completed", and their own words are kept.
    /// - The SDK's message errors (`NSError.newError`) give their message.
    /// - Any other Swift enum error gives its type and case, never the case's values, unless it bridges to a system
    ///   domain.
    /// - Any other error gives the system's words with its domain and code, and those of the error under it. A file
    ///   error's words name the file and the folder it is in, which are the SDK's own fixed names; never the path.
    var logDescription: String {
        // Through `Any`: the compiler counts a cast from an error as certain, since every error bridges to NSError,
        // and warns; at run time it fails for an error that does not describe itself.
        if !(Self.self is NSError.Type), let described = self as Any as? any CustomStringConvertible {
            return described.description
        }
        let error = self as NSError
        if error.domain == NSError.messageDomain {
            return error.localizedDescription
        }
        // An enum that bridges to a system domain (`CustomNSError`, such as Network's `NWError`) is a system error: its
        // words and codes say more than its case.
        if !(Self.self is NSError.Type), !(self as Any is any CustomNSError), let caseName {
            return "\(Self.self).\(caseName)"
        }
        var codes = "\(error.domain) \(error.code)"
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            codes += ", \(underlying.domain) \(underlying.code)"
        }
        // An error with no words of its own gets the system's "The operation couldn't be completed. (<domain> error
        // <code>.)": its codes alone say as much.
        let words = error.localizedDescription
        return words.hasSuffix("(\(error.domain) error \(error.code).)") ? codes : "\(words) (\(codes))"
    }

    /// An enum's case, without its values; nil for any other type.
    private var caseName: String? {
        let mirror = Mirror(reflecting: self)
        guard mirror.displayStyle == .enum else { return nil }
        // A case with values is the mirror's one child, labelled with the case; a case without is its own name.
        return mirror.children.first?.label ?? String(describing: self)
    }
}
