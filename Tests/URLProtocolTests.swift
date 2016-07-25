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

class ProxyURLProtocol: URLProtocol {

    // MARK: Properties

    struct PropertyKeys {
        static let HandledByForwarderURLProtocol = "HandledByProxyURLProtocol"
    }

    lazy var session: Foundation.URLSession = {
        let configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders

            return configuration
        }()

        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        return session
    }()

    var activeTask: URLSessionTask?

    // MARK: Class Request Methods

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: PropertyKeys.HandledByForwarderURLProtocol, in: request) != nil {
            return false
        }

        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let headers = request.allHTTPHeaderFields {
            return ParameterEncoding.url.encode(request, parameters: headers).0
        }

        return request
    }

    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return false
    }

    // MARK: Loading Methods

    override func startLoading() {
        // rdar://26849668
        // Hopefully will be fixed in a future seed
        // URLProtocol had some API's that didnt make the value type conversion
        let mutableRequest = (request.urlRequest as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: PropertyKeys.HandledByForwarderURLProtocol, in: mutableRequest)
        activeTask = session.dataTask(with: mutableRequest as URLRequest)
        activeTask?.resume()
    }

    override func stopLoading() {
        activeTask?.cancel()
    }
}

// MARK: -

extension ProxyURLProtocol: URLSessionDelegate {

    // MARK: NSURLSessionDelegate

    func URLSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, didReceiveData data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func URLSession(_ session: Foundation.URLSession, task: URLSessionTask, didCompleteWithError error: NSError?) {
        if let response = task.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: -

class URLProtocolTestCase: BaseTestCase {
    var manager: Manager!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()

        manager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [ProxyURLProtocol.self]
                configuration.httpAdditionalHeaders = ["session-configuration-header": "foo"]

                return configuration
            }()

            return Manager(configuration: configuration)
        }()
    }

    // MARK: Tests

    func testThatURLProtocolReceivesRequestHeadersAndSessionConfigurationHeaders() {
        // Given
        let URLString = "https://httpbin.org/response-headers"
        let URL = Foundation.URL(string: URLString)!

        var mutableURLRequest = URLRequest(url: URL)
        mutableURLRequest.httpMethod = Method.GET.rawValue
        mutableURLRequest.setValue("foobar", forHTTPHeaderField: "request-header")

        let expectation = self.expectation(description: "GET request should succeed")

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(mutableURLRequest)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let headers = response?.allHeaderFields as? [String: String] {
            XCTAssertEqual(headers["request-header"], "foobar")
            XCTAssertEqual(headers["session-configuration-header"], "foo")
        } else {
            XCTFail("headers should not be nil")
        }
    }
}
