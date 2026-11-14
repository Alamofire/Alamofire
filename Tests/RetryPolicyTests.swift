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
import Testing

@Suite(.storesInstances)
struct RetryPolicyTestCase {
    // MARK: Helper Types

    final class StubRequest: DataRequest, @unchecked Sendable {
        let urlRequest: URLRequest
        override var request: URLRequest? { urlRequest }

        let mockedResponse: HTTPURLResponse?
        override var response: HTTPURLResponse? { mockedResponse }

        init(_ url: URL, method: HTTPMethod, response: HTTPURLResponse?, session: Session) {
            mockedResponse = response

            let request = Session.RequestConvertible(url: url,
                                                     method: method,
                                                     parameters: nil,
                                                     encoding: URLEncoding.default,
                                                     headers: nil,
                                                     requestModifier: nil)

            urlRequest = try! request.asURLRequest()

            super.init(convertible: request,
                       underlyingQueue: session.rootQueue,
                       serializationQueue: session.serializationQueue,
                       eventMonitor: session.eventMonitor,
                       interceptor: nil,
                       shouldAutomaticallyResume: nil,
                       delegate: session)
        }
    }

    // MARK: Properties

    let idempotentMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options, .trace]
    let nonIdempotentMethods: Set<HTTPMethod> = [.post, .patch, .connect]
    var methods: Set<HTTPMethod> { idempotentMethods.union(nonIdempotentMethods) }

    let session = stored(Session.independent(startRequestsImmediately: false))

    let url = Endpoint().url

    let connectionLost = URLError(.networkConnectionLost)
    let resourceUnavailable = URLError(.resourceUnavailable)
    let unknown = URLError(.unknown)

    var connectionLostError: AFError { AFError.sessionTaskFailed(error: connectionLost) }
    var resourceUnavailableError: AFError { AFError.sessionTaskFailed(error: resourceUnavailable) }
    var unknownError: AFError { AFError.sessionTaskFailed(error: unknown) }

    let retryableStatusCodes: Set<Int> = [408, 500, 502, 503, 504]
    let statusCodes = Set(100...599)

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
        retryableErrorCodes.union(nonRetryableErrorCodes)
    }

    // MARK: Test Helpers

    func request(method: HTTPMethod = .get, statusCode: Int? = nil) -> Request {
        var response: HTTPURLResponse?

        if let statusCode {
            response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        }

        return StubRequest(url, method: method, response: response, session: session)
    }

    func urlError(with code: URLError.Code) -> URLError {
        NSError(domain: URLError.errorDomain, code: code.rawValue, userInfo: nil) as! URLError
    }

    // MARK: Tests - Retry

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryIsNotPerformedOnCancelledRequests() async {
        // Given
        let retrier = InspectorInterceptor(Retrier { _, _, _, completion in
            completion(.retry)
        })
        let session = stored(Session.independent(interceptor: retrier))
        let didFinish = Completion("didFinish request")

        // When
        let request = session.request(.default)
        request.cancel()
        request.responseDecodable(of: TestResponse.self) { _ in
            didFinish.complete()
        }

        await didFinish.wait()

        // Then
        #expect(request.isCancelled)
        #expect(retrier.retryCalledCount == 0)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyRetriesRequestsBelowRetryLimit() async {
        // Given
        let retryPolicy = RetryPolicy()
        let request = request(method: .get)

        let results = Capture<[Int: RetryResult]>([:])

        // When
        for index in 0...2 {
            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: connectionLostError) { result in
                results.write { $0[index] = result }
                expectation.complete()
            }

            await expectation.wait()

            // prepareForRetry() must be called on the request's underlying queue, the session's root queue.
            session.rootQueue.sync { request.prepareForRetry() }
        }

        // Then
        #expect(results.count == 3)

        if results.count == 3 {
            #expect(results.value[0]?.retryRequired == true)
            #expect(results.value[0]?.delay == 0.5)
            #expect(results.value[0]?.error == nil)

            #expect(results.value[1]?.retryRequired == true)
            #expect(results.value[1]?.delay == 1.0)
            #expect(results.value[1]?.error == nil)

            #expect(results.value[2]?.retryRequired == false)
            #expect(results.value[2]?.delay == nil)
            #expect(results.value[2]?.error == nil)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyRetriesIdempotentRequests() async {
        // Given
        let retryPolicy = RetryPolicy()
        let results = Capture<[HTTPMethod: RetryResult]>([:])

        // When
        for method in methods {
            let request = request(method: method)
            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: connectionLostError) { result in
                results.write { $0[method] = result }
                expectation.complete()
            }

            await expectation.wait()
        }

        // Then
        #expect(results.count == methods.count)

        for (method, result) in results.value {
            #expect(result.retryRequired == idempotentMethods.contains(method))
            #expect(result.delay == (result.retryRequired ? 0.5 : nil))
            #expect(result.error == nil)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyRetriesRequestsWithRetryableStatusCodes() async {
        // Given
        let retryPolicy = RetryPolicy()
        let results = Capture<[Int: RetryResult]>([:])

        // When
        for statusCode in statusCodes {
            let request = request(method: .get, statusCode: statusCode)
            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: unknownError) { result in
                results.write { $0[statusCode] = result }
                expectation.complete()
            }

            await expectation.wait()
        }

        // Then
        #expect(results.count == statusCodes.count)

        for (statusCode, result) in results.value {
            #expect(result.retryRequired == retryableStatusCodes.contains(statusCode))
            #expect(result.delay == (result.retryRequired ? 0.5 : nil))
            #expect(result.error == nil)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyRetriesRequestsWithRetryableErrors() async {
        // Given
        let retryPolicy = RetryPolicy()
        let results = Capture<[URLError.Code: RetryResult]>([:])

        // When
        for code in errorCodes {
            let request = request(method: .get)
            let error = URLError(code)

            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: error) { result in
                results.write { $0[code] = result }
                expectation.complete()
            }

            await expectation.wait()
        }

        // Then
        #expect(results.count == errorCodes.count)

        for (urlErrorCode, result) in results.value {
            #expect(result.retryRequired == retryableErrorCodes.contains(urlErrorCode))
            #expect(result.delay == (result.retryRequired ? 0.5 : nil))
            #expect(result.error == nil)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyRetriesRequestsWithRetryableAFErrors() async {
        // Given
        let retryPolicy = RetryPolicy()
        let results = Capture<[URLError.Code: RetryResult]>([:])

        // When
        for code in errorCodes {
            let request = request(method: .get)
            let error = AFError.sessionTaskFailed(error: URLError(code))

            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: error) { result in
                results.write { $0[code] = result }
                expectation.complete()
            }

            await expectation.wait()
        }

        // Then
        #expect(results.count == errorCodes.count)

        for (urlErrorCode, result) in results.value {
            #expect(result.retryRequired == retryableErrorCodes.contains(urlErrorCode))
            #expect(result.delay == (result.retryRequired ? 0.5 : nil))
            #expect(result.error == nil)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyDoesNotRetryErrorsThatAreNotRetryable() async {
        // Given
        let retryPolicy = RetryPolicy()
        let request = request(method: .get)

        let errors: [any Error] = [resourceUnavailable,
                                   unknown,
                                   resourceUnavailableError,
                                   unknownError]

        let results = Capture<[RetryResult]>([])

        // When
        for error in errors {
            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: error) { result in
                results.write { $0.append(result) }
                expectation.complete()
            }

            await expectation.wait()
        }

        // Then
        #expect(results.count == errors.count)

        for result in results.value {
            #expect(!result.retryRequired)
            #expect(result.delay == nil)
            #expect(result.error == nil)
        }
    }

    // MARK: Tests - Exponential Backoff

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retryPolicyTimeDelayBacksOffExponentially() async {
        // Given
        let retryPolicy = RetryPolicy(retryLimit: 4)
        let request = request(method: .get)

        let results = Capture<[Int: RetryResult]>([:])

        // When
        for index in 0...4 {
            let expectation = Completion("retry policy should complete")

            retryPolicy.retry(request, for: session, dueTo: connectionLostError) { result in
                results.write { $0[index] = result }
                expectation.complete()
            }

            await expectation.wait()

            // prepareForRetry() must be called on the request's underlying queue, the session's root queue.
            session.rootQueue.sync { request.prepareForRetry() }
        }

        // Then
        #expect(results.count == 5)

        if results.count == 5 {
            #expect(results.value[0]?.retryRequired == true)
            #expect(results.value[0]?.delay == 0.5)
            #expect(results.value[0]?.error == nil)

            #expect(results.value[1]?.retryRequired == true)
            #expect(results.value[1]?.delay == 1.0)
            #expect(results.value[1]?.error == nil)

            #expect(results.value[2]?.retryRequired == true)
            #expect(results.value[2]?.delay == 2.0)
            #expect(results.value[2]?.error == nil)

            #expect(results.value[3]?.retryRequired == true)
            #expect(results.value[3]?.delay == 4.0)
            #expect(results.value[3]?.error == nil)

            #expect(results.value[4]?.retryRequired == false)
            #expect(results.value[4]?.delay == nil)
            #expect(results.value[4]?.error == nil)
        }
    }
}

