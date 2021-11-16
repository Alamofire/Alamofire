//
//  ValidationTests.swift
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

@testable import Alamofire
import Foundation
import XCTest

final class StatusCodeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeResponseSucceeds() {
        // Given
        let endpoint = Endpoint.status(200)

        let expectation1 = expectation(description: "request should return 200 status code")
        let expectation2 = expectation(description: "download should return 200 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(statusCode: 200..<300)
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(statusCode: 200..<300)
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let endpoint = Endpoint.status(404)

        let expectation1 = expectation(description: "request should return 404 status code")
        let expectation2 = expectation(description: "download should return 404 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(statusCode: [200])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(statusCode: [200])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableStatusCode, true)
            XCTAssertEqual(error?.responseCode, 404)
        }
    }

    func testThatValidationForRequestWithNoAcceptableStatusCodesFails() {
        // Given
        let endpoint = Endpoint.status(201)

        let expectation1 = expectation(description: "request should return 201 status code")
        let expectation2 = expectation(description: "download should return 201 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(statusCode: [])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(statusCode: [])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableStatusCode, true)
            XCTAssertEqual(error?.responseCode, 201)
        }
    }
}

// MARK: -

final class ContentTypeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableContentTypeResponseSucceeds() {
        // Given
        let endpoint = Endpoint.ip

