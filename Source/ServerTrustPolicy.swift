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

/// Responsible for managing the mapping of `ServerTrustPolicy` objects to a given host.
open class ServerTrustPolicyManager {
    /// The dictionary of policies mapped to a particular host.
    open let evaluators: [String: ServerTrustEvaluating]

    /// Initializes the `ServerTrustPolicyManager` instance with the given policies.
    ///
    /// Since different servers and web services can have different leaf certificates, intermediate and even root
    /// certficates, it is important to have the flexibility to specify evaluation policies on a per host basis. This
    /// allows for scenarios such as using default evaluation for host1, certificate pinning for host2, public key
    /// pinning for host3 and disabling evaluation for host4.
    ///
    /// - parameter policies: A dictionary of all policies mapped to a particular host.
    ///
    /// - returns: The new `ServerTrustPolicyManager` instance.
    public init(evaluators: [String: ServerTrustEvaluating]) {
        self.evaluators = evaluators
    }

    /// Returns the `ServerTrustPolicy` for the given host if applicable.
    ///
    /// By default, this method will return the policy that perfectly matches the given host. Subclasses could override
    /// this method and implement more complex mapping implementations such as wildcards.
    ///
    /// - parameter host: The host to use when searching for a matching policy.
    ///
    /// - returns: The server trust policy for the given host if found.
//    open func serverTrustPolicy(forHost host: String) -> ServerTrustPolicy? {
//        return policies[host]
//    }

    open func serverTrustEvaluators(forHost host: String) -> ServerTrustEvaluating? {
        return evaluators[host]
    }

}

public protocol ServerTrustEvaluating {
    #if os(Linux)
    // Define a method to evaluate trust on Linux.
    #else
    func evaluate(_ trust: SecTrust, forHost host: String) -> Bool
    #endif
}

extension Array where Element == ServerTrustEvaluating {
    #if os(Linux)
    // Convenience method for Linux.
    #else
    func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        for evaluator in self {
            guard evaluator.evaluate(trust, forHost: host) else { return false }
        }

        return true
    }
    #endif
}

// MARK: -

extension URLSession {
    private struct AssociatedKeys {
        static var managerKey = "URLSession.ServerTrustPolicyManager"
    }

