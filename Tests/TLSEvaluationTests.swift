//
//  TLSEvaluationTests.swift
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

#if canImport(Security)

import Alamofire
import Foundation
@preconcurrency import Security
import Testing

private enum TestCertificates {
    static let rootCA = TestCertificates.certificate(filename: "expired.badssl.com-root-ca")
    static let intermediateCA1 = TestCertificates.certificate(filename: "expired.badssl.com-intermediate-ca-1")
    static let intermediateCA2 = TestCertificates.certificate(filename: "expired.badssl.com-intermediate-ca-2")
    static let leaf = TestCertificates.certificate(filename: "expired.badssl.com-leaf")

    static func certificate(filename: String) -> SecCertificate {
        let filePath = Bundle.test.path(forResource: filename, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        return SecCertificateCreateWithData(nil, data as CFData)!
    }
}

// MARK: -

@Suite(.storesInstances, .serialized)
struct TLSEvaluationExpiredLeafCertificateTestCase {
    private let expiredURLString = "https://expired.badssl.com/"
    private let expiredHost = "expired.badssl.com"

    private let revokedURLString = "https://revoked.badssl.com"
    private let revokedHost = "revoked.badssl.com"

    /// Replaces `setUp()`.
    private let configuration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        // badssl.com sometimes stalls a connection. Time out quickly so the request can be retried.
        configuration.timeoutIntervalForRequest = 5

        return configuration
    }()

