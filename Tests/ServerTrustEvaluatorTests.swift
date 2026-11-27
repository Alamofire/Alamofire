//
//  ServerTrustEvaluatorTests.swift
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
        let filePath = Bundle.test.path(forResource: filename, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        return SecCertificateCreateWithData(nil, data as CFData)!
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
        switch self {
        case .leafWildcard:
            TestTrusts.trustWithCertificates([TestCertificates.leafWildcard,
                                              TestCertificates.intermediateCA1,
                                              TestCertificates.rootCA])
        case .leafMultipleDNSNames:
            TestTrusts.trustWithCertificates([TestCertificates.leafMultipleDNSNames,
                                              TestCertificates.intermediateCA1,
                                              TestCertificates.rootCA])
        case .leafSignedByCA1:
            TestTrusts.trustWithCertificates([TestCertificates.leafSignedByCA1,
                                              TestCertificates.intermediateCA1,
                                              TestCertificates.rootCA])
        case .leafDNSNameAndURI:
            TestTrusts.trustWithCertificates([TestCertificates.leafDNSNameAndURI,
                                              TestCertificates.intermediateCA1,
                                              TestCertificates.rootCA])
        case .leafExpired:
            TestTrusts.trustWithCertificates([TestCertificates.leafExpired,
                                              TestCertificates.intermediateCA2,
                                              TestCertificates.rootCA])
        case .leafMissingDNSNameAndURI:
            TestTrusts.trustWithCertificates([TestCertificates.leafMissingDNSNameAndURI,
                                              TestCertificates.intermediateCA2,
                                              TestCertificates.rootCA])
        case .leafSignedByCA2:
            TestTrusts.trustWithCertificates([TestCertificates.leafSignedByCA2,
                                              TestCertificates.intermediateCA2,
                                              TestCertificates.rootCA])
        case .leafValidDNSName:
            TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                              TestCertificates.intermediateCA2,
                                              TestCertificates.rootCA])
        case .leafValidURI:
            TestTrusts.trustWithCertificates([TestCertificates.leafValidURI,
                                              TestCertificates.intermediateCA2,
                                              TestCertificates.rootCA])
        case .leafValidDNSNameMissingIntermediate:
            TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                              TestCertificates.rootCA])
        case .leafValidDNSNameWithIncorrectIntermediate:
            TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                              TestCertificates.intermediateCA1,
                                              TestCertificates.rootCA])
        }
    }

    /// 2020-01-01 UTC: after every fixture was issued (2015), before any valid one expires (2025), and
    /// after `expired.cer` expired (2015-07-13).
    static let verifyDate = Date(timeIntervalSince1970: 1_577_836_800)

    static func trustWithCertificates(_ certificates: [SecCertificate]) -> SecTrust {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificates as CFTypeRef, policy, &trust)
        // Evaluate at a fixed date inside the fixtures' validity periods, so they never expire.
        SecTrustSetVerifyDate(trust!, verifyDate as CFDate)

        return trust!
    }
}

// MARK: - Basic X509 and SSL Exploration Tests -

private func setRootCertificateAsLoneAnchorCertificateForTrust(_ trust: SecTrust) {
    SecTrustSetAnchorCertificates(trust, [TestCertificates.rootCA] as CFArray)
    SecTrustSetAnchorCertificatesOnly(trust, true)
}

// MARK: - SecTrust Extension

extension SecTrust {
    enum TrustError: Error { case invalid }

