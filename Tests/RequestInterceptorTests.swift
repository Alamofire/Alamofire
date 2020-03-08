//
//  RequestInterceptorTests.swift
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

private struct MockError: Error {}
private struct RetryError: Error {}

// MARK: -

final class RetryResultTestCase: BaseTestCase {
    func testRetryRequiredProperty() {
        // Given, When
        let retry = RetryResult.retry
        let retryWithDelay = RetryResult.retryWithDelay(1.0)
        let doNotRetry = RetryResult.doNotRetry
        let doNotRetryWithError = RetryResult.doNotRetryWithError(MockError())

        // Then
        XCTAssertTrue(retry.retryRequired)
        XCTAssertTrue(retryWithDelay.retryRequired)
        XCTAssertFalse(doNotRetry.retryRequired)
        XCTAssertFalse(doNotRetryWithError.retryRequired)
    }

    func testDelayProperty() {
        // Given, When
        let retry = RetryResult.retry
        let retryWithDelay = RetryResult.retryWithDelay(1.0)
        let doNotRetry = RetryResult.doNotRetry
        let doNotRetryWithError = RetryResult.doNotRetryWithError(MockError())

        // Then
        XCTAssertEqual(retry.delay, nil)
        XCTAssertEqual(retryWithDelay.delay, 1.0)
        XCTAssertEqual(doNotRetry.delay, nil)
        XCTAssertEqual(doNotRetryWithError.delay, nil)
    }

    func testErrorProperty() {
        // Given, When
        let retry = RetryResult.retry
        let retryWithDelay = RetryResult.retryWithDelay(1.0)
        let doNotRetry = RetryResult.doNotRetry
        let doNotRetryWithError = RetryResult.doNotRetryWithError(MockError())

        // Then
        XCTAssertNil(retry.error)
        XCTAssertNil(retryWithDelay.error)
        XCTAssertNil(doNotRetry.error)
        XCTAssertTrue(doNotRetryWithError.error is MockError)
    }
}

// MARK: -

final class AdapterTestCase: BaseTestCase {
    func testThatAdapterCallsAdaptHandler() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()
        var adapted = false

        let adapter = Adapter { request, _, completion in
            adapted = true
            completion(.success(request))
        }

        var result: Result<URLRequest, Error>!

        // When
        adapter.adapt(urlRequest, for: session) { result = $0 }

        // Then
        XCTAssertTrue(adapted)
        XCTAssertTrue(result.isSuccess)
    }

    func testThatAdapterCallsRequestRetrierDefaultImplementationInProtocolExtension() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        let adapter = Adapter { request, _, completion in
            completion(.success(request))
        }

        var result: RetryResult!

        // When
        adapter.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .doNotRetry)
    }

    func testThatAdapterCanBeImplementedAsynchronously() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()
        var adapted = false

        let adapter = Adapter { request, _, completion in
            adapted = true
            DispatchQueue.main.async {
                completion(.success(request))
            }
        }

        var result: Result<URLRequest, Error>!

        let completesExpectation = expectation(description: "adapter completes")

        // When
        adapter.adapt(urlRequest, for: session) {
            result = $0
            completesExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(adapted)
        XCTAssertTrue(result.isSuccess)
    }
}

// MARK: -

final class RetrierTestCase: BaseTestCase {
    func testThatRetrierCallsRetryHandler() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)
        var retried = false

        let retrier = Retrier { _, _, _, completion in
            retried = true
            completion(.retry)
        }

        var result: RetryResult!

        // When
        retrier.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertTrue(retried)
        XCTAssertEqual(result, .retry)
    }

    func testThatRetrierCallsRequestAdapterDefaultImplementationInProtocolExtension() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()

        let retrier = Retrier { _, _, _, completion in
            completion(.retry)
        }

        var result: Result<URLRequest, Error>!

        // When
        retrier.adapt(urlRequest, for: session) { result = $0 }

        // Then
        XCTAssertTrue(result.isSuccess)
    }

    func testThatRetrierCanBeImplementedAsynchronously() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)
        var retried = false

        let retrier = Retrier { _, _, _, completion in
            retried = true
            DispatchQueue.main.async {
                completion(.retry)
            }
        }

        var result: RetryResult!

        let completesExpectation = expectation(description: "retrier completes")

        // When
        retrier.retry(request, for: session, dueTo: MockError()) {
            result = $0
            completesExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(retried)
        XCTAssertEqual(result, .retry)
    }
}

// MARK: -

final class InterceptorTestCase: BaseTestCase {
    func testAdaptHandlerAndRetryHandlerDefaultInitializer() {
        // Given
        let adaptHandler: AdaptHandler = { urlRequest, _, completion in completion(.success(urlRequest)) }
        let retryHandler: RetryHandler = { _, _, _, completion in completion(.doNotRetry) }

        // When
        let interceptor = Interceptor(adaptHandler: adaptHandler, retryHandler: retryHandler)

        // Then
        XCTAssertEqual(interceptor.adapters.count, 1)
        XCTAssertEqual(interceptor.retriers.count, 1)
    }

    func testAdapterAndRetrierDefaultInitializer() {
        // Given
        let adapter = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let retrier = Retrier { _, _, _, completion in completion(.doNotRetry) }

        // When
        let interceptor = Interceptor(adapter: adapter, retrier: retrier)

        // Then
        XCTAssertEqual(interceptor.adapters.count, 1)
        XCTAssertEqual(interceptor.retriers.count, 1)
    }

