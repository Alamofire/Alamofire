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
        let imageURL = URLForResource("rainbow", withExtension: "jpg")

        // When
        let request = Alamofire.upload(.POST, urlString, file: imageURL)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndFile() {
        // Given
        let urlString = "https://httpbin.org/"
        let imageURL = URLForResource("rainbow", withExtension: "jpg")

        // When
        let request = Alamofire.upload(.POST, urlString, headers: ["Authorization": "123456"], file: imageURL)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")

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
        let request = Alamofire.upload(.POST, urlString, data: Data())

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndData() {
        // Given
        let urlString = "https://httpbin.org/"

        // When
        let request = Alamofire.upload(.POST, urlString, headers: ["Authorization": "123456"], data: Data())

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")

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
        let imageURL = URLForResource("rainbow", withExtension: "jpg")
        let imageStream = InputStream(url: imageURL)!

        // When
        let request = Alamofire.upload(.POST, urlString, stream: imageStream)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")
        XCTAssertNil(request.response, "response should be nil")
    }

    func testUploadClassMethodWithMethodURLHeadersAndStream() {
        // Given
        let urlString = "https://httpbin.org/"
        let imageURL = URLForResource("rainbow", withExtension: "jpg")
        let imageStream = InputStream(url: imageURL)!

        // When
        let request = Alamofire.upload(.POST, urlString, headers: ["Authorization": "123456"], stream: imageStream)

        // Then
        XCTAssertNotNil(request.request, "request should not be nil")
        XCTAssertEqual(request.request?.httpMethod ?? "", "POST", "request HTTP method should be POST")
        XCTAssertEqual(request.request?.urlString ?? "", urlString, "request URL string should be equal")

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

        var request: URLRequest?
        var response: HTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.upload(.POST, urlString, data: data)
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

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var responseRequest: URLRequest?
        var responseResponse: HTTPURLResponse?
        var responseData: Data?
        var responseError: ErrorProtocol?

        // When
        let upload = Alamofire.upload(.POST, urlString, data: data)
        upload.progress { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
            let bytes = (bytes: bytesWritten, totalBytes: totalBytesWritten, totalBytesExpected: totalBytesExpectedToWrite)
            byteValues.append(bytes)

            let progress = (
                completedUnitCount: upload.progress.completedUnitCount,
                totalUnitCount: upload.progress.totalUnitCount
            )
            progressValues.append(progress)
        }
        upload.response { request, response, data, error in
            responseRequest = request
            responseResponse = response
            responseData = data
            responseError = error

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(responseRequest, "response request should not be nil")
        XCTAssertNotNil(responseResponse, "response response should not be nil")
        XCTAssertNotNil(responseData, "response data should not be nil")
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
        var request: URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        Alamofire.upload(
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: uploadData, name: "upload_data")
                formData = multipartFormData
            },
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload.response { responseRequest, responseResponse, responseData, responseError in
                        request = responseRequest
                        response = responseResponse
                        data = responseData
                        error = responseError

                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        if let request = request,
           let multipartFormData = formData,
           let contentType = request.value(forHTTPHeaderField: "Content-Type")
        {
            XCTAssertEqual(contentType, multipartFormData.contentType, "Content-Type header value should match")
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }

    func testThatUploadingMultipartFormDataSucceedsWithDefaultParameters() {
        // Given
        let urlString = "https://httpbin.org/post"
        let french = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let japanese = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var request: URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        Alamofire.upload(
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: french, name: "french")
                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
            },
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload.response { responseRequest, responseResponse, responseData, responseError in
                        request = responseRequest
                        response = responseResponse
                        data = responseData
                        error = responseError

                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")
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
        let french = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let japanese = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var streamingFromDisk: Bool?
        var streamFileURL: URL?

        // When
        Alamofire.upload(
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: french, name: "french")
                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
            },
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, uploadStreamFileURL):
                    streamingFromDisk = uploadStreamingFromDisk
                    streamFileURL = uploadStreamFileURL

                    upload.response { _, _, _, _ in
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
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: uploadData, name: "upload_data")
                formData = multipartFormData
            },
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, _):
                    streamingFromDisk = uploadStreamingFromDisk

                    upload.response { responseRequest, _, _, _ in
                        request = responseRequest
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

        if let request = request,
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
        let french = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let japanese = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let expectation = self.expectation(description: "multipart form data upload should succeed")

        var streamingFromDisk: Bool?
        var streamFileURL: URL?

        // When
        Alamofire.upload(
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: french, name: "french")
                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
            },
            encodingMemoryThreshold: 0,
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, uploadStreamFileURL):
                    streamingFromDisk = uploadStreamingFromDisk
                    streamFileURL = uploadStreamFileURL

                    upload.response { _, _, _, _ in
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

        if let streamingFromDisk = streamingFromDisk,
           let streamFilePath = streamFileURL?.path
        {
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
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: uploadData, name: "upload_data")
                formData = multipartFormData
            },
            encodingMemoryThreshold: 0,
            encodingCompletion: { result in
                switch result {
                case let .success(upload, uploadStreamingFromDisk, _):
                    streamingFromDisk = uploadStreamingFromDisk

                    upload.response { responseRequest, _, _, _ in
                        request = responseRequest
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

        if let request = request,
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
//        let manager: Manager = {
//            let identifier = "com.alamofire.uploadtests.\(UUID().uuidString)"
//            let configuration = URLSessionConfiguration.backgroundSessionConfigurationForAllPlatformsWithIdentifier(identifier)
//
//            return Manager(configuration: configuration, serverTrustPolicyManager: nil)
//        }()
//
//        let urlString = "https://httpbin.org/post"
//        let french = "français".data(using: String.Encoding.utf8, allowLossyConversion: false)!
//        let japanese = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!
//
//        let expectation = self.expectation(withDescription: "multipart form data upload should succeed")
//
//        var request: URLRequest?
//        var response: HTTPURLResponse?
//        var data: Data?
//        var error: NSError?
//        var streamingFromDisk: Bool?
//
//        // When
//        manager.upload(
//            .POST,
//            urlString,
//            multipartFormData: { multipartFormData in
//                multipartFormData.appendBodyPart(data: french, name: "french")
//                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
//            },
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
//        waitForExpectations(withTimeout: timeout, handler: nil)
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

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var request: URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        Alamofire.upload(
            .POST,
            urlString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: loremData1, name: "lorem1")
                multipartFormData.appendBodyPart(data: loremData2, name: "lorem2")
            },
            encodingMemoryThreshold: streamFromDisk ? 0 : 100_000_000,
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload.progress { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
                        let bytes = (
                            bytes: bytesWritten,
                            totalBytes: totalBytesWritten,
                            totalBytesExpected: totalBytesExpectedToWrite
                        )
                        byteValues.append(bytes)

                        let progress = (
                            completedUnitCount: upload.progress.completedUnitCount,
                            totalUnitCount: upload.progress.totalUnitCount
                        )
                        progressValues.append(progress)
                    }
                    upload.response { responseRequest, responseResponse, responseData, responseError in
                        request = responseRequest
                        response = responseResponse
                        data = responseData
                        error = responseError

                        expectation.fulfill()
                    }
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

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
    }
}
