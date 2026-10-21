//
//  SplitTunnelManagerTests.swift
//  DVPNSDK
//

#if os(macOS)
import DVPNCoreKit
import DVPNSplitTunnelCore
@testable import DVPNTunnel
import Foundation
import NetworkExtension
import Testing

/// The one proxy configuration and how it follows the setting.
///
/// One fixed suite, emptied before and after each test.
@Suite(.serialized)
@MainActor
struct SplitTunnelManagerTests {
    private let suiteName = "com.example.vpn.tests.split-tunnel-manager"
    private let defaults: UserDefaults
    private let extensionID = "com.example.vpn.mac-split-tunnel-ne"
    private let enabled = SplitTunnelSettings(mode: .exceptSelected, apps: ["com.apple.curl"])

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func anEnabledSettingMakesTheOneConfigurationAndStartsTheProxy() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (manager, store) = makeManager()

        try await manager.apply(enabled)

        let profile = try #require(store.made.first)
        #expect(store.made.count == 1)
        #expect(profile.saves == 1 && profile.isEnabled)
        #expect(profile.providerBundleID == extensionID)
        #expect(profile.localizedDescription == "DVPN")
        #expect(profile.starts == 1 && profile.connectionStatus == .connected)
        #expect(!profile.isOnDemandEnabled)
        #expect(manager.settings() == enabled)
        #expect(await manager.isRunning())
    }

    /// A proxy configuration with on-demand loses it at the next launch: macOS keeps on-demand on one of an app's
    /// configurations at a time, and the proxy's took it off the connected tunnel.
    @Test
    func aConfigurationWithOnDemandLosesItAtTheLaunch() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try SplitTunnelSettingsStore.save(enabled, in: defaults)
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID, status: .connected)
        existing.isOnDemandEnabled = true
        let (manager, _) = makeManager([existing])

        try await manager.startIfEnabled()

        #expect(!existing.isOnDemandEnabled && existing.saves == 1)
        #expect(existing.stops == 0 && existing.starts == 0)
    }

    /// A change reaches the running proxy as a message, without a second configuration and without the restart that
    /// crashed the extension.
    @Test
    func aChangeReachesTheRunningProxyAsAMessage() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID, status: .connected)
        let (manager, store) = makeManager([existing])

        try await manager.apply(SplitTunnelSettings(mode: .allowSelected, apps: ["com.apple.Safari"]))

        #expect(store.made.isEmpty)
        #expect(existing.messages == [SplitTunnelMessage.reloadSettings.data])
        #expect(existing.stops == 0 && existing.starts == 0)
        #expect(existing.connectionStatus == .connected)
        #expect(manager.settings().mode == .allowSelected)
    }

    /// A running proxy that does not answer the message is restarted, so it still reads the change.
    @Test
    func aProxyThatDoesNotTakeTheMessageIsRestarted() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID, status: .connected)
        existing.messageError = NEVPNError(.connectionFailed)
        let (manager, _) = makeManager([existing])

        try await manager.apply(SplitTunnelSettings(mode: .allowSelected, apps: ["com.apple.Safari"]))

        #expect(existing.stops == 1 && existing.starts == 1)
        #expect(existing.connectionStatus == .connected)
    }

    @Test
    func disablingStopsTheProxy() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID, status: .connected)
        let (manager, _) = makeManager([existing])

        try await manager.apply(.disabled)

        #expect(existing.stops == 1 && existing.starts == 0)
        #expect(existing.connectionStatus == .disconnected)
        #expect(!manager.settings().isEnabled)
    }

    /// Stopping, as an app does when it no longer allows split tunnelling, keeps the setting for when it does again.
    @Test
    func stoppingKeepsTheSettingForLater() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID)
        let (manager, _) = makeManager([existing])
        try await manager.apply(enabled)

        await manager.stop()
        #expect(existing.connectionStatus == .disconnected && manager.settings() == enabled)

        try await manager.startIfEnabled()
        #expect(existing.connectionStatus == .connected)
    }

    @Test
    func theLaunchStartsTheProxyOnlyWhenTheSettingIsOn() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID)
        let (manager, _) = makeManager([existing])

        try await manager.startIfEnabled()
        #expect(existing.starts == 0)

        try SplitTunnelSettingsStore.save(enabled, in: defaults)
        try await manager.startIfEnabled()
        #expect(existing.starts == 1)
    }

    @Test
    func anAppWithoutTheExtensionRefuses() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (manager, store) = makeManager(extensionID: nil)

        #expect(!manager.isSupported)
        await #expect(throws: SplitTunnelError.self) { try await manager.apply(enabled) }
        #expect(store.made.isEmpty)
    }

    @Test
    func aRefusedSaveIsReported() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (manager, store) = makeManager()
        let refused = NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationReadWriteFailed.rawValue)
        store.onMake = { $0.saveError = refused }

        await #expect(throws: SplitTunnelError.self) { try await manager.apply(enabled) }
        #expect(store.made.first?.starts == 0)
        #expect(manager.settings() == .disabled, "a declined prompt leaves the setting as it was")
        #expect(store.profiles.isEmpty, "a declined prompt saves no configuration")
    }

    /// A launch leaves a running proxy as it is: it already has the saved setting, and restarting it crashed the
    /// extension.
    @Test(arguments: [NEVPNStatus.connected, .connecting, .reasserting])
    func theLaunchLeavesARunningProxyAlone(status: NEVPNStatus) async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try SplitTunnelSettingsStore.save(enabled, in: defaults)
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID, status: status)
        let (manager, _) = makeManager([existing])

        try await manager.startIfEnabled()

        #expect(existing.stops == 0 && existing.starts == 0)
        #expect(existing.connectionStatus == status)
    }

    /// A proxy on its way down, as the previous copy of the app stops it, is started again once it is down.
    @Test
    func theLaunchStartsAProxyThatIsStopping() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try SplitTunnelSettingsStore.save(enabled, in: defaults)
        let existing = FakeSplitTunnelProfile(providerBundleID: extensionID, status: .disconnecting)
        let (manager, _) = makeManager([existing])

        try await manager.startIfEnabled()

        #expect(existing.starts == 1)
        #expect(existing.connectionStatus == .connected)
    }

    /// A configuration removed in System Settings while the app runs is made again at the next change, as the first one
    /// was: starting the removed one never connects.
    @Test
    func aConfigurationRemovedInSystemSettingsIsMadeAgain() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let removed = FakeSplitTunnelProfile(providerBundleID: extensionID)
        let (manager, store) = makeManager([removed])
        try await manager.apply(enabled)
        // Removed in System Settings: the system drops the configuration and stops its proxy.
        store.profiles = []
        removed.connectionStatus = .invalid

        try await manager.apply(SplitTunnelSettings(mode: .allowSelected, apps: ["com.apple.Safari"]))

        #expect(removed.starts == 1 && removed.messages.isEmpty)
        let remade = try #require(store.made.first)
        #expect(store.made.count == 1 && store.profiles.first === remade)
        #expect(remade.saves == 1 && remade.providerBundleID == extensionID)
        #expect(remade.starts == 1 && remade.connectionStatus == .connected)
        #expect(manager.profile === remade, "the manager keeps the configuration it made")
        #expect(await manager.isRunning())
    }

    /// The configuration loaded last stays alive between calls, so the system goes on posting its proxy's status
    /// changes, which an app watches to restart a proxy that stopped.
    @Test
    func theConfigurationLoadedLastStaysAlive() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try SplitTunnelSettingsStore.save(enabled, in: defaults)
        let (manager, store) = makeManager()
        weak var loaded: FakeSplitTunnelProfile?
        do {
            let running = FakeSplitTunnelProfile(providerBundleID: extensionID, status: .connected)
            loaded = running
            store.profiles = [running]
        }

        try await manager.startIfEnabled()
        store.profiles = []

        withExtendedLifetime(manager) { #expect(loaded != nil, "the manager holds the configuration it loaded last") }
    }

    // MARK: Helpers

    private func makeManager(
        _ profiles: [FakeSplitTunnelProfile] = [],
        extensionID: String? = "com.example.vpn.mac-split-tunnel-ne"
    ) -> (SplitTunnelManager, FakeSplitTunnelProfileStore) {
        let store = FakeSplitTunnelProfileStore()
        store.profiles = profiles
        let configuration = DVPNCoreConfiguration(
            appGroupID: "group.com.example.vpn.tests",
            protocols: [
                TunnelProtocolDescriptor(id: .xray, providerBundleID: "com.example.vpn.mac-v2ray-ne", tunnelName: "DVPN", readiness: .immediate),
            ],
            splitTunnelProviderBundleID: extensionID
        )
        let manager = SplitTunnelManager(configuration: configuration, store: store, defaults: defaults, clock: StepClock())
        return (manager, store)
    }
}
#endif
