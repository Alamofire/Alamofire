//
//  ResponseTests.swift
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

import Alamofire
import Foundation
import XCTest

class ResponseTestCase: BaseTestCase {
    func testThatResponseReturnsSuccessResultWithValidData() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DefaultDataResponse?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatResponseReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DefaultDataResponse?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.error)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }
}

// MARK: -

class ResponseDataTestCase: BaseTestCase {
    func testThatResponseDataReturnsSuccessResultWithValidData() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatResponseDataReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<Data>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }
}

// MARK: -

class ResponseStringTestCase: BaseTestCase {
    func testThatResponseStringReturnsSuccessResultWithValidString() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }
}

// MARK: -

class ResponseJSONTestCase: BaseTestCase {
    func testThatResponseJSONReturnsSuccessResultWithValidJSON() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<Any>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatResponseJSONReturnsSuccessResultForGETRequest() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0, *) {
            XCTAssertNotNil(response?.metrics)
        }

        if
            let responseDictionary = response?.result.value as? [String: Any],
            let args = responseDictionary["args"] as? [String: String]
        {
            XCTAssertEqual(args, ["foo": "bar"], "args should match parameters")
        } else {
            XCTFail("args should not be nil")
        }
    }

    func testThatResponseJSONReturnsSuccessResultForPOSTRequest() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any>?

        // When
        Alamofire.request(urlString, method: .post, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }

        if
            let responseDictionary = response?.result.value as? [String: Any],
            let form = responseDictionary["form"] as? [String: String]
        {
            XCTAssertEqual(form, ["foo": "bar"], "form should match parameters")
        } else {
            XCTFail("form should not be nil")
        }
    }
}

// MARK: -

class ResponseMapTestCase: BaseTestCase {
    func testThatMapTransformsSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.map { json in
                // json["args"]["foo"] is "bar": use this invariant to test the map function
                return ((json as? [String: Any])?["args"] as? [String: Any])?["foo"] as? String ?? "invalid"
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.value, "bar")

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.map { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }
}

// MARK: -

class ResponseFlatMapTestCase: BaseTestCase {
    func testThatFlatMapTransformsSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.flatMap { json in
                // json["args"]["foo"] is "bar": use this invariant to test the flatMap function
                return ((json as? [String: Any])?["args"] as? [String: Any])?["foo"] as? String ?? "invalid"
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.value, "bar")

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatFlatMapCatchesTransformationError() {
        // Given
        struct TransformError: Error {}

        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.flatMap { json in
                throw TransformError()
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if let error = response?.result.error {
            XCTAssertTrue(error is TransformError)
        } else {
            XCTFail("flatMap should catch the transformation error")
        }

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }

    func testThatFlatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String>?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.flatMap { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            XCTAssertNotNil(response?.metrics)
        }
    }
}
