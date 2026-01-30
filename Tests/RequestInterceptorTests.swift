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
import Testing

private struct MockError: Error {}
private struct RetryError: Error {}

// MARK: -

@Suite
struct RetryResultTests {
    @Test
    func retryRequiredProperty() {
        // Given, When
        let retry = RetryResult.retry
        let retryWithDelay = RetryResult.retryWithDelay(1.0)
        let doNotRetry = RetryResult.doNotRetry
        let doNotRetryWithError = RetryResult.doNotRetryWithError(MockError())

        // Then
        #expect(retry.retryRequired == true)
        #expect(retryWithDelay.retryRequired == true)
        #expect(doNotRetry.retryRequired == false)
        #expect(doNotRetryWithError.retryRequired == false)
    }

    @Test
    func delayProperty() {
        // Given, When
        let retry = RetryResult.retry
        let retryWithDelay = RetryResult.retryWithDelay(1.0)
        let doNotRetry = RetryResult.doNotRetry
        let doNotRetryWithError = RetryResult.doNotRetryWithError(MockError())

        // Then
        #expect(retry.delay == nil)
        #expect(retryWithDelay.delay == 1.0)
        #expect(doNotRetry.delay == nil)
        #expect(doNotRetryWithError.delay == nil)
    }

    @Test
    func errorProperty() {
        // Given, When
        let retry = RetryResult.retry
        let retryWithDelay = RetryResult.retryWithDelay(1.0)
        let doNotRetry = RetryResult.doNotRetry
        let doNotRetryWithError = RetryResult.doNotRetryWithError(MockError())

        // Then
        #expect(retry.error == nil)
        #expect(retryWithDelay.error == nil)
        #expect(doNotRetry.error == nil)
        #expect(doNotRetryWithError.error is MockError)
    }
}

// MARK: -

@Suite
struct AdapterTests {
    @Test
    func thatAdapterCallsAdaptHandler() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()
        var adapted = false

        let adapter = Adapter { request, _, completion in
            adapted = true
            completion(.success(request))
        }

        var result: Result<URLRequest, any Error>!

        // When
        adapter.adapt(urlRequest, for: session) { result = $0 }

        // Then
        #expect(adapted)
        #expect(result.isSuccess)
    }

    @Test
    func thatAdapterCallsAdaptHandlerWithStateAPI() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()
        let requestID = UUID()

        let interceptor = InspectorInterceptor(.adapter { @Sendable request, _, completionHandler in
            completionHandler(.success(request))
        })

        let state = RequestAdapterState(requestID: requestID, session: session)

        // When
        interceptor.adapt(urlRequest, using: state) { _ in }
        let adaptation = interceptor.adaptations.first

        // Then
        #expect(interceptor.adaptations.count == 1)
        #expect(adaptation?.result.isSuccess == true)
        #expect(adaptation?.urlRequest == urlRequest)
        #expect(adaptation?.state.requestID == requestID)
        #expect(adaptation.map(\.state.sessionID) == ObjectIdentifier(session))
    }

    @Test
    func thatAdapterCallsRequestRetrierDefaultImplementationInProtocolExtension() {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let adapter = InspectorInterceptor(.adapter { @Sendable request, _, completion in
            completion(.success(request))
        })

        // When
        adapter.retry(request, for: session, dueTo: MockError()) { _ in }

        // Then
        #expect(adapter.retryResults.first == .doNotRetry)
    }

    @Test
    func thatAdapterCanBeImplementedAsynchronously() async {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let adapter = InspectorInterceptor(.adapter { @Sendable request, _, completion in
            DispatchQueue.main.async {
                completion(.success(request))
            }
        })

        // When
        await withCheckedContinuation { continuation in
            adapter.adapt(urlRequest, for: session) { _ in
                continuation.resume()
            }
        }

        // Then
        #expect(adapter.adaptations.count == 1)
        #expect(adapter.adaptations.first?.result.isSuccess == true)
    }
}

// MARK: -

@Suite
struct RetrierTests {
    @Test
    func thatRetrierCallsRetryHandler() {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let retrier = InspectorInterceptor(Retrier { _, _, _, completion in
            completion(.retry)
        })

        // When
        retrier.retry(request, for: session, dueTo: MockError()) { _ in }

        // Then
        #expect(retrier.retryCalledCount == 1)
        #expect(retrier.retryResults.first == .retry)
    }

