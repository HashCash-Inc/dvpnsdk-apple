//
//  ErrorLogDescriptionTests.swift
//  DVPNSDK
//

@testable import DVPNCoreKit
import DVPNXRayCore
import Foundation
import Testing

/// A recorded reason keeps an SDK error's own words, and a system error's.
struct ErrorLogDescriptionTests {
    @Test
    func anSDKErrorGivesItsOwnDescription() {
        let error: any Error = XraySourceError.unreadable("the file is cut short")
        #expect(error.logDescription == XraySourceError.unreadable("the file is cut short").description)
        #expect(!error.logDescription.contains("couldn’t be completed"))
    }

    @Test
    func aSystemErrorGivesItsLocalizedWords() {
        let error: any Error = NSError(domain: "Go", code: 1, userInfo: [NSLocalizedDescriptionKey: "no valid outbound found"])
        #expect(error.logDescription == "no valid outbound found")
    }
}
