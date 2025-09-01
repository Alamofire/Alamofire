//
//  AFErrorURLExtractionTests.swift
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

final class AFErrorURLExtractionTests: XCTestCase {
    
    // MARK: - multipartEncodingFailed

    func testMultipartEncodingFailedWithURL() {
        // Given
        let httpURL = URL(string: "https://example.com/image.jpg")!
        let reason = AFError.MultipartEncodingFailureReason.bodyPartURLInvalid(url: httpURL)
        
        // When
        let error = AFError.multipartEncodingFailed(reason: reason)
        
        // Then
        XCTAssertEqual(error.url, httpURL)
    }
    
    func testMultipartEncodingFailedWithoutURL() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let reason = AFError.MultipartEncodingFailureReason.outputStreamWriteFailed(error: underlyingError)
        
        // When
        let error = AFError.multipartEncodingFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - responseValidationFailed

    func testResponseValidationFailedWithURL() {
        // Given
        let fileURL = URL(fileURLWithPath: "/tmp/response_data.json")
        let reason = AFError.ResponseValidationFailureReason.dataFileReadFailed(at: fileURL)
        
        // When
        let error = AFError.responseValidationFailed(reason: reason)
        
        // Then
        XCTAssertEqual(error.url, fileURL)
    }
    
    func testResponseValidationFailedWithoutURL() {
        // Given
        let reason = AFError.ResponseValidationFailureReason.dataFileNil
        
        // When
        let error = AFError.responseValidationFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - responseSerializationFailed

    func testResponseSerializationFailedWithURL() {
        // Given
        let fileURL = URL(fileURLWithPath: "/tmp/response.json")
        let reason = AFError.ResponseSerializationFailureReason.inputFileReadFailed(at: fileURL)
        
        // When
        let error = AFError.responseSerializationFailed(reason: reason)
        
        // Then
        XCTAssertEqual(error.url, fileURL)
    }
    
    func testResponseSerializationFailedWithoutURL() {
        // Given
        let reason = AFError.ResponseSerializationFailureReason.inputDataNilOrZeroLength
        
        // When
        let error = AFError.responseSerializationFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - invalidURL

    func testInvalidURLWithInvalidString() {
        // Given
        let invalidString = ""  // Empty string cannot create valid URL
        
        // When
        let error = AFError.invalidURL(url: invalidString)
        
        // Then
        XCTAssertNil(error.url)  // invalidURL error means URL is invalid
    }
    
    func testInvalidURLWithInvalidURLComponents() {
        // Given
        var components = URLComponents()
        components.scheme = "http"
        // Missing host makes URLComponents.url nil, causing asURL() to throw
        
        // When
        let error = AFError.invalidURL(url: components)
        
        // Then
        XCTAssertNil(error.url)  // invalidURL error means URL is invalid
    }

    // MARK: - sessionTaskFailed

    func testSessionTaskFailedWithURLError() {
        // Given
        let requestURL = URL.nonexistentDomain
        let urlError = URLError(.notConnectedToInternet, userInfo: [NSURLErrorFailingURLErrorKey: requestURL])
        
        // When
        let error = AFError.sessionTaskFailed(error: urlError)
        
        // Then
        XCTAssertEqual(error.url, requestURL)
    }
    
    func testSessionTaskFailedWithoutURL() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        
        // When
        let error = AFError.sessionTaskFailed(error: underlyingError)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - sessionInvalidated

    func testSessionInvalidatedWithURLError() {
        // Given
        let requestURL = URL.nonexistentDomain
        let urlError = URLError(.networkConnectionLost, userInfo: [NSURLErrorFailingURLErrorKey: requestURL])
        
        // When
        let error = AFError.sessionInvalidated(error: urlError)
        
        // Then
        XCTAssertEqual(error.url, requestURL)
    }
    
    func testSessionInvalidatedWithNilError() {
        // Given
        // When
        let error = AFError.sessionInvalidated(error: nil)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testSessionInvalidatedWithNonURLError() {
        // Given
        let underlyingError = NSError(domain: "SessionDomain", code: 2, userInfo: nil)
        
        // When
        let error = AFError.sessionInvalidated(error: underlyingError)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - requestAdaptationFailed

    func testRequestAdaptationFailedWithCustomError() {
        // Given
        let adaptationError = NSError(domain: "AdapterDomain", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        
        // When
        let error = AFError.requestAdaptationFailed(error: adaptationError)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testRequestAdaptationFailedWithURLError() {
        // Given
        let requestURL = URL.nonexistentDomain
        let urlError = URLError(.badURL, userInfo: [NSURLErrorFailingURLErrorKey: requestURL])
        
        // When
        let error = AFError.requestAdaptationFailed(error: urlError)
        
        // Then
        XCTAssertEqual(error.url, requestURL)
    }

    // MARK: - requestRetryFailed

    func testRequestRetryFailedWithURLInOriginalError() {
        // Given
        let requestURL = URL.nonexistentDomain
        let originalError = URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: requestURL])
        let retryError = NSError(domain: "RetryDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "Token refresh failed"])
        
        // When
        let error = AFError.requestRetryFailed(retryError: retryError, originalError: originalError)
        
        // Then
        XCTAssertEqual(error.url, requestURL)
    }
    
    func testRequestRetryFailedWithURLInRetryError() {
        // Given
        let retryURL = URL.nonexistentDomain
        let originalError = NSError(domain: "NetworkDomain", code: 100, userInfo: nil)
        let retryError = URLError(.badURL, userInfo: [NSURLErrorFailingURLErrorKey: retryURL])
        
        // When
        let error = AFError.requestRetryFailed(retryError: retryError, originalError: originalError)
        
        // Then
        XCTAssertEqual(error.url, retryURL)
    }
    
    func testRequestRetryFailedWithoutURL() {
        // Given
        let originalError = NSError(domain: "NetworkDomain", code: 100, userInfo: nil)
        let retryError = NSError(domain: "RetryDomain", code: 500, userInfo: nil)
        
        // When
        let error = AFError.requestRetryFailed(retryError: retryError, originalError: originalError)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testRequestRetryFailedWithURLInBothErrors() {
        // Given
        let originalURL = URL.nonexistentDomain
        let retryURL = URL(string: "https://retry.example.com")!
        let originalError = URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: originalURL])
        let retryError = URLError(.badURL, userInfo: [NSURLErrorFailingURLErrorKey: retryURL])
        
        // When
        let error = AFError.requestRetryFailed(retryError: retryError, originalError: originalError)
        
        // Then
        XCTAssertEqual(error.url, originalURL)  // Should prefer originalError's URL
    }

    // MARK: - downloadedFileMoveFailed

    func testDownloadedFileMoveFailedURLIsNil() {
        // Given
        let sourceURL = FileManager.temporaryDirectoryURL.appendingPathComponent("download.tmp")
        let destinationURL = FileManager.temporaryDirectoryURL.appendingPathComponent("file.pdf")
        let moveError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: nil)
        
        // When
        let error = AFError.downloadedFileMoveFailed(error: moveError, source: sourceURL, destination: destinationURL)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testDownloadedFileMoveFailedWithURLErrorStillReturnsNil() {
        // Given
        let sourceURL = FileManager.temporaryDirectoryURL.appendingPathComponent("download.tmp")
        let destinationURL = FileManager.temporaryDirectoryURL.appendingPathComponent("file.pdf")
        let urlError = URLError(.fileDoesNotExist, userInfo: [NSURLErrorFailingURLErrorKey: sourceURL])
        
        // When
        let error = AFError.downloadedFileMoveFailed(error: urlError, source: sourceURL, destination: destinationURL)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - createURLRequestFailed

    func testCreateURLRequestFailedURLIsNil() {
        // Given
        let encodingError = NSError(domain: "EncodingDomain", code: 400, userInfo: [NSLocalizedDescriptionKey: "Parameter encoding failed"])
        
        // When
        let error = AFError.createURLRequestFailed(error: encodingError)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testCreateURLRequestFailedWithURLErrorStillReturnsNil() {
        // Given
        let requestURL = URL.nonexistentDomain
        let urlError = URLError(.badURL, userInfo: [NSURLErrorFailingURLErrorKey: requestURL])
        
        // When
        let error = AFError.createURLRequestFailed(error: urlError)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - createUploadableFailed

    func testCreateUploadableFailedURLIsNil() {
        // Given
        let uploadError = NSError(domain: "UploadDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "File upload preparation failed"])
        
        // When
        let error = AFError.createUploadableFailed(error: uploadError)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testCreateUploadableFailedWithURLErrorStillReturnsNil() {
        // Given
        let fileURL = URL(fileURLWithPath: "/tmp/upload_file.txt")
        let urlError = URLError(.fileDoesNotExist, userInfo: [NSURLErrorFailingURLErrorKey: fileURL])
        
        // When
        let error = AFError.createUploadableFailed(error: urlError)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - parameterEncoderFailed

    func testParameterEncoderFailedURLIsNil() {
        // Given
        let reason = AFError.ParameterEncoderFailureReason.missingRequiredComponent(.url)
        
        // When
        let error = AFError.parameterEncoderFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testParameterEncoderFailedWithErrorStillReturnsNil() {
        // Given
        let encodingError = NSError(domain: "EncoderDomain", code: 100, userInfo: [NSLocalizedDescriptionKey: "Custom encoding failed"])
        let reason = AFError.ParameterEncoderFailureReason.encoderFailed(error: encodingError)
        
        // When
        let error = AFError.parameterEncoderFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - parameterEncodingFailed

    func testParameterEncodingFailedURLIsNil() {
        // Given
        let reason = AFError.ParameterEncodingFailureReason.missingURL
        
        // When
        let error = AFError.parameterEncodingFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testParameterEncodingFailedWithErrorStillReturnsNil() {
        // Given
        let jsonError = NSError(domain: NSCocoaErrorDomain, code: 3840, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        let reason = AFError.ParameterEncodingFailureReason.jsonEncodingFailed(error: jsonError)
        
        // When
        let error = AFError.parameterEncodingFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - serverTrustEvaluationFailed

    #if canImport(Security)
    func testServerTrustEvaluationFailedURLIsNil() {
        // Given
        let reason = AFError.ServerTrustFailureReason.noRequiredEvaluator(host: "example.com")
        
        // When
        let error = AFError.serverTrustEvaluationFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }
    
    func testServerTrustEvaluationFailedWithErrorStillReturnsNil() {
        // Given
        let trustError = NSError(domain: "SecurityDomain", code: -9802, userInfo: [NSLocalizedDescriptionKey: "Certificate validation failed"])
        let reason = AFError.ServerTrustFailureReason.trustEvaluationFailed(error: trustError)
        
        // When
        let error = AFError.serverTrustEvaluationFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }
    #endif

    // MARK: - explicitlyCancelled

    func testExplicitlyCancelledURLIsNil() {
        // Given
        // When
        let error = AFError.explicitlyCancelled
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - sessionDeinitialized

    func testSessionDeinitializedURLIsNil() {
        // Given
        // When
        let error = AFError.sessionDeinitialized
        
        // Then
        XCTAssertNil(error.url)
    }

    // MARK: - urlRequestValidationFailed

    func testURLRequestValidationFailedURLIsNil() {
        // Given
        let invalidBodyData = "invalid body in GET".data(using: .utf8)!
        let reason = AFError.URLRequestValidationFailureReason.bodyDataInGETRequest(invalidBodyData)
        
        // When
        let error = AFError.urlRequestValidationFailed(reason: reason)
        
        // Then
        XCTAssertNil(error.url)
    }
}