    @Test
    func thatRetrierCallsRequestAdapterDefaultImplementationInProtocolExtension() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let retrier = InspectorInterceptor(Retrier { _, _, _, completion in
            completion(.retry)
        })

        // When
        retrier.adapt(urlRequest, for: session) { _ in }

        // Then
        #expect(retrier.adaptations.first?.result.isSuccess == true)
    }

    @Test
    func thatRetrierCanBeImplementedAsynchronously() async {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let retrier = InspectorInterceptor(Retrier { _, _, _, completion in
            DispatchQueue.main.async {
                completion(.retry)
            }
        })

        // When
        await withCheckedContinuation { continuation in
            retrier.retry(request, for: session, dueTo: MockError()) { _ in
                continuation.resume()
            }
        }

        // Then
        #expect(retrier.retryCalledCount == 1)
        #expect(retrier.retryResults.first == .retry)
    }
}

// MARK: -

@Suite
struct InterceptorTests {
    @Test
    func adaptHandlerAndRetryHandlerDefaultInitializer() {
        // Given
        let adaptHandler: AdaptHandler = { urlRequest, _, completion in completion(.success(urlRequest)) }
        let retryHandler: RetryHandler = { _, _, _, completion in completion(.doNotRetry) }

        // When
        let interceptor = Interceptor(adaptHandler: adaptHandler, retryHandler: retryHandler)

        // Then
        #expect(interceptor.adapters.count == 1)
        #expect(interceptor.retriers.count == 1)
    }

    @Test
    func adapterAndRetrierDefaultInitializer() {
        // Given
        let adapter = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let retrier = Retrier { _, _, _, completion in completion(.doNotRetry) }

        // When
        let interceptor = Interceptor(adapter: adapter, retrier: retrier)

        // Then
        #expect(interceptor.adapters.count == 1)
        #expect(interceptor.retriers.count == 1)
    }

    @Test
    func adaptersAndRetriersDefaultInitializer() {
        // Given
        let adapter = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let retrier = Retrier { _, _, _, completion in completion(.doNotRetry) }

        // When
        let interceptor = Interceptor(adapters: [adapter, adapter], retriers: [retrier, retrier])

        // Then
        #expect(interceptor.adapters.count == 2)
        #expect(interceptor.retriers.count == 2)
    }

    @Test
    func thatInterceptorCanBeComposedOfMultipleRequestInterceptors() {
        // Given
        let adapter = Adapter { request, _, completion in completion(.success(request)) }
        let retrier = Retrier { _, _, _, completion in completion(.doNotRetry) }
        let inner = Interceptor(adapter: adapter, retrier: retrier)

        // When
        let interceptor = Interceptor(interceptors: [inner])

        // Then
        #expect(interceptor.adapters.count == 1)
        #expect(interceptor.retriers.count == 1)
    }

    @Test
    func thatInterceptorCanAdaptRequestWithNoAdapters() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()
        let interceptor = Interceptor()

        var result: Result<URLRequest, any Error>!

        // When
        interceptor.adapt(urlRequest, for: session) { result = $0 }

