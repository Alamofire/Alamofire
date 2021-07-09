//
//  AsyncTests.swift
//
//  Copyright (c) 2021 Alamofire Software Foundation (http://alamofire.org/)
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

#if swift(>=5.5)

import Alamofire
import XCTest

@available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class AsyncTests: BaseTestCase {
    func testDataTaskResponse() async {
        // Given, When
        let response = await AF.request(.get).decode(TestResponse.self).response

        // Then
        XCTAssertNotNil(response.value)
    }

    func testDataTaskCancellation() async {
        // Given
        let task = AF.request(.get).decode(TestResponse.self)

        // When
        task.cancel()
        let response = await task.response

        // Then
        XCTAssertTrue(response.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    func testDataTaskResult() async {
        // Given, When
        let result = await AF.request(.get).decode(TestResponse.self).result

        // Then
        XCTAssertNotNil(result.success)
    }

    func testDataTaskValue() async throws {
        // Given, When
        let value = try await AF.request(.get).decode(TestResponse.self).value

        // Then
        XCTAssertEqual(value.url, "http://127.0.0.1:8080/get")
    }

    func testConcurrentRequests() async {
        // Given
        let session = Session(); defer { withExtendedLifetime(session) {} }

        // When
        async let first = session.request(.get).decode(TestResponse.self).response
        async let second = session.request(.get).decode(TestResponse.self).response
        async let third = session.request(.get).decode(TestResponse.self).response

        // Then
        let values = await [first.value, second.value, third.value].compactMap { $0 }
        XCTAssertEqual(values.count, 3)
    }

    func testTaskString() async {
        // Given
        let session = Session(); defer { withExtendedLifetime(session) {} }

        // When
        let result = await session.request(.get).string().result

        // Then
        XCTAssertTrue(result.isSuccess)
    }

    func testTaskData() async {
        // Given
        let session = Session(); defer { withExtendedLifetime(session) {} }

        // When
        let result = await session.request(.get).data().result

        // Then
        XCTAssertTrue(result.isSuccess)
    }
}

#endif
