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
import Testing

@Suite(.storesInstances)
struct UploadFileInitializationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadClassMethodWithMethodURLAndFile() async {
        // Given
        let session = stored(Session.independent())
        let requestURL = Endpoint.method(.post).url
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let expectation = Completion("upload should complete")

        // When
        let request = session.upload(imageURL, to: requestURL).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil, "request should not be nil")
        #expect(request.request?.httpMethod == "POST", "request HTTP method should be POST")
        #expect(request.request?.url == requestURL, "request URL should be equal")
        #expect(request.response != nil, "response should not be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadClassMethodWithMethodURLHeadersAndFile() async {
        // Given
        let session = stored(Session.independent())
        let requestURL = Endpoint.method(.post).url
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let expectation = Completion("upload should complete")

        // When
        let request = session.upload(imageURL, to: requestURL, method: .post, headers: headers).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil, "request should not be nil")
        #expect(request.request?.httpMethod == "POST", "request HTTP method should be POST")
        #expect(request.request?.url == requestURL, "request URL should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        #expect(authorizationHeader == "123456", "Authorization header is incorrect")

        #expect(request.response != nil, "response should not be nil")
    }
}

// MARK: -

@Suite(.storesInstances)
struct UploadDataInitializationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadClassMethodWithMethodURLAndData() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let expectation = Completion("upload should complete")

        // When
        let request = session.upload(Data(), to: url).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil, "request should not be nil")
        #expect(request.request?.httpMethod ?? "" == "POST", "request HTTP method should be POST")
        #expect(request.request?.url == url, "request URL should be equal")
        #expect(request.response != nil, "response should not be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadClassMethodWithMethodURLHeadersAndData() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let expectation = Completion("upload should complete")

        // When
        let request = session.upload(Data(), to: url, headers: headers).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil, "request should not be nil")
        #expect(request.request?.httpMethod == "POST", "request HTTP method should be POST")
        #expect(request.request?.url == url, "request URL should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        #expect(authorizationHeader == "123456", "Authorization header is incorrect")

        #expect(request.response != nil, "response should not be nil")
    }
}

// MARK: -

@Suite(.storesInstances)
struct UploadStreamInitializationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadClassMethodWithMethodURLAndStream() async {
        // Given
        let session = stored(Session.independent())
        let requestURL = Endpoint.method(.post).url
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let imageStream = InputStream(url: imageURL)!
        let expectation = Completion("upload should complete")

        // When
        let request = session.upload(imageStream, to: requestURL).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil, "request should not be nil")
        #expect(request.request?.httpMethod == "POST", "request HTTP method should be POST")
        #expect(request.request?.url == requestURL, "request URL should be equal")
        #expect(request.response != nil, "response should not be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadClassMethodWithMethodURLHeadersAndStream() async {
        // Given
        let session = stored(Session.independent())
        let requestURL = Endpoint.method(.post).url
        let imageURL = url(forResource: "rainbow", withExtension: "jpg")
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let imageStream = InputStream(url: imageURL)!
        let expectation = Completion("upload should complete")

        // When
        let request = session.upload(imageStream, to: requestURL, headers: headers).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil, "request should not be nil")
        #expect(request.request?.httpMethod == "POST", "request HTTP method should be POST")
        #expect(request.request?.url == requestURL, "request URL should be equal")

        let authorizationHeader = request.request?.value(forHTTPHeaderField: "Authorization") ?? ""
        #expect(authorizationHeader == "123456", "Authorization header is incorrect")

        #expect(request.response != nil, "response should not be nil, tasks: \(request.tasks)")
    }
}

// MARK: -

