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
        let URLString = "http://httpbin.org/"

        // When
        let request = Alamofire.request(.GET, URLString)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request.HTTPMethod ?? "", "GET", "request HTTP method should match expected value")
        XCTAssertEqual(request.request.URL!, NSURL(string: URLString)!, "request URL should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testRequestClassMethodWithMethodAndURLAndParameters() {
        // Given
        let URLString = "http://httpbin.org/get"

        // When
        let request = Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request.HTTPMethod ?? "", "GET", "request HTTP method should match expected value")
        XCTAssertNotEqual(request.request.URL!, NSURL(string: URLString)!, "request URL should be equal")
        XCTAssertEqual(request.request.URL?.query ?? "", "foo=bar", "query is incorrect")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testRequestClassMethodWithMethodURLParametersAndHeaders() {
        // Given
        let URLString = "http://httpbin.org/get"

        // When
        let request = Alamofire.request(.GET, URLString, parameters: ["foo": "bar"], headers: ["Authorization": "123456"])

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request.HTTPMethod ?? "", "GET", "request HTTP method should match expected value")
        XCTAssertNotEqual(request.request.URL!, NSURL(string: URLString)!, "request URL should be equal")
        XCTAssertEqual(request.request.URL?.query ?? "", "foo=bar", "query is incorrect")

        let authorizationHeader = request.request.valueForHTTPHeaderField("Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class RequestResponseTestCase: BaseTestCase {
    func testRequestResponse() {
        // Given
        let URLString = "http://httpbin.org/get"
        let serializer = Alamofire.Request.stringResponseSerializer(encoding: NSUTF8StringEncoding)

        let expectation = expectationWithDescription("GET request should succeed: \(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var string: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(.GET, URLString, parameters: ["foo": "bar"])
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

    func testRequestResponseWithProgress() {
        // Given
        let randomBytes = 4 * 1024 * 1024
        let URLString = "http://httpbin.org/bytes/\(randomBytes)"

        let expectation = expectationWithDescription("Bytes download progress should be reported: \(URLString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var responseRequest: NSURLRequest?
        var responseResponse: NSHTTPURLResponse?
        var responseData: AnyObject?
        var responseError: NSError?

        // When
        let request = Alamofire.request(.GET, URLString)
        request.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
            let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
            byteValues.append(bytes)

            let progress = (completedUnitCount: request.progress.completedUnitCount, totalUnitCount: request.progress.totalUnitCount)
            progressValues.append(progress)
        }
        request.response { request, response, data, error in
            responseRequest = request
            responseResponse = response
            responseData = data
            responseError = error

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(responseRequest, "response request should not be nil")
        XCTAssertNotNil(responseResponse, "response response should not be nil")
        XCTAssertNotNil(responseData, "response data should not be nil")
        XCTAssertNil(responseError, "response error should be nil")

        XCTAssertEqual(byteValues.count, progressValues.count, "byteValues count should equal progressValues count")

        if byteValues.count == progressValues.count {
            for index in 0..<byteValues.count {
                let byteValue = byteValues[index]
                let progressValue = progressValues[index]

                XCTAssertGreaterThan(byteValue.bytes, 0, "reported bytes should always be greater than 0")
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount, "total bytes should be equal to completed unit count")
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount, "total bytes expected should be equal to total unit count")
            }
        }

        if let
            lastByteValue = byteValues.last,
            lastProgressValue = progressValues.last
        {
            let byteValueFractionalCompletion = Double(lastByteValue.totalBytes) / Double(lastByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastProgressValue.0) / Double(lastProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0, "byte value fractional completion should equal 1.0")
            XCTAssertEqual(progressValueFractionalCompletion, 1.0, "progress value fractional completion should equal 1.0")
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }
    }

    func testRequestResponseWithStream() {
        // Given
        let randomBytes = 4 * 1024 * 1024
        let URLString = "http://httpbin.org/bytes/\(randomBytes)"

        let expectation = expectationWithDescription("Bytes download progress should be reported: \(URLString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var accumulatedData = [NSData]()

        var responseRequest: NSURLRequest?
        var responseResponse: NSHTTPURLResponse?
        var responseData: AnyObject?
        var responseError: NSError?

        // When
        let request = Alamofire.request(.GET, URLString)
        request.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
            let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
            byteValues.append(bytes)

            let progress = (completedUnitCount: request.progress.completedUnitCount, totalUnitCount: request.progress.totalUnitCount)
            progressValues.append(progress)
        }
        request.stream { accumulatedData.append($0) }
        request.response { request, response, data, error in
            responseRequest = request
            responseResponse = response
            responseData = data
            responseError = error

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(responseRequest, "response request should not be nil")
        XCTAssertNotNil(responseResponse, "response response should not be nil")
        XCTAssertNil(responseData, "response data should be nil")
        XCTAssertNil(responseError, "response error should be nil")
        XCTAssertGreaterThanOrEqual(accumulatedData.count, 1, "accumulated data should have one or more parts")

        XCTAssertEqual(byteValues.count, progressValues.count, "byteValues count should equal progressValues count")

        if byteValues.count == progressValues.count {
            for index in 0..<byteValues.count {
                let byteValue = byteValues[index]
                let progressValue = progressValues[index]

                XCTAssertGreaterThan(byteValue.bytes, 0, "reported bytes should always be greater than 0")
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount, "total bytes should be equal to completed unit count")
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount, "total bytes expected should be equal to total unit count")
            }
        }

        if let
            lastByteValue = byteValues.last,
            lastProgressValue = progressValues.last
        {
            let byteValueFractionalCompletion = Double(lastByteValue.totalBytes) / Double(lastByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastProgressValue.0) / Double(lastProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0, "byte value fractional completion should equal 1.0")
            XCTAssertEqual(progressValueFractionalCompletion, 1.0, "progress value fractional completion should equal 1.0")

            XCTAssertEqual(reduce(accumulatedData, 0) { $0 + $1.length }, lastByteValue.totalBytes, "accumulated data length should match byte count")
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }
    }
}

