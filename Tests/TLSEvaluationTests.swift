//
//  TLSEvaluationTests.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
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

import Alamofire
import Foundation
import XCTest

private struct TestCertificates {
    static let rootCA = TestCertificates.certificate(withFileName: "expired.badssl.com-root-ca")
    static let intermediateCA1 = TestCertificates.certificate(withFileName: "expired.badssl.com-intermediate-ca-1")
    static let intermediateCA2 = TestCertificates.certificate(withFileName: "expired.badssl.com-intermediate-ca-2")
    static let leaf = TestCertificates.certificate(withFileName: "expired.badssl.com-leaf")

    static func certificate(withFileName fileName: String) -> SecCertificate {
        class Locater {}
        let filePath = Bundle(for: Locater.self).path(forResource: fileName, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!

        return certificate
    }
}

// MARK: -

private struct TestPublicKeys {
    static let rootCA = TestPublicKeys.publicKey(for: TestCertificates.rootCA)
    static let intermediateCA1 = TestPublicKeys.publicKey(for: TestCertificates.intermediateCA1)
    static let intermediateCA2 = TestPublicKeys.publicKey(for: TestCertificates.intermediateCA2)
    static let leaf = TestPublicKeys.publicKey(for: TestCertificates.leaf)

    static func publicKey(for certificate: SecCertificate) -> SecKey {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificate, policy, &trust)

        let publicKey = SecTrustCopyPublicKey(trust!)!

        return publicKey
    }
}

// MARK: -

class TLSEvaluationExpiredLeafCertificateTestCase: BaseTestCase {
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
        // On iOS 8.0 - 8.4, this test passes by itself, but fails for no explanable reason when run with the rest of
        // the suite. Because of this, there's no reliable way to run all these tests together pre iOS 9, so let's
        // disable this one when run against the entire test suite.
        guard #available(iOS 9.0, *) else { return }

        // Given
        let expectation = self.expectation(description: "\(expiredURLString)")
        let manager = SessionManager(configuration: configuration)
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .serverCertificateUntrusted)
        } else if let error = error as NSError? {
            XCTAssertEqual(error.domain, kCFErrorDomainCFNetwork as String)
            XCTAssertEqual(error.code, Int(CFNetworkErrors.cfErrorHTTPSProxyConnectionFailure.rawValue))
        } else {
            XCTFail("error should be a URLError or NSError from CFNetwork")
        }
    }

    func disabled_testRevokedCertificateRequestBehaviorWithNoServerTrustPolicy() {
        // Disabled due to the instability of due revocation testing of default evaluation from all platforms. This
        // test is left for debugging purposes only. Should not be committed into the test suite while enabled.

        // Given
        let expectation = self.expectation(description: "\(revokedURLString)")
        let manager = SessionManager(configuration: configuration)

        var error: Error?

        // When
        manager.request(revokedURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

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
        let policies = [expiredHost: ServerTrustPolicy.performDefaultEvaluation(validateHost: true)]
        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }

    func disabled_testRevokedCertificateRequestBehaviorWithDefaultServerTrustPolicy() {
        // Disabled due to the instability of due revocation testing of default evaluation from all platforms. This
        // test is left for debugging purposes only. Should not be committed into the test suite while enabled.

        // Given
        let defaultPolicy = ServerTrustPolicy.performDefaultEvaluation(validateHost: true)
        let policies = [revokedHost: defaultPolicy]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(revokedURLString)")
        var error: Error?

        // When
        manager.request(revokedURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

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
        let policy = ServerTrustPolicy.performRevokedEvaluation(
            validateHost: true,
            revocationFlags: kSecRevocationUseAnyAvailableMethod
        )

        let policies = [expiredHost: policy]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }

    func testThatRevokedCertificateRequestFailsWithRevokedServerTrustPolicy() {
        // Given
        let policy = ServerTrustPolicy.performRevokedEvaluation(
            validateHost: true,
            revocationFlags: kSecRevocationUseAnyAvailableMethod
        )

        let policies = [revokedHost: policy]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(revokedURLString)")
        var error: Error?

        // When
        manager.request(revokedURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }

    // MARK: Server Trust Policy - Certificate Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafCertificateWithCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.leaf]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }

    func testThatExpiredCertificateRequestFailsWhenPinningAllCertificatesWithCertificateChainValidation() {
        // Given
        let certificates = [
            TestCertificates.leaf,
            TestCertificates.intermediateCA1,
            TestCertificates.intermediateCA2,
            TestCertificates.rootCA
        ]

        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafCertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.leaf]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.intermediateCA2]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.rootCA]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

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
        let publicKeys = [TestPublicKeys.leaf]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: true, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.leaf]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.intermediateCA2]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.rootCA]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

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
        let policies = [expiredHost: ServerTrustPolicy.disableEvaluation]
        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Custom Evaluation Tests

    func testThatExpiredCertificateRequestSucceedsWhenCustomEvaluationReturnsTrue() {
        // Given
        let policies = [
            expiredHost: ServerTrustPolicy.customEvaluation { _, _ in
                // Implement a custom evaluation routine here...
                return true
            }
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestFailsWhenCustomEvaluationReturnsFalse() {
        // Given
        let policies = [
            expiredHost: ServerTrustPolicy.customEvaluation { _, _ in
                // Implement a custom evaluation routine here...
                return false
            }
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = self.expectation(description: "\(expiredURLString)")
        var error: Error?

        // When
        manager.request(expiredURLString)
            .response { resp in
                error = resp.error
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }
}
