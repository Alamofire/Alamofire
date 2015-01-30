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
    
    let spDirectory : NSSearchPathDirectory  = .DocumentDirectory
    let spDomain    : NSSearchPathDomainMask = .UserDomainMask
    
    let fileManager =  NSFileManager.defaultManager()
    
    let baseURL = "http://httpbin.org/stream/"
    let numberOfLines = 100
    
    override func tearDown() {
        removeDownloadedFile()
    }
    
    // MARK: Test
    
    func testDownloadRequest() {
        
        alamofireDownloadFileWithResponse { [unowned self] request, response, _, error in
            
            self.assertNotNilResponse(response)
            self.assertNilError(error)
            self.assertDownloadedFileExist()
            self.assertDownloadedFileContainsData(self.downloadedFileContent())
        }
    }
    
    func testDownloadRequestWithProgress() {
        
        let URL = requestUrl()
        
        let expectation = expectationWithDescription(URL)
        
        let destination = Alamofire.Request.suggestedDownloadDestination(directory: spDirectory, domain: spDomain)
        
        let download = Alamofire.download(.GET, URL, destination)
        download.progress { (bytesRead, totalBytesRead, totalBytesExpectedToRead) in
            expectation.fulfill()
            
            XCTAssert(bytesRead > 0, "bytesRead should be > 0")
            XCTAssert(totalBytesRead > 0, "totalBytesRead should be > 0")
            XCTAssert(totalBytesExpectedToRead == -1, "totalBytesExpectedToRead should be -1")
            
            download.cancel()
        }
        
        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }
    
    // MARK: - Assert
    
    func assertNotNilResponse(response: AnyObject?) {
        XCTAssertNotNil(response, "Response should not be nil")
    }
    
    func assertNilError(error: NSError?) {
        XCTAssertNil(error, "Error should be nil")
    }
    
    func assertDownloadedFileExist() {
        XCTAssertNotNil(urlToDownloadedFile(), "No file with name \(self.numberOfLines)")
    }
    
    func assertDownloadedFileContainsData(data: NSData?) {
        if let d = data {
            XCTAssertGreaterThan(d.length, 0, "Data length should be non-zero")
        } else {
            XCTFail("No data for downloaded file")
        }
    }
    
    // MARK: - Download
    func alamofireDownloadFileWithResponse(closure:
        (request: NSURLRequest, response: NSHTTPURLResponse?, object: AnyObject?, error: NSError?) -> ()) {
            
            let URL = requestUrl()
            
            let expectation = expectationWithDescription(URL)
            
            let destination = Alamofire.Request.suggestedDownloadDestination(directory: spDirectory, domain: spDomain)
            
            Alamofire.download(.GET, URL, destination).response {request, response, _, error in
                
                expectation.fulfill()
                
                closure(request: request, response: response, object: nil, error: error)
            }
            
            waitForExpectationsWithTimeout(10) { (error) in
                XCTAssertNil(error, "\(error)")
            }
    }
    
    // MARK: -
    
    func requestUrl() -> String {
        return "\(baseURL)\(numberOfLines)"
    }
    
    func downloadsDirectory() -> NSURL {
        return self.fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as NSURL
    }
    
    func contentsOfDownloadsDirectory() -> [AnyObject]? {
        return fileManager.contentsOfDirectoryAtURL(downloadsDirectory(),
            includingPropertiesForKeys: nil, options: .SkipsHiddenFiles, error: nil)!
    }
    
    func urlToDownloadedFile() -> NSURL? {
        let filtered = contentsOfDownloadsDirectory()?.filter { [unowned self]
            url in (url.lastPathComponent == "\(self.numberOfLines)")
        }
        return filtered?.first as? NSURL
    }
    
    func downloadedFileContent() -> NSData? {
        if let url = self.urlToDownloadedFile() {
            return NSData(contentsOfURL: url)
        }
        return nil
    }
    
    func removeDownloadedFile() {
        contentsOfDownloadsDirectory()?.map{ [unowned self] file in
            self.fileManager.removeItemAtURL(file as NSURL, error: nil)
        }
    }
}
