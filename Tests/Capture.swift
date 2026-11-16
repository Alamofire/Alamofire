//
//  Capture.swift
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

@testable import Alamofire
import Foundation
import Testing

/// A lock-protected value for capturing results in `@Sendable` callbacks and checking them later in a test.
///
/// Unlike `Protected`, `Capture` offers `@dynamicMemberLookup`, so `#expect(response.statusCode == 200)` reads like
/// the captured value itself. Each member access takes the lock separately, so a series of accesses isn't atomic,
/// which is fine for checking a value once the callbacks that set it have finished.
@dynamicMemberLookup
final class Capture<Value>: Sendable {
    private let protected: Protected<Value>

    /// Creates a capture holding `value`.
    init(_ value: Value) {
        protected = Protected(value)
    }

    /// Creates an empty capture for an optional value.
    convenience init<Wrapped>() where Value == Wrapped? {
        self.init(nil)
    }

    /// The captured value.
    var value: Value {
        get { protected.read { $0 } }
        set { protected.write(newValue) }
    }

    /// Mutates the captured value in place while holding the lock.
    @discardableResult
    func write<Result>(_ closure: (inout Value) throws -> Result) rethrows -> Result {
        try protected.write(closure)
    }

    /// Reads a property of the captured value.
    subscript<Property>(dynamicMember keyPath: KeyPath<Value, Property>) -> Property {
        protected.read { $0[keyPath: keyPath] }
    }

    /// Reads a property of a captured optional value, or `nil` if nothing was captured.
    subscript<Wrapped, Property>(dynamicMember keyPath: KeyPath<Wrapped, Property>) -> Property? where Value == Wrapped? {
        protected.read { $0?[keyPath: keyPath] }
    }

    /// Reads an optional property of a captured optional value, flattened to a single optional, so
    /// `#expect(response.data == nil)` checks the property rather than whether a value was captured.
    subscript<Wrapped, Property>(dynamicMember keyPath: KeyPath<Wrapped, Property?>) -> Property? where Value == Wrapped? {
        protected.read { $0?[keyPath: keyPath] ?? nil }
    }
}

// MARK: - Tests

@Suite
struct CaptureTests {
    private struct Captured {
        var status: Int
        var data: Data?
    }

    @Test
    func emptyOptionalCaptureReadsMembersAsNil() {
        // Given
        let capture = Capture<Captured?>()

        // Then
        #expect(capture.value == nil)
        #expect(capture.status == nil)
        #expect(capture.data == nil)
    }

    @Test
    func optionalMembersOfCapturedValueAreFlattened() {
        // Given
        let capture = Capture<Captured?>()

        // When
        capture.value = Captured(status: 200, data: nil)

        // Then
        #expect(capture.status == 200)
        // `Data?` rather than `Data??`, so this checks the property, not whether a value was captured.
        #expect(capture.data == nil)
    }

    @Test
    func writeMutatesInPlaceFromConcurrentCallbacks() async {
        // Given
        let capture = Capture<[Int]>([])

        // When
        await withTaskGroup(of: Void.self) { group in
            for value in 0..<100 {
                group.addTask { capture.write { $0.append(value) } }
            }
        }

        // Then
        #expect(capture.count == 100)
        #expect(capture.value.sorted() == Array(0..<100))
    }
}
