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

#if !(os(Linux) || os(Windows))

import Alamofire
import Foundation
import XCTest

private enum TestCertificates {
    static let rootCA = TestCertificates.certificate(filename: "expired.badssl.com-root-ca")
    static let intermediateCA1 = TestCertificates.certificate(filename: "expired.badssl.com-intermediate-ca-1")
    static let intermediateCA2 = TestCertificates.certificate(filename: "expired.badssl.com-intermediate-ca-2")
    static let leaf = TestCertificates.certificate(filename: "expired.badssl.com-leaf")

    static func certificate(filename: String) -> SecCertificate {
        let filePath = Bundle.test.path(forResource: filename, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!

        return certificate
    }
}

// MARK: -

final class TLSEvaluationExpiredLeafCertificateTestCase: BaseTestCase {
    private let expiredURLString = "https://expired.badssl.com/"
    private let expiredHost = "expired.badssl.com"

    private let revokedURLString = "https://revoked.badssl.com"
    private let revokedHost = "revoked.badssl.com"

    private var configuration: URLSessionConfiguration!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()

        configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
    }

    // MARK: Default Behavior Tests

    func testThatExpiredCertificateRequestFailsWithNoServerTrustPolicy() {
        // Given
        let expectation = expectation(description: "\(expiredURLString)")
        let manager = Session(configuration: configuration)
        var error: AFError?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error)