        let expectation1 = expectation(description: "request should succeed and return ip")
        let expectation2 = expectation(description: "download should succeed and return ip")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json; charset=utf-8"])
            .validate(contentType: ["application/json; q=0.8; charset=utf-8"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json; charset=utf-8"])
            .validate(contentType: ["application/json; q=0.8; charset=utf-8"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let endpoint = Endpoint.ip

        let expectation1 = expectation(description: "request should succeed and return ip")
        let expectation2 = expectation(description: "download should succeed and return ip")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let endpoint = Endpoint.xml

        let expectation1 = expectation(description: "request should succeed and return xml")
        let expectation2 = expectation(description: "download should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableContentType, true)
            XCTAssertEqual(error?.responseContentType, "application/xml")
            XCTAssertEqual(error?.acceptableContentTypes?.first, "application/octet-stream")
        }
    }

    func testThatContentTypeValidationFailureSortsPossibleContentTypes() {
        // Given
        let endpoint = Endpoint.xml

        let requestDidCompleteExpectation = expectation(description: "request should succeed and return xml")
        let downloadDidCompleteExpectation = expectation(description: "download should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        let acceptableContentTypes = [// Sorted in a random order, not alphabetically
            "application/octet-stream",
            "image/gif",
            "image/x-xbitmap",
            "image/tiff",
            "image/jpg",
            "image/x-bmp",
            "image/jpeg",
            "image/x-icon",
            "image/jp2",
            "image/png",
            "image/ico",
            "image/bmp",
            "image/x-ms-bmp",
            "image/x-win-bitmap"]

        // When
        AF.request(endpoint)
            .validate(contentType: acceptableContentTypes)
            .response { resp in
                requestError = resp.error
                requestDidCompleteExpectation.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: acceptableContentTypes)
            .response { resp in
                downloadError = resp.error
                downloadDidCompleteExpectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        let expectedAcceptableContentTypes = [// Sorted in a specific order, alphabetically
            "application/octet-stream",
            "image/bmp",
            "image/gif",
            "image/ico",
            "image/jp2",
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/tiff",
            "image/x-bmp",
            "image/x-icon",
            "image/x-ms-bmp",
            "image/x-win-bitmap",
            "image/x-xbitmap"]

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableContentType, true)
            XCTAssertEqual(error?.responseContentType, "application/xml")
            XCTAssertEqual(error?.acceptableContentTypes, expectedAcceptableContentTypes)
        }
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseFails() {
        // Given
        let endpoint = Endpoint.xml

        let expectation1 = expectation(description: "request should succeed and return xml")
        let expectation2 = expectation(description: "download should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(contentType: [])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: [])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableContentType, true)
            XCTAssertEqual(error?.responseContentType, "application/xml")
            XCTAssertEqual(error?.acceptableContentTypes?.isEmpty, true)
        }
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseSucceedsWhenNoDataIsReturned() {
        // Given
        let endpoint = Endpoint.status(204)

        let expectation1 = expectation(description: "request should succeed and return no data")
        let expectation2 = expectation(description: "download should succeed and return no data")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(contentType: [])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: [])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceedsWhenResponseIsNil() {
        // Given
        class MockManager: Session {
            override func request(_ convertible: URLRequestConvertible,
                                  interceptor: RequestInterceptor? = nil) -> DataRequest {
                let request = MockDataRequest(convertible: convertible,
                                              underlyingQueue: rootQueue,
                                              serializationQueue: serializationQueue,
                                              eventMonitor: eventMonitor,
                                              interceptor: interceptor,
                                              delegate: self)

                perform(request)

                return request
            }

            override func download(_ convertible: URLRequestConvertible,
                                   interceptor: RequestInterceptor? = nil,
                                   to destination: DownloadRequest.Destination?)
                -> DownloadRequest {
                let request = MockDownloadRequest(downloadable: .request(convertible),
                                                  underlyingQueue: rootQueue,
                                                  serializationQueue: serializationQueue,
                                                  eventMonitor: eventMonitor,
                                                  interceptor: interceptor,
                                                  delegate: self,
                                                  destination: destination ?? MockDownloadRequest.defaultDestination)

                perform(request)

                return request
            }
        }

        class MockDataRequest: DataRequest {
            override var response: HTTPURLResponse? {
                MockHTTPURLResponse(url: request!.url!,
                                    statusCode: 204,
                                    httpVersion: "HTTP/1.1",
                                    headerFields: nil)
            }
        }

        class MockDownloadRequest: DownloadRequest {
            override var response: HTTPURLResponse? {
                MockHTTPURLResponse(url: request!.url!,
                                    statusCode: 204,
                                    httpVersion: "HTTP/1.1",
                                    headerFields: nil)
            }
        }

        class MockHTTPURLResponse: HTTPURLResponse {
            override var mimeType: String? { nil }
        }

        let manager: Session = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.headers = HTTPHeaders.default

                return configuration
            }()

            return MockManager(configuration: configuration)
        }()

        let endpoint = Endpoint.method(.delete)

        let expectation1 = expectation(description: "request should be stubbed and return 204 status code")
        let expectation2 = expectation(description: "download should be stubbed and return 204 status code")

        var requestResponse: DataResponse<Data?, AFError>?
        var downloadResponse: DownloadResponse<URL?, AFError>?

        // When
        manager.request(endpoint)
            .validate(contentType: ["*/*"])
            .response { resp in
                requestResponse = resp
                expectation1.fulfill()
            }

        manager.download(endpoint)
            .validate(contentType: ["*/*"])
            .response { resp in
                downloadResponse = resp
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestResponse?.response)
        XCTAssertNotNil(requestResponse?.data)
        XCTAssertNil(requestResponse?.error)

        XCTAssertEqual(requestResponse?.response?.statusCode, 204)
        XCTAssertNil(requestResponse?.response?.mimeType)

        XCTAssertNotNil(downloadResponse?.response)
        XCTAssertNotNil(downloadResponse?.fileURL)
        XCTAssertNil(downloadResponse?.error)

        XCTAssertEqual(downloadResponse?.response?.statusCode, 204)
        XCTAssertNil(downloadResponse?.response?.mimeType)
    }
}

// MARK: -

final class MultipleValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let endpoint = Endpoint.ip

        let expectation1 = expectation(description: "request should succeed and return ip")
        let expectation2 = expectation(description: "request should succeed and return ip")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithStatusCodeError() {
        // Given
        let endpoint = Endpoint.xml

        let expectation1 = expectation(description: "request should succeed and return xml")
        let expectation2 = expectation(description: "download should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableStatusCode, true)
            XCTAssertEqual(error?.responseCode, 200)
        }
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithContentTypeError() {
        // Given
        let endpoint = Endpoint.xml

        let expectation1 = expectation(description: "request should succeed and return xml")
        let expectation2 = expectation(description: "download should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableContentType, true)
            XCTAssertEqual(error?.responseContentType, "application/xml")
            XCTAssertEqual(error?.acceptableContentTypes?.first, "application/octet-stream")
        }
    }
}

// MARK: -

final class AutomaticValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let urlRequest = Endpoint.ip.modifying(\.headers, to: [.accept("application/json")])

        let expectation1 = expectation(description: "request should succeed and return ip")
        let expectation2 = expectation(description: "download should succeed and return ip")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        AF.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let request = Endpoint.status(404)

        let expectation1 = expectation(description: "request should return 404 status code")
        let expectation2 = expectation(description: "download should return 404 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(request)
            .validate()
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(request)
            .validate()
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableStatusCode, true)
            XCTAssertEqual(error?.responseCode, 404)
        }
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let urlRequest = Endpoint.ip.modifying(\.headers, to: [.accept("application/*")])

