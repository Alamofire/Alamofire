// MultipartFormDataTests.swift
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
    // Root Certificates
    static let RootCA = TestCertificates.certificateWithFileName("alamofire-root-ca")

    // Intermediate Certificates
    static let IntermediateCA1 = TestCertificates.certificateWithFileName("alamofire-signing-ca1")
    static let IntermediateCA2 = TestCertificates.certificateWithFileName("alamofire-signing-ca2")

    // Leaf Certificates - Signed by CA1
    static let LeafWildcard = TestCertificates.certificateWithFileName("*.alamofire.org")
    static let LeafMultipleDNSNames = TestCertificates.certificateWithFileName("multiple-dns-names")
    static let LeafSignedByCA1 = TestCertificates.certificateWithFileName("signed-by-ca1")
    static let LeafDNSNameAndURI = TestCertificates.certificateWithFileName("test.alamofire.org")

    // Leaf Certificates - Signed by CA2
    static let LeafExpired = TestCertificates.certificateWithFileName("expired")
    static let LeafMissingDNSNameAndURI = TestCertificates.certificateWithFileName("missing-dns-name-and-uri")
    static let LeafSignedByCA2 = TestCertificates.certificateWithFileName("signed-by-ca2")
    static let LeafValidDNSName = TestCertificates.certificateWithFileName("valid-dns-name")
    static let LeafValidURI = TestCertificates.certificateWithFileName("valid-uri")

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
    // Root Public Keys
    static let RootCA = TestPublicKeys.publicKeyForCertificate(TestCertificates.RootCA)

    // Intermediate Public Keys
    static let IntermediateCA1 = TestPublicKeys.publicKeyForCertificate(TestCertificates.IntermediateCA1)
    static let IntermediateCA2 = TestPublicKeys.publicKeyForCertificate(TestCertificates.IntermediateCA2)

    // Leaf Public Keys - Signed by CA1
    static let LeafWildcard = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafWildcard)
    static let LeafMultipleDNSNames = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafMultipleDNSNames)
    static let LeafSignedByCA1 = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafSignedByCA1)
    static let LeafDNSNameAndURI = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafDNSNameAndURI)

    // Leaf Public Keys - Signed by CA2
    static let LeafExpired = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafExpired)
    static let LeafMissingDNSNameAndURI = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafMissingDNSNameAndURI)
    static let LeafSignedByCA2 = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafSignedByCA2)
    static let LeafValidDNSName = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafValidDNSName)
    static let LeafValidURI = TestPublicKeys.publicKeyForCertificate(TestCertificates.LeafValidURI)

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

private enum TestTrusts {
    // Leaf Trusts - Signed by CA1
    case LeafWildcard
    case LeafMultipleDNSNames
    case LeafSignedByCA1
    case LeafDNSNameAndURI

    // Leaf Trusts - Signed by CA2
    case LeafExpired
    case LeafMissingDNSNameAndURI
    case LeafSignedByCA2
    case LeafValidDNSName
    case LeafValidURI

    // Invalid Trusts
    case LeafValidDNSNameMissingIntermediate
    case LeafValidDNSNameWithIncorrectIntermediate

    var trust: SecTrust {
        let trust: SecTrust

        switch self {
        case .LeafWildcard:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafWildcard,
                TestCertificates.IntermediateCA1,
                TestCertificates.RootCA
            ])
        case .LeafMultipleDNSNames:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafMultipleDNSNames,
                TestCertificates.IntermediateCA1,
                TestCertificates.RootCA
            ])
        case .LeafSignedByCA1:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafSignedByCA1,
                TestCertificates.IntermediateCA1,
                TestCertificates.RootCA
            ])
        case .LeafDNSNameAndURI:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafDNSNameAndURI,
                TestCertificates.IntermediateCA1,
                TestCertificates.RootCA
            ])
        case .LeafExpired:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafExpired,
                TestCertificates.IntermediateCA2,
                TestCertificates.RootCA
            ])
        case .LeafMissingDNSNameAndURI:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafMissingDNSNameAndURI,
                TestCertificates.IntermediateCA2,
                TestCertificates.RootCA
            ])
        case .LeafSignedByCA2:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafSignedByCA2,
                TestCertificates.IntermediateCA2,
                TestCertificates.RootCA
            ])
        case .LeafValidDNSName:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafValidDNSName,
                TestCertificates.IntermediateCA2,
                TestCertificates.RootCA
            ])
        case .LeafValidURI:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafValidURI,
                TestCertificates.IntermediateCA2,
                TestCertificates.RootCA
            ])
        case LeafValidDNSNameMissingIntermediate:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafValidDNSName,
                TestCertificates.RootCA
            ])
        case LeafValidDNSNameWithIncorrectIntermediate:
            trust = TestTrusts.trustWithCertificates([
                TestCertificates.LeafValidDNSName,
                TestCertificates.IntermediateCA1,
                TestCertificates.RootCA
            ])
        }

        return trust
    }

    static func trustWithCertificates(certificates: [SecCertificate]) -> SecTrust {
        let policy = SecPolicyCreateBasicX509().takeRetainedValue()
        var unmanagedTrust: Unmanaged<SecTrust>?
        SecTrustCreateWithCertificates(certificates, policy, &unmanagedTrust)
        let trust = unmanagedTrust!.takeRetainedValue()

        return trust
    }
}

