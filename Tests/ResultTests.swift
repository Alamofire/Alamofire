//
//  ResultTests.swift
//
//  Copyright (c) 2014 Alamofire Software Foundation (http://alamofire.org/)
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

class ResultTestCase: BaseTestCase {
    let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))

    // MARK: - Is Success Tests

    func testThatIsSuccessPropertyReturnsTrueForSuccessCase() {
        // Given, When
        let result = Result<String>.success("success")

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true for success case")
    }

    func testThatIsSuccessPropertyReturnsFalseForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertFalse(result.isSuccess, "result is success should be false for failure case")
    }

    // MARK: - Is Failure Tests

    func testThatIsFailurePropertyReturnsFalseForSuccessCase() {
        // Given, When
        let result = Result<String>.success("success")

        // Then
        XCTAssertFalse(result.isFailure, "result is failure should be false for success case")
    }

    func testThatIsFailurePropertyReturnsTrueForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true for failure case")
    }

    // MARK: - Value Tests

    func testThatValuePropertyReturnsValueForSuccessCase() {
        // Given, When
        let result = Result<String>.success("success")

        // Then
        XCTAssertEqual(result.value ?? "", "success", "result value should match expected value")
    }

    func testThatValuePropertyReturnsNilForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertNil(result.value, "result value should be nil for failure case")
    }

    // MARK: - Error Tests

    func testThatErrorPropertyReturnsNilForSuccessCase() {
        // Given, When
        let result = Result<String>.success("success")

        // Then
        XCTAssertNil(result.error, "result error should be nil for success case")
    }

    func testThatErrorPropertyReturnsErrorForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertNotNil(result.error, "result error should not be nil for failure case")
    }

    // MARK: - Description Tests

    func testThatDescriptionStringMatchesExpectedValueForSuccessCase() {
        // Given, When
        let result = Result<String>.success("success")

        // Then
        XCTAssertEqual(result.description, "SUCCESS", "result description should match expected value for success case")
    }

    func testThatDescriptionStringMatchesExpectedValueForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertEqual(result.description, "FAILURE", "result description should match expected value for failure case")
    }

    // MARK: - Debug Description Tests

    func testThatDebugDescriptionStringMatchesExpectedValueForSuccessCase() {
        // Given, When
        let result = Result<String>.success("success value")

        // Then
        XCTAssertEqual(
            result.debugDescription,
            "SUCCESS: success value",
            "result debug description should match expected value for success case"
        )
    }

    func testThatDebugDescriptionStringMatchesExpectedValueForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertEqual(
            result.debugDescription,
            "FAILURE: \(error)",
            "result debug description should match expected value for failure case"
        )
    }

    // MARK: - Initializer Tests

    func testThatInitializerFromThrowingClosureStoresResultAsASuccess() {
        // Given
        let value = "success value"

        // When
        let result1 = Result(value: { value })
        let result2 = Result { value }

        // Then
        for result in [result1, result2] {
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(result.value, value)
        }
    }

    func testThatInitializerFromThrowingClosureCatchesErrorAsAFailure() {
        // Given
        struct ResultError: Error {}

        // When
        let result1 = Result(value: { throw ResultError() })
        let result2 = Result { throw ResultError() }

        // Then
        for result in [result1, result2] {
            XCTAssertTrue(result.isFailure)
            XCTAssertTrue(result.error! is ResultError)
        }
    }

    // MARK: - Unwrap Tests

    func testThatUnwrapReturnsSuccessValue() {
        // Given
        let result = Result<String>.success("success value")

        // When
        let unwrappedValue = try? result.unwrap()

        // Then
        XCTAssertEqual(unwrappedValue, "success value")
    }

    func testThatUnwrapThrowsFailureError() {
        // Given
        struct ResultError: Error {}

        // When
        let result = Result<String>.failure(ResultError())

        // Then
        do {
            _ = try result.unwrap()
            XCTFail("result unwrapping should throw the failure error")
        } catch {
            XCTAssertTrue(error is ResultError)
        }
    }

    // MARK: - Map Tests

    func testThatMapTransformsSuccessValue() {
        // Given
        let result = Result<String>.success("success value")

        // When
        #if swift(>=3.2)
        let mappedResult = result.map { $0.count }
        #else
        let mappedResult = result.map { $0.characters.count }
        #endif

        // Then
        XCTAssertEqual(mappedResult.value, 13)
    }

    func testThatMapPreservesFailureError() {
        // Given
        struct ResultError: Error {}
        let result = Result<String>.failure(ResultError())

        // When
        #if swift(>=3.2)
        let mappedResult = result.map { $0.count }
        #else
        let mappedResult = result.map { $0.characters.count }
        #endif

        // Then
        if let error = mappedResult.error {
            XCTAssertTrue(error is ResultError)
        } else {
            XCTFail("map should preserve the failure error")
        }
    }

    // MARK: - FlatMap Tests

    func testThatFlatMapTransformsSuccessValue() {
        // Given
        let result = Result<String>.success("success value")

        // When
        #if swift(>=3.2)
        let mappedResult = result.map { $0.count }
        #else
        let mappedResult = result.map { $0.characters.count }
        #endif

        // Then
        XCTAssertEqual(mappedResult.value, 13)
    }

    func testThatFlatMapCatchesTransformationError() {
        // Given
        struct TransformError: Error {}
        let result = Result<String>.success("success value")

        // When
        let mappedResult = result.flatMap { _ in throw TransformError() }

        // Then
        if let error = mappedResult.error {
            XCTAssertTrue(error is TransformError)
        } else {
            XCTFail("flatMap should catch the transformation error")
        }
    }

    func testThatFlatMapPreservesFailureError() {
        // Given
        struct ResultError: Error {}
        struct TransformError: Error {}
        let result = Result<String>.failure(ResultError())

        // When
        let mappedResult = result.flatMap { _ in throw TransformError() }

        // Then
        if let error = mappedResult.error {
            XCTAssertTrue(error is ResultError)
        } else {
            XCTFail("flatMap should preserve the failure error")
        }
    }

    // MARK: - Error Mapping Tests

    func testMapErrorTransformsErrorValue() {
        // Given
        struct ResultError: Error {}
        struct OtherError: Error { let error: Error }
        let result: Result<String> = .failure(ResultError())

        // When
        let mappedResult = result.mapError { OtherError(error: $0) }

        // Then
        if let error = mappedResult.error {
            XCTAssertTrue(error is OtherError)
        } else {
            XCTFail("mapError should transform error value")
        }
    }

    func testMapErrorPreservesSuccessError() {
        // Given
        struct ResultError: Error {}
        struct OtherError: Error { let error: Error }
        let result: Result<String> = .success("success")

        // When
        let mappedResult = result.mapError { OtherError(error: $0) }

        // Then
        XCTAssertEqual(mappedResult.value, "success")
    }

    func testFlatMapErrorTransformsErrorValue() {
        // Given
        struct ResultError: Error {}
        struct OtherError: Error { let error: Error }
        let result: Result<String> = .failure(ResultError())

        // When
        let mappedResult = result.flatMapError { OtherError(error: $0) }

        // Then
        if let error = mappedResult.error {
            XCTAssertTrue(error is OtherError)
        } else {
            XCTFail("mapError should transform error value")
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
        let result: Result<String> = .failure(ResultError())

        // When
        let mappedResult = result.flatMapError { try OtherError(error: $0) }

        // Then
        if let error = mappedResult.error {
            XCTAssertTrue(error is ThrownError)
        } else {
            XCTFail("mapError should capture thrown error value")
        }
    }

    // MARK: - With Value or Error Tests

    func testWithValueExecutesWhenSuccess() {
        // Given
        let result: Result<String> = .success("success")
        var string = "failure"

        // When
        result.withValue { string = $0 }

        // Then
        XCTAssertEqual(string, "success")
    }

    func testWithValueDoesNotExecutesWhenFailure() {
        // Given
        struct ResultError: Error {}
        let result: Result<String> = .failure(ResultError())
        var string = "failure"

        // When
        result.withValue { string = $0 }

        // Then
        XCTAssertEqual(string, "failure")
    }

    func testWithErrorExecutesWhenFailure() {
        // Given
        struct ResultError: Error {}
        let result: Result<String> = .failure(ResultError())
        var string = "success"

        // When
        result.withError { string = "\(type(of: $0))" }

        // Then
    #if swift(>=4.0)
        XCTAssertEqual(string, "ResultError")
    #elseif swift(>=3.2)
        XCTAssertEqual(string, "ResultError #1")
    #else
        XCTAssertEqual(string, "(ResultError #1)")
    #endif
    }

    func testWithErrorDoesNotExecuteWhenSuccess() {
        // Given
        let result: Result<String> = .success("success")
        var string = "success"

        // When
        result.withError { string = "\(type(of: $0))" }

        // Then
        XCTAssertEqual(string, "success")
    }

    // MARK: - If Success or Failure Tests

    func testIfSuccessExecutesWhenSuccess() {
        // Given
        let result: Result<String> = .success("success")
        var string = "failure"

        // When
        result.ifSuccess { string = "success" }

        // Then
        XCTAssertEqual(string, "success")
    }

    func testIfSuccessDoesNotExecutesWhenFailure() {
        // Given
        struct ResultError: Error {}
        let result: Result<String> = .failure(ResultError())
        var string = "failure"

        // When
        result.ifSuccess { string = "success" }

        // Then
        XCTAssertEqual(string, "failure")
    }

    func testIfFailureExecutesWhenFailure() {
        // Given
        struct ResultError: Error {}
        let result: Result<String> = .failure(ResultError())
        var string = "success"

        // When
        result.ifFailure { string = "failure" }

        // Then
        XCTAssertEqual(string, "failure")
    }

    func testIfFailureDoesNotExecuteWhenSuccess() {
        // Given
        let result: Result<String> = .success("success")
        var string = "success"

        // When
        result.ifFailure { string = "failure" }

        // Then
        XCTAssertEqual(string, "success")
    }

    // MARK: - Functional Chaining Tests

    func testFunctionalMethodsCanBeChained() {
        // Given
        struct ResultError: Error {}
        let result: Result<String> = .success("first")
        var string = "first"
        var success = false

        // When
        let endResult = result
            .map { _ in "second" }
            .flatMap { _ in "third" }
            .withValue { if $0 == "third" { string = "fourth" } }
            .ifSuccess { success = true }

        // Then
        XCTAssertEqual(endResult.value, "third")
        XCTAssertEqual(string, "fourth")
        XCTAssertTrue(success)
    }
}
