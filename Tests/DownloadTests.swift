// DownloadTests.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
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
    func testDownloadRequest() {
        let numberOfLines = 100
        let URL = "http://httpbin.org/stream/\(numberOfLines)"

        let expectation = expectationWithDescription(URL)

        Alamofire.download(.GET, URL, Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask))
            .response { request, response, _, error in
                expectation.fulfill()

                XCTAssertNotNil(request, "request should not be nil")
                XCTAssertNotNil(response, "response should not be nil")

                XCTAssertNil(error, "error should be nil")

                let fileManager = NSFileManager.defaultManager()
                var fileManagerError: NSError?
                let directory = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
//                    let contents = fileManager.contentsOfDirectoryAtURL(directory, includingPropertiesForKeys: nil, options: , error: &fileManagerError) as NSArray

                let contents = fileManager.contentsOfDirectoryAtURL(directory, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, error: &fileManagerError)!

                XCTAssertNil(fileManagerError, "fileManagerError should be nil")

//                    let predicate = NSPredicate(format: "lastPathComponent = '\(numberOfLines)'")
//                    let filteredContents = contents.filteredArrayUsingPredicate(predicate)

//                XCTAssertEqual(filteredContents.count, 1, "should have one file in Documents")
//
//                let file = filteredContents[0] as NSURL
//                XCTAssertEqual(file.lastPathComponent!, "\(numberOfLines)", "filename should be \(numberOfLines)")
//
//                let data = NSData(contentsOfURL: file)
//                XCTAssertGreaterThan(data.length, 0, "data length should be non-zero")
        }

        waitForExpectationsWithTimeout(10){ error in
            XCTAssertNil(error, "\(error)")
        }
    }
}
