//
//  ManualClock.swift
//  DVPNSDK
//

import Foundation
import Synchronization

/// A clock that moves only when the test advances it: a sleep suspends until the clock passes its deadline, so a
/// timeout elapses when the test says so and never on its own. `sleepers` counts the sleeps waiting, for the test to
/// advance once the code under test is in its wait.
final class ManualClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        let offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let state = Mutex<(now: Duration, sleepers: [UUID: Sleeper])>((.zero, [:]))

    var now: Instant { Instant(offset: state.withLock { $0.now }) }
    var minimumResolution: Duration { .zero }
    var sleepers: Int { state.withLock { $0.sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let outcome: Result<Void, any Error>? = state.withLock { state in
                    if Task.isCancelled { return .failure(CancellationError()) }
                    if deadline.offset <= state.now { return .success(()) }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let outcome { continuation.resume(with: outcome) }
            }
        } onCancel: {
            state.withLock { $0.sleepers.removeValue(forKey: id) }?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the clock forward and resumes every sleep whose deadline it passed.
    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now += duration
            let due = state.sleepers.filter { $0.value.deadline.offset <= state.now }
            due.keys.forEach { state.sleepers.removeValue(forKey: $0) }
            return Array(due.values)
        }
        due.forEach { $0.continuation.resume() }
    }
}

/// Polls `condition` every millisecond, for two seconds at most, so a test can wait for the code under test to reach
/// a state (a probe called, a sleep begun) without a fixed sleep of its own.
func eventually(_ condition: @Sendable () -> Bool) async {
    var tries = 0
    while !condition(), tries < 2000 {
        tries += 1
        try? await Task.sleep(for: .milliseconds(1))
    }
}
