//
//  ResolutionBudget.swift
//  DVPNSDK
//

import Foundation
import Synchronization

/// One resolution's budget: a single sleep on the resolver's clock, started at once. `wait()` returns when the budget
/// is spent, or at once when the waiter is cancelled; `isSpent` tells the two apart. `cancel()` ends the sleep when the
/// resolution finishes first, so no task outlives it.
final class ResolutionBudget: Sendable {
    private let shared: Shared
    private let sleep: Task<Void, Never>

    init(_ budget: Duration, clock: any Clock<Duration>) {
        let shared = Shared()
        self.shared = shared
        sleep = Task {
            do { try await clock.sleep(for: budget) } catch { return }
            shared.spend()
        }
    }

    var isSpent: Bool { shared.isSpent }

    func wait() async { await shared.wait() }

    func cancel() { sleep.cancel() }

    private final class Shared: Sendable {
        private let state = Mutex<(spent: Bool, waiters: [UUID: CheckedContinuation<Void, Never>])>((false, [:]))

        var isSpent: Bool { state.withLock { $0.spent } }

        func spend() {
            let waiters = state.withLock { state in
                state.spent = true
                let waiters = state.waiters
                state.waiters = [:]
                return waiters
            }
            waiters.values.forEach { $0.resume() }
        }

        func wait() async {
            let id = UUID()
            await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    let resumeNow = state.withLock { state in
                        if state.spent || Task.isCancelled { return true }
                        state.waiters[id] = continuation
                        return false
                    }
                    if resumeNow { continuation.resume() }
                }
            } onCancel: {
                state.withLock { $0.waiters.removeValue(forKey: id) }?.resume()
            }
        }
    }
}
