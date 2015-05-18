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

import Alamofire
import Foundation
import XCTest

class RequestInitializationTestCase: BaseTestCase {
    func testRequestClassMethodWithMethodAndURL() {
        // Given
        let URL = "http://httpbin.org/"

        // When
        let request = Alamofire.request(.GET, URL)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request.URL!, NSURL(string: URL)!, "request URL should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testRequestClassMethodWithMethodAndURLAndParameters() {
        // Given
        let URL = "http://httpbin.org/get"

        // When
        let request = Alamofire.request(.GET, URL, parameters: ["foo": "bar"])

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertNotEqual(request.request.URL!, NSURL(string: URL)!, "request URL should be equal")
        XCTAssertEqual(request.request.URL?.query ?? "", "foo=bar", "query is incorrect")
        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class RequestResponseTestCase: BaseTestCase {
    func testRequestResponse() {
        // Given
        let URL = "http://httpbin.org/get"
        let serializer = Alamofire.Request.stringResponseSerializer(encoding: NSUTF8StringEncoding)

        let expectation = expectationWithDescription("\(URL)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var string: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URL, parameters: ["foo": "bar"])
            .response(serializer: serializer) { responseRequest, responseResponse, responseString, responseError in
                request = responseRequest
                response = responseResponse
                string = responseString
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(string, "string should not be nil")
        XCTAssertNil(error, "error should be nil")
    }
}

// MARK: -

class RequestDescriptionTestCase: BaseTestCase {
    func testRequestDescription() {
        // Given
        let URL = "http://httpbin.org/get"
        let request = Alamofire.request(.GET, URL)
        let initialRequestDescription = request.description

        let expectation = expectationWithDescription("\(URL)")

        var finalRequestDescription: String?
        var response: NSHTTPURLResponse?

        // When
        request.response { _, responseResponse, _, _ in
            finalRequestDescription = request.description
            response = responseResponse

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertEqual(initialRequestDescription, "GET http://httpbin.org/get", "incorrect request description")
        XCTAssertEqual(finalRequestDescription ?? "", "GET http://httpbin.org/get (\(response?.statusCode ?? -1))", "incorrect request description")
    }
}

// MARK: -

class RequestDebugDescriptionTestCase: BaseTestCase {
    // MARK: Properties

    let manager: Alamofire.Manager = {
        let manager = Alamofire.Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        manager.startRequestsImmediately = false
        return manager
    }()

    // MARK: Tests

    func testGETRequestDebugDescription() {
        // Given
        let URL = "http://httpbin.org/get"

        // When
        let request = manager.request(.GET, URL)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertFalse(contains(components, "-X"), "command should not contain explicit -X flag")
        XCTAssertEqual(components.last ?? "", "\"\(URL)\"", "URL component should be equal")
    }

    func testPOSTRequestDebugDescription() {
        // Given
        let URL = "http://httpbin.org/post"

        // When
        let request = manager.request(.POST, URL)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertEqual(components[3..<5], ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssertEqual(components.last ?? "", "\"\(URL)\"", "URL component should be equal")
    }

    func testPOSTRequestWithJSONParametersDebugDescription() {
        // Given
        let URL = "http://httpbin.org/post"

        // When
        let request = manager.request(.POST, URL, parameters: ["foo": "bar"], encoding: .JSON)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertEqual(components[3..<5], ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssertTrue(request.debugDescription.rangeOfString("-H \"Content-Type: application/json\"") != nil, "command should contain 'application/json' Content-Type")
        XCTAssertTrue(request.debugDescription.rangeOfString("-d \"{\\\"foo\\\":\\\"bar\\\"}\"") != nil, "command data should contain JSON encoded parameters")
        XCTAssertEqual(components.last ?? "", "\"\(URL)\"", "URL component should be equal")
    }

    func testPOSTRequestWithCookieDebugDescription() {
        // Given
        let URL = "http://httpbin.org/post"

        let properties = [
            NSHTTPCookieDomain: "httpbin.org",
            NSHTTPCookiePath: "/post",
            NSHTTPCookieName: "foo",
            NSHTTPCookieValue: "bar",
        ]
        let cookie = NSHTTPCookie(properties: properties)!
        manager.session.configuration.HTTPCookieStorage?.setCookie(cookie)

        // When
        let request = manager.request(.POST, URL)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertEqual(components[3..<5], ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssertEqual(components.last ?? "", "\"\(URL)\"", "URL component should be equal")

        #if !os(OSX)
        XCTAssertEqual(components[5..<6], ["-b"], "command should contain -b flag")
        #endif
    }

    // MARK: Test Helper Methods

    private func cURLCommandComponents(request: Request) -> [String] {
        return request.debugDescription.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).filter { $0 != "" && $0 != "\\" }
    }
}
