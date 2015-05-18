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
        let URL = "http://httpbin.org/get"
        let expectation = expectationWithDescription("\(URL)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var JSON: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URL, parameters: ["foo": "bar"])
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

        if let args = JSON?["args"] as? NSObject {
            XCTAssertEqual(args, ["foo": "bar"], "args should match parameters")
        } else {
            XCTFail("args should not be nil")
        }
    }

    func testPOSTRequestJSONResponse() {
        // Given
        let URL = "http://httpbin.org/post"
        let expectation = expectationWithDescription("\(URL)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var JSON: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.POST, URL, parameters: ["foo": "bar"])
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

        if let form = JSON?["form"] as? NSObject {
            XCTAssertEqual(form, ["foo": "bar"], "form should match parameters")
        } else {
            XCTFail("form should not be nil")
        }
    }
}

// MARK: -

class RedirectResponseTestCase: BaseTestCase {
    func testGETRequestRedirectResponse() {
        // Given
        let URLString = "http://google.com"
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate

        delegate.taskWillPerformHTTPRedirection = { session, task, response, request in
            // Accept the redirect by returning the updated request.
            return request
        }

        let expectation = expectationWithDescription("\(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
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

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL ?? NSURL(), NSURL(string: "http://www.google.com/")!, "request should have followed a redirect")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testGETRequestDisallowRedirectResponse() {
        // Given
        let URLString = "http://google.com/"
        let delegate: Alamofire.Manager.SessionDelegate = Alamofire.Manager.sharedInstance.delegate

        delegate.taskWillPerformHTTPRedirection = { session, task, response, request in
            // Disallow redirects by returning nil.
            // NOTE: NSURLSessionDelegate's `URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:`
            // suggests that returning nil should refuse the redirect, but this causes a deadlock/timeout.
            return NSURLRequest(URL: NSURL(string: URLString)!)
        }

        let expectation = expectationWithDescription("\(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
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

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.URL ?? NSURL(string: "")!, NSURL(string: URLString)!, "request should not have followed a redirect")
        XCTAssertEqual(response?.statusCode ?? -1, 301, "response should have a 301 status code")
    }
}
