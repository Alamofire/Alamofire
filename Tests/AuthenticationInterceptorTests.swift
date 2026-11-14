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
import Testing

@Suite(.storesInstances)
struct AuthenticationInterceptorTestCase {
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
        private struct Counts {
            var apply = 0
            var refresh = 0
            var didRequestFailDueToAuthError = 0
            var isRequestAuthenticatedWithCredential = 0
        }

        private let counts = Protected(Counts())

        var applyCount: Int { counts.read(\.apply) }
        var refreshCount: Int { counts.read(\.refresh) }
        var didRequestFailDueToAuthErrorCount: Int { counts.read(\.didRequestFailDueToAuthError) }
        var isRequestAuthenticatedWithCredentialCount: Int { counts.read(\.isRequestAuthenticatedWithCredential) }

        let refreshResult: Result<TestCredential, any Error>?
        let refreshQueue: DispatchQueue?

        init(refreshQueue: DispatchQueue? = DispatchQueue(label: "org.alamofire.TestAuthenticator"),
             refreshResult: Result<TestCredential, any Error>? = nil) {
            self.refreshQueue = refreshQueue
            self.refreshResult = refreshResult
        }

        func apply(_ credential: TestCredential, to urlRequest: inout URLRequest) {
            counts.write { $0.apply += 1 }

            urlRequest.headers.add(.authorization(credential.accessToken))
        }

        func refresh(_ credential: TestCredential,
                     for session: Session,
                     completion: @escaping @Sendable (Result<TestCredential, any Error>) -> Void) {
            let refreshCount = counts.write { counts in
                counts.refresh += 1
                return counts.refresh
            }

            let result = refreshResult ?? .success(
                TestCredential(accessToken: "a\(refreshCount)",
                               refreshToken: "a\(refreshCount)",
                               userID: "u1",
                               expiration: Date())
            )

            if let refreshQueue {
                // The 10 ms delay here is important to allow multiple requests to queue up while refreshing.
                refreshQueue.asyncAfter(deadline: .now() + 0.01) { completion(result) }
            } else {
                completion(result)
            }
        }

        func didRequest(_ urlRequest: URLRequest,
                        with response: HTTPURLResponse,
                        failDueToAuthenticationError error: any Error)
            -> Bool {
            counts.write { $0.didRequestFailDueToAuthError += 1 }

            return response.statusCode == 401
        }

