//
//  RequestTests.swift
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

class RequestInitializationTestCase: BaseTestCase {
    func testRequestClassMethodWithMethodAndURL() {
        // Given
        let urlString = "https://httpbin.org/"

        // When
        let request = Alamofire.request(urlString)

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertEqual(request.request?.url?.urlString, urlString)
        XCTAssertNil(request.response)
    }

    func testRequestClassMethodWithMethodAndURLAndParameters() {
        // Given
        let urlString = "https://httpbin.org/get"

        // When
        let request = Alamofire.request(urlString, parameters: ["foo": "bar"])

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertNotEqual(request.request?.url?.urlString, urlString)
        XCTAssertEqual(request.request?.url?.query, "foo=bar")
        XCTAssertNil(request.response)
    }

    func testRequestClassMethodWithMethodURLParametersAndHeaders() {
        // Given
        let urlString = "https://httpbin.org/get"
        let headers = ["Authorization": "123456"]

        // When
        let request = Alamofire.request(urlString, parameters: ["foo": "bar"], headers: headers)

        // Then
        XCTAssertNotNil(request.request)
        XCTAssertEqual(request.request?.httpMethod, "GET")
        XCTAssertNotEqual(request.request?.url?.urlString, urlString)
        XCTAssertEqual(request.request?.url?.query, "foo=bar")
        XCTAssertEqual(request.request?.value(forHTTPHeaderField: "Authorization"), "123456")
        XCTAssertNil(request.response)
    }
}

// MARK: -

class RequestResponseTestCase: BaseTestCase {
    func testRequestResponse() {
        // Given
        let urlString = "https://httpbin.org/get"

        let expectation = self.expectation(description: "GET request should succeed: \(urlString)")

        var response: DefaultDataResponse?

        // When
        Alamofire.request(urlString, parameters: ["foo": "bar"])
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

    func testRequestResponseWithProgress() {
        // Given
        let randomBytes = 4 * 1024 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var response: DefaultDataResponse?

        // When
        Alamofire.request(urlString)
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
        XCTAssertNotNil(response?.data)
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

    func testRequestResponseWithStream() {
        // Given
        let randomBytes = 4 * 1024 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var accumulatedData = [Data]()
        var response: DefaultDataResponse?

        // When
        Alamofire.request(urlString)
            .downloadProgress { progress in
                progressValues.append((progress.completedUnitCount, progress.totalUnitCount))
            }
            .downloadProgress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
                let bytes = (bytes: bytesRead, totalBytes: totalBytesRead, totalBytesExpected: totalBytesExpectedToRead)
                byteValues.append(bytes)
            }
            .stream { data in
                accumulatedData.append(data)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)
        XCTAssertGreaterThanOrEqual(accumulatedData.count, 1)

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
            XCTAssertEqual(accumulatedData.reduce(Int64(0)) { $0 + $1.count }, lastByteValue.totalBytes)
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }
    }

    func testPOSTRequestWithUnicodeParameters() {
        // Given
        let urlString = "https://httpbin.org/post"
        let parameters = [
            "french": "français",
            "japanese": "日本語",
            "arabic": "العربية",
            "emoji": "😃"
        ]

        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any>?

        // When
        Alamofire.request(urlString, method: .post, parameters: parameters)
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)

        if let json = response?.result.value as? [String: Any], let form = json["form"] as? [String: String] {
            XCTAssertEqual(form["french"], parameters["french"])
            XCTAssertEqual(form["japanese"], parameters["japanese"])
            XCTAssertEqual(form["arabic"], parameters["arabic"])
            XCTAssertEqual(form["emoji"], parameters["emoji"])
        } else {
            XCTFail("form parameter in JSON should not be nil")
        }
    }

    func testPOSTRequestWithBase64EncodedImages() {
        // Given
        let urlString = "https://httpbin.org/post"

        let pngBase64EncodedString: String = {
            let URL = url(forResource: "unicorn", withExtension: "png")
            let data = try! Data(contentsOf: URL)

            return data.base64EncodedString(options: .lineLength64Characters)
        }()

        let jpegBase64EncodedString: String = {
            let URL = url(forResource: "rainbow", withExtension: "jpg")
            let data = try! Data(contentsOf: URL)

            return data.base64EncodedString(options: .lineLength64Characters)
        }()

        let parameters = [
            "email": "user@alamofire.org",
            "png_image": pngBase64EncodedString,
            "jpeg_image": jpegBase64EncodedString
        ]

        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any>?

        // When
        Alamofire.request(urlString, method: .post, parameters: parameters)
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if let json = response?.result.value as? [String: Any], let form = json["form"] as? [String: String] {
            XCTAssertEqual(form["email"], parameters["email"])
            XCTAssertEqual(form["png_image"], parameters["png_image"])
            XCTAssertEqual(form["jpeg_image"], parameters["jpeg_image"])
        } else {
            XCTFail("form parameter in JSON should not be nil")
        }
    }
}

