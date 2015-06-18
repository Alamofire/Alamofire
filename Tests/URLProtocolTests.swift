// URLProtocolTests.swift
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
        return request
    }

    override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        return false
    }

    // MARK: Loading Methods

    override func startLoading() {
        let mutableRequest = self.request.mutableCopy() as! NSMutableURLRequest
        NSURLProtocol.setProperty(true, forKey: PropertyKeys.HandledByForwarderURLProtocol, inRequest: mutableRequest)

        self.activeTask = self.session.dataTaskWithRequest(mutableRequest)
        self.activeTask?.resume()
    }

    override func stopLoading() {
        self.activeTask?.cancel()
    }
}

// MARK: -

extension ProxyURLProtocol: NSURLSessionDelegate {

    // MARK: NSURLSessionDelegate

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        self.client?.URLProtocol(self, didLoadData: data)
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let response = task.response {
            self.client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
        }

        self.client?.URLProtocolDidFinishLoading(self)
    }
}

// MARK: -

class URLProtocolTestCase: BaseTestCase {

    // MARK: Setup and Teardown Methods

    override func setUp() {
        super.setUp()

        let protocolClasses: [AnyClass] = [ProxyURLProtocol.self]
        Alamofire.Manager.sharedInstance.session.configuration.protocolClasses = protocolClasses
        Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders = ["Session-Configuration-Header": "foo"]
    }

    override func tearDown() {
        super.tearDown()

        Alamofire.Manager.sharedInstance.session.configuration.protocolClasses = []
    }

    // MARK: Tests

    func testThatURLProtocolReceivesRequestHeadersAndNotSessionConfigurationHeaders() {
        // Given
        let URLString = "http://httpbin.org/response-headers"
        let URL = NSURL(string: URLString)!
        let parameters = ["URLRequest-Header": "foobar"]

        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.HTTPMethod = Method.GET.rawValue

        let URLRequest = ParameterEncoding.URL.encode(mutableURLRequest, parameters: parameters).0

        let expectation = expectationWithDescription("GET request should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var string: AnyObject?
        var error: NSError?

        // When
        Alamofire.request(URLRequest)
            .response { responseRequest, responseResponse, responseString, responseError in
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

        if let headers = response?.allHeaderFields as? [String: String] {
            XCTAssertEqual(headers["URLRequest-Header"] ?? "", "foobar", "URLRequest-Header should be foobar")
            XCTAssertNil(headers["Session-Configuration-Header"], "Session-Configuration-Header should be nil")
        } else {
            XCTFail("headers should not be nil")
        }
    }
}
