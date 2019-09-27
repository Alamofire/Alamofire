//
//  RetryPolicyTests.swift
//
//  Copyright (c) 2019 Alamofire Software Foundation (http://alamofire.org/)
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

class BaseRetryPolicyTestCase: BaseTestCase {
    // MARK: Helper Types

    class StubRequest: DataRequest {
        let urlRequest: URLRequest
        override var request: URLRequest? { return urlRequest }

        let mockedResponse: HTTPURLResponse?
        override var response: HTTPURLResponse? { return mockedResponse }

        init(_ url: URL, method: HTTPMethod, response: HTTPURLResponse?, session: Session) {
            mockedResponse = response

            let request = Session.RequestConvertible(url: url,
                                                     method: method,
                                                     parameters: nil,
                                                     encoding: URLEncoding.default,
                                                     headers: nil)

            urlRequest = try! request.asURLRequest()

            super.init(convertible: request,
                       underlyingQueue: session.rootQueue,
                       serializationQueue: session.serializationQueue,
                       eventMonitor: session.eventMonitor,
                       interceptor: nil,
                       delegate: session)
        }
    }

    // MARK: Properties

    let idempotentMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options, .trace]
    let nonIdempotentMethods: Set<HTTPMethod> = [.post, .patch, .connect]
    var methods: Set<HTTPMethod> { return idempotentMethods.union(nonIdempotentMethods) }

    let session = Session(startRequestsImmediately: false)

    let url = URL(string: "https://api.alamofire.org")!
    let connectionLostError = NSError(domain: URLError.errorDomain, code: URLError.networkConnectionLost.rawValue, userInfo: nil)
    let resourceUnavailableError = NSError(domain: URLError.errorDomain, code: URLError.resourceUnavailable.rawValue, userInfo: nil)
    let unknownError = NSError(domain: URLError.errorDomain, code: URLError.unknown.rawValue, userInfo: nil)

    let retryableStatusCodes: Set<Int> = [408, 500, 502, 503, 504]

    let retryableErrorCodes: Set<URLError.Code> = [.backgroundSessionInUseByAnotherProcess,
                                                   .backgroundSessionWasDisconnected,
                                                   .badServerResponse,
                                                   .callIsActive,
                                                   .cannotConnectToHost,
                                                   .cannotFindHost,
                                                   .cannotLoadFromNetwork,
                                                   .dataNotAllowed,
                                                   .dnsLookupFailed,
                                                   .downloadDecodingFailedMidStream,
                                                   .downloadDecodingFailedToComplete,
                                                   .internationalRoamingOff,
                                                   .networkConnectionLost,
                                                   .notConnectedToInternet,
                                                   .secureConnectionFailed,
                                                   .serverCertificateHasBadDate,
                                                   .serverCertificateNotYetValid,
                                                   .timedOut]

    let nonRetryableErrorCodes: Set<URLError.Code> = [.appTransportSecurityRequiresSecureConnection,
                                                      .backgroundSessionRequiresSharedContainer,
                                                      .badURL,
                                                      .cancelled,
                                                      .cannotCloseFile,
                                                      .cannotCreateFile,
                                                      .cannotDecodeContentData,
                                                      .cannotDecodeRawData,
                                                      .cannotMoveFile,
                                                      .cannotOpenFile,
                                                      .cannotParseResponse,
                                                      .cannotRemoveFile,
                                                      .cannotWriteToFile,
                                                      .clientCertificateRejected,
                                                      .clientCertificateRequired,
                                                      .dataLengthExceedsMaximum,
                                                      .fileDoesNotExist,
                                                      .fileIsDirectory,
                                                      .httpTooManyRedirects,
                                                      .noPermissionsToReadFile,
                                                      .redirectToNonExistentLocation,
                                                      .requestBodyStreamExhausted,
                                                      .resourceUnavailable,
                                                      .serverCertificateHasUnknownRoot,
                                                      .serverCertificateUntrusted,
                                                      .unknown,
                                                      .unsupportedURL,
                                                      .userAuthenticationRequired,
                                                      .userCancelledAuthentication,
                                                      .zeroByteResource]

    var errorCodes: Set<URLError.Code> {
        return retryableErrorCodes.union(nonRetryableErrorCodes)
    }
}

