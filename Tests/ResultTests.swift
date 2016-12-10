//
//  ResultTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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
        XCTAssertFalse(result.isSuccess, "result is success should be true for failure case")
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
        XCTAssertTrue(result.error == nil, "result error should be nil for success case")
    }

    func testThatErrorPropertyReturnsErrorForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error)

        // Then
        XCTAssertTrue(result.error != nil, "result error should not be nil for failure case")
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
    
    // MARK: - Unwrap Tests
    
    func testThatUnwrapReturnsSuccessValue() {
        // Given, When
        let result = Result<String>.success("success value")
        
        // Then
        XCTAssertEqual(
            try result.unwrap(),
            "success value",
            "result unwrapping should return the success value"
        )
    }
    
    func testThatUnwrapThrowsFailureError() {
        // Given, When
        struct ResultError : Error { }
        let result = Result<String>.failure(ResultError())
        
        // Then
        do {
            _ = try result.unwrap()
            XCTFail("result unwrapping should throw the failure error")
        } catch {
            XCTAssert(
                error is ResultError,
                "result unwrapping should throw the failure error")
        }
    }
    
    // MARK: - Map Tests
    
    func testThatMapTransformsSuccessValue() {
        // Given, When
        let result = Result<String>.success("success value")
        
        // Then
        let mappedResult = result.map { $0.characters.count }
        XCTAssertEqual(
            mappedResult.value ?? 0,
            13,
            "map should transform the success value"
        )
    }
    
    func testThatMapPreservesFailureError() {
        // Given, When
        struct ResultError : Error { }
        let result = Result<String>.failure(ResultError())
        
        // Then
        let mappedResult = result.map { $0.characters.count }
        if let error = mappedResult.error {
            XCTAssertTrue(
                error is ResultError,
                "map should preserve the failure error"
            )
        } else {
            XCTFail("map should preserve the failure error")
        }
    }
    
    // MARK: - FlatMap Tests
    
    func testThatFlatMapTransformsSuccessValue() {
        // Given, When
        let result = Result<String>.success("success value")
        
        // Then
        let mappedResult = result.map { $0.characters.count }
        XCTAssertEqual(
            mappedResult.value ?? 0,
            13,
            "flatMap should transform the success value"
        )
    }
    
    func testThatFlatMapCatchesTransformationError() {
        // Given, When
        let result = Result<String>.success("success value")
        
        // Then
        struct TransformError : Error { }
        let mappedResult = result.flatMap { _ in throw TransformError() }
        if let error = mappedResult.error {
            XCTAssertTrue(
                error is TransformError,
                "flatMap should catch the transformation error"
            )
        } else {
            XCTFail("flatMap should catch the transformation error")
        }
    }
    
    func testThatFlatMapPreservesFailureError() {
        // Given, When
        struct ResultError : Error { }
        let result = Result<String>.failure(ResultError())
        
        // Then
        struct TransformError : Error { }
        let mappedResult = result.flatMap { _ in throw TransformError() }
        if let error = mappedResult.error {
            XCTAssertTrue(
                error is ResultError,
                "flatMap should preserve the failure error"
            )
        } else {
            XCTFail("flatMap should preserve the failure error")
        }
    }
}