    // MARK: Default Behavior Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestFailsWithNoServerTrustPolicy() async {
        // Given
        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let manager = stored(Session.independent(configuration: configuration, interceptor: DroppedConnectionRetrier()))
        let error = Capture<AFError?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil)

        if let error = error.underlyingError as? URLError {
            #expect(error.code == .serverCertificateUntrusted)
        } else {
            Issue.record("error should be a URLError or NSError from CFNetwork")
        }
    }

    @Test(.disabled("Revocation behavior of default evaluation is unstable across platforms; left for debugging only."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func revokedCertificateRequestBehaviorWithNoServerTrustPolicy() async {
        // Disabled due to the instability of due revocation testing of default evaluation from all platforms. This
        // test is left for debugging purposes only. Should not be committed into the test suite while enabled.

        // Given
        let expectation = Completion("\(revokedURLString)", timeout: .retriedRequest)
        let manager = stored(Session.independent(configuration: configuration, interceptor: DroppedConnectionRetrier()))

        let error = Capture<(any Error)?>()

        // When
        manager.request(revokedURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
            // Apple appears to have started revocation tests as part of default evaluation in 10.1
            #expect(error.value != nil)
    }

    // MARK: Server Trust Policy - Perform Default Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestFailsWithDefaultServerTrustPolicy() async {
        // Given
        let evaluators = [expiredHost: DefaultTrustEvaluator(validateHost: true)]
        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<AFError?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")

        #expect(error.isServerTrustEvaluationError == true)
        if case let .serverTrustEvaluationFailed(reason)? = error.value {
            #expect(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
        } else {
            Issue.record("error should be .serverTrustEvaluationFailed")
        }
    }

    @Test(.disabled("Revocation behavior of default evaluation is unstable across platforms; left for debugging only."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func revokedCertificateRequestBehaviorWithDefaultServerTrustPolicy() async {
        // Disabled due to the instability of due revocation testing of default evaluation from all platforms. This
        // test is left for debugging purposes only. Should not be committed into the test suite while enabled.

        // Given
        let defaultPolicy = DefaultTrustEvaluator()
        let evaluators = [revokedHost: defaultPolicy]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(revokedURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(revokedURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
            // Apple appears to have started revocation tests as part of default evaluation in 10.1
            #expect(error.value != nil)
    }

    // MARK: Server Trust Policy - Perform Revoked Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestFailsWithRevokedServerTrustPolicy() async {
        // Given
        let policy = RevocationTrustEvaluator()

        let evaluators = [expiredHost: policy]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<AFError?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
        #expect(error.isServerTrustEvaluationError == true)

        if case let .serverTrustEvaluationFailed(reason)? = error.value {
            #expect(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
        } else {
            Issue.record("error should be .serverTrustEvaluationFailed")
        }
    }

    // watchOS doesn't perform revocation checking at all.
    #if !os(watchOS)
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func revokedCertificateRequestFailsWithRevokedServerTrustPolicy() async {
        // Given
        let policy = RevocationTrustEvaluator(options: [.requirePositiveResponse, .any])

        let evaluators = [revokedHost: policy]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(revokedURLString)", timeout: .retriedRequest)
        let error = Capture<AFError?>()

        // When
        manager.request(revokedURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
        #expect(error.isServerTrustEvaluationError == true)

        if case let .serverTrustEvaluationFailed(reason)? = error.value {
            #expect(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
        } else {
            Issue.record("error should be .serverTrustEvaluationFailed")
        }
    }
    #endif

    // MARK: Server Trust Policy - Certificate Pinning Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestFailsWhenPinningLeafCertificateWithCertificateChainValidation() async {
        // Given
        let certificates = [TestCertificates.leaf]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<AFError?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
        #expect(error.isServerTrustEvaluationError == true)

        if case let .serverTrustEvaluationFailed(reason)? = error.value {
            #expect(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
        } else {
            Issue.record("error should be .serverTrustEvaluationFailed")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestFailsWhenPinningAllCertificatesWithCertificateChainValidation() async {
        // Given
        let certificates = [TestCertificates.leaf,
                            TestCertificates.intermediateCA1,
                            TestCertificates.intermediateCA2,
                            TestCertificates.rootCA]

        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<AFError?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
        #expect(error.isServerTrustEvaluationError == true)

        if case let .serverTrustEvaluationFailed(reason)? = error.value {
            #expect(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
        } else {
            Issue.record("error should be .serverTrustEvaluationFailed")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenPinningLeafCertificateWithoutCertificateChainOrHostValidation() async {
        // Given
        let certificates = [TestCertificates.leaf]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates, performDefaultValidation: false, validateHost: false)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value == nil, "error should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenPinningIntermediateCACertificateWithoutCertificateChainOrHostValidation() async {
        // Given
        let certificates = [TestCertificates.intermediateCA2]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates, performDefaultValidation: false, validateHost: false)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value == nil, "error should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenPinningRootCACertificateWithoutCertificateChainValidation() async {
        // Given
        let certificates = [TestCertificates.rootCA]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates, performDefaultValidation: false)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
    }

    // MARK: Server Trust Policy - Public Key Pinning Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestFailsWhenPinningLeafPublicKeyWithCertificateChainValidation() async {
        // Given
        let keys = [TestCertificates.leaf].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<AFError?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
        #expect(error.isServerTrustEvaluationError == true)

        if case let .serverTrustEvaluationFailed(reason)? = error.value {
            #expect(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
        } else {
            Issue.record("error should be .serverTrustEvaluationFailed")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenPinningLeafPublicKeyWithoutCertificateChainOrHostValidation() async {
        // Given
        let keys = [TestCertificates.leaf].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys, performDefaultValidation: false, validateHost: false)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value == nil, "error should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenPinningIntermediateCAPublicKeyWithoutCertificateChainOrHostValidation() async {
        // Given
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys, performDefaultValidation: false, validateHost: false)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value == nil, "error should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenPinningRootCAPublicKeyWithoutCertificateChainValidation() async {
        // Given
        let keys = [TestCertificates.rootCA].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys, performDefaultValidation: false, validateHost: false)]

        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
    }

    // MARK: Server Trust Policy - Disabling Evaluation Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func expiredCertificateRequestSucceedsWhenDisablingEvaluation() async {
        // Given
        let evaluators = [expiredHost: DisabledTrustEvaluator()]
        let manager = stored(Session.independent(configuration: configuration,
                                                 interceptor: DroppedConnectionRetrier(),
                                                 serverTrustManager: ServerTrustManager(evaluators: evaluators)))

        let expectation = Completion("\(expiredURLString)", timeout: .retriedRequest)
        let error = Capture<(any Error)?>()

        // When
        manager.request(expiredURLString)
            .response { resp in
                error.value = resp.error
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(error.value == nil, "error should be nil")
    }
}

/// Retries requests whose connection badssl.com drops during the TLS handshake or stalls, which it does to a few percent
/// of CI requests.
///
/// A dropped handshake fails with `secureConnectionFailed` and an underlying `errSSLClosedNoNotify` (`-9816`), and a
/// stalled one with `timedOut`. Neither says anything about the behavior under test: evaluator failures are
/// `serverTrustEvaluationFailed`, and default evaluation of an untrusted certificate is `serverCertificateUntrusted`.
struct DroppedConnectionRetrier: RequestInterceptor {
    var maximumRetries = 5

    func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping @Sendable (RetryResult) -> Void) {
        guard request.retryCount < maximumRetries, Self.isDroppedConnection(error) else {
            completion(.doNotRetry)
            return
        }

        // badssl.com drops connections in bursts that can last tens of seconds, so back off until one ends.
        completion(.retryWithDelay(pow(2, TimeInterval(request.retryCount))))
    }

    static func isDroppedConnection(_ error: any Error) -> Bool {
        guard let error = (error.asAFError?.underlyingError ?? error) as NSError?, error.domain == NSURLErrorDomain else {
            return false
        }

        switch URLError.Code(rawValue: error.code) {
        case .timedOut:
            return true
        case .secureConnectionFailed:
            return error.userInfo["_kCFStreamErrorCodeKey"] as? Int == -9816
        default:
            return false
        }
    }
}

@Suite(.storesInstances)
struct DroppedConnectionRetrierTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func handshakeDropIsRetried() async {
        let result = await retryResult(for: URLError(.secureConnectionFailed, userInfo: ["_kCFStreamErrorCodeKey": -9816]))

        #expect(result == .retryWithDelay(1))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func stalledConnectionIsRetried() async {
        let result = await retryResult(for: URLError(.timedOut))

        #expect(result == .retryWithDelay(1))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func otherTLSFailuresAreNotRetried() async {
        let untrusted = await retryResult(for: URLError(.serverCertificateUntrusted))
        let otherSecureConnectionFailure = await retryResult(for: URLError(.secureConnectionFailed, userInfo: ["_kCFStreamErrorCodeKey": -9806]))

        #expect(untrusted == .doNotRetry)
        #expect(otherSecureConnectionFailure == .doNotRetry)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func handshakeDropIsNotRetriedPastTheMaximum() async {
        let result = await retryResult(for: URLError(.secureConnectionFailed, userInfo: ["_kCFStreamErrorCodeKey": -9816]),
                                       retrier: DroppedConnectionRetrier(maximumRetries: 0))

        #expect(result == .doNotRetry)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func retryResult(for error: URLError, retrier: DroppedConnectionRetrier = DroppedConnectionRetrier()) async -> RetryResult {
        let session = stored(Session.independent(startRequestsImmediately: false))
        let request = session.request(Endpoint())

        return await withCheckedContinuation { continuation in
            retrier.retry(request, for: session, dueTo: AFError.sessionTaskFailed(error: error)) { continuation.resume(returning: $0) }
        }
    }
}

extension TimeInterval {
    /// Long enough for a request that times out every time it's tried, plus the delays between retries.
    fileprivate static let retriedRequest: TimeInterval = 75
}

#endif
