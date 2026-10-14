//
//  Logger+SDK.swift
//  DVPNSDK
//

import Foundation
import OSLog

extension Logger {
    /// The API client's log under the host app's bundle identifier, as the tunnel layer's (`makeLogger(category:)`),
    /// so a log an app exports by its subsystem has the requests too.
    static func sdk(category: String) -> Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "DVPNSDK", category: category)
    }
}
