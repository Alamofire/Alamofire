// Alamofire.swift
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

// TODO: DocStrings
public class ServerTrustPolicyManager {
    let policies: [String: ServerTrustPolicy]

    // TODO: DocStrings
    public init(policies: [String: ServerTrustPolicy]) {
        self.policies = policies
    }

    // TODO: DocStrings
    public func serverTrustPolicyForHost(host: String) -> ServerTrustPolicy? {
        return self.policies[host]
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
            objc_setAssociatedObject(self, &AssociatedKeys.ManagerKey, manager, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
        }
    }
}

// MARK: - ServerTrustPolicy

// TODO: DocStrings
public enum ServerTrustPolicy {
    case PerformDefaultEvaluation(validateHost: Bool)
    case PinCertificates(certificates: [SecCertificate], validateHost: Bool)
    case PinPublicKeys(publicKeys: [SecKey], validateHost: Bool, allowInvalidCertificates: Bool)
    case DisableEvaluation
    case CustomEvaluation((serverTrust: SecTrust, host: String) -> Bool)

    // MARK: - Bundle Location

    // TODO: DocStrings
    public func certificatesInBundle(bundle: NSBundle = NSBundle.mainBundle()) -> [SecCertificate] {
        var certificates: [SecCertificate] = []

        for path in bundle.pathsForResourcesOfType(".cer", inDirectory: nil) as! [String] {
            if let
                certificateData = NSData(contentsOfFile: path),
                certificate = SecCertificateCreateWithData(nil, certificateData)?.takeRetainedValue()
            {
                certificates.append(certificate)
            }
        }

        return certificates
    }

    // TODO: DocStrings
    public func publicKeysInBundle(bundle: NSBundle = NSBundle.mainBundle()) -> [SecKey] {
        var publicKeys: [SecKey] = []

        for certificate in certificatesInBundle(bundle: bundle) {
            if let publicKey = publicKeyForCertificate(certificate) {
                publicKeys.append(publicKey)
            }
        }

        return publicKeys
    }

    // MARK: - Evaluation

    // TODO: DocStrings
    public func evaluateServerTrust(serverTrust: SecTrust, isValidForHost host: String) -> Bool {
        var serverTrustIsValid = false

        switch self {
        case let .PerformDefaultEvaluation(validateHost):
            let policy = validateHost ? SecPolicyCreateSSL(1, host as CFString) : SecPolicyCreateBasicX509()
            SecTrustSetPolicies(serverTrust, [policy.takeRetainedValue()])

            serverTrustIsValid = trustIsValid(serverTrust)
        case let .PinCertificates(pinnedCertificates, validateHost):
            let policy = validateHost ? SecPolicyCreateSSL(1, host as CFString) : SecPolicyCreateBasicX509()
            SecTrustSetPolicies(serverTrust, [policy.takeRetainedValue()])

            SecTrustSetAnchorCertificates(serverTrust, pinnedCertificates)
            SecTrustSetAnchorCertificatesOnly(serverTrust, 1)

            serverTrustIsValid = trustIsValid(serverTrust)
        case let .PinPublicKeys(pinnedPublicKeys, validateHost, allowInvalidCertificates):
            var certificateChainEvaluationPassed = true

            if !allowInvalidCertificates {
                let policy = validateHost ? SecPolicyCreateSSL(1, host as CFString) : SecPolicyCreateBasicX509()
                SecTrustSetPolicies(serverTrust, [policy.takeRetainedValue()])

                certificateChainEvaluationPassed = trustIsValid(serverTrust)
            }

            if certificateChainEvaluationPassed {
                let serverKeys = publicKeysForTrust(serverTrust)
                outerLoop: for serverPublicKey in publicKeysForTrust(serverTrust) as [AnyObject] {
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

    // MARK: - Private - Public Key Extraction

    private func publicKeysForTrust(trust: SecTrust) -> [SecKey] {
        var publicKeys: [SecKey] = []

        for index in 0..<SecTrustGetCertificateCount(trust) {
            let certificate = SecTrustGetCertificateAtIndex(trust, index).takeUnretainedValue()

            if let publicKey = publicKeyForCertificate(certificate) {
                publicKeys.append(publicKey)
            }
        }

        return publicKeys
    }

    private func publicKeyForCertificate(certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?

        let policy = SecPolicyCreateBasicX509().takeRetainedValue()
        var unmanagedTrust: Unmanaged<SecTrust>?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &unmanagedTrust)

        if let trust = unmanagedTrust?.takeRetainedValue() where trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust).takeRetainedValue()
        }

        return publicKey
    }
}
