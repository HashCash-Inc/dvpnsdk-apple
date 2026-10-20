//
//  String+Redacting.swift
//  DVPNSDK
//

import Foundation

package extension String {
    /// This text with each of `values` replaced by "…": an engine's text can quote what it was given, a credential
    /// included. Longer values go first, so a value holding another is replaced whole; empty values are skipped.
    func redacting(_ values: [String]) -> String {
        values.filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .reduce(self) { text, value in text.replacingOccurrences(of: value, with: "…") }
    }
}