@Suite(.storesInstances)
struct UploadDataTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadDataRequest() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let data = Data("Lorem ipsum dolor sit amet".utf8)

        let expectation = Completion("Upload request should succeed: \(url)")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(data, to: url)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadDataRequestWithProgress() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let string = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 1000)
        let data = Data(string.utf8)

        let expectation = Completion("Bytes upload progress should be reported: \(url)")

        let uploadProgressValues = Capture<[Double]>([])
        let downloadProgressValues = Capture<[Double]>([])

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(data, to: url)
            .uploadProgress(queue: session.rootQueue) { progress in
                uploadProgressValues.write { $0.append(progress.fractionCompleted) }
            }
            .downloadProgress(queue: session.rootQueue) { progress in
                downloadProgressValues.write { $0.append(progress.fractionCompleted) }
            }
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0

        for progress in uploadProgressValues.value {
            #expect(progress >= previousUploadProgress)
            previousUploadProgress = progress
        }

        if let lastProgressValue = uploadProgressValues.last {
            #expect(lastProgressValue == 1.0)
        } else {
            Issue.record("last item in uploadProgressValues should not be nil")
        }

        var previousDownloadProgress: Double = downloadProgressValues.first ?? 0.0

        for progress in downloadProgressValues.value {
            #expect(progress >= previousDownloadProgress)
            previousDownloadProgress = progress
        }

        if let lastProgressValue = downloadProgressValues.last {
            #expect(lastProgressValue == 1.0)
        } else {
            Issue.record("last item in downloadProgressValues should not be nil")
        }
    }
}

// MARK: -

