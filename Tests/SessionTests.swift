//
//  SessionTests.swift
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

class SessionTestCase: BaseTestCase {

    // MARK: Helper Types

    private class HTTPMethodAdapter: RequestInterceptor {
        let method: HTTPMethod
        let throwsError: Bool

        var adaptedCount = 0

        init(method: HTTPMethod, throwsError: Bool = false) {
            self.method = method
            self.throwsError = throwsError
        }

        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (AFResult<URLRequest>) -> Void) {
            adaptedCount += 1

            let result: AFResult<URLRequest> = AFResult {
                guard !throwsError else { throw AFError.invalidURL(url: "") }

                var urlRequest = urlRequest
                urlRequest.httpMethod = method.rawValue

                return urlRequest
            }

            completion(result)
        }
    }

    private class HeaderAdapter: RequestInterceptor {
        let headers: HTTPHeaders
        let throwsError: Bool

        var adaptedCount = 0

        init(headers: HTTPHeaders = ["field": "value"], throwsError: Bool = false) {
            self.headers = headers
            self.throwsError = throwsError
        }

        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (AFResult<URLRequest>) -> Void) {
            adaptedCount += 1

            let result: AFResult<URLRequest> = AFResult {
                guard !throwsError else { throw AFError.invalidURL(url: "") }

                var urlRequest = urlRequest

                var finalHeaders = urlRequest.headers
                headers.forEach { finalHeaders.add($0) }

                urlRequest.headers = finalHeaders

                return urlRequest
            }

            completion(result)
        }
    }

    private class RequestHandler: RequestInterceptor {
        var adaptCalledCount = 0
        var adaptedCount = 0
        var retryCount = 0
        var retryCalledCount = 0
        var retryErrors: [Error] = []

        var shouldApplyAuthorizationHeader = false
        var throwsErrorOnFirstAdapt = false
        var throwsErrorOnSecondAdapt = false
        var throwsErrorOnRetry = false
        var shouldRetry = true
        var retryDelay: TimeInterval?

        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (AFResult<URLRequest>) -> Void) {
            adaptCalledCount += 1

            let result: AFResult<URLRequest> = AFResult {
                if throwsErrorOnFirstAdapt {
                    throwsErrorOnFirstAdapt = false
                    throw AFError.invalidURL(url: "/adapt/error/1")
                }

                if throwsErrorOnSecondAdapt && adaptedCount == 1 {
                    throwsErrorOnSecondAdapt = false
                    throw AFError.invalidURL(url: "/adapt/error/2")
                }

                var urlRequest = urlRequest

                adaptedCount += 1

                if shouldApplyAuthorizationHeader && adaptedCount > 1 {
                    urlRequest.headers.update(.authorization(username: "user", password: "password"))
                }

                return urlRequest
            }

            completion(result)
        }

        func retry(
            _ request: Request,
            for session: Session,
            dueTo error: Error,
            completion: @escaping (RetryResult) -> Void)
        {
            retryCalledCount += 1

            if throwsErrorOnRetry {
                let error = AFError.invalidURL(url: "/invalid/url/\(retryCalledCount)")
                completion(.doNotRetryWithError(error))
                return
            }

            guard shouldRetry else { completion(.doNotRetry); return }

            retryCount += 1
            retryErrors.append(error)

            if retryCount < 2 {
                if let retryDelay = retryDelay {
                    completion(.retryWithDelay(retryDelay))
                } else {
                    completion(.retry)
                }
            } else {
                completion(.doNotRetry)
            }
        }
    }

    private class UploadHandler: RequestInterceptor {
        var adaptCalledCount = 0
        var adaptedCount = 0
        var retryCalledCount = 0
        var retryCount = 0
        var retryErrors: [Error] = []

        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (AFResult<URLRequest>) -> Void) {
            adaptCalledCount += 1

            let result: AFResult<URLRequest> = AFResult {
                adaptedCount += 1

                if adaptedCount == 1 { throw AFError.invalidURL(url: "") }

                return urlRequest
            }

            completion(result)
        }

        func retry(
            _ request: Request,
            for session: Session,
            dueTo error: Error,
            completion: @escaping (RetryResult) -> Void)
        {
            retryCalledCount += 1

            retryCount += 1
            retryErrors.append(error)

            completion(.retry)
        }
    }

    // MARK: Tests - Initialization

    func testInitializerWithDefaultArguments() {
        // Given, When
        let session = Session()

        // Then
        XCTAssertNotNil(session.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNil(session.serverTrustManager, "session server trust policy manager should be nil")
    }

    func testInitializerWithSpecifiedArguments() {
        // Given
        let configuration = URLSessionConfiguration.default
        let delegate = SessionDelegate()
        let serverTrustManager = ServerTrustManager(evaluators: [:])

        // When
        let session = Session(configuration: configuration,
                                     delegate: delegate,
                                     serverTrustManager: serverTrustManager)

        // Then
        XCTAssertNotNil(session.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNotNil(session.serverTrustManager, "session server trust policy manager should not be nil")
    }

    func testThatSessionInitializerSucceedsWithDefaultArguments() {
        // Given
        let delegate = SessionDelegate()
        let underlyingQueue = DispatchQueue(label: "underlyingQueue")
        let urlSession: URLSession = {
            let configuration = URLSessionConfiguration.default
            let queue = OperationQueue(underlyingQueue: underlyingQueue, name: "delegateQueue")
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        }()

        // When
        let session = Session(session: urlSession, delegate: delegate, rootQueue: underlyingQueue)

        // Then
        XCTAssertTrue(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNil(session.serverTrustManager, "session server trust policy manager should be nil")
    }

    func testThatSessionInitializerSucceedsWithSpecifiedArguments() {
        // Given
        let delegate = SessionDelegate()
        let underlyingQueue = DispatchQueue(label: "underlyingQueue")
        let urlSession: URLSession = {
            let configuration = URLSessionConfiguration.default
            let queue = OperationQueue(underlyingQueue: underlyingQueue, name: "delegateQueue")
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        }()

        let serverTrustManager = ServerTrustManager(evaluators: [:])

        // When
        let session = Session(session: urlSession,
                                     delegate: delegate,
                                     rootQueue: underlyingQueue,
                                     serverTrustManager: serverTrustManager)

        // Then
        XCTAssertTrue(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNotNil(session.serverTrustManager, "session server trust policy manager should not be nil")
    }

    // MARK: Tests - Default HTTP Headers

    func testDefaultUserAgentHeader() {
        // Given, When
        let userAgent = HTTPHeaders.default["User-Agent"]

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
                    return "macOS"
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
                let afInfo = Bundle(for: Session.self).infoDictionary,
                let build = afInfo["CFBundleShortVersionString"]
            else { return "Unknown" }

            return "Alamofire/\(build)"
        }()

        XCTAssertTrue(userAgent?.contains(alamofireVersion) == true)
        XCTAssertTrue(userAgent?.contains(osNameVersion) == true)
        XCTAssertTrue(userAgent?.contains("Unknown/Unknown") == true)
    }

    // MARK: Tests - Supported Accept-Encodings

    func testDefaultAcceptEncodingSupportsAppropriateEncodingsOnAppropriateSystems() {
        // Given
        let brotliURL = URL(string: "https://httpbin.org/brotli")!
        let gzipURL = URL(string: "https://httpbin.org/gzip")!
        let deflateURL = URL(string: "https://httpbin.org/deflate")!
        let brotliExpectation = expectation(description: "brotli request should complete")
        let gzipExpectation = expectation(description: "gzip request should complete")
        let deflateExpectation = expectation(description: "deflate request should complete")
        var brotliResponse: DataResponse<Any>?
        var gzipResponse: DataResponse<Any>?
        var deflateResponse: DataResponse<Any>?

        // When
        AF.request(brotliURL).responseJSON { response in
            brotliResponse = response
            brotliExpectation.fulfill()
        }

        AF.request(gzipURL).responseJSON { response in
            gzipResponse = response
            gzipExpectation.fulfill()
        }

        AF.request(deflateURL).responseJSON { response in
            deflateResponse = response
            deflateExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            XCTAssertTrue(brotliResponse?.result.isSuccess == true)
        } else {
            XCTAssertTrue(brotliResponse?.result.isFailure == true)
        }

        XCTAssertTrue(gzipResponse?.result.isSuccess == true)
        XCTAssertTrue(deflateResponse?.result.isSuccess == true)
    }

    // MARK: Tests - Start Requests Immediately

    func testSetStartRequestsImmediatelyToFalseAndResumeRequest() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: HTTPURLResponse?

        // When
        session.request(urlRequest)
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

    func testSetStartRequestsImmediatelyToFalseAndCancelledCallsResponseHandlers() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: DataResponse<Data?>?

        // When
        let request = session.request(urlRequest)
            .cancel()
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed))

        guard let error = request.error?.asAFError, case .explicitlyCancelled = error else {
            XCTFail("Request should have an .explicitlyCancelled error.")
            return
        }
    }

    func testSetStartRequestsImmediatelyToFalseAndResumeThenCancelRequestHasCorrectOutput() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: DataResponse<Data?>?

        // When
        let request = session.request(urlRequest)
            .resume()
            .cancel()
            .response { resp in
                response = resp
                expectation.fulfill()
            }


        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed))

        guard let error = request.error?.asAFError, case .explicitlyCancelled = error else {
            XCTFail("Request should have an .explicitlyCancelled error.")
            return
        }
    }

    func testSetStartRequestsImmediatelyToFalseAndCancelThenResumeRequestDoesntCreateTaskAndStaysCancelled() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: DataResponse<Data?>?

        // When
        let request = session.request(urlRequest)
            .cancel()
            .resume()
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed))

        guard let error = request.error?.asAFError, case .explicitlyCancelled = error else {
            XCTFail("Request should have an .explicitlyCancelled error.")
            return
        }
    }

    // MARK: Tests - Deinitialization

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        // Given
        let monitor = ClosureEventMonitor()
        let expectation = self.expectation(description: "Request created")
        monitor.requestDidCreateTask = { _, _ in expectation.fulfill() }
        var session: Session? = Session(startRequestsImmediately: false, eventMonitors: [monitor])

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        // When
        let request = session?.request(urlRequest)
        session = nil

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request?.task?.state, .suspended)
        XCTAssertNil(session, "manager should be nil")
    }

    func testReleasingManagerWithPendingCanceledRequestDeinitializesSuccessfully() {
        // Given
        var session: Session? = Session(startRequestsImmediately: false)

        let url = URL(string: "https://httpbin.org/get")!
        let urlRequest = URLRequest(url: url)

        // When
        let request = session?.request(urlRequest)
        request?.cancel()
        session = nil

        let state = request?.state

        // Then
        XCTAssertTrue(state == .cancelled, "state should be .cancelled")
        XCTAssertNil(session, "manager should be nil")
    }

    // MARK: Tests - Bad Requests

    func testThatDataRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let expectation = self.expectation(description: "Request should fail with error")

        var response: DataResponse<Data?>?

        // When
        session.request("https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)

        if let error = response?.error?.asAFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDownloadRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let expectation = self.expectation(description: "Download should fail with error")

        var response: DownloadResponse<URL?>?

        // When
        session.download("https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)

        if let error = response?.error?.asAFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatUploadDataRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DataResponse<Data?>?

        // When
        session.upload(Data(), to: "https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)

        if let error = response?.error?.asAFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatUploadFileRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DataResponse<Data?>?

        // When
        session.upload(URL(fileURLWithPath: "/invalid"), to: "https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)

        if let error = response?.error?.asAFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatUploadStreamRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DataResponse<Data?>?

        // When
        session.upload(InputStream(data: Data()), to: "https://httpbin.org/get/äëïöü").response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)

        if let error = response?.error?.asAFError {
            XCTAssertTrue(error.isInvalidURLError)
            XCTAssertEqual(error.urlConvertible as? String, "https://httpbin.org/get/äëïöü")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: Tests - Request Adapter

    func testThatSessionCallsRequestAdaptersWhenCreatingDataRequest() {
        // Given
        let urlString = "https://httpbin.org/get"

        let methodAdapter = HTTPMethodAdapter(method: .post)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = self.expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.request(urlString)
        waitForExpectations(timeout: timeout, handler: nil)

        let expectation2 = self.expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.request(urlString, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionCallsRequestAdaptersWhenCreatingDownloadRequest() {
        // Given
        let urlString = "https://httpbin.org/get"

        let methodAdapter = HTTPMethodAdapter(method: .post)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = self.expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.download(urlString)
        waitForExpectations(timeout: timeout, handler: nil)

        let expectation2 = self.expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.download(urlString, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionCallsRequestAdaptersWhenCreatingUploadRequestWithData() {
        // Given
        let data = Data("data".utf8)
        let urlString = "https://httpbin.org/post"

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = self.expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.upload(data, to: urlString)
        waitForExpectations(timeout: timeout, handler: nil)

        let expectation2 = self.expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.upload(data, to: urlString, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionCallsRequestAdaptersWhenCreatingUploadRequestWithFile() {
        // Given
        let fileURL = URL(fileURLWithPath: "/path/to/some/file.txt")
        let urlString = "https://httpbin.org/post"

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = self.expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.upload(fileURL, to: urlString)
        waitForExpectations(timeout: timeout, handler: nil)

        let expectation2 = self.expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.upload(fileURL, to: urlString, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionCallsRequestAdaptersWhenCreatingUploadRequestWithInputStream() {
        // Given
        let inputStream = InputStream(data: Data("data".utf8))
        let urlString = "https://httpbin.org/post"

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = self.expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.upload(inputStream, to: urlString)
        waitForExpectations(timeout: timeout, handler: nil)

        let expectation2 = self.expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.upload(inputStream, to: urlString, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionReturnsRequestAdaptationErrorWhenRequestAdapterThrowsError() {
        // Given
        let urlString = "https://httpbin.org/get"

        let methodAdapter = HTTPMethodAdapter(method: .post, throwsError: true)
        let headerAdapter = HeaderAdapter(throwsError: true)
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = self.expectation(description: "Request 1 created")
        monitor.requestDidFailToAdaptURLRequestWithError = { _, _, _ in expectation1.fulfill() }

        let request1 = session.request(urlString)
        waitForExpectations(timeout: timeout, handler: nil)

        let expectation2 = self.expectation(description: "Request 2 created")
        monitor.requestDidFailToAdaptURLRequestWithError = { _, _, _ in expectation2.fulfill() }

        let request2 = session.request(urlString, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout, handler: nil)

        let requests = [request1, request2]

        // Then
        for request in requests {
            if let error = request.error?.asAFError {
                XCTAssertTrue(error.isRequestAdaptationError)
                XCTAssertEqual(error.underlyingError?.asAFError?.urlConvertible as? String, "")
            } else {
                XCTFail("error should not be nil")
            }
        }
    }

    // MARK: Tests - Request Retrier

    func testThatSessionCallsRequestRetrierWhenRequestEncountersError() {
        // Given
        let handler = RequestHandler()

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/basic-auth/user/password", interceptor: handler)
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
    }

    func testThatSessionCallsRequestRetrierThenSessionRetrierWhenRequestEncountersError() {
        // Given
        let sessionHandler = RequestHandler()
        let requestHandler = RequestHandler()

        let session = Session(interceptor: sessionHandler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/basic-auth/user/password", interceptor: requestHandler)
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(sessionHandler.adaptCalledCount, 3)
        XCTAssertEqual(sessionHandler.adaptedCount, 3)
        XCTAssertEqual(sessionHandler.retryCalledCount, 3)
        XCTAssertEqual(sessionHandler.retryCount, 3)
        XCTAssertEqual(requestHandler.adaptCalledCount, 3)
        XCTAssertEqual(requestHandler.adaptedCount, 3)
        XCTAssertEqual(requestHandler.retryCalledCount, 4)
        XCTAssertEqual(requestHandler.retryCount, 4)
        XCTAssertEqual(request.retryCount, 2)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
    }

    func testThatSessionCallsRequestRetrierWhenRequestInitiallyEncountersAdaptError() {
        // Given
        let handler = RequestHandler()
        handler.adaptedCount = 1
        handler.throwsErrorOnSecondAdapt = true
        handler.shouldApplyAuthorizationHeader = true

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        session.request("https://httpbin.org/basic-auth/user/password", interceptor: handler)
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
    }

    func testThatSessionCallsRequestRetrierWhenDownloadInitiallyEncountersAdaptError() {
        // Given
        let handler = RequestHandler()
        handler.adaptedCount = 1
        handler.throwsErrorOnSecondAdapt = true
        handler.shouldApplyAuthorizationHeader = true

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DownloadResponse<Any>?

        let destination: DownloadRequest.Destination = { _, _ in
            let fileURL = self.testDirectoryURL.appendingPathComponent("test-output.json")
            return (fileURL, [.removePreviousFile])
        }

        // When
        session.download("https://httpbin.org/basic-auth/user/password", interceptor: handler, to: destination)
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
    }

    func testThatSessionCallsRequestRetrierWhenUploadInitiallyEncountersAdaptError() {
        // Given
        let handler = UploadHandler()
        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        let uploadData = Data("upload data".utf8)

        // When
        session.upload(uploadData, to: "https://httpbin.org/post")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
    }

    func testThatSessionCallsAdapterWhenRequestIsRetried() {
        // Given
        let handler = RequestHandler()
        handler.shouldApplyAuthorizationHeader = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually succeed")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
    }

    func testThatSessionReturnsRequestAdaptationErrorWhenRequestIsRetried() {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnSecondAdapt = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        if let error = response?.result.error?.asAFError {
            XCTAssertTrue(error.isRequestAdaptationError)
            XCTAssertEqual(error.underlyingError?.asAFError?.urlConvertible as? String, "/adapt/error/2")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatSessionRetriesRequestWithDelayWhenRetryResultContainsDelay() {
        // Given
        let handler = RequestHandler()
        handler.retryDelay = 0.01
        handler.throwsErrorOnSecondAdapt = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        if let error = response?.result.error?.asAFError {
            XCTAssertTrue(error.isRequestAdaptationError)
            XCTAssertEqual(error.underlyingError?.asAFError?.urlConvertible as? String, "/adapt/error/2")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatSessionReturnsRequestRetryErrorWhenRequestRetrierThrowsError() {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnRetry = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/basic-auth/user/password")
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 2)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        if let error = response?.result.error?.asAFError {
            XCTAssertTrue(error.isRequestRetryError)
            XCTAssertEqual(error.underlyingError?.asAFError?.urlConvertible as? String, "/invalid/url/2")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: Tests - Response Serializer Retry

    func testThatSessionCallsRequestRetrierWhenResponseSerializerThrowsError() {
        // Given
        let handler = RequestHandler()
        handler.shouldRetry = false

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/image/jpeg", interceptor: handler)
            .validate()
            .responseJSON { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        if let error = response?.error?.asAFError {
            XCTAssertTrue(error.isResponseSerializationError)
            XCTAssertTrue(error.localizedDescription.starts(with: "JSON could not be serialized"))
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatSessionCallsRequestRetrierForAllResponseSerializersThatThrowError() throws {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnRetry = true

        let session = Session()

        let json1Expectation = self.expectation(description: "request should eventually fail")
        var json1Response: DataResponse<Any>?

        let json2Expectation = self.expectation(description: "request should eventually fail")
        var json2Response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/image/jpeg", interceptor: handler)
            .validate()
            .responseJSON { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseJSON { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 2)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        let errors: [AFError] = [json1Response, json2Response].compactMap { $0?.error?.asAFError }
        XCTAssertEqual(errors.count, 2)

        for (index, error) in errors.enumerated() {
            XCTAssertTrue(error.isRequestRetryError)
            XCTAssertEqual(error.localizedDescription.starts(with: "Request retry failed with retry error"), true)

            if case let .requestRetryFailed(retryError, originalError) = error {
                XCTAssertEqual(try retryError.asAFError?.urlConvertible?.asURL().absoluteString, "/invalid/url/\(index + 1)")
                XCTAssertTrue(originalError.localizedDescription.starts(with: "JSON could not be serialized"))
            } else {
                XCTFail("Error failure reason should be response serialization failure")
            }
        }
    }

    func testThatSessionRetriesRequestImmediatelyWhenResponseSerializerRequestsRetry() throws {
        // Given
        let handler = RequestHandler()
        let session = Session()

        let json1Expectation = self.expectation(description: "request should eventually fail")
        var json1Response: DataResponse<Any>?

        let json2Expectation = self.expectation(description: "request should eventually fail")
        var json2Response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/image/jpeg", interceptor: handler)
            .validate()
            .responseJSON { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseJSON { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: 10, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        let errors: [AFError] = [json1Response, json2Response].compactMap { $0?.error?.asAFError }
        XCTAssertEqual(errors.count, 2)

        for error in errors {
            XCTAssertTrue(error.isResponseSerializationError)
            XCTAssertTrue(error.localizedDescription.starts(with: "JSON could not be serialized"))
        }
    }

    func testThatSessionCallsResponseSerializerCompletionsWhenAdapterThrowsErrorDuringRetry() {
        // Four retries should occur given this scenario:
        // 1) Retrier is called from first response serializer failure (trips retry)
        // 2) Retrier is called by Session for adapt error thrown
        // 3) Retrier is called again from first response serializer failure
        // 4) Retrier is called from second response serializer failure

        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnSecondAdapt = true

        let session = Session()

        let json1Expectation = self.expectation(description: "request should eventually fail")
        var json1Response: DataResponse<Any>?

        let json2Expectation = self.expectation(description: "request should eventually fail")
        var json2Response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/image/jpeg", interceptor: handler)
            .validate()
            .responseJSON { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseJSON { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: 10, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 4)
        XCTAssertEqual(handler.retryCount, 4)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        let errors: [AFError] = [json1Response, json2Response].compactMap { $0?.error?.asAFError }
        XCTAssertEqual(errors.count, 2)

        for error in errors {
            XCTAssertTrue(error.isRequestAdaptationError)
            XCTAssertEqual(error.localizedDescription, "Request adaption failed with error: URL is not valid: /adapt/error/2")
        }
    }

    func testThatSessionCallsResponseSerializerCompletionsWhenAdapterThrowsErrorDuringRetryForDownloads() {
        // Four retries should occur given this scenario:
        // 1) Retrier is called from first response serializer failure (trips retry)
        // 2) Retrier is called by Session for adapt error thrown
        // 3) Retrier is called again from first response serializer failure
        // 4) Retrier is called from second response serializer failure

        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnSecondAdapt = true

        let session = Session()

        let json1Expectation = self.expectation(description: "request should eventually fail")
        var json1Response: DownloadResponse<Any>?

        let json2Expectation = self.expectation(description: "request should eventually fail")
        var json2Response: DownloadResponse<Any>?

        // When
        let request = session.download("https://httpbin.org/image/jpeg", interceptor: handler)
            .validate()
            .responseJSON { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseJSON { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: 10, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 4)
        XCTAssertEqual(handler.retryCount, 4)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        XCTAssertTrue(session.requestTaskMap.isEmpty)

        let errors: [AFError] = [json1Response, json2Response].compactMap { $0?.error?.asAFError }
        XCTAssertEqual(errors.count, 2)

        for error in errors {
            XCTAssertTrue(error.isRequestAdaptationError)
            XCTAssertEqual(error.localizedDescription, "Request adaption failed with error: URL is not valid: /adapt/error/2")
        }
    }

    // MARK: Tests - Session Invalidation

    func testThatSessionIsInvalidatedAndAllRequestsCompleteWhenSessionIsDeinitialized() {
        // Given
        let invalidationExpectation = expectation(description: "sessionDidBecomeInvalidWithError should be called")
        let events = ClosureEventMonitor()
        events.sessionDidBecomeInvalidWithError = { (_, _) in
            invalidationExpectation.fulfill()
        }
        var session: Session? = Session(startRequestsImmediately: false, eventMonitors: [events])
        var error: Error?
        let requestExpectation = expectation(description: "request should complete")

        // When
        session?.request(URLRequest.makeHTTPBinRequest()).response { (response) in
            error = response.error
            requestExpectation.fulfill()
        }
        session = nil

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        assertErrorIsAFError(error) { XCTAssertTrue($0.isSessionDeinitializedError) }
    }

    // MARK: Tests - Request Cancellation

    func testThatSessionOnlyCallsResponseSerializerCompletionWhenCancellingInsideCompletion() {
        // Given
        let handler = RequestHandler()
        let session = Session()

        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<Any>?
        var completionCallCount = 0

        // When
        let request = session.request("https://httpbin.org/get", interceptor: handler)
        request.validate()

        request.responseJSON { resp in
            request.cancel()

            response = resp
            completionCallCount += 1

            DispatchQueue.main.after(0.01) { expectation.fulfill() }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 0)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.requestTaskMap.isEmpty)
        XCTAssertEqual(completionCallCount, 1)
    }

    // MARK: Tests - Request State

    func testThatSessionSetsRequestStateWhenStartRequestsImmediatelyIsTrue() {
        // Given
        let session = Session()

        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<Any>?

        // When
        let request = session.request("https://httpbin.org/get").responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
        XCTAssertEqual(response?.result.isSuccess, true)
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
        let session: Session = {
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

                var headers = HTTPHeaders.default
                headers["Authorization"] = "Bearer 123456"
                configuration.headers = headers

                return configuration
            }()

            return Session(configuration: configuration)
        }()

        let expectation = self.expectation(description: "request should complete successfully")

        var response: DataResponse<Any>?

        // When
        session.request("https://httpbin.org/headers")
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
