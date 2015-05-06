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

import Foundation
import Alamofire
import XCTest

class AlamofireTLSEvaluationTestCase: XCTestCase {
    func testSSLCertificateCommonNameValidation() {
        let URL = "https://testssl-expire.disig.sk/"

        let expectation = expectationWithDescription("\(URL)")

        Alamofire.request(.GET, URL)
            .response { (_, _, _, error) in
                XCTAssertNotNil(error, "error should not be nil")
                XCTAssert(error?.code == NSURLErrorServerCertificateUntrusted, "error should be NSURLErrorServerCertificateUntrusted")

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
    
    // MARK: - TLSTrustPolicy
    struct TestSec {
        static let commonHost = "foobar.com"
        static let foobar = TestSec.certificateWithName("foobar.com")
        static let altname = TestSec.certificateWithName("AltName")
        static let nodomains = TestSec.certificateWithName("NoDomains")
        
        static let foobarTrust = TestSec.serverTrustForCertificates([TestSec.foobar])
        static let altnameTrust = TestSec.serverTrustForCertificates([TestSec.altname])
        static let nodomainsTrust = TestSec.serverTrustForCertificates([TestSec.nodomains])
        
        static func certificateWithName(filename: String) -> SecCertificateRef {
            let path = NSBundle(forClass: AlamofireTLSEvaluationTestCase.self).pathForResource(filename, ofType: "cer")
            let data = NSData(contentsOfFile: path!)!
            return SecCertificateCreateWithData(nil, data).takeRetainedValue()
        }
        
        static func serverTrustForCertificates(certificates: [SecCertificateRef]) -> SecTrustRef {
            let policy = SecPolicyCreateBasicX509().takeRetainedValue()
            var trustPtr: Unmanaged<SecTrustRef>? = nil
            SecTrustCreateWithCertificates(certificates, policy, &trustPtr)
            let trust = trustPtr!.takeRetainedValue()
            return trust
        }
        
        
        static let chainRoot = TestSec.certificateWithName("root")
        static let chainGoodLeaf = TestSec.certificateWithName("goodLeaf")
        static let chainBadFakeLeaf = TestSec.certificateWithName("badFakeLeaf")
    }
    
    // MARK: Test assumptions made on Apple's APIs
    func testSetAnchorCanSpecifyRoot() {
        let certificate = TestSec.foobar
        let policy = SecPolicyCreateSSL(1, TestSec.commonHost as CFString).takeRetainedValue()
        XCTAssertNotNil(policy, "policy should not be nil")
        
        var trustPtr: Unmanaged<SecTrustRef>? = nil
        SecTrustCreateWithCertificates(certificate, policy, &trustPtr)
        let serverTrust = trustPtr!.takeRetainedValue()
        
        var status = errSecSuccess
        status = SecTrustSetAnchorCertificates(serverTrust, [certificate])
        XCTAssertEqual(status, errSecSuccess, "SecTrustSetAnchorCertificates should succeed")
        
        var anchorsPtr: Unmanaged<CFArray>? = nil
        SecTrustCopyCustomAnchorCertificates(serverTrust, &anchorsPtr)
        let anchors = anchorsPtr?.takeRetainedValue() as! [SecCertificateRef]
        XCTAssertEqual(anchors.count, 1, "anchors should contain the root certificate")
        
        var result = SecTrustResultType(kSecTrustResultInvalid)
        status = SecTrustEvaluate(serverTrust, &result)
        
        XCTAssertEqual(status, errSecSuccess, "None of the operations should have failed")
        XCTAssertEqual(result, SecTrustResultType(kSecTrustResultUnspecified), "Trust result should be kSecTrustResultUnspecified")
    }
    
    func testSetAnchorCanSpecifyLeaf() {
        let certificate = TestSec.chainGoodLeaf
        let policy = SecPolicyCreateSSL(1, "goodleaf" as CFString).takeRetainedValue()
        XCTAssertNotNil(policy, "policy should not be nil")
        
        var trustPtr: Unmanaged<SecTrustRef>? = nil
        SecTrustCreateWithCertificates(certificate, policy, &trustPtr)
        let serverTrust = trustPtr!.takeRetainedValue()
        
        var status = errSecSuccess
        status = SecTrustSetAnchorCertificates(serverTrust, [certificate])
        XCTAssertEqual(status, errSecSuccess, "SecTrustSetAnchorCertificates should succeed")
        
        var anchorsPtr: Unmanaged<CFArray>? = nil
        SecTrustCopyCustomAnchorCertificates(serverTrust, &anchorsPtr)
        let anchors = anchorsPtr?.takeRetainedValue() as! [SecCertificateRef]
        XCTAssertEqual(anchors.count, 1, "anchors should contain the leaf certificate")
        
        var result = SecTrustResultType(kSecTrustResultInvalid)
        status = SecTrustEvaluate(serverTrust, &result)
        
        XCTAssertEqual(status, errSecSuccess, "None of the operations should have failed")
        XCTAssertEqual(result, SecTrustResultType(kSecTrustResultUnspecified), "Trust result should be kSecTrustResultUnspecified")
    }
    
    func testPublicKeyRespondsToIsEqual() {
        let certificate = TestSec.foobar
        let key = TLSTrustPolicy.publicKeyFromCertificate(certificate)!
        let keyCastedObj: AnyObject? = key as AnyObject
        XCTAssertNotNil(keyCastedObj, "SecKeyRef is assumed to be castable to AnyObject")
        
        let keyObj: AnyObject = keyCastedObj!
        let responds = keyObj.respondsToSelector(Selector("isEqual:"))
        XCTAssertTrue(responds, "SecKeyRef is assumed to respond to isEqual selector")
    }
    
    func testPublicKeyComparison() {
        let key1: AnyObject = TLSTrustPolicy.publicKeyFromCertificate(TestSec.foobar)! as AnyObject
        XCTAssertTrue(key1.isEqual(key1), "key1 should be equal to itself")
        
        let key2: AnyObject = TLSTrustPolicy.publicKeyFromCertificate(TestSec.altname)! as AnyObject
        XCTAssertFalse(key1.isEqual(key2), "Different keys should not be equal")
    }
    
    // MARK: Certificate pinning
    func testPinningEmptyCertificateSetFails() {
        let policy = TLSTrustPolicy.PinCertificates([SecCertificateRef]())
        let serverTrust = TestSec.foobarTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: TestSec.commonHost)
        XCTAssertFalse(trusted, "PinCertificates policy with no pinned certificates should always return false")
    }
    
    func testPinningWithIncorrectHostFails() {
        let policy = TLSTrustPolicy.PinCertificates([TestSec.foobar])
        let serverTrust = TestSec.foobarTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: "")
        XCTAssertFalse(trusted, "PinCertificates policy should verify that host names match")
    }
    