// MARK: -

class RequestDescriptionTestCase: BaseTestCase {
    func testRequestDescription() {
        // Given
        let URLString = "http://httpbin.org/get"
        let request = Alamofire.request(.GET, URLString)
        let initialRequestDescription = request.description

        let expectation = expectationWithDescription("Request description should update: \(URLString)")

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

    let manager: Manager = {
        let manager = Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        manager.startRequestsImmediately = false
        return manager
    }()

    let managerDisallowingCookies: Manager = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPShouldSetCookies = false

        let manager = Manager(configuration: configuration)
        manager.startRequestsImmediately = false

        return manager
    }()

    // MARK: Tests

    func testGETRequestDebugDescription() {
        // Given
        let URLString = "http://httpbin.org/get"

        // When
        let request = manager.request(.GET, URLString)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertFalse(contains(components, "-X"), "command should not contain explicit -X flag")
        XCTAssertEqual(components.last ?? "", "\"\(URLString)\"", "URL component should be equal")
    }

    func testPOSTRequestDebugDescription() {
        // Given
        let URLString = "http://httpbin.org/post"

        // When
        let request = manager.request(.POST, URLString)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertEqual(components[3..<5], ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssertEqual(components.last ?? "", "\"\(URLString)\"", "URL component should be equal")
    }

    func testPOSTRequestWithJSONParametersDebugDescription() {
        // Given
        let URLString = "http://httpbin.org/post"

        // When
        let request = manager.request(.POST, URLString, parameters: ["foo": "bar"], encoding: .JSON)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertEqual(components[3..<5], ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssertTrue(request.debugDescription.rangeOfString("-H \"Content-Type: application/json\"") != nil, "command should contain 'application/json' Content-Type")
        XCTAssertTrue(request.debugDescription.rangeOfString("-d \"{\\\"foo\\\":\\\"bar\\\"}\"") != nil, "command data should contain JSON encoded parameters")
        XCTAssertEqual(components.last ?? "", "\"\(URLString)\"", "URL component should be equal")
    }

    func testPOSTRequestWithCookieDebugDescription() {
        // Given
        let URLString = "http://httpbin.org/post"

        let properties = [
            NSHTTPCookieDomain: "httpbin.org",
            NSHTTPCookiePath: "/post",
            NSHTTPCookieName: "foo",
            NSHTTPCookieValue: "bar",
        ]

        let cookie = NSHTTPCookie(properties: properties)!
        manager.session.configuration.HTTPCookieStorage?.setCookie(cookie)

        // When
        let request = manager.request(.POST, URLString)
        let components = cURLCommandComponents(request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"], "components should be equal")
        XCTAssertEqual(components[3..<5], ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssertEqual(components.last ?? "", "\"\(URLString)\"", "URL component should be equal")

        #if !os(OSX)
        XCTAssertEqual(components[5..<6], ["-b"], "command should contain -b flag")
        #endif
    }

    func testPOSTRequestWithCookiesDisabledDebugDescription() {
        // Given
        let URLString = "http://httpbin.org/post"

        let properties = [
            NSHTTPCookieDomain: "httpbin.org",
            NSHTTPCookiePath: "/post",
            NSHTTPCookieName: "foo",
            NSHTTPCookieValue: "bar",
        ]

        let cookie = NSHTTPCookie(properties: properties)!
        managerDisallowingCookies.session.configuration.HTTPCookieStorage?.setCookie(cookie)

        // When
        let request = managerDisallowingCookies.request(.POST, URLString)
        let components = cURLCommandComponents(request)

        // Then
        let cookieComponents = components.filter { $0 == "-b" }
        XCTAssertTrue(cookieComponents.isEmpty, "command should not contain -b flag")
    }

    // MARK: Test Helper Methods

    private func cURLCommandComponents(request: Request) -> [String] {
        return request.debugDescription.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).filter { $0 != "" && $0 != "\\" }
    }
}
