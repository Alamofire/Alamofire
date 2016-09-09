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

        // When
        let request = Alamofire.download(urlString)

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertEqual(request.request?.url?.urlString, urlString)
        XCTAssertNil(request.response)
    }

    func testDownloadClassMethodWithMethodURLHeadersAndDestination() {
        // Given
        let urlString = "https://httpbin.org/"
        let headers = ["Authorization": "123456"]

        // When
        let request = Alamofire.download(urlString, headers: headers)

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertEqual(request.request?.url?.urlString, urlString)
        XCTAssertEqual(request.request?.value(forHTTPHeaderField: "Authorization"), "123456")
        XCTAssertNil(request.response)
    }
}

// MARK: -

class DownloadResponseTestCase: BaseTestCase {
    private var randomCachesFileURL: URL {
        return FileManager.cachesDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
    }

    func testDownloadRequest() {
        // Given
        let fileURL = randomCachesFileURL
        let numberOfLines = 100
        let urlString = "https://httpbin.org/stream/\(numberOfLines)"
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in (fileURL, []) }

        let expectation = self.expectation(description: "Download request should download data to file: \(urlString)")
        var response: DefaultDownloadResponse?

        // When
        Alamofire.download(urlString, to: destination)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        if let destinationURL = response?.destinationURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))

            if let data = try? Data(contentsOf: destinationURL) {
                XCTAssertGreaterThan(data.count, 0)
            } else {
                XCTFail("data should exist for contents of destinationURL")
            }
        }
    }

    func testDownloadRequestWithProgress() {
        // Given
        let randomBytes = 4 * 1024 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var response: DefaultDownloadResponse?

        // When
        Alamofire.download(urlString)
            .downloadProgress { progress in
                progressValues.append((progress.completedUnitCount, progress.totalUnitCount))
            }
            .downloadProgress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
                let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
                byteValues.append(bytes)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.temporaryURL)
        XCTAssertNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        XCTAssertEqual(byteValues.count, progressValues.count)

        if byteValues.count == progressValues.count {
            for (byteValue, progressValue) in zip(byteValues, progressValues) {
                XCTAssertGreaterThan(byteValue.bytes, 0)
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount)
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount)
            }
        }

        if let lastByteValue = byteValues.last, let lastProgressValue = progressValues.last {
            let byteValueFractionalCompletion = Double(lastByteValue.totalBytes) / Double(lastByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastProgressValue.0) / Double(lastProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0)
            XCTAssertEqual(progressValueFractionalCompletion, 1.0)
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }
    }

    func testDownloadRequestWithParameters() {
        // Given
        let urlString = "https://httpbin.org/get"
        let parameters = ["foo": "bar"]

        let expectation = self.expectation(description: "Download request should download data to file")
        var response: DefaultDownloadResponse?

        // When
        Alamofire.download(urlString, parameters: parameters)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.temporaryURL)
        XCTAssertNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        if
            let temporaryURL = response?.temporaryURL,
            let data = try? Data(contentsOf: temporaryURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)),
            let json = jsonObject as? [String: Any],
            let args = json["args"] as? [String: String]
        {
            XCTAssertEqual(args["foo"], "bar")
        } else {
            XCTFail("args parameter in JSON should not be nil")
        }
    }

    func testDownloadRequestWithHeaders() {
        // Given
        let fileURL = randomCachesFileURL
        let urlString = "https://httpbin.org/get"
        let headers = ["Authorization": "123456"]
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in (fileURL, []) }

        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")
        var response: DefaultDownloadResponse?

        // When
        Alamofire.download(urlString, headers: headers, to: destination)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        if
            let data = try? Data(contentsOf: fileURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
            let json = jsonObject as? [String: Any],
            let headers = json["headers"] as? [String: String]
        {
            XCTAssertEqual(headers["Authorization"], "123456")
        } else {
            XCTFail("headers parameter in JSON should not be nil")
        }
    }

    func testThatDownloadingFileAndMovingToDirectoryThatDoesNotExistThrowsError() {
        // Given
        let fileURL = FileManager.cachesDirectoryURL.appendingPathComponent("some/random/folder/test_output.json")

        let expectation = self.expectation(description: "Download request should download data but fail to move file")
        var response: DefaultDownloadResponse?

        // When
        Alamofire.download("https://httpbin.org/get", to: { _, _ in (fileURL, [])})
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.temporaryURL)
        XCTAssertNotNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)

        if let error = response?.error as? CocoaError {
            XCTAssertEqual(error.code, .fileNoSuchFile)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDownloadOptionsCanCreateIntermediateDirectoriesPriorToMovingFile() {
        // Given
        let fileURL = FileManager.cachesDirectoryURL.appendingPathComponent("some/random/folder/test_output.json")

        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")
        var response: DefaultDownloadResponse?

        // When
        Alamofire.download("https://httpbin.org/get", to: { _, _ in (fileURL, [.createIntermediateDirectories])})
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.temporaryURL)
        XCTAssertNotNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
    }

    func testThatDownloadingFileAndMovingToDestinationThatIsOccupiedThrowsError() {
        do {
            // Given
            let directoryURL = FileManager.cachesDirectoryURL.appendingPathComponent("some/random/folder")
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            let fileURL = directoryURL.appendingPathComponent("test_output.json")
            try "random_data".write(to: fileURL, atomically: true, encoding: .utf8)

            let expectation = self.expectation(description: "Download should complete but fail to move file")
            var response: DefaultDownloadResponse?

            // When
            Alamofire.download("https://httpbin.org/get", to: { _, _ in (fileURL, [])})
                .response { resp in
                    response = resp
                    expectation.fulfill()
                }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertNotNil(response?.request)
            XCTAssertNotNil(response?.response)
            XCTAssertNotNil(response?.temporaryURL)
            XCTAssertNotNil(response?.destinationURL)
            XCTAssertNil(response?.resumeData)
            XCTAssertNotNil(response?.error)

            if let error = response?.error as? CocoaError {
                XCTAssertEqual(error.code, .fileWriteFileExists)
            } else {
                XCTFail("error should not be nil")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatDownloadOptionsCanRemovePreviousFilePriorToMovingFile() {
        do {
            // Given
            let directoryURL = FileManager.cachesDirectoryURL.appendingPathComponent("some/random/folder")
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            let fileURL = directoryURL.appendingPathComponent("test_output.json")

            let expectation = self.expectation(description: "Download should complete and move file to URL: \(fileURL)")
            var response: DefaultDownloadResponse?

            // When
            Alamofire.download("https://httpbin.org/get", to: { _, _ in (fileURL, [.removePreviousFile])})
                .response { resp in
                    response = resp
                    expectation.fulfill()
                }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertNotNil(response?.request)
            XCTAssertNotNil(response?.response)
            XCTAssertNotNil(response?.temporaryURL)
            XCTAssertNotNil(response?.destinationURL)
            XCTAssertNil(response?.resumeData)
            XCTAssertNil(response?.error)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}

// MARK: -

class DownloadResumeDataTestCase: BaseTestCase {
    let urlString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"

    func testThatImmediatelyCancelledDownloadDoesNotHaveResumeDataAvailable() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var response: DefaultDownloadResponse?

        // When
        let download = Alamofire.download(urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        download.cancel()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)

        XCTAssertNil(download.resumeData)
    }

    func testThatCancelledDownloadResponseDataMatchesResumeData() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var response: DefaultDownloadResponse?

        // When
        let download = Alamofire.download(urlString)
        download.downloadProgress { _, totalBytesReceived, _ in
            if totalBytesReceived > 10_000 { download.cancel() }
        }
        download.response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.destinationURL)
        XCTAssertNotNil(response?.resumeData)
        XCTAssertNotNil(response?.error)

        XCTAssertNotNil(download.resumeData)

        if let responseResumeData = response?.resumeData, let resumeData = download.resumeData {
            XCTAssertEqual(responseResumeData, resumeData)
        } else {
            XCTFail("response resume data or resume data was unexpectedly nil")
        }
    }

    func testThatCancelledDownloadResumeDataIsAvailableWithJSONResponseSerializer() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var response: DownloadResponse<Any>?

        // When
        let download = Alamofire.download(urlString)
        download.downloadProgress { _, totalBytesReceived, _ in
            if totalBytesReceived > 10_000 { download.cancel() }
        }
        download.responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.destinationURL)
        XCTAssertNotNil(response?.resumeData)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.result.error)

        XCTAssertNotNil(download.resumeData)
    }
}
