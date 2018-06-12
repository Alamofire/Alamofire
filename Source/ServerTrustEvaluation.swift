//
//  ServerTrustPolicy.swift
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

import Foundation

/// Responsible for managing the mapping of `ServerTrustEvaluating` values to given hosts.
open class ServerTrustManager {
    /// The dictionary of policies mapped to a particular host.
    public let evaluators: [String: ServerTrustEvaluating]

    /// Initializes the `ServerTrustManager` instance with the given evaluators.
    ///
    /// Since different servers and web services can have different leaf certificates, intermediate and even root
    /// certficates, it is important to have the flexibility to specify evaluation policies on a per host basis. This
    /// allows for scenarios such as using default evaluation for host1, certificate pinning for host2, public key
    /// pinning for host3 and disabling evaluation for host4.
    ///
    /// - Parameter evaluators: A dictionary of all evaluators mapped to a particular host.
    public init(evaluators: [String: ServerTrustEvaluating]) {
        self.evaluators = evaluators
    }

    /// Returns the `ServerTrustEvaluating` value for the given host, if one is set.
    ///
    /// By default, this method will return the policy that perfectly matches the given host. Subclasses could override
    /// this method and implement more complex mapping implementations such as wildcards.
    ///
    /// - Parameter host: The host to use when searching for a matching policy.
    /// - Returns:        The `ServerTrustEvaluating` value for the given host if found, `nil` otherwise.
    open func serverTrustEvaluators(forHost host: String) -> ServerTrustEvaluating? {
        return evaluators[host]
    }
}


/// A protocol describing the API used to evaluate server trusts.
public protocol ServerTrustEvaluating {
    #if os(Linux)
    // Implement this once Linux has API for evaluating server trusts.
    #else
    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: A `Bool` indicating whether the evaluator considers the `SecTrust` value valid for `host`.
    func evaluate(_ trust: SecTrust, forHost host: String) -> Bool
    #endif
}

extension Array where Element == ServerTrustEvaluating {
    #if os(Linux)
    // Add this same convenience method for Linux.
    #else
    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        for evaluator in self {
            guard evaluator.evaluate(trust, forHost: host) else { return false }
        }

        return true
    }
    #endif
}

// MARK: - Server Trust Evaluators

/// An evaluator which uses the default server trust evaluation while allowing you to control whether to validate the
/// host provided by the challenge. Applications are encouraged to always validate the host in production environments
/// to guarantee the validity of the server's certificate chain.
public final class DefaultTrustEvaluator: ServerTrustEvaluating {
    private let validateHost: Bool

    /// Creates a `DefaultTrustEvalutor`.
    ///
    /// - Parameter validateHost: Determines whether or not the evaluator should validate the host. Defaults to `true`.
    public init(validateHost: Bool = true) {
        self.validateHost = validateHost
    }

    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
        SecTrustSetPolicies(trust, policy)

        return trust.isValid
    }
}

/// An evaluator which Uses the default and revoked server trust evaluations allowing you to control whether to validate
/// the host provided by the challenge as well as specify the revocation flags for testing for revoked certificates.
/// Apple platforms did not start testing for revoked certificates automatically until iOS 10.1, macOS 10.12 and tvOS
/// 10.1 which is demonstrated in our TLS tests. Applications are encouraged to always validate the host in production
/// environments to guarantee the validity of the server's certificate chain.
public final class RevocationTrustEvaluator: ServerTrustEvaluating {
    /// Represents the options to be use when evaluating the status of a certificate.
    /// Only Revocation Policy Constants are valid, and can be found in [Apple's documentation](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/policies/1563600-revocation_policy_constants).
    public struct Options: OptionSet {
        /// The raw value of the option.
        public let rawValue: CFOptionFlags

        /// Creates an `Options` value with the given `CFOptionFlags`.
        ///
        /// - Parameter rawValue: The `CFOptionFlags` value to initialize with.
        public init(rawValue: CFOptionFlags) {
            self.rawValue = rawValue
        }

