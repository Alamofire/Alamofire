// DownloadTests.swift
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

class AlamofireStatusCodeValidationTestCase: XCTestCase {
    func testValidationForRequestWithAcceptableStatusCodeResponse() {
        let URL = "http://httpbin.org/status/200"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(statusCode: 200..<300)
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
            }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithUnacceptableStatusCodeResponse() {
        let URL = "http://httpbin.org/status/404"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(statusCode: [200])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNotNil(error, "error should not be nil")
                XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithNoAcceptableStatusCodes() {
        let URL = "http://httpbin.org/status/201"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(statusCode: [])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNotNil(error, "error should not be nil")
                XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}

class AlamofireContentTypeValidationTestCase: XCTestCase {
    func testValidationForRequestWithAcceptableContentTypeResponse() {
        let URL = "http://httpbin.org/ip"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(contentType: ["application/json"])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithAcceptableWildcardContentTypeResponse() {
        let URL = "http://httpbin.org/ip"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithUnacceptableContentTypeResponse() {
        let URL = "http://httpbin.org/xml"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(contentType: ["application/octet-stream"])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNotNil(error, "error should not be nil")
                XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithNoAcceptableContentTypeResponse() {
        let URL = "http://httpbin.org/xml"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(contentType: [])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNotNil(error, "error should not be nil")
                XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}

class AlamofireMultipleValidationTestCase: XCTestCase {
    func testValidationForRequestWithAcceptableStatusCodeAndContentTypeResponse() {
        let URL = "http://httpbin.org/ip"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponse() {
        let URL = "http://httpbin.org/xml"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNotNil(error, "error should not be nil")
                XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}

class AlamofireAutomaticValidationTestCase: XCTestCase {
    func testValidationForRequestWithAcceptableStatusCodeAndContentTypeResponse() {
        let URL = NSURL(string: "http://httpbin.org/ip")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate()
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithUnacceptableStatusCodeResponse() {
        let URL = "http://httpbin.org/status/404"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate()
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNotNil(error, "error should not be nil")
                XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }


    func testValidationForRequestWithAcceptableWildcardContentTypeResponse() {
        let URL = NSURL(string: "http://httpbin.org/ip")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/*", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate()
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithAcceptableComplexContentTypeResponse() {
        let URL = NSURL(string: "http://httpbin.org/xml")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate()
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testValidationForRequestWithUnacceptableContentTypeResponse() {
        let URL = NSURL(string: "http://httpbin.org/xml")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .validate()
            .response { (_, _, _, error) in
                expectation.fulfill()

                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}
