//
//  UploadTests.swift
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

#if !SWIFT_PACKAGE
final class UploadFileInitializationTestCase: BaseTestCase {
    func testUploadClassMethodWithMethodURLAndFile() {
        // Given
        let urlString = "https://httpbin.org/post"
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let expectation = self.expectation(description: "upload should complete")

        // When
        let request = AF.upload(imageURL, to: urlString).response { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod, "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString, "request URL string should be equal")
        XCTAssertNotNil(request.response, "response should not be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndFile() {
        // Given
        let urlString = "https://httpbin.org/post"
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let expectation = self.expectation(description: "upload should complete")

        // When
        let request = AF.upload(imageURL, to: urlString, method: .post, headers: headers).response { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod, "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNotNil(request.response, "response should not be nil")
    }
}
#endif

// MARK: -

class UploadDataInitializationTestCase: BaseTestCase {
    func testUploadClassMethodWithMethodURLAndData() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "upload should complete")

        // When
        let request = AF.upload(Data(), to: urlString).response { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString, "request URL string should be equal")
        XCTAssertNotNil(request.response, "response should not be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndData() {
        // Given
        let urlString = "https://httpbin.org/post"
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let expectation = self.expectation(description: "upload should complete")

        // When
        let request = AF.upload(Data(), to: urlString, headers: headers).response { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod, "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNotNil(request.response, "response should not be nil")
    }
}

// MARK: -

#if !SWIFT_PACKAGE
final class UploadStreamInitializationTestCase: BaseTestCase {
    func testUploadClassMethodWithMethodURLAndStream() {
        // Given
        let urlString = "https://httpbin.org/post"
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let imageStream = InputStream(url: imageURL)!
        let expectation = self.expectation(description: "upload should complete")

        // When
        let request = AF.upload(imageStream, to: urlString).response { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod, "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString, "request URL string should be equal")
        XCTAssertNotNil(request.response, "response should not be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndStream() {
        // Given
        let urlString = "https://httpbin.org/post"
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let imageStream = InputStream(url: imageURL)!
        let expectation = self.expectation(description: "upload should complete")

        // When
        let request = AF.upload(imageStream, to: urlString, headers: headers).response { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod, "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.absoluteString, urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNotNil(request.response, "response should not be nil, tasks: \(request.tasks)")
    }
}
#endif

// MARK: -

class UploadDataTestCase: BaseTestCase {
    func testUploadDataRequest() {
        // Given
        let urlString = "https://httpbin.org/post"
        let data = Data("Lorem ipsum dolor sit amet".utf8)

        let expectation = self.expectation(description: "Upload request should succeed: \(urlString)")
        var response: DataResponse<Data?, AFError>?

        // When
        AF.upload(data, to: urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.error)
    }

    func testUploadDataRequestWithProgress() {
        // Given
        let urlString = "https://httpbin.org/post"
        let string = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 300)
        let data = Data(string.utf8)

        let expectation = self.expectation(description: "Bytes upload progress should be reported: \(urlString)")

        var uploadProgressValues: [Double] = []
        var downloadProgressValues: [Double] = []

        var response: DataResponse<Data?, AFError>?

        // When
        AF.upload(data, to: urlString)
            .uploadProgress { progress in
                uploadProgressValues.append(progress.fractionCompleted)
            }
            .downloadProgress { progress in
                downloadProgressValues.append(progress.fractionCompleted)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0

        for progress in uploadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousUploadProgress)
            previousUploadProgress = progress
        }

        if let lastProgressValue = uploadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in uploadProgressValues should not be nil")
        }

        var previousDownloadProgress: Double = downloadProgressValues.first ?? 0.0

        for progress in downloadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousDownloadProgress)
            previousDownloadProgress = progress
        }

        if let lastProgressValue = downloadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in downloadProgressValues should not be nil")
        }
    }
}

// MARK: -

class UploadMultipartFormDataTestCase: BaseTestCase {
    // MARK: Tests

    func testThatUploadingMultipartFormDataSetsContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let uploadData = Data("upload_data".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var formData: MultipartFormData?
        var response: DataResponse<Data?, AFError>?

        // When
        AF.upload(multipartFormData: { multipartFormData in
                      multipartFormData.append(uploadData, withName: "upload_data")
                      formData = multipartFormData
                  },
                  to: urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        if
            let request = response?.request,
            let multipartFormData = formData,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            XCTAssertEqual(contentType, multipartFormData.contentType)
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatCustomBoundaryCanBeSetWhenUploadingMultipartFormData() throws {
        // Given
        let urlRequest = try URLRequest(url: "https://httpbin.org/post", method: .post)
        let uploadData = Data("upload_data".utf8)

        let formData = MultipartFormData(fileManager: .default, boundary: "custom-test-boundary")
        formData.append(uploadData, withName: "upload_data")

        let expectation = self.expectation(description: "multipart form data upload should succeed")
        var response: DataResponse<Data?, AFError>?

        // When
        AF.upload(multipartFormData: formData, with: urlRequest).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        if let request = response?.request, let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            XCTAssertEqual(contentType, formData.contentType)
            XCTAssertTrue(contentType.contains("boundary=custom-test-boundary"))
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatUploadingMultipartFormDataSucceedsWithDefaultParameters() {
        // Given
        let urlString = "https://httpbin.org/post"
        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")
        var response: DataResponse<Data?, AFError>?

        // When
        AF.upload(multipartFormData: { multipartFormData in
                      multipartFormData.append(frenchData, withName: "french")
                      multipartFormData.append(japaneseData, withName: "japanese")
                  },
                  to: urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func testThatUploadingMultipartFormDataWhileStreamingFromMemoryMonitorsProgress() {
        executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: false)
    }

    func testThatUploadingMultipartFormDataWhileStreamingFromDiskMonitorsProgress() {
        executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: true)
    }

    func testThatUploadingMultipartFormDataBelowMemoryThresholdStreamsFromMemory() {
        // Given
        let urlString = "https://httpbin.org/post"
        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")
        var response: DataResponse<Data?, AFError>?

        // When
        let request = AF.upload(multipartFormData: { multipartFormData in
                                    multipartFormData.append(frenchData, withName: "french")
                                    multipartFormData.append(japaneseData, withName: "japanese")
                                },
                                to: urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        guard let uploadable = request.uploadable, case .data = uploadable else {
            XCTFail("Uploadable is not .data")
            return
        }

        XCTAssertTrue(response?.result.isSuccess == true)
    }

    func testThatUploadingMultipartFormDataBelowMemoryThresholdSetsContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let uploadData = Data("upload_data".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var formData: MultipartFormData?
        var response: DataResponse<Data?, AFError>?

        // When
        let request = AF.upload(multipartFormData: { multipartFormData in
                                    multipartFormData.append(uploadData, withName: "upload_data")
                                    formData = multipartFormData
                                },
                                to: urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        guard let uploadable = request.uploadable, case .data = uploadable else {
            XCTFail("Uploadable is not .data")
            return
        }

        if
            let request = response?.request,
            let multipartFormData = formData,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            XCTAssertEqual(contentType, multipartFormData.contentType, "Content-Type header value should match")
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatUploadingMultipartFormDataAboveMemoryThresholdStreamsFromDisk() {
        // Given
        let urlString = "https://httpbin.org/post"
        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")
        var response: DataResponse<Data?, AFError>?

        // When
        let request = AF.upload(multipartFormData: { multipartFormData in
                                    multipartFormData.append(frenchData, withName: "french")
                                    multipartFormData.append(japaneseData, withName: "japanese")
                                },
                                to: urlString,
                                usingThreshold: 0).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        guard let uploadable = request.uploadable, case let .file(url, _) = uploadable else {
            XCTFail("Uploadable is not .file")
            return
        }

        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testThatUploadingMultipartFormDataAboveMemoryThresholdSetsContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let uploadData = Data("upload_data".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")
        var response: DataResponse<Data?, AFError>?
        var formData: MultipartFormData?

        // When
        let request = AF.upload(multipartFormData: { multipartFormData in
                                    multipartFormData.append(uploadData, withName: "upload_data")
                                    formData = multipartFormData
                                },
                                to: urlString,
                                usingThreshold: 0).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        guard let uploadable = request.uploadable, case .file = uploadable else {
            XCTFail("Uploadable is not .file")
            return
        }

        XCTAssertTrue(response?.result.isSuccess == true)

        if
            let request = response?.request,
            let multipartFormData = formData,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            XCTAssertEqual(contentType, multipartFormData.contentType, "Content-Type header value should match")
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatUploadingMultipartFormDataWithNonexistentFileThrowsAnError() {
        // Given
        let urlString = URL.makeHTTPBinURL(path: "post")
        let imageURL = URL(fileURLWithPath: "does_not_exist.jpg")

        let expectation = self.expectation(description: "multipart form data upload from nonexistent file should fail")
        var response: DataResponse<Data?, AFError>?

        // When
        let request = AF.upload(multipartFormData: { multipartFormData in
                                    multipartFormData.append(imageURL, withName: "upload_file")
                                },
                                to: urlString,
                                usingThreshold: 0).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(request.uploadable)
        XCTAssertTrue(response?.result.isSuccess == false)
    }

    #if os(macOS)
    func disabled_testThatUploadingMultipartFormDataOnBackgroundSessionWritesDataToFileToAvoidCrash() {
        // Given
        let manager: Session = {
            let identifier = "org.alamofire.uploadtests.\(UUID().uuidString)"
            let configuration = URLSessionConfiguration.background(withIdentifier: identifier)

            return Session(configuration: configuration)
        }()

        let urlString = "https://httpbin.org/post"
        let french = Data("français".utf8)
        let japanese = Data("日本語".utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: AFError?

        // When
        let upload = manager.upload(multipartFormData: { multipartFormData in
                                        multipartFormData.append(french, withName: "french")
                                        multipartFormData.append(japanese, withName: "japanese")
                                    },
                                    to: urlString)
            .response { defaultResponse in
                request = defaultResponse.request
                response = defaultResponse.response
                data = defaultResponse.data
                error = defaultResponse.error

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        guard let uploadable = upload.uploadable, case .file = uploadable else {
            XCTFail("Uploadable is not .file")
            return
        }
    }
    #endif

    // MARK: Combined Test Execution

    private func executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: Bool) {
        // Given
        let urlString = "https://httpbin.org/post"
        let loremData1 = Data(String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                                     count: 100).utf8)
        let loremData2 = Data(String(repeating: "Lorem ipsum dolor sit amet, nam no graeco recusabo appellantur.",
                                     count: 100).utf8)

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var uploadProgressValues: [Double] = []
        var downloadProgressValues: [Double] = []

        var response: DataResponse<Data?, AFError>?

        // When
        AF.upload(multipartFormData: { multipartFormData in
                      multipartFormData.append(loremData1, withName: "lorem1")
                      multipartFormData.append(loremData2, withName: "lorem2")
                  },
                  to: urlString,
                  usingThreshold: streamFromDisk ? 0 : 100_000_000)
            .uploadProgress { progress in
                uploadProgressValues.append(progress.fractionCompleted)
            }
            .downloadProgress { progress in
                downloadProgressValues.append(progress.fractionCompleted)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0

        for progress in uploadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousUploadProgress)
            previousUploadProgress = progress
        }

        if let lastProgressValue = uploadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in uploadProgressValues should not be nil")
        }

        var previousDownloadProgress: Double = downloadProgressValues.first ?? 0.0

        for progress in downloadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousDownloadProgress)
            previousDownloadProgress = progress
        }

        if let lastProgressValue = downloadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in downloadProgressValues should not be nil")
        }
    }
}

final class UploadRetryTests: BaseTestCase {
    func testThatDataUploadRetriesCorrectly() {
        // Given
        let request = URLRequest.makeHTTPBinRequest(path: "delay/1",
                                                    method: .post,
                                                    headers: [.contentType("text/plain")],
                                                    timeout: 0.1)
        let retrier = InspectorInterceptor(SingleRetrier())
        let didRetry = expectation(description: "request did retry")
        retrier.onRetry = { _ in didRetry.fulfill() }
        let session = Session(interceptor: retrier)
        let body = "body"
        let data = Data(body.utf8)
        var response: AFDataResponse<HTTPBinResponse>?
        let completion = expectation(description: "upload should complete")

        // When
        session.upload(data, with: request).responseDecodable(of: HTTPBinResponse.self) {
            response = $0
            completion.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(retrier.retryCalledCount, 1)
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertEqual(response?.value?.data, body)
    }
}

final class UploadRequestEventsTestCase: BaseTestCase {
    func testThatUploadRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didCreateInitialURLRequest = expectation(description: "didCreateInitialURLRequest should fire")
        let didCreateURLRequest = expectation(description: "didCreateURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didCreateUploadable = expectation(description: "didCreateUploadable should fire")
        let didParseResponse = expectation(description: "didParseResponse should fire")
        let responseHandler = expectation(description: "responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.fulfill() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateInitialURLRequest.fulfill() }
        eventMonitor.requestDidCreateURLRequest = { _, _ in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.fulfill() }
        eventMonitor.requestDidFinish = { _ in didFinish.fulfill() }
        eventMonitor.requestDidResume = { _ in didResume.fulfill() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.fulfill() }
        eventMonitor.requestDidCreateUploadable = { _, _ in didCreateUploadable.fulfill() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.fulfill() }

        // When
        let request = session.upload(Data("PAYLOAD".utf8),
                                     with: URLRequest.makeHTTPBinRequest(path: "post", method: .post)).response { _ in
            responseHandler.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatCancelledUploadRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didCreateInitialURLRequest = expectation(description: "didCreateInitialURLRequest should fire")
        let didCreateURLRequest = expectation(description: "didCreateURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didCreateUploadable = expectation(description: "didCreateUploadable should fire")
        let didParseResponse = expectation(description: "didParseResponse should fire")
        let didCancel = expectation(description: "didCancel should fire")
        let didCancelTask = expectation(description: "didCancelTask should fire")
        let responseHandler = expectation(description: "responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.fulfill() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateInitialURLRequest.fulfill() }
        eventMonitor.requestDidCreateURLRequest = { _, _ in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.fulfill() }
        eventMonitor.requestDidFinish = { _ in didFinish.fulfill() }
        eventMonitor.requestDidResume = { _ in didResume.fulfill() }
        eventMonitor.requestDidCreateUploadable = { _, _ in didCreateUploadable.fulfill() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.fulfill() }
        eventMonitor.requestDidCancel = { _ in didCancel.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in didCancelTask.fulfill() }

        // When
        let request = session.upload(Data("PAYLOAD".utf8),
                                     with: URLRequest.makeHTTPBinRequest(path: "delay/5", method: .post)).response { _ in
            responseHandler.fulfill()
        }

        eventMonitor.requestDidResumeTask = { [unowned request] _, _ in
            request.cancel()
            didResumeTask.fulfill()
        }

        request.resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }
}
