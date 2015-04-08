// UploadTests.swift
//
// Copyright (c) 2014–2015 Alamofire (http://alamofire.org)
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

class UploadResponseTestCase: XCTestCase {
    func testUploadRequest() {
        let URL = "http://httpbin.org/post"
        let data = "Lorem ipsum dolor sit amet".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)

        let expectation = expectationWithDescription(URL)

        Alamofire.upload(.POST, URL, data!)
                 .response { (request, response, _, error) in
                    XCTAssertNotNil(request, "request should not be nil")
                    XCTAssertNotNil(response, "response should not be nil")
                    XCTAssertNil(error, "error should be nil")

                    expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testUploadRequestWithProgress() {
        let URL = "http://httpbin.org/post"
        let data = "Lorem ipsum dolor sit amet".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)

        let expectation = expectationWithDescription(URL)

        let upload = Alamofire.upload(.POST, URL, data!)
        upload.progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            XCTAssert(bytesWritten > 0, "bytesWritten should be > 0")
            XCTAssert(totalBytesWritten > 0, "totalBytesWritten should be > 0")
            XCTAssert(totalBytesExpectedToWrite > 0, "totalBytesExpectedToWrite should be > 0")

            upload.cancel()

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}
