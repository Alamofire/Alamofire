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

class AlamofireAuthenticationTestCase: XCTestCase {
    func testHTTPBasicAuthentication() {
        let user = "user"
        let password = "password"
        let URL = "http://httpbin.org/basic-auth/\(user)/\(password)"

        let invalidCredentialsExpectation = expectationWithDescription("\(URL) 401")

        Alamofire.request(.GET, URL)
            .authenticate(user: "invalid", password: "credentials")
            .response { (request, response, _, error) in
                invalidCredentialsExpectation.fulfill()

                XCTAssertNotNil(request, "request should not be nil")
                XCTAssertNil(response, "response should be nil")
                XCTAssertNotNil(error, "error should not be nil")
                XCTAssert(error?.code == -999, "error should be NSURLErrorDomain Code -999 'cancelled'")
        }

        let validCredentialsExpectation = expectationWithDescription("\(URL) 200")

        Alamofire.request(.GET, URL)
            .authenticate(user: user, password: password)
            .response { (request, response, _, error) in
                validCredentialsExpectation.fulfill()

                XCTAssertNotNil(request, "request should not be nil")
                XCTAssertNotNil(response, "response should not be nil")
                XCTAssert(response?.statusCode == 200, "response status code should be 200")
                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testHTTPDigestAuthentication() {
        let qop = "auth"
        let user = "user"
        let password = "password"
        let URL = "http://httpbin.org/digest-auth/\(qop)/\(user)/\(password)"

        let invalidCredentialsExpectation = expectationWithDescription("\(URL) 401")

        Alamofire.request(.GET, URL)
            .authenticate(user: "invalid", password: "credentials")
            .response { (request, response, _, error) in
                invalidCredentialsExpectation.fulfill()

                XCTAssertNotNil(request, "request should not be nil")
                XCTAssertNil(response, "response should be nil")
                XCTAssertNotNil(error, "error should not be nil")
                XCTAssert(error?.code == -999, "error should be NSURLErrorDomain Code -999 'cancelled'")
        }

        let validCredentialsExpectation = expectationWithDescription("\(URL) 200")

        Alamofire.request(.GET, URL)
            .authenticate(user: user, password: password)
            .response { (request, response, _, error) in
                validCredentialsExpectation.fulfill()

                XCTAssertNotNil(request, "request should not be nil")
                XCTAssertNotNil(response, "response should not be nil")
                XCTAssert(response?.statusCode == 200, "response status code should be 200")
                XCTAssertNil(error, "error should be nil")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}
