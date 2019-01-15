//
//  ValidationTests.swift
//
//  Copyright (c) 2014 Alamofire Software Foundation (http://alamofire.org/)
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

class StatusCodeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/status/200"

        let expectation1 = self.expectation(description: "request should return 200 status code")
        let expectation2 = self.expectation(description: "download should return 200 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(statusCode: 200..<300)
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(statusCode: 200..<300)
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/status/404"

        let expectation1 = self.expectation(description: "request should return 404 status code")
        let expectation2 = self.expectation(description: "download should return 404 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(statusCode: [200])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(statusCode: [200])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError, let statusCode = error.responseCode {
                XCTAssertTrue(error.isUnacceptableStatusCode)
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Error should not be nil, should be an AFError, and should have an associated statusCode.")
            }
        }
    }

    func testThatValidationForRequestWithNoAcceptableStatusCodesFails() {
        // Given
        let urlString = "https://httpbin.org/status/201"

        let expectation1 = self.expectation(description: "request should return 201 status code")
        let expectation2 = self.expectation(description: "download should return 201 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(statusCode: [])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(statusCode: [])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError, let statusCode = error.responseCode {
                XCTAssertTrue(error.isUnacceptableStatusCode)
                XCTAssertEqual(statusCode, 201)
            } else {
                XCTFail("Error should not be nil, should be an AFError, and should have an associated statusCode.")
            }
        }
    }
}

// MARK: -

class ContentTypeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableContentTypeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/ip"

        let expectation1 = self.expectation(description: "request should succeed and return ip")
        let expectation2 = self.expectation(description: "download should succeed and return ip")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json; charset=utf-8"])
            .validate(contentType: ["application/json; q=0.8; charset=utf-8"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json; charset=utf-8"])
            .validate(contentType: ["application/json; q=0.8; charset=utf-8"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/ip"

        let expectation1 = self.expectation(description: "request should succeed and return ip")
        let expectation2 = self.expectation(description: "download should succeed and return ip")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/xml"

        let expectation1 = self.expectation(description: "request should succeed and return xml")
        let expectation2 = self.expectation(description: "download should succeed and return xml")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError {
                XCTAssertTrue(error.isUnacceptableContentType)
                XCTAssertEqual(error.responseContentType, "application/xml")
                XCTAssertEqual(error.acceptableContentTypes?.first, "application/octet-stream")
            } else {
                XCTFail("error should not be nil")
            }
        }
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/xml"

        let expectation1 = self.expectation(description: "request should succeed and return xml")
        let expectation2 = self.expectation(description: "download should succeed and return xml")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(contentType: [])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(contentType: [])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError {
                XCTAssertTrue(error.isUnacceptableContentType)
                XCTAssertEqual(error.responseContentType, "application/xml")
                XCTAssertTrue(error.acceptableContentTypes?.isEmpty ?? false)
            } else {
                XCTFail("error should not be nil")
            }
        }
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseSucceedsWhenNoDataIsReturned() {
        // Given
        let urlString = "https://httpbin.org/status/204"

        let expectation1 = self.expectation(description: "request should succeed and return no data")
        let expectation2 = self.expectation(description: "download should succeed and return no data")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(contentType: [])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(contentType: [])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceedsWhenResponseIsNil() {
        // Given
        class MockManager: SessionManager {
            override func request(_ urlRequest: URLRequestConvertible) -> DataRequest {
                do {
                    let originalRequest = try urlRequest.asURLRequest()
                    let originalTask = DataRequest.Requestable(urlRequest: originalRequest)

                    let task = try originalTask.task(session: session, adapter: adapter, queue: queue)
                    let request = MockDataRequest(session: session, requestTask: .data(originalTask, task))

                    delegate[task] = request

                    if startRequestsImmediately { request.resume() }

                    return request
                } catch {
                    let request = DataRequest(session: session, requestTask: .data(nil, nil), error: error)
                    if startRequestsImmediately { request.resume() }
                    return request
                }
            }

            override func download(
                _ urlRequest: URLRequestConvertible,
                to destination: DownloadRequest.DownloadFileDestination? = nil)
                -> DownloadRequest
            {
                do {
                    let originalRequest = try urlRequest.asURLRequest()
                    let originalTask = DownloadRequest.Downloadable.request(originalRequest)

                    let task = try originalTask.task(session: session, adapter: adapter, queue: queue)
                    let request = MockDownloadRequest(session: session, requestTask: .download(originalTask, task))

                    request.downloadDelegate.destination = destination

                    delegate[task] = request

                    if startRequestsImmediately { request.resume() }

                    return request
                } catch {
                    let download = DownloadRequest(session: session, requestTask: .download(nil, nil), error: error)
                    if startRequestsImmediately { download.resume() }
                    return download
                }
            }
        }

        class MockDataRequest: DataRequest {
            override var response: HTTPURLResponse? {
                return MockHTTPURLResponse(
                    url: request!.url!,
                    statusCode: 204,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )
            }
        }

        class MockDownloadRequest: DownloadRequest {
            override var response: HTTPURLResponse? {
                return MockHTTPURLResponse(
                    url: request!.url!,
                    statusCode: 204,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )
            }
        }

        class MockHTTPURLResponse: HTTPURLResponse {
            override var mimeType: String? { return nil }
        }

        let manager: SessionManager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

                return configuration
            }()

            return MockManager(configuration: configuration)
        }()

        let urlString = "https://httpbin.org/delete"

        let expectation1 = self.expectation(description: "request should be stubbed and return 204 status code")
        let expectation2 = self.expectation(description: "download should be stubbed and return 204 status code")

        var requestResponse: DefaultDataResponse?
        var downloadResponse: DefaultDownloadResponse?

        // When
        manager.request(urlString, method: .delete)
            .validate(contentType: ["*/*"])
            .response { resp in
                requestResponse = resp
                expectation1.fulfill()
            }

        manager.download(urlString, method: .delete)
            .validate(contentType: ["*/*"])
            .response { resp in
                downloadResponse = resp
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestResponse?.response)
        XCTAssertNotNil(requestResponse?.data)
        XCTAssertNil(requestResponse?.error)

        XCTAssertEqual(requestResponse?.response?.statusCode, 204)
        XCTAssertNil(requestResponse?.response?.mimeType)

        XCTAssertNotNil(downloadResponse?.response)
        XCTAssertNotNil(downloadResponse?.temporaryURL)
        XCTAssertNil(downloadResponse?.destinationURL)
        XCTAssertNil(downloadResponse?.error)

        XCTAssertEqual(downloadResponse?.response?.statusCode, 204)
        XCTAssertNil(downloadResponse?.response?.mimeType)
    }
}