        if let error = error?.underlyingError as? URLError {
            XCTAssertEqual(error.code, .serverCertificateUntrusted)
        } else {
            XCTFail("error should be a URLError or NSError from CFNetwork")
        }
    }

    func disabled_testRevokedCertificateRequestBehaviorWithNoServerTrustPolicy() {
        // Disabled due to the instability of due revocation testing of default evaluation from all platforms. This
        // test is left for debugging purposes only. Should not be committed into the test suite while enabled.

        // Given
        let expectation = expectation(description: "\(revokedURLString)")
        let manager = Session(configuration: configuration)

        var error: Error?

        // When
        manager.request(revokedURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        if #available(iOS 10.1, macOS 10.12, tvOS 10.1, *) {
            // Apple appears to have started revocation tests as part of default evaluation in 10.1
            XCTAssertNotNil(error)
        } else {
            XCTAssertNil(error)
        }
    }

    // MARK: Server Trust Policy - Perform Default Tests

    func testThatExpiredCertificateRequestFailsWithDefaultServerTrustPolicy() {
        // Given
        let evaluators = [expiredHost: DefaultTrustEvaluator(validateHost: true)]
        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: AFError?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        XCTAssertEqual(error?.isServerTrustEvaluationError, true)
        if case let .serverTrustEvaluationFailed(reason)? = error {
            if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) {
                XCTAssertTrue(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
            } else {
                XCTAssertTrue(reason.isHostValidationFailed, "should be .hostValidationFailed")
            }
        } else {
            XCTFail("error should be .serverTrustEvaluationFailed")
        }
    }

    func disabled_testRevokedCertificateRequestBehaviorWithDefaultServerTrustPolicy() {
        // Disabled due to the instability of due revocation testing of default evaluation from all platforms. This
        // test is left for debugging purposes only. Should not be committed into the test suite while enabled.

        // Given
        let defaultPolicy = DefaultTrustEvaluator()
        let evaluators = [revokedHost: defaultPolicy]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(revokedURLString)")
        var error: Error?

        // When
        manager.request(revokedURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        if #available(iOS 10.1, macOS 10.12, tvOS 10.1, *) {
            // Apple appears to have started revocation tests as part of default evaluation in 10.1
            XCTAssertNotNil(error)
        } else {
            XCTAssertNil(error)
        }
    }

    // MARK: Server Trust Policy - Perform Revoked Tests

    func testThatExpiredCertificateRequestFailsWithRevokedServerTrustPolicy() {
        // Given
        let policy = RevocationTrustEvaluator()

        let evaluators = [expiredHost: policy]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: AFError?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.isServerTrustEvaluationError, true)

        if case let .serverTrustEvaluationFailed(reason)? = error {
            if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) {
                XCTAssertTrue(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
            } else {
                XCTAssertTrue(reason.isDefaultEvaluationFailed, "should be .defaultEvaluationFailed")
            }
        } else {
            XCTFail("error should be .serverTrustEvaluationFailed")
        }
    }

    // watchOS doesn't perform revocation checking at all.
    #if !os(watchOS)
    func testThatRevokedCertificateRequestFailsWithRevokedServerTrustPolicy() {
        // Given
        let policy = RevocationTrustEvaluator()

        let evaluators = [revokedHost: policy]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(revokedURLString)")
        var error: AFError?

        // When
        manager.request(revokedURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.isServerTrustEvaluationError, true)

        if case let .serverTrustEvaluationFailed(reason)? = error {
            if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) {
                XCTAssertTrue(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
            } else {
                // Test seems flaky and can result in either of these failures, perhaps due to the OS actually checking?
                XCTAssertTrue(reason.isDefaultEvaluationFailed || reason.isRevocationCheckFailed,
                              "should be .defaultEvaluationFailed or .revocationCheckFailed")
            }
        } else {
            XCTFail("error should be .serverTrustEvaluationFailed")
        }
    }
    #endif

    // MARK: Server Trust Policy - Certificate Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafCertificateWithCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.leaf]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: AFError?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.isServerTrustEvaluationError, true)

        if case let .serverTrustEvaluationFailed(reason)? = error {
            if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) {
                XCTAssertTrue(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
            } else {
                XCTAssertTrue(reason.isDefaultEvaluationFailed, "should be .defaultEvaluationFailed")
            }
        } else {
            XCTFail("error should be .serverTrustEvaluationFailed")
        }
    }

    func testThatExpiredCertificateRequestFailsWhenPinningAllCertificatesWithCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.leaf,
                            TestCertificates.intermediateCA1,
                            TestCertificates.intermediateCA2,
                            TestCertificates.rootCA]

        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: AFError?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.isServerTrustEvaluationError, true)

        if case let .serverTrustEvaluationFailed(reason)? = error {
            if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) {
                XCTAssertTrue(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
            } else {
                XCTAssertTrue(reason.isDefaultEvaluationFailed, "should be .defaultEvaluationFailed")
            }
        } else {
            XCTFail("error should be .serverTrustEvaluationFailed")
        }
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafCertificateWithoutCertificateChainOrHostValidation() {
        // Given
        let certificates = [TestCertificates.leaf]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates, performDefaultValidation: false, validateHost: false)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCACertificateWithoutCertificateChainOrHostValidation() {
        // Given
        let certificates = [TestCertificates.intermediateCA2]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates, performDefaultValidation: false, validateHost: false)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.rootCA]
        let evaluators = [expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates, performDefaultValidation: false)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        if #available(iOS 10.1, macOS 10.12.0, tvOS 10.1, *) {
            XCTAssertNotNil(error, "error should not be nil")
        } else {
            XCTAssertNil(error, "error should be nil")
        }
    }

    // MARK: Server Trust Policy - Public Key Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafPublicKeyWithCertificateChainValidation() {
        // Given
        let keys = [TestCertificates.leaf].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: AFError?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.isServerTrustEvaluationError, true)

        if case let .serverTrustEvaluationFailed(reason)? = error {
            if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, *) {
                XCTAssertTrue(reason.isTrustEvaluationFailed, "should be .trustEvaluationFailed")
            } else {
                XCTAssertTrue(reason.isDefaultEvaluationFailed, "should be .defaultEvaluationFailed")
            }
        } else {
            XCTFail("error should be .serverTrustEvaluationFailed")
        }
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafPublicKeyWithoutCertificateChainOrHostValidation() {
        // Given
        let keys = [TestCertificates.leaf].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys, performDefaultValidation: false, validateHost: false)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCAPublicKeyWithoutCertificateChainOrHostValidation() {
        // Given
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys, performDefaultValidation: false, validateHost: false)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let keys = [TestCertificates.rootCA].af.publicKeys
        let evaluators = [expiredHost: PublicKeysTrustEvaluator(keys: keys, performDefaultValidation: false, validateHost: false)]

        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        if #available(iOS 10.1, macOS 10.12.0, tvOS 10.1, *) {
            XCTAssertNotNil(error, "error should not be nil")
        } else {
            XCTAssertNil(error, "error should be nil")
        }
    }

    // MARK: Server Trust Policy - Disabling Evaluation Tests

    func testThatExpiredCertificateRequestSucceedsWhenDisablingEvaluation() {
        // Given
        let evaluators = [expiredHost: DisabledTrustEvaluator()]
        let manager = Session(configuration: configuration,
                              serverTrustManager: ServerTrustManager(evaluators: evaluators))

        let expectation = expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(error, "error should be nil")
    }
}
#endif
