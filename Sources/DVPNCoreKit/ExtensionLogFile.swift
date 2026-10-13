//
//  ExtensionLogFile.swift
//  DVPNSDK
//

import Foundation
import OSLog

/// A tunnel provider's own log lines, copied to a file in the App Group so the app can add them to a log it exports:
/// iOS shows a process no other process's log, and macOS refuses its local store to a sandboxed app. Each provider
/// writes its file when its tunnel stops or its start fails; one file per process, replaced each time.
///
/// Only what the system kept is copied, as the system kept it: an argument logged without `privacy: .public` is
/// `<private>` in the file too. Log nothing about the user, and the file carries nothing about the user.
public enum ExtensionLogFile {
    /// How far back a file reaches.
    public static let window: TimeInterval = 3600

    /// The directory the files live in, inside the App Group container; nil without one, or before the App Group is
    /// known (`DVPNCore.bootstrap(_:)` in the app, the Info.plist key in an extension).
    public static var directory: URL? {
        guard let appGroupID = TunnelEnvironment.knownAppGroupID,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else {
            return nil
        }
#if os(tvOS)
        return container.appendingPathComponent("Library/Caches/DVPNLogs")
#else
        return container.appendingPathComponent("Library/Logs/DVPN")
#endif
    }

    /// The files written so far, by name.
    public static func urls() -> [URL] {
        guard let directory else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Writes this process's lines of the last `window` to `<process>.log` in `directory`.
    package static func dump(now: Date = Date(), into directory: URL? = directory) {
        guard let directory else { return }
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let subsystem = Bundle.main.bundleIdentifier ?? "DVPNCore"
            let predicate = NSPredicate(format: "subsystem == %@", subsystem)
            let entries = try store.getEntries(at: store.position(date: now.addingTimeInterval(-window)), matching: predicate)
            let process = ProcessInfo.processInfo.processName
            let stamp = ISO8601DateFormatter()
            stamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var lines = ["# \(process) log, the hour before \(stamp.string(from: now))"]
            for case let entry as OSLogEntryLog in entries {
                lines.append("\(stamp.string(from: entry.date)) \(entry.process)[\(entry.category)] \(name(of: entry.level)): \(entry.composedMessage)")
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(process).log")
            try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Log file not written: \(error, privacy: .public)")
        }
    }

    private static func name(of level: OSLogEntryLog.Level) -> String {
        switch level {
        case .undefined: "undefined"
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        @unknown default: "unknown"
        }
    }
}