// MARK: -

class MultipleValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/ip"

        let expectation1 = self.expectation(description: "request should succeed and return ip")
        let expectation2 = self.expectation(description: "request should succeed and return ip")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithStatusCodeError() {
        // Given
        let urlString = "https://httpbin.org/xml"

        let expectation1 = self.expectation(description: "request should succeed and return xml")
        let expectation2 = self.expectation(description: "download should succeed and return xml")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError {
                XCTAssertTrue(error.isUnacceptableStatusCode)
                XCTAssertEqual(error.responseCode, 200)
            } else {
                XCTFail("error should not be nil")
            }
        }
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithContentTypeError() {
        // Given
        let urlString = "https://httpbin.org/xml"

        let expectation1 = self.expectation(description: "request should succeed and return xml")
        let expectation2 = self.expectation(description: "download should succeed and return xml")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError {
                XCTAssertTrue(error.isUnacceptableContentType)
                XCTAssertEqual(error.responseContentType, "application/xml")
                XCTAssertEqual(error.acceptableContentTypes?.first, "application/octet-stream")
            } else {
                XCTFail("error should not be nil")
            }
        }
    }
}

// MARK: -

class AutomaticValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let url = URL(string: "https://httpbin.org/ip")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation1 = self.expectation(description: "request should succeed and return ip")
        let expectation2 = self.expectation(description: "download should succeed and return ip")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        Alamofire.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/status/404"

        let expectation1 = self.expectation(description: "request should return 404 status code")
        let expectation2 = self.expectation(description: "download should return 404 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate()
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate()
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError, let statusCode = error.responseCode {
                XCTAssertTrue(error.isUnacceptableStatusCode)
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("error should not be nil")
            }
        }
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let url = URL(string: "https://httpbin.org/ip")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/*", forHTTPHeaderField: "Accept")

        let expectation1 = self.expectation(description: "request should succeed and return ip")
        let expectation2 = self.expectation(description: "download should succeed and return ip")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        Alamofire.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithAcceptableComplexContentTypeResponseSucceeds() {
        // Given
        let url = URL(string: "https://httpbin.org/xml")!
        var urlRequest = URLRequest(url: url)

        let headerValue = "text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5"
        urlRequest.setValue(headerValue, forHTTPHeaderField: "Accept")

        let expectation1 = self.expectation(description: "request should succeed and return xml")
        let expectation2 = self.expectation(description: "request should succeed and return xml")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        Alamofire.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let url = URL(string: "https://httpbin.org/xml")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation1 = self.expectation(description: "request should succeed and return xml")
        let expectation2 = self.expectation(description: "download should succeed and return xml")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlRequest).validate().response { resp in
            requestError = resp.error
            expectation1.fulfill()
        }

        Alamofire.download(urlRequest).validate().response { resp in
            downloadError = resp.error
            expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(requestError)
        XCTAssertNotNil(downloadError)

        for error in [requestError, downloadError] {
            if let error = error as? AFError {
                XCTAssertTrue(error.isUnacceptableContentType)
                XCTAssertEqual(error.responseContentType, "application/xml")
                XCTAssertEqual(error.acceptableContentTypes?.first, "application/json")
            } else {
                XCTFail("error should not be nil")
            }
        }
    }
}

// MARK: -

private enum ValidationError: Error {
    case missingData, missingFile, fileReadFailed
}

extension DataRequest {
    func validateDataExists() -> Self {
        return validate { request, response, data in
            guard data != nil else { return .failure(ValidationError.missingData) }
            return .success
        }
    }

    func validate(with error: Error) -> Self {
        return validate { _, _, _ in .failure(error) }
    }
}

extension DownloadRequest {
    func validateDataExists() -> Self {
        return validate { request, response, _, _ in
            let fileURL = self.downloadDelegate.fileURL

            guard let validFileURL = fileURL else { return .failure(ValidationError.missingFile) }

            do {
                let _ = try Data(contentsOf: validFileURL)
                return .success
            } catch {
                return .failure(ValidationError.fileReadFailed)
            }
        }
    }

    func validate(with error: Error) -> Self {
        return validate { _, _, _, _ in .failure(error) }
    }
}

// MARK: -

class CustomValidationTestCase: BaseTestCase {
    func testThatCustomValidationClosureHasAccessToServerResponseData() {
        // Given
        let urlString = "https://httpbin.org/get"

        let expectation1 = self.expectation(description: "request should return 200 status code")
        let expectation2 = self.expectation(description: "download should return 200 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate { request, response, data in
                guard data != nil else { return .failure(ValidationError.missingData) }
                return .success
            }
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate { request, response, temporaryURL, destinationURL in
                guard let fileURL = temporaryURL else { return .failure(ValidationError.missingFile) }

                do {
                    let _ = try Data(contentsOf: fileURL)
                    return .success
                } catch {
                    return .failure(ValidationError.fileReadFailed)
                }
            }
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatCustomValidationCanThrowCustomError() {
        // Given
        let urlString = "https://httpbin.org/get"

        let expectation1 = self.expectation(description: "request should return 200 status code")
        let expectation2 = self.expectation(description: "download should return 200 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate { _, _, _ in .failure(ValidationError.missingData) }
            .validate { _, _, _ in .failure(ValidationError.missingFile) } // should be ignored
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate { _, _, _, _ in .failure(ValidationError.missingFile) }
            .validate { _, _, _, _ in .failure(ValidationError.fileReadFailed) } // should be ignored
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(requestError as? ValidationError, ValidationError.missingData)
        XCTAssertEqual(downloadError as? ValidationError, ValidationError.missingFile)
    }

    func testThatValidationExtensionHasAccessToServerResponseData() {
        // Given
        let urlString = "https://httpbin.org/get"

        let expectation1 = self.expectation(description: "request should return 200 status code")
        let expectation2 = self.expectation(description: "download should return 200 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validateDataExists()
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
        }

        Alamofire.download(urlString)
            .validateDataExists()
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(requestError)
        XCTAssertNil(downloadError)
    }

    func testThatValidationExtensionCanThrowCustomError() {
        // Given
        let urlString = "https://httpbin.org/get"

        let expectation1 = self.expectation(description: "request should return 200 status code")
        let expectation2 = self.expectation(description: "download should return 200 status code")

        var requestError: Error?
        var downloadError: Error?

        // When
        Alamofire.request(urlString)
            .validate(with: ValidationError.missingData)
            .validate(with: ValidationError.missingFile) // should be ignored
            .response { resp in
                requestError = resp.error
                expectation1.fulfill()
            }

        Alamofire.download(urlString)
            .validate(with: ValidationError.missingFile)
            .validate(with: ValidationError.fileReadFailed) // should be ignored
            .response { resp in
                downloadError = resp.error
                expectation2.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(requestError as? ValidationError, ValidationError.missingData)
        XCTAssertEqual(downloadError as? ValidationError, ValidationError.missingFile)
    }
}
