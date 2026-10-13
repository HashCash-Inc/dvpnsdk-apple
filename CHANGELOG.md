# Changelog

Changes that apps can notice, newest first, in the style of [Keep a Changelog](https://keepachangelog.com). The
versions follow [Semantic Versioning](https://semver.org); until 1.0.0 a minor version may change the API.

## Unreleased

### Added

- `ExtensionLogFile`: each tunnel provider writes the lines the system kept of its own process to a file in the App
  Group when its tunnel stops or its start fails (`ExtensionLogFile.directory`, `urls()`), so an app can add the
  extensions' lines to a log it exports. Arguments logged as private stay `<private>`.

### Changed

- The errors (`TunnelsServiceError`, `TunnelActivationError`, `SplitTunnelError`, `XraySourceError`, `HysteriaError`,
  `XConfigurationError`, `AmneziaWGParameterError`, `TLSLeafProbe.Error`) are no longer `LocalizedError`s: the SDK writes no user text. Each describes itself for the log
  (`CustomStringConvertible`), and `TunnelsServiceError` and `TunnelActivationError` compare by case, a system error
  counting by its domain and code.
- `SplitTunnelSettings.Mode` is `CaseIterable`.
- Only the package sees what only it uses: `XraySourceStore.removeIfUnreadable()`, `HysteriaConfigurationStore`,
  `TunnelConfigDirectories.homeDirectory` and `SplitTunnelManager.isSupported` are `package`, and
  `XrayDocumentBuilder`'s tags are internal.

### Fixed

- After a start that failed or timed out, a refused save of the profile with on-demand off is tried once more and
  logged, instead of being dropped silently with on-demand left on.

### Removed

- `NetworkModel.current`, `NetworkModel.save()` and `TunnelConfigDirectories.network`: the proxy providers run with
  `NetworkModel.default`, the only value ever stored.

## 0.2.0 (2026-10-12)

The engines are those of 0.1.0.

### Added

- `TunnelManager.connectedNode()`: the address or host name of the node the running tunnel connects to, as the
  tunnel's provider recorded it, or nil while the tunnel is down.
- `TunnelManager.restart()` starts the tunnel again on the node it last used, with the DNS and obfuscation settings
  as they are now, without new credentials. With nothing stored to start from, it throws the new
  `TunnelsServiceError.noStoredConfiguration` and leaves the tunnel as it is.

### Fixed

- macOS split tunnelling: an app's helper processes follow the app. A flow whose signing identifier extends a selected
  app's with a dot (`com.example.app.helper`) counts as that app's.
- A request is tried when the network path requires a connection, such as an on-demand VPN coming up, instead of
  failing at once as offline.
- macOS: with split tunnelling on, Hysteria 2 connects. The split-tunnel proxy was offered the tunnel's own UDP flow to
  its node and declined it, which broke the socket. The tunnels now record their node, and the proxy leaves its
  addresses out of its rules.
- A request now ends within its own timeout across the primary and the mirrors. A primary that answered with a server
  error and a mirror that did not answer used to add up to minutes for one request, as each mirror attempt waited the
  full timeout. At the deadline the request ends with the primary's answer, or with a timeout.
- Xray and V2Ray connections go to the address the device looked up through its own DNS. The client used to hand the
  node each sniffed site name, so the node looked it up again with its own resolver and used that answer instead;
  sniffing now only chooses routes (`routeOnly`).

## 0.1.0

The first release: the DVPN SDK API client and the WireGuard/AmneziaWG, Xray and Hysteria 2 tunnels in one package,
with the engines as prebuilt release assets.
