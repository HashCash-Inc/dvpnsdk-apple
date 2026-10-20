//
//  NSError+Ext.swift
//  DVPNSDK
//

import Foundation

package extension NSError {
    /// The domain of the SDK's message errors: their message is the whole error.
    static let messageDomain = "io.dvpn.tunnel"

    static func newError(_ message: String) -> NSError {
        NSError(domain: messageDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
