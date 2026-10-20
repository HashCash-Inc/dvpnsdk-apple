//
//  TunnelErrorTests.swift
//  DVPNSDK
//

import DVPNCoreKit
@testable import DVPNTunnel
import Foundation
import NetworkExtension
import Testing

/// Only a declined "Add VPN Configurations" prompt counts as a denied permission.
struct TunnelErrorTests {
    @Test
    func aDeclinedPromptIsAPermissionDenial() {
        let denied = NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationReadWriteFailed.rawValue)
        #expect(TunnelsServiceError.addTunnelFailed(systemError: denied).isPermissionDenied)
    }

    @Test
    func otherFailuresAreNot() {
        let invalid = NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationInvalid.rawValue)
        let diskFull = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)

        #expect(!TunnelsServiceError.addTunnelFailed(systemError: invalid).isPermissionDenied)
        #expect(!TunnelsServiceError.addTunnelFailed(systemError: diskFull).isPermissionDenied)
        #expect(!TunnelsServiceError.activationFailed(.handshakeTimedOut).isPermissionDenied)
        #expect(!TunnelsServiceError.emptyCredentials.isPermissionDenied)
    }

    /// A start that failed names the system's error by its domain and code, and an SDK message error by its words.
    @Test
    func aFailedStartNamesItsErrorsCode() {
        let systemError = NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationInvalid.rawValue)
        let description = TunnelActivationError.startingFailed(systemError: systemError).description
        #expect(description.hasPrefix("Starting failed due to "))
        #expect(description.contains("NEVPNErrorDomain 1"))
        #expect(!description.contains("NEVPNErrorDomain error 1"))

        let message = TunnelActivationError.startingFailed(systemError: NSError.newError("reason"))
        #expect(message.description == "Starting failed due to reason")
    }
}
