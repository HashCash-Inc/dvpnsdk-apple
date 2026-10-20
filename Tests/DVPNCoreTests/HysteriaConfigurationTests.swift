//
//  HysteriaConfigurationTests.swift
//  DVPNSDK
//

import DVPNCoreKit
@testable import DVPNHysteriaCore
import Foundation
import Testing

struct HysteriaConfigurationTests {
    @Test
    func fixtureIsTheGoContract() throws {
        // The same document lives in GoBridge/libhysteria/testdata/config.json; both sides must accept it.
        let url = try #require(Bundle.module.url(forResource: "hysteria-config", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let configuration = try JSONDecoder().decode(HysteriaConfiguration.self, from: data)

        #expect(configuration.server == "203.0.113.10")
        #expect(configuration.bandwidth == .init(upMbps: 20, downMbps: 100))
        #expect(configuration.quic?.maxIdleTimeoutSec == 30)
        #expect(configuration.socks5 == .init(listen: "[::1]:8080", username: "local-user", password: "local-pass"))

        let canonicalFixture = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: data), options: [.sortedKeys])
        let rendered = try JSONSerialization.jsonObject(with: Data(configuration.jsonString().utf8))
        let reencoded = try JSONSerialization.data(withJSONObject: rendered, options: [.sortedKeys])
        #expect(String(decoding: reencoded, as: UTF8.self) == String(decoding: canonicalFixture, as: UTF8.self))
    }

    /// The extension's start replaces the stored SOCKS5 section with its local proxy.
    @Test
    func theLocalProxyGivesTheListenAddressAndCredentials() {
        let proxy = LocalProxy(port: 49_152, username: "user", password: "pass")
        #expect(HysteriaConfiguration.SOCKS5.local(proxy) == .init(listen: "[::1]:49152", username: "user", password: "pass"))
    }

    /// The credentials an engine's text must not show: the auth, the obfuscation password and the local proxy's.
    @Test
    func theCredentialsAreTheAuthTheObfsPasswordAndTheProxys() {
        var configuration = HysteriaConfiguration(server: "192.0.2.1", auth: "the-auth", obfs: .init(password: "the-obfs"))
        configuration.socks5 = .local(LocalProxy(port: 49_152, username: "user", password: "pass"))
        #expect(Set(configuration.credentials) == ["the-auth", "the-obfs", "user", "pass"])
        #expect("auth the-auth refused by 192.0.2.1".redacting(configuration.credentials) == "auth … refused by 192.0.2.1")
    }
}
