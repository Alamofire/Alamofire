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
    /// When `expectedCount` was reached, relative to every other `Completion`, for `wait(for:enforceOrder:)`.
    private var completionOrder: UInt64?
    private var waiter: CheckedContinuation<Bool, Never>?
    private var timeoutTask: Task<Void, Never>?
    /// Removes the notification observer of a completion made by `notification(_:object:center:handler:)`.
    private var stopObserving: (() -> Void)?
    /// Whether a notification completion is still waiting for an accepted notification.
    private var isObservingNotification = false

    deinit {
        stopObserving?()
    }

    /// Creates a completion.
    ///
    /// - Parameters:
    ///   - description:    What's being waited for, used in recorded issues.
    ///   - expectedCount:  The number of `complete()` calls needed. `1` by default.
    ///   - timeout:        How long `wait()` waits, in seconds. `10` by default, matching `BaseTestCase.timeout`.
    ///   - fileID:         With `filePath`, `line`, and `column`, where issues for extra `complete()` calls are
    ///                     recorded. The call site by default.
    init(_ description: String,
         expectedCount: Int = 1,
         timeout: TimeInterval = 10,
         fileID: String = #fileID,
         filePath: String = #filePath,
         line: Int = #line,
         column: Int = #column) {
        self.description = description
        self.expectedCount = expectedCount
        self.timeout = timeout
        sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    }

    /// Records one completion, resuming `wait()` once `expectedCount` is reached. Safe to call from any thread.
    ///
    /// Calls past `expectedCount` record an issue, like an over-fulfilled expectation.
    func complete() {
        let (continuation, isOverCompleted) = withLock { () -> (CheckedContinuation<Bool, Never>?, Bool) in
            count += 1
            guard count <= expectedCount else { return (nil, true) }
            guard count == expectedCount else { return (nil, false) }

            completionOrder = CompletionOrder.shared.next()
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

    /// Creates a completion that completes when `center` posts a `name` notification that `handler` accepts, like
    /// `XCTestCase.expectation(forNotification:object:handler:)`.
    ///
    /// The completion stops observing once a notification is accepted, or when it's deinitialized.
    ///
    /// - Parameters:
    ///   - name:    The notification name to observe.
    ///   - object:  The object whose notifications to observe, or `nil` for any object.
    ///   - center:  The `NotificationCenter` to observe. `.default` by default.
    ///   - timeout: How long `wait()` waits, in seconds. `10` by default.
    ///   - handler: Returns whether a notification completes the completion. Accepts every notification by default.
    static func notification(_ name: Notification.Name,
                             object: AnyObject? = nil,
                             center: NotificationCenter = .default,
                             timeout: TimeInterval = 10,
                             fileID: String = #fileID,
                             filePath: String = #filePath,
                             line: Int = #line,
                             column: Int = #column,
                             handler: @escaping @Sendable (Notification) -> Bool = { _ in true }) -> Completion {
        let completion = Completion("notification \(name.rawValue)",
                                    timeout: timeout,
                                    fileID: fileID,
                                    filePath: filePath,
                                    line: line,
                                    column: column)
        // Mark the completion as observing before registering, so a notification posted right away still counts.
        completion.withLock { completion.isObservingNotification = true }
        // The observer holds the completion weakly, so the completion's deinit can remove it.
        let observer = center.addObserver(forName: name, object: object, queue: nil) { [weak completion] notification in
            guard let completion, handler(notification) else { return }

            completion.completeObservedNotification()
        }
        let removeObserver = { center.removeObserver(observer) }
        let isStillObserving = completion.withLock { () -> Bool in
            guard completion.isObservingNotification else { return false }

            completion.stopObserving = removeObserver
            return true
        }
        // A notification already completed it while the observer was being registered.
        if !isStillObserving { removeObserver() }

        return completion
    }

    /// Completes once for an accepted notification, then stops observing.
    private func completeObservedNotification() {
        // Clearing the flag under the lock ensures only one accepted notification completes, even if several are posted
        // at once.
        let (shouldComplete, stopObserving) = withLock { () -> (Bool, (() -> Void)?) in
            guard isObservingNotification else { return (false, nil) }

            isObservingNotification = false
            defer { self.stopObserving = nil }
            return (true, self.stopObserving)
        }
        guard shouldComplete else { return }

        stopObserving?()
        complete()
    }

    /// Suspends until `expectedCount` completions have happened, or records an issue after `timeout` seconds.
    ///
    /// Returns immediately if the completions already happened.
    ///
    /// Magic identifiers are separate parameters, rather than one `SourceLocation` default, because they're only
    /// evaluated at the call site when they're the whole default argument.
    func wait(fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) async {
        await wait(timeout: timeout,
                   sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    }

    /// Waits up to `timeout` seconds, recording an issue on timeout. Returns whether the completion happened.
    @discardableResult
    fileprivate func wait(timeout: TimeInterval, sourceLocation: SourceLocation) async -> Bool {
        guard withLock({ waiter == nil }) else {
            Issue.record("wait() was called on \(description) while another wait() was in progress.", sourceLocation: sourceLocation)
            return false
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

        guard !isCompleted else { return true }

        let completedCount = withLock { count }
        Issue.record("Timed out after \(timeout) seconds waiting for \(description) (\(completedCount) of \(expectedCount) completions).",
                     sourceLocation: sourceLocation)

        return false
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

    fileprivate var order: UInt64? {
        withLock { completionOrder }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }

        return body()
    }
}

/// Waits for every completion in `completions`, like `XCTestCase.wait(for:timeout:enforceOrder:)`.
///
/// The completions share one deadline, the longest of their `timeout`s from when waiting starts, and each one that
/// isn't completed by then records an issue. With `enforceOrder`, an issue is also recorded unless the completions
/// reached their expected counts in the order given.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
func wait(for completions: [Completion],
          enforceOrder: Bool = false,
          fileID: String = #fileID,
          filePath: String = #filePath,
          line: Int = #line,
          column: Int = #column) async {
    let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    let timeout = completions.map(\.timeout).max() ?? 0
    let deadline = Date().addingTimeInterval(timeout)
    var allCompleted = true
    for completion in completions {
        let remaining = max(0, deadline.timeIntervalSinceNow)
        let isCompleted = await completion.wait(timeout: remaining, sourceLocation: sourceLocation)
        allCompleted = allCompleted && isCompleted
    }

    // Order is only meaningful once everything completed; timeouts were already recorded.
    guard enforceOrder, allCompleted else { return }

    let completedInOrder = completions.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    guard completedInOrder.map(ObjectIdentifier.init) != completions.map(ObjectIdentifier.init) else { return }

    Issue.record("""
    Completions weren't completed in the expected order.
    Expected: \(completions.map(\.description).joined(separator: ", "))
    Actual: \(completedInOrder.map(\.description).joined(separator: ", "))
    """, sourceLocation: sourceLocation)
}

/// Orders completions across all tests, so `wait(for:enforceOrder:)` can compare when they completed.
private final class CompletionOrder: @unchecked Sendable {
    static let shared = CompletionOrder()

    private let lock = NSLock()
    private var last: UInt64 = 0

    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        last += 1
        return last
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
        let waitLine = #line + 2
        await withKnownIssue {
            await completion.wait()
        } matching: { issue in
            // Recorded at the call to wait(), not inside Completion.
            issue.description.contains("Timed out after 0.1 seconds waiting for never completed (1 of 2 completions).")
                && issue.sourceLocation?.line == waitLine
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

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitForCompletionsInOrder() async {
        // Given
        let first = Completion("first")
        let second = Completion("second", expectedCount: 2)
        let third = Completion("third")

        // When
        DispatchQueue.global().async {
            first.complete()
            second.complete()
            second.complete()
            third.complete()
        }

        // Then
        await wait(for: [first, second, third], enforceOrder: true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitForCompletionsOutOfOrderRecordsIssue() async {
        // Given
        let first = Completion("first")
        let second = Completion("second")

        // When
        second.complete()
        first.complete()

        // Then
        await withKnownIssue {
            await wait(for: [first, second], enforceOrder: true)
        } matching: { issue in
            issue.description.contains("Expected: first, second") && issue.description.contains("Actual: second, first")
        }
        await wait(for: [first, second])
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func waitForCompletionsSharesOneDeadline() async {
        // Given
        let first = Completion("first", timeout: 0.2)
        let second = Completion("second", timeout: 0.2)
        let start = Date()

        // When, Then
        await withKnownIssue {
            await wait(for: [first, second])
        } matching: { issue in
            issue.description.contains("Timed out")
        }
        #expect(Date().timeIntervalSince(start) < 0.35)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func notificationCompletionCompletesOnAcceptedNotificationOnly() async {
        // Given
        let center = NotificationCenter()
        let name = Notification.Name("org.alamofire.tests.completion")
        let completion = Completion.notification(name, center: center) { notification in
            notification.userInfo?["accept"] as? Bool == true
        }

        // When
        center.post(name: name, object: nil, userInfo: ["accept": false])
        DispatchQueue.global().async {
            center.post(name: name, object: nil, userInfo: ["accept": true])
        }

        // Then
        await completion.wait()
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func notificationCompletionStopsObservingAfterCompleting() async {
        // Given
        let center = NotificationCenter()
        let name = Notification.Name("org.alamofire.tests.completion")
        let completion = Completion.notification(name, center: center)

        // When
        center.post(name: name, object: nil)
        // Would record an over-completion issue if the completion still observed.
        center.post(name: name, object: nil)

        // Then
        await completion.wait()
    }
}
