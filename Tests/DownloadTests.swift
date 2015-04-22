// DownloadTests.swift
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

class AlamofireDownloadResponseTestCase: XCTestCase {
    let searchPathDirectory: NSSearchPathDirectory = .DocumentDirectory
    let searchPathDomain: NSSearchPathDomainMask = .UserDomainMask

    // MARK: -

    func testDownloadRequest() {
        let numberOfLines = 100
        let URL = "http://httpbin.org/stream/\(numberOfLines)"

        let expectation = expectationWithDescription(URL)

        let destination = Alamofire.Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        Alamofire.download(.GET, URL, destination)
            .response { request, response, _, error in
                XCTAssertNotNil(request, "request should not be nil")
                XCTAssertNotNil(response, "response should not be nil")

                XCTAssertNil(error, "error should be nil")

                let fileManager = NSFileManager.defaultManager()
                let directory = fileManager.URLsForDirectory(self.searchPathDirectory, inDomains: self.searchPathDomain)[0] as! NSURL

                var fileManagerError: NSError?
                let contents = fileManager.contentsOfDirectoryAtURL(directory, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, error: &fileManagerError)!
                XCTAssertNil(fileManagerError, "fileManagerError should be nil")

                #if os(iOS)
                let suggestedFilename = "\(numberOfLines)"
                #elseif os(OSX)
                let suggestedFilename = "\(numberOfLines).json"
                #endif

                let predicate = NSPredicate(format: "lastPathComponent = '\(suggestedFilename)'")
                let filteredContents = (contents as NSArray).filteredArrayUsingPredicate(predicate)
                XCTAssertEqual(filteredContents.count, 1, "should have one file in Documents")

                let file = filteredContents.first as! NSURL
                XCTAssertEqual(file.lastPathComponent!, "\(suggestedFilename)", "filename should be \(suggestedFilename)")

                if let data = NSData(contentsOfURL: file) {
                    XCTAssertGreaterThan(data.length, 0, "data length should be non-zero")
                } else {
                    XCTFail("data should exist for contents of URL")
                }

                fileManager.removeItemAtURL(file, error: nil)

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testDownloadRequestWithProgress() {
        let numberOfLines = 100
        let URL = "http://httpbin.org/stream/\(numberOfLines)"

        let expectation = expectationWithDescription(URL)

        let destination = Alamofire.Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        let download = Alamofire.download(.GET, URL, destination)
        download.progress { (bytesRead, totalBytesRead, totalBytesExpectedToRead) -> Void in
            XCTAssert(bytesRead > 0, "bytesRead should be > 0")
            XCTAssert(totalBytesRead > 0, "totalBytesRead should be > 0")
            XCTAssert(totalBytesExpectedToRead == -1, "totalBytesExpectedToRead should be -1")

            download.cancel()

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
}