    func testPinningCert() {
        let policy = TLSTrustPolicy.PinCertificates([TestSec.foobar])
        let serverTrust = TestSec.foobarTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: TestSec.commonHost)
        XCTAssertTrue(trusted, "PinCertificates policy should trust pinned cert with correct host")
    }
    
    func testPinningCertDNSDomain() {
        let policy = TLSTrustPolicy.PinCertificates([TestSec.altname])
        let serverTrust = TestSec.altnameTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: TestSec.commonHost)
        XCTAssertTrue(trusted, "PinCertificates policy should trust cert with DNS domain")
    }
    
    func testPinningCertNoDomains() {
        let policy = TLSTrustPolicy.PinCertificates([TestSec.nodomains])
        let serverTrust = TestSec.nodomainsTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: TestSec.commonHost)
        XCTAssertFalse(trusted, "PinCertificates policy should never trust cert with no domains")
    }
    
    func testPinningRootInChain() {
        let policy = TLSTrustPolicy.PinCertificates([TestSec.chainRoot])
        let serverTrust = TestSec.serverTrustForCertificates([TestSec.chainGoodLeaf])
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: "goodleaf")
        XCTAssertTrue(trusted, "PinCertificates policy should trust chain")
    }
    
    func testPinningEnforcesRootInChain() {
        let policy = TLSTrustPolicy.PinCertificates([TestSec.chainRoot])
        let serverTrust = TestSec.serverTrustForCertificates([TestSec.chainBadFakeLeaf])
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: "alamofire")
        XCTAssertFalse(trusted, "PinCertificates policy should not trust chain")
    }
    
    // MARK: Public key pinning
    func testPublicKeyExtraction() {
        let certificate = TestSec.foobar
        let key = TLSTrustPolicy.publicKeyFromCertificate(certificate)
        XCTAssertNotNil(key, "key should not be nil")
    }
    
    func testPinningEmptyKeySetFails() {
        let policy = TLSTrustPolicy.PinPublicKeys([SecKeyRef]())
        let serverTrust = TestSec.foobarTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: TestSec.commonHost)
        XCTAssertFalse(trusted, "PinPublicKeys policy with no pinned keys should always return false")
    }
    
    func testPinningKeyDoesNotEnforceHost() {
        let key = TLSTrustPolicy.publicKeyFromCertificate(TestSec.foobar)!
        let policy = TLSTrustPolicy.PinPublicKeys([key])
        let serverTrust = TestSec.foobarTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: "")
        XCTAssertTrue(trusted, "PinPublicKeys policy should not take the host name into account")
    }
    
    func testPinningKey() {
        let key = TLSTrustPolicy.publicKeyFromCertificate(TestSec.foobar)!
        let policy = TLSTrustPolicy.PinPublicKeys([key])
        let serverTrust = TestSec.foobarTrust
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: TestSec.commonHost)
        XCTAssertTrue(trusted, "PinPublicKeys policy should trust pinned key")
    }
    
    func testPinningLeafKeyInChain() {
        let key = TLSTrustPolicy.publicKeyFromCertificate(TestSec.chainGoodLeaf)!
        let policy = TLSTrustPolicy.PinPublicKeys([key])
        let serverTrust = TestSec.serverTrustForCertificates([TestSec.chainGoodLeaf, TestSec.chainRoot])
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: "")
        XCTAssertTrue(trusted, "PinPublicKeys policy should trust chain")
    }
    
    func testPinningRootKeyThwartsBadLeaf() {
        let key = TLSTrustPolicy.publicKeyFromCertificate(TestSec.chainRoot)!
        let policy = TLSTrustPolicy.PinPublicKeys([key])
        let serverTrust = TestSec.serverTrustForCertificates([TestSec.chainBadFakeLeaf, TestSec.chainRoot])
        
        let trusted = policy.evaluateTrust(serverTrust, forHost: "")
        XCTAssertFalse(trusted, "PinPublicKeys policy should not trust chain")
    }
}
