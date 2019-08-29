//
//  ServerTrustPolicyTests.swift
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

import Alamofire
import Foundation
import XCTest

private struct TestCertificates {
    // Root Certificates
    static let rootCA = TestCertificates.certificate(filename: "alamofire-root-ca")

    // Intermediate Certificates
    static let intermediateCA1 = TestCertificates.certificate(filename: "alamofire-signing-ca1")
    static let intermediateCA2 = TestCertificates.certificate(filename: "alamofire-signing-ca2")

    // Leaf Certificates - Signed by CA1
    static let leafWildcard = TestCertificates.certificate(filename: "wildcard.alamofire.org")
    static let leafMultipleDNSNames = TestCertificates.certificate(filename: "multiple-dns-names")
    static let leafSignedByCA1 = TestCertificates.certificate(filename: "signed-by-ca1")
    static let leafDNSNameAndURI = TestCertificates.certificate(filename: "test.alamofire.org")

    // Leaf Certificates - Signed by CA2
    static let leafExpired = TestCertificates.certificate(filename: "expired")
    static let leafMissingDNSNameAndURI = TestCertificates.certificate(filename: "missing-dns-name-and-uri")
    static let leafSignedByCA2 = TestCertificates.certificate(filename: "signed-by-ca2")
    static let leafValidDNSName = TestCertificates.certificate(filename: "valid-dns-name")
    static let leafValidURI = TestCertificates.certificate(filename: "valid-uri")

    static func certificate(filename: String) -> SecCertificate {
        class Locator {}
        let filePath = Bundle(for: Locator.self).path(forResource: filename, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!

        return certificate
    }
}

// MARK: -

private enum TestTrusts {
    // Leaf Trusts - Signed by CA1
    case leafWildcard
    case leafMultipleDNSNames
    case leafSignedByCA1
    case leafDNSNameAndURI

    // Leaf Trusts - Signed by CA2
    case leafExpired
    case leafMissingDNSNameAndURI
    case leafSignedByCA2
    case leafValidDNSName
    case leafValidURI

    // Invalid Trusts
    case leafValidDNSNameMissingIntermediate
    case leafValidDNSNameWithIncorrectIntermediate

    var trust: SecTrust {
        let trust: SecTrust

        switch self {
        case .leafWildcard:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafWildcard,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])
        case .leafMultipleDNSNames:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafMultipleDNSNames,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])
        case .leafSignedByCA1:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafSignedByCA1,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])
        case .leafDNSNameAndURI:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafDNSNameAndURI,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])
        case .leafExpired:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafExpired,
                                                      TestCertificates.intermediateCA2,
                                                      TestCertificates.rootCA])
        case .leafMissingDNSNameAndURI:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafMissingDNSNameAndURI,
                                                      TestCertificates.intermediateCA2,
                                                      TestCertificates.rootCA])
        case .leafSignedByCA2:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafSignedByCA2,
                                                      TestCertificates.intermediateCA2,
                                                      TestCertificates.rootCA])
        case .leafValidDNSName:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                      TestCertificates.intermediateCA2,
                                                      TestCertificates.rootCA])
        case .leafValidURI:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafValidURI,
                                                      TestCertificates.intermediateCA2,
                                                      TestCertificates.rootCA])
        case .leafValidDNSNameMissingIntermediate:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                      TestCertificates.rootCA])
        case .leafValidDNSNameWithIncorrectIntermediate:
            trust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])
        }

        return trust
    }

    static func trustWithCertificates(_ certificates: [SecCertificate]) -> SecTrust {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificates as CFTypeRef, policy, &trust)

        return trust!
    }
}

// MARK: - Basic X509 and SSL Exploration Tests -

