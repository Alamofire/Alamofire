// ResultTests.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

@testable import Alamofire
import Foundation
import XCTest

class ResultTestCase: BaseTestCase {
    let error = Error.errorWithCode(.StatusCodeValidationFailed, failureReason: "Status code validation failed")

    // MARK: - Is Success Tests

    func testThatIsSuccessPropertyReturnsTrueForSuccessCase() {
        // Given, When
        let result = Result<String, NSError>.Success("success")

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true for success case")
    }

    func testThatIsSuccessPropertyReturnsFalseForFailureCase() {
        // Given, When
        let result = Result<String, NSError>.Failure(error)

        // Then
        XCTAssertFalse(result.isSuccess, "result is success should be true for failure case")
    }

    // MARK: - Is Failure Tests

    func testThatIsFailurePropertyReturnsFalseForSuccessCase() {
        // Given, When
        let result = Result<String, NSError>.Success("success")

        // Then
        XCTAssertFalse(result.isFailure, "result is failure should be false for success case")
    }

    func testThatIsFailurePropertyReturnsTrueForFailureCase() {
        // Given, When
        let result = Result<String, NSError>.Failure(error)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true for failure case")
    }

    // MARK: - Value Tests

    func testThatValuePropertyReturnsValueForSuccessCase() {
        // Given, When
        let result = Result<String, NSError>.Success("success")

        // Then
        XCTAssertEqual(result.value ?? "", "success", "result value should match expected value")
    }

    func testThatValuePropertyReturnsNilForFailureCase() {
        // Given, When
        let result = Result<String, NSError>.Failure(error)

        // Then
        XCTAssertNil(result.value, "result value should be nil for failure case")
    }

    // MARK: - Error Tests

    func testThatErrorPropertyReturnsNilForSuccessCase() {
        // Given, When
        let result = Result<String, NSError>.Success("success")

        // Then
        XCTAssertTrue(result.error == nil, "result error should be nil for success case")
    }

    func testThatErrorPropertyReturnsErrorForFailureCase() {
        // Given, When
        let result = Result<String, NSError>.Failure(error)

        // Then
        XCTAssertTrue(result.error != nil, "result error should not be nil for failure case")
    }

    // MARK: - Description Tests

    func testThatDescriptionStringMatchesExpectedValueForSuccessCase() {
        // Given, When
        let result = Result<String, NSError>.Success("success")

        // Then
        XCTAssertEqual(result.description, "SUCCESS", "result description should match expected value for success case")
    }

    func testThatDescriptionStringMatchesExpectedValueForFailureCase() {
        // Given, When
        let result = Result<String, NSError>.Failure(error)

        // Then
        XCTAssertEqual(result.description, "FAILURE", "result description should match expected value for failure case")
    }

    // MARK: - Debug Description Tests

    func testThatDebugDescriptionStringMatchesExpectedValueForSuccessCase() {
        // Given, When
        let result = Result<String, NSError>.Success("success value")

        // Then
        XCTAssertEqual(
            result.debugDescription,
            "SUCCESS: success value",
            "result debug description should match expected value for success case"
        )
    }

    func testThatDebugDescriptionStringMatchesExpectedValueForFailureCase() {
        // Given, When
        let result = Result<String, NSError>.Failure(error)

        // Then
        XCTAssertEqual(
            result.debugDescription,
            "FAILURE: \(error)",
            "result debug description should match expected value for failure case"
        )
    }
}
