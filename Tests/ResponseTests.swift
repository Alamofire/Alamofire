// ResponseTests.swift
//
// Copyright (c) 2014–2016 Alamofire Software Foundation (http://alamofire.org/)
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

import Alamofire
import Foundation
import XCTest

class ResponseDataTestCase: BaseTestCase {
    func testThatResponseDataReturnsSuccessResultWithValidData() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var response: Response<NSData, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseData { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be success")
        } else {
            XCTFail("response should not be nil")
        }
    }

    func testThatResponseDataReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let URLString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = expectationWithDescription("request should fail with 404")

        var response: Response<NSData, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseData { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNil(response.response, "response should be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isFailure, "result should be failure")
        } else {
            XCTFail("response should not be nil")
        }
    }
}

// MARK: -

class ResponseStringTestCase: BaseTestCase {
    func testThatResponseStringReturnsSuccessResultWithValidString() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var response: Response<String, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseString { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be success")
        } else {
            XCTFail("response should not be nil")
        }
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let URLString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = expectationWithDescription("request should fail with 404")

        var response: Response<String, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseString { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNil(response.response, "response should be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isFailure, "result should be failure")
        } else {
            XCTFail("response should not be nil")
        }
    }
}

// MARK: -

class ResponseJSONTestCase: BaseTestCase {
    func testThatResponseJSONReturnsSuccessResultWithValidJSON() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var response: Response<AnyObject, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be success")
        } else {
            XCTFail("response should not be nil")
        }
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let URLString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = expectationWithDescription("request should fail with 404")

        var response: Response<AnyObject, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNil(response.response, "response should be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isFailure, "result should be failure")
        } else {
            XCTFail("response should not be nil")
        }
    }

    func testThatResponseJSONReturnsSuccessResultForGETRequest() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var response: Response<AnyObject, NSError>?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be success")

            // The `as NSString` cast is necessary due to a compiler bug. See the following rdar for more info.
            // - https://openradar.appspot.com/radar?id=5517037090635776
            if let args = response.result.value?["args" as NSString] as? [String: String] {
                XCTAssertEqual(args, ["foo": "bar"], "args should match parameters")
            } else {
                XCTFail("args should not be nil")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }

    func testThatResponseJSONReturnsSuccessResultForPOSTRequest() {
        // Given
        let URLString = "https://httpbin.org/post"
        let expectation = expectationWithDescription("request should succeed")

        var response: Response<AnyObject, NSError>?

        // When
        Alamofire.request(.POST, URLString, parameters: ["foo": "bar"])
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be success")

            // The `as NSString` cast is necessary due to a compiler bug. See the following rdar for more info.
            // - https://openradar.appspot.com/radar?id=5517037090635776
            if let form = response.result.value?["form" as NSString] as? [String: String] {
                XCTAssertEqual(form, ["foo": "bar"], "form should match parameters")
            } else {
                XCTFail("form should not be nil")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }
}