// MARK: - Basic X509 and SSL Exploration Tests -

class ServerTrustPolicyTestCase: BaseTestCase {
    func setRootCertificateAsLoneAnchorCertificateForTrust(trust: SecTrust) {
        SecTrustSetAnchorCertificates(trust, [TestCertificates.RootCA])
        SecTrustSetAnchorCertificatesOnly(trust, 1)
    }

    func trustIsValid(trust: SecTrust) -> Bool {
        var isValid = false

        var result = SecTrustResultType(kSecTrustResultInvalid)
        let status = SecTrustEvaluate(trust, &result)

        if status == errSecSuccess {
            let unspecified = SecTrustResultType(kSecTrustResultUnspecified)
            let proceed = SecTrustResultType(kSecTrustResultProceed)

            isValid = result == unspecified || result == proceed
        }

        return isValid
    }
}

// MARK: -

class ServerTrustPolicyExplorationBasicX509PolicyValidationTestCase: ServerTrustPolicyTestCase {
    func testThatAnchoredRootCertificatePassesBasicX509ValidationWithRootInTrust() {
        // Given
        let trust = TestTrusts.trustWithCertificates([
            TestCertificates.LeafDNSNameAndURI,
            TestCertificates.IntermediateCA1,
            TestCertificates.RootCA
        ])

        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509().takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatAnchoredRootCertificatePassesBasicX509ValidationWithoutRootInTrust() {
        // Given
        let trust = TestTrusts.LeafDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509().takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatCertificateMissingDNSNamePassesBasicX509Validation() {
        // Given
        let trust = TestTrusts.LeafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509().takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatExpiredCertificateFailsBasicX509Validation() {
        // Given
        let trust = TestTrusts.LeafExpired.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509().takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertFalse(trustIsValid(trust), "trust should not be valid")
    }
}

// MARK: -

class ServerTrustPolicyExplorationSSLPolicyValidationTestCase: ServerTrustPolicyTestCase {
    func testThatAnchoredRootCertificatePassesSSLValidationWithRootInTrust() {
        // Given
        let trust = TestTrusts.trustWithCertificates([
            TestCertificates.LeafDNSNameAndURI,
            TestCertificates.IntermediateCA1,
            TestCertificates.RootCA
        ])

        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatAnchoredRootCertificatePassesSSLValidationWithoutRootInTrust() {
        // Given
        let trust = TestTrusts.LeafDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatCertificateMissingDNSNameFailsSSLValidation() {
        // Given
        let trust = TestTrusts.LeafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertFalse(trustIsValid(trust), "trust should not be valid")
    }

    func testThatWildcardCertificatePassesSSLValidation() {
        // Given
        let trust = TestTrusts.LeafWildcard.trust // *.alamofire.org
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatDNSNameCertificatePassesSSLValidation() {
        // Given
        let trust = TestTrusts.LeafValidDNSName.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should be valid")
    }

    func testThatURICertificateFailsSSLValidation() {
        // Given
        let trust = TestTrusts.LeafValidURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertFalse(trustIsValid(trust), "trust should not be valid")
    }

    func testThatMultipleDNSNamesCertificatePassesSSLValidationForAllEntries() {
        // Given
        let trust = TestTrusts.LeafMultipleDNSNames.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [
            SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue(),
            SecPolicyCreateSSL(1, "blog.alamofire.org").takeRetainedValue(),
            SecPolicyCreateSSL(1, "www.alamofire.org").takeRetainedValue()
        ]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should not be valid")
    }

    func testThatPassingNilForHostParameterAllowsCertificateMissingDNSNameToPassSSLValidation() {
        // Given
        let trust = TestTrusts.LeafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, nil).takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertTrue(trustIsValid(trust), "trust should not be valid")
    }

    func testThatExpiredCertificateFailsSSLValidation() {
        // Given
        let trust = TestTrusts.LeafExpired.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(1, "test.alamofire.org").takeRetainedValue()]
        SecTrustSetPolicies(trust, policies)

        // Then
        XCTAssertFalse(trustIsValid(trust), "trust should not be valid")
    }
}

// MARK: - Server Trust Policy Tests -

class ServerTrustPolicyPerformDefaultEvaluationTestCase: ServerTrustPolicyTestCase {

    // MARK: Do NOT Validate Host

    func testThatValidCertificateChainPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: false)

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatMissingDNSNameLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafMissingDNSNameAndURI.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatExpiredCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatMissingIntermediateCertificateInChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    // MARK: Validate Host

    func testThatValidCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatMissingDNSNameLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafMissingDNSNameAndURI.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatWildcardedLeafCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafWildcard.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatExpiredCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatMissingIntermediateCertificateInChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = ServerTrustPolicy.PerformDefaultEvaluation(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyPinCertificatesTestCase: ServerTrustPolicyTestCase {

    // MARK: Validate Certificate Chain Without Validating Host

    func testThatPinnedLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinnedIntermediateCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinnedRootCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningLeafCertificateNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.LeafSignedByCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.IntermediateCA1]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningExpiredLeafCertificateFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.LeafExpired]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateWithExpiredLeafCertificateFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    // MARK: Validate Certificate Chain and Host

    func testThatPinnedLeafCertificatePassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinnedIntermediateCertificatePassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinnedRootCertificatePassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningLeafCertificateNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.LeafSignedByCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.IntermediateCA1]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningExpiredLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.LeafExpired]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateWithExpiredLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    // MARK: Do NOT Validate Certificate Chain or Host

    func testThatPinnedLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinnedIntermediateCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinnedRootCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningLeafCertificateNotInCertificateChainWithoutCertificateChainValidationFailsEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.LeafSignedByCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateNotInCertificateChainWithoutCertificateChainValidationFailsEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let certificates = [TestCertificates.IntermediateCA1]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.LeafExpired]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateCertificateWithExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)
        
        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningRootCertificateWithExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let certificates = [TestCertificates.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningMultipleCertificatesWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust

        let certificates = [
            TestCertificates.LeafMultipleDNSNames, // not in certificate chain
            TestCertificates.LeafSignedByCA1,      // not in certificate chain
            TestCertificates.LeafExpired,          // in certificate chain 👍🏼👍🏼
            TestCertificates.LeafWildcard,         // not in certificate chain
            TestCertificates.LeafDNSNameAndURI,    // not in certificate chain
        ]

        let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
            certificates: certificates,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyPinPublicKeysTestCase: ServerTrustPolicyTestCase {

    // MARK: Validate Certificate Chain Without Validating Host

    func testThatPinningLeafKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningKeyNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.LeafSignedByCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningBackupKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.LeafSignedByCA1, TestPublicKeys.IntermediateCA1, TestPublicKeys.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    // MARK: Validate Certificate Chain and Host

    func testThatPinningLeafKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningKeyNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.LeafSignedByCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningBackupKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let publicKeys = [TestPublicKeys.LeafSignedByCA1, TestPublicKeys.IntermediateCA1, TestPublicKeys.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: true,
            validateHost: true
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    // MARK: Do NOT Validate Certificate Chain or Host

    func testThatPinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithMissingIntermediateCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSNameMissingIntermediate.trust
        let publicKeys = [TestPublicKeys.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyWithoutCertificateChainValidationFailsEvaluationWithMissingIntermediateCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSNameMissingIntermediate.trust
        let publicKeys = [TestPublicKeys.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }

    func testThatPinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithIncorrectIntermediateCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSNameWithIncorrectIntermediate.trust
        let publicKeys = [TestPublicKeys.LeafValidDNSName]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let publicKeys = [TestPublicKeys.LeafExpired]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let publicKeys = [TestPublicKeys.IntermediateCA2]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let publicKeys = [TestPublicKeys.RootCA]
        let serverTrustPolicy = ServerTrustPolicy.PinPublicKeys(
            publicKeys: publicKeys,
            validateCertificateChain: false,
            validateHost: false
        )

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyDisableEvaluationTestCase: ServerTrustPolicyTestCase {
    func testThatCertificateChainMissingIntermediateCertificatePassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = ServerTrustPolicy.DisableEvaluation

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatExpiredLeafCertificatePassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafExpired.trust
        let serverTrustPolicy = ServerTrustPolicy.DisableEvaluation

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyCustomEvaluationTestCase: ServerTrustPolicyTestCase {
    func testThatReturningTrueFromClosurePassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let serverTrustPolicy = ServerTrustPolicy.CustomEvaluation { _, _ in
            return true
        }

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertTrue(serverTrustIsValid, "server trust should pass evaluation")
    }

    func testThatReturningFalseFromClosurePassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.LeafValidDNSName.trust
        let serverTrustPolicy = ServerTrustPolicy.CustomEvaluation { _, _ in
            return false
        }

        // When
        let serverTrustIsValid = serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host)

        // Then
        XCTAssertFalse(serverTrustIsValid, "server trust should not pass evaluation")
    }
}