// MARK: -

extension Request {
    fileprivate func preValidate(operation: @escaping (Void) -> Void) -> Self {
        delegate.queue.addOperation {
            operation()
        }

        return self
    }

    fileprivate func postValidate(operation: @escaping (Void) -> Void) -> Self {
        delegate.queue.addOperation {
            operation()
        }

        return self
    }
}

// MARK: -

class RequestExtensionTestCase: BaseTestCase {
    func testThatRequestExtensionHasAccessToTaskDelegateQueue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "GET request should succeed: \(urlString)")

        var responses: [String] = []

        // When
        Alamofire.request(urlString)
            .preValidate {
                responses.append("preValidate")
            }
            .validate()
            .postValidate {
                responses.append("postValidate")
            }
            .response { _ in
                responses.append("response")
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        if responses.count == 3 {
            XCTAssertEqual(responses[0], "preValidate")
            XCTAssertEqual(responses[1], "postValidate")
            XCTAssertEqual(responses[2], "response")
        } else {
            XCTFail("responses count should be equal to 3")
        }
    }
}

// MARK: -

class RequestDescriptionTestCase: BaseTestCase {
    func testRequestDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let request = Alamofire.request(urlString)
        let initialRequestDescription = request.description

        let expectation = self.expectation(description: "Request description should update: \(urlString)")

        var finalRequestDescription: String?
        var response: HTTPURLResponse?

        // When
        request.response { resp in
            finalRequestDescription = request.description
            response = resp.response

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(initialRequestDescription, "GET https://httpbin.org/get")
        XCTAssertEqual(finalRequestDescription, "GET https://httpbin.org/get (\(response?.statusCode ?? -1))")
    }
}

// MARK: -

class RequestDebugDescriptionTestCase: BaseTestCase {
    // MARK: Properties

    let manager: SessionManager = {
        let manager = SessionManager(configuration: .default)
        manager.startRequestsImmediately = false
        return manager
    }()

    let managerWithAcceptLanguageHeader: SessionManager = {
        var headers = SessionManager.default.session.configuration.httpAdditionalHeaders ?? [:]
        headers["Accept-Language"] = "en-US"

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = headers

        let manager = SessionManager(configuration: configuration)
        manager.startRequestsImmediately = false

        return manager
    }()

    let managerWithContentTypeHeader: SessionManager = {
        var headers = SessionManager.default.session.configuration.httpAdditionalHeaders ?? [:]
        headers["Content-Type"] = "application/json"

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = headers

        let manager = SessionManager(configuration: configuration)
        manager.startRequestsImmediately = false

        return manager
    }()

    let managerDisallowingCookies: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false

        let manager = SessionManager(configuration: configuration)
        manager.startRequestsImmediately = false

