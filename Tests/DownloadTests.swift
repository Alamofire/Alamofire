//
//  DownloadTests.swift
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

class DownloadInitializationTestCase: BaseTestCase {
    func testDownloadClassMethodWithMethodURLAndDestination() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "download should complete")

        // When
        let request = AF.download(urlString).response { (resp) in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString)
        XCTAssertNotNil(request.response)
    }

    func testDownloadClassMethodWithMethodURLHeadersAndDestination() {
        // Given
        let urlString = "https://httpbin.org/get"
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let expectation = self.expectation(description: "download should complete")

        // When
        let request = AF.download(urlString, headers: headers).response { (resp) in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString)
        XCTAssertEqual(request.request?.value(forHTTPHeaderField: "Authorization"), "123456")
        XCTAssertNotNil(request.response)
    }
}

// MARK: -

class DownloadResponseTestCase: BaseTestCase {
    private var randomCachesFileURL: URL {
        return testDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
    }

    func testDownloadRequest() {
        // Given
        let fileURL = randomCachesFileURL
        let numberOfLines = 10
        let urlString = "https://httpbin.org/stream/\(numberOfLines)"
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = self.expectation(description: "Download request should download data to file: \(urlString)")
        var response: DownloadResponse<URL?>?

        // When
        AF.download(urlString, to: destination)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        if let destinationURL = response?.fileURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))

            if let data = try? Data(contentsOf: destinationURL) {
                XCTAssertGreaterThan(data.count, 0)
            } else {
                XCTFail("data should exist for contents of destinationURL")
            }
        }
    }

    func testCancelledDownloadRequest() {
        // Given
        let fileURL = randomCachesFileURL
        let numberOfLines = 10
        let urlString = "https://httpbin.org/stream/\(numberOfLines)"
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = self.expectation(description: "Cancelled download request should not download data to file")
        var response: DownloadResponse<URL?>?

        // When
        AF.download(urlString, to: destination)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
            .cancel()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNotNil(response?.error)
    }

    func testDownloadRequestWithProgress() {
        // Given
        let randomBytes = 1 * 1024 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var progressValues: [Double] = []
        var response: DownloadResponse<URL?>?

        // When
        AF.download(urlString)
            .downloadProgress { progress in
                progressValues.append(progress.fractionCompleted)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        var previousProgress: Double = progressValues.first ?? 0.0

        for progress in progressValues {
            XCTAssertGreaterThanOrEqual(progress, previousProgress)
            previousProgress = progress
        }

        if let lastProgressValue = progressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in progressValues should not be nil")
        }
    }

    func testDownloadRequestWithParameters() {
        // Given
        let fileURL = randomCachesFileURL
        let urlString = "https://httpbin.org/get"
        let parameters = ["foo": "bar"]
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = self.expectation(description: "Download request should download data to file")
        var response: DownloadResponse<URL?>?

        // When
        AF.download(urlString, parameters: parameters, to: destination)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
        // TODO: Fails since the file is deleted by the time we get here?
        if
            let data = try? Data(contentsOf: fileURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
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
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")
        var response: DownloadResponse<URL?>?

        // When
        AF.download(urlString, headers: headers, to: destination)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
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
        let fileURL = testDirectoryURL.appendingPathComponent("some/random/folder/test_output.json")

        let expectation = self.expectation(description: "Download request should download data but fail to move file")
        var response: DownloadResponse<URL?>?

        // When
        AF.download("https://httpbin.org/get", to: { _, _ in (fileURL, [])})
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.fileURL)
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
        let fileURL = testDirectoryURL.appendingPathComponent("some/random/folder/test_output.json")

        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")
        var response: DownloadResponse<URL?>?

        // When
        AF.download("https://httpbin.org/get", to: { _, _ in (fileURL, [.createIntermediateDirectories])})
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
    }

    func testThatDownloadingFileAndMovingToDestinationThatIsOccupiedThrowsError() {
        do {
            // Given
            let directoryURL = testDirectoryURL.appendingPathComponent("some/random/folder")
            let directoryCreated = FileManager.createDirectory(at: directoryURL)

            let fileURL = directoryURL.appendingPathComponent("test_output.json")
            try "random_data".write(to: fileURL, atomically: true, encoding: .utf8)

            let expectation = self.expectation(description: "Download should complete but fail to move file")
            var response: DownloadResponse<URL?>?

            // When
            AF.download("https://httpbin.org/get", to: { _, _ in (fileURL, [])})
                .response { resp in
                    response = resp
                    expectation.fulfill()
                }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertTrue(directoryCreated)

            XCTAssertNotNil(response?.request)
            XCTAssertNotNil(response?.response)
            XCTAssertNil(response?.fileURL)
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
        // Given
        let directoryURL = testDirectoryURL.appendingPathComponent("some/random/folder")
        let directoryCreated = FileManager.createDirectory(at: directoryURL)

        let fileURL = directoryURL.appendingPathComponent("test_output.json")

        let expectation = self.expectation(description: "Download should complete and move file to URL: \(fileURL)")
        var response: DownloadResponse<URL?>?

        // When
        AF.download("https://httpbin.org/get", to: { _, _ in (fileURL, [.removePreviousFile, .createIntermediateDirectories])})
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(directoryCreated)

        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
    }
}

