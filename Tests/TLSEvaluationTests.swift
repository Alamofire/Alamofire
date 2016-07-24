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
    static let RootCA = TestCertificates.certificateWithFileName("expired.badssl.com-root-ca")
    static let IntermediateCA1 = TestCertificates.certificateWithFileName("expired.badssl.com-intermediate-ca-1")
    static let IntermediateCA2 = TestCertificates.certificateWithFileName("expired.badssl.com-intermediate-ca-2")
    static let Leaf = TestCertificates.certificateWithFileName("expired.badssl.com-leaf")

    static func certificateWithFileName(_ fileName: String) -> SecCertificate {
        class Bundle {}
        let filePath = Foundation.Bundle(for: Bundle.self).pathForResource(fileName, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data)!

        return certificate
    }
}

// MARK: -

private struct TestPublicKeys {
    static let RootCA = TestPublicKeys.publicKeyForCertificate(TestCertificates.RootCA)
    static let IntermediateCA1 = TestPublicKeys.publicKeyForCertificate(TestCertificates.IntermediateCA1)
    static let IntermediateCA2 = TestPublicKeys.publicKeyForCertificate(TestCertificates.IntermediateCA2)
    static let Leaf = TestPublicKeys.publicKeyForCertificate(TestCertificates.Leaf)

    static func publicKeyForCertificate(_ certificate: SecCertificate) -> SecKey {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificate, policy, &trust)

        let publicKey = SecTrustCopyPublicKey(trust!)!

        return publicKey
    }
}

// MARK: -

class TLSEvaluationExpiredLeafCertificateTestCase: BaseTestCase {
    let URL = "https://expired.badssl.com/"
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
        weak var expectation = self.expectation(description: "\(URL)")
        let manager = Manager(configuration: configuration)
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let code = error?.code {
            XCTAssertEqual(code, NSURLErrorServerCertificateUntrusted, "code should be untrusted server certficate")
        } else {
            XCTFail("error should be an NSError")
        }
    }

    // MARK: Server Trust Policy - Perform Default Tests

    func testThatExpiredCertificateRequestFailsWithDefaultServerTrustPolicy() {
        // Given
        let policies = [host: ServerTrustPolicy.performDefaultEvaluation(validateHost: true)]
        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let code = error?.code {
            XCTAssertEqual(code, NSURLErrorCancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an NSError")
        }
    }

    // MARK: Server Trust Policy - Certificate Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafCertificateWithCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let code = error?.code {
            XCTAssertEqual(code, NSURLErrorCancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an NSError")
        }
    }

    func testThatExpiredCertificateRequestFailsWhenPinningAllCertificatesWithCertificateChainValidation() {
        // Given
        let certificates = [
            TestCertificates.Leaf,
            TestCertificates.IntermediateCA1,
            TestCertificates.IntermediateCA2,
            TestCertificates.RootCA
        ]

        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let code = error?.code {
            XCTAssertEqual(code, NSURLErrorCancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an NSError")
        }
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafCertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.IntermediateCA2]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCACertificateWithoutCertificateChainValidation() {
        // Given
        let certificates = [TestCertificates.RootCA]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Public Key Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafPublicKeyWithCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: true, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let code = error?.code {
            XCTAssertEqual(code, NSURLErrorCancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an NSError")
        }
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.IntermediateCA2]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.RootCA]
        let policies: [String: ServerTrustPolicy] = [
            host: .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
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
        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
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

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
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

        let manager = Manager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        weak var expectation = self.expectation(description: "\(URL)")
        var error: NSError?

        // When
        manager.request(.GET, URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation?.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let code = error?.code {
            XCTAssertEqual(code, NSURLErrorCancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an NSError")
        }
    }
}
