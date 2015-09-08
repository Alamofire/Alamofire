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

class DownloadInitializationTestCase: BaseTestCase {
    let searchPathDirectory: NSSearchPathDirectory = .CachesDirectory
    let searchPathDomain: NSSearchPathDomainMask = .UserDomainMask

    func testDownloadClassMethodWithMethodURLAndDestination() {
        // Given
        let URLString = "https://httpbin.org/"
        let destination = Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        // When
        let request = Alamofire.download(.GET, URLString, destination: destination)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.HTTPMethod ?? "", "GET", "request HTTP method should be GET")
        XCTAssertEqual(request.request?.URLString ?? "", URLString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testDownloadClassMethodWithMethodURLHeadersAndDestination() {
        // Given
        let URLString = "https://httpbin.org/"
        let destination = Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        // When
        let request = Alamofire.download(.GET, URLString, headers: ["Authorization": "123456"], destination: destination)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.HTTPMethod ?? "", "GET", "request HTTP method should be GET")
        XCTAssertEqual(request.request?.URLString ?? "", URLString, "request URL string should be equal")

        let authorizationHeader = request.request?.valueForHTTPHeaderField("Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class DownloadResponseTestCase: BaseTestCase {
    let searchPathDirectory: NSSearchPathDirectory = .CachesDirectory
    let searchPathDomain: NSSearchPathDomainMask = .UserDomainMask

    let cachesURL: NSURL = {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true).first!
        let cachesURL = NSURL(fileURLWithPath: cachesDirectory, isDirectory: true)

        return cachesURL
    }()

    var randomCachesFileURL: NSURL {
        return cachesURL.URLByAppendingPathComponent("\(NSUUID().UUIDString).json")
    }

    func testDownloadRequest() {
        // Given
        let numberOfLines = 100
        let URLString = "https://httpbin.org/stream/\(numberOfLines)"

        let destination = Alamofire.Request.suggestedDownloadDestination(
            directory: searchPathDirectory,
            domain: searchPathDomain
        )

        let expectation = expectationWithDescription("Download request should download data to file: \(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var error: ErrorType?

        // When
        Alamofire.download(.GET, URLString, destination: destination)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")

        let fileManager = NSFileManager.defaultManager()
        let directory = fileManager.URLsForDirectory(searchPathDirectory, inDomains: self.searchPathDomain)[0]

        do {
            let contents = try fileManager.contentsOfDirectoryAtURL(
                directory,
                includingPropertiesForKeys: nil,
                options: .SkipsHiddenFiles
            )

            #if os(iOS)
            let suggestedFilename = "\(numberOfLines)"
            #elseif os(OSX)
            let suggestedFilename = "\(numberOfLines).json"
            #endif

            let predicate = NSPredicate(format: "lastPathComponent = '\(suggestedFilename)'")
            let filteredContents = (contents as NSArray).filteredArrayUsingPredicate(predicate)
            XCTAssertEqual(filteredContents.count, 1, "should have one file in Documents")

            if let file = filteredContents.first as? NSURL {
                XCTAssertEqual(
                    file.lastPathComponent ?? "",
                    "\(suggestedFilename)",
                    "filename should be \(suggestedFilename)"
                )

                if let data = NSData(contentsOfURL: file) {
                    XCTAssertGreaterThan(data.length, 0, "data length should be non-zero")
                } else {
                    XCTFail("data should exist for contents of URL")
                }

                do {
                    try fileManager.removeItemAtURL(file)
                } catch {
                    XCTFail("file manager should remove item at URL: \(file)")
                }
            } else {
                XCTFail("file should not be nil")
            }
        } catch {
            XCTFail("contents should not be nil")
        }
    }

    func testDownloadRequestWithProgress() {
        // Given
        let randomBytes = 4 * 1024 * 1024
        let URLString = "https://httpbin.org/bytes/\(randomBytes)"

        let fileManager = NSFileManager.defaultManager()
        let directory = fileManager.URLsForDirectory(searchPathDirectory, inDomains: self.searchPathDomain)[0]
        let filename = "test_download_data"
        let fileURL = directory.URLByAppendingPathComponent(filename)

        let expectation = expectationWithDescription("Bytes download progress should be reported: \(URLString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var responseRequest: NSURLRequest?
        var responseResponse: NSHTTPURLResponse?
        var responseData: NSData?
        var responseError: ErrorType?

        // When
        let download = Alamofire.download(.GET, URLString) { _, _ in
            return fileURL
        }
        download.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
            let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
            byteValues.append(bytes)

            let progress = (
                completedUnitCount: download.progress.completedUnitCount,
                totalUnitCount: download.progress.totalUnitCount
            )
            progressValues.append(progress)
        }
        download.response { request, response, data, error in
            responseRequest = request
            responseResponse = response
            responseData = data
            responseError = error

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(responseRequest, "response request should not be nil")
        XCTAssertNotNil(responseResponse, "response should not be nil")
        XCTAssertNil(responseData, "response data should be nil")
        XCTAssertNil(responseError, "response error should be nil")

        XCTAssertEqual(byteValues.count, progressValues.count, "byteValues count should equal progressValues count")

        if byteValues.count == progressValues.count {
            for index in 0..<byteValues.count {
                let byteValue = byteValues[index]
                let progressValue = progressValues[index]

                XCTAssertGreaterThan(byteValue.bytes, 0, "reported bytes should always be greater than 0")
                XCTAssertEqual(
                    byteValue.totalBytes,
                    progressValue.completedUnitCount,
                    "total bytes should be equal to completed unit count"
                )
                XCTAssertEqual(
                    byteValue.totalBytesExpected,
                    progressValue.totalUnitCount,
                    "total bytes expected should be equal to total unit count"
                )
            }
        }

        if let
            lastByteValue = byteValues.last,
            lastProgressValue = progressValues.last
        {
            let byteValueFractionalCompletion = Double(lastByteValue.totalBytes) / Double(lastByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastProgressValue.0) / Double(lastProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0, "byte value fractional completion should equal 1.0")
            XCTAssertEqual(
                progressValueFractionalCompletion,
                1.0,
                "progress value fractional completion should equal 1.0"
            )
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }

        do {
            try fileManager.removeItemAtURL(fileURL)
        } catch {
            XCTFail("file manager should remove item at URL: \(fileURL)")
        }
    }

    func testDownloadRequestWithParameters() {
        // Given
        let fileURL = randomCachesFileURL
        let URLString = "https://httpbin.org/get"
        let parameters = ["foo": "bar"]
        let destination: Request.DownloadFileDestination = { _, _ in fileURL }

        let expectation = expectationWithDescription("Download request should download data to file: \(fileURL)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var error: ErrorType?

        // When
        Alamofire.download(.GET, URLString, parameters: parameters, destination: destination)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let
            data = NSData(contentsOfURL: fileURL),
            JSONObject = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)),
            JSON = JSONObject as? [String: AnyObject],
            args = JSON["args"] as? [String: String]
        {
            XCTAssertEqual(args["foo"], "bar", "foo parameter should equal bar")
        } else {
            XCTFail("args parameter in JSON should not be nil")
        }
    }

    func testDownloadRequestWithHeaders() {
        // Given
        let fileURL = randomCachesFileURL
        let URLString = "https://httpbin.org/get"
        let headers = ["Authorization": "123456"]
        let destination: Request.DownloadFileDestination = { _, _ in fileURL }

        let expectation = expectationWithDescription("Download request should download data to file: \(fileURL)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var error: ErrorType?

        // When
        Alamofire.download(.GET, URLString, headers: headers, destination: destination)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let
            data = NSData(contentsOfURL: fileURL),
            JSONObject = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)),
            JSON = JSONObject as? [String: AnyObject],
            headers = JSON["headers"] as? [String: String]
        {
            XCTAssertEqual(headers["Authorization"], "123456", "Authorization parameter should equal 123456")
        } else {
            XCTFail("headers parameter in JSON should not be nil")
        }
    }
}

// MARK: -

class DownloadResumeDataTestCase: BaseTestCase {
    let URLString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"
    let destination: Request.DownloadFileDestination = {
        let searchPathDirectory: NSSearchPathDirectory = .CachesDirectory
        let searchPathDomain: NSSearchPathDomainMask = .UserDomainMask

        return Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)
    }()