    var serverTrustPolicyManager: ServerTrustPolicyManager? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.managerKey) as? ServerTrustPolicyManager
        }
        set (manager) {
            objc_setAssociatedObject(self, &AssociatedKeys.managerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}



// MARK: - ServerTrustPolicy

/// The `ServerTrustPolicy` evaluates the server trust generally provided by a `URLAuthenticationChallenge` when
/// connecting to a server over a secure HTTPS connection. The policy configuration then evaluates the server trust
/// with a given set of criteria to determine whether the server trust is valid and the connection should be made.
///
/// Using pinned certificates or public keys for evaluation helps prevent man-in-the-middle (MITM) attacks and other
/// vulnerabilities. Applications dealing with sensitive customer data or financial information are strongly encouraged
/// to route all communication over an HTTPS connection with pinning enabled.
///
/// - `defaultEvaluation`: Uses the default server trust evaluation while allowing you to control whether to
///                        validate the host provided by the challenge. Applications are encouraged to always
///                        validate the host in production environments to guarantee the validity of the server's
///                        certificate chain.
///
/// - `revocation`:        Uses the default and revoked server trust evaluations allowing you to control whether to
///                        validate the host provided by the challenge as well as specify the revocation flags for
///                        testing for revoked certificates. Apple platforms did not start testing for revoked
///                        certificates automatically until iOS 10.1, macOS 10.12 and tvOS 10.1 which is
///                        demonstrated in our TLS tests. Applications are encouraged to always validate the host
///                        in production environments to guarantee the validity of the server's certificate chain.
///
/// - `pinCertificates`:   Uses the pinned certificates to validate the server trust. The server trust is
///                        considered valid if one of the pinned certificates match one of the server certificates.
///                        By validating both the certificate chain and host, certificate pinning provides a very
///                        secure form of server trust validation mitigating most, if not all, MITM attacks.
///                        Applications are encouraged to always validate the host and require a valid certificate
///                        chain in production environments.
///
/// - `pinPublicKeys`:     Uses the pinned public keys to validate the server trust. The server trust is considered
///                        valid if one of the pinned public keys match one of the server certificate public keys.
///                        By validating both the certificate chain and host, public key pinning provides a very
///                        secure form of server trust validation mitigating most, if not all, MITM attacks.
///                        Applications are encouraged to always validate the host and require a valid certificate
///                        chain in production environments.
///
/// - `disabled`:          Disables all evaluation which in turn will always consider any server trust as valid.
///
public final class ValidCertificateEvaluator: ServerTrustEvaluating {
    private let validateHost: Bool

    public init(validateHost: Bool = true) {
        self.validateHost = validateHost
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
        SecTrustSetPolicies(trust, policy)

        return trust.isValid
    }
}

public final class CertificateRevocationEvaluator: ServerTrustEvaluating {
    public struct Options: OptionSet {
        public let rawValue: CFOptionFlags

        public init(rawValue: CFOptionFlags) {
            self.rawValue = rawValue
        }

        public static let crl = Options(rawValue: kSecRevocationCRLMethod)
        public static let networkAccessDisabled = Options(rawValue: kSecRevocationNetworkAccessDisabled)
        public static let ocsp = Options(rawValue: kSecRevocationOCSPMethod)
        public static let preferCRL = Options(rawValue: kSecRevocationPreferCRL)
        public static let requirePositiveResponse = Options(rawValue: kSecRevocationRequirePositiveResponse)
        public static let any = Options(rawValue: kSecRevocationUseAnyAvailableMethod)
    }

    private let validateHost: Bool
    private let options: Options

    public init(validateHost: Bool = true, options: Options = .any) {
        self.validateHost = validateHost
        self.options = options
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        let defaultPolicy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
        let revokedPolicy = SecPolicyCreateRevocation(options.rawValue)
        SecTrustSetPolicies(trust, [defaultPolicy, revokedPolicy] as CFTypeRef)

        return trust.isValid
    }
}

public final class PinnedCertificatesEvaluator: ServerTrustEvaluating {
    private let certificates: [SecCertificate]
    private let validateCertificateChain: Bool
    private let validateHost: Bool

    public init(certificates: [SecCertificate] = Bundle.main.certificates,
                validateCertificateChain: Bool = true,
                validateHost: Bool = true) {
        self.certificates = certificates
        self.validateCertificateChain = validateCertificateChain
        self.validateHost = validateHost
    }


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

public final class PublicKeysEvaluator: ServerTrustEvaluating {
    private let keys: [SecKey]
    private let validateCertificateChain: Bool
    private let validateHost: Bool

    public init(keys: [SecKey] = Bundle.main.publicKeys,
                validateCertificateChain: Bool = true,
                validateHost: Bool = true) {
        self.keys = keys
        self.validateCertificateChain = validateCertificateChain
        self.validateHost = validateHost
    }

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

public final class CompositeEvaluator: ServerTrustEvaluating {
    private let evaluators: [ServerTrustEvaluating]

    public init(evaluators: [ServerTrustEvaluating]) {
        self.evaluators = evaluators
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        return evaluators.evaluate(trust, forHost: host)
    }
}

public final class DisabledEvaluator: ServerTrustEvaluating {
    public init() { }

    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        return true
    }
}

public extension Bundle {
    var certificates: [SecCertificate] {
        return paths(forResourcesOfTypes: [".cer", ".CER", ".crt", ".CRT", ".der", ".DER"]).flatMap { path in
            guard
                let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData,
                let certificate = SecCertificateCreateWithData(nil, certificateData) else { return nil }

            return certificate
        }
    }

    var publicKeys: [SecKey] {
        return certificates.flatMap { $0.publicKey }
    }

    func paths(forResourcesOfTypes types: [String]) -> [String] {
        return Array(Set(types.flatMap { paths(forResourcesOfType: $0, inDirectory: nil) }))
    }
}

public extension SecTrust {
    var isValid: Bool {
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(self, &result)

        return (status == errSecSuccess) ? result == .unspecified || result == .proceed : false
    }

    var publicKeys: [SecKey] {
        var publicKeys: [SecKey] = []

        for index in 0..<SecTrustGetCertificateCount(self) {
            if
                let certificate = SecTrustGetCertificateAtIndex(self, index),
                let publicKey = certificate.publicKey
            {
                publicKeys.append(publicKey)
            }
        }

        return publicKeys
    }

    var certificateData: [Data] {
        var certificates: [SecCertificate] = []

        for index in 0..<SecTrustGetCertificateCount(self) {
            if let certificate = SecTrustGetCertificateAtIndex(self, index) {
                certificates.append(certificate)
            }
        }

        return certificates.data
    }
}

public extension Array where Element == SecCertificate {
    var data: [Data] {
        return map { SecCertificateCopyData($0) as Data }
    }
}

public extension SecCertificate {
    var publicKey: SecKey? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(self, policy, &trust)

        guard let createdTrust = trust, trustCreationStatus == errSecSuccess else { return nil }

        return SecTrustCopyPublicKey(createdTrust)
    }
}
