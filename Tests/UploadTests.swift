//
//  UploadTests.swift
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

class UploadFileInitializationTestCase: BaseTestCase {
    func testUploadClassMethodWithMethodURLAndFile() {
        // Given
        let urlString = "https://httpbin.org/"
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")

        // When
        let request = Alamofire.upload(imageURL, to: urlString)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.urlString, urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndFile() {
        // Given
        let urlString = "https://httpbin.org/"
        let headers = ["Authorization": "123456"]
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")

        // When
        let request = Alamofire.upload(imageURL, to: urlString, method: .post, headers: headers)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.urlString, urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class UploadDataInitializationTestCase: BaseTestCase {
    func testUploadClassMethodWithMethodURLAndData() {
        // Given
        let urlString = "https://httpbin.org/"

        // When
        let request = Alamofire.upload(Data(), to: urlString)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.urlString, urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndData() {
        // Given
        let urlString = "https://httpbin.org/"
        let headers = ["Authorization": "123456"]

        // When
        let request = Alamofire.upload(Data(), to: urlString, headers: headers)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.urlString, urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class UploadStreamInitializationTestCase: BaseTestCase {
    func testUploadClassMethodWithMethodURLAndStream() {
        // Given
        let urlString = "https://httpbin.org/"
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let imageStream = InputStream(url: imageURL)!

        // When
        let request = Alamofire.upload(imageStream, to: urlString)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.urlString, urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndStream() {
        // Given
        let urlString = "https://httpbin.org/"
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let headers = ["Authorization": "123456"]
        let imageStream = InputStream(url: imageURL)!

        // When
        let request = Alamofire.upload(imageStream, to: urlString, headers: headers)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.url?.urlString, urlString, "request URL string should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertEqual(authorizationHeader, "123456", "Authorization header is incorrect")

        XCTAssertNil(request.response, "response should be nil")
    }
}

// MARK: -

class UploadDataTestCase: BaseTestCase {
    func testUploadDataRequest() {
        // Given
        let urlString = "https://httpbin.org/post"
        let data = "Lorem ipsum dolor sit amet".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "Upload request should succeed: \(urlString)")
        var response: DefaultDataResponse?

        // When
        Alamofire.upload(data, to: urlString)
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
        let data: Data = {
            var text = ""
            for _ in 1...3_000 {
                text += "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
            }

            return text.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        }()

        let expectation = self.expectation(description: "Bytes upload progress should be reported: \(urlString)")

        var uploadByteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var uploadProgressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []

        var downloadByteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var downloadProgressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []

        var response: DefaultDataResponse?

        // When
        Alamofire.upload(data, to: urlString)
            .uploadProgress { progress in
                uploadProgressValues.append((progress.completedUnitCount, progress.totalUnitCount))
            }
            .uploadProgress { bytesSent, totalBytesSent, totalBytesExpectedToSend in
                let bytes = (bytes: bytesSent, totalBytes: totalBytesSent, totalBytesExpected: totalBytesExpectedToSend)
                uploadByteValues.append(bytes)
            }
            .downloadProgress { progress in
                downloadProgressValues.append((progress.completedUnitCount, progress.totalUnitCount))
            }
            .downloadProgress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
                let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
                downloadByteValues.append(bytes)
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

        XCTAssertEqual(uploadByteValues.count, uploadProgressValues.count)
        XCTAssertEqual(downloadByteValues.count, downloadProgressValues.count)

        if uploadByteValues.count == uploadProgressValues.count {
            for (byteValue, progressValue) in zip(uploadByteValues, uploadProgressValues) {
                XCTAssertGreaterThan(byteValue.bytes, 0)
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount)
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount)
            }
        }

        if let lastUploadByteValue = uploadByteValues.last, let lastUploadProgressValue = uploadProgressValues.last {
            let byteValueFractionalCompletion = Double(lastUploadByteValue.totalBytes) / Double(lastUploadByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastUploadProgressValue.0) / Double(lastUploadProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0)
            XCTAssertEqual(progressValueFractionalCompletion, 1.0)
        } else {
            XCTFail("last item in uploadByteValues and uploadProgressValues should not be nil")
        }

        if downloadByteValues.count == downloadProgressValues.count {
            for (byteValue, progressValue) in zip(downloadByteValues, downloadProgressValues) {
                XCTAssertGreaterThan(byteValue.bytes, 0)
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount)
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount)
            }
        }

        if let lastDownloadByteValue = downloadByteValues.last, let lastDownloadProgressValue = downloadProgressValues.last {
            let byteValueFractionalCompletion = Double(lastDownloadByteValue.totalBytes) / Double(lastDownloadByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastDownloadProgressValue.0) / Double(lastDownloadProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0)
            XCTAssertEqual(progressValueFractionalCompletion, 1.0)
        } else {
            XCTFail("last item in downloadByteValues and downloadProgressValues should not be nil")
        }
    }
}

// MARK: -

class UploadMultipartFormDataTestCase: BaseTestCase {

    // MARK: Tests

    func testThatUploadingMultipartFormDataSetsContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let uploadData = "upload_data".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var formData: MultipartFormData?
        var response: DefaultDataResponse?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(uploadData, withName: "upload_data")
                formData = multipartFormData
            },
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload.response { resp in
                        response = resp
                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        if
            let request = response?.request,
            let multipartFormData = formData,
            let contentType = request.value(forHTTPHeaderField: "Content-Type")
        {
            XCTAssertEqual(contentType, multipartFormData.contentType)
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatUploadingMultipartFormDataSucceedsWithDefaultParameters() {
        // Given
        let urlString = "https://httpbin.org/post"
        let frenchData = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let japaneseData = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")
        var response: DefaultDataResponse?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(frenchData, withName: "french")
                multipartFormData.append(japaneseData, withName: "japanese")
            },
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload.response { resp in
                        response = resp
                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

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
        let frenchData = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let japaneseData = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var streamingFromDisk: Bool?
        var streamFileURL: URL?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(frenchData, withName: "french")
                multipartFormData.append(japaneseData, withName: "japanese")
            },
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, uploadStreamFileURL):
                    streamingFromDisk = uploadStreamingFromDisk
                    streamFileURL = uploadStreamFileURL

                    upload.response { _ in
                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(streamingFromDisk, "streaming from disk should not be nil")
        XCTAssertNil(streamFileURL, "stream file URL should be nil")

        if let streamingFromDisk = streamingFromDisk {
            XCTAssertFalse(streamingFromDisk, "streaming from disk should be false")
        }
    }

    func testThatUploadingMultipartFormDataBelowMemoryThresholdSetsContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let uploadData = "upload data".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var formData: MultipartFormData?
        var request: URLRequest?
        var streamingFromDisk: Bool?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(uploadData, withName: "upload_data")
                formData = multipartFormData
            },
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, _):
                    streamingFromDisk = uploadStreamingFromDisk

