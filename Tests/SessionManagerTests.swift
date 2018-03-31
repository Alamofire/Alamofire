//
//  SessionManagerTests.swift
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

class SessionManagerTestCase: BaseTestCase {

    // MARK: Helper Types

    private class HTTPMethodAdapter: RequestAdapter {
        let method: HTTPMethod
        let throwsError: Bool

        init(method: HTTPMethod, throwsError: Bool = false) {
            self.method = method
            self.throwsError = throwsError
        }

        func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
            guard !throwsError else { throw AFError.invalidURL(url: "") }

            var urlRequest = urlRequest
            urlRequest.httpMethod = method.rawValue

            return urlRequest
        }
    }

    private class RequestHandler: RequestAdapter, RequestRetrier {
        var adaptedCount = 0
        var retryCount = 0
        var retryErrors: [Error] = []

        var shouldApplyAuthorizationHeader = false
        var throwsErrorOnSecondAdapt = false

        func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
            if throwsErrorOnSecondAdapt && adaptedCount == 1 {
                throwsErrorOnSecondAdapt = false
                throw AFError.invalidURL(url: "")
            }

            var urlRequest = urlRequest

            adaptedCount += 1

            if shouldApplyAuthorizationHeader && adaptedCount > 1 {
                if let header = Request.authorizationHeader(user: "user", password: "password") {
                    urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
                }
            }

            return urlRequest
        }

        func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
            retryCount += 1
            retryErrors.append(error)

            if retryCount < 2 {
                completion(true, 0.0)
            } else {
                completion(false, 0.0)
            }
        }
    }

    private class UploadHandler: RequestAdapter, RequestRetrier {
        var adaptedCount = 0
        var retryCount = 0
        var retryErrors: [Error] = []

        func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
            adaptedCount += 1

            if adaptedCount == 1 { throw AFError.invalidURL(url: "") }

            return urlRequest
        }

        func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
            retryCount += 1
            retryErrors.append(error)

            completion(true, 0.0)
        }
    }

    // MARK: Tests - Initialization

    func testInitializerWithDefaultArguments() {
        // Given, When
        let manager = SessionManager()

        // Then
        XCTAssertNotNil(manager.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should be nil")
    }

    func testInitializerWithSpecifiedArguments() {
        // Given
        let configuration = URLSessionConfiguration.default
        let delegate = SessionDelegate()
        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [:])

        // When
        let manager = SessionManager(
            configuration: configuration,
            delegate: delegate,
            serverTrustPolicyManager: serverTrustPolicyManager
        )

        // Then
        XCTAssertNotNil(manager.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNotNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should not be nil")
    }

    func testThatFailableInitializerSucceedsWithDefaultArguments() {
        // Given
        let delegate = SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }()

        // When
        let manager = SessionManager(session: session, delegate: delegate)

        // Then
        if let manager = manager {
            XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
            XCTAssertNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should be nil")
        } else {
            XCTFail("manager should not be nil")
        }
    }

    func testThatFailableInitializerSucceedsWithSpecifiedArguments() {
        // Given
        let delegate = SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }()

        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [:])

        // When
        let manager = SessionManager(session: session, delegate: delegate, serverTrustPolicyManager: serverTrustPolicyManager)

        // Then
        if let manager = manager {
            XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
            XCTAssertNotNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should not be nil")
        } else {
            XCTFail("manager should not be nil")
        }
    }

    func testThatFailableInitializerFailsWithWhenDelegateDoesNotEqualSessionDelegate() {
        // Given
        let delegate = SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: SessionDelegate(), delegateQueue: nil)
        }()

        // When
        let manager = SessionManager(session: session, delegate: delegate)

        // Then
        XCTAssertNil(manager, "manager should be nil")
    }

    func testThatFailableInitializerFailsWhenSessionDelegateIsNil() {
        // Given
        let delegate = SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        }()

        // When
        let manager = SessionManager(session: session, delegate: delegate)

        // Then
        XCTAssertNil(manager, "manager should be nil")
    }

    // MARK: Tests - Default HTTP Headers

    func testDefaultUserAgentHeader() {
        // Given, When
        let userAgent = SessionManager.defaultHTTPHeaders["User-Agent"]

        // Then
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

            let osName: String = {
                #if os(iOS)
                    return "iOS"
                #elseif os(watchOS)
                    return "watchOS"
                #elseif os(tvOS)
                    return "tvOS"
                #elseif os(macOS)
                    return "OS X"
                #elseif os(Linux)
                    return "Linux"
                #else
                    return "Unknown"
                #endif
            }()

            return "\(osName) \(versionString)"
        }()

        let alamofireVersion: String = {
            guard
                let afInfo = Bundle(for: SessionManager.self).infoDictionary,
                let build = afInfo["CFBundleShortVersionString"]
            else { return "Unknown" }

            return "Alamofire/\(build)"
        }()

        let expectedUserAgent = "Unknown/Unknown (Unknown; build:Unknown; \(osNameVersion)) \(alamofireVersion)"
        XCTAssertEqual(userAgent, expectedUserAgent)
    }

    // MARK: Tests - Start Requests Immediately

    func testSetStartRequestsImmediatelyToFalseAndResumeRequest() {
        // Given
        let manager = SessionManager()
        manager.startRequestsImmediately = false

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: HTTPURLResponse?

        // When
        manager.request(urlRequest)
            .response { resp in
                response = resp.response
                expectation.fulfill()
            }
            .resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(response?.statusCode == 200, "response status code should be 200")
    }

    // MARK: Tests - Deinitialization

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        // Given
        var manager: SessionManager? = SessionManager()
        manager?.startRequestsImmediately = false

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        // When
        let request = manager?.request(urlRequest)
        manager = nil

        // Then
        XCTAssertTrue(request?.task?.state == .suspended, "request task state should be '.Suspended'")
        XCTAssertNil(manager, "manager should be nil")
    }

    func testReleasingManagerWithPendingCanceledRequestDeinitializesSuccessfully() {
        // Given
        var manager: SessionManager? = SessionManager()
        manager!.startRequestsImmediately = false

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        // When
        let request = manager!.request(urlRequest)
        request.cancel()
        manager = nil

        // Then
        let state = request.task?.state
        XCTAssertTrue(state == .canceling || state == .completed, "state should be .Canceling or .Completed")
        XCTAssertNil(manager, "manager should be nil")
    }

    // MARK: Tests - Bad Requests

    func testThatDataRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let sessionManager = SessionManager()
        let expectation = self.expectation(description: "Request should fail with error")

        var response: DefaultDataResponse?

        // When
        sessionManager.request("https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.data?.count, 0)
        XCTAssertNotNil(response?.error)

        if let error = response?.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDownloadRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let sessionManager = SessionManager()
        let expectation = self.expectation(description: "Download should fail with error")

        var response: DefaultDownloadResponse?

        // When
        sessionManager.download("https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.temporaryURL)
        XCTAssertNil(response?.destinationURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)

        if let error = response?.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatUploadDataRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let sessionManager = SessionManager()
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DefaultDataResponse?

        // When
        sessionManager.upload(Data(), to: "https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.data?.count, 0)
        XCTAssertNotNil(response?.error)

        if let error = response?.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatUploadFileRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let sessionManager = SessionManager()
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DefaultDataResponse?

        // When
        sessionManager.upload(URL(fileURLWithPath: "/invalid"), to: "https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.data?.count, 0)
        XCTAssertNotNil(response?.error)

        if let error = response?.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatUploadStreamRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let sessionManager = SessionManager()
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DefaultDataResponse?

        // When
        sessionManager.upload(InputStream(data: Data()), to: "https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.data?.count, 0)
        XCTAssertNotNil(response?.error)

        if let error = response?.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: Tests - Request Adapter

    func testThatSessionManagerCallsRequestAdapterWhenCreatingDataRequest() {
        // Given
        let adapter = HTTPMethodAdapter(method: .post)

        let sessionManager = SessionManager()
        sessionManager.adapter = adapter
        sessionManager.startRequestsImmediately = false

        // When
        let request = sessionManager.request("https://httpbin.org/get")

        // Then
        XCTAssertEqual(request.task?.originalRequest?.httpMethod, adapter.method.rawValue)
    }

    func testThatSessionManagerCallsRequestAdapterWhenCreatingDownloadRequest() {
        // Given
        let adapter = HTTPMethodAdapter(method: .post)

        let sessionManager = SessionManager()
        sessionManager.adapter = adapter
        sessionManager.startRequestsImmediately = false

        // When
        let destination = DownloadRequest.suggestedDownloadDestination()
        let request = sessionManager.download("https://httpbin.org/get", to: destination)

        // Then
        XCTAssertEqual(request.task?.originalRequest?.httpMethod, adapter.method.rawValue)
    }

    func testThatSessionManagerCallsRequestAdapterWhenCreatingUploadRequestWithData() {
        // Given
        let adapter = HTTPMethodAdapter(method: .get)

        let sessionManager = SessionManager()
        sessionManager.adapter = adapter
        sessionManager.startRequestsImmediately = false

        // When
        let request = sessionManager.upload("data".data(using: .utf8)!, to: "https://httpbin.org/post")

        // Then
        XCTAssertEqual(request.task?.originalRequest?.httpMethod, adapter.method.rawValue)
    }

    func testThatSessionManagerCallsRequestAdapterWhenCreatingUploadRequestWithFile() {
        // Given
        let adapter = HTTPMethodAdapter(method: .get)

        let sessionManager = SessionManager()
        sessionManager.adapter = adapter
        sessionManager.startRequestsImmediately = false

        // When
        let fileURL = URL(fileURLWithPath: "/path/to/some/file.txt")
        let request = sessionManager.upload(fileURL, to: "https://httpbin.org/post")

        // Then
        XCTAssertEqual(request.task?.originalRequest?.httpMethod, adapter.method.rawValue)
    }

    func testThatSessionManagerCallsRequestAdapterWhenCreatingUploadRequestWithInputStream() {
        // Given
        let adapter = HTTPMethodAdapter(method: .get)

        let sessionManager = SessionManager()
        sessionManager.adapter = adapter
        sessionManager.startRequestsImmediately = false

        // When
        let inputStream = InputStream(data: "data".data(using: .utf8)!)
        let request = sessionManager.upload(inputStream, to: "https://httpbin.org/post")

        // Then
        XCTAssertEqual(request.task?.originalRequest?.httpMethod, adapter.method.rawValue)
    }

    func testThatRequestAdapterErrorThrowsResponseHandlerError() {
        // Given
        let adapter = HTTPMethodAdapter(method: .post, throwsError: true)

        let sessionManager = SessionManager()
        sessionManager.adapter = adapter
        sessionManager.startRequestsImmediately = false

        // When
        let request = sessionManager.request("https://httpbin.org/get")

        // Then
        if let error = request.delegate.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: Tests - Request Retrier

    func testThatSessionManagerCallsRequestRetrierWhenRequestEncountersError() {
        // Given
        let handler = RequestHandler()

        let sessionManager = SessionManager()
        sessionManager.adapter = handler
        sessionManager.retrier = handler

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = sessionManager.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCount, 2)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
    }

    func testThatSessionManagerCallsRequestRetrierWhenRequestInitiallyEncountersAdaptError() {
        // Given
        let handler = RequestHandler()
        handler.adaptedCount = 1
        handler.throwsErrorOnSecondAdapt = true
        handler.shouldApplyAuthorizationHeader = true

        let sessionManager = SessionManager()
        sessionManager.adapter = handler
        sessionManager.retrier = handler

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        sessionManager.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)

        handler.retryErrors.forEach { XCTAssertFalse($0 is AdaptError) }
    }

    func testThatSessionManagerCallsRequestRetrierWhenDownloadInitiallyEncountersAdaptError() {
        // Given
        let handler = RequestHandler()
        handler.adaptedCount = 1
        handler.throwsErrorOnSecondAdapt = true
        handler.shouldApplyAuthorizationHeader = true

        let sessionManager = SessionManager()
        sessionManager.adapter = handler
        sessionManager.retrier = handler

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DownloadResponse<Any>?

        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let fileURL = self.testDirectoryURL.appendingPathComponent("test-output.json")
            return (fileURL, [.removePreviousFile])
        }

        // When
        sessionManager.download("https://httpbin.org/basic-auth/user/password", to: destination)
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)

        handler.retryErrors.forEach { XCTAssertFalse($0 is AdaptError) }
    }

    func testThatSessionManagerCallsRequestRetrierWhenUploadInitiallyEncountersAdaptError() {
        // Given
        let handler = UploadHandler()

        let sessionManager = SessionManager()
        sessionManager.adapter = handler
        sessionManager.retrier = handler

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        let uploadData = "upload data".data(using: .utf8, allowLossyConversion: false)!

        // When
        sessionManager.upload(uploadData, to: "https://httpbin.org/post")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)

        handler.retryErrors.forEach { XCTAssertFalse($0 is AdaptError) }
    }

    func testThatSessionManagerCallsAdapterWhenRequestIsRetried() {
        // Given
        let handler = RequestHandler()
        handler.shouldApplyAuthorizationHeader = true

        let sessionManager = SessionManager()
        sessionManager.adapter = handler
        sessionManager.retrier = handler

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = sessionManager.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatRequestAdapterErrorThrowsResponseHandlerErrorWhenRequestIsRetried() {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnSecondAdapt = true

        let sessionManager = SessionManager()
        sessionManager.adapter = handler
        sessionManager.retrier = handler

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = sessionManager.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, false)

        if let error = response?.result.error as? AFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "")
        } else {
            XCTFail("error should not be nil")
        }
    }
}