        // Then
        #expect(result.isSuccess == true)
        #expect(result.success == urlRequest)
    }

    @Test
    func thatInterceptorCanAdaptRequestWithOneAdapter() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let adapter = Adapter { _, _, completion in completion(.failure(MockError())) }
        let interceptor = Interceptor(adapters: [adapter])

        var result: Result<URLRequest, any Error>!

        // When
        interceptor.adapt(urlRequest, for: session) { result = $0 }

        // Then
        #expect(result.isFailure)
        #expect(result.failure is MockError)
    }

    @Test
    func thatInterceptorCanAdaptRequestWithMultipleAdapters() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let adapter1 = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let adapter2 = Adapter { _, _, completion in completion(.failure(MockError())) }
        let interceptor = Interceptor(adapters: [adapter1, adapter2])

        var result: Result<URLRequest, any Error>!

        // When
        interceptor.adapt(urlRequest, for: session) { result = $0 }

        // Then
        #expect(result.isFailure)
        #expect(result.failure is MockError)
    }

    @Test
    func thatInterceptorCanAdaptRequestWithMultipleAdaptersUsingStateAPI() {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let adapter1 = Adapter { urlRequest, _, completion in completion(.success(urlRequest)) }
        let adapter2 = Adapter { _, _, completion in completion(.failure(MockError())) }
        let interceptor = Interceptor(adapters: [adapter1, adapter2])
        let state = RequestAdapterState(requestID: UUID(), session: session)

        var result: Result<URLRequest, any Error>!

        // When
        interceptor.adapt(urlRequest, using: state) { result = $0 }

        // Then
        #expect(result.isFailure)
        #expect(result.failure is MockError)
    }

    @Test
    func thatInterceptorCanAdaptRequestAsynchronously() async {
        // Given
        let urlRequest = Endpoint().urlRequest
        let session = Session()

        let adapter = Adapter { _, _, completion in
            DispatchQueue.main.async {
                completion(.failure(MockError()))
            }
        }
        let interceptor = InspectorInterceptor(Interceptor(adapters: [adapter]))

        // When
        await withCheckedContinuation { continuation in
            interceptor.adapt(urlRequest, for: session) { _ in
                continuation.resume()
            }
        }

        // Then
        #expect(interceptor.adaptations.first?.result.isFailure == true)
        #expect(interceptor.adaptations.first?.result.failure is MockError)
    }

    @Test
    func thatInterceptorCanRetryRequestWithNoRetriers() {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let interceptor = Interceptor()

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        #expect(result == .doNotRetry)
    }

    @Test
    func thatInterceptorCanRetryRequestWithOneRetrier() {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let retrier = Retrier { _, _, _, completion in completion(.retry) }
        let interceptor = Interceptor(retriers: [retrier])

        var result: RetryResult!

        // When
        interceptor.retry(request, for: session, dueTo: MockError()) { result = $0 }

        // Then
        #expect(result == .retry)
    }

    @Test
    func thatInterceptorCanRetryRequestWithMultipleRetriers() {
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
        #expect(result == .retry)
    }

    @Test
    func thatInterceptorCanRetryRequestAsynchronously() async {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.request(.default)

        let retrier = Retrier { _, _, _, completion in
            DispatchQueue.main.async {
                completion(.retry)
            }
        }
        let interceptor = InspectorInterceptor(Interceptor(retriers: [retrier]))

        // When
        await withCheckedContinuation { continuation in
            interceptor.retry(request, for: session, dueTo: MockError()) { _ in
                continuation.resume()
            }
        }
        // Then
        #expect(interceptor.retryResults.first == .retry)
    }

    @Test
    func thatInterceptorStopsIteratingThroughPendingRetriersWithRetryResult() {
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
        #expect(result == .retry)
        #expect(retrier2Called == false)
    }

    @Test
    func thatInterceptorStopsIteratingThroughPendingRetriersWithRetryWithDelayResult() {
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
        #expect(result == .retryWithDelay(1.0))
        #expect(result.delay == 1.0)
        #expect(retrier2Called == false)
    }

    @Test
    func thatInterceptorStopsIteratingThroughPendingRetriersWithDoNotRetryResult() {
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
        #expect(result == RetryResult.doNotRetryWithError(RetryError()))
        #expect(result.error is RetryError)
        #expect(retrier2Called == false)
    }
}

// MARK: - Functional Tests

@Suite
struct InterceptorRequestTests {
    @Test
    func thatRetryPolicyRetriesRequestTimeout() async {
        // Given
        let interceptor = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0.1))
        let urlRequest = Endpoint.delay(1).modifying(\.timeout, to: 0.01)

        // When
        let request = AF.request(urlRequest, interceptor: interceptor)
        await request.finished()

        // Then
        #expect(request.tasks.count == 2, "There should be two tasks, one original, one retry.")
        #expect(interceptor.retryCalledCount == 2, "retry() should be called twice.")
        #expect(interceptor.retryResults == [.retryWithDelay(0.1), .doNotRetry], "RetryResults should be .retryWithDelay(0.1), .doNotRetry")
    }
}

extension DataRequest {
    func finished() async {
        await withCheckedContinuation { continuation in
            response { _ in continuation.resume() }
        }
    }
}

// MARK: - Static Accessors

@Suite
struct StaticAccessorTests {
    func consumeRequestAdapter(_ requestAdapter: any RequestAdapter) {
        _ = requestAdapter
    }

    func consumeRequestRetrier(_ requestRetrier: any RequestRetrier) {
        _ = requestRetrier
    }

    func consumeRequestInterceptor(_ requestInterceptor: any RequestInterceptor) {
        _ = requestInterceptor
    }

