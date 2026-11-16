//
//  URLProtocolTests.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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
import Testing

class ProxyURLProtocol: URLProtocol {
    // MARK: Properties

    enum PropertyKeys {
        static let handledByForwarderURLProtocol = "HandledByProxyURLProtocol"
    }

    lazy var session: URLSession = {
        let configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.headers = HTTPHeaders.default

            return configuration
        }()

        return URLSession(configuration: configuration, delegate: ForwardingDelegate(proxy: self), delegateQueue: nil)
    }()

    weak var activeTask: URLSessionTask?

    // MARK: Class Request Methods

    override class func canInit(with task: URLSessionTask) -> Bool {
        if let request = task.currentRequest,
           URLProtocol.property(forKey: PropertyKeys.handledByForwarderURLProtocol, in: request) != nil {
            return false
        }

        return true
    }

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
        false
    }

    // MARK: Loading Methods

    override func startLoading() {
        // rdar://26849668 - URLProtocol had some API's that didn't make the value type conversion
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

extension ProxyURLProtocol {
    /// Forwards the proxy session's events to the protocol. `URLSessionDataDelegate` requires `Sendable`, which
    /// `URLProtocol` explicitly isn't, so the protocol can't be the session's delegate itself.
    final class ForwardingDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private weak var proxy: ProxyURLProtocol?

        init(proxy: ProxyURLProtocol) {
            self.proxy = proxy
        }

        // MARK: NSURLSessionDelegate

        func urlSession(_ session: URLSession,
                        dataTask: URLSessionDataTask,
                        didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
            guard let proxy else { return .cancel }

            proxy.client?.urlProtocol(proxy, didReceive: response, cacheStoragePolicy: .notAllowed)

            return .allow
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let proxy else { return }

            proxy.client?.urlProtocol(proxy, didLoad: data)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
            guard let proxy else { return }

            proxy.client?.urlProtocolDidFinishLoading(proxy)
        }
    }
}

// MARK: -

@Suite(.storesInstances)
struct URLProtocolTestCase {
    let manager: Session

    // MARK: Setup and Teardown

    /// Replaces `setUp()`.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    init() {
        manager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [ProxyURLProtocol.self]
                configuration.headers["Session-Configuration-Header"] = "foo"

                return configuration
            }()

            return stored(Session.independent(configuration: configuration))
        }()
    }

    // MARK: Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func urlProtocolReceivesRequestHeadersAndSessionConfigurationHeaders() async {
        // Given
        let endpoint = Endpoint.responseHeaders.modifying(\.headers, to: ["Request-Header": "foobar"])

        let expectation = Completion("GET request should succeed")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        manager.request(endpoint)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)
        #expect(response.response?.headers["Request-Header"] == "foobar")
        #expect(response.response?.headers["Session-Configuration-Header"] == "foo")
    }
}
