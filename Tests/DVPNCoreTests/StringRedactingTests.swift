//
//  StringRedactingTests.swift
//  DVPNSDK
//

import DVPNCoreKit
import Testing

/// An engine's text loses every credential it quotes, and keeps the rest.
struct StringRedactingTests {
    @Test
    func eachValueBecomesAnEllipsis() {
        #expect("user abc, password xyz".redacting(["abc", "xyz"]) == "user …, password …")
    }

    @Test
    func emptyValuesAreSkipped() {
        #expect("nothing to hide".redacting(["", "absent"]) == "nothing to hide")
    }

    /// A value holding another is replaced whole, not around the shorter one.
    @Test
    func longerValuesGoFirst() {
        #expect("id abc123".redacting(["abc", "abc123"]) == "id …")
    }
}
