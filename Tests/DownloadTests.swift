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

import Alamofire
import Foundation
import XCTest

class DownloadResponseTestCase: BaseTestCase {
    // MARK: - Properties

    let searchPathDirectory: NSSearchPathDirectory = .CachesDirectory
    let searchPathDomain: NSSearchPathDomainMask = .UserDomainMask

    // MARK: - Tests

    func testDownloadRequest() {
        // Given
        let numberOfLines = 100
        let URL = "http://httpbin.org/stream/\(numberOfLines)"

        let destination = Alamofire.Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        let expectation = expectationWithDescription(URL)

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.download(.GET, URL, destination)
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

        let fileManager = NSFileManager.defaultManager()
        let directory = fileManager.URLsForDirectory(self.searchPathDirectory, inDomains: self.searchPathDomain)[0] as! NSURL

        var fileManagerError: NSError?
        if let contents = fileManager.contentsOfDirectoryAtURL(directory, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles, error: &fileManagerError) {
            XCTAssertNil(fileManagerError, "fileManagerError should be nil")

            #if os(iOS)
            let suggestedFilename = "\(numberOfLines)"
            #elseif os(OSX)
            let suggestedFilename = "\(numberOfLines).json"
            #endif

            let predicate = NSPredicate(format: "lastPathComponent = '\(suggestedFilename)'")
            let filteredContents = (contents as NSArray).filteredArrayUsingPredicate(predicate)
            XCTAssertEqual(filteredContents.count, 1, "should have one file in Documents")

            if let file = filteredContents.first as? NSURL {
                XCTAssertEqual(file.lastPathComponent ?? "", "\(suggestedFilename)", "filename should be \(suggestedFilename)")

                if let data = NSData(contentsOfURL: file) {
                    XCTAssertGreaterThan(data.length, 0, "data length should be non-zero")
                } else {
                    XCTFail("data should exist for contents of URL")
                }

                fileManager.removeItemAtURL(file, error: nil)
            } else {
                XCTFail("file should not be nil")
            }
        } else {
            XCTFail("contents should not be nil")
        }
    }

    func testDownloadRequestWithProgress() {
        // Given
        let numberOfLines = 100
        let URL = "http://httpbin.org/stream/\(numberOfLines)"

        let destination = Alamofire.Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        let expectation = expectationWithDescription(URL)

        var bytesRead: Int64?
        var totalBytesRead: Int64?
        var totalBytesExpectedToRead: Int64?

        // When
        let download = Alamofire.download(.GET, URL, destination)
        download.progress { progressBytesRead, progressTotalBytesRead, progressTotalBytesExpectedToRead in
            bytesRead = progressBytesRead
            totalBytesRead = progressTotalBytesRead
            totalBytesExpectedToRead = progressTotalBytesExpectedToRead

            download.cancel()

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertGreaterThan(bytesRead ?? 0, 0, "bytesRead should be > 0")
        XCTAssertGreaterThan(totalBytesRead ?? 0, 0, "totalBytesRead should be > 0")
        XCTAssertEqual(totalBytesExpectedToRead ?? 0, -1, "totalBytesExpectedToRead should be -1")
    }
}
