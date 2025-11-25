//
//  AFErrorURLTests.swift
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

final class AFErrorURLTestCase: BaseTestCase {
    func testThatSessionTaskFailedWithURLErrorContainingFailingURLReturnsURL() {
        // Given
        let failingURL = URL(string: "https://example.com/api/endpoint")!
        // Create URLError with failingURL in userInfo (as URLSession does)
        let urlError = URLError(.networkConnectionLost, userInfo: [NSURLErrorFailingURLErrorKey: failingURL])
        let error = AFError.sessionTaskFailed(error: urlError)

        // When
        let url = error.url

        // Then
        XCTAssertNotNil(url, "URL should not be nil when URLError contains failingURL")
        XCTAssertEqual(url, failingURL, "URL should match the failingURL from URLError")
    }

    func testThatSessionTaskFailedWithURLErrorWithoutFailingURLReturnsNil() {
        // Given
        let urlError = URLError(.networkConnectionLost)
        let error = AFError.sessionTaskFailed(error: urlError)

        // When
        let url = error.url

        // Then
        XCTAssertNil(url, "URL should be nil when URLError doesn't contain failingURL")
    }

    func testThatSessionTaskFailedWithNonURLErrorReturnsNil() {
        // Given
        let customError = NSError(domain: "CustomErrorDomain", code: 123, userInfo: nil)
        let error = AFError.sessionTaskFailed(error: customError)

        // When
        let url = error.url

        // Then
        XCTAssertNil(url, "URL should be nil when error is not a URLError")
    }

    func testThatMultipartEncodingFailedStillReturnsURL() {
        // Given
        let fileURL = URL(string: "file:///path/to/file.jpg")!
        let reason = AFError.MultipartEncodingFailureReason.bodyPartURLInvalid(url: fileURL)
        let error = AFError.multipartEncodingFailed(reason: reason)

        // When
        let url = error.url

        // Then
        XCTAssertEqual(url, fileURL, "URL should match the fileURL from multipart encoding failure reason")
    }

    func testThatOtherErrorCasesReturnNil() {
        // Given
        let errors: [AFError] = [
            .explicitlyCancelled,
            .invalidURL(url: "invalid"),
            .sessionDeinitialized,
            .parameterEncodingFailed(reason: .missingURL),
            .requestAdaptationFailed(error: NSError(domain: "Test", code: 1, userInfo: nil)),
            .responseValidationFailed(reason: .dataFileNil),
            .responseSerializationFailed(reason: .inputDataNilOrZeroLength),
            .urlRequestValidationFailed(reason: .bodyDataInGETRequest(Data()))
        ]

        // When & Then
        for error in errors {
            XCTAssertNil(error.url, "URL should be nil for \(error)")
        }
    }
}

