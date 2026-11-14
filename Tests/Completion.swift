//
//  Completion.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Testing

/// An async counterpart to `XCTestExpectation` for Swift Testing.
///
/// Call `complete()` from a callback, then `await wait()` later in the test. If the completion doesn't happen within
/// `timeout` seconds of starting to wait, `wait()` records an issue and returns, like `waitForExpectations(timeout:)`.
/// Waiting suspends the test's task rather than blocking a thread.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class Completion: @unchecked Sendable {
    /// What's being waited for, used in recorded issues.
    let description: String
    /// The number of `complete()` calls needed, like `XCTestExpectation.expectedFulfillmentCount`.
    let expectedCount: Int
    /// How long `wait()` waits, in seconds, before recording an issue.
    let timeout: TimeInterval

    private let sourceLocation: SourceLocation
    private let lock = NSLock()
    private var count = 0
    private var waiter: CheckedContinuation<Bool, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// Creates a completion.
    ///
    /// - Parameters:
    ///   - description:    What's being waited for, used in recorded issues.
    ///   - expectedCount:  The number of `complete()` calls needed. `1` by default.
    ///   - timeout:        How long `wait()` waits, in seconds. `10` by default, matching `BaseTestCase.timeout`.
    ///   - sourceLocation: Where issues for extra `complete()` calls are recorded. The call site by default.
    init(_ description: String,
         expectedCount: Int = 1,
         timeout: TimeInterval = 10,
         sourceLocation: SourceLocation = SourceLocation(fileID: #fileID,
                                                         filePath: #filePath,
                                                         line: #line,
                                                         column: #column)) {
        self.description = description
        self.expectedCount = expectedCount
        self.timeout = timeout
        self.sourceLocation = sourceLocation
    }

    /// Records one completion, resuming `wait()` once `expectedCount` is reached. Safe to call from any thread.
    ///
    /// Calls past `expectedCount` record an issue, like an over-fulfilled expectation.
    func complete() {
        let (continuation, isOverCompleted) = withLock { () -> (CheckedContinuation<Bool, Never>?, Bool) in
            count += 1
            guard count <= expectedCount else { return (nil, true) }
            guard count == expectedCount else { return (nil, false) }

            timeoutTask?.cancel()
            timeoutTask = nil
            defer { waiter = nil }

            return (waiter, false)
        }

        if isOverCompleted {
            Issue.record("\(description) was completed more than \(expectedCount) time(s).", sourceLocation: sourceLocation)
        }

        continuation?.resume(returning: true)
    }

    /// Suspends until `expectedCount` completions have happened, or records an issue after `timeout` seconds.
    ///
    /// Returns immediately if the completions already happened.
    func wait(sourceLocation: SourceLocation = SourceLocation(fileID: #fileID,
                                                              filePath: #filePath,
                                                              line: #line,
                                                              column: #column)) async {
        guard withLock({ waiter == nil }) else {
            Issue.record("wait() was called on \(description) while another wait() was in progress.", sourceLocation: sourceLocation)
            return
        }

        let isCompleted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let isAlreadyCompleted = withLock { () -> Bool in
                guard count < expectedCount else { return true }

                waiter = continuation
                timeoutTask = Task { [timeout] in
                    do {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    } catch {
                        return // Cancelled by complete().
                    }
                    self.timeOut()
                }

                return false
            }

            if isAlreadyCompleted { continuation.resume(returning: true) }
        }

        guard !isCompleted else { return }

        let completedCount = withLock { count }
        Issue.record("Timed out after \(timeout) seconds waiting for \(description) (\(completedCount) of \(expectedCount) completions).",
                     sourceLocation: sourceLocation)
    }

    private func timeOut() {
        let continuation = withLock { () -> CheckedContinuation<Bool, Never>? in
            defer {
                waiter = nil
                timeoutTask = nil
            }

            return waiter
        }

        continuation?.resume(returning: false)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }

        return body()
    }
}

// MARK: - Tests

@Suite
struct CompletionTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitReturnsWhenCompletedBeforeWaiting() async {
        // Given
        let completion = Completion("completed before waiting")

        // When
        completion.complete()

        // Then
        await completion.wait()
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitReturnsWhenCompletedWhileWaiting() async {
        // Given
        let completion = Completion("completed while waiting")

        // When
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { completion.complete() }

        // Then
        await completion.wait()
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitReturnsOnlyAfterExpectedCountCompletions() async {
        // Given
        let completion = Completion("three completions", expectedCount: 3)

        // When
        for _ in 0..<3 {
            DispatchQueue.global().async { completion.complete() }
        }

        // Then
        await completion.wait()
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitRecordsIssueOnTimeout() async {
        // Given
        let completion = Completion("never completed", expectedCount: 2, timeout: 0.1)
        completion.complete()

        // When, Then
        await withKnownIssue {
            await completion.wait()
        } matching: { issue in
            issue.description.contains("Timed out after 0.1 seconds waiting for never completed (1 of 2 completions).")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func extraCompletionRecordsIssue() async {
        // Given
        let completion = Completion("completed twice")

        // When, Then
        completion.complete()
        withKnownIssue {
            completion.complete()
        } matching: { issue in
            issue.description.contains("completed twice was completed more than 1 time(s).")
        }
        await completion.wait()
    }
}