                    upload.response { resp in
                        request = resp.request
                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(streamingFromDisk, "streaming from disk should not be nil")

        if let streamingFromDisk = streamingFromDisk {
            XCTAssertFalse(streamingFromDisk, "streaming from disk should be false")
        }

        if
            let request = request,
            let multipartFormData = formData,
            let contentType = request.value(forHTTPHeaderField: "Content-Type")
        {
            XCTAssertEqual(contentType, multipartFormData.contentType, "Content-Type header value should match")
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatUploadingMultipartFormDataAboveMemoryThresholdStreamsFromDisk() {
        // Given
        let urlString = "https://httpbin.org/post"
        let frenchData = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let japaneseData = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var streamingFromDisk: Bool?
        var streamFileURL: URL?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(frenchData, withName: "french")
                multipartFormData.append(japaneseData, withName: "japanese")
            },
            usingThreshold: 0,
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, uploadStreamFileURL):
                    streamingFromDisk = uploadStreamingFromDisk
                    streamFileURL = uploadStreamFileURL

                    upload.response { _ in
                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(streamingFromDisk, "streaming from disk should not be nil")
        XCTAssertNotNil(streamFileURL, "stream file URL should not be nil")

        if let streamingFromDisk = streamingFromDisk, let streamFilePath = streamFileURL?.path {
            XCTAssertTrue(streamingFromDisk, "streaming from disk should be true")
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: streamFilePath),
                "stream file path should exist"
            )
        }
    }

    func testThatUploadingMultipartFormDataAboveMemoryThresholdSetsContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let uploadData = "upload data".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var formData: MultipartFormData?
        var request: URLRequest?
        var streamingFromDisk: Bool?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(uploadData, withName: "upload_data")
                formData = multipartFormData
            },
            usingThreshold: 0,
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, _):
                    streamingFromDisk = uploadStreamingFromDisk

                    upload.response { resp in
                        request = resp.request
                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(streamingFromDisk, "streaming from disk should not be nil")

        if let streamingFromDisk = streamingFromDisk {
            XCTAssertTrue(streamingFromDisk, "streaming from disk should be true")
        }

        if
            let request = request,
            let multipartFormData = formData,
            let contentType = request.value(forHTTPHeaderField: "Content-Type")
        {
            XCTAssertEqual(contentType, multipartFormData.contentType, "Content-Type header value should match")
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

//    ⚠️ This test has been removed as a result of rdar://26870455 in Xcode 8 Seed 1
//    func testThatUploadingMultipartFormDataOnBackgroundSessionWritesDataToFileToAvoidCrash() {
//        // Given
//        let manager: SessionManager = {
//            let identifier = "org.alamofire.uploadtests.\(UUID().uuidString)"
//            let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
//
//            return SessionManager(configuration: configuration, serverTrustPolicyManager: nil)
//        }()
//
//        let urlString = "https://httpbin.org/post"
//        let french = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
//        let japanese = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!
//
//        let expectation = self.expectation(description: "multipart form data upload should succeed")
//
//        var request: URLRequest?
//        var response: HTTPURLResponse?
//        var data: Data?
//        var error: Error?
//        var streamingFromDisk: Bool?
//
//        // When
//        manager.upload(
//            multipartFormData: { multipartFormData in
//                multipartFormData.append(french, withName: "french")
//                multipartFormData.append(japanese, withName: "japanese")
//            },
//            to: urlString,
//            withMethod: .post,
//            encodingCompletion: { result in
//                switch result {
//                case let .success(upload, uploadStreamingFromDisk, _):
//                    streamingFromDisk = uploadStreamingFromDisk
//
//                    upload.response { responseRequest, responseResponse, responseData, responseError in
//                        request = responseRequest
//                        response = responseResponse
//                        data = responseData
//                        error = responseError
//
//                        expectation.fulfill()
//                    }
//                case .failure:
//                    expectation.fulfill()
//                }
//            }
//        )
//
//        waitForExpectations(timeout: timeout, handler: nil)
//
//        // Then
//        XCTAssertNotNil(request, "request should not be nil")
//        XCTAssertNotNil(response, "response should not be nil")
//        XCTAssertNotNil(data, "data should not be nil")
//        XCTAssertNil(error, "error should be nil")
//
//        if let streamingFromDisk = streamingFromDisk {
//            XCTAssertTrue(streamingFromDisk, "streaming from disk should be true")
//        } else {
//            XCTFail("streaming from disk should not be nil")
//        }
//    }

    // MARK: Combined Test Execution

    private func executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: Bool) {
        // Given
        let urlString = "https://httpbin.org/post"
        let loremData1: Data = {
            var loremValues: [String] = []
            for _ in 1...1_500 {
                loremValues.append("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
            }

            return loremValues.joined(separator: " ").data(using: String.Encoding.utf8, allowLossyConversion: false)!
        }()
        let loremData2: Data = {
            var loremValues: [String] = []
            for _ in 1...1_500 {
                loremValues.append("Lorem ipsum dolor sit amet, nam no graeco recusabo appellantur.")
            }

            return loremValues.joined(separator: " ").data(using: String.Encoding.utf8, allowLossyConversion: false)!
        }()

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var uploadByteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var uploadProgressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []

        var downloadByteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var downloadProgressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []

        var response: DefaultDataResponse?

        // When
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(loremData1, withName: "lorem1")
                multipartFormData.append(loremData2, withName: "lorem2")
            },
            usingThreshold: streamFromDisk ? 0 : 100_000_000,
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload
                        .uploadProgress { progress in
                            uploadProgressValues.append((progress.completedUnitCount, progress.totalUnitCount))
                        }
                        .uploadProgress { bytesSent, totalBytesSent, totalBytesExpectedToSend in
                            let bytes = (bytes: bytesSent, totalBytes: totalBytesSent, totalBytesExpected: totalBytesExpectedToSend)
                            uploadByteValues.append(bytes)
                        }
                        .downloadProgress { progress in
                            downloadProgressValues.append((progress.completedUnitCount, progress.totalUnitCount))
                        }
                        .downloadProgress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
                            let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
                            downloadByteValues.append(bytes)
                        }
                        .response { resp in
                            response = resp
                            expectation.fulfill()
                        }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        XCTAssertEqual(uploadByteValues.count, uploadProgressValues.count)
        XCTAssertEqual(downloadByteValues.count, downloadProgressValues.count)

        if uploadByteValues.count == uploadProgressValues.count {
            for (byteValue, progressValue) in zip(uploadByteValues, uploadProgressValues) {
                XCTAssertGreaterThan(byteValue.bytes, 0)
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount)
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount)
            }
        }

        if let lastUploadByteValue = uploadByteValues.last, let lastUploadProgressValue = uploadProgressValues.last {
            let byteValueFractionalCompletion = Double(lastUploadByteValue.totalBytes) / Double(lastUploadByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastUploadProgressValue.0) / Double(lastUploadProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0)
            XCTAssertEqual(progressValueFractionalCompletion, 1.0)
        } else {
            XCTFail("last item in uploadByteValues and uploadProgressValues should not be nil")
        }

        if downloadByteValues.count == downloadProgressValues.count {
            for (byteValue, progressValue) in zip(downloadByteValues, downloadProgressValues) {
                XCTAssertGreaterThan(byteValue.bytes, 0)
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount)
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount)
            }
        }

        if let lastDownloadByteValue = downloadByteValues.last, let lastDownloadProgressValue = downloadProgressValues.last {
            let byteValueFractionalCompletion = Double(lastDownloadByteValue.totalBytes) / Double(lastDownloadByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastDownloadProgressValue.0) / Double(lastDownloadProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0)
            XCTAssertEqual(progressValueFractionalCompletion, 1.0)
        } else {
            XCTFail("last item in downloadByteValues and downloadProgressValues should not be nil")
        }
    }
}
