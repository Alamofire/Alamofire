// UploadTests.swift
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

import Alamofire
import Foundation
import XCTest

class UploadResponseTestCase: BaseTestCase {
    func testUploadRequest() {
        // Given
        let URL = "http://httpbin.org/post"
        let data = "Lorem ipsum dolor sit amet".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let expectation = expectationWithDescription(URL)

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.upload(.POST, URL, data)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")
    }

    func testUploadRequestWithProgress() {
        // Given
        let URL = "http://httpbin.org/post"
        let data = "Lorem ipsum dolor sit amet".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let expectation = expectationWithDescription(URL)

        var bytesWritten: Int64?
        var totalBytesWritten: Int64?
        var totalBytesExpectedToWrite: Int64?

        // When
        let upload = Alamofire.upload(.POST, URL, data)
        upload.progress { progressBytesWritten, progressTotalBytesWritten, progressTotalBytesExpectedToWrite in
            bytesWritten = progressBytesWritten
            totalBytesWritten = progressTotalBytesWritten
            totalBytesExpectedToWrite = progressTotalBytesExpectedToWrite

            upload.cancel()

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertGreaterThan(bytesWritten ?? 0, 0, "bytesWritten should be > 0")
        XCTAssertGreaterThan(totalBytesWritten ?? 0, 0, "totalBytesWritten should be > 0")
        XCTAssertGreaterThan(totalBytesExpectedToWrite ?? 0, 0, "totalBytesExpectedToWrite should be > 0")
    }
}