        /// Perform revocation checking using the CRL (Certification Revocation List) method.
        public static let crl = Options(rawValue: kSecRevocationCRLMethod)
        /// Consult only locally cached replies; do not use network access.
        public static let networkAccessDisabled = Options(rawValue: kSecRevocationNetworkAccessDisabled)
        /// Perform revocation checking using OCSP (Online Certificate Status Protocol).
        public static let ocsp = Options(rawValue: kSecRevocationOCSPMethod)
        /// Prefer CRL revocation checking over OCSP; by default, OCSP is preferred.
        public static let preferCRL = Options(rawValue: kSecRevocationPreferCRL)
        /// Require a positive response to pass the policy. If the flag is not set, revocation checking is done on a
        /// "best attempt" basis, where failure to reach the server is not considered fatal.
        public static let requirePositiveResponse = Options(rawValue: kSecRevocationRequirePositiveResponse)
        /// Perform either OCSP or CRL checking. The checking is performed according to the method(s) specified in the
        /// certificate and the value of `preferCRL`.
        public static let any = Options(rawValue: kSecRevocationUseAnyAvailableMethod)
    }

    private let validateHost: Bool
    private let options: Options

    /// Creates a `RevocationTrustEvaluator`
    ///
    /// - Parameters:
    ///   - options:      The `Options` to use to check the revocation status of the certificate. Defaults to `.any`.
    ///   - validateHost: Determines whether or not the evaluator should validate the host. Defaults to `true`.
    public init(options: Options = .any, validateHost: Bool = true) {
        self.validateHost = validateHost
        self.options = options
    }

    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        let defaultPolicy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
        let revokedPolicy = SecPolicyCreateRevocation(options.rawValue)
        SecTrustSetPolicies(trust, [defaultPolicy, revokedPolicy] as CFTypeRef)

        return trust.isValid
    }
}

/// Uses the pinned certificates to validate the server trust. The server trust is considered valid if one of the pinned
/// certificates match one of the server certificates. By validating both the certificate chain and host, certificate
/// pinning provides a very secure form of server trust validation mitigating most, if not all, MITM attacks.
/// Applications are encouraged to always validate the host and require a valid certificate chain in production
/// environments.
public final class PinnedCertificatesTrustEvaluator: ServerTrustEvaluating {
    private let certificates: [SecCertificate]
    private let validateCertificateChain: Bool
    private let validateHost: Bool

    /// Creates a `PinnedCertificatesTrustEvaluator`.
    ///
    /// - Parameters:
    ///   - certificates:             The certificates to use to evalute the trust. Defaults to all `cer`, `crt`, and
    ///                               `der` certificates in `Bundle.main`.
    ///   - validateCertificateChain: Determines whether the certificate chain should be evaluated or just the given
    ///                               certificate.
    ///   - validateHost:             Determines whether or not the evaluator should validate the host. Defaults to
    ///                               `true`.
    public init(certificates: [SecCertificate] = Bundle.main.certificates,
                validateCertificateChain: Bool = true,
                validateHost: Bool = true) {
        self.certificates = certificates
        self.validateCertificateChain = validateCertificateChain
        self.validateHost = validateHost
    }

    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        if validateCertificateChain {
            let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
            SecTrustSetPolicies(trust, policy)

            SecTrustSetAnchorCertificates(trust, certificates as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust, true)

            return trust.isValid
        } else {
            let serverCertificatesData = Set(trust.certificateData)
            let pinnedCertificatesData = Set(certificates.data)

            return !serverCertificatesData.isDisjoint(with: pinnedCertificatesData)
        }
    }
}

/// Uses the pinned public keys to validate the server trust. The server trust is considered valid if one of the pinned
/// public keys match one of the server certificate public keys. By validating both the certificate chain and host,
/// public key pinning provides a very secure form of server trust validation mitigating most, if not all, MITM attacks.
/// Applications are encouraged to always validate the host and require a valid certificate chain in production
/// environments.
public final class PublicKeysTrustEvaluator: ServerTrustEvaluating {
    private let keys: [SecKey]
    private let validateCertificateChain: Bool
    private let validateHost: Bool

