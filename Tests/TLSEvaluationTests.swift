// DownloadTests.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Alamofire
import Foundation
import XCTest

private struct TestCertificates {
    static let RootCA = TestCertificates.certificateWithFileName("root-ca-disig")
    static let IntermedateCA = TestCertificates.certificateWithFileName("intermediate-ca-disig")
    static let Leaf = TestCertificates.certificateWithFileName("testssl-expire.disig.sk")

    static func certificateWithFileName(fileName: String) -> SecCertificate {
        class Bundle {}
        let filePath = NSBundle(forClass: Bundle.self).pathForResource(fileName, ofType: "cer")!
        let data = NSData(contentsOfFile: filePath)!
        let certificate = SecCertificateCreateWithData(nil, data).takeRetainedValue()

        return certificate
    }
}

// MARK: -

private struct TestPublicKeys {
    static let RootCA = TestPublicKeys.publicKeyForCertificate(TestCertificates.RootCA)
    static let IntermediateCA = TestPublicKeys.publicKeyForCertificate(TestCertificates.IntermedateCA)
    static let Leaf = TestPublicKeys.publicKeyForCertificate(TestCertificates.Leaf)

    static func publicKeyForCertificate(certificate: SecCertificate) -> SecKey {
        let policy = SecPolicyCreateBasicX509().takeRetainedValue()
        var unmanagedTrust: Unmanaged<SecTrust>?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &unmanagedTrust)

        let trust = unmanagedTrust!.takeRetainedValue()
        let publicKey = SecTrustCopyPublicKey(trust).takeRetainedValue()

        return publicKey
    }
}

// MARK: -

class TLSEvaluationExpiredLeafCertificateTestCase: BaseTestCase {
    let URL = "https://testssl-expire.disig.sk/"
    let host = "testssl-expire.disig.sk"
    var configuration: NSURLSessionConfiguration!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        self.configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
    }

    // MARK: Default Behavior Tests

    func testThatExpiredCertificateRequestFailsWithNoServerTrustPolicy() {
        // Given
        let expectation = expectationWithDescription("\(self.URL)")
        let manager = Manager(configuration: self.configuration)
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.code ?? -1, NSURLErrorServerCertificateUntrusted, "error should be NSURLErrorServerCertificateUntrusted")
    }

    // MARK: Server Trust Policy - Perform Default Tests

    func testThatExpiredCertificateRequestFailsWithDefaultServerTrustPolicy() {
        // Given
        let policies = [self.host: ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)]
        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.code ?? -1, NSURLErrorCancelled, "error should be NSURLErrorCancelled")
    }

    // MARK: Server Trust Policy - Certificate Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafCertificate() {
        // Given
        let certificates = [TestCertificates.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            self.host: .PinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.code ?? -1, NSURLErrorCancelled, "error should be NSURLErrorCancelled")
    }

    func testThatExpiredCertificateRequestFailsWhenPinningAllCertificates() {
        // Given
        let certificates = [TestCertificates.Leaf, TestCertificates.IntermedateCA, TestCertificates.RootCA]
        let policies: [String: ServerTrustPolicy] = [
            self.host: .PinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.code ?? -1, NSURLErrorCancelled, "error should be NSURLErrorCancelled")
    }

    // MARK: Server Trust Policy - Public Key Pinning Tests

    func testThatExpiredCertificateRequestFailsWhenPinningLeafPublicKeyWithCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            self.host: .PinPublicKeys(publicKeys: publicKeys, validateCertificateChain: true, validateHost: true)
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.code ?? -1, NSURLErrorCancelled, "error should be NSURLErrorCancelled")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningLeafPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.Leaf]
        let policies: [String: ServerTrustPolicy] = [
            self.host: .PinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningIntermediateCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.IntermediateCA]
        let policies: [String: ServerTrustPolicy] = [
            self.host: .PinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestSucceedsWhenPinningRootCAPublicKeyWithoutCertificateChainValidation() {
        // Given
        let publicKeys = [TestPublicKeys.RootCA]
        let policies: [String: ServerTrustPolicy] = [
            self.host: .PinPublicKeys(publicKeys: publicKeys, validateCertificateChain: false, validateHost: true)
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Disabling Evaluation Tests

    func testThatExpiredCertificateRequestSucceedsWhenDisablingEvaluation() {
        // Given
        let policies = [self.host: ServerTrustPolicy.DisableEvaluation]
        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    // MARK: Server Trust Policy - Custom Evaluation Tests

    func testThatExpiredCertificateRequestSucceedsWhenCustomEvaluationReturnsTrue() {
        // Given
        let policies = [
            self.host: ServerTrustPolicy.CustomEvaluation { _, _ in
                // Implement a custom evaluation routine here...
                return true
            }
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testThatExpiredCertificateRequestFailsWhenCustomEvaluationReturnsFalse() {
        // Given
        let policies = [
            self.host: ServerTrustPolicy.CustomEvaluation { _, _ in
                // Implement a custom evaluation routine here...
                return false
            }
        ]

        let manager = Manager(
            configuration: self.configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )

        let expectation = expectationWithDescription("\(self.URL)")
        var error: NSError?

        // When
        manager.request(.GET, self.URL)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertEqual(error?.code ?? -1, NSURLErrorCancelled, "error should be NSURLErrorCancelled")
    }
}
