//
//  ProtectedTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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

@testable
import Alamofire

import XCTest

final class ProtectedTests: XCTestCase {
    func testThatProtectedValuesAreAccessedSafely() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.wrappedValue
            protected.wrappedValue = "\(i)"
        }

        // Then
        XCTAssertNotEqual(protected.wrappedValue, initialValue)
    }

    func testThatProtectedAPIIsSafe() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.read { $0 }
            protected.write { $0 = "\(i)" }
        }

        // Then
        XCTAssertNotEqual(protected.wrappedValue, initialValue)
    }
}

final class ProtectedWrapperTests: XCTestCase {
    @Protected var value = "value"

    override func setUp() {
        super.setUp()

        value = "value"
    }

    func testThatWrappedValuesAreAccessedSafely() {
        // Given
        let initialValue = value

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = value
            value = "\(i)"
        }

        // Then
        XCTAssertNotEqual(value, initialValue)
    }

    func testThatProjectedAPIIsAccessedSafely() {
        // Given
        let initialValue = value

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = $value.read { $0 }
            $value.write { $0 = "\(i)" }
        }

        // Then
        XCTAssertNotEqual(value, initialValue)
    }

    func testThatDynamicMembersAreAccessedSafely() {
        // Given
        let count = Protected<Int>(0)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
            count.wrappedValue = value.count
        }

        // Then
        XCTAssertEqual(count.wrappedValue, 5)
    }

    func testThatDynamicMembersAreSetSafely() {
        // Given
        struct Mutable { var value = "value" }
        let mutable = Protected<Mutable>(.init())

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            mutable.value = "\(i)"
        }

        // Then
        XCTAssertNotEqual(mutable.wrappedValue.value, "value")
    }
}
