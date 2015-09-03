// AuthenticationTests.swift
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

class AuthenticationTestCase: BaseTestCase {
    let user = "user"
    let password = "password"
    var URLString = ""

    override func setUp() {
        super.setUp()

        let credentialStorage = NSURLCredentialStorage.sharedCredentialStorage()

        for (protectionSpace, credentials) in credentialStorage.allCredentials {
            for (_, credential) in credentials {
                credentialStorage.removeCredential(credential, forProtectionSpace: protectionSpace)
            }
        }
    }
}

// MARK: -

class BasicAuthenticationTestCase: AuthenticationTestCase {
    override func setUp() {
        super.setUp()
        URLString = "https://httpbin.org/basic-auth/\(user)/\(password)"
    }

    func testHTTPBasicAuthenticationWithInvalidCredentials() {
        // Given
        let expectation = expectationWithDescription("\(URLString) 401")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: ErrorType?

        // When
        Alamofire.request(.GET, URLString)
            .authenticate(user: "invalid", password: "credentials")
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
        XCTAssertNil(response, "response should be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNotNil(error, "error should not be nil")

        if let code = (error as? NSError)?.code {
            XCTAssertEqual(code, -999, "error should be NSURLErrorDomain Code -999 'cancelled'")
        }
    }

    func testHTTPBasicAuthenticationWithValidCredentials() {
        // Given
        let expectation = expectationWithDescription("\(URLString) 200")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: ErrorType?

        // When
        Alamofire.request(.GET, URLString)
            .authenticate(user: user, password: password)
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
        XCTAssertEqual(response?.statusCode ?? 0, 200, "response status code should be 200")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")
    }
}

// MARK: -

class HTTPDigestAuthenticationTestCase: AuthenticationTestCase {
    let qop = "auth"

    override func setUp() {
        super.setUp()
        URLString = "https://httpbin.org/digest-auth/\(qop)/\(user)/\(password)"
    }

    func testHTTPDigestAuthenticationWithInvalidCredentials() {
        // Given
        let expectation = expectationWithDescription("\(URLString) 401")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: ErrorType?

        // When
        Alamofire.request(.GET, URLString)
            .authenticate(user: "invalid", password: "credentials")
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
        XCTAssertNil(response, "response should be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNotNil(error, "error should not be nil")

        if let code = (error as? NSError)?.code {
            XCTAssertEqual(code, -999, "error should be NSURLErrorDomain Code -999 'cancelled'")
        }
    }

    func testHTTPDigestAuthenticationWithValidCredentials() {
        // Given
        let expectation = expectationWithDescription("\(URLString) 200")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: ErrorType?

        // When
        Alamofire.request(.GET, URLString)
            .authenticate(user: user, password: password)
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
        XCTAssertEqual(response?.statusCode ?? 0, 200, "response status code should be 200")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")
    }
}
