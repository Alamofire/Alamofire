//
//  AFError+OriginalErrorTests.swift
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

import Foundation
import XCTest
@testable import Alamofire

class AFErrorOriginalErrorTestCase: BaseTestCase {
    
    let testError = NSError(domain: "com.alamofire.test.error", code: -123456789, userInfo: nil)
    let retryError = NSError(domain: "com.alamofire.test.retryError", code: -1, userInfo: nil)
    let testUrl = URL(string: "http://alamofire.com")!
    
    func testAFErrorOriginalErrorForNonNestedCases() {
        XCTAssertOriginalError(for: .createUploadableFailed(error: testError))
        XCTAssertOriginalError(for: .createURLRequestFailed(error: testError))
        XCTAssertOriginalError(for: .downloadedFileMoveFailed(error: testError, source: testUrl, destination: testUrl))
        XCTAssertNoOriginalError(for: .explicitlyCancelled)
        XCTAssertNoOriginalError(for: .invalidURL(url: testUrl))
        XCTAssertOriginalError(for: .requestAdaptationFailed(error: testError))
        XCTAssertOriginalError(for: .requestRetryFailed(retryError: retryError, originalError: testError))
        XCTAssertNoOriginalError(for: .sessionDeinitialized)
        XCTAssertOriginalError(for: .sessionInvalidated(error: testError))
        XCTAssertOriginalError(for: .sessionTaskFailed(error: testError))
    }
    
    func testAFErrorOriginalErrorForMultipartEncodingFailed() {
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .bodyPartURLInvalid(url: testUrl)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .bodyPartFilenameInvalid(in: testUrl)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .bodyPartFileNotReachable(at: testUrl)))
        XCTAssertOriginalError(for: .multipartEncodingFailed(reason: .bodyPartFileNotReachableWithError(atURL: testUrl, error: testError)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .bodyPartFileIsDirectory(at: testUrl)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .bodyPartFileSizeNotAvailable(at: testUrl)))
        XCTAssertOriginalError(for: .multipartEncodingFailed(reason: .bodyPartFileSizeQueryFailedWithError(forURL: testUrl, error: testError)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .bodyPartInputStreamCreationFailed(for: testUrl)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .outputStreamCreationFailed(for: testUrl)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: testUrl)))
        XCTAssertNoOriginalError(for: .multipartEncodingFailed(reason: .outputStreamURLInvalid(url: testUrl)))
        XCTAssertOriginalError(for: .multipartEncodingFailed(reason: .outputStreamWriteFailed(error: testError)))
        XCTAssertOriginalError(for: .multipartEncodingFailed(reason: .inputStreamReadFailed(error: testError)))
    }
    
    func testAFErrorOriginalErrorForParameterEncoderFailed() {
        XCTAssertNoOriginalError(for: .parameterEncoderFailed(reason: .missingRequiredComponent(.url)))
        XCTAssertOriginalError(for: .parameterEncoderFailed(reason: .encoderFailed(error: testError)))
    }
    
    func testAFErrorOriginalErrorForParameterEncodingFailed() {
        XCTAssertNoOriginalError(for: .parameterEncodingFailed(reason: .missingURL))
        XCTAssertOriginalError(for: .parameterEncodingFailed(reason: .jsonEncodingFailed(error: testError)))
        XCTAssertOriginalError(for: .parameterEncodingFailed(reason: .customEncodingFailed(error: testError)))
    }
    
    func testAFErrorOriginalErrorForResponseValidationFailed() {
        XCTAssertNoOriginalError(for: .responseValidationFailed(reason: .dataFileNil))
        XCTAssertNoOriginalError(for: .responseValidationFailed(reason: .dataFileReadFailed(at: testUrl)))
        XCTAssertNoOriginalError(for: .responseValidationFailed(reason: .missingContentType(acceptableContentTypes: [])))
        XCTAssertNoOriginalError(for: .responseValidationFailed(reason: .unacceptableContentType(acceptableContentTypes: [], responseContentType: "")))
        XCTAssertNoOriginalError(for: .responseValidationFailed(reason: .unacceptableStatusCode(code: 123)))
        XCTAssertOriginalError(for: .responseValidationFailed(reason: .customValidationFailed(error: testError)))
    }
    
    func testAFErrorOriginalErrorForResponseSerializationFailed() {
        XCTAssertNoOriginalError(for: .responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        XCTAssertNoOriginalError(for: .responseSerializationFailed(reason: .inputFileNil))
        XCTAssertNoOriginalError(for: .responseSerializationFailed(reason: .inputFileReadFailed(at: testUrl)))
        XCTAssertNoOriginalError(for: .responseSerializationFailed(reason: .stringSerializationFailed(encoding: .ascii)))
        XCTAssertOriginalError(for: .responseSerializationFailed(reason: .jsonSerializationFailed(error: testError)))
        XCTAssertOriginalError(for: .responseSerializationFailed(reason: .decodingFailed(error: testError)))
        XCTAssertOriginalError(for: .responseSerializationFailed(reason: .customSerializationFailed(error: testError)))
        XCTAssertNoOriginalError(for: .responseSerializationFailed(reason: .invalidEmptyResponse(type: "")))
    }
    
    /**
     This test suite doesn't test trust-based logic, since I
     couldn't figure out how to create a trust object.
     */
    func testAFErrorOriginalErrorForServerTrustEvaluationFailed() {
        let policy = SecPolicyCreateBasicX509()
        let status = OSStatus()
        var trust: SecTrust?
        _ = SecTrustCreateWithCertificates([] as AnyObject, policy, &trust)
        // let output = AFError.ServerTrustFailureReason.Output("", trust, status, .deny)
        XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .noRequiredEvaluator(host: "")))
        XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .noCertificatesFound))
        XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .noPublicKeysFound))
        // XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .policyApplicationFailed(trust: trust, policy: policy, status: status)))
        XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .settingAnchorCertificatesFailed(status: status, certificates: [])))
        XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .revocationPolicyCreationFailed))
        XCTAssertOriginalError(for: .serverTrustEvaluationFailed(reason: .trustEvaluationFailed(error: testError)))
        // XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .defaultEvaluationFailed(output: output)))
        // XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .hostValidationFailed(output: output)))
        // XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .revocationCheckFailed(output: output, options: .crl)))
        // XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .certificatePinningFailed(host: "", trust: trust, pinnedCertificates: [], serverCertificates: [])))
        // XCTAssertNoOriginalError(for: .serverTrustEvaluationFailed(reason: .publicKeyPinningFailed(host: "", trust: trust, pinnedKeys: [], serverKeys: [])))
        XCTAssertOriginalError(for: .serverTrustEvaluationFailed(reason: .customEvaluationFailed(error: testError)))
    }
    
    func testAFErrorOriginalErrorForUrlRequestValidationFailed() {
        let data = "".data(using: .ascii)!
        XCTAssertNoOriginalError(for: .urlRequestValidationFailed(reason: .bodyDataInGETRequest(data)))
    }
}

private func XCTAssertOriginalError(for error: AFError) {
    guard let nsError = error.originalError as NSError? else { return XCTFail("originalError should exist for \(error)") }
    XCTAssertEqual(nsError.domain, "com.alamofire.test.error")
    XCTAssertEqual(nsError.code, -123456789)
}

private func XCTAssertNoOriginalError(for error: AFError) {
    XCTAssertNil(error.originalError, "originalError should be nil for \(error)")
}