        let expectation1 = expectation(description: "request should succeed and return ip")
        let expectation2 = expectation(description: "download should succeed and return ip")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        AF.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithAcceptableComplexContentTypeResponseSucceeds() {
        // Given
        var urlRequest = Endpoint.xml.urlRequest

        let headerValue = "text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5"
        urlRequest.headers["Accept"] = headerValue

        let expectation1 = expectation(description: "request should succeed and return xml")
        let expectation2 = expectation(description: "request should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        AF.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let urlRequest = Endpoint.xml.modifying(\.headers, to: [.accept("application/json")])

        let expectation1 = expectation(description: "request should succeed and return xml")
        let expectation2 = expectation(description: "download should succeed and return xml")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        AF.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            XCTAssertEqual(error?.isUnacceptableContentType, true)
            XCTAssertEqual(error?.responseContentType, "application/xml")
            XCTAssertEqual(error?.acceptableContentTypes?.first, "application/json")
        }
    }
}

// MARK: -

private enum ValidationError: Error {
    case missingData, missingFile, fileReadFailed
}

extension DataRequest {
    func validateDataExists() -> Self {
        validate { _, _, data in
            guard data != nil else { return .failure(ValidationError.missingData) }
            return .success(())
        }
    }

    func validate(with error: Error) -> Self {
        validate { _, _, _ in .failure(error) }
    }
}

extension DownloadRequest {
    func validateDataExists() -> Self {
        validate { [unowned self] _, _, _ in
            let fileURL = self.fileURL

            guard let validFileURL = fileURL else { return .failure(ValidationError.missingFile) }

            do {
                _ = try Data(contentsOf: validFileURL)
                return .success(())
            } catch {
                return .failure(ValidationError.fileReadFailed)
            }
        }
    }

    func validate(with error: Error) -> Self {
        validate { _, _, _ in .failure(error) }
    }
}

// MARK: -

final class CustomValidationTestCase: BaseTestCase {
    func testThatCustomValidationClosureHasAccessToServerResponseData() {
        // Given
        let endpoint = Endpoint()

        let expectation1 = expectation(description: "request should return 200 status code")
        let expectation2 = expectation(description: "download should return 200 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate { _, _, data in
                guard data != nil else { return .failure(ValidationError.missingData) }
                return .success(())
            }
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate { _, _, fileURL in
                guard let fileURL = fileURL else { return .failure(ValidationError.missingFile) }

                do {
                    _ = try Data(contentsOf: fileURL)
                    return .success(())
                } catch {
                    return .failure(ValidationError.fileReadFailed)
                }
            }
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatCustomValidationCanThrowCustomError() {
        // Given
        let endpoint = Endpoint()

        let expectation1 = expectation(description: "request should return 200 status code")
        let expectation2 = expectation(description: "download should return 200 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate { _, _, _ in .failure(ValidationError.missingData) }
            .validate { _, _, _ in .failure(ValidationError.missingFile) } // should be ignored
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate { _, _, _ in .failure(ValidationError.missingFile) }
            .validate { _, _, _ in .failure(ValidationError.fileReadFailed) } // should be ignored
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(requestError?.asAFError?.underlyingError as? ValidationError, .missingData)
        XCTAssertEqual(downloadError?.asAFError?.underlyingError as? ValidationError, .missingFile)
    }

    func testThatValidationExtensionHasAccessToServerResponseData() {
        // Given
        let endpoint = Endpoint()

        let expectation1 = expectation(description: "request should return 200 status code")
        let expectation2 = expectation(description: "download should return 200 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validateDataExists()
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validateDataExists()
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationExtensionCanThrowCustomError() {
        // Given
        let endpoint = Endpoint()

        let expectation1 = expectation(description: "request should return 200 status code")
        let expectation2 = expectation(description: "download should return 200 status code")

        var requestError: AFError?
        var downloadError: AFError?

        // When
        AF.request(endpoint)
            .validate(with: ValidationError.missingData)
            .validate(with: ValidationError.missingFile) // should be ignored
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        AF.download(endpoint)
            .validate(with: ValidationError.missingFile)
            .validate(with: ValidationError.fileReadFailed) // should be ignored
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(requestError?.asAFError?.underlyingError as? ValidationError, .missingData)
        XCTAssertEqual(downloadError?.asAFError?.underlyingError as? ValidationError, .missingFile)
    }
}