    /// Evaluates `self` and returns `true` if the evaluation succeeds with a value of `.unspecified` or `.proceed`.
    var isValid: Bool {
        if #available(iOS 12, macOS 10.14, tvOS 12, watchOS 5, visionOS 1, *) {
            Result { try af.evaluate() }.isSuccess
        } else {
            Result { try af.validate { _, _ in TrustError.invalid } }.isSuccess
        }
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyExplorationBasicX509PolicyValidationTestCase {
    @Test
    func anchoredRootCertificatePassesBasicX509ValidationWithRootInTrust() {
        // Given
        let trust = TestTrusts.trustWithCertificates([TestCertificates.leafDNSNameAndURI,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])

        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func anchoredRootCertificatePassesBasicX509ValidationWithoutRootInTrust() {
        // Given
        let trust = TestTrusts.leafDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func certificateMissingDNSNamePassesBasicX509Validation() {
        // Given
        let trust = TestTrusts.leafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func expiredCertificateFailsBasicX509Validation() {
        // Given
        let trust = TestTrusts.leafExpired.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateBasicX509()]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(!trust.isValid, "trust should not be valid")
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyExplorationSSLPolicyValidationTestCase {
    @Test
    func anchoredRootCertificatePassesSSLValidationWithRootInTrust() {
        // Given
        let trust = TestTrusts.trustWithCertificates([TestCertificates.leafDNSNameAndURI,
                                                      TestCertificates.intermediateCA1,
                                                      TestCertificates.rootCA])

        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func anchoredRootCertificatePassesSSLValidationWithoutRootInTrust() {
        // Given
        let trust = TestTrusts.leafDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func certificateMissingDNSNameFailsSSLValidation() {
        // Given
        let trust = TestTrusts.leafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(!trust.isValid, "trust should not be valid")
    }

    @Test
    func wildcardCertificatePassesSSLValidation() {
        // Given
        let trust = TestTrusts.leafWildcard.trust // *.alamofire.org
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func dnsNameCertificatePassesSSLValidation() {
        // Given
        let trust = TestTrusts.leafValidDNSName.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should be valid")
    }

    @Test
    func uriCertificateFailsSSLValidation() {
        // Given
        let trust = TestTrusts.leafValidURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(!trust.isValid, "trust should not be valid")
    }

    @Test
    func multipleDNSNamesCertificatePassesSSLValidationForAllEntries() {
        // Given
        let trust = TestTrusts.leafMultipleDNSNames.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString),
                        SecPolicyCreateSSL(true, "blog.alamofire.org" as CFString),
                        SecPolicyCreateSSL(true, "www.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should not be valid")
    }

    @Test
    func passingNilForHostParameterAllowsCertificateMissingDNSNameToPassSSLValidation() {
        // Given
        let trust = TestTrusts.leafMissingDNSNameAndURI.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, nil)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(trust.isValid, "trust should not be valid")
    }

    @Test
    func expiredCertificateFailsSSLValidation() {
        // Given
        let trust = TestTrusts.leafExpired.trust
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)

        // When
        let policies = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, policies as CFTypeRef)

        // Then
        #expect(!trust.isValid, "trust should not be valid")
    }
}

// MARK: - Server Trust Policy Tests -

@Suite
struct ServerTrustPolicyPerformDefaultEvaluationTestCase {
    // MARK: Do NOT Validate Host

    @Test
    func validCertificateChainPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func nonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingDNSNameLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func expiredCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingIntermediateCertificateInChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Validate Host

    @Test
    func validCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func nonAnchoredRootCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingDNSNameLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func wildcardedLeafCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafWildcard.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func expiredCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: true)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingIntermediateCertificateInChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = DefaultTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
        #expect(result.failure?.asAFError?.isServerTrustEvaluationError == true)
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyPerformRevokedEvaluationTestCase {
    // MARK: Do NOT Validate Host

    @Test
    func validCertificateChainPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func nonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingDNSNameLeafCertificatePassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func expiredCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingIntermediateCertificateInChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = RevocationTrustEvaluator(validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Validate Host

    @Test
    func validCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func nonAnchoredRootCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.trustWithCertificates([TestCertificates.leafValidDNSName,
                                                            TestCertificates.intermediateCA2])
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingDNSNameLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafMissingDNSNameAndURI.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func wildcardedLeafCertificateChainPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafWildcard.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func expiredCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func missingIntermediateCertificateInChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = RevocationTrustEvaluator()

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyPinCertificatesTestCase {
    // MARK: Validate Certificate Chain Without Validating Host

    @Test
    func pinnedLeafCertificatePassesEvaluationWithoutHostValidation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinnedIntermediateCertificatePassesEvaluationWithoutHostValidation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinnedRootCertificatePassesEvaluationWithoutHostValidation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningLeafCertificateNotInCertificateChainFailsEvaluationWithoutHostValidation() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningIntermediateCertificateNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA1]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningExpiredLeafCertificateFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.leafExpired]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningIntermediateCertificateWithExpiredLeafCertificateFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, validateHost: false)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Validate Certificate Chain and Host

    @Test
    func pinnedLeafCertificatePassesEvaluationWithSelfSignedSupportAndHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.leafValidDNSName]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, acceptSelfSignedCertificates: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinnedIntermediateCertificatePassesEvaluationWithSelfSignedSupportAndHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, acceptSelfSignedCertificates: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinnedRootCertificatePassesEvaluationWithSelfSignedSupportAndHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.rootCA]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates, acceptSelfSignedCertificates: true)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningLeafCertificateNotInCertificateChainFailsEvaluationWithHostValidation() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningIntermediateCertificateNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let certificates = [TestCertificates.intermediateCA1]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningExpiredLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.leafExpired]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningIntermediateCertificateWithExpiredLeafCertificateFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let certificates = [TestCertificates.intermediateCA2]
        let serverTrustPolicy = PinnedCertificatesTrustEvaluator(certificates: certificates)

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    // MARK: Do NOT Validate Certificate Chain or Host

    @Test
    func pinnedLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinnedIntermediateCertificateWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinnedRootCertificateWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningLeafCertificateNotInCertificateChainWithoutCertificateChainValidationFailsEvaluation() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningIntermediateCertificateNotInCertificateChainWithoutCertificateChainValidationFailsEvaluation() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningIntermediateCertificateWithExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningRootCertificateWithExpiredLeafCertificateWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningMultipleCertificatesWithoutCertificateChainValidationPassesEvaluation() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyPinPublicKeysTestCase {
    // MARK: Validate Certificate Chain Without Validating Host

    @Test
    func pinningLeafKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningIntermediateKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningRootKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.rootCA].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningKeyNotInCertificateChainFailsEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningBackupKeyPassesEvaluationWithoutHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA1, TestCertificates.intermediateCA1, TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys, validateHost: false)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    // MARK: Validate Certificate Chain and Host

    @Test
    func pinningLeafKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningIntermediateKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.intermediateCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningRootKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.rootCA].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningKeyNotInCertificateChainFailsEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA2].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningBackupKeyPassesEvaluationWithHostValidation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSName.trust
        let keys = [TestCertificates.leafSignedByCA1, TestCertificates.intermediateCA1, TestCertificates.leafValidDNSName].af.publicKeys
        let serverTrustPolicy = PublicKeysTrustEvaluator(keys: keys)

        // When
        setRootCertificateAsLoneAnchorCertificateForTrust(serverTrust)
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    // MARK: Do NOT perform default validation or validate host.

    @Test
    func pinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithMissingIntermediateCertificate() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningRootKeyWithoutCertificateChainValidationFailsEvaluationWithMissingIntermediateCertificate() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func pinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithIncorrectIntermediateCertificate() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningLeafKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningIntermediateKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func pinningRootKeyWithoutCertificateChainValidationPassesEvaluationWithExpiredLeafCertificate() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyDisableEvaluationTestCase {
    @Test
    func certificateChainMissingIntermediateCertificatePassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafValidDNSNameMissingIntermediate.trust
        let serverTrustPolicy = DisabledTrustEvaluator()

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func expiredLeafCertificatePassesEvaluation() {
        // Given
        let host = "test.alamofire.org"
        let serverTrust = TestTrusts.leafExpired.trust
        let serverTrustPolicy = DisabledTrustEvaluator()

        // When
        let result = Result { try serverTrustPolicy.evaluate(serverTrust, forHost: host) }

        // Then
        #expect(result.isSuccess, "server trust should pass evaluation")
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyCompositeTestCase {
    @Test
    func validCertificateChainPassesDefaultAndRevocationCompositeChecks() {
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
        #expect(result.isSuccess, "server trust should pass evaluation")
    }

    @Test
    func nonAnchoredRootCertificateChainFailsEvaluationWithoutHostValidation() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }

    @Test
    func expiredLeafCertificateFailsDefaultAndRevocationComposite() {
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
        #expect(!result.isSuccess, "server trust should not pass evaluation")
    }
}

// MARK: -

@Suite
struct ServerTrustPolicyCertificatesInBundleTestCase {
    @Test
    func onlyValidCertificatesAreDetected() {
        // Given
        // Files present in bundle in the form of type+encoding+extension [key|cert][DER|PEM].[cer|crt|der|key|pem]
        // certDER.cer: DER-encoded well-formed certificate
        // certDER.crt: DER-encoded well-formed certificate
        // certDER.der: DER-encoded well-formed certificate
        // certPEM.*: PEM-encoded well-formed certificates, expected to fail: Apple API only handles DER encoding
        // devURandomGibberish.crt: Random data, should fail
        // keyDER.der: DER-encoded key, not a certificate, should fail

        // When
        let certificates = Bundle.test.af.certificates

        // Then
        // Expectation: 19 well-formed certificates in the test bundle plus 4 invalid certificates.
        #if os(macOS)
        // For some reason, macOS is allowing all certificates to be considered valid. Need to file a
        // rdar demonstrating this behavior.
        if #available(macOS 10.12, *) {
            #expect(certificates.count == 19, "Expected 19 well-formed certificates")
        } else {
            #expect(certificates.count == 23, "Expected 23 well-formed certificates")
        }
        #else
        #expect(certificates.count == 19, "Expected 19 well-formed certificates")
        #endif
    }
}

@Suite
struct StaticServerTrustAccessorTests {
    func consumeServerTrustEvaluator(_ evaluator: any ServerTrustEvaluating) {
        _ = evaluator
    }

    @Test
    func revocationEvaluatorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeServerTrustEvaluator(.revocationChecking())
    }

    @Test
    func pinnedCertificatesEvaluatorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeServerTrustEvaluator(.pinnedCertificates())
    }

    @Test
    func publicKeysEvaluatorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeServerTrustEvaluator(.publicKeys())
    }
}

#endif
