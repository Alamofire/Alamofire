// DownloadTests.swift
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
    func testValidationForRequestWithAcceptableStatusCodeResponse() {
        // Given
        let URL = "http://httpbin.org/status/200"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(statusCode: 200..<300)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithUnacceptableStatusCodeResponse() {
        // Given
        let URL = "http://httpbin.org/status/404"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(statusCode: [200])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }

    func testValidationForRequestWithNoAcceptableStatusCodes() {
        // Given
        let URL = "http://httpbin.org/status/201"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(statusCode: [])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}

// MARK: -

class ContentTypeValidationTestCase: BaseTestCase {
    func testValidationForRequestWithAcceptableContentTypeResponse() {
        // Given
        let URL = "http://httpbin.org/ip"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(contentType: ["application/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithAcceptableWildcardContentTypeResponse() {
        // Given
        let URL = "http://httpbin.org/ip"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithUnacceptableContentTypeResponse() {
        // Given
        let URL = "http://httpbin.org/xml"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(contentType: ["application/octet-stream"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }

    func testValidationForRequestWithNoAcceptableContentTypeResponse() {
        // Given
        let URL = "http://httpbin.org/xml"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(contentType: [])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}

// MARK: -

class MultipleValidationTestCase: BaseTestCase {
    func testValidationForRequestWithAcceptableStatusCodeAndContentTypeResponse() {
        // Given
        let URL = "http://httpbin.org/ip"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponse() {
        // Given
        let URL = "http://httpbin.org/xml"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.domain ?? "", AlamofireErrorDomain, "error should be in Alamofire error domain")
    }
}

// MARK: -

class AutomaticValidationTestCase: BaseTestCase {
    func testValidationForRequestWithAcceptableStatusCodeAndContentTypeResponse() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/ip")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithUnacceptableStatusCodeResponse() {
        // Given
        let URL = "http://httpbin.org/status/404"
        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error!.domain, AlamofireErrorDomain, "error should be in Alamofire error domain")
    }

    func testValidationForRequestWithAcceptableWildcardContentTypeResponse() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/ip")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/*", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithAcceptableComplexContentTypeResponse() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/xml")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testValidationForRequestWithUnacceptableContentTypeResponse() {
        // Given
        let URL = NSURL(string: "http://httpbin.org/xml")!
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = expectationWithDescription("\(URL)")

        var error: NSError?

        // When
        Alamofire.request(.GET, URLString: URL)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }
}
