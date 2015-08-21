// ServerTrustPolicy.swift
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

import Foundation

/// Responsible for managing the mapping of `ServerTrustPolicy` objects to a given host.
public class ServerTrustPolicyManager {
    /// The dictionary of policies mapped to a particular host.
    public let policies: [String: ServerTrustPolicy]

    /**
        Initializes the `ServerTrustPolicyManager` instance with the given policies.

        Since different servers and web services can have different leaf certificates, intermediate and even root 
        certficates, it is important to have the flexibility to specify evaluation policies on a per host basis. This 
        allows for scenarios such as using default evaluation for host1, certificate pinning for host2, public key 
        pinning for host3 and disabling evaluation for host4.

        - parameter policies: A dictionary of all policies mapped to a particular host.

        - returns: The new `ServerTrustPolicyManager` instance.
    */
    public init(policies: [String: ServerTrustPolicy]) {
        self.policies = policies
    }

    /**
        Returns the `ServerTrustPolicy` for the given host if applicable.

        By default, this method will return the policy that perfectly matches the given host. Subclasses could override
        this method and implement more complex mapping implementations such as wildcards.

        - parameter host: The host to use when searching for a matching policy.

        - returns: The server trust policy for the given host if found.
    */
    public func serverTrustPolicyForHost(host: String) -> ServerTrustPolicy? {
        return policies[host]
    }
}

// MARK: -

extension NSURLSession {
    private struct AssociatedKeys {
        static var ManagerKey = "NSURLSession.ServerTrustPolicyManager"
    }

