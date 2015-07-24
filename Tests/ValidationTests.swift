// ValidationTests.swift
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

class StatusCodeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeResponseSucceeds() {
        // Given
        let URL = "http://httpbin.org/status/200"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(statusCode: 200..<300)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let URL = "http://httpbin.org/status/404"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(statusCode: [200])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }

    func testThatValidationForRequestWithNoAcceptableStatusCodesFails() {
        // Given
        let URL = "http://httpbin.org/status/201"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(statusCode: [])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}

// MARK: -

class ContentTypeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableContentTypeResponseSucceeds() {
        // Given
        let URL = "http://httpbin.org/ip"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(contentType: ["application/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let URL = "http://httpbin.org/ip"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let URL = "http://httpbin.org/xml"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(contentType: ["application/octet-stream"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseFails() {
        // Given
        let URL = "http://httpbin.org/xml"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(contentType: [])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}

// MARK: -

class MultipleValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let URL = "http://httpbin.org/ip"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFails() {
        // Given
        let URL = "http://httpbin.org/xml"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}

// MARK: -

class AutomaticValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/ip")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let URL = "http://httpbin.org/status/404"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/ip")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/*", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithAcceptableComplexContentTypeResponseSucceeds() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/xml")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/xml")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(mutableURLRequest)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}
