//
//  ValidationTests.swift
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

@testable import Alamofire
import Foundation
import XCTest

class StatusCodeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/status/200"
        let expectation = self.expectation(description: "request should return 200 status code")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(statusCode: 200..<300)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/status/404"
        let expectation = self.expectation(description: "request should return 404 status code")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(statusCode: [200])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError, let statusCode = error.responseCode {
            XCTAssertTrue(error.isUnacceptableStatusCode)
            XCTAssertEqual(statusCode, 404)
        } else {
            XCTFail("Error should not be nil, should be an AFError, and should have an associated statusCode.")
        }
    }

    func testThatValidationForRequestWithNoAcceptableStatusCodesFails() {
        // Given
        let urlString = "https://httpbin.org/status/201"
        let expectation = self.expectation(description: "request should return 201 status code")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(statusCode: [])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError, let statusCode = error.responseCode {
            XCTAssertTrue(error.isUnacceptableStatusCode)
            XCTAssertEqual(statusCode, 201)
        } else {
            XCTFail("Error should not be nil, should be an AFError, and should have an associated statusCode.")
        }
    }
}

// MARK: -

class ContentTypeValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableContentTypeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/ip"
        let expectation = self.expectation(description: "request should succeed and return ip")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json;charset=utf8"])
            .validate(contentType: ["application/json;q=0.8;charset=utf8"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/ip"
        let expectation = self.expectation(description: "request should succeed and return ip")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/xml"
        let expectation = self.expectation(description: "request should succeed and return xml")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(contentType: ["application/octet-stream"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError {
            XCTAssertTrue(error.isUnacceptableContentType)
            XCTAssertEqual(error.responseContentType, "application/xml")
            XCTAssertEqual(error.acceptableContentTypes?.first, "application/octet-stream")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/xml"
        let expectation = self.expectation(description: "request should succeed and return xml")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(contentType: [])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")

        if let error = error as? AFError {
            XCTAssertTrue(error.isUnacceptableContentType)
            XCTAssertEqual(error.responseContentType, "application/xml")
            XCTAssertTrue(error.acceptableContentTypes?.isEmpty ?? false)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatValidationForRequestWithNoAcceptableContentTypeResponseSucceedsWhenNoDataIsReturned() {
        // Given
        let urlString = "https://httpbin.org/status/204"
        let expectation = self.expectation(description: "request should succeed and return no data")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(contentType: [])
            .response { _, response, data, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceedsWhenResponseIsNil() {
        // Given
        class MockManager: SessionManager {
            override func request(_ urlRequest: URLRequestConvertible) -> Request {
                let urlRequest = urlRequest.urlRequest
                var dataTask: URLSessionDataTask!

                queue.sync { dataTask = self.session.dataTask(with: urlRequest) }

                let request = MockRequest(session: session, task: dataTask, originalTask: .data(urlRequest))
                delegate[request.delegate.task] = request

                if startRequestsImmediately {
                    request.resume()
                }

                return request
            }
        }

        class MockRequest: Request {
            override var response: HTTPURLResponse? {
                return MockHTTPURLResponse(
                    url: URL(string: request!.urlString)!,
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
        let expectation = self.expectation(description: "request should be stubbed and return 204 status code")

        var response: HTTPURLResponse?
        var data: Data?
        var error: Error?

        // When
        manager.request(urlString, withMethod: .delete)
            .validate(contentType: ["*/*"])
            .response { _, responseResponse, responseData, responseError in
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response)
        XCTAssertNotNil(data)
        XCTAssertNil(error)

        if let response = response {
            XCTAssertEqual(response.statusCode, 204)
            XCTAssertNil(response.mimeType)
        }
    }
}

// MARK: -

class MultipleValidationTestCase: BaseTestCase {
    func testThatValidationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() {
        // Given
        let urlString = "https://httpbin.org/ip"
        let expectation = self.expectation(description: "request should succeed and return ip")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithStatusCodeError() {
        // Given
        let urlString = "https://httpbin.org/xml"
        let expectation = self.expectation(description: "request should succeed and return xml")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError {
            XCTAssertTrue(error.isUnacceptableStatusCode)
            XCTAssertEqual(error.responseCode, 200)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithContentTypeError() {
        // Given
        let urlString = "https://httpbin.org/xml"
        let expectation = self.expectation(description: "request should succeed and return xml")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError {
            XCTAssertTrue(error.isUnacceptableContentType)
            XCTAssertEqual(error.responseContentType, "application/xml")
            XCTAssertEqual(error.acceptableContentTypes?.first, "application/octet-stream")
        } else {
            XCTFail("error should not be nil")
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

        let expectation = self.expectation(description: "request should succeed and return ip")

        var error: Error?

        // When
        Alamofire.request(urlRequest)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithUnacceptableStatusCodeResponseFails() {
        // Given
        let urlString = "https://httpbin.org/status/404"
        let expectation = self.expectation(description: "request should return 404 status code")

        var error: Error?

        // When
        Alamofire.request(urlString, withMethod: .get)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError, let statusCode = error.responseCode {
            XCTAssertTrue(error.isUnacceptableStatusCode)
            XCTAssertEqual(statusCode, 404)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatValidationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() {
        // Given
        let url = URL(string: "https://httpbin.org/ip")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/*", forHTTPHeaderField: "Accept")

        let expectation = self.expectation(description: "request should succeed and return ip")

        var error: Error?

        // When
        Alamofire.request(urlRequest)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithAcceptableComplexContentTypeResponseSucceeds() {
        // Given
        let url = URL(string: "https://httpbin.org/xml")!
        var urlRequest = URLRequest(url: url)

        let headerValue = "text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5"
        urlRequest.setValue(headerValue, forHTTPHeaderField: "Accept")

        let expectation = self.expectation(description: "request should succeed and return xml")

        var error: Error?

        // When
        Alamofire.request(urlRequest)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error)
    }

    func testThatValidationForRequestWithUnacceptableContentTypeResponseFails() {
        // Given
        let url = URL(string: "https://httpbin.org/xml")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let expectation = self.expectation(description: "request should succeed and return xml")

        var error: Error?

        // When
        Alamofire.request(urlRequest)
            .validate()
            .response { _, _, _, responseError in
                error = responseError
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error)

        if let error = error as? AFError {
            XCTAssertTrue(error.isUnacceptableContentType)
            XCTAssertEqual(error.responseContentType, "application/xml")
            XCTAssertEqual(error.acceptableContentTypes?.first, "application/json")
        } else {
            XCTFail("error should not be nil")
        }
    }
}
