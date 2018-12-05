//
//  RequestTests.swift
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

// MARK: -

class RequestResponseTestCase: BaseTestCase {
    func testRequestResponse() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "GET request should succeed: \(urlString)")
        var response: DataResponse<Data?>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"])
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
        let randomBytes = 1 * 1024 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var progressValues: [Double] = []
        var response: DataResponse<Data?>?

        // When
        AF.request(urlString)
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
        XCTAssertNotNil(response?.data)
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
        AF.request(urlString, method: .post, parameters: parameters)
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
        AF.request(urlString, method: .post, parameters: parameters)
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

    // MARK: Serialization Queue

    func testThatResponseSerializationWorksWithSerializationQueue() {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.serializationQueue")
        let manager = Session(serializationQueue: queue)
        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<Any>?

        // When
        manager.request("https://httpbin.org/get").responseJSON { (resp) in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    // MARK: Encodable Parameters

    func testThatRequestsCanPassEncodableParametersAsJSONBodyData() {
        // Given
        let parameters = HTTPBinParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<HTTPBinResponse>?

        // When
        AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: JSONParameterEncoder.default)
          .responseDecodable { (response: DataResponse<HTTPBinResponse>) in
              receivedResponse = response
              expect.fulfill()
          }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(receivedResponse?.result.value?.data, "{\"property\":\"one\"}")
    }

    func testThatRequestsCanPassEncodableParametersAsAURLQuery() {
        // Given
        let parameters = HTTPBinParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<HTTPBinResponse>?

        // When
        AF.request("https://httpbin.org/get", method: .get, parameters: parameters)
          .responseDecodable { (response: DataResponse<HTTPBinResponse>) in
              receivedResponse = response
              expect.fulfill()
          }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(receivedResponse?.result.value?.args, ["property": "one"])
    }

    func testThatRequestsCanPassEncodableParametersAsURLEncodedBodyData() {
        // Given
        let parameters = HTTPBinParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<HTTPBinResponse>?

        // When
        AF.request("https://httpbin.org/post", method: .post, parameters: parameters)
            .responseDecodable { (response: DataResponse<HTTPBinResponse>) in
                receivedResponse = response
                expect.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(receivedResponse?.result.value?.form, ["property": "one"])
    }
}

// MARK: -

class RequestDescriptionTestCase: BaseTestCase {
    func testRequestDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let manager = Session(startRequestsImmediately: false)
        let request = manager.request(urlString)

        let expectation = self.expectation(description: "Request description should update: \(urlString)")

        var response: HTTPURLResponse?

        // When
        request.response { resp in
            response = resp.response

            expectation.fulfill()
        }.resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.description, "GET https://httpbin.org/get (\(response?.statusCode ?? -1))")
    }
}

// MARK: -

class RequestDebugDescriptionTestCase: BaseTestCase {
    // MARK: Properties

    let manager: Session = {
        let manager = Session()

        return manager
    }()

    let managerWithAcceptLanguageHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Accept-Language"] = "en-US"

        let configuration = URLSessionConfiguration.alamofireDefault
        configuration.httpHeaders = headers

        let manager = Session(configuration: configuration)

        return manager
    }()

    let managerWithContentTypeHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Content-Type"] = "application/json"

        let configuration = URLSessionConfiguration.alamofireDefault
        configuration.httpHeaders = headers

        let manager = Session(configuration: configuration)

        return manager
    }()

    func managerWithCookie(_ cookie: HTTPCookie) -> Session {
        let configuration = URLSessionConfiguration.alamofireDefault
        configuration.httpCookieStorage?.setCookie(cookie)

        return Session(configuration: configuration)
    }

    let managerDisallowingCookies: Session = {
        let configuration = URLSessionConfiguration.alamofireDefault
        configuration.httpShouldSetCookies = false

        let manager = Session(configuration: configuration)

        return manager
    }()

    // MARK: Tests

    func testGETRequestDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")

        // When
        let request = manager.request(urlString).response { _ in expectation.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components.contains("-X"))
        XCTAssertEqual(components.last, "\"\(urlString)\"")
    }

    func testGETRequestWithJSONHeaderDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")

        // When
        let headers: HTTPHeaders = [ "X-Custom-Header": "{\"key\": \"value\"}" ]
        let request = manager.request(urlString, headers: headers).response { _ in expectation.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request.debugDescription.range(of: "-H \"X-Custom-Header: {\\\"key\\\": \\\"value\\\"}\""))
    }

    func testGETRequestWithDuplicateHeadersDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")

        // When
        let headers: HTTPHeaders = [ "Accept-Language": "en-GB" ]
        let request = managerWithAcceptLanguageHeader.request(urlString, headers: headers).response { _ in expectation.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components.contains("-X"))
        XCTAssertEqual(components.last, "\"\(urlString)\"")

        let tokens = request.debugDescription.components(separatedBy: "Accept-Language:")
        XCTAssertTrue(tokens.count == 2, "command should contain a single Accept-Language header")

        XCTAssertNotNil(request.debugDescription.range(of: "-H \"Accept-Language: en-GB\""))
    }

    func testPOSTRequestDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "request should complete")


        // When
        let request = manager.request(urlString, method: .post).response { _ in expectation.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components[3..<5], ["-X", "POST"])
        XCTAssertEqual(components.last, "\"\(urlString)\"")
    }

    func testPOSTRequestWithJSONParametersDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "request should complete")

        let parameters = [
            "foo": "bar",
            "fo\"o": "b\"ar",
            "f'oo": "ba'r"
        ]

        // When
        let request = manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default).response {
            _ in expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-v"])
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
        let cookieManager = managerWithCookie(cookie)
        let expectation = self.expectation(description: "request should complete")


        // When
        let request = cookieManager.request(urlString, method: .post).response { _ in expectation.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-v"])
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
        let japaneseData = Data("日本語".utf8)
        let expectation = self.expectation(description: "multipart form data encoding should succeed")

        // When
        let request = managerWithContentTypeHeader.upload(multipartFormData: { (data) in
            data.append(japaneseData, withName: "japanese")
        }, to: urlString)
            .response { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        let components = cURLCommandComponents(for: request)

        // Then
        XCTAssertEqual(components[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components.contains("-X"))
        XCTAssertEqual(components.last, "\"\(urlString)\"")

        let tokens = request.debugDescription.components(separatedBy: "Content-Type:")
        XCTAssertTrue(tokens.count == 2, "command should contain a single Content-Type header")

        XCTAssertNotNil(request.debugDescription.range(of: "-H \"Content-Type: multipart/form-data;"))
    }

    func testThatRequestWithInvalidURLDebugDescription() {
        // Given
        let urlString = "invalid_url"
        let expectation = self.expectation(description: "request should complete")

        // When
        let request = manager.request(urlString).response { _ in expectation.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

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
