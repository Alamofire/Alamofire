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

class JSONResponseTestCase: BaseTestCase {
    func testGETRequestJSONResponse() {
        // Given
        let URLString = "http://httpbin.org/get"
        let expectation = expectationWithDescription("\(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var JSON: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URLString, parameters: ["foo": "bar"])
            .responseJSON { responseRequest, responseResponse, responseJSON, responseError in
                request = responseRequest
                response = responseResponse
                JSON = responseJSON
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(JSON, "JSON should not be nil")
        XCTAssertNil(error, "error should be nil")

        // The `as NSString` cast is necessary due to a compiler bug. See the following rdar for more info.
        // - http://openradar.appspot.com/radar?id=5517037090635776
        if let args = JSON?["args" as NSString] as? [String: String] {
            XCTAssertEqual(args, ["foo": "bar"], "args should match parameters")
        } else {
            XCTFail("args should not be nil")
        }
    }

    func testPOSTRequestJSONResponse() {
        // Given
        let URLString = "http://httpbin.org/post"
        let expectation = expectationWithDescription("\(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var JSON: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.POST, URLString: URLString, parameters: ["foo": "bar"])
            .responseJSON { responseRequest, responseResponse, responseJSON, responseError in
                request = responseRequest
                response = responseResponse
                JSON = responseJSON
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(JSON, "JSON should not be nil")
        XCTAssertNil(error, "error should be nil")

        // The `as NSString` cast is necessary due to a compiler bug. See the following rdar for more info.
        // - http://openradar.appspot.com/radar?id=5517037090635776
        if let form = JSON?["form" as NSString] as? [String: String] {
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
        let redirectURLString = "http://www.apple.com"
        let URLString = "http://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

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
        let redirectURLString = "http://httpbin.org/get"
        let URLString = "http://httpbin.org/redirect/5"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

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
        let redirectURLString = "http://www.apple.com"
        let URLString = "http://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            return request
        }

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

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
        let redirectURLString = "http://www.apple.com"
        let URLString = "http://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = expectationWithDescription("Request should not redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, _ in
            return nil
        }

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

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
        let redirectURLString = "http://httpbin.org/get"
        let URLString = "http://httpbin.org/redirect/5"

        let expectation = expectationWithDescription("Request should redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate
        var totalRedirectCount = 0

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            ++totalRedirectCount
            return request
        }

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

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