    /// Creates a `PublicKeysTrustEvaluator`.
    ///
    /// - Parameters:
    ///   - keys:                     The public keys to use to evaluate the trust. Defaults to the public keys of all
    ///                               `cer`, `crt`, and `der` certificates in `Bundle.main`.
    ///   - validateCertificateChain: Determines whether the certificate chain should be evaluated.
    ///   - validateHost:             Determines whether or not the evaluator should validate the host. Defaults to
    ///                               `true`.
    public init(keys: [SecKey] = Bundle.main.publicKeys,
                validateCertificateChain: Bool = true,
                validateHost: Bool = true) {
        self.keys = keys
        self.validateCertificateChain = validateCertificateChain
        self.validateHost = validateHost
    }

    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        let certificateChainEvaluationPassed: Bool = {
            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(trust, policy)

                return trust.isValid
            } else {
                return true
            }
        }()

        guard certificateChainEvaluationPassed else { return false }

        outerLoop: for serverPublicKey in trust.publicKeys as [AnyHashable] {
            for pinnedPublicKey in keys as [AnyHashable] {
                if serverPublicKey == pinnedPublicKey {
                    return true
                }
            }
        }
        return false
    }
}

/// Uses the provided evaluators to validate the server trust. The trust is only considered valid if all of the
/// evaluators consider it valid.
public final class CompositeTrustEvaluator: ServerTrustEvaluating {
    private let evaluators: [ServerTrustEvaluating]

    /// Creates a `CompositeTrustEvaluator`.
    ///
    /// - Parameter evaluators: The `ServerTrustEvaluating` values used to evaluate the server trust.
    public init(evaluators: [ServerTrustEvaluating]) {
        self.evaluators = evaluators
    }

    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        return evaluators.evaluate(trust, forHost: host)
    }
}

/// Disables all evaluation which in turn will always consider any server trust as valid.
public final class DisabledEvaluator: ServerTrustEvaluating {
    public init() { }

    /// Evaluates the given `SecTrust` value for the given `host`.
    ///
    /// - Parameters:
    ///   - trust: The `SecTrust` value to evaluate.
    ///   - host:  The host for which to evaluate the `SecTrust` value.
    /// - Returns: Whether or not the evaluator considers the `SecTrust` value valid for `host`.
    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        return true
    }
}

public extension Bundle {
    /// Returns all valid `cer`, `crt`, and `der` certificates in the bundle.
    var certificates: [SecCertificate] {
        return paths(forResourcesOfTypes: [".cer", ".CER", ".crt", ".CRT", ".der", ".DER"]).compactMap { path in
            guard
                let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData,
                let certificate = SecCertificateCreateWithData(nil, certificateData) else { return nil }

            return certificate
        }
    }

    /// Returns all public keys for the valid certificates in the bundle.
    var publicKeys: [SecKey] {
        return certificates.compactMap { $0.publicKey }
    }

    /// Returns all pathnames for the resources identified by the provided file extensions.
    ///
    /// - Parameter types: The filename extensions locate.
    /// - Returns:         All pathnames for the given filename extensions.
    func paths(forResourcesOfTypes types: [String]) -> [String] {
        return Array(Set(types.flatMap { paths(forResourcesOfType: $0, inDirectory: nil) }))
    }
}

public extension SecTrust {
    /// Evaluates `self` and returns `true` if the evaluation succeeds with a value of `.unspecified` or `.proceed`.
    var isValid: Bool {
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(self, &result)

        return (status == errSecSuccess) ? result == .unspecified || result == .proceed : false
    }

    /// The public keys contained in `self`.
    var publicKeys: [SecKey] {
        return (0..<SecTrustGetCertificateCount(self)).compactMap { index in
            return SecTrustGetCertificateAtIndex(self, index)?.publicKey
        }
    }

    /// The `Data` values for all certificates contained in `self`.
    var certificateData: [Data] {
        return (0..<SecTrustGetCertificateCount(self)).compactMap { index in
            SecTrustGetCertificateAtIndex(self, index)
        }.data
    }
}

public extension Array where Element == SecCertificate {
    /// All `Data` values for the contained `SecCertificate` values.
    var data: [Data] {
        return map { SecCertificateCopyData($0) as Data }
    }
}

public extension SecCertificate {
    /// The public key for `self`, if it can be extracted.
    var publicKey: SecKey? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(self, policy, &trust)

        guard let createdTrust = trust, trustCreationStatus == errSecSuccess else { return nil }

        return SecTrustCopyPublicKey(createdTrust)
    }
}
