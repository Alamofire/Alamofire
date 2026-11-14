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

/// Gives each test its own `TestLifetimeStorage`, released when the test ends.
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
                          sourceLocation: SourceLocation = SourceLocation(fileID: #fileID,
                                                                          filePath: #filePath,
                                                                          line: #line,
                                                                          column: #column)) -> T {
    if let storage = TestLifetimeStorage.current {
        storage.store(object)
    } else {
        Issue.record("stored(_:) needs the .storesInstances trait on the test or its suite.", sourceLocation: sourceLocation)
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