    func testThatImmediatelyCancelledDownloadDoesNotHaveResumeDataAvailable() {
        // Given
        let expectation = expectationWithDescription("Download should be cancelled")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: ErrorType?

        // When
        let download = Alamofire.download(.GET, URLString, destination: destination)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        download.cancel()

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNil(response, "response should be nil")
        XCTAssertNil(data, "data should be nil")
        XCTAssertNotNil(error, "error should not be nil")

        XCTAssertNil(download.resumeData, "resume data should be nil")
    }

    func testThatCancelledDownloadResponseDataMatchesResumeData() {
        // Given
        let expectation = expectationWithDescription("Download should be cancelled")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: ErrorType?

        // When
        let download = Alamofire.download(.GET, URLString, destination: destination)
        download.progress { _, _, _ in
            download.cancel()
        }
        download.response { responseRequest, responseResponse, responseData, responseError in
            request = responseRequest
            response = responseResponse
            data = responseData
            error = responseError

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNotNil(error, "error should not be nil")

        XCTAssertNotNil(download.resumeData, "resume data should not be nil")

        if let
            responseData = data as? NSData,
            resumeData = download.resumeData
        {
            XCTAssertEqual(responseData, resumeData, "response data should equal resume data")
        } else {
            XCTFail("response data or resume data was unexpectedly nil")
        }
    }

    func testThatCancelledDownloadResumeDataIsAvailableWithJSONResponseSerializer() {
        // Given
        let expectation = expectationWithDescription("Download should be cancelled")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<AnyObject>!

        // When
        let download = Alamofire.download(.GET, URLString, destination: destination)
        download.progress { _, _, _ in
            download.cancel()
        }
        download.responseJSON { responseRequest, responseResponse, responseResult in
            request = responseRequest
            response = responseResponse
            result = responseResult

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")

        XCTAssertTrue(result.isFailure, "result should be a failure")
        XCTAssertNotNil(result.data, "data should not be nil")
        XCTAssertTrue(result.error != nil, "error should not be nil")

        XCTAssertNotNil(download.resumeData, "resume data should not be nil")
    }
}
