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
        let urlRequest = Endpoint().urlRequest
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

    func testThatAdapterCallsAdaptHandlerWithStateAPI() {
        // Given
        class StateCaptureAdapter: Adapter {
            private(set) var urlRequest: URLRequest?
            private(set) var state: RequestAdapterState?

            override func adapt(_ urlRequest: URLRequest,
                                using state: RequestAdapterState,
                                completion: @escaping (Result<URLRequest, Error>) -> Void) {
                self.urlRequest = urlRequest
                self.state = state

                super.adapt(urlRequest, using: state, completion: completion)
            }
        }

        let urlRequest = Endpoint().urlRequest
        let session = Session()
        let requestID = UUID()

        var adapted = false

        let adapter = StateCaptureAdapter { urlRequest, _, completion in
            adapted = true
            completion(.success(urlRequest))
        }

        let state = RequestAdapterState(requestID: requestID, session: session)

        var result: Result<URLRequest, Error>!

        // When
        adapter.adapt(urlRequest, using: state) { result = $0 }

        // Then
        XCTAssertTrue(adapted)
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(adapter.urlRequest, urlRequest)
        XCTAssertEqual(adapter.state?.requestID, requestID)
        XCTAssertEqual(adapter.state?.session.session, session.session)
    }

    func testThatAdapterCallsRequestRetrierDefaultImplementationInProtocolExtension() {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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
        let urlRequest = Endpoint().urlRequest
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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)
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
        let urlRequest = Endpoint().urlRequest
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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)
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

final class InterceptorTests: BaseTestCase {
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

    func testThatInterceptorCanBeComposedOfMultipleRequestInterceptors() {
        // Given
        let adapter = Adapter { request, _, completion in completion(.success(request)) }
        let retrier = Retrier { _, _, _, completion in completion(.doNotRetry) }
        let inner = Interceptor(adapter: adapter, retrier: retrier)

        // When
        let interceptor = Interceptor(interceptors: [inner])

        // Then
        XCTAssertEqual(interceptor.adapters.count, 1)
        XCTAssertEqual(interceptor.retriers.count, 1)
    }

    func testThatInterceptorCanAdaptRequestWithNoAdapters() {
        // Given
        let urlRequest = Endpoint().urlRequest
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
        let urlRequest = Endpoint().urlRequest
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
        let urlRequest = Endpoint().urlRequest
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

    func testThatInterceptorCanAdaptRequestWithMultipleAdaptersUsingStateAPI() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let adapter1 = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let adapter2 = Adapter { _, _, completion in completion(.failure(MockError())) }
        let interceptor = Interceptor(adapters: [adapter1, adapter2])
        let state = RequestAdapterState(requestID: UUID(), session: session)

        var result: Result<URLRequest, Error>!

        // When
        interceptor.adapt(urlRequest, using: state) { result = $0 }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertTrue(result.failure is MockError)
    }

    func testThatInterceptorCanAdaptRequestAsynchronously() {
        // Given
        let urlRequest = Endpoint().urlRequest
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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let interceptor = Interceptor()

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        XCTAssertEqual(result, .doNotRetry)
    }

    func testThatInterceptorCanRetryRequestWithOneRetrier() {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

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

// MARK: - Functional Tests

final class InterceptorRequestTests: BaseTestCase {
    func testThatRetryPolicyRetriesRequestTimeout() {
        // Given
        let interceptor = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0.1))
        let urlRequest = Endpoint.delay(1).modifying(\.timeout, to: 0.01)
        let expect = expectation(description: "request completed")

        // When
        let request = AF.request(urlRequest, interceptor: interceptor).response { _ in
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request.tasks.count, 2, "There should be two tasks, one original, one retry.")
        XCTAssertEqual(interceptor.retryCalledCount, 2, "retry() should be called twice.")
        XCTAssertEqual(interceptor.retries, [.retryWithDelay(0.1), .doNotRetry], "RetryResults should retryWithDelay, doNotRetry")
    }
}

// MARK: - Static Accessors

#if swift(>=5.5)
final class StaticAccessorTests: BaseTestCase {
    func consumeRequestAdapter(_ requestAdapter: RequestAdapter) {
        _ = requestAdapter
    }

    func consumeRequestRetrier(_ requestRetrier: RequestRetrier) {
        _ = requestRetrier
    }

    func consumeRequestInterceptor(_ requestInterceptor: RequestInterceptor) {
        _ = requestInterceptor
    }

    func testThatAdapterCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestAdapter(.adapter { request, _, completion in completion(.success(request)) })
    }

    func testThatRetrierCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestRetrier(.retrier { _, _, _, completion in completion(.doNotRetry) })
    }

    func testThatInterceptorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestInterceptor(.interceptor())
    }

    func testThatRetryPolicyCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestInterceptor(.retryPolicy())
    }

    func testThatConnectionLostRetryPolicyCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestInterceptor(.connectionLostRetryPolicy())
    }
}
#endif

// MARK: - Helpers

/// Class which captures the output of any underlying `RequestInterceptor`.
final class InspectorInterceptor<Interceptor: RequestInterceptor>: RequestInterceptor {
    var onAdaptation: ((Result<URLRequest, Error>) -> Void)?
    var onRetry: ((RetryResult) -> Void)?

    private(set) var adaptations: [Result<URLRequest, Error>] = []
    private(set) var retries: [RetryResult] = []

    /// Number of times `retry` was called.
    var retryCalledCount: Int { retries.count }

    let interceptor: Interceptor

    init(_ interceptor: Interceptor) {
        self.interceptor = interceptor
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        interceptor.adapt(urlRequest, for: session) { result in
            self.adaptations.append(result)
            completion(result)
            self.onAdaptation?(result)
        }
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        interceptor.retry(request, for: session, dueTo: error) { result in
            self.retries.append(result)
            completion(result)
            self.onRetry?(result)
        }
    }
}

/// Retry a request once, allowing the second to succeed using the method path.
final class SingleRetrier: RequestInterceptor {
    private var hasRetried = false

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if hasRetried {
            let method = urlRequest.method ?? .get
            let endpoint = Endpoint(path: .method(method),
                                    method: method,
                                    headers: urlRequest.headers)
            completion(.success(endpoint.urlRequest))
        } else {
            completion(.success(urlRequest))
        }
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        completion(hasRetried ? .doNotRetry : .retry)
        hasRetried = true
    }
}

extension RetryResult: Equatable {
    public static func ==(lhs: RetryResult, rhs: RetryResult) -> Bool {
        switch (lhs, rhs) {
        case (.retry, .retry),
             (.doNotRetry, .doNotRetry),
             (.doNotRetryWithError, .doNotRetryWithError):
            return true
        case let (.retryWithDelay(leftDelay), .retryWithDelay(rightDelay)):
            return leftDelay == rightDelay
        default:
            return false
        }
    }
}