// MARK: -

class SessionManagerConfigurationHeadersTestCase: BaseTestCase {
    enum ConfigurationType {
        case `default`, ephemeral, background
    }

    func testThatDefaultConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTest(for: .default)
    }

    func testThatEphemeralConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTest(for: .ephemeral)
    }
#if os(macOS)
    func testThatBackgroundConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTest(for: .background)
    }
#endif

    private func executeAuthorizationHeaderTest(for type: ConfigurationType) {
        // Given
        let manager: SessionManager = {
            let configuration: URLSessionConfiguration = {
                let configuration: URLSessionConfiguration

                switch type {
                case .default:
                    configuration = .default
                case .ephemeral:
                    configuration = .ephemeral
                case .background:
                    let identifier = "org.alamofire.test.manager-configuration-tests"
                    configuration = .background(withIdentifier: identifier)
                }

                var headers = SessionManager.defaultHTTPHeaders
                headers["Authorization"] = "Bearer 123456"
                configuration.httpAdditionalHeaders = headers

                return configuration
            }()

            return SessionManager(configuration: configuration)
        }()

        let expectation = self.expectation(description: "request should complete successfully")

        var response: DataResponse<Any>?

        // When
        manager.request("https://httpbin.org/headers")
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be a success")

            if
                let response = response.result.value as? [String: Any],
                let headers = response["headers"] as? [String: String],
                let authorization = headers["Authorization"]
            {
                XCTAssertEqual(authorization, "Bearer 123456", "authorization header value does not match")
            } else {
                XCTFail("failed to extract authorization header value")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }
}