class ServerTrustPolicyTestCase: BaseTestCase {
    func setRootCertificateAsLoneAnchorCertificateForTrust(_ trust: SecTrust) {
        SecTrustSetAnchorCertificates(trust, [TestCertificates.rootCA] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
    }
}

// MARK: - SecTrust Extension

extension SecTrust {
    /// Evaluates `self` and returns `true` if the evaluation succeeds with a value of `.unspecified` or `.proceed`.
    var isValid: Bool {
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(self, &result)

        return (status == errSecSuccess) ? (result == .unspecified || result == .proceed) : false
    }
}

// MARK: -

class ServerTrustPolicyExplorationBasicX509PolicyValidationTestCase: ServerTrustPolicyTestCase {
    func testThatAnchoredRootCertificatePassesBasicX509ValidationWithRootInTrust() {
        // Given
        let trust = TestTrusts.trustWithCertificates([TestCertificates.leafDNSNameAndURI,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])

        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatAnchoredRootCertificatePassesBasicX509ValidationWithoutRootInTrust() {
        // Given
        let trust = TestTrusts.leafDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatCertificateMissingDNSNamePassesBasicX509Validation() {
        // Given
        let trust = TestTrusts.leafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatExpiredCertificateFailsBasicX509Validation() {
        // Given
        let trust = TestTrusts.leafExpired.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertFalse(trust.isValid, "trust should not be valid")
    }
}

// MARK: -

class ServerTrustPolicyExplorationSSLPolicyValidationTestCase: ServerTrustPolicyTestCase {
    func testThatAnchoredRootCertificatePassesSSLValidationWithRootInTrust() {
        // Given
        let trust = TestTrusts.trustWithCertificates([TestCertificates.leafDNSNameAndURI,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])

        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatAnchoredRootCertificatePassesSSLValidationWithoutRootInTrust() {
        // Given
        let trust = TestTrusts.leafDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatCertificateMissingDNSNameFailsSSLValidation() {
        // Given
        let trust = TestTrusts.leafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertFalse(trust.isValid, "trust should not be valid")
    }

    func testThatWildcardCertificatePassesSSLValidation() {
        // Given
        let trust = TestTrusts.leafWildcard.trust // *.alamofire.org
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatDNSNameCertificatePassesSSLValidation() {
        // Given
        let trust = TestTrusts.leafValidDNSName.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should be valid")
    }

    func testThatURICertificateFailsSSLValidation() {
        // Given
        let trust = TestTrusts.leafValidURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertFalse(trust.isValid, "trust should not be valid")
    }

    func testThatMultipleDNSNamesCertificatePassesSSLValidationForAllEntries() {
        // Given
        let trust = TestTrusts.leafMultipleDNSNames.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString),
                        SecPolicyCreateSSL(true, "blog.alamofire.org" as CFString),
                        SecPolicyCreateSSL(true, "www.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should not be valid")
    }

    func testThatPassingNilForHostParameterAllowsCertificateMissingDNSNameToPassSSLValidation() {
        // Given
        let trust = TestTrusts.leafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, nil)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertTrue(trust.isValid, "trust should not be valid")
    }

    func testThatExpiredCertificateFailsSSLValidation() {
        // Given
        let trust = TestTrusts.leafExpired.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        XCTAssertFalse(trust.isValid, "trust should not be valid")
    }
}

// MARK: - Server Trust Policy Tests -

class ServerTrustPolicyPerformDefaultEvaluationTestCase: ServerTrustPolicyTestCase {
    // MARK: Do NOT Validate Host

    func testThatValidCertificateChainPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingDNSNameLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatExpiredCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingIntermediateCertificateInChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Validate Host

    func testThatValidCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingDNSNameLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatWildcardedLeafCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafWildcard.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatExpiredCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingIntermediateCertificateInChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
        XCTAssertEqual(result.failure?.asAFError?.isServerTrustEvaluationError, true)
    }
}

// MARK: -

class ServerTrustPolicyPerformRevokedEvaluationTestCase: ServerTrustPolicyTestCase {
    // MARK: Do NOT Validate Host

    func testThatValidCertificateChainPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingDNSNameLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatExpiredCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingIntermediateCertificateInChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Validate Host

    func testThatValidCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingDNSNameLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatWildcardedLeafCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafWildcard.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatExpiredCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatMissingIntermediateCertificateInChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyPinCertificatesTestCase: ServerTrustPolicyTestCase {
    // MARK: Validate Certificate Chain Without Validating Host

    func testThatPinnedLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafValidDNSName]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinnedIntermediateCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinnedRootCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.rootCA]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningLeafCertificateNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafSignedByCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: true,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA1]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningExpiredLeafCertificateFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.leafExpired]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateWithExpiredLeafCertificateFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Validate Certificate Chain and Host

