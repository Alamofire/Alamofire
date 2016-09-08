//
//  TLSEvaluationTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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
    let urlString = "https://expired.badssl.com/"
    let host = "expired.badssl.com"
    var configuration: URLSessionConfiguration!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        configuration = URLSessionConfiguration.ephemeral
    }

    // MARK: Default Behavior Tests

    func testThatExpiredCertificateRequestFailsWithNoServerTrustPolicy() {
        // Given
        weak var expectation = self.expectation(description: "\(urlString)")
        let manager = SessionManager(configuration: configuration)
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? URLError {
            XCTAssertEqual(error.code, .serverCertificateUntrusted)
        } else if let error = error as? NSError {
            XCTAssertEqual(error.domain, kCFErrorDomainCFNetwork as String)
            XCTAssertEqual(error.code, Int(CFNetworkErrors.cfErrorHTTPSProxyConnectionFailure.rawValue))
        } else {
            XCTFail("error should be a URLError or NSError from CFNetwork")
        }
    }

    // MARK: Server Trust Policy - Perform Default Tests

    func testThatExpiredCertificateRequestFailsWithDefaultServerTrustPolicy() {
        // Given
        let policies = [host: ServerTrustPolicy.performDefaultEvaluation(validateHost: true)]
        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
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
            host: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
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
            host: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
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
            host: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.intermediateCA2]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.rootCA]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Public Key Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafPublicKeyWithCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.leaf]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: true, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
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
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.intermediateCA2]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.rootCA]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Disabling Evaluation Tests

    func testThatExpiredCertificateRequestSucceedsWhenDisablingEvaluation() {
        // Given
        let policies = [host: ServerTrustPolicy.disableEvaluation]
        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Custom Evaluation Tests

    func testThatExpiredCertificateRequestSucceedsWhenCustomEvaluationReturnsTrue() {
        // Given
        let policies = [
            host: ServerTrustPolicy.customEvaluation { _, _ in
                // Implement a custom evaluation routine here...
                return true
            }
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestFailsWhenCustomEvaluationReturnsFalse() {
        // Given
        let policies = [
            host: ServerTrustPolicy.customEvaluation { _, _ in
                // Implement a custom evaluation routine here...
                return false
            }
        ]

        let manager = SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(urlString)")
        var error: Error?

        // When
        manager.request(urlString)
            .response { resp in
                error = resp.error
                expectation?.fulfill()
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