    var serverTrustPolicyManager: ServerTrustPolicyManager? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.ManagerKey) as? ServerTrustPolicyManager
        }
        set (manager) {
            objc_setAssociatedObject(self, &AssociatedKeys.ManagerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - ServerTrustPolicy

/**
    The `ServerTrustPolicy` evaluates the server trust generally provided by an `NSURLAuthenticationChallenge` when 
    connecting to a server over a secure HTTPS connection. The policy configuration then evaluates the server trust 
    with a given set of criteria to determine whether the server trust is valid and the connection should be made.

    Using pinned certificates or public keys for evaluation helps prevent man-in-the-middle (MITM) attacks and other 
    vulnerabilities. Applications dealing with sensitive customer data or financial information are strongly encouraged 
    to route all communication over an HTTPS connection with pinning enabled.

    - PerformDefaultEvaluation: Uses the default server trust evaluation while allowing you to control whether to 
                                validate the host provided by the challenge. Applications are encouraged to always 
                                validate the host in production environments to guarantee the validity of the server's 
                                certificate chain.

    - PinCertificates:          Uses the pinned certificates to validate the server trust. The server trust is
                                considered valid if one of the pinned certificates match one of the server certificates. 
                                By validating both the certificate chain and host, certificate pinning provides a very 
                                secure form of server trust validation mitigating most, if not all, MITM attacks. 
                                Applications are encouraged to always validate the host and require a valid certificate 
                                chain in production environments.

    - PinPublicKeys:            Uses the pinned public keys to validate the server trust. The server trust is considered
                                valid if one of the pinned public keys match one of the server certificate public keys. 
                                By validating both the certificate chain and host, public key pinning provides a very 
                                secure form of server trust validation mitigating most, if not all, MITM attacks. 
                                Applications are encouraged to always validate the host and require a valid certificate 
                                chain in production environments.

    - DisableEvaluation:        Disables all evaluation which in turn will always consider any server trust as valid.

    - CustomEvaluation:         Uses the associated closure to evaluate the validity of the server trust.
*/
public enum ServerTrustPolicy {
    case PerformDefaultEvaluation(validateHost: Bool)
    case PinCertificates(certificates: [SecCertificate], validateCertificateChain: Bool, validateHost: Bool)
    case PinPublicKeys(publicKeys: [SecKey], validateCertificateChain: Bool, validateHost: Bool)
    case DisableEvaluation
    case CustomEvaluation((serverTrust: SecTrust, host: String) -> Bool)

    // MARK: - Bundle Location

    /**
        Returns all certificates within the given bundle with a `.cer` file extension.

        - parameter bundle: The bundle to search for all `.cer` files.

        - returns: All certificates within the given bundle.
    */
    public static func certificatesInBundle(bundle: NSBundle = NSBundle.mainBundle()) -> [SecCertificate] {
        var certificates: [SecCertificate] = []

        for path in bundle.pathsForResourcesOfType(".cer", inDirectory: nil) {
            if let
                certificateData = NSData(contentsOfFile: path),
                certificate = SecCertificateCreateWithData(nil, certificateData)
            {
                certificates.append(certificate)
            }
        }

        return certificates
    }

    /**
        Returns all public keys within the given bundle with a `.cer` file extension.

        - parameter bundle: The bundle to search for all `*.cer` files.

        - returns: All public keys within the given bundle.
    */
    public static func publicKeysInBundle(bundle: NSBundle = NSBundle.mainBundle()) -> [SecKey] {
        var publicKeys: [SecKey] = []

        for certificate in certificatesInBundle(bundle) {
            if let publicKey = publicKeyForCertificate(certificate) {
                publicKeys.append(publicKey)
            }
        }

        return publicKeys
    }

    // MARK: - Evaluation

    /**
        Evaluates whether the server trust is valid for the given host.

        - parameter serverTrust: The server trust to evaluate.
        - parameter host:        The host of the challenge protection space.

        - returns: Whether the server trust is valid.
    */
    public func evaluateServerTrust(serverTrust: SecTrust, isValidForHost host: String) -> Bool {
        var serverTrustIsValid = false

        switch self {
        case let .PerformDefaultEvaluation(validateHost):
            let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
            SecTrustSetPolicies(serverTrust, [policy])

            serverTrustIsValid = trustIsValid(serverTrust)
        case let .PinCertificates(pinnedCertificates, validateCertificateChain, validateHost):
            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(serverTrust, [policy])

                SecTrustSetAnchorCertificates(serverTrust, pinnedCertificates)
                SecTrustSetAnchorCertificatesOnly(serverTrust, true)

                serverTrustIsValid = trustIsValid(serverTrust)
            } else {
                let serverCertificatesDataArray = certificateDataForTrust(serverTrust)

                //======================================================================================================
                // The following `[] +` is a temporary workaround for a Swift 2.0 compiler error. This workaround should
                // be removed once the following radar has been resolved:
                //   - http://openradar.appspot.com/radar?id=6082025006039040
                //======================================================================================================

                let pinnedCertificatesDataArray = certificateDataForCertificates([] + pinnedCertificates)

                outerLoop: for serverCertificateData in serverCertificatesDataArray {
                    for pinnedCertificateData in pinnedCertificatesDataArray {
                        if serverCertificateData.isEqualToData(pinnedCertificateData) {
                            serverTrustIsValid = true
                            break outerLoop
                        }
                    }
                }
            }
        case let .PinPublicKeys(pinnedPublicKeys, validateCertificateChain, validateHost):
            var certificateChainEvaluationPassed = true

            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(serverTrust, [policy])

                certificateChainEvaluationPassed = trustIsValid(serverTrust)
            }

            if certificateChainEvaluationPassed {
                outerLoop: for serverPublicKey in ServerTrustPolicy.publicKeysForTrust(serverTrust) as [AnyObject] {
                    for pinnedPublicKey in pinnedPublicKeys as [AnyObject] {
                        if serverPublicKey.isEqual(pinnedPublicKey) {
                            serverTrustIsValid = true
                            break outerLoop
                        }
                    }
                }
            }
        case .DisableEvaluation:
            serverTrustIsValid = true
        case let .CustomEvaluation(closure):
            serverTrustIsValid = closure(serverTrust: serverTrust, host: host)
        }

        return serverTrustIsValid
    }

    // MARK: - Private - Trust Validation

    private func trustIsValid(trust: SecTrust) -> Bool {
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

    // MARK: - Private - Certificate Data

    private func certificateDataForTrust(trust: SecTrust) -> [NSData] {
        var certificates: [SecCertificate] = []

        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let certificate = SecTrustGetCertificateAtIndex(trust, index) {
                certificates.append(certificate)
            }
        }

        return certificateDataForCertificates(certificates)
    }

    private func certificateDataForCertificates(certificates: [SecCertificate]) -> [NSData] {
        return certificates.map { SecCertificateCopyData($0) as NSData }
    }

    // MARK: - Private - Public Key Extraction

    private static func publicKeysForTrust(trust: SecTrust) -> [SecKey] {
        var publicKeys: [SecKey] = []

        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let
                certificate = SecTrustGetCertificateAtIndex(trust, index),
                publicKey = publicKeyForCertificate(certificate)
            {
                publicKeys.append(publicKey)
            }
        }

        return publicKeys
    }

    private static func publicKeyForCertificate(certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?

        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)

        if let trust = trust where trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust)
        }

        return publicKey
    }
}