final class DownloadRequestEventsTestCase: BaseTestCase {
    func testThatDownloadRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didCreateURLRequest = expectation(description: "didCreateURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didWriteData = expectation(description: "didWriteData should fire")
        let didFinishDownloading = expectation(description: "didFinishDownloading should fire")
        let didFinishWithResult = expectation(description: "didFinishWithResult should fire")
        let didCreate = expectation(description: "didCreate should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didParseResponse = expectation(description: "didParseResponse should fire")
        let responseHandler = expectation(description: "responseHandler should fire")

        var wroteData = false

        eventMonitor.taskDidFinishCollectingMetrics = { (_, _, _) in taskDidFinishCollecting.fulfill() }
        eventMonitor.requestDidCreateURLRequest = { (_, _) in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { (_, _) in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { (_, _) in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { (_, _, _) in didComplete.fulfill() }
        eventMonitor.downloadTaskDidWriteData = { (_, _, _, _, _) in
            guard !wroteData else { return }

            wroteData = true
            didWriteData.fulfill()
        }
        eventMonitor.downloadTaskDidFinishDownloadingToURL = { (_, _, _) in didFinishDownloading.fulfill() }
        eventMonitor.requestDidFinishDownloadingUsingTaskWithResult = { (_, _, _) in didFinishWithResult.fulfill() }
        eventMonitor.requestDidCreateDestinationURL = { (_, _) in didCreate.fulfill() }
        eventMonitor.requestDidFinish = { (_) in didFinish.fulfill() }
        eventMonitor.requestDidResume = { (_) in didResume.fulfill() }
        eventMonitor.requestDidResumeTask = { (_, _) in didResumeTask.fulfill() }
        eventMonitor.requestDidParseDownloadResponse = { (_, _) in didParseResponse.fulfill() }

        // When
        let request = session.download(URLRequest.makeHTTPBinRequest()).response { response in
            responseHandler.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatCancelledDownloadRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didCreateURLRequest = expectation(description: "didCreateURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didParseResponse = expectation(description: "didParseResponse should fire")
        let didCancel = expectation(description: "didCancel should fire")
        let didCancelTask = expectation(description: "didCancelTask should fire")
        let responseHandler = expectation(description: "responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { (_, _, _) in taskDidFinishCollecting.fulfill() }
        eventMonitor.requestDidCreateURLRequest = { (_, _) in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { (_, _) in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { (_, _) in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { (_, _, _) in didComplete.fulfill() }
        eventMonitor.requestDidFinish = { (_) in didFinish.fulfill() }
        eventMonitor.requestDidResume = { (_) in didResume.fulfill() }
        eventMonitor.requestDidParseDownloadResponse = { (_, _) in didParseResponse.fulfill() }
        eventMonitor.requestDidCancel = { (_) in didCancel.fulfill() }
        eventMonitor.requestDidCancelTask = { (_, _) in didCancelTask.fulfill() }

        // When
        let request = session.download(URLRequest.makeHTTPBinRequest()).response { response in
            responseHandler.fulfill()
        }

        eventMonitor.requestDidResumeTask = { (_, _) in
            request.cancel()
            didResumeTask.fulfill()
        }

        request.resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }
}

// MARK: -

final class DownloadResumeDataTestCase: BaseTestCase {
    let urlString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"

    func testThatCancelledDownloadRequestDoesNotProduceResumeData() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var cancelled = false

        var response: DownloadResponse<URL?>?

        // When
        let download = AF.download(urlString)
        download.downloadProgress { progress in
            guard !cancelled else { return }

            if progress.fractionCompleted > 0.1 {
                download.cancel()
                cancelled = true
            }
        }
        download.response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNotNil(response?.error)

        XCTAssertNil(response?.resumeData)
        XCTAssertNil(download.resumeData)
    }

    func testThatCancelledDownloadResponseDataMatchesResumeData() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var cancelled = false

        var response: DownloadResponse<URL?>?

        // When
        let download = AF.download(urlString)
        download.downloadProgress { progress in
            guard !cancelled else { return }

            if progress.fractionCompleted > 0.1 {
                download.cancel(producingResumeData: true)
                cancelled = true
            }
        }
        download.response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNotNil(response?.error)

        XCTAssertNotNil(response?.resumeData)
        XCTAssertNotNil(download.resumeData)

        XCTAssertEqual(response?.resumeData, download.resumeData)
    }

    func testThatCancelledDownloadResumeDataIsAvailableWithJSONResponseSerializer() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var cancelled = false

        var response: DownloadResponse<Any>?

        // When
        let download = AF.download(urlString)
        download.downloadProgress { progress in
            guard !cancelled else { return }

            if progress.fractionCompleted > 0.1 {
                download.cancel(producingResumeData: true)
                cancelled = true
            }
        }
        download.responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.result.error)

        XCTAssertNotNil(response?.resumeData)
        XCTAssertNotNil(download.resumeData)

        XCTAssertEqual(response?.resumeData, download.resumeData)
    }

    func testThatCancelledDownloadCanBeResumedWithResumeData() {
        // Given
        let expectation1 = self.expectation(description: "Download should be cancelled")
        var cancelled = false

        var response1: DownloadResponse<Data>?

        // When
        let download = AF.download(urlString)
        download.downloadProgress { progress in
            guard !cancelled else { return }

            if progress.fractionCompleted > 0.4 {
                download.cancel(producingResumeData: true)
                cancelled = true
            }
        }
        download.responseData { resp in
            response1 = resp
            expectation1.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        guard let resumeData = download.resumeData else {
            XCTFail("resumeData should not be nil")
            return
        }

        let expectation2 = self.expectation(description: "Download should complete")

        var progressValues: [Double] = []
        var response2: DownloadResponse<Data>?

        AF.download(resumingWith: resumeData)
            .downloadProgress { progress in
                progressValues.append(progress.fractionCompleted)
            }
            .responseData { resp in
                response2 = resp
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response1?.request)
        XCTAssertNotNil(response1?.response)
        XCTAssertNil(response1?.fileURL)
        XCTAssertEqual(response1?.result.isFailure, true)
        XCTAssertNotNil(response1?.result.error)

        XCTAssertNotNil(response2?.response)
        XCTAssertNotNil(response2?.fileURL)
        XCTAssertEqual(response2?.result.isSuccess, true)
        XCTAssertNil(response2?.result.error)

        progressValues.forEach { XCTAssertGreaterThanOrEqual($0, 0.4) }
    }

    func testThatCancelledDownloadProducesMatchingResumeData() {
        // Given
        let expectation = self.expectation(description: "Download should be cancelled")
        var cancelled = false
        var receivedResumeData: Data?
        var response: DownloadResponse<URL?>?

        // When
        let download = AF.download(urlString)
        download.downloadProgress { progress in
            guard !cancelled else { return }

            if progress.fractionCompleted > 0.1 {
                download.cancel { receivedResumeData = $0 }
                cancelled = true
            }
        }
        download.response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNotNil(response?.error)

        XCTAssertNotNil(response?.resumeData)
        XCTAssertNotNil(download.resumeData)

        XCTAssertEqual(response?.resumeData, download.resumeData)
        XCTAssertEqual(response?.resumeData, receivedResumeData)
        XCTAssertEqual(download.resumeData, receivedResumeData)
    }
}

// MARK: -

class DownloadResponseMapTestCase: BaseTestCase {
    func testThatMapTransformsSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DownloadResponse<String>?

        // When
        AF.download(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.map { json in
                // json["args"]["foo"] is "bar": use this invariant to test the map function
                return ((json as? [String: Any])?["args"] as? [String: Any])?["foo"] as? String ?? "invalid"
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
        XCTAssertEqual(response?.result.value, "bar")
        XCTAssertNotNil(response?.metrics)
    }

    func testThatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DownloadResponse<String>?

        // When
        AF.download(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.map { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
    }
}

// MARK: -

class DownloadResponseFlatMapTestCase: BaseTestCase {
    func testThatFlatMapTransformsSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DownloadResponse<String>?

        // When
        AF.download(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.flatMap { json in
                // json["args"]["foo"] is "bar": use this invariant to test the map function
                return ((json as? [String: Any])?["args"] as? [String: Any])?["foo"] as? String ?? "invalid"
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
        XCTAssertEqual(response?.result.value, "bar")
        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapCatchesTransformationError() {
        // Given
        struct TransformError: Error {}

        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DownloadResponse<String>?

        // When
        AF.download(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.flatMap { json in
                throw TransformError()
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        if let error = response?.result.error {
            XCTAssertTrue(error is TransformError)
        } else {
            XCTFail("flatMap should catch the transformation error")
        }

        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DownloadResponse<String>?

        // When
        AF.download(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.flatMap { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertNotNil(response?.metrics)
    }
}

class DownloadResponseMapErrorTestCase: BaseTestCase {
    func testThatMapErrorTransformsFailureValue() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should not succeed")

        var response: DownloadResponse<Any>?

        // When
        AF.download(urlString).responseJSON { resp in
            response = resp.mapError { error in
                return TestError.error(error: error)
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.result.isFailure, true)

        guard let error = response?.error as? TestError, case .error = error else { XCTFail(); return }

        XCTAssertNotNil(response?.metrics)
    }

    func testThatMapErrorPreservesSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DownloadResponse<Data>?

        // When
        AF.download(urlString).responseData { resp in
            response = resp.mapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertNotNil(response?.metrics)
    }
}

// MARK: -

class DownloadResponseFlatMapErrorTestCase: BaseTestCase {
    func testThatFlatMapErrorPreservesSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DownloadResponse<Data>?

        // When
        AF.download(urlString).responseData { resp in
            response = resp.flatMapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapErrorCatchesTransformationError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DownloadResponse<Data>?

        // When
        AF.download(urlString).responseData { resp in
            response = resp.flatMapError { _ in try TransformationError.error.alwaysFails() }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.result.isFailure, true)

        if let error = response?.result.error {
            XCTAssertTrue(error is TransformationError)
        } else {
            XCTFail("flatMapError should catch the transformation error")
        }

        XCTAssertNotNil(response?.metrics)
    }

    func testThatFlatMapErrorTransformsError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DownloadResponse<Data>?

        // When
        AF.download(urlString).responseData { resp in
            response = resp.flatMapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.result.isFailure, true)
        guard let error = response?.error as? TestError, case .error = error else { XCTFail(); return }

        XCTAssertNotNil(response?.metrics)
    }
}