        func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: TestCredential) -> Bool {
            counts.write { $0.isRequestAuthenticatedWithCredential += 1 }

            return urlRequest.headers["Authorization"] == credential.accessToken
        }
    }

    final class PathAdapter: RequestAdapter {
        private let paths: Protected<[String]>

        init(paths: [String]) {
            self.paths = Protected(paths)
        }

        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
            var request = urlRequest

            var urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            urlComponents.path = paths.write { $0.removeFirst() }

            request.url = urlComponents.url

            completion(.success(request))
        }
    }

    // MARK: - Tests - Adapt

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorCanAdaptURLRequest() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a0")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorRethrowsRefreshErrorToAllDeferredAdaptOperations() async {
        // Given
        let session = stored(Session.independent())
        let credential = TestCredential(requiresRefresh: true)
        // Completing the refresh on the session's root queue queues it behind every request's adapt call, so all of them
        // are deferred while refreshing.
        let authenticator = TestAuthenticator(refreshQueue: session.rootQueue,
                                              refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 3

        let expect = Completion("all requests should complete", expectedCount: requestCount)

        let requests = Capture<[Int: Request]>([:])
        let responses = Capture<[Int: AFDataResponse<Data?>]>([:])

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(200), interceptor: interceptor).validate().response {
                responses.value[index] = $0
                expect.complete()
            }
            requests.value[index] = request
        }

        await expect.wait()

        // Then
        for index in 0..<requestCount {
            #expect(responses.value[index]?.request?.headers.isEmpty == true)
            #expect(responses.value[index]?.result.isFailure == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.isRequestAdaptationError == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)
            #expect(requests.value[index]?.retryCount == 0)
        }

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorQueuesAdaptOperationWhenRefreshing() async {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let expect = Completion("both requests should complete", expectedCount: 2)

        let response1 = Capture<AFDataResponse<Data?>?>()
        let response2 = Capture<AFDataResponse<Data?>?>()

        // When
        let request1 = session.request(.status(200), interceptor: interceptor).validate().response {
            response1.value = $0
            expect.complete()
        }

        let request2 = session.request(.status(202), interceptor: interceptor).validate().response {
            response2.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response1.request?.headers["Authorization"] == "a1")
        #expect(response2.request?.headers["Authorization"] == "a1")
        #expect(response1.result?.isSuccess == true)
        #expect(response2.result?.isSuccess == true)

        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request1.retryCount == 0)
        #expect(request2.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorQueuesMultipleAdaptOperationsWhenRefreshing() async {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 6
        let session = stored(Session.independent())

        let expect = Completion("all requests should complete", expectedCount: requestCount)

        let requests = Capture<[Int: Request]>([:])
        let responses = Capture<[Int: AFDataResponse<Data?>]>([:])

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(200 + index), interceptor: interceptor).validate().response {
                responses.value[index] = $0
                expect.complete()
            }
            requests.value[index] = request
        }

        await expect.wait()

        // Then
        for index in 0..<requestCount {
            #expect(responses.value[index]?.request?.headers["Authorization"] == "a1")
            #expect(responses.value[index]?.result.isSuccess == true)
            #expect(requests.value[index]?.retryCount == 0)
        }

        #expect(authenticator.applyCount == requestCount)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsMissingCredentialErrorWhenCredentialIsNil() async {
        // Given
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator)

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers.isEmpty == true)

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestAdaptationError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .missingCredential)

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorRethrowsRefreshErrorFromAdapt() async {
        // Given
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers.isEmpty == true)

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestAdaptationError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)

        if case let .requestRetryFailed(_, originalError) = response.result?.failure {
            #expect(originalError.asAFError?.isResponseValidationError == true)
            #expect(originalError.asAFError?.responseCode == 401)
        }

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    // MARK: - Tests - Retry

    // If we not using swift-corelibs-foundation where URLRequest to /invalid/path is a fatal error.
    #if !canImport(FoundationNetworking)
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorDoesNotRetryWithoutResponse() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let urlRequest = URLRequest(url: URL(string: "/invalid/path")!)
        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(urlRequest, interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a0")

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isSessionTaskError == true)

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }
    #endif

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorDoesNotRetryWhenRequestDoesNotFailDueToAuthError() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.status(500), interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a0")

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isResponseValidationError == true)
        #expect(response.result?.failure?.asAFError?.responseCode == 500)

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsMissingCredentialErrorWhenCredentialIsNilAndRequestShouldBeRetried() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.status(401), interceptor: interceptor)
            .validate {
                interceptor.credential = nil
            }
            .response {
                response.value = $0
                expect.complete()
            }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a0")

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .missingCredential)

        if case let .requestRetryFailed(_, originalError) = response.result?.failure {
            #expect(originalError.asAFError?.isResponseValidationError == true)
            #expect(originalError.asAFError?.responseCode == 401)
        }

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorRetriesRequestThatFailedWithOutdatedCredential() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

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
                response.value = $0
                expect.complete()
            }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a1")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)

        #expect(request.retryCount == 1)
    }

    // Produces double lock reported in https://github.com/Alamofire/Alamofire/issues/3294#issuecomment-703241558
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorDoesNotDeadlockWhenAuthenticatorCallsRefreshCompletionSynchronouslyOnCallingQueue() async {
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

        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let pathAdapter = PathAdapter(paths: ["/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a1")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorRetriesRequestAfterRefresh() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])

        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a1")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)

        #expect(request.retryCount == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorTriggersRetryRefreshAfterProactiveRefreshUsesStaleURL() async {
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

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a2")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 2)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)

        #expect(request.retryCount == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorRethrowsRefreshErrorFromRetry() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.status(401), interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a0")

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)

        if case let .requestRetryFailed(_, originalError) = response.result?.failure {
            #expect(originalError.asAFError?.isResponseValidationError == true)
            #expect(originalError.asAFError?.responseCode == 401)
        }

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorRethrowsRefreshErrorToAllPendingRetryRequests() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 3
        let session = stored(Session.independent())

        let expect = Completion("all requests should complete", expectedCount: requestCount)

        let requests = Capture<[Int: Request]>([:])
        let responses = Capture<[Int: AFDataResponse<Data?>]>([:])

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(401), interceptor: interceptor).validate().response {
                responses.value[index] = $0
                expect.complete()
            }
            requests.value[index] = request
        }

        await expect.wait()

        // Then
        for index in 0..<requestCount {
            #expect(responses.value[index]?.request?.headers["Authorization"] == "a0")
            #expect(responses.value[index]?.result.isFailure == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.isRequestRetryError == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)
            #expect(requests.value[index]?.retryCount == 0)
        }

        #expect(authenticator.applyCount == requestCount)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == requestCount)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == requestCount)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorAllowsNewRequestsToTriggerRefreshAfterPreviousRefreshFailure() async {
        // Given
        // A failed refresh sets .failed state on the interceptor. A subsequent, independent request
        // that also receives a 401 must be able to trigger a fresh refresh attempt; it is not a
        // late arrival from the failed batch and must not be permanently blocked by cached failure state.
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        // Phase 1 — first request triggers a refresh that fails.
        let firstExpect = Completion("first request should complete")
        let firstResponse = Capture<AFDataResponse<Data?>?>()

        let firstRequest = session.request(.status(401), interceptor: interceptor).validate().response {
            firstResponse.value = $0
            firstExpect.complete()
        }

        await firstExpect.wait()

        // Precondition: first request failed and triggered exactly one refresh.
        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)
        #expect(firstResponse.result?.isFailure == true)
        #expect(firstRequest.retryCount == 0)

        // Phase 2 — a new, independent request is made after the failed refresh has fully completed.
        let secondExpect = Completion("second request should complete")
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        let secondRequest = session.request(.status(401), interceptor: interceptor).validate().response {
            secondResponse.value = $0
            secondExpect.complete()
        }

        await secondExpect.wait()

        // Then: the new request must trigger its own fresh refresh attempt rather than
        // immediately failing with the cached error left over from the previous failed refresh.
        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 2) // Fails: .failed state blocks the new refresh, refreshCount stays at 1.
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 2)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 2)
        #expect(secondResponse.result?.isFailure == true)
        #expect(secondResponse.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(secondResponse.result?.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)
        #expect(secondRequest.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorTriggersRefreshWithMultipleParallelRequestsReturning401Responses() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)

        let requestCount = 6
        let session = stored(Session.independent())

        let expect = Completion("both requests should complete", expectedCount: requestCount)

        let requests = Capture<[Int: Request]>([:])
        let responses = Capture<[Int: AFDataResponse<Data?>]>([:])

        for index in 0..<requestCount {
            let pathAdapter = PathAdapter(paths: ["/status/401", "/status/20\(index)"])
            let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

            // When
            let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
                responses.value[index] = $0
                expect.complete()
            }

            requests.value[index] = request
        }

        await expect.wait()

        // Then
        for index in 0..<requestCount {
            let response = responses.value[index]
            #expect(response?.request?.headers["Authorization"] == "a1")
            #expect(response?.result.isSuccess == true)

            let request = requests.value[index]
            #expect(request?.retryCount == 1)
        }

        #expect(authenticator.applyCount == 12)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 6)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 6)
    }

    // MARK: - Tests - Excessive Refresh

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorIgnoresExcessiveRefreshWhenRefreshWindowIsNil() async {
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

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a5")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 6)
        #expect(authenticator.refreshCount == 5)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 5)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 5)

        #expect(request.retryCount == 5)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsExcessiveRefreshErrorWhenExcessiveRefreshOccurs() async {
        // Given
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 2))

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.status(401), interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a2")

        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)

        if case let .requestRetryFailed(_, originalError) = response.result?.failure {
            #expect(originalError.asAFError?.isResponseValidationError == true)
            #expect(originalError.asAFError?.responseCode == 401)
        }

        #expect(authenticator.applyCount == 3)
        #expect(authenticator.refreshCount == 2)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 3)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 3)

        #expect(request.retryCount == 2)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsExcessiveRefreshErrorFromAdaptPath() async {
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

        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.status(200), interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers.isEmpty == true)
        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestAdaptationError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsExcessiveRefreshErrorToAllDeferredAdaptOperationsOnReplay() async {
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
        let session = stored(Session.independent())

        let expect = Completion("all requests should complete", expectedCount: requestCount)

        let requests = Capture<[Int: Request]>([:])
        let responses = Capture<[Int: AFDataResponse<Data?>]>([:])

        // When
        for index in 0..<requestCount {
            let request = session.request(.status(200), interceptor: interceptor).validate().response {
                responses.value[index] = $0
                expect.complete()
            }
            requests.value[index] = request
        }

        await expect.wait()

        // Then
        for index in 0..<requestCount {
            #expect(responses.value[index]?.request?.headers.isEmpty == true)
            #expect(responses.value[index]?.result.isFailure == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.isRequestAdaptationError == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)
            #expect(requests.value[index]?.retryCount == 0)
        }

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)
    }

    // MARK: - Tests - Additional Coverage

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorHandlesMultipleSuccessiveRefreshCyclesCorrectly() async {
        // Given
        // Two independent 401→refresh→success cycles on the same interceptor instance. Verifies that
        // updateCredential(_:) fully resets the state machine after each successful refresh so that
        // subsequent cycles behave identically to the first.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        // When — cycle 1: request with a0 gets 401, refresh (a0 → a1), retry succeeds.
        let firstExpect = Completion("first cycle should complete")
        let firstResponse = Capture<AFDataResponse<Data?>?>()

        let firstPathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let firstCompositeInterceptor = Interceptor(adapters: [firstPathAdapter, interceptor], retriers: [interceptor])

        let firstRequest = session.request(.default, interceptor: firstCompositeInterceptor).validate().response {
            firstResponse.value = $0
            firstExpect.complete()
        }

        await firstExpect.wait()

        // Then — cycle 1
        #expect(firstResponse.request?.headers["Authorization"] == "a1")
        #expect(firstResponse.result?.isSuccess == true)
        #expect(firstRequest.retryCount == 1)
        #expect(authenticator.refreshCount == 1)

        // When — cycle 2: new request with a1 gets 401, refresh (a1 → a2), retry succeeds.
        let secondExpect = Completion("second cycle should complete")
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        let secondPathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let secondCompositeInterceptor = Interceptor(adapters: [secondPathAdapter, interceptor], retriers: [interceptor])

        let secondRequest = session.request(.default, interceptor: secondCompositeInterceptor).validate().response {
            secondResponse.value = $0
            secondExpect.complete()
        }

        await secondExpect.wait()

        // Then — cycle 2 and cumulative state
        #expect(secondResponse.request?.headers["Authorization"] == "a2")
        #expect(secondResponse.result?.isSuccess == true)
        #expect(secondRequest.retryCount == 1)

        #expect(authenticator.applyCount == 4)
        #expect(authenticator.refreshCount == 2)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 2)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 2)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorAdaptsNewRequestWithoutDeferringWhileRetryPathRefreshIsInProgress() async {
        // Given
        // When a refresh is triggered by the retry path, adaptOperations is empty. Any new adapt call must NOT be
        // deferred, it should proceed immediately with the current credential.
        // This is the documented invariant: defer only when adaptOperations is non-empty (i.e., a proactive
        // requiresRefresh-driven refresh is running).
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        let expect = Completion("both requests should complete", expectedCount: 2)

        let firstResponse = Capture<AFDataResponse<Data?>?>()
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        // When
        // Request A: gets 401, triggering an async retry-path refresh.
        let pathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

        let requestA = session.request(.default, interceptor: compositeInterceptor).validate().response {
            firstResponse.value = $0
            expect.complete()
        }

        // Request B: adapts while A's refresh may be running. Since adaptOperations is empty,
        // B must not be deferred regardless of the current refreshState.
        let requestB = session.request(.status(200), interceptor: interceptor).validate().response {
            secondResponse.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then: both succeed, only one refresh occurred, and B was applied (not deferred).
        #expect(firstResponse.result?.isSuccess == true)
        #expect(secondResponse.result?.isSuccess == true)
        #expect(secondResponse.request?.headers["Authorization"] != nil)

        #expect(requestA.retryCount == 1)
        #expect(requestB.retryCount == 0)

        #expect(authenticator.applyCount == 3)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorAllowsNewRefreshAfterExternalCredentialUpdateFollowingRetryPathFailure() async {
        // Given
        // After a retry-path refresh fails the interceptor enters .failed state, which blocks subsequent retries from
        // triggering another refresh. Setting interceptor.credential externally calls updateCredential(_:), which
        // increments credentialVersion and resets refreshState to .idle, restoring the ability to refresh.
        let credential = TestCredential()
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        // First, trigger a retry-path refresh that fails, putting interceptor into .failed state.
        let firstExpect = Completion("first request should complete")
        let firstResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(401), interceptor: interceptor).validate().response {
            firstResponse.value = $0
            firstExpect.complete()
        }

        await firstExpect.wait()

        #expect(authenticator.refreshCount == 1)
        #expect(firstResponse.result?.isFailure == true)

        // When: credential is externally replaced. updateCredential(_:) resets refreshState to .idle.
        interceptor.credential = TestCredential(accessToken: "ext")

        // Second, a new 401 should now trigger a fresh refresh rather than immediately failing with the error cached in
        // .failed state.
        let secondExpect = Completion("second request should complete")
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(401), interceptor: interceptor).validate().response {
            secondResponse.value = $0
            secondExpect.complete()
        }

        await secondExpect.wait()

        // Then: a second refresh was attempted, proving .failed was cleared by updateCredential(_:).
        // The refresh fails again (same authenticator), but crucially refreshCount is 2, not 1.
        #expect(secondResponse.request?.headers["Authorization"] == "ext")
        #expect(secondResponse.result?.isFailure == true)
        #expect(secondResponse.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(secondResponse.result?.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)

        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 2)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 2)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 2)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorAdaptsDirectlyAfterExternalCredentialUpdateFollowingProactiveRefreshFailure() async {
        // Given
        // After a proactive (requiresRefresh-triggered) refresh failure the interceptor is in .failed state with the
        // original requiresRefresh: true credential still in place. Setting interceptor.credential to a valid, non-stale
        // credential via updateCredential(_:) resets refreshState to .idle and installs the new credential so the next
        // request can adapt immediately without triggering any further refresh.
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        // First, proactive refresh fails and the deferred request gets an adaptation error.
        let firstExpect = Completion("first request should complete")
        let firstResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(200), interceptor: interceptor).validate().response {
            firstResponse.value = $0
            firstExpect.complete()
        }

        await firstExpect.wait()

        #expect(authenticator.refreshCount == 1)
        #expect(firstResponse.result?.isFailure == true)
        #expect(firstResponse.result?.failure?.asAFError?.isRequestAdaptationError == true)

        // When: a working, non-stale credential is set externally.
        interceptor.credential = TestCredential(accessToken: "ext", requiresRefresh: false)

        // Phase 2 — new request should adapt immediately with the new credential; no refresh needed.
        let secondExpect = Completion("second request should complete")
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        let secondRequest = session.request(.status(200), interceptor: interceptor).validate().response {
            secondResponse.value = $0
            secondExpect.complete()
        }

        await secondExpect.wait()

        // Then: the new request succeeds using the externally set credential, with no additional refresh.
        #expect(secondResponse.request?.headers["Authorization"] == "ext")
        #expect(secondResponse.result?.isSuccess == true)
        #expect(secondRequest.retryCount == 0)

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorDoesNotDeadlockWhenAuthenticatorCallsRefreshCompletionSynchronouslyOnRetryPath() async {
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
        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a1")
        #expect(response.result?.isSuccess == true)

        #expect(authenticator.applyCount == 2)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)

        #expect(request.retryCount == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func excessiveRefreshTimestampsArePreservedAfterFailedStateIsClearedByAdapt() async {
        // Given
        // The adapt path clears .failed to .idle to allow new requests to trigger a fresh refresh. The refreshTimestamps
        // array must survive this reset because it is the RefreshWindow's authoritative history; clearing it would
        // silently bypass the excessive-refresh guard.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 1))
        let session = stored(Session.independent())

        // First, one successful refresh consumes the entire budget (maximumAttempts: 1).
        let firstExpect = Completion("first request should complete")
        let firstResponse = Capture<AFDataResponse<Data?>?>()

        let firstPathAdapter = PathAdapter(paths: ["/status/401", "/status/200"])
        let firstCompositeInterceptor = Interceptor(adapters: [firstPathAdapter, interceptor], retriers: [interceptor])

        session.request(.default, interceptor: firstCompositeInterceptor).validate().response {
            firstResponse.value = $0
            firstExpect.complete()
        }

        await firstExpect.wait()

        #expect(firstResponse.result?.isSuccess == true)
        #expect(authenticator.refreshCount == 1)

        // Second, a 401 hits the exhausted window, producing .failed(excessiveRefresh) state.
        let secondExpect = Completion("second request should complete")
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(401), interceptor: interceptor).validate().response {
            secondResponse.value = $0
            secondExpect.complete()
        }

        await secondExpect.wait()

        #expect(secondResponse.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(secondResponse.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)

        // Third, a new request adapts, firing the adapt-clear (.failed to .idle). The request then gets a 401 and attempts
        // another refresh. Despite the state reset, refreshTimestamps is unchanged, so the excessive-refresh guard
        // fires again immediately.
        let thirdExpect = Completion("third request should complete")
        let thirdResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(401), interceptor: interceptor).validate().response {
            thirdResponse.value = $0
            thirdExpect.complete()
        }

        await thirdExpect.wait()

        // Then: It also fails with excessiveRefresh, proving the timestamp survived the adapt-clear.
        #expect(thirdResponse.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(thirdResponse.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)

        // Only one actual authenticator.refresh call ever occurred.
        // Second and third were both blocked before reaching authenticator.refresh.
        #expect(authenticator.refreshCount == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsMissingCredentialErrorWhenCredentialIsSetToNilAfterBeingValid() async {
        // Given
        // Setting interceptor.credential = nil calls updateCredential(nil), which stores nil, increments credentialVersion,
        // and resets refreshState. Subsequent requests must fail immediately with .missingCredential at the adapt stage.
        // This is distinct from the existing test that starts with no credential. Here the transition is valid to nil.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        // When
        interceptor.credential = nil

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        let request = session.request(.status(200), interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers.isEmpty == true)
        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestAdaptationError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .missingCredential)

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsExcessiveRefreshErrorImmediatelyWhenMaximumAttemptsIsZero() async {
        // Given
        // A RefreshWindow with maximumAttempts: 0 makes every refresh attempt immediately excessive: isRefreshExcessive
        // checks refreshAttemptsWithinWindow >= maximumAttempts, and 0 >= 0 is unconditionally true regardless of how
        // many (zero) refreshes have actually occurred. authenticator.refresh is therefore never reached.
        let credential = TestCredential()
        let authenticator = TestAuthenticator()
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                    credential: credential,
                                                    refreshWindow: .init(interval: 30, maximumAttempts: 0))
        let session = stored(Session.independent())

        let expect = Completion("request should complete")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        let request = session.request(.status(401), interceptor: interceptor).validate().response {
            response.value = $0
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.request?.headers["Authorization"] == "a0")
        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure?.asAFError?.isRequestRetryError == true)
        #expect(response.result?.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)

        #expect(authenticator.applyCount == 1)
        #expect(authenticator.refreshCount == 0)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 1)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 1)

        #expect(request.retryCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorThrowsExcessiveRefreshErrorToAllParallelRequestsAfterExceedingRefreshWindow() async {
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
        let session = stored(Session.independent())

        let expect = Completion("all requests should complete", expectedCount: requestCount)

        let requests = Capture<[Int: Request]>([:])
        let responses = Capture<[Int: AFDataResponse<Data?>]>([:])

        // When: Each request hits /status/401 twice: once on the initial attempt (triggering the one allowed refresh),
        // and once after retrying with a1 (triggering the excessive check).
        for index in 0..<requestCount {
            let pathAdapter = PathAdapter(paths: ["/status/401", "/status/401"])
            let compositeInterceptor = Interceptor(adapters: [pathAdapter, interceptor], retriers: [interceptor])

            let request = session.request(.default, interceptor: compositeInterceptor).validate().response {
                responses.value[index] = $0
                expect.complete()
            }
            requests.value[index] = request
        }

        await expect.wait()

        // Then
        for index in 0..<requestCount {
            #expect(responses.value[index]?.result.isFailure == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.isRequestRetryError == true)
            #expect(responses.value[index]?.result.failure?.asAFError?.underlyingError as? AuthenticationError == .excessiveRefresh)
            // retryCount is 1, each request was retried once after the first successful refresh, then rejected by the
            // excessive check without a second actual retry.
            #expect(requests.value[index]?.retryCount == 1)
        }

        // One successful refresh occurred (first batch). The second was blocked.
        #expect(authenticator.applyCount == 6)
        #expect(authenticator.refreshCount == 1)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 6)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 6)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func interceptorAllowsProactiveRefreshFromFailedStateUnlikeRetryPath() async {
        // Given
        // After a proactive refresh failure, refreshState is .failed. The retry path has an explicit .failed case that
        // returns .doNotRetryWithError immediately. The proactive adapt path has no such gate. It only checks
        // isRefreshing (which is false for .failed), so a new request with requiresRefresh: true triggers another
        // proactive refresh, overwriting .failed with .refreshing. This test verifies that asymmetry is intentional
        // and preserved.
        let credential = TestCredential(requiresRefresh: true)
        let authenticator = TestAuthenticator(refreshResult: .failure(TestAuthError.refreshNetworkFailure))
        let interceptor = AuthenticationInterceptor(authenticator: authenticator, credential: credential)
        let session = stored(Session.independent())

        // Phase 1 — proactive refresh fails, putting interceptor into .failed state.
        let firstExpect = Completion("first request should complete")
        let firstResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(200), interceptor: interceptor).validate().response {
            firstResponse.value = $0
            firstExpect.complete()
        }

        await firstExpect.wait()

        #expect(firstResponse.result?.isFailure == true)
        #expect(firstResponse.result?.failure?.asAFError?.isRequestAdaptationError == true)
        #expect(authenticator.refreshCount == 1)

        // Second, a new request with the same requiresRefresh: true credential adapts. It enters the proactive path,
        // appends to adaptOperations, calls refresh(), overwriting .failed with .refreshing. The retry path's .failed
        // gate is never reached.
        let secondExpect = Completion("second request should complete")
        let secondResponse = Capture<AFDataResponse<Data?>?>()

        session.request(.status(200), interceptor: interceptor).validate().response {
            secondResponse.value = $0
            secondExpect.complete()
        }

        await secondExpect.wait()

        // Then: a second refresh was triggered (refreshCount == 2), proving .failed did not block the proactive adapt
        // path the way it blocks the retry path.
        #expect(secondResponse.result?.isFailure == true)
        #expect(secondResponse.result?.failure?.asAFError?.isRequestAdaptationError == true)
        #expect(secondResponse.result?.failure?.asAFError?.underlyingError as? TestAuthError == .refreshNetworkFailure)

        #expect(authenticator.applyCount == 0)
        #expect(authenticator.refreshCount == 2)
        #expect(authenticator.didRequestFailDueToAuthErrorCount == 0)
        #expect(authenticator.isRequestAuthenticatedWithCredentialCount == 0)
    }
}
