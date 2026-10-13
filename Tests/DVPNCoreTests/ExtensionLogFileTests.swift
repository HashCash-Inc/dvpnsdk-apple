//
//  ExtensionLogFileTests.swift
//  DVPNSDK
//

@testable import DVPNCoreKit
import Foundation
import os
import Testing

/// A provider's log file holds the lines the system kept of its process, in the export's line format, with
/// private arguments redacted as the system keeps them.
struct ExtensionLogFileTests {
    @Test
    func theFileHoldsALineLoggedJustBefore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = "ExtensionLogFileTests \(UUID().uuidString)"
        let secret = "secret-\(UUID().uuidString)"
        let logger = makeLogger(category: "ExtensionLogFileTests")
        logger.notice("\(marker, privacy: .public) token \(secret, privacy: .private)")

        ExtensionLogFile.dump(into: directory)

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let file = try #require(files.first { $0.pathExtension == "log" })
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.hasPrefix("# \(ProcessInfo.processInfo.processName) log, the hour before "))
        #expect(text.contains(marker))
        #expect(!text.contains(secret), "a private argument is not in the file")
        #expect(text.contains("<private>"))
    }
}