// MARK: -

@Suite
struct ConnectionLostRetryPolicyTestCase {
    private let idempotentMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options, .trace]

    @Test
    func connectionLostRetryPolicyCanBeInitializedWithDefaultValues() {
        // Given, When
        let retryPolicy = ConnectionLostRetryPolicy()

        // Then
        #expect(retryPolicy.retryLimit == 2)
        #expect(retryPolicy.exponentialBackoffBase == 2)
        #expect(retryPolicy.exponentialBackoffScale == 0.5)
        #expect(retryPolicy.retryableHTTPMethods == idempotentMethods)
        #expect(retryPolicy.retryableHTTPStatusCodes == [])
        #expect(retryPolicy.retryableURLErrorCodes == [.networkConnectionLost])
    }

    @Test
    func connectionLostRetryPolicyCanBeInitializedWithCustomValues() {
        // Given, When
        let retryPolicy = ConnectionLostRetryPolicy(retryLimit: 3,
                                                    exponentialBackoffBase: 4,
                                                    exponentialBackoffScale: 0.25,
                                                    retryableHTTPMethods: [.delete, .get])

        // Then
        #expect(retryPolicy.retryLimit == 3)
        #expect(retryPolicy.exponentialBackoffBase == 4)
        #expect(retryPolicy.exponentialBackoffScale == 0.25)
        #expect(retryPolicy.retryableHTTPMethods == [.delete, .get])
        #expect(retryPolicy.retryableHTTPStatusCodes == [])
        #expect(retryPolicy.retryableURLErrorCodes == [.networkConnectionLost])
    }
}
