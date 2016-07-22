//
//  DownloadTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

class DownloadInitializationTestCase: BaseTestCase {
    let searchPathDirectory: FileManager.SearchPathDirectory = .cachesDirectory
    let searchPathDomain: FileManager.SearchPathDomainMask = .userDomainMask

    func testDownloadClassMethodWithMethodURLAndDestination() {
        // Given
        let urlString = "https://httpbin.org/"
        let destination = Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        // When
        let request = Alamofire.download(.GET, urlString, destination: destination)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "GET", "request HTTP method should be GET")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testDownloadClassMethodWithMethodURLHeadersAndDestination() {
        // Given
        let urlString = "https://httpbin.org/"
        let destination = Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)

        // When
        let request = Alamofire.download(.GET, urlString, headers: ["Authorization": "123456"], destination: destination)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "GET", "request HTTP method should be GET")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class DownloadResponseTestCase: BaseTestCase {
    let searchPathDirectory: FileManager.SearchPathDirectory = .cachesDirectory
    let searchPathDomain: FileManager.SearchPathDomainMask = .userDomainMask

    let cachesURL: URL = {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let cachesURL = URL(fileURLWithPath: cachesDirectory, isDirectory: true)

        return cachesURL
    }()

    var randomCachesFileURL: URL {
        return try! cachesURL.appendingPathComponent("\(UUID().uuidString).json")
    }

    func testDownloadRequest() {
        // Given
        let numberOfLines = 100
        let urlString = "https://httpbin.org/stream/\(numberOfLines)"

        let destination = Alamofire.Request.suggestedDownloadDestination(
            directory: searchPathDirectory,
            domain: searchPathDomain
        )

        let expectation = self.expectation(description: "Download request should download data to file: \(urlString)")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.download(.GET, urlString, destination: destination)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")

        let fileManager = FileManager.default
        let directory = fileManager.urlsForDirectory(searchPathDirectory, inDomains: self.searchPathDomain)[0]

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            #if os(iOS) || os(tvOS)
            let suggestedFilename = "\(numberOfLines)"
            #elseif os(OSX)
            let suggestedFilename = "\(numberOfLines).json"
            #endif

            let predicate = Predicate(format: "lastPathComponent = '\(suggestedFilename)'")
            let filteredContents = (contents as NSArray).filtered(using: predicate)
            XCTAssertEqual(filteredContents.count, 1, "should have one file in Documents")

            if let file = filteredContents.first as? URL {
                XCTAssertEqual(
                    file.lastPathComponent ?? "",
                    "\(suggestedFilename)",
                    "filename should be \(suggestedFilename)"
                )

                if let data = try? Data(contentsOf: file) {
                    XCTAssertGreaterThan(data.count, 0, "data length should be non-zero")
                } else {
                    XCTFail("data should exist for contents of URL")
                }

                do {
                    try fileManager.removeItem(at: file)
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
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let fileManager = FileManager.default
        let directory = fileManager.urlsForDirectory(searchPathDirectory, inDomains: self.searchPathDomain)[0]
        let filename = "test_download_data"
        let fileURL = try! directory.appendingPathComponent(filename)

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var responseRequest: URLRequest?
        var responseResponse: HTTPURLResponse?
        var responseData: Data?
        var responseError: ErrorProtocol?

        // When
        let download = Alamofire.download(.GET, urlString) { _, _ in
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

        waitForExpectations(timeout: timeout, handler: nil)

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

        if let lastByteValue = byteValues.last,
           let lastProgressValue = progressValues.last
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
            try fileManager.removeItem(at: fileURL)
        } catch {
            XCTFail("file manager should remove item at URL: \(fileURL)")
        }
    }

    func testDownloadRequestWithParameters() {
        // Given
        let fileURL = randomCachesFileURL
        let urlString = "https://httpbin.org/get"
        let parameters = ["foo": "bar"]
        let destination: Request.DownloadFileDestination = { _, _ in fileURL }

        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.download(.GET, urlString, parameters: parameters, destination: destination)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let data = try? Data(contentsOf: fileURL),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)),
           let json = jsonObject as? [String: AnyObject],
           let args = json["args"] as? [String: String]
        {
            XCTAssertEqual(args["foo"], "bar", "foo parameter should equal bar")
        } else {
            XCTFail("args parameter in JSON should not be nil")
        }
    }

    func testDownloadRequestWithHeaders() {
        // Given
        let fileURL = randomCachesFileURL
        let urlString = "https://httpbin.org/get"
        let headers = ["Authorization": "123456"]
        let destination: Request.DownloadFileDestination = { _, _ in fileURL }

        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.download(.GET, urlString, headers: headers, destination: destination)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let data = try? Data(contentsOf: fileURL),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)),
           let json = jsonObject as? [String: AnyObject],
           let headers = json["headers"] as? [String: String]
        {
            XCTAssertEqual(headers["Authorization"], "123456", "Authorization parameter should equal 123456")
        } else {
            XCTFail("headers parameter in JSON should not be nil")
        }
    }
}

// MARK: -

class DownloadResumeDataTestCase: BaseTestCase {
    let urlString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"
    let destination: Request.DownloadFileDestination = {
        let searchPathDirectory: FileManager.SearchPathDirectory = .cachesDirectory
        let searchPathDomain: FileManager.SearchPathDomainMask = .userDomainMask

        return Request.suggestedDownloadDestination(directory: searchPathDirectory, domain: searchPathDomain)
    }()

    func testThatImmediatelyCancelledDownloadDoesNotHaveResumeDataAvailable() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        let download = Alamofire.download(.GET, urlString, destination: destination)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        download.cancel()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNil(response, "response should be nil")
        XCTAssertNil(data, "data should be nil")
        XCTAssertNotNil(error, "error should not be nil")

        XCTAssertNil(download.resumeData, "resume data should be nil")
    }

    func testThatCancelledDownloadResponseDataMatchesResumeData() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        let download = Alamofire.download(.GET, urlString, destination: destination)
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

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNotNil(error, "error should not be nil")

        XCTAssertNotNil(download.resumeData, "resume data should not be nil")

        if let responseData = data as? Data,
           let resumeData = download.resumeData
        {
            XCTAssertEqual(responseData, resumeData, "response data should equal resume data")
        } else {
            XCTFail("response data or resume data was unexpectedly nil")
        }
    }

    func testThatCancelledDownloadResumeDataIsAvailableWithJSONResponseSerializer() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var response: Response<AnyObject, NSError>?

        // When
        let download = Alamofire.download(.GET, urlString, destination: destination)
        download.progress { _, _, _ in
            download.cancel()
        }
        download.responseJSON { closureResponse in
            response = closureResponse
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isFailure, "result should be failure")
            XCTAssertNotNil(response.result.error, "result error should not be nil")
        } else {
            XCTFail("response should not be nil")
        }

        XCTAssertNotNil(download.resumeData, "resume data should not be nil")
    }
}
