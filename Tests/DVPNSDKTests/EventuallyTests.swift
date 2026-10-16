//
//  EventuallyTests.swift
//  DVPNSDK
//

import Testing

/// The tests' wait for a state fails when the state never comes, instead of letting the test step a clock too early
/// and hang.
struct EventuallyTests {
    @Test
    func aConditionThatNeverHoldsFailsTheWait() async {
        await #expect(throws: ConditionNotMet.self) { try await eventually(within: .milliseconds(20)) { false } }
    }

    @Test
    func aConditionThatHoldsEndsTheWait() async throws {
        try await eventually { true }
    }
}
