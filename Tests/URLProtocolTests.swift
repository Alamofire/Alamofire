//
//  URLProtocolTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Alamofire
import Foundation
import XCTest

class ProxyURLProtocol: NSURLProtocol {

    // MARK: Properties

    struct PropertyKeys {
        static let HandledByForwarderURLProtocol = "HandledByProxyURLProtocol"
    }

    lazy var session: NSURLSession = {
        let configuration: NSURLSessionConfiguration = {
            let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
            configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders

            return configuration
        }()

        let session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        return session
    }()

    var activeTask: NSURLSessionTask?

    // MARK: Class Request Methods

    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if NSURLProtocol.propertyForKey(PropertyKeys.HandledByForwarderURLProtocol, inRequest: request) != nil {
            return false
        }

        return true
    }

    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        if let headers = request.allHTTPHeaderFields {
            return ParameterEncoding.URL.encode(request, parameters: headers).0
        }

        return request
    }

    override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        return false
    }

    // MARK: Loading Methods

    override func startLoading() {
        let mutableRequest = request.URLRequest
        NSURLProtocol.setProperty(true, forKey: PropertyKeys.HandledByForwarderURLProtocol, inRequest: mutableRequest)

        activeTask = session.dataTaskWithRequest(mutableRequest)
        activeTask?.resume()
    }

    override func stopLoading() {
        activeTask?.cancel()
    }
}

// MARK: -

extension ProxyURLProtocol: NSURLSessionDelegate {

    // MARK: NSURLSessionDelegate

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        client?.URLProtocol(self, didLoadData: data)
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let response = task.response {
            client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
        }

        client?.URLProtocolDidFinishLoading(self)
    }
}

// MARK: -

class URLProtocolTestCase: BaseTestCase {
    var manager: Manager!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()

        manager = {
            let configuration: NSURLSessionConfiguration = {
                let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
                configuration.protocolClasses = [ProxyURLProtocol.self]
                configuration.HTTPAdditionalHeaders = ["session-configuration-header": "foo"]

                return configuration
            }()

            return Manager(configuration: configuration)
        }()
    }

    // MARK: Tests

    func testThatURLProtocolReceivesRequestHeadersAndSessionConfigurationHeaders() {
        // Given
        let URLString = "https://httpbin.org/response-headers"
        let URL = NSURL(string: URLString)!

        let URLRequest = NSMutableURLRequest(URL: URL)
        URLRequest.HTTPMethod = Method.GET.rawValue
        URLRequest.setValue("foobar", forHTTPHeaderField: "request-header")

        let expectation = expectationWithDescription("GET request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: NSData?
        var error: NSError?

        // When
        manager.request(URLRequest)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let headers = response?.allHeaderFields as? [String: String] {
            XCTAssertEqual(headers["request-header"], "foobar")

            // Configuration headers are only passed in on iOS 9.0+
            if #available(iOS 9.0, *) {
                XCTAssertEqual(headers["session-configuration-header"], "foo")
            } else {
                XCTAssertNil(headers["session-configuration-header"])
            }
        } else {
            XCTFail("headers should not be nil")
        }
    }
}
