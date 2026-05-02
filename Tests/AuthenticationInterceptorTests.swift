//
//  AuthenticationInterceptorTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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

final class AuthenticationInterceptorTestCase: BaseTestCase {
    // MARK: - Helper Types

    struct TestCredential: AuthenticationCredential {
        let accessToken: String
        let refreshToken: String
        let userID: String
        let expiration: Date

        let requiresRefresh: Bool

        init(accessToken: String = "a0",
             refreshToken: String = "r0",
             userID: String = "u0",
             expiration: Date = Date(),
             requiresRefresh: Bool = false) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.userID = userID
            self.expiration = expiration
            self.requiresRefresh = requiresRefresh
        }
    }

    enum TestAuthError: Error {
        case refreshNetworkFailure
    }

    final class TestAuthenticator: Authenticator {
        private(set) var applyCount = 0
        private(set) var refreshCount = 0
        private(set) var didRequestFailDueToAuthErrorCount = 0
        private(set) var isRequestAuthenticatedWithCredentialCount = 0

        let refreshResult: Result<TestCredential, any Error>?
        let lock = NSLock()
        let refreshQueue: DispatchQueue?

        init(refreshQueue: DispatchQueue? = DispatchQueue(label: "org.alamofire.TestAuthenticator"),
             refreshResult: Result<TestCredential, any Error>? = nil) {
            self.refreshQueue = refreshQueue
            self.refreshResult = refreshResult
        }

        func apply(_ credential: TestCredential, to urlRequest: inout URLRequest) {
            lock.lock(); defer { lock.unlock() }

            applyCount += 1

            urlRequest.headers.add(.authorization(credential.accessToken))
        }

        func refresh(_ credential: TestCredential,
                     for session: Session,
                     completion: @escaping (Result<TestCredential, any Error>) -> Void) {
            lock.lock()

            refreshCount += 1

            let result = refreshResult ?? .success(
                TestCredential(accessToken: "a\(refreshCount)",
                               refreshToken: "a\(refreshCount)",
                               userID: "u1",
                               expiration: Date())
            )

            if let refreshQueue {
                // The 10 ms delay here is important to allow multiple requests to queue up while refreshing.
                refreshQueue.asyncAfter(deadline: .now() + 0.01) { completion(result) }
                lock.unlock()
            } else {
                lock.unlock()
                completion(result)
            }
        }

        func didRequest(_ urlRequest: URLRequest,
                        with response: HTTPURLResponse,
                        failDueToAuthenticationError error: any Error)
            -> Bool {
            lock.lock(); defer { lock.unlock() }

            didRequestFailDueToAuthErrorCount += 1

            return response.statusCode == 401
        }

        func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: TestCredential) -> Bool {
            lock.lock(); defer { lock.unlock() }

            isRequestAuthenticatedWithCredentialCount += 1

            return urlRequest.headers["Authorization"] == credential.accessToken
        }
    }

    final class PathAdapter: RequestAdapter {
        var paths: [String]

        init(paths: [String]) {
            self.paths = paths
        }

        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
            var request = urlRequest

            var urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            urlComponents.path = paths.removeFirst()

            request.url = urlComponents.url

            completion(.success(request))
        }
    }

    // MARK: - Tests - Adapt

    @MainActor
    func testThatInterceptorCanAdaptURLRequest() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a0")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorRethrowsRefreshErrorToAllDeferredAdaptOperations() {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.\(#function)")
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshQueue: queue, refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 3
        let session = stored(Session(rootQueue: queue))

        let expect = expectation(description: "all requests should complete")
        expect.expectedFulfillmentCount = requestCount

        var requests: [Int: Request] = [:]
        var responses: [Int: AFDataResponse<Data?>] = [:]

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(200), interceptor: interceptor).validate().response {
                responses[index] = $0
                expect.fulfill()
            }
            requests[index] = request
        }

        waitForExpectations(timeout: timeout)

        // Then
        for index in 0..<requestCount {
            XCTAssertEqual(responses[index]?.request?.headers.count, 0)
            XCTAssertEqual(responses[index]?.result.isFailure, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.isRequestAdaptationError, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)
            XCTAssertEqual(requests[index]?.retryCount, 0)
        }

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)
    }

    @MainActor
    func testThatInterceptorQueuesAdaptOperationWhenRefreshing() {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let expect = expectation(description: "both requests should complete")
        expect.expectedFulfillmentCount = 2

        var response1: AFDataResponse<Data?>?
        var response2: AFDataResponse<Data?>?

        // When
        let request1 = session.request(.status(200), interceptor: interceptor).validate().response {
            response1 = $0
            expect.fulfill()
        }

        let request2 = session.request(.status(202), interceptor: interceptor).validate().response {
            response2 = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response1?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(response2?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(response1?.result.isSuccess, true)
        XCTAssertEqual(response2?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request1.retryCount, 0)
        XCTAssertEqual(request2.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorQueuesMultipleAdaptOperationsWhenRefreshing() {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 6
        let session = stored(Session())

        let expect = expectation(description: "all requests should complete")
        expect.expectedFulfillmentCount = requestCount

        var requests: [Int: Request] = [:]
        var responses: [Int: AFDataResponse<Data?>] = [:]

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(200 + index), interceptor: interceptor).validate().response {
                responses[index] = $0
                expect.fulfill()
            }
            requests[index] = request
        }

        waitForExpectations(timeout: timeout)

        // Then
        for index in 0..<requestCount {
            XCTAssertEqual(responses[index]?.request?.headers["Authorization"], "a1")
            XCTAssertEqual(responses[index]?.result.isSuccess, true)
            XCTAssertEqual(requests[index]?.retryCount, 0)
        }

        XCTAssertEqual(authenticator.applyCount, requestCount)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)
    }

    @MainActor
    func testThatInterceptorThrowsMissingCredentialErrorWhenCredentialIsNil() {
        // Given
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator)

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers.count, 0)

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestAdaptationError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .missingCredential)

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorRethrowsRefreshErrorFromAdapt() {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers.count, 0)

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestAdaptationError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)

        if case let .requestRetryFailed(_, originalError) = response?.result.failure {
            XCTAssertEqual(originalError.asAFError?.isResponseValidationError, true)
            XCTAssertEqual(originalError.asAFError?.responseCode, 401)
        }

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    // MARK: - Tests - Retry

    // If we not using swift-corelibs-foundation where URLRequest to /invalid/path is a fatal error.
    #if !canImport(FoundationNetworking)
    @MainActor
    func testThatInterceptorDoesNotRetryWithoutResponse() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let urlRequest = URLRequest(url: URL(string: "/invalid/path")!)
        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(urlRequest, interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a0")

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isSessionTaskError, true)

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }
    #endif

    @MainActor
    func testThatInterceptorDoesNotRetryWhenRequestDoesNotFailDueToAuthError() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.status(500), interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a0")

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isResponseValidationError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.responseCode, 500)

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorThrowsMissingCredentialErrorWhenCredentialIsNilAndRequestShouldBeRetried() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.status(401), interceptor: interceptor)
            .validate {
                interceptor.credential = nil
            }
            .response {
                response = $0
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a0")

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .missingCredential)

        if case let .requestRetryFailed(_, originalError) = response?.result.failure {
            XCTAssertEqual(originalError.asAFError?.isResponseValidationError, true)
            XCTAssertEqual(originalError.asAFError?.responseCode, 401)
        }

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorRetriesRequestThatFailedWithOutdatedCredential() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: compositeInterceptor)
            .validate {
                interceptor.credential = TestCredential(accessToken: "a1",
                                                        refreshToken: "r1",
                                                        userID: "u0",
                                                        expiration: Date(),
                                                        requiresRefresh: false)
            }
            .response {
                response = $0
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)

        XCTAssertEqual(request.retryCount, 1)
    }

    // Produces double lock reported in https://github.com/Alamofire/Alamofire/issues/3294#issuecomment-703241558
    @MainActor
    func testThatInterceptorDoesNotDeadlockWhenAuthenticatorCallsRefreshCompletionSynchronouslyOnCallingQueue() {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshQueue: nil)
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let eventMonitor = ClosureEventMonitor()

        eventMonitor.requestDidCreateTask = { _, _ in
            interceptor.credential = TestCredential(accessToken: "a1",
                                                    refreshToken: "r1",
                                                    userID: "u0",
                                                    expiration: Date(),
                                                    requiresRefresh: false)
        }

        let session = stored(Session(eventMonitors: [eventMonitor]))

        let pathAdapter = PathAdapter(paths: ["/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorRetriesRequestAfterRefresh() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])

        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)

        XCTAssertEqual(request.retryCount, 1)
    }

    @MainActor
    func testThatInterceptorTriggersRetryRefreshAfterProactiveRefreshUsesStaleURL() {
        // Given
        // When a request is deferred via requiresRefresh, handleRefreshSuccess replays it through
        // AuthenticationInterceptor.adapt only (not the full adapter chain). A stateful adapter earlier in the chain
        // (PathAdapter) already consumed its first path entry, so the replayed request reuses the stale URL, causing a
        // second 401, a second refresh, and a second apply, resulting in credential a2 and refreshCount == 2.
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a2")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 2)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)

        XCTAssertEqual(request.retryCount, 1)
    }

    @MainActor
    func testThatInterceptorRethrowsRefreshErrorFromRetry() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.status(401), interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a0")

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)

        if case let .requestRetryFailed(_, originalError) = response?.result.failure {
            XCTAssertEqual(originalError.asAFError?.isResponseValidationError, true)
            XCTAssertEqual(originalError.asAFError?.responseCode, 401)
        }

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorRethrowsRefreshErrorToAllPendingRetryRequests() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 3
        let session = stored(Session())

        let expect = expectation(description: "all requests should complete")
        expect.expectedFulfillmentCount = requestCount

        var requests: [Int: Request] = [:]
        var responses: [Int: AFDataResponse<Data?>] = [:]

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(401), interceptor: interceptor).validate().response {
                responses[index] = $0
                expect.fulfill()
            }
            requests[index] = request
        }

        waitForExpectations(timeout: timeout)

        // Then
        for index in 0..<requestCount {
            XCTAssertEqual(responses[index]?.request?.headers["Authorization"], "a0")
            XCTAssertEqual(responses[index]?.result.isFailure, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.isRequestRetryError, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)
            XCTAssertEqual(requests[index]?.retryCount, 0)
        }

        XCTAssertEqual(authenticator.applyCount, requestCount)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, requestCount)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, requestCount)
    }

    @MainActor
    func testThatInterceptorAllowsNewRequestsToTriggerRefreshAfterPreviousRefreshFailure() {
        // Given
        // A failed refresh sets .failed state on the interceptor. A subsequent, independent request
        // that also receives a 401 must be able to trigger a fresh refresh attempt; it is not a
        // late arrival from the failed batch and must not be permanently blocked by cached failure state.
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        // Phase 1 — first request triggers a refresh that fails.
        let firstExpect = expectation(description: "first request should complete")
        var firstResponse: AFDataResponse<Data?>?

        let firstRequest = session.request(.status(401), interceptor: interceptor).validate().response {
            firstResponse = $0
            firstExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Precondition: first request failed and triggered exactly one refresh.
        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)
        XCTAssertEqual(firstResponse?.result.isFailure, true)
        XCTAssertEqual(firstRequest.retryCount, 0)

        // Phase 2 — a new, independent request is made after the failed refresh has fully completed.
        let secondExpect = expectation(description: "second request should complete")
        var secondResponse: AFDataResponse<Data?>?

        let secondRequest = session.request(.status(401), interceptor: interceptor).validate().response {
            secondResponse = $0
            secondExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then: the new request must trigger its own fresh refresh attempt rather than
        // immediately failing with the cached error left over from the previous failed refresh.
        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 2) // Fails: .failed state blocks the new refresh, refreshCount stays at 1.
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 2)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 2)
        XCTAssertEqual(secondResponse?.result.isFailure, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)
        XCTAssertEqual(secondRequest.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorTriggersRefreshWithMultipleParallelRequestsReturning401Responses() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 6
        let session = stored(Session())

        let expect = expectation(description: "both requests should complete")
        expect.expectedFulfillmentCount = requestCount

        var requests: [Int: Request] = [:]
        var responses: [Int: AFDataResponse<Data?>] = [:]

        for index in 0..<requestCount {
            let pathAdapter = PathAdapter(paths: ["/status/401", "/status/20\(index)"])
            let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

            // When
            let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
                responses[index] = $0
                expect.fulfill()
            }

            requests[index] = request
        }

        waitForExpectations(timeout: timeout)

        // Then
        for index in 0..<requestCount {
            let response = responses[index]
            XCTAssertEqual(response?.request?.headers["Authorization"], "a1")
            XCTAssertEqual(response?.result.isSuccess, true)

            let request = requests[index]
            XCTAssertEqual(request?.retryCount, 1)
        }

        XCTAssertEqual(authenticator.applyCount, 12)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 6)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 6)
    }

    // MARK: - Tests - Excessive Refresh

    @MainActor
    func testThatInterceptorIgnoresExcessiveRefreshWhenRefreshWindowIsNil() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let pathAdapter = PathAdapter(paths: ["/status/401",
                                              "/status/401",
                                              "/status/401",
                                              "/status/401",
                                              "/status/401",
                                              "/status/200"])

        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a5")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 6)
        XCTAssertEqual(authenticator.refreshCount, 5)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 5)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 5)

        XCTAssertEqual(request.retryCount, 5)
    }

    @MainActor
    func testThatInterceptorThrowsExcessiveRefreshErrorWhenExcessiveRefreshOccurs() {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 2))

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.status(401), interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a2")

        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)

        if case let .requestRetryFailed(_, originalError) = response?.result.failure {
            XCTAssertEqual(originalError.asAFError?.isResponseValidationError, true)
            XCTAssertEqual(originalError.asAFError?.responseCode, 401)
        }

        XCTAssertEqual(authenticator.applyCount, 3)
        XCTAssertEqual(authenticator.refreshCount, 2)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 3)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 3)

        XCTAssertEqual(request.retryCount, 2)
    }

    @MainActor
    func testThatInterceptorThrowsExcessiveRefreshErrorFromAdaptPath() {
        // Given
        // The requiresRefresh path can also trigger excessive refresh. When a refresh produces a credential that still
        // has requiresRefresh == true, the next adapt attempt will trigger another refresh, and the refresh window
        // guard should fire exactly as it does on the retry path.
        let credential = TestCredential(requiresRefresh: true)
        let refreshedCredential = TestCredential(accessToken: "a1", requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .success(refreshedCredential))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 1))

        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.status(200), interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers.count, 0)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestAdaptationError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorThrowsExcessiveRefreshErrorToAllDeferredAdaptOperationsOnReplay() {
        // Given
        // When multiple requests are queued during a requiresRefresh-triggered refresh, and the refresh produces a
        // credential that still requires refresh, each deferred adapt attempt independently hits the excessive refresh
        // guard and fails with .excessiveRefresh.
        let credential = TestCredential(requiresRefresh: true)
        let refreshedCredential = TestCredential(accessToken: "a1", requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .success(refreshedCredential))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 1))

        let requestCount = 3
        let session = stored(Session())

        let expect = expectation(description: "all requests should complete")
        expect.expectedFulfillmentCount = requestCount

        var requests: [Int: Request] = [:]
        var responses: [Int: AFDataResponse<Data?>] = [:]

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(200), interceptor: interceptor).validate().response {
                responses[index] = $0
                expect.fulfill()
            }
            requests[index] = request
        }

        waitForExpectations(timeout: timeout)

        // Then
        for index in 0..<requestCount {
            XCTAssertEqual(responses[index]?.request?.headers.count, 0)
            XCTAssertEqual(responses[index]?.result.isFailure, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.isRequestAdaptationError, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)
            XCTAssertEqual(requests[index]?.retryCount, 0)
        }

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)
    }

    // MARK: - Tests - Additional Coverage

    @MainActor
    func testThatInterceptorHandlesMultipleSuccessiveRefreshCyclesCorrectly() {
        // Given
        // Two independent 401→refresh→success cycles on the same interceptor instance. Verifies that
        // updateCredential(_:) fully resets the state machine after each successful refresh so that
        // subsequent cycles behave identically to the first.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        // When — cycle 1: request with a0 gets 401, refresh (a0 → a1), retry succeeds.
        let firstExpect = expectation(description: "first cycle should complete")
        var firstResponse: AFDataResponse<Data?>?

        let firstPathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let firstCompositeInterceptor = Interceptor(adapters: [firstPathAdapter, interceptor], retriers: [interceptor])

        let firstRequest = session.request(.default, interceptor: firstCompositeInterceptor).validate().response {
            firstResponse = $0
            firstExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then — cycle 1
        XCTAssertEqual(firstResponse?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(firstResponse?.result.isSuccess, true)
        XCTAssertEqual(firstRequest.retryCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 1)

        // When — cycle 2: new request with a1 gets 401, refresh (a1 → a2), retry succeeds.
        let secondExpect = expectation(description: "second cycle should complete")
        var secondResponse: AFDataResponse<Data?>?

        let secondPathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let secondCompositeInterceptor = Interceptor(adapters: [secondPathAdapter, interceptor], retriers: [interceptor])

        let secondRequest = session.request(.default, interceptor: secondCompositeInterceptor).validate().response {
            secondResponse = $0
            secondExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then — cycle 2 and cumulative state
        XCTAssertEqual(secondResponse?.request?.headers["Authorization"], "a2")
        XCTAssertEqual(secondResponse?.result.isSuccess, true)
        XCTAssertEqual(secondRequest.retryCount, 1)

        XCTAssertEqual(authenticator.applyCount, 4)
        XCTAssertEqual(authenticator.refreshCount, 2)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 2)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 2)
    }

    @MainActor
    func testThatInterceptorAdaptsNewRequestWithoutDeferringWhileRetryPathRefreshIsInProgress() {
        // Given
        // When a refresh is triggered by the retry path, adaptOperations is empty. Any new adapt call must NOT be
        // deferred, it should proceed immediately with the current credential.
        // This is the documented invariant: defer only when adaptOperations is non-empty (i.e., a proactive
        // requiresRefresh-driven refresh is running).
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        let expect = expectation(description: "both requests should complete")
        expect.expectedFulfillmentCount = 2

        var firstResponse: AFDataResponse<Data?>?
        var secondResponse: AFDataResponse<Data?>?

        // When
        // Request A: gets 401, triggering an async retry-path refresh.
        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let requestA = session.request(.default, interceptor: compositeInterceptor).validate().response {
            firstResponse = $0
            expect.fulfill()
        }

        // Request B: adapts while A's refresh may be running. Since adaptOperations is empty,
        // B must not be deferred regardless of the current refreshState.
        let requestB = session.request(.status(200), interceptor: interceptor).validate().response {
            secondResponse = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then: both succeed, only one refresh occurred, and B was applied (not deferred).
        XCTAssertEqual(firstResponse?.result.isSuccess, true)
        XCTAssertEqual(secondResponse?.result.isSuccess, true)
        XCTAssertNotNil(secondResponse?.request?.headers["Authorization"])

        XCTAssertEqual(requestA.retryCount, 1)
        XCTAssertEqual(requestB.retryCount, 0)

        XCTAssertEqual(authenticator.applyCount, 3)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)
    }

    @MainActor
    func testThatInterceptorAllowsNewRefreshAfterExternalCredentialUpdateFollowingRetryPathFailure() {
        // Given
        // After a retry-path refresh fails the interceptor enters .failed state, which blocks subsequent retries from
        // triggering another refresh. Setting interceptor.credential externally calls updateCredential(_:), which
        // increments credentialVersion and resets refreshState to .idle, restoring the ability to refresh.
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        // First, trigger a retry-path refresh that fails, putting interceptor into .failed state.
        let firstExpect = expectation(description: "first request should complete")
        var firstResponse: AFDataResponse<Data?>?

        session.request(.status(401), interceptor: interceptor).validate().response {
            firstResponse = $0
            firstExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(firstResponse?.result.isFailure, true)

        // When: credential is externally replaced. updateCredential(_:) resets refreshState to .idle.
        interceptor.credential = TestCredential(accessToken: "ext")

        // Second, a new 401 should now trigger a fresh refresh rather than immediately failing with the error cached in
        // .failed state.
        let secondExpect = expectation(description: "second request should complete")
        var secondResponse: AFDataResponse<Data?>?

        session.request(.status(401), interceptor: interceptor).validate().response {
            secondResponse = $0
            secondExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then: a second refresh was attempted, proving .failed was cleared by updateCredential(_:).
        // The refresh fails again (same authenticator), but crucially refreshCount is 2, not 1.
        XCTAssertEqual(secondResponse?.request?.headers["Authorization"], "ext")
        XCTAssertEqual(secondResponse?.result.isFailure, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)

        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 2)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 2)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 2)
    }

    @MainActor
    func testThatInterceptorAdaptsDirectlyAfterExternalCredentialUpdateFollowingProactiveRefreshFailure() {
        // Given
        // After a proactive (requiresRefresh-triggered) refresh failure the interceptor is in .failed state with the
        // original requiresRefresh: true credential still in place. Setting interceptor.credential to a valid, non-stale
        // credential via updateCredential(_:) resets refreshState to .idle and installs the new credential so the next
        // request can adapt immediately without triggering any further refresh.
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        // First, proactive refresh fails and the deferred request gets an adaptation error.
        let firstExpect = expectation(description: "first request should complete")
        var firstResponse: AFDataResponse<Data?>?

        session.request(.status(200), interceptor: interceptor).validate().response {
            firstResponse = $0
            firstExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(firstResponse?.result.isFailure, true)
        XCTAssertEqual(firstResponse?.result.failure?.asAFError?.isRequestAdaptationError, true)

        // When: a working, non-stale credential is set externally.
        interceptor.credential = TestCredential(accessToken: "ext", requiresRefresh: false)

        // Phase 2 — new request should adapt immediately with the new credential; no refresh needed.
        let secondExpect = expectation(description: "second request should complete")
        var secondResponse: AFDataResponse<Data?>?

        let secondRequest = session.request(.status(200), interceptor: interceptor).validate().response {
            secondResponse = $0
            secondExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then: the new request succeeds using the externally set credential, with no additional refresh.
        XCTAssertEqual(secondResponse?.request?.headers["Authorization"], "ext")
        XCTAssertEqual(secondResponse?.result.isSuccess, true)
        XCTAssertEqual(secondRequest.retryCount, 0)

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)
    }

    @MainActor
    func testThatInterceptorDoesNotDeadlockWhenAuthenticatorCallsRefreshCompletionSynchronouslyOnRetryPath() {
        // Given
        // The refresh(_:for:insideLock:) helper dispatches to a serial queue via queue.async before calling
        // authenticator.refresh(_:for:completion:), ensuring the mutableState write lock is not held when the completion
        // fires. This test verifies that invariant holds on the retry path (a 401 response), complementing the existing
        // proactive-path (requiresRefresh) test.
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshQueue: nil)
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])
        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a1")
        XCTAssertEqual(response?.result.isSuccess, true)

        XCTAssertEqual(authenticator.applyCount, 2)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)

        XCTAssertEqual(request.retryCount, 1)
    }

    @MainActor
    func testThatExcessiveRefreshTimestampsArePreservedAfterFailedStateIsClearedByAdapt() {
        // Given
        // The adapt path clears .failed to .idle to allow new requests to trigger a fresh refresh. The refreshTimestamps
        // array must survive this reset because it is the RefreshWindow's authoritative history; clearing it would
        // silently bypass the excessive-refresh guard.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 1))
        let session = stored(Session())

        // First, one successful refresh consumes the entire budget (maximumAttempts: 1).
        let firstExpect = expectation(description: "first request should complete")
        var firstResponse: AFDataResponse<Data?>?

        let firstPathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let firstCompositeInterceptor = Interceptor(adapters: [firstPathAdapter, interceptor], retriers: [interceptor])

        session.request(.default, interceptor: firstCompositeInterceptor).validate().response {
            firstResponse = $0
            firstExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        XCTAssertEqual(firstResponse?.result.isSuccess, true)
        XCTAssertEqual(authenticator.refreshCount, 1)

        // Second, a 401 hits the exhausted window, producing .failed(excessiveRefresh) state.
        let secondExpect = expectation(description: "second request should complete")
        var secondResponse: AFDataResponse<Data?>?

        session.request(.status(401), interceptor: interceptor).validate().response {
            secondResponse = $0
            secondExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)

        // Third, a new request adapts, firing the adapt-clear (.failed to .idle). The request then gets a 401 and attempts
        // another refresh. Despite the state reset, refreshTimestamps is unchanged, so the excessive-refresh guard
        // fires again immediately.
        let thirdExpect = expectation(description: "third request should complete")
        var thirdResponse: AFDataResponse<Data?>?

        session.request(.status(401), interceptor: interceptor).validate().response {
            thirdResponse = $0
            thirdExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then: It also fails with excessiveRefresh, proving the timestamp survived the adapt-clear.
        XCTAssertEqual(thirdResponse?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(thirdResponse?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)

        // Only one actual authenticator.refresh call ever occurred.
        // Second and third were both blocked before reaching authenticator.refresh.
        XCTAssertEqual(authenticator.refreshCount, 1)
    }

    @MainActor
    func testThatInterceptorThrowsMissingCredentialErrorWhenCredentialIsSetToNilAfterBeingValid() {
        // Given
        // Setting interceptor.credential = nil calls updateCredential(nil), which stores nil, increments credentialVersion,
        // and resets refreshState. Subsequent requests must fail immediately with .missingCredential at the adapt stage.
        // This is distinct from the existing test that starts with no credential. Here the transition is valid to nil.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        // When
        interceptor.credential = nil

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        let request = session.request(.status(200), interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers.count, 0)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestAdaptationError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .missingCredential)

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorThrowsExcessiveRefreshErrorImmediatelyWhenMaximumAttemptsIsZero() {
        // Given
        // A RefreshWindow with maximumAttempts: 0 makes every refresh attempt immediately excessive: isRefreshExcessive
        // checks refreshAttemptsWithinWindow >= maximumAttempts, and 0 >= 0 is unconditionally true regardless of how
        // many (zero) refreshes have actually occurred. authenticator.refresh is therefore never reached.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 0))
        let session = stored(Session())

        let expect = expectation(description: "request should complete")
        var response: AFDataResponse<Data?>?

        // When
        let request = session.request(.status(401), interceptor: interceptor).validate().response {
            response = $0
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.request?.headers["Authorization"], "a0")
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.isRequestRetryError, true)
        XCTAssertEqual(response?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)

        XCTAssertEqual(authenticator.applyCount, 1)
        XCTAssertEqual(authenticator.refreshCount, 0)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 1)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 1)

        XCTAssertEqual(request.retryCount, 0)
    }

    @MainActor
    func testThatInterceptorThrowsExcessiveRefreshErrorToAllParallelRequestsAfterExceedingRefreshWindow() {
        // Given
        // Three parallel requests all get 401, triggering one refresh (a0 → a1). All three retry with a1 and all get
        // 401 again. The second refresh attempt is blocked by the refresh window (maximumAttempts: 1 already exhausted).
        // All three requests fail with .excessiveRefresh. This exercises the path where isRefreshExcessive fires after
        // requestsToRetry has been built up by a prior successful refresh cycle.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 1))

        let requestCount = 3
        let session = stored(Session())

        let expect = expectation(description: "all requests should complete")
        expect.expectedFulfillmentCount = requestCount

        var requests: [Int: Request] = [:]
        var responses: [Int: AFDataResponse<Data?>] = [:]

        // When: Each request hits /status/401 twice: once on the initial attempt (triggering the one allowed refresh),
        // and once after retrying with a1 (triggering the excessive check).
        for index in 0..<requestCount {
            let pathAdapter = PathAdapter(paths: ["/status/401", "/status/401"])
            let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

            let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
                responses[index] = $0
                expect.fulfill()
            }
            requests[index] = request
        }

        waitForExpectations(timeout: timeout)

        // Then
        for index in 0..<requestCount {
            XCTAssertEqual(responses[index]?.result.isFailure, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.isRequestRetryError, true)
            XCTAssertEqual(responses[index]?.result.failure?.asAFError?.underlyingError as? AuthenticationError, .excessiveRefresh)
            // retryCount is 1, each request was retried once after the first successful refresh, then rejected by the
            // excessive check without a second actual retry.
            XCTAssertEqual(requests[index]?.retryCount, 1)
        }

        // One successful refresh occurred (first batch). The second was blocked.
        XCTAssertEqual(authenticator.applyCount, 6)
        XCTAssertEqual(authenticator.refreshCount, 1)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 6)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 6)
    }

    @MainActor
    func testThatInterceptorAllowsProactiveRefreshFromFailedStateUnlikeRetryPath() {
        // Given
        // After a proactive refresh failure, refreshState is .failed. The retry path has an explicit .failed case that
        // returns .doNotRetryWithError immediately. The proactive adapt path has no such gate. It only checks
        // isRefreshing (which is false for .failed), so a new request with requiresRefresh: true triggers another
        // proactive refresh, overwriting .failed with .refreshing. This test verifies that asymmetry is intentional
        // and preserved.
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session())

        // Phase 1 — proactive refresh fails, putting interceptor into .failed state.
        let firstExpect = expectation(description: "first request should complete")
        var firstResponse: AFDataResponse<Data?>?

        session.request(.status(200), interceptor: interceptor).validate().response {
            firstResponse = $0
            firstExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        XCTAssertEqual(firstResponse?.result.isFailure, true)
        XCTAssertEqual(firstResponse?.result.failure?.asAFError?.isRequestAdaptationError, true)
        XCTAssertEqual(authenticator.refreshCount, 1)

        // Second, a new request with the same requiresRefresh: true credential adapts. It enters the proactive path,
        // appends to adaptOperations, calls refresh(), overwriting .failed with .refreshing. The retry path's .failed
        // gate is never reached.
        let secondExpect = expectation(description: "second request should complete")
        var secondResponse: AFDataResponse<Data?>?

        session.request(.status(200), interceptor: interceptor).validate().response {
            secondResponse = $0
            secondExpect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then: a second refresh was triggered (refreshCount == 2), proving .failed did not block the proactive adapt
        // path the way it blocks the retry path.
        XCTAssertEqual(secondResponse?.result.isFailure, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.isRequestAdaptationError, true)
        XCTAssertEqual(secondResponse?.result.failure?.asAFError?.underlyingError as? TestAuthError, .refreshNetworkFailure)

        XCTAssertEqual(authenticator.applyCount, 0)
        XCTAssertEqual(authenticator.refreshCount, 2)
        XCTAssertEqual(authenticator.didRequestFailDueToAuthErrorCount, 0)
        XCTAssertEqual(authenticator.isRequestAuthenticatedWithCredentialCount, 0)
    }
}