// MARK: -

class RetryPolicyTestCase: BaseRetryPolicyTestCase {
    // MARK: Tests - Retry

    func testThatRetryPolicyRetriesRequestsBelowRetryLimit() {
        // Given
        let retryPolicy = RetryPolicy()
        let request = self.request(method: .get)

        var results: [Int: RetryResult] = [:]

        // When
        for index in 0...2 {
            let expectation = self.expectation(description: "retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: connectionLostError) { result in
                results[index] = result
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)

            request.prepareForRetry()
        }

        // Then
        XCTAssertEqual(results.count, 3)

        if results.count == 3 {
            XCTAssertEqual(results[0]?.retryRequired, true)
            XCTAssertEqual(results[0]?.delay, 0.5)
            XCTAssertNil(results[0]?.error)

            XCTAssertEqual(results[1]?.retryRequired, true)
            XCTAssertEqual(results[1]?.delay, 1.0)
            XCTAssertNil(results[1]?.error)

            XCTAssertEqual(results[2]?.retryRequired, false)
            XCTAssertNil(results[2]?.delay)
            XCTAssertNil(results[2]?.error)
        }
    }

    func testThatRetryPolicyRetriesIdempotentRequests() {
        // Given
        let retryPolicy = RetryPolicy()
        var results: [HTTPMethod: RetryResult] = [:]

        // When
        for method in methods {
            let request = self.request(method: method)
            let expectation = self.expectation(description: "retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: connectionLostError) { result in
                results[method] = result
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)
        }

        // Then
        XCTAssertEqual(results.count, methods.count)

        for (method, result) in results {
            XCTAssertEqual(result.retryRequired, idempotentMethods.contains(method))
            XCTAssertEqual(result.delay, result.retryRequired ? 0.5 : nil)
            XCTAssertNil(result.error)
        }
    }

    func testThatRetryPolicyRetriesRequestsWithRetryableStatusCodes() {
        // Given
        let retryPolicy = RetryPolicy()
        let statusCodes = Set(100...599)
        var results: [Int: RetryResult] = [:]

        // When
        for statusCode in statusCodes {
            let request = self.request(method: .get, statusCode: statusCode)
            let expectation = self.expectation(description: "retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: unknownError) { result in
                results[statusCode] = result
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)
        }

        // Then
        XCTAssertEqual(results.count, statusCodes.count)

        for (statusCode, result) in results {
            XCTAssertEqual(result.retryRequired, retryableStatusCodes.contains(statusCode))
            XCTAssertEqual(result.delay, result.retryRequired ? 0.5 : nil)
            XCTAssertNil(result.error)
        }
    }

    func testThatRetryPolicyRetriesRequestsWithRetryableErrors() {
        // Given
        let retryPolicy = RetryPolicy()
        var results: [URLError.Code: RetryResult] = [:]

        // When
        for code in errorCodes {
            let request = self.request(method: .get)
            let error = urlError(with: code)

            let expectation = self.expectation(description: "retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: error) { result in
                results[code] = result
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)
        }

        // Then
        XCTAssertEqual(results.count, errorCodes.count)

        for (urlErrorCode, result) in results {
            XCTAssertEqual(result.retryRequired, retryableErrorCodes.contains(urlErrorCode))
            XCTAssertEqual(result.delay, result.retryRequired ? 0.5 : nil)
            XCTAssertNil(result.error)
        }
    }