    func testThatPinnedLeafCertificatePassesEvaluationWithSelfSignedSupportAndHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafValidDNSName]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, acceptSelfSignedCertificates: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinnedIntermediateCertificatePassesEvaluationWithSelfSignedSupportAndHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, acceptSelfSignedCertificates: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinnedRootCertificatePassesEvaluationWithSelfSignedSupportAndHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.rootCA]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, acceptSelfSignedCertificates: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningLeafCertificateNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafSignedByCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: true,
                                                                 validateHost: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA1]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningExpiredLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.leafExpired]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateWithExpiredLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Do NOT Validate Certificate Chain or Host

    func testThatPinnedLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafValidDNSName]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinnedIntermediateCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinnedRootCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.rootCA]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningLeafCertificateNotInCertificateChainWithoutCertificateChainValidationFailsEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafSignedByCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningIntermediateCertificateNotInCertificateChainWithoutCertificateChainValidationFailsEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA1]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.leafExpired]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateCertificateWithExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningRootCertificateWithExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.rootCA]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningMultipleCertificatesWithoutCertificateChainValidationPassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust

        let certificates = [TestCertificates.leafMultipleDNSNames, // not in certificate chain
                            TestCertificates.leafSignedByCA1, // not in certificate chain
                            TestCertificates.leafExpired, // in certificate chain 👍🏼👍🏼
                            TestCertificates.leafWildcard, // not in certificate chain
                            TestCertificates.leafDNSNameAndURI // not in certificate chain
        ]

        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates,
                                                                 performDefaultValidation: false,
                                                                 validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyPinPublicKeysTestCase: ServerTrustPolicyTestCase {
    // MARK: Validate Certificate Chain Without Validating Host

    func testThatPinningLeafKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.rootCA].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningKeyNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningBackupKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA1, TestCertificates.intermediateCA1, TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    // MARK: Validate Certificate Chain and Host

    func testThatPinningLeafKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.rootCA].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningKeyNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningBackupKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA1, TestCertificates.intermediateCA1, TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    // MARK: Do NOT perform default validation or validate host.

    func testThatPinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithMissingIntermediateCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let keys = [TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys,
                                                         performDefaultValidation: false,
                                                         validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyWithoutCertificateChainValidationFailsEvaluationWithMissingIntermediateCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let keys = [TestCertificates.rootCA].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys,
                                                         performDefaultValidation: false,
                                                         validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatPinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithIncorrectIntermediateCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameWithIncorrectIntermediate.trust
        let keys = [TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys,
                                                         performDefaultValidation: false,
                                                         validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let keys = [TestCertificates.leafExpired].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys,
                                                         performDefaultValidation: false,
                                                         validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningIntermediateKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys,
                                                         performDefaultValidation: false,
                                                         validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatPinningRootKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let keys = [TestCertificates.rootCA].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys,
                                                         performDefaultValidation: false,
                                                         validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyDisableEvaluationTestCase: ServerTrustPolicyTestCase {
    func testThatCertificateChainMissingIntermediateCertificatePassesEvaluation() throws {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = DisabledEvaluator()

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatExpiredLeafCertificatePassesEvaluation() throws {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = DisabledEvaluator()

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyCompositeTestCase: ServerTrustPolicyTestCase {
    func testThatValidCertificateChainPassesDefaultAndRevocationCompositeChecks() throws {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let defaultPolicy = DefaultTrustEvaluator(validateHost: false)
        let revocationPolicy = RevocationTrustEvaluator(validateHost: false)
        let compositePolicy = CompositeTrustEvaluator(evaluators: [defaultPolicy, revocationPolicy])

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try compositePolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertTrue(result.isSuccess, "server trust should pass evaluation")
    }

    func testThatNonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() throws {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let defaultPolicy = DefaultTrustEvaluator(validateHost: false)
        let revocationPolicy = RevocationTrustEvaluator(validateHost: false)
        let compositePolicy = CompositeTrustEvaluator(evaluators: [defaultPolicy, revocationPolicy])

        // When
        let result = Result { try compositePolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }

    func testThatExpiredLeafCertificateFailsDefaultAndRevocationComposite() throws {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let defaultPolicy = DefaultTrustEvaluator(validateHost: false)
        let revocationPolicy = RevocationTrustEvaluator(validateHost: false)
        let compositePolicy = CompositeTrustEvaluator(evaluators: [defaultPolicy, revocationPolicy])

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try compositePolicy.evaluate(serverTrust, forHost: host) }

        // Then
        XCTAssertFalse(result.isSuccess, "server trust should not pass evaluation")
    }
}

// MARK: -

class ServerTrustPolicyCertificatesInBundleTestCase: ServerTrustPolicyTestCase {
    func testOnlyValidCertificatesAreDetected() {
        // Given
        // Files present in bundle in the form of type+encoding+extension [key|cert][DER|PEM].[cer|crt|der|key|pem]
        // certDER.cer: DER-encoded well-formed certificate
        // certDER.crt: DER-encoded well-formed certificate
        // certDER.der: DER-encoded well-formed certificate
        // certPEM.*: PEM-encoded well-formed certificates, expected to fail: Apple API only handles DER encoding
        // devURandomGibberish.crt: Random data, should fail
        // keyDER.der: DER-encoded key, not a certificate, should fail

        // When
        let certificates = Bundle(for: ServerTrustPolicyCertificatesInBundleTestCase.self).af.certificates

// Then
// Expectation: 19 well-formed certificates in the test bundle plus 4 invalid certificates.
#if os(macOS)
        // For some reason, macOS is allowing all certificates to be considered valid. Need to file a
        // rdar demonstrating this behavior.
        if #available(macOS 10.12, *) {
            XCTAssertEqual(certificates.count, 19, "Expected 19 well-formed certificates")
        } else {
            XCTAssertEqual(certificates.count, 23, "Expected 23 well-formed certificates")
        }
#else
        XCTAssertEqual(certificates.count, 19, "Expected 19 well-formed certificates")
#endif
    }
}
