//
//  XrayInvokeSmokeTests.swift
//  DVPNSDK
//

@testable import DVPNXRayProvider
import Foundation
import Testing

/// LibXray validates one configuration at a time (`testXray` refuses a second instance), so every
/// suite that calls it nests here and runs serialized.
@Suite(.serialized)
enum LibXrayTests {}

extension LibXrayTests {
    /// Proves the Go c-archive links into the test bundle and the Invoke envelope round-trips.
    @Suite(.serialized)
    struct XrayInvokeSmokeTests {
        @Test
        func versionIsReported() throws {
            let version = try XrayInvoke.xrayVersion()
            #expect(!version.isEmpty)
            #expect(version != "unknown")
        }

        @Test
        func notRunningByDefault() {
            #expect(!XrayInvoke.isRunning())
        }

        @Test
        func xrayRejectsGarbage() {
            #expect(throws: (any Error).self) { try XrayInvoke.testXray(configJSON: "{\"outbounds\":[{\"protocol\":\"nope\"}]}") }
        }

        @Test
        func xrayAcceptsMinimalConfig() throws {
            try XrayInvoke.testXray(configJSON: "{\"outbounds\":[{\"protocol\":\"freedom\",\"tag\":\"direct\"}]}")
        }

        /// Xray quotes a malformed user ID whole in its error, VLESS or VMess: one of 31 characters, or 37 and more (one of
        /// 1 to 30 becomes a name-based UUID, and one of 32 to 36 hex digits is read as a UUID). The reason a start error
        /// is cleaned of every credential before it is logged or recorded.
        @Test(arguments: [("vless", 31), ("vless", 37), ("vmess", 31)])
        func xrayQuotesAMalformedUserID(protocolName: String, length: Int) {
            let id = String(repeating: "7", count: length)
            let user = protocolName == "vless" ? #"{"id":"\#(id)","encryption":"none"}"# : #"{"id":"\#(id)"}"#
            let outbound = #"{"protocol":"\#(protocolName)","settings":{"vnext":[{"address":"192.0.2.1","port":443,"users":[\#(user)]}]}}"#
            do {
                try XrayInvoke.testXray(configJSON: #"{"outbounds":[\#(outbound)]}"#)
                Issue.record("Xray accepted a \(length)-character \(protocolName) ID")
            } catch {
                #expect(error.localizedDescription.contains(id))
            }
        }

        /// The provider's start text, which it logs and records for the app, shows every credential as "…" and keeps
        /// Xray's words.
        @Test
        func theStartTextShowsNoCredential() {
            let id = String(repeating: "7", count: 37)
            let outbound = #"{"protocol":"vless","settings":{"vnext":[{"address":"192.0.2.1","port":443,"users":[{"id":"\#(id)","encryption":"none"}]}]}}"#
            do {
                try XrayInvoke.testXray(configJSON: #"{"outbounds":[\#(outbound)]}"#)
                Issue.record("Xray accepted a 37-character ID")
            } catch {
                let text = XrayPacketTunnelProvider.startErrorText(error, credentials: [id, "proxy-user", "proxy-pass"])
                #expect(!text.contains(id))
                #expect(text.contains("…"))
                #expect(text.contains("invalid UUID"))
            }
        }
    }
}