    func testThatRetryPolicyDoesNotRetryErrorsThatAreNotURLErrors() {
        // Given
        let retryPolicy = RetryPolicy()
        let request = self.request(method: .get)

        let errors: [Error] = [resourceUnavailableError,
                               unknownError]

        var results: [RetryResult] = []

        // When
        for error in errors {
            let expectation = self.expectation(description: "retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: error) { result in
                results.append(result)
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)
        }

        // Then
        XCTAssertEqual(results.count, errors.count)

        for result in results {
            XCTAssertEqual(result.retryRequired, false)
            XCTAssertNil(result.delay)
            XCTAssertNil(result.error)
        }
    }

    // MARK: Tests - Exponential Backoff

    func testThatRetryPolicyTimeDelayBacksOffExponentially() {
        // Given
        let retryPolicy = RetryPolicy(retryLimit: 4)
        let request = self.request(method: .get)

        var results: [Int: RetryResult] = [:]

        // When
        for index in 0...4 {
            let expectation = self.expectation(description: "retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: connectionLostError) { result in
                results[index] = result
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)

            request.prepareForRetry()
        }

        // Then
        XCTAssertEqual(results.count, 5)

        if results.count == 5 {
            XCTAssertEqual(results[0]?.retryRequired, true)
            XCTAssertEqual(results[0]?.delay, 0.5)
            XCTAssertNil(results[0]?.error)

            XCTAssertEqual(results[1]?.retryRequired, true)
            XCTAssertEqual(results[1]?.delay, 1.0)
            XCTAssertNil(results[1]?.error)

            XCTAssertEqual(results[2]?.retryRequired, true)
            XCTAssertEqual(results[2]?.delay, 2.0)
            XCTAssertNil(results[2]?.error)

            XCTAssertEqual(results[3]?.retryRequired, true)
            XCTAssertEqual(results[3]?.delay, 4.0)
            XCTAssertNil(results[3]?.error)

            XCTAssertEqual(results[4]?.retryRequired, false)
            XCTAssertNil(results[4]?.delay)
            XCTAssertNil(results[4]?.error)
        }
    }

    // MARK: Test Helpers

    func request(method: HTTPMethod = .get, statusCode: Int? = nil) -> Request {
        var response: HTTPURLResponse?

        if let statusCode = statusCode {
            response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        }

        return StubRequest(url, method: method, response: response, session: session)
    }

    func urlError(with code: URLError.Code) -> URLError {
        return NSError(domain: URLError.errorDomain, code: code.rawValue, userInfo: nil) as! URLError
    }
}

// MARK: -

class ConnectionLostRetryPolicyTestCase: BaseRetryPolicyTestCase {
    func testThatConnectionLostRetryPolicyCanBeInitializedWithDefaultValues() {
        // Given, When
        let retryPolicy = ConnectionLostRetryPolicy()

        // Then
        XCTAssertEqual(retryPolicy.retryLimit, 2)
        XCTAssertEqual(retryPolicy.exponentialBackoffBase, 2)
        XCTAssertEqual(retryPolicy.exponentialBackoffScale, 0.5)
        XCTAssertEqual(retryPolicy.retryableHTTPMethods, idempotentMethods)
        XCTAssertEqual(retryPolicy.retryableHTTPStatusCodes, [])
        XCTAssertEqual(retryPolicy.retryableURLErrorCodes, [.networkConnectionLost])
    }

    func testThatConnectionLostRetryPolicyCanBeInitializedWithCustomValues() {
        // Given, When
        let retryPolicy = ConnectionLostRetryPolicy(retryLimit: 3,
                                                    exponentialBackoffBase: 4,
                                                    exponentialBackoffScale: 0.25,
                                                    retryableHTTPMethods: [.delete, .get])

        // Then
        XCTAssertEqual(retryPolicy.retryLimit, 3)
        XCTAssertEqual(retryPolicy.exponentialBackoffBase, 4)
        XCTAssertEqual(retryPolicy.exponentialBackoffScale, 0.25)
        XCTAssertEqual(retryPolicy.retryableHTTPMethods, [.delete, .get])
        XCTAssertEqual(retryPolicy.retryableHTTPStatusCodes, [])
        XCTAssertEqual(retryPolicy.retryableURLErrorCodes, [.networkConnectionLost])
    }
}
