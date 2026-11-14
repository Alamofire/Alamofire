//
//  TestLifetimes.swift
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

/// Objects kept alive by `stored(_:)`, the Swift Testing counterpart of `BaseTestCase.stored(_:)`.
final class TestLifetimeStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var objects: [AnyObject] = []

    func store(_ object: AnyObject) {
        lock.lock()
        defer { lock.unlock() }

        objects.append(object)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension TestLifetimeStorage {
    /// The storage for the running test.
    @TaskLocal static var current: TestLifetimeStorage?
}

/// Limits how many tests run at once to the `ALAMOFIRE_TEST_CONCURRENCY` environment variable, when it's set.
///
/// Swift Testing starts every test at once. That's fine on a fast Mac, but on a small CI machine running a simulator,
/// hundreds of simultaneous requests starve the test process until timers and requests time out. Swift Testing's own
/// limit, `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH`, isn't available before Xcode 26.6. Set the variable for
/// `xcodebuild` as `TEST_RUNNER_ALAMOFIRE_TEST_CONCURRENCY`.
final class TestConcurrencyLimit: @unchecked Sendable {
    static let shared: TestConcurrencyLimit? = ProcessInfo.processInfo.environment["ALAMOFIRE_TEST_CONCURRENCY"]
        .flatMap(Int.init)
        .flatMap { $0 > 0 ? TestConcurrencyLimit(limit: $0) : nil }

    private let lock = NSLock()
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        available = limit
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func acquire() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if available > 0 {
                available -= 1
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        guard !waiters.isEmpty else {
            available += 1
            lock.unlock()
            return
        }

        let next = waiters.removeFirst()
        lock.unlock()
        next.resume()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension TestConcurrencyLimit {
    /// Whether the running test already holds a place, so a nested scope doesn't wait for a second one.
    @TaskLocal static var isHeld = false
}

/// Gives each test its own `TestLifetimeStorage`, released when the test ends, and applies `TestConcurrencyLimit`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct StoresInstancesTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        // Scope to each test case so every run gets its own storage.
        testCase == nil ? nil : self
    }

    func provideScope(for test: Test,
                      testCase: Test.Case?,
                      performing function: @Sendable () async throws -> Void) async throws {
        guard let limit = TestConcurrencyLimit.shared, !TestConcurrencyLimit.isHeld else {
            try await withStorage(performing: function)
            return
        }

        await limit.acquire()
        defer { limit.release() }

        try await TestConcurrencyLimit.$isHeld.withValue(true) {
            try await withStorage(performing: function)
        }
    }

    private func withStorage(performing function: @Sendable () async throws -> Void) async throws {
        // A closure, rather than passing `function` directly, selects the non-deprecated
        // `nonisolated(nonsending)` overload of `withValue` on Swift 6.4 and later.
        try await TestLifetimeStorage.$current.withValue(TestLifetimeStorage()) {
            try await function()
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Trait where Self == StoresInstancesTrait {
    /// Keeps objects passed to `stored(_:)` alive until the end of each test.
    static var storesInstances: Self { Self() }
}

/// Keeps `object` alive until the end of the current test. Requires the `.storesInstances` trait on the test or its suite.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@discardableResult
func stored<T: AnyObject>(_ object: T,
                          fileID: String = #fileID,
                          filePath: String = #filePath,
                          line: Int = #line,
                          column: Int = #column) -> T {
    if let storage = TestLifetimeStorage.current {
        storage.store(object)
    } else {
        Issue.record("stored(_:) needs the .storesInstances trait on the test or its suite.",
                     sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    }

    return object
}

// MARK: - Tests

private final class LifetimeProbe {}

private final class WeakProbe: @unchecked Sendable {
    weak var probe: LifetimeProbe?
}

@Suite(.storesInstances)
struct TestLifetimesTests {
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @Test
    func storedObjectOutlivesItsLastUse() async {
        weak var weakProbe: LifetimeProbe?
        do {
            weakProbe = stored(LifetimeProbe())
        }
        await Task.yield()

        #expect(weakProbe != nil)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @Test
    func storedObjectIsReleasedWhenItsTestEnds() async throws {
        // Given
        let test = try #require(Test.current)
        let weakProbe = WeakProbe()

        // When: run a nested scope the way Swift Testing runs a test.
        try await StoresInstancesTrait().provideScope(for: test, testCase: Test.Case.current) {
            weakProbe.probe = stored(LifetimeProbe())
            await Task.yield()
            #expect(weakProbe.probe != nil)
        }

        // Then
        #expect(weakProbe.probe == nil)
    }
}
