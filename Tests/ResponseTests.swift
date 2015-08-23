// ResponseTests.swift
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

import Alamofire
import Foundation
import XCTest

class ResponseDataTestCase: BaseTestCase {
    func testThatResponseDataReturnsSuccessResultWithValidData() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<NSData>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseData { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(result.isSuccess, "result should be success")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatResponseDataReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let URLString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = expectationWithDescription("request should fail with 404")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<NSData>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseData { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNil(response, "response should be nil")
        XCTAssertTrue(result.isFailure, "result should be a failure")
        XCTAssertNil(result.value, "result value should not be nil")
        XCTAssertNotNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")
    }
}

// MARK: -

class ResponseStringTestCase: BaseTestCase {
    func testThatResponseStringReturnsSuccessResultWithValidString() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<String>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseString { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(result.isSuccess, "result should be success")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let URLString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = expectationWithDescription("request should fail with 404")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<String>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseString { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNil(response, "response should be nil")
        XCTAssertTrue(result.isFailure, "result should be a failure")
        XCTAssertNil(result.value, "result value should not be nil")
        XCTAssertNotNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")
    }
}

// MARK: -

class ResponseJSONTestCase: BaseTestCase {
    func testThatResponseJSONReturnsSuccessResultWithValidJSON() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<AnyObject>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseJSON { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(result.isSuccess, "result should be success")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let URLString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = expectationWithDescription("request should fail with 404")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<AnyObject>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseJSON { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNil(response, "response should be nil")
        XCTAssertTrue(result.isFailure, "result should be a failure")
        XCTAssertNil(result.value, "result value should not be nil")
        XCTAssertNotNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")
    }

    func testThatResponseJSONReturnsSuccessResultForGETRequest() {
        // Given
        let URLString = "https://httpbin.org/get"
        let expectation = expectationWithDescription("request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<AnyObject>!

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
            .responseJSON { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(result.isSuccess, "result should be success")

        // The `as NSString` cast is necessary due to a compiler bug. See the following rdar for more info.
        // - https://openradar.appspot.com/radar?id=5517037090635776
        if let args = result.value?["args" as NSString] as? [String: String] {
            XCTAssertEqual(args, ["foo": "bar"], "args should match parameters")
        } else {
            XCTFail("args should not be nil")
        }
    }

    func testThatResponseJSONReturnsSuccessResultForPOSTRequest() {
        // Given
        let URLString = "https://httpbin.org/post"
        let expectation = expectationWithDescription("request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<AnyObject>!

        // When
        Alamofire.request(.POST, URLString, parameters: ["foo": "bar"])
            .responseJSON { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(result.isSuccess, "result should be success")

        // The `as NSString` cast is necessary due to a compiler bug. See the following rdar for more info.
        // - https://openradar.appspot.com/radar?id=5517037090635776
        if let form = result.value?["form" as NSString] as? [String: String] {
            XCTAssertEqual(form, ["foo": "bar"], "form should match parameters")
        } else {
            XCTFail("form should not be nil")
        }
    }
}

// MARK: -

class RedirectResponseTestCase: BaseTestCase {
    func testThatRequestWillPerformHTTPRedirectionByDefault() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL?.URLString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatRequestWillPerformRedirectionMultipleTimesByDefault() {
        // Given
        let redirectURLString = "https://httpbin.org/get"
        let URLString = "https://httpbin.org/redirect/5"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL?.URLString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatTaskOverrideClosureCanPerformHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            return request
        }

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL?.URLString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatTaskOverrideClosureCanCancelHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = expectationWithDescription("Request should not redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, _ in
            return nil
        }

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL?.URLString ?? "", URLString, "response URL should match the origin URL")
        XCTAssertEqual(response?.statusCode ?? -1, 302, "response should have a 302 status code")
    }

    func testThatTaskOverrideClosureIsCalledMultipleTimesForMultipleHTTPRedirects() {
        // Given
        let redirectURLString = "https://httpbin.org/get"
        let URLString = "https://httpbin.org/redirect/5"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate
        var totalRedirectCount = 0

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            ++totalRedirectCount
            return request
        }

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL?.URLString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
        XCTAssertEqual(totalRedirectCount, 5, "total redirect count should be 5")
    }
}
