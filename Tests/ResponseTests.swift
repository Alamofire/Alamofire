//
//  ResponseTests.swift
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

import Alamofire
import Foundation
import XCTest

class ResponseTestCase: BaseTestCase {
    func testThatResponseReturnsSuccessResultWithValidData() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data?>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
        XCTAssertNotNil(response?.metrics)
    }

    func testThatResponseReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<Data?>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)
        XCTAssertNotNil(response?.metrics)
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
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
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
        XCTAssertNotNil(response?.metrics)
    }

    func testThatResponseDataReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<Data>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
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
        AF.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
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
        XCTAssertNotNil(response?.metrics)
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
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
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
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
        XCTAssertNotNil(response?.metrics)
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<Any>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
    }

    func testThatResponseJSONReturnsSuccessResultForGETRequest() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
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
        XCTAssertNotNil(response?.metrics)

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
        AF.request(urlString, method: .post, parameters: ["foo": "bar"]).responseJSON { resp in
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
        XCTAssertNotNil(response?.metrics)

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

class ResponseJSONDecodableTestCase: BaseTestCase {
    func testThatResponseJSONReturnsSuccessResultWithValidJSON() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<HTTPBinResponse>?

        // When
        AF.request(urlString, parameters: [:]).responseDecodable { (resp: DataResponse<HTTPBinResponse>) in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.value?.url, "https://httpbin.org/get")
        XCTAssertNotNil(response?.metrics)
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<HTTPBinResponse>?

        // When
        AF.request(urlString, parameters: [:]).responseDecodable { (resp: DataResponse<HTTPBinResponse>) in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
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
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
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
        XCTAssertNotNil(response?.metrics)
    }

    func testThatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.map { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
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
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
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
        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapCatchesTransformationError() {
        // Given
        struct TransformError: Error {}

        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
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

        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.flatMap { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
    }
}

// MARK: -

enum TestError: Error {
    case error(error: Error)
}

enum TransformationError: Error {
    case error

    func alwaysFails() throws -> TestError {
        throw TransformationError.error
    }
}

class ResponseMapErrorTestCase: BaseTestCase {
    func testThatMapErrorTransformsFailureValue() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should not succeed")

        var response: DataResponse<Any>?

        // When
        AF.request(urlString).responseJSON { resp in
            response = resp.mapError { error in
                return TestError.error(error: error)
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        guard let error = response?.error as? TestError, case .error = error else { XCTFail(); return }

        XCTAssertNotNil(response?.metrics)
    }

    func testThatMapErrorPreservesSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.mapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertNotNil(response?.metrics)
    }
}

// MARK: -

class ResponseFlatMapErrorTestCase: BaseTestCase {
    func testThatFlatMapErrorPreservesSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.flatMapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapErrorCatchesTransformationError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<Data>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.flatMapError { _ in try TransformationError.error.alwaysFails() }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if let error = response?.result.error {
            XCTAssertTrue(error is TransformationError)
        } else {
            XCTFail("flatMapError should catch the transformation error")
        }

        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapErrorTransformsError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<Data>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.flatMapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        guard let error = response?.error as? TestError, case .error = error else { XCTFail(); return }

        XCTAssertNotNil(response?.metrics)
    }
}