    func testAdaptersAndRetriersDefaultInitializer() {
        // Given
        let adapter = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let retrier = Retrier { _, _, _, completion in completion(.doNotRetry) }

        // When
        let interceptor = Interceptor(adapters: [adapter, adapter], retriers: [retrier, retrier])

        // Then
        XCTAssertEqual(interceptor.adapters.count, 2)
        XCTAssertEqual(interceptor.retriers.count, 2)
    }

    func testThatInterceptorCanAdaptRequestWithNoAdapters() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()
        let interceptor = Interceptor()

        var result: Result<URLRequest, Error>!

        // When
        interceptor.adapt(urlRequest, for: session) { result = $0 }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.success, urlRequest)
    }

    func testThatInterceptorCanAdaptRequestWithOneAdapter() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()

        let adapter = Adapter { _, _, completion in completion(.failure(MockError())) }
        let interceptor = Interceptor(adapters: [adapter])

        var result: Result<URLRequest, Error>!

        // When
        interceptor.adapt(urlRequest, for: session) { result = $0 }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertTrue(result.failure is MockError)
    }

    func testThatInterceptorCanAdaptRequestWithMultipleAdapters() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()

        let adapter1 = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let adapter2 = Adapter { _, _, completion in completion(.failure(MockError())) }
        let interceptor = Interceptor(adapters: [adapter1, adapter2])

        var result: Result<URLRequest, Error>!

        // When
        interceptor.adapt(urlRequest, for: session) { result = $0 }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertTrue(result.failure is MockError)
    }

    func testThatInterceptorCanAdaptRequestAsynchronously() {
        // Given
        let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        let session = Session()

        let adapter = Adapter { _, _, completion in
            DispatchQueue.main.async {
                completion(.failure(MockError()))
            }
        }
        let interceptor = Interceptor(adapters: [adapter])

        var result: Result<URLRequest, Error>!

        let completesExpectation = expectation(description: "interceptor completes")

        // When
        interceptor.adapt(urlRequest, for: session) {
            result = $0
            completesExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertTrue(result.failure is MockError)
    }

    func testThatInterceptorCanRetryRequestWithNoRetriers() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        let interceptor = Interceptor()

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .doNotRetry)
    }

    func testThatInterceptorCanRetryRequestWithOneRetrier() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        let retrier = Retrier { _, _, _, completion in completion(.retry) }
        let interceptor = Interceptor(retriers: [retrier])

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .retry)
    }

    func testThatInterceptorCanRetryRequestWithMultipleRetriers() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        let retrier1 = Retrier { _, _, _, completion in completion(.doNotRetry) }
        let retrier2 = Retrier { _, _, _, completion in completion(.retry) }
        let interceptor = Interceptor(retriers: [retrier1, retrier2])

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .retry)
    }

    func testThatInterceptorCanRetryRequestAsynchronously() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        let retrier = Retrier { _, _, _, completion in
            DispatchQueue.main.async {
                completion(.retry)
            }
        }
        let interceptor = Interceptor(retriers: [retrier])

        var result: RetryResult!

        let completesExpectation = expectation(description: "interceptor completes")

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) {
            result = $0
            completesExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(result, .retry)
    }

    func testThatInterceptorStopsIteratingThroughPendingRetriersWithRetryResult() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        var retrier2Called = false

        let retrier1 = Retrier { _, _, _, completion in completion(.retry) }
        let retrier2 = Retrier { _, _, _, completion in retrier2Called = true; completion(.doNotRetry) }
        let interceptor = Interceptor(retriers: [retrier1, retrier2])

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .retry)
        XCTAssertFalse(retrier2Called)
    }

    func testThatInterceptorStopsIteratingThroughPendingRetriersWithRetryWithDelayResult() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        var retrier2Called = false

        let retrier1 = Retrier { _, _, _, completion in completion(.retryWithDelay(1.0)) }
        let retrier2 = Retrier { _, _, _, completion in retrier2Called = true; completion(.doNotRetry) }
        let interceptor = Interceptor(retriers: [retrier1, retrier2])

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .retryWithDelay(1.0))
        XCTAssertEqual(result.delay, 1.0)
        XCTAssertFalse(retrier2Called)
    }

    func testThatInterceptorStopsIteratingThroughPendingRetriersWithDoNotRetryResult() {
        // Given
        let url = URL(string: "https://httpbin.org/get")!
        let session = Session(startRequestsImmediately: false)
        let request = session.request(url)

        var retrier2Called = false

        let retrier1 = Retrier { _, _, _, completion in completion(.doNotRetryWithError(RetryError())) }
        let retrier2 = Retrier { _, _, _, completion in retrier2Called = true; completion(.doNotRetry) }
        let interceptor = Interceptor(retriers: [retrier1, retrier2])

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, RetryResult.doNotRetryWithError(RetryError()))
        XCTAssertTrue(result.error is RetryError)
        XCTAssertFalse(retrier2Called)
    }
}

// MARK: -

extension RetryResult: Equatable {
    public static func ==(lhs: RetryResult, rhs: RetryResult) -> Bool {
        switch (lhs, rhs) {
        case (.retry, .retry),
             (.retryWithDelay, .retryWithDelay),
             (.doNotRetry, .doNotRetry),
             (.doNotRetryWithError, .doNotRetryWithError):
            return true
        default:
            return false
        }
    }
}
