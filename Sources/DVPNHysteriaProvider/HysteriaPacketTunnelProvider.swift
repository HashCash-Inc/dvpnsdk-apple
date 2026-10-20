//
//  HysteriaPacketTunnelProvider.swift
//  DVPNSDK
//

import DVPNCoreKit
import DVPNHysteriaCore
import DVPNProxyProviderCore
import NetworkExtension
import os

// MARK: - HysteriaPacketTunnelProvider

/// Base packet tunnel provider for the Hysteria 2 network extension.
/// The extension target only subclasses it:
/// `final class PacketTunnelProvider: HysteriaPacketTunnelProvider {}`
///
/// The Hysteria client runs in-process through libhysteria and exposes a SOCKS5 server that the
/// shared `ProxyPacketTunnelProvider` plumbing connects to the tunnel interface.
open class HysteriaPacketTunnelProvider: ProxyPacketTunnelProvider {
    override public init() {
        super.init()
    }

    override open var nodeHost: String? {
        try? HysteriaConfigurationStore.loadCurrent().server
    }

    override open nonisolated(nonsending) func startProxy(network: NetworkModel, proxy: LocalProxy) async throws {
        var configuration = try HysteriaConfigurationStore.loadCurrent()
        configuration.socks5 = .local(proxy)

        logger.info("Starting libhysteria \(HysteriaBridge.version(), privacy: .public)")
        do {
            try HysteriaBridge.start(configJSON: try configuration.jsonString())
        } catch {
            // The provider logs and records this text for the app's log; libhysteria's can quote what it was given.
            throw NSError.newError(error.logDescription.redacting(configuration.credentials))
        }
    }

    override open func stopProxy() {
        do {
            try HysteriaBridge.stop()
        } catch {
            logger.error("Hysteria failed to stop: \(error.logDescription, privacy: .public)")
        }
    }
}