@Suite(.storesInstances)
struct UploadMultipartFormDataTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataSetsContentTypeHeader() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let uploadData = Data("upload_data".utf8)

        let expectation = Completion("multipart form data upload should succeed")

        let formData = Capture<MultipartFormData?>()
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(multipartFormData: { multipartFormData in
                           multipartFormData.append(uploadData, withName: "upload_data")
                           formData.value = multipartFormData
                       },
                       to: url)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        if
            let request = response.request,
            let multipartFormData = formData.value,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            #expect(contentType == multipartFormData.contentType)
        } else {
            Issue.record("Content-Type header value should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func accessingMultipartFormDataURLIsThreadSafe() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let uploadData = Data("upload_data".utf8)

        let expectation = Completion("multipart form data upload should succeed")

        let formData = Capture<MultipartFormData?>()
        let generatedURL = Capture<URL?>()
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let upload = session.upload(multipartFormData: { multipartFormData in
                                        multipartFormData.append(uploadData, withName: "upload_data")
                                        formData.value = multipartFormData
                                    },
                                    to: url)

        // Access will produce a thread-sanitizer issue if it isn't safe.
        generatedURL.value = upload.convertible.urlRequest?.url

        upload.response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        if
            let request = response.request,
            let multipartFormData = formData.value,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            #expect(contentType == multipartFormData.contentType)
            #expect(url == generatedURL.value)
        } else {
            Issue.record("Content-Type header value should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func customBoundaryCanBeSetWhenUploadingMultipartFormData() async {
        // Given
        let session = stored(Session.independent())
        let uploadData = Data("upload_data".utf8)

        let formData = MultipartFormData(fileManager: .default, boundary: "custom-test-boundary")
        formData.append(uploadData, withName: "upload_data")

        let expectation = Completion("multipart form data upload should succeed")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(multipartFormData: formData, with: Endpoint.method(.post)).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        if let request = response.request, let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            #expect(contentType == formData.contentType)
            #expect(contentType.contains("boundary=custom-test-boundary"))
        } else {
            Issue.record("Content-Type header value should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataSucceedsWithDefaultParameters() async {
        // Given
        let session = stored(Session.independent())
        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)

        let expectation = Completion("multipart form data upload should succeed")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(multipartFormData: { multipartFormData in
                           multipartFormData.append(frenchData, withName: "french")
                           multipartFormData.append(japaneseData, withName: "japanese")
                       },
                       to: Endpoint.method(.post))
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataWhileStreamingFromMemoryMonitorsProgress() async {
        await executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: false)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataWhileStreamingFromDiskMonitorsProgress() async {
        await executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataBelowMemoryThresholdStreamsFromMemory() async {
        // Given
        let session = stored(Session.independent())
        let frenchData = Data(String(repeating: "français", count: 1_000_000).utf8)
        let japaneseData = Data(String(repeating: "日本語", count: 1_000_000).utf8)

        let expectation = Completion("multipart form data upload should succeed")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.upload(multipartFormData: { multipartFormData in
                                         multipartFormData.append(frenchData, withName: "french")
                                         multipartFormData.append(japaneseData, withName: "japanese")
                                     },
                                     to: Endpoint.method(.post),
                                     usingThreshold: .max)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        guard let uploadable = request.uploadable, case .data = uploadable else {
            Issue.record("Uploadable is not .data")
            return
        }

        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataBelowMemoryThresholdSetsContentTypeHeader() async {
        // Given
        let session = stored(Session.independent())
        let uploadData = Data("upload_data".utf8)

        let expectation = Completion("multipart form data upload should succeed")

        let formData = Capture<MultipartFormData?>()
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.upload(multipartFormData: { multipartFormData in
                                         multipartFormData.append(uploadData, withName: "upload_data")
                                         formData.value = multipartFormData
                                     },
                                     to: Endpoint.method(.post))
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        guard let uploadable = request.uploadable, case .data = uploadable else {
            Issue.record("Uploadable is not .data")
            return
        }

        if
            let request = response.request,
            let multipartFormData = formData.value,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            #expect(contentType == multipartFormData.contentType, "Content-Type header value should match")
        } else {
            Issue.record("Content-Type header value should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataAboveMemoryThresholdStreamsFromDisk() async {
        // Given
        let session = stored(Session.independent())
        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)

        let expectation = Completion("multipart form data upload should succeed")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.upload(multipartFormData: { multipartFormData in
                                         multipartFormData.append(frenchData, withName: "french")
                                         multipartFormData.append(japaneseData, withName: "japanese")
                                     },
                                     to: Endpoint.method(.post),
                                     usingThreshold: 0).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        // No deterministic way to test whether the upload was written to disk, so just check whether the upload was a file.
        guard let uploadable = request.uploadable, case .file = uploadable else {
            Issue.record("Uploadable is not .file")
            return
        }

        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataAboveMemoryThresholdSetsContentTypeHeader() async {
        // Given
        let session = stored(Session.independent())
        let uploadData = Data("upload_data".utf8)

        let expectation = Completion("multipart form data upload should succeed")
        let response = Capture<DataResponse<Data?, AFError>?>()
        let formData = Capture<MultipartFormData?>()

        // When
        let request = session.upload(multipartFormData: { multipartFormData in
                                         multipartFormData.append(uploadData, withName: "upload_data")
                                         formData.value = multipartFormData
                                     },
                                     to: Endpoint.method(.post),
                                     usingThreshold: 0).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        guard let uploadable = request.uploadable, case .file = uploadable else {
            Issue.record("Uploadable is not .file")
            return
        }

        #expect(response.result?.isSuccess == true)

        if
            let request = response.request,
            let multipartFormData = formData.value,
            let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            #expect(contentType == multipartFormData.contentType, "Content-Type header value should match")
        } else {
            Issue.record("Content-Type header value should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataWithNonexistentFileThrowsAnError() async {
        // Given
        let session = stored(Session.independent())
        let imageURL = URL(fileURLWithPath: "does_not_exist.jpg")

        let expectation = Completion("multipart form data upload from nonexistent file should fail")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.upload(multipartFormData: { multipartFormData in
                                         multipartFormData.append(imageURL, withName: "upload_file")
                                     },
                                     to: Endpoint.method(.post),
                                     usingThreshold: 0).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.uploadable == nil)
        #expect(response.result?.isSuccess == false)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataWorksWhenAppendingBodyPartsInURLRequestConvertible() async {
        // Given
        let session = stored(Session.independent())
        // MultipartFormData isn't Sendable, but Alamofire only calls asURLRequest() from its serial request creation path.
        struct MultipartFormDataRequest: URLRequestConvertible, @unchecked Sendable {
            let multipartFormData = MultipartFormData()

            func asURLRequest() throws -> URLRequest {
                appendBodyParts()
                return try Endpoint.method(.post).asURLRequest()
            }

            func appendBodyParts() {
                let frenchData = Data("français".utf8)
                multipartFormData.append(frenchData, withName: "french")

                let japaneseData = Data("日本語".utf8)
                multipartFormData.append(japaneseData, withName: "japanese")
            }
        }

        let request = MultipartFormDataRequest()

        let expectation = Completion("multipart form data upload should succeed")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let uploadRequest = session.upload(multipartFormData: request.multipartFormData, with: request)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        switch uploadRequest.uploadable {
        case let .data(data):
            #expect(data.count == 241)

        default:
            Issue.record("Uploadable should be of type data and not be empty")
        }
    }

    #if os(macOS)
    @Test(.disabled("Background sessions aren't supported by Alamofire."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadingMultipartFormDataOnBackgroundSessionWritesDataToFileToAvoidCrash() async {
        // Given
        let manager: Session = {
            let identifier = "org.alamofire.uploadtests.\(UUID().uuidString)"
            let configuration = URLSessionConfiguration.background(withIdentifier: identifier)

            return stored(Session.independent(configuration: configuration))
        }()

        let french = Data("français".utf8)
        let japanese = Data("日本語".utf8)

        let expectation = Completion("multipart form data upload should succeed")

        let request = Capture<URLRequest?>()
        let response = Capture<HTTPURLResponse?>()
        let data = Capture<Data?>()
        let error = Capture<AFError?>()

        // When
        let upload = manager.upload(multipartFormData: { multipartFormData in
                                        multipartFormData.append(french, withName: "french")
                                        multipartFormData.append(japanese, withName: "japanese")
                                    },
                                    to: Endpoint.method(.post))
            .response { defaultResponse in
                request.value = defaultResponse.request
                response.value = defaultResponse.response
                data.value = defaultResponse.data
                error.value = defaultResponse.error

                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(request.value != nil, "request should not be nil")
        #expect(response.value != nil, "response should not be nil")
        #expect(data.value != nil, "data should not be nil")
        #expect(error.value == nil, "error should be nil")

        guard let uploadable = upload.uploadable, case .file = uploadable else {
            Issue.record("Uploadable is not .file")
            return
        }
    }
    #endif

    // MARK: Combined Test Execution

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: Bool) async {
        // Given
        let session = stored(Session.independent())
        let loremData1 = Data(String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                                     count: 8700).utf8)
        let loremData2 = Data(String(repeating: "Lorem ipsum dolor sit amet, nam no graeco recusabo appellantur.",
                                     count: 7900).utf8)

        let expectation = Completion("multipart form data upload should succeed")

        let uploadProgressValues = Capture<[Double]>([])
        let downloadProgressValues = Capture<[Double]>([])

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(multipartFormData: { multipartFormData in
                           multipartFormData.append(loremData1, withName: "lorem1")
                           multipartFormData.append(loremData2, withName: "lorem2")
                       },
                       to: Endpoint.method(.post),
                       usingThreshold: streamFromDisk ? 0 : .max)
            .uploadProgress(queue: session.rootQueue) { progress in
                uploadProgressValues.write { $0.append(progress.fractionCompleted) }
            }
            .downloadProgress(queue: session.rootQueue) { progress in
                downloadProgressValues.write { $0.append(progress.fractionCompleted) }
            }
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0

        for progress in uploadProgressValues.value {
            #expect(progress >= previousUploadProgress)
            previousUploadProgress = progress
        }

        if let lastProgressValue = uploadProgressValues.last {
            #expect(lastProgressValue == 1.0)
        } else {
            Issue.record("last item in uploadProgressValues should not be nil")
        }

        var previousDownloadProgress: Double = downloadProgressValues.first ?? 0.0

        for progress in downloadProgressValues.value {
            #expect(progress >= previousDownloadProgress)
            previousDownloadProgress = progress
        }

        if let lastProgressValue = downloadProgressValues.last {
            #expect(lastProgressValue == 1.0)
        } else {
            Issue.record("last item in downloadProgressValues should not be nil")
        }
    }
}

@Suite(.storesInstances)
struct UploadRetryTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataUploadRetriesCorrectly() async {
        // Given
        let endpoint = Endpoint(path: .delay(interval: 1),
                                method: .post,
                                headers: [.contentType("text/plain")],
                                timeout: 0.1)
        let didRetry = Completion("request did retry")
        let retrier = InspectorInterceptor(SingleRetrier(), onRetry: { _ in didRetry.complete() })
        let session = stored(Session.independent(interceptor: retrier))
        let body = "body"
        let data = Data(body.utf8)
        let response = Capture<AFDataResponse<TestResponse>?>()
        let completion = Completion("upload should complete")

        // When
        session.upload(data, with: endpoint).responseDecodable(of: TestResponse.self) {
            response.value = $0
            completion.complete()
        }

        await wait(for: [didRetry, completion])

        // Then
        #expect(retrier.retryCalledCount == 1)
        #expect(response.result?.isSuccess == true)
        #expect(response.value?.value?.data == body)
    }
}

@Suite(.storesInstances)
struct UploadRequestEventsTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadRequestTriggersAllAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didCreateInitialURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateURLRequest = Completion("didCreateURLRequest should fire")
        let didCreateTask = Completion("didCreateTask should fire")
        let didGatherMetrics = Completion("didGatherMetrics should fire")
        let didComplete = Completion("didComplete should fire")
        let didFinish = Completion("didFinish should fire")
        let didResume = Completion("didResume should fire")
        let didResumeTask = Completion("didResumeTask should fire")
        let didCreateUploadable = Completion("didCreateUploadable should fire")
        let didParseResponse = Completion("didParseResponse should fire")
        let responseHandler = Completion("responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.complete() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateInitialURLRequest.complete() }
        eventMonitor.requestDidCreateURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.complete() }
        eventMonitor.requestDidCreateUploadable = { _, _ in didCreateUploadable.complete() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.complete() }

        // When
        let request = session.upload(Data("PAYLOAD".utf8),
                                     with: Endpoint.method(.post)).response { _ in
            responseHandler.complete()
        }

        await wait(for: [taskDidFinishCollecting, didCreateInitialURLRequest, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didFinish, didResume, didResumeTask, didCreateUploadable, didParseResponse, responseHandler])

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledUploadRequestTriggersAllAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [eventMonitor]))

        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didCreateInitialURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateURLRequest = Completion("didCreateURLRequest should fire")
        let didCreateTask = Completion("didCreateTask should fire")
        let didGatherMetrics = Completion("didGatherMetrics should fire")
        let didComplete = Completion("didComplete should fire")
        let didFinish = Completion("didFinish should fire")
        let didResume = Completion("didResume should fire")
        let didResumeTask = Completion("didResumeTask should fire")
        let didCreateUploadable = Completion("didCreateUploadable should fire")
        let didParseResponse = Completion("didParseResponse should fire")
        let didCancel = Completion("didCancel should fire")
        let didCancelTask = Completion("didCancelTask should fire")
        let responseHandler = Completion("responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.complete() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateInitialURLRequest.complete() }
        eventMonitor.requestDidCreateURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidCreateUploadable = { _, _ in didCreateUploadable.complete() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.complete() }
        eventMonitor.requestDidCancel = { _ in didCancel.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in didCancelTask.complete() }

        // When
        let request = session.upload(Data("PAYLOAD".utf8),
                                     with: Endpoint.delay(5).modifying(\.method, to: .post)).response { _ in
            responseHandler.complete()
        }

        eventMonitor.requestDidResumeTask = { [unowned request] _, _ in
            request.cancel()
            didResumeTask.complete()
        }

        request.resume()

        await wait(for: [taskDidFinishCollecting, didCreateInitialURLRequest, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didFinish, didResume, didResumeTask, didCreateUploadable, didParseResponse, didCancel, didCancelTask, responseHandler])

        // Then
        #expect(request.state == .cancelled)
    }
}