    @Test
    func thatAdapterCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestAdapter(.adapter { request, _, completion in completion(.success(request)) })
    }

    @Test
    func thatRetrierCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestRetrier(.retrier { _, _, _, completion in completion(.doNotRetry) })
    }

    @Test
    func thatInterceptorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestInterceptor(.interceptor())
    }

    @Test
    func thatRetryPolicyCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestInterceptor(.retryPolicy())
    }

    @Test
    func thatConnectionLostRetryPolicyCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeRequestInterceptor(.connectionLostRetryPolicy())
    }
}

// MARK: - Helpers

/// Class which captures the output of any underlying `RequestInterceptor`.
final class InspectorInterceptor<Interceptor: RequestInterceptor>: RequestInterceptor, Sendable {
    private struct State {
        let onAdaptation: ((_ result: Result<URLRequest, any Error>) -> Void)?
        let onRetry: ((_ retryResult: RetryResult) -> Void)?

        var adaptations: [Adaptation] = []
        var retries: [Retry] = []
    }

    private let state: Protected<State>

    struct Adaptation {
        var urlRequest: URLRequest
        var state: State
        var result: Result<URLRequest, any Error>
        var date: Date

        struct State {
            var requestID: UUID
            var sessionID: ObjectIdentifier
        }
    }

    struct Retry {
        var result: RetryResult
        var date: Date
    }

    /// Underlying interceptor.
    let interceptor: Interceptor
    /// Result of performed adaptations.
    var adaptations: [Adaptation] { state.read(\.adaptations) }
    /// Retry events.
    var retries: [Retry] { state.read(\.retries) }
    /// Result of performed retries.
    var retryResults: [RetryResult] { retries.map(\.result) }
    /// Number of times `retry` was called.
    var retryCalledCount: Int { state.read(\.retries.count) }

    init(_ interceptor: Interceptor,
         onAdaptation: ((_ result: Result<URLRequest, any Error>) -> Void)? = nil,
         onRetry: ((_ retryResult: RetryResult) -> Void)? = nil) {
        self.interceptor = interceptor
        state = Protected(State(onAdaptation: onAdaptation, onRetry: onRetry))
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
        let sessionID = ObjectIdentifier(session)
        interceptor.adapt(urlRequest, for: session) { result in
            let onAdaptation = self.state.write { state in
                state.adaptations.append(.init(urlRequest: urlRequest, state: .init(requestID: .zero, sessionID: sessionID), result: result, date: .now))
                return state.onAdaptation
            }

            completion(result)
            onAdaptation?(result)
        }
    }

    func adapt(_ urlRequest: URLRequest, using adapterState: RequestAdapterState, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        let requestID = adapterState.requestID
        let sessionID = ObjectIdentifier(adapterState.session)
        interceptor.adapt(urlRequest, using: adapterState) { result in
            let onAdaptation = self.state.write { state in
                state.adaptations.append(.init(urlRequest: urlRequest, state: .init(requestID: requestID, sessionID: sessionID), result: result, date: .now))
                return state.onAdaptation
            }

            completion(result)
            onAdaptation?(result)
        }
    }

    func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping @Sendable (RetryResult) -> Void) {
        interceptor.retry(request, for: session, dueTo: error) { result in
            let onRetry = self.state.write { state in
                state.retries.append(.init(result: result, date: .now))
                return state.onRetry
            }

            completion(result)
            onRetry?(result)
        }
    }
}

extension UUID {
    static let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

/// Retry a request once, allowing the second to succeed using the method path.
final class SingleRetrier: RequestInterceptor, Sendable {
    private let state = Protected(false)
    private var hasRetried: Bool { state.read(\.self) }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
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

    func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping @Sendable (RetryResult) -> Void) {
        completion(hasRetried ? .doNotRetry : .retry)
        state.write(true)
    }
}

extension Alamofire.RetryResult: Swift.Equatable {
    public static func ==(lhs: RetryResult, rhs: RetryResult) -> Bool {
        switch (lhs, rhs) {
        case (.retry, .retry),
             (.doNotRetry, .doNotRetry),
             (.doNotRetryWithError, .doNotRetryWithError):
            true
        case let (.retryWithDelay(leftDelay), .retryWithDelay(rightDelay)):
            leftDelay == rightDelay
        default:
            false
        }
    }
}
