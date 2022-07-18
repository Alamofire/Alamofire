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

final class SessionTestCase: BaseTestCase {
    // MARK: Helper Types

    private class HTTPMethodAdapter: RequestInterceptor {
        let method: HTTPMethod
        let throwsError: Bool

        var adaptedCount = 0

        init(method: HTTPMethod, throwsError: Bool = false) {
            self.method = method
            self.throwsError = throwsError
        }

        func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping (Result<URLRequest, Error>) -> Void) {
            adaptedCount += 1

            let result: Result<URLRequest, Error> = Result {
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

        func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping (Result<URLRequest, Error>) -> Void) {
            adaptedCount += 1

            let result: Result<URLRequest, Error> = Result {
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

        func adapt(_ urlRequest: URLRequest,
                   using state: RequestAdapterState,
                   completion: @escaping (Result<URLRequest, Error>) -> Void) {
            adaptCalledCount += 1

            let result: Result<URLRequest, Error> = Result {
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

        func retry(_ request: Request,
                   for session: Session,
                   dueTo error: Error,
                   completion: @escaping (RetryResult) -> Void) {
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

        func adapt(_ urlRequest: URLRequest,
                   using state: RequestAdapterState,
                   completion: @escaping (Result<URLRequest, Error>) -> Void) {
            adaptCalledCount += 1

            let result: Result<URLRequest, Error> = Result {
                adaptedCount += 1

                if adaptedCount == 1 { throw AFError.invalidURL(url: "") }

                return urlRequest
            }

            completion(result)
        }

        func retry(_ request: Request,
                   for session: Session,
                   dueTo error: Error,
                   completion: @escaping (RetryResult) -> Void) {
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

    // MARK: Tests - Parallel Root Queue

    func testThatSessionWorksCorrectlyWhenPassedAConcurrentRootQueue() {
        // Given
        let queue = DispatchQueue(label: "ohNoAParallelQueue", attributes: .concurrent)
        let session = Session(rootQueue: queue)
        let didFinish = expectation(description: "request did finish")
        var receivedResponse: TestResponse?

        // When
        session.request(.get).responseDecodable(of: TestResponse.self) { response in
            receivedResponse = response.value
            didFinish.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(receivedResponse, "Should receive TestResponse.")
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
                #if targetEnvironment(macCatalyst)
                return "macOS(Catalyst)"
                #else
                return "iOS"
                #endif
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

        let alamofireVersion = "Alamofire/\(Alamofire.version)"

        XCTAssertTrue(userAgent?.contains(alamofireVersion) == true)
        XCTAssertTrue(userAgent?.contains(osNameVersion) == true)
        XCTAssertTrue(userAgent?.contains("xctest/") == true)
    }

    // MARK: Tests - Supported Accept-Encodings

    func testDefaultAcceptEncodingSupportsAppropriateEncodingsOnAppropriateSystems() {
        // Given
        let brotliExpectation = expectation(description: "brotli request should complete")
        let gzipExpectation = expectation(description: "gzip request should complete")
        let deflateExpectation = expectation(description: "deflate request should complete")
        var brotliResponse: DataResponse<TestResponse, AFError>?
        var gzipResponse: DataResponse<TestResponse, AFError>?
        var deflateResponse: DataResponse<TestResponse, AFError>?

        // When
        AF.request(.compression(.brotli)).responseDecodable(of: TestResponse.self) { response in
            brotliResponse = response
            brotliExpectation.fulfill()
        }

        AF.request(.compression(.gzip)).responseDecodable(of: TestResponse.self) { response in
            gzipResponse = response
            gzipExpectation.fulfill()
        }

        AF.request(.compression(.deflate)).responseDecodable(of: TestResponse.self) { response in
            deflateResponse = response
            deflateExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

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

        let url = Endpoint().url
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

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(response?.statusCode == 200, "response status code should be 200")
    }

    func testSetStartRequestsImmediatelyToFalseAndCancelledCallsResponseHandlers() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = Endpoint().url
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: DataResponse<Data?, AFError>?

        // When
        let request = session.request(urlRequest)
            .cancel()
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed))
        XCTAssertEqual(request.error?.isExplicitlyCancelledError, true)
    }

    func testSetStartRequestsImmediatelyToFalseAndResumeThenCancelRequestHasCorrectOutput() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = Endpoint().url
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: DataResponse<Data?, AFError>?

        // When
        let request = session.request(urlRequest)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
            .resume()
            .cancel()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed))
        XCTAssertEqual(request.error?.isExplicitlyCancelledError, true)
    }

    func testSetStartRequestsImmediatelyToFalseAndCancelThenResumeRequestDoesntCreateTaskAndStaysCancelled() {
        // Given
        let session = Session(startRequestsImmediately: false)

        let url = Endpoint().url
        let urlRequest = URLRequest(url: url)

        let expectation = self.expectation(description: "\(url)")

        var response: DataResponse<Data?, AFError>?

        // When
        let request = session.request(urlRequest)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
            .cancel()
            .resume()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed))
        XCTAssertEqual(request.error?.isExplicitlyCancelledError, true)
    }

    // MARK: Tests - Deinitialization

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        // Given
        let monitor = ClosureEventMonitor()
        let didCreateRequest = expectation(description: "Request created")
        monitor.requestDidCreateTask = { _, _ in didCreateRequest.fulfill() }
        var session: Session? = Session(startRequestsImmediately: false, eventMonitors: [monitor])
        weak var weakSession = session

        // When
        let request = session?.request(.default)
        session = nil

        waitForExpectations(timeout: timeout)

        // Then
        if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
            // On 2022 OS versions and later, URLSessionTasks are completed even if not resumed before invalidating a session.
            XCTAssertTrue([.canceling, .completed].contains(request?.task?.state))
        } else {
            XCTAssertEqual(request?.task?.state, .suspended)
        }
        XCTAssertNil(session, "session should be nil")
        XCTAssertNil(weakSession, "weak session should be nil")
    }

    func testReleasingManagerWithPendingCanceledRequestDeinitializesSuccessfully() {
        // Given
        var session: Session? = Session(startRequestsImmediately: false)

        // When
        let request = session?.request(.default)
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
        let url = Endpoint().url.absoluteString.appending("/äëïöü")
        let expectation = self.expectation(description: "Request should fail with error")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(url).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.isInvalidURLError, true)
        XCTAssertEqual(response?.error?.urlConvertible as? String, url)
    }

    func testThatDownloadRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let url = Endpoint().url.absoluteString.appending("/äëïöü")
        let expectation = self.expectation(description: "Download should fail with error")

        var response: DownloadResponse<URL?, AFError>?

        // When
        session.download(url).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.fileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.isInvalidURLError, true)
        XCTAssertEqual(response?.error?.urlConvertible as? String, url)
    }

    func testThatUploadDataRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let url = Endpoint().url.absoluteString.appending("/äëïöü")
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DataResponse<Data?, AFError>?

        // When
        session.upload(Data(), to: url).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.isInvalidURLError, true)
        XCTAssertEqual(response?.error?.urlConvertible as? String, url)
    }

    func testThatUploadFileRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let url = Endpoint().url.absoluteString.appending("/äëïöü")
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DataResponse<Data?, AFError>?

        // When
        session.upload(URL(fileURLWithPath: "/invalid"), to: url).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.isInvalidURLError, true)
        XCTAssertEqual(response?.error?.urlConvertible as? String, url)
    }

    func testThatUploadStreamRequestWithInvalidURLStringThrowsResponseHandlerError() {
        // Given
        let session = Session()
        let url = Endpoint().url.absoluteString.appending("/äëïöü")
        let expectation = self.expectation(description: "Upload should fail with error")

        var response: DataResponse<Data?, AFError>?

        // When
        session.upload(InputStream(data: Data()), to: url).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.isInvalidURLError, true)
        XCTAssertEqual(response?.error?.urlConvertible as? String, url)
    }

    // MARK: Tests - Request Adapter

    func testThatSessionCallsRequestAdaptersWhenCreatingDataRequest() {
        // Given
        let endpoint = Endpoint()

        let methodAdapter = HTTPMethodAdapter(method: .post)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.request(endpoint)
        waitForExpectations(timeout: timeout)

        let expectation2 = expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.request(endpoint, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionCallsRequestAdaptersWhenCreatingDownloadRequest() {
        // Given
        let endpoint = Endpoint()

        let methodAdapter = HTTPMethodAdapter(method: .post)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.download(endpoint)
        waitForExpectations(timeout: timeout)

        let expectation2 = expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.download(endpoint, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout)

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
        let endpoint = Endpoint.method(.post)

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.upload(data, to: endpoint)
        waitForExpectations(timeout: timeout)

        let expectation2 = expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.upload(data, to: endpoint, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout)

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
        let endpoint = Endpoint.method(.post)

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.upload(fileURL, to: endpoint)
        waitForExpectations(timeout: timeout)

        let expectation2 = expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.upload(fileURL, to: endpoint, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout)

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
        let endpoint = Endpoint.method(.post)

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = expectation(description: "Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.fulfill() }

        let request1 = session.upload(inputStream, to: endpoint)
        waitForExpectations(timeout: timeout)

        let expectation2 = expectation(description: "Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.fulfill() }

        let request2 = session.upload(inputStream, to: endpoint, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request1.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.httpMethod, methodAdapter.method.rawValue)
        XCTAssertEqual(request2.task?.originalRequest?.allHTTPHeaderFields?.count, 1)
        XCTAssertEqual(methodAdapter.adaptedCount, 2)
        XCTAssertEqual(headerAdapter.adaptedCount, 1)
    }

    func testThatSessionReturnsRequestAdaptationErrorWhenRequestAdapterThrowsError() {
        // Given
        let endpoint = Endpoint()

        let methodAdapter = HTTPMethodAdapter(method: .post, throwsError: true)
        let headerAdapter = HeaderAdapter(throwsError: true)
        let monitor = ClosureEventMonitor()

        let session = Session(startRequestsImmediately: false, interceptor: methodAdapter, eventMonitors: [monitor])

        // When
        let expectation1 = expectation(description: "Request 1 created")
        monitor.requestDidFailToAdaptURLRequestWithError = { _, _, _ in expectation1.fulfill() }

        let request1 = session.request(endpoint)
        waitForExpectations(timeout: timeout)

        let expectation2 = expectation(description: "Request 2 created")
        monitor.requestDidFailToAdaptURLRequestWithError = { _, _, _ in expectation2.fulfill() }

        let request2 = session.request(endpoint, interceptor: headerAdapter)
        waitForExpectations(timeout: timeout)

        let requests = [request1, request2]

        // Then
        for request in requests {
            XCTAssertEqual(request.error?.isRequestAdaptationError, true)
            XCTAssertEqual(request.error?.underlyingError?.asAFError?.urlConvertible as? String, "")
        }
    }

    // MARK: Tests - Request Retrier

    func testThatSessionCallsRequestRetrierWhenRequestInitiallyEncountersAdaptError() {
        // Given
        let handler = RequestHandler()
        handler.adaptedCount = 1
        handler.throwsErrorOnSecondAdapt = true
        handler.shouldApplyAuthorizationHeader = true

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        // When
        session.request(.basicAuth(), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionCallsRequestRetrierWhenDownloadInitiallyEncountersAdaptError() {
        // Given
        let handler = RequestHandler()
        handler.adaptedCount = 1
        handler.throwsErrorOnSecondAdapt = true
        handler.shouldApplyAuthorizationHeader = true

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DownloadResponse<TestResponse, AFError>?

        let destination: DownloadRequest.Destination = { _, _ in
            let fileURL = self.testDirectoryURL.appendingPathComponent("test-output.json")
            return (fileURL, [.removePreviousFile])
        }

        // When
        session.download(.basicAuth(), interceptor: handler, to: destination)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionCallsRequestRetrierWhenUploadInitiallyEncountersAdaptError() {
        // Given
        let handler = UploadHandler()
        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        let uploadData = Data("upload data".utf8)

        // When
        session.upload(uploadData, to: .method(.post))
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionCallsRequestRetrierWhenRequestEncountersError() {
        // Given
        let handler = RequestHandler()

        let session = Session()

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.basicAuth(), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionCallsRequestRetrierThenSessionRetrierWhenRequestEncountersError() {
        // Given
        let sessionHandler = RequestHandler()
        let requestHandler = RequestHandler()

        let session = Session(interceptor: sessionHandler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.basicAuth(), interceptor: requestHandler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

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
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionCallsAdapterWhenRequestIsRetried() {
        // Given
        let handler = RequestHandler()
        handler.shouldApplyAuthorizationHeader = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually succeed")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 1)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, true)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionReturnsRequestAdaptationErrorWhenRequestIsRetried() {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnSecondAdapt = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertEqual(request.error?.isRequestAdaptationError, true)
        XCTAssertEqual(request.error?.underlyingError?.asAFError?.urlConvertible as? String, "/adapt/error/2")
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionRetriesRequestWithDelayWhenRetryResultContainsDelay() {
        // Given
        let handler = RequestHandler()
        handler.retryDelay = 0.01
        handler.throwsErrorOnSecondAdapt = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertEqual(request.error?.isRequestAdaptationError, true)
        XCTAssertEqual(request.error?.underlyingError?.asAFError?.urlConvertible as? String, "/adapt/error/2")
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionReturnsRequestRetryErrorWhenRequestRetrierThrowsError() {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnRetry = true

        let session = Session(interceptor: handler)

        let expectation = self.expectation(description: "request should eventually fail")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 2)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, false)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }

        if let error = response?.result.failure {
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
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response = jsonResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 1)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, false)
        XCTAssertEqual(response?.error?.isResponseSerializationError, true)
        XCTAssertNotNil(response?.error?.underlyingError as? DecodingError)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    func testThatSessionCallsRequestRetrierForAllResponseSerializersThatThrowError() throws {
        // Given
        let handler = RequestHandler()
        handler.throwsErrorOnRetry = true

        let session = Session()

        let json1Expectation = expectation(description: "request should eventually fail")
        var json1Response: DataResponse<TestResponse, AFError>?

        let json2Expectation = expectation(description: "request should eventually fail")
        var json2Response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 2)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }

        let errors = [json1Response, json2Response].compactMap { $0?.error }

        XCTAssertEqual(errors.count, 2)

        for (index, error) in errors.enumerated() {
            XCTAssertTrue(error.isRequestRetryError)
            if case let .requestRetryFailed(retryError, originalError) = error {
                XCTAssertEqual(retryError.asAFError?.urlConvertible as? String, "/invalid/url/\(index + 1)")
                XCTAssertNotNil(originalError.asAFError?.underlyingError as? DecodingError)
            } else {
                XCTFail("Error failure reason should be response serialization failure")
            }
        }
    }

    func testThatSessionRetriesRequestImmediatelyWhenResponseSerializerRequestsRetry() throws {
        // Given
        let handler = RequestHandler()
        let session = Session()

        let json1Expectation = expectation(description: "request should eventually fail")
        var json1Response: DataResponse<TestResponse, AFError>?

        let json2Expectation = expectation(description: "request should eventually fail")
        var json2Response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 2)
        XCTAssertEqual(handler.retryCalledCount, 3)
        XCTAssertEqual(handler.retryCount, 3)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }

        let errors = [json1Response, json2Response].compactMap { $0?.error }
        XCTAssertEqual(errors.count, 2)

        for error in errors {
            XCTAssertTrue(error.isResponseSerializationError)
            XCTAssertNotNil(error.underlyingError as? DecodingError)
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

        let json1Expectation = expectation(description: "request should eventually fail")
        var json1Response: DataResponse<TestResponse, AFError>?

        let json2Expectation = expectation(description: "request should eventually fail")
        var json2Response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 4)
        XCTAssertEqual(handler.retryCount, 4)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }

        let errors = [json1Response, json2Response].compactMap { $0?.error }
        XCTAssertEqual(errors.count, 2)

        for error in errors {
            XCTAssertTrue(error.isRequestAdaptationError)
            XCTAssertEqual(error.underlyingError?.asAFError?.urlConvertible as? String, "/adapt/error/2")
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

        let json1Expectation = expectation(description: "request should eventually fail")
        var json1Response: DownloadResponse<TestResponse, AFError>?

        let json2Expectation = expectation(description: "request should eventually fail")
        var json2Response: DownloadResponse<TestResponse, AFError>?

        // When
        let request = session.download(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response = response
                json1Expectation.fulfill()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response = response
                json2Expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 2)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 4)
        XCTAssertEqual(handler.retryCount, 4)
        XCTAssertEqual(request.retryCount, 1)
        XCTAssertEqual(json1Response?.result.isSuccess, false)
        XCTAssertEqual(json2Response?.result.isSuccess, false)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }

        let errors = [json1Response, json2Response].compactMap { $0?.error }
        XCTAssertEqual(errors.count, 2)

        for error in errors {
            XCTAssertTrue(error.isRequestAdaptationError)
            XCTAssertEqual(error.underlyingError?.asAFError?.urlConvertible as? String, "/adapt/error/2")
        }
    }

    // MARK: Tests - Session Invalidation

    func testThatSessionIsInvalidatedAndAllRequestsCompleteWhenSessionIsDeinitialized() {
        // Given
        let invalidationExpectation = expectation(description: "sessionDidBecomeInvalidWithError should be called")
        let events = ClosureEventMonitor()
        events.sessionDidBecomeInvalidWithError = { _, _ in
            invalidationExpectation.fulfill()
        }
        var session: Session? = Session(startRequestsImmediately: false, eventMonitors: [events])
        var error: AFError?
        let requestExpectation = expectation(description: "request should complete")

        // When
        session?.request(.default).response { response in
            error = response.error
            requestExpectation.fulfill()
        }
        session = nil

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(error?.isSessionDeinitializedError, true)
    }

    // MARK: Tests - Request Cancellation

    func testThatSessionOnlyCallsResponseSerializerCompletionWhenCancellingInsideCompletion() {
        // Given
        let handler = RequestHandler()
        let session = Session()

        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<TestResponse, AFError>?
        var completionCallCount = 0

        // When
        let request = session.request(.default, interceptor: handler)
        request.validate()

        request.responseDecodable(of: TestResponse.self) { resp in
            request.cancel()

            response = resp
            completionCallCount += 1

            DispatchQueue.main.after(0.01) { expectation.fulfill() }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(handler.adaptCalledCount, 1)
        XCTAssertEqual(handler.adaptedCount, 1)
        XCTAssertEqual(handler.retryCalledCount, 0)
        XCTAssertEqual(handler.retryCount, 0)
        XCTAssertEqual(request.retryCount, 0)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(completionCallCount, 1)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty)
            XCTAssertTrue(session.activeRequests.isEmpty)
        }
    }

    // MARK: Tests - Request State

    func testThatSessionSetsRequestStateWhenStartRequestsImmediatelyIsTrue() {
        // Given
        let session = Session()

        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<TestResponse, AFError>?

        // When
        let request = session.request(.default).responseDecodable(of: TestResponse.self) { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request.state, .finished)
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    // MARK: Invalid Requests

    func testThatGETRequestsWithBodyDataAreConsideredInvalid() {
        // Given
        let session = Session()
        var request = Endpoint().urlRequest
        request.httpBody = Data("invalid".utf8)
        let expect = expectation(description: "request should complete")
        var response: DataResponse<TestResponse, AFError>?

        // When
        session.request(request).responseDecodable(of: TestResponse.self) { resp in
            response = resp
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isBodyDataInGETRequest, true)
    }

    func testThatAdaptedGETRequestsWithBodyDataAreConsideredInvalid() {
        // Given
        struct InvalidAdapter: RequestInterceptor {
            func adapt(_ urlRequest: URLRequest,
                       for session: Session,
                       completion: @escaping (Result<URLRequest, Error>) -> Void) {
                var request = urlRequest
                request.httpBody = Data("invalid".utf8)

                completion(.success(request))
            }
        }
        let session = Session(interceptor: InvalidAdapter())
        let expect = expectation(description: "request should complete")
        var response: DataResponse<TestResponse, AFError>?

        // When
        session.request(.default).responseDecodable(of: TestResponse.self) { resp in
            response = resp
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isRequestAdaptationError, true)
        XCTAssertEqual(response?.error?.underlyingError?.asAFError?.isBodyDataInGETRequest, true)
    }
}

// MARK: -

final class SessionMassActionTestCase: BaseTestCase {
    func testThatRequestsCanHaveMassActionsPerformed() {
        // Given
        let count = 10
        let createdTasks = expectation(description: "all tasks created")
        createdTasks.expectedFulfillmentCount = count
        let massActions = expectation(description: "cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.fulfill() }
        let session = Session(eventMonitors: [monitor])
        let request = Endpoint.delay(1)
        var requests: [DataRequest] = []

        // When
        requests = (0..<count).map { _ in session.request(request) }

        wait(for: [createdTasks], timeout: timeout)

        session.withAllRequests { $0.forEach { $0.suspend() }; massActions.fulfill() }

        wait(for: [massActions], timeout: timeout)

        // Then
        XCTAssertTrue(requests.allSatisfy(\.isSuspended))
    }

    func testThatAutomaticallyResumedRequestsCanBeMassCancelled() {
        // Given
        let count = 100
        let completion = expectation(description: "all requests should finish")
        completion.expectedFulfillmentCount = count
        let createdTasks = expectation(description: "all tasks created")
        createdTasks.expectedFulfillmentCount = count
        let gatheredMetrics = expectation(description: "metrics gathered for all tasks")
        gatheredMetrics.expectedFulfillmentCount = count
        let cancellation = expectation(description: "cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.fulfill() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.fulfill() }
        let session = Session(eventMonitors: [monitor])
        let request = Endpoint.delay(1)
        var requests: [DataRequest] = []
        var responses: [DataResponse<Data?, AFError>] = []

        // When
        requests = (0..<count).map { _ in session.request(request) }

        wait(for: [createdTasks], timeout: timeout)

        requests.forEach { request in
            request.response { response in
                responses.append(response)
                completion.fulfill()
            }
        }

        session.cancelAllRequests {
            cancellation.fulfill()
        }

        wait(for: [gatheredMetrics, cancellation, completion], timeout: timeout)

        // Then
        XCTAssertTrue(responses.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty, "requestTaskMap should be empty but has \(session.requestTaskMap.count) items")
            XCTAssertTrue(session.activeRequests.isEmpty, "activeRequests should be empty but has \(session.activeRequests.count) items")
        }
    }

    func testThatManuallyResumedRequestsCanBeMassCancelled() {
        // Given
        let count = 100
        let completion = expectation(description: "all requests should finish")
        completion.expectedFulfillmentCount = count
        let createdTasks = expectation(description: "all tasks created")
        createdTasks.expectedFulfillmentCount = count
        let gatheredMetrics = expectation(description: "metrics gathered for all tasks")
        gatheredMetrics.expectedFulfillmentCount = count
        let cancellation = expectation(description: "cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.fulfill() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.fulfill() }
        let session = Session(startRequestsImmediately: false, eventMonitors: [monitor])
        let request = Endpoint.delay(1)
        var responses: [DataResponse<Data?, AFError>] = []

        // When
        for _ in 0..<count {
            session.request(request).response { response in
                responses.append(response)
                completion.fulfill()
            }
        }

        wait(for: [createdTasks], timeout: timeout)

        session.cancelAllRequests {
            cancellation.fulfill()
        }

        wait(for: [gatheredMetrics, cancellation, completion], timeout: timeout)

        // Then
        XCTAssertTrue(responses.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty, "requestTaskMap should be empty but has \(session.requestTaskMap.count) items")
            XCTAssertTrue(session.activeRequests.isEmpty, "activeRequests should be empty but has \(session.activeRequests.count) items")
        }
    }

    func testThatRetriedRequestsCanBeMassCancelled() {
        // Given
        final class OnceRetrier: RequestInterceptor {
            private var hasRetried = false

            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
                if hasRetried {
                    var request = urlRequest
                    request.url = Endpoint.delay(1).url
                    completion(.success(request))
                } else {
                    completion(.success(urlRequest))
                }
            }

            func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
                completion(hasRetried ? .doNotRetry : .retry)
                hasRetried = true
            }
        }

        let queue = DispatchQueue(label: "com.alamofire.testQueue")
        let monitor = ClosureEventMonitor(queue: queue)
        let session = Session(rootQueue: queue, interceptor: OnceRetrier(), eventMonitors: [monitor])
        let request = Endpoint.status(401)
        let completion = expectation(description: "all requests should finish")
        let cancellation = expectation(description: "cancel all requests should be called")
        let createTask = expectation(description: "should create task twice")
        createTask.expectedFulfillmentCount = 2
        var tasksCreated = 0
        monitor.requestDidCreateTask = { [unowned session] _, _ in
            tasksCreated += 1
            createTask.fulfill()
            // Cancel after the second task is created to ensure proper lifetime events.
            if tasksCreated == 2 {
                session.cancelAllRequests {
                    cancellation.fulfill()
                }
            }
        }

        var received: DataResponse<Data?, AFError>?

        // When
        session.request(request).validate().response { response in
            received = response
            completion.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(received?.error?.isExplicitlyCancelledError, true)
        assert(on: session.rootQueue) {
            XCTAssertTrue(session.requestTaskMap.isEmpty, "requestTaskMap should be empty but has \(session.requestTaskMap.count) items")
            XCTAssertTrue(session.activeRequests.isEmpty, "activeRequests should be empty but has \(session.activeRequests.count) items")
        }
    }
}

// MARK: -

final class SessionConfigurationHeadersTestCase: BaseTestCase {
    enum ConfigurationType {
        case `default`, ephemeral
    }

    func testThatDefaultConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTest(for: .default)
    }

    func testThatEphemeralConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTest(for: .ephemeral)
    }

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
                }

                var headers = HTTPHeaders.default
                headers["Authorization"] = "Bearer 123456"
                configuration.headers = headers

                return configuration
            }()

            return Session(configuration: configuration)
        }()

        let expectation = self.expectation(description: "request should complete successfully")

        var response: DataResponse<TestResponse, AFError>?

        // When
        session.request(.default)
            .responseDecodable(of: TestResponse.self) { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request, "request should not be nil")
        XCTAssertNotNil(response?.response, "response should not be nil")
        XCTAssertNotNil(response?.data, "data should not be nil")
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.value?.headers["Authorization"], "Bearer 123456", "Authorization header should match")
    }
}
