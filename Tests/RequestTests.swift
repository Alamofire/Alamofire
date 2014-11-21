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
        XCTAssertEqual(request.request.URL, NSURL(string: URL)!, "request URL should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testRequestClassMethodWithMethodAndURLAndParameters() {
        let URL = "http://httpbin.org/get"
        let request = Alamofire.request(.GET, URL, parameters: ["foo": "bar"])

        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertNotEqual(request.request.URL, NSURL(string: URL)!, "request URL should be equal")
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

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}

class AlamofireRequestDescriptionTestCase: XCTestCase {
    func testRequestDescription() {
        let URL = "http://httpbin.org/get"
        let request = Alamofire.request(.GET, URL)

        XCTAssertEqual(request.description, "GET http://httpbin.org/get", "incorrect request description")

        let expectation = expectationWithDescription("\(URL)")

        request.response { (_, response,_,_) in
            expectation.fulfill()

            XCTAssertEqual(request.description, "GET http://httpbin.org/get (\(response!.statusCode))", "incorrect request description")
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}

class AlamofireRequestDebugDescriptionTestCase: XCTestCase {
    private func cURLCommandComponents(request: Request) -> [String] {
        return request.debugDescription.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).filter { $0 != "" && $0 != "\\" }
    }

    // MARK: -

    func testGETRequestDebugDescription() {
        let URL = "http://httpbin.org/get"
        let request = Alamofire.request(.GET, URL)
        let components = cURLCommandComponents(request)

        XCTAssert(components[0..<3] == ["$", "curl", "-i"], "components should be equal")
        XCTAssert(!contains(components, "-X"), "command should not contain explicit -X flag")
        XCTAssert(components.last! == "\"\(URL)\"", "URL component should be equal")
    }

    func testPOSTRequestDebugDescription() {
        let URL = "http://httpbin.org/post"
        let request = Alamofire.request(.POST, URL)
        let components = cURLCommandComponents(request)

        XCTAssert(components[0..<3] == ["$", "curl", "-i"], "components should be equal")
        XCTAssert(components[3..<5] == ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssert(components.last! == "\"\(URL)\"", "URL component should be equal")
    }

    func testPOSTRequestWithJSONParametersDebugDescription() {
        let URL = "http://httpbin.org/post"
        let request = Alamofire.request(.POST, URL, parameters: ["foo": "bar"], encoding: .JSON)
        let components = cURLCommandComponents(request)

        XCTAssert(components[0..<3] == ["$", "curl", "-i"], "components should be equal")
        XCTAssert(components[3..<5] == ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssert(request.debugDescription.rangeOfString("-H \"Content-Type: application/json\"") != nil)
        XCTAssert(request.debugDescription.rangeOfString("-d \"{\\\"foo\\\":\\\"bar\\\"}\"") != nil)
        XCTAssert(components.last! == "\"\(URL)\"", "URL component should be equal")
    }

    func testPOSTRequestWithCookieDebugDescription() {
        let URL = "http://httpbin.org/post"

        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()

        let properties = [
            NSHTTPCookieDomain: "httpbin.org",
            NSHTTPCookiePath: "/post",
            NSHTTPCookieName: "foo",
            NSHTTPCookieValue: "bar",
        ]
        let cookie = NSHTTPCookie(properties: properties)!
        configuration.HTTPCookieStorage?.setCookie(cookie)

        let manager = Alamofire.Manager(configuration: configuration)
        let request = manager.request(.POST, URL)
        let components = cURLCommandComponents(request)

        XCTAssert(components[0..<3] == ["$", "curl", "-i"], "components should be equal")
        XCTAssert(components[3..<5] == ["-X", "POST"], "command should contain explicit -X flag")
        XCTAssert(components[5..<7] == ["-b", "\"foo=bar\""], "command should contain -b flag")
        XCTAssert(components.last! == "\"\(URL)\"", "URL component should be equal")
    }
}
