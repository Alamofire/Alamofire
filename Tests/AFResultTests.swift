//
//  AFResultTests.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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
import XCTest

class AFResultTestCase: BaseTestCase {
    let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))

    // MARK: - Value Tests

    func testThatValuePropertyReturnsValueForSuccessCase() {
        // Given, When
        let result = AFResult<String>.success("success")

        // Then
        XCTAssertEqual(result.af.value ?? "", "success", "result value should match expected value")
    }

    func testThatValuePropertyReturnsNilForFailureCase() {
        // Given, When
        let result = AFResult<String>.failure(error)

        // Then
        XCTAssertNil(result.af.value, "result value should be nil for failure case")
    }

    // MARK: - Error Tests

    func testThatErrorPropertyReturnsNilForSuccessCase() {
        // Given, When
        let result = AFResult<String>.success("success")

        // Then
        XCTAssertNil(result.af.error, "result error should be nil for success case")
    }

    func testThatErrorPropertyReturnsErrorForFailureCase() {
        // Given, When
        let result = AFResult<String>.failure(error)

        // Then
        XCTAssertNotNil(result.af.error, "result error should not be nil for failure case")
    }

    // MARK: - Initializer Tests

    func testThatInitializerFromThrowingClosureStoresResultAsASuccess() {
        // Given
        let value = "success value"

        // When
        let result1 = AFResult(catching: { value })
        let result2 = AFResult { value }

        // Then
        for result in [result1, result2] {
            XCTAssertTrue(result.af.isSuccess)
            XCTAssertEqual(result.af.value, value)
        }
    }

    func testThatInitializerFromThrowingClosureCatchesErrorAsAFailure() {
        // Given
        struct ResultError: Error {}

        // When
        let result1 = AFResult(catching: { throw ResultError() })
        let result2 = AFResult { throw ResultError() }

        // Then
        for result in [result1, result2] {
            XCTAssertTrue(result.af.isFailure)
            XCTAssertTrue(result.af.error! is ResultError)
        }
    }

    // MARK: - FlatMap Tests

    func testThatFlatMapTransformsSuccessValue() {
        // Given
        let result = AFResult<String>.success("success value")

        // When
        let mappedResult = result.map { $0.count }

        // Then
        XCTAssertEqual(mappedResult.af.value, 13)
    }

    func testThatFlatMapCatchesTransformationError() {
        // Given
        struct TransformError: Error {}
        let result = AFResult<String>.success("success value")

        // When
        let mappedResult = result.af.flatMap { _ in throw TransformError() }

        // Then
        if let error = mappedResult.af.error {
            XCTAssertTrue(error is TransformError)
        } else {
            XCTFail("flatMap should catch the transformation error")
        }
    }

    func testThatFlatMapPreservesFailureError() {
        // Given
        struct ResultError: Error {}
        struct TransformError: Error {}
        let result = AFResult<String>.failure(ResultError())

        // When
        let mappedResult = result.af.flatMap { _ in throw TransformError() }

        // Then
        if let error = mappedResult.af.error {
            XCTAssertTrue(error is ResultError)
        } else {
            XCTFail("flatMap should preserve the failure error")
        }
    }

    // MARK: - FlatMapError Tests

    func testFlatMapErrorTransformsErrorValue() {
        // Given
        struct ResultError: Error {}
        struct OtherError: Error { let error: Error }
        let result: AFResult<String> = .failure(ResultError())

        // When
        let mappedResult = result.af.flatMapError { OtherError(error: $0) }

        // Then
        if let error = mappedResult.af.error {
            XCTAssertTrue(error is OtherError)
        } else {
            XCTFail("flatMapError should transform error value")
        }
    }

    func testFlatMapErrorCapturesThrownError() {
        // Given
        struct ResultError: Error {}
        struct OtherError: Error {
            let error: Error
            init(error: Error) throws { throw ThrownError() }
        }
        struct ThrownError: Error {}
        let result: AFResult<String> = .failure(ResultError())

        // When
        let mappedResult = result.af.flatMapError { try OtherError(error: $0) }

        // Then
        if let error = mappedResult.af.error {
            XCTAssertTrue(error is ThrownError)
        } else {
            XCTFail("flatMapError should capture thrown error value")
        }
    }
}
