//
//  ConnectionLostRetryPolicyTests.swift
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

@testable import Alamofire
import Foundation
import XCTest

class ConnectionLostRetryPolicyTestCase: BaseTestCase {

    // MARK: - Helper Types

    private class StubRequest: DataRequest {
        let urlRequest: URLRequest
        override var request: URLRequest? { return urlRequest }

        init(_ url: URL, method: HTTPMethod, session: Session) {
            let request = Session.RequestConvertible(
                url: url,
                method: method,
                parameters: nil,
                encoding: URLEncoding.default,
                headers: nil
            )

            urlRequest = try! request.asURLRequest()

            super.init(
                convertible: request,
                underlyingQueue: session.rootQueue,
                serializationQueue: session.serializationQueue,
                eventMonitor: session.eventMonitor,
                interceptor: nil,
                retryPolicies: [],
                delegate: session
            )
        }
    }

    // MARK: - Properties

    private let idempotentMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options, .trace]
    private let nonIdempotentMethods: Set<HTTPMethod> = [.post, .patch, .connect]
    private var methods: Set<HTTPMethod> { return idempotentMethods.union(nonIdempotentMethods) }

    private let session = Session(startRequestsImmediately: false)

    private let url = URL(string: "https://api.example.com")!
    private let connectionLostError = NSError(domain: URLError.errorDomain, code: URLError.networkConnectionLost.rawValue, userInfo: nil)
    private let dnsLookupError = NSError(domain: URLError.errorDomain, code: URLError.dnsLookupFailed.rawValue, userInfo: nil)
    private let badServerResponseError = NSError(domain: URLError.errorDomain, code: URLError.badServerResponse.rawValue, userInfo: nil)

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        // No-op
    }

    override func tearDown() {
        super.tearDown()
        session.session.invalidateAndCancel()
    }

    // MARK: - Tests - Retry

    func testThatRetryPolicyRetriesRequestsBelowRetryLimit() {
        // Given
        let retryPolicy = ConnectionLostRetryPolicy()
        let request = self.request(method: .get)

        var results: [Int: (shouldRetry: Bool, timeDelay: TimeInterval)] = [:]

        // When
        for index in 0...2 {
            results[index] = retryPolicy.shouldRetry(request, with: connectionLostError)
            request.requestIsRetrying()
        }

        // Then
        XCTAssertEqual(results.count, 3)

        if results.count == 3 {
            XCTAssertEqual(results[0]?.shouldRetry, true)
            XCTAssertEqual(results[0]?.timeDelay, 0.25)

            XCTAssertEqual(results[1]?.shouldRetry, true)
            XCTAssertEqual(results[1]?.timeDelay, 0.5)

            XCTAssertEqual(results[2]?.shouldRetry, false)
            XCTAssertEqual(results[2]?.timeDelay, 0.0)
        }
    }

    func testThatRetryPolicyRetriesIdempotentRequestsWhenErrorIsConnectionLostError() {
        // Given
        let retryPolicy = ConnectionLostRetryPolicy()
        var results: [HTTPMethod: (shouldRetry: Bool, timeDelay: TimeInterval)] = [:]

        // When
        for method in methods {
            let request = self.request(method: method)
            results[method] = retryPolicy.shouldRetry(request, with: connectionLostError)
        }

        // Then
        XCTAssertEqual(results.count, methods.count)

        for (method, result) in results {
            XCTAssertEqual(result.shouldRetry, idempotentMethods.contains(method))
            XCTAssertEqual(result.timeDelay, result.shouldRetry ? 0.25 : 0.0)
        }
    }

    func testThatRetryPolicyDoesNotRetryRequestWithInvalidHTTPMethod() {
        // Given
        let retryPolicy = ConnectionLostRetryPolicy()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "invalid"

        let request = session.request(urlRequest)

        // When
        let (shouldRetry, timeDelay) = retryPolicy.shouldRetry(request, with: connectionLostError)

        // Then
        XCTAssertEqual(shouldRetry, false)
        XCTAssertEqual(timeDelay, 0.0)
    }

    func testThatRetryPolicyDoesNotRetryWhenErrorIsNotConnectionLostError() {
        // Given
        let retryPolicy = ConnectionLostRetryPolicy()
        let errors: [Error] = [dnsLookupError, badServerResponseError]

        var results: [(shouldRetry: Bool, timeDelay: TimeInterval)] = []

        // When
        for error in errors {
            let request = self.request(method: .get)
            results.append(retryPolicy.shouldRetry(request, with: error))
        }

        // Then
        XCTAssertEqual(results.count, errors.count)

        for (shouldRetry, timeDelay) in results {
            XCTAssertEqual(shouldRetry, false)
            XCTAssertEqual(timeDelay, 0.0)
        }
    }

    // MARK: - Tests - Exponential Backoff

    func testThatRetryPolicyTimeDelayBacksOffExponentially() {
        // Given
        let retryPolicy = ConnectionLostRetryPolicy(
            retryLimit: 4,
            exponentialBackoffBase: 2,
            exponentialBackoffScale: 0.25
        )

        let request = self.request(method: .get)

        var results: [Int: (shouldRetry: Bool, timeDelay: TimeInterval)] = [:]

        // When
        for index in 0...4 {
            results[index] = retryPolicy.shouldRetry(request, with: connectionLostError)
            request.requestIsRetrying()
        }

        // Then
        XCTAssertEqual(results.count, 5)

        if results.count == 5 {
            XCTAssertEqual(results[0]?.shouldRetry, true)
            XCTAssertEqual(results[0]?.timeDelay, 0.25)

            XCTAssertEqual(results[1]?.shouldRetry, true)
            XCTAssertEqual(results[1]?.timeDelay, 0.5)

            XCTAssertEqual(results[2]?.shouldRetry, true)
            XCTAssertEqual(results[2]?.timeDelay, 1.0)

            XCTAssertEqual(results[3]?.shouldRetry, true)
            XCTAssertEqual(results[3]?.timeDelay, 2.0)

            XCTAssertEqual(results[4]?.shouldRetry, false)
            XCTAssertEqual(results[4]?.timeDelay, 0.0)
        }
    }

    // MARK: - Private - Test Helpers

    private func request(method: HTTPMethod) -> Request {
        return StubRequest(url, method: method, session: session)
    }
}
