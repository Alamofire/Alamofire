// RequestTests.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
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

import Foundation
import Alamofire
import XCTest

class AlamofireRequestInitializationTestCase: XCTestCase {
    func testRequestClassMethodWithMethodAndURL() {
        let URL = "http://httpbin.org/"
        let request = Alamofire.request(.GET, URL)

        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request.URL, NSURL(string: URL), "request URL should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testRequestClassMethodWithMethodAndURLAndParameters() {
        let URL = "http://httpbin.org/get"
        let request = Alamofire.request(.GET, URL, parameters: ["foo": "bar"])

        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertNotEqual(request.request.URL, NSURL(string: URL), "request URL should be equal")
        XCTAssertEqual(request.request.URL.query!, "foo=bar", "query is incorrect")
        XCTAssertNil(request.response, "response should be nil")
    }
}

class AlamofireRequestResponseTestCase: XCTestCase {
    func testRequestResponse() {
        let URL = "http://httpbin.org/get"
        let serializer = Alamofire.Request.stringResponseSerializer(encoding: NSUTF8StringEncoding)

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL, parameters: ["foo": "bar"])
                 .response(serializer: serializer){ (request, response, string, error) in
                    expectation.fulfill()

                    XCTAssertNotNil(request, "request should not be nil")
                    XCTAssertNotNil(response, "response should not be nil")
                    XCTAssertNotNil(string, "string should not be nil")
                    XCTAssertNil(error, "error should be nil")
                 }

        waitForExpectationsWithTimeout(10){ error in
            XCTAssertNil(error, "\(error)")
        }
    }
}