        return manager
    }()

    // MARK: Tests

    func testGETRequestDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/get"

        // When
        let request = manager.request(urlString)
        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"])
        XCTAssertFalse(components.contains("-X"))
        XCTAssertEqual(components.last, "\"\(urlString)\"")
    }

    func testGETRequestWithDuplicateHeadersDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/get"

        // When
        let headers = [ "Accept-Language": "en-GB" ]
        let request = managerWithAcceptLanguageHeader.request(urlString, headers: headers)
        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"])
        XCTAssertFalse(components.contains("-X"))
        XCTAssertEqual(components.last, "\"\(urlString)\"")

        let tokens = request.debugDescription.components(separatedBy: "Accept-Language:")
        XCTAssertTrue(tokens.count == 2, "command should contain a single Accept-Language header")

        XCTAssertNotNil(request.debugDescription.range(of: "-H \"Accept-Language: en-GB\""))
    }

    func testPOSTRequestDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"

        // When
        let request = manager.request(urlString, method: .post)
        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"])
        XCTAssertEqual(components[3..<5], ["-X", "POST"])
        XCTAssertEqual(components.last, "\"\(urlString)\"")
    }

    func testPOSTRequestWithJSONParametersDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"

        let parameters = [
            "foo": "bar",
            "fo\"o": "b\"ar",
            "f'oo": "ba'r"
        ]

        // When
        let request = manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default)
        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"])
        XCTAssertEqual(components[3..<5], ["-X", "POST"])

        XCTAssertNotNil(request.debugDescription.range(of: "-H \"Content-Type: application/json\""))
        XCTAssertNotNil(request.debugDescription.range(of: "-d \"{"))
        XCTAssertNotNil(request.debugDescription.range(of: "\\\"f'oo\\\":\\\"ba'r\\\""))
        XCTAssertNotNil(request.debugDescription.range(of: "\\\"fo\\\\\\\"o\\\":\\\"b\\\\\\\"ar\\\""))
        XCTAssertNotNil(request.debugDescription.range(of: "\\\"foo\\\":\\\"bar\\"))

        XCTAssertEqual(components.last, "\"\(urlString)\"")
    }

    func testPOSTRequestWithCookieDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"

        let properties = [
            HTTPCookiePropertyKey.domain: "httpbin.org",
            HTTPCookiePropertyKey.path: "/post",
            HTTPCookiePropertyKey.name: "foo",
            HTTPCookiePropertyKey.value: "bar",
        ]

        let cookie = HTTPCookie(properties: properties)!
        manager.session.configuration.httpCookieStorage?.setCookie(cookie)

        // When
        let request = manager.request(urlString, method: .post)
        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"])
        XCTAssertEqual(components[3..<5], ["-X", "POST"])
        XCTAssertEqual(components.last, "\"\(urlString)\"")
        XCTAssertEqual(components[5..<6], ["-b"])
    }

    func testPOSTRequestWithCookiesDisabledDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"

        let properties = [
            HTTPCookiePropertyKey.domain: "httpbin.org",
            HTTPCookiePropertyKey.path: "/post",
            HTTPCookiePropertyKey.name: "foo",
            HTTPCookiePropertyKey.value: "bar",
        ]

        let cookie = HTTPCookie(properties: properties)!
        managerDisallowingCookies.session.configuration.httpCookieStorage?.setCookie(cookie)

        // When
        let request = managerDisallowingCookies.request(urlString, method: .post)
        let components = cURLCommandComponents(for: request)

        // Then
        let cookieComponents = components.filter { $0 == "-b" }
        XCTAssertTrue(cookieComponents.isEmpty)
    }

    func testMultipartFormDataRequestWithDuplicateHeadersDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"
        let japaneseData = "日本語".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let expectation = self.expectation(description: "multipart form data encoding should succeed")

        var request: Request?
        var components: [String] = []

        // When
        managerWithContentTypeHeader.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(japaneseData, withName: "japanese")
            },
            to: urlString,
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    request = upload
                    components = self.cURLCommandComponents(for: upload)

                    expectation.fulfill()
                case .failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectations(timeout: timeout, handler: nil)

        debugPrint(request!)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-i"])
        XCTAssertTrue(components.contains("-X"))
        XCTAssertEqual(components.last, "\"\(urlString)\"")

        let tokens = request.debugDescription.components(separatedBy: "Content-Type:")
        XCTAssertTrue(tokens.count == 2, "command should contain a single Content-Type header")

        XCTAssertNotNil(request.debugDescription.range(of: "-H \"Content-Type: multipart/form-data;"))
    }

    func testThatRequestWithInvalidURLDebugDescription() {
        // Given
        let urlString = "invalid_url"

        // When
        let request = manager.request(urlString)
        let debugDescription = request.debugDescription

        // Then
        XCTAssertNotNil(debugDescription, "debugDescription should not crash")
    }

    // MARK: Test Helper Methods

    private func cURLCommandComponents(for request: Request) -> [String] {
        let whitespaceCharacterSet = CharacterSet.whitespacesAndNewlines
        return request.debugDescription
            .components(separatedBy: whitespaceCharacterSet)
            .filter { $0 != "" && $0 != "\\" }
    }
}
