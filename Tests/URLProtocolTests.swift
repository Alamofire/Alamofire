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
        static let handledByForwarderURLProtocol = "HandledByProxyURLProtocol"
    }

    lazy var session: URLSession = {
        let configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

            return configuration
        }()

        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        return session
    }()

    var activeTask: URLSessionTask?

    // MARK: Class Request Methods

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: PropertyKeys.handledByForwarderURLProtocol, in: request) != nil {
            return false
        }

        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let headers = request.allHTTPHeaderFields {
            do {
                return try URLEncoding.default.encode(request, with: headers)
            } catch {
                return request
            }
        }

        return request
    }

    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return false
    }

    // MARK: Loading Methods

    override func startLoading() {
        // rdar://26849668 - URLProtocol had some API's that didnt make the value type conversion
        let urlRequest = (request.urlRequest! as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: PropertyKeys.handledByForwarderURLProtocol, in: urlRequest)
        activeTask = session.dataTask(with: urlRequest as URLRequest)
        activeTask?.resume()
    }

    override func stopLoading() {
        activeTask?.cancel()
    }
}

// MARK: -

extension ProxyURLProtocol: URLSessionDelegate {

    // MARK: NSURLSessionDelegate

    func URLSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceiveData data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func URLSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let response = task.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: -

class URLProtocolTestCase: BaseTestCase {
    var manager: SessionManager!

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

            return SessionManager(configuration: configuration)
        }()
    }

    // MARK: Tests

    func testThatURLProtocolReceivesRequestHeadersAndSessionConfigurationHeaders() {
        // Given
        let urlString = "https://httpbin.org/response-headers"
        let url = URL(string: urlString)!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.get.rawValue
        urlRequest.setValue("foobar", forHTTPHeaderField: "request-header")

        let expectation = self.expectation(description: "GET request should succeed")

        var response: DefaultDataResponse?

        // When
        manager.request(urlRequest)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        if let headers = response?.response?.allHeaderFields {
            XCTAssertEqual(headers["request-header"] as? String, "foobar")
            XCTAssertEqual(headers["session-configuration-header"] as? String, "foo")
        } else {
            XCTFail("headers should not be nil")
        }
    }
}
