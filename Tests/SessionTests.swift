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
import Testing

@Suite(.storesInstances)
struct SessionTestCase {
    private let directory = TemporaryDirectory()
    private var testDirectoryURL: URL { directory.url }

    // MARK: Helper Types

    private final class HTTPMethodAdapter: RequestInterceptor {
        let method: HTTPMethod
        let throwsError: Bool

        let adaptedCount = Protected(0)

        init(method: HTTPMethod, throwsError: Bool = false) {
            self.method = method
            self.throwsError = throwsError
        }

        func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
            adaptedCount.write { $0 += 1 }

            let result: Result<URLRequest, any Error> = Result {
                guard !throwsError else { throw AFError.invalidURL(url: "") }

                var urlRequest = urlRequest
                urlRequest.httpMethod = method.rawValue

                return urlRequest
            }

            completion(result)
        }
    }

    private final class HeaderAdapter: RequestInterceptor {
        let headers: HTTPHeaders
        let throwsError: Bool

        let adaptedCount = Protected(0)

        init(headers: HTTPHeaders = ["field": "value"], throwsError: Bool = false) {
            self.headers = headers
            self.throwsError = throwsError
        }

        func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
            adaptedCount.write { $0 += 1 }

            let result: Result<URLRequest, any Error> = Result {
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

    private final class RequestHandler: RequestInterceptor {
        struct MutableState {
            var adaptCalledCount = 0
            var adaptedCount = 0
            var retryCount = 0
            var retryCalledCount = 0
            var retryErrors: [any Error] = []

            var shouldApplyAuthorizationHeader = false
            var throwsErrorOnFirstAdapt = false
            var throwsErrorOnSecondAdapt = false
            var throwsErrorOnRetry = false
            var shouldRetry = true
            var retryDelay: TimeInterval?
        }

        private let mutableState: Protected<MutableState>

        var adaptCalledCount: Int { mutableState.read(\.adaptCalledCount) }
        var adaptedCount: Int { mutableState.read(\.adaptedCount) }
        var retryCalledCount: Int { mutableState.read(\.retryCalledCount) }
        var retryCount: Int { mutableState.read(\.retryCount) }
        var retryErrors: [any Error] { mutableState.read(\.retryErrors) }

        init(adaptedCount: Int = 0,
             throwsErrorOnSecondAdapt: Bool = false,
             throwsErrorOnRetry: Bool = false,
             shouldApplyAuthorizationHeader: Bool = false,
             shouldRetry: Bool = true,
             retryDelay: TimeInterval? = nil) {
            mutableState = Protected(.init(adaptedCount: adaptedCount,
                                           shouldApplyAuthorizationHeader: shouldApplyAuthorizationHeader,
                                           throwsErrorOnSecondAdapt: throwsErrorOnSecondAdapt,
                                           throwsErrorOnRetry: throwsErrorOnRetry,
                                           shouldRetry: shouldRetry,
                                           retryDelay: retryDelay))
        }

        func adapt(_ urlRequest: URLRequest,
                   using state: RequestAdapterState,
                   completion: @escaping (Result<URLRequest, any Error>) -> Void) {
            let result = mutableState.write { mutableState in
                mutableState.adaptCalledCount += 1

                return Result {
                    if mutableState.throwsErrorOnFirstAdapt {
                        mutableState.throwsErrorOnFirstAdapt = false
                        throw AFError.invalidURL(url: "/adapt/error/1")
                    }

                    if mutableState.throwsErrorOnSecondAdapt && mutableState.adaptedCount == 1 {
                        mutableState.throwsErrorOnSecondAdapt = false
                        throw AFError.invalidURL(url: "/adapt/error/2")
                    }

                    var urlRequest = urlRequest

                    mutableState.adaptedCount += 1

                    if mutableState.shouldApplyAuthorizationHeader && mutableState.adaptedCount > 1 {
                        urlRequest.headers.update(.authorization(username: "user", password: "password"))
                    }

                    return urlRequest
                }
            }

            completion(result)
        }

        func retry(_ request: Request,
                   for session: Session,
                   dueTo error: any Error,
                   completion: @escaping (RetryResult) -> Void) {
            let result: RetryResult = mutableState.write { mutableState in
                mutableState.retryCalledCount += 1

                if mutableState.throwsErrorOnRetry {
                    let error = AFError.invalidURL(url: "/invalid/url/\(mutableState.retryCalledCount)")
                    return .doNotRetryWithError(error)
                }

                guard mutableState.shouldRetry else { return .doNotRetry }

                mutableState.retryCount += 1
                mutableState.retryErrors.append(error)

                if mutableState.retryCount < 2 {
                    if let retryDelay = mutableState.retryDelay {
                        return .retryWithDelay(retryDelay)
                    } else {
                        return .retry
                    }
                } else {
                    return .doNotRetry
                }
            }

            completion(result)
        }
    }

    private final class UploadHandler: RequestInterceptor {
        struct MutableState {
            var adaptCalledCount = 0
            var adaptedCount = 0
            var retryCalledCount = 0
            var retryCount = 0
            var retryErrors: [any Error] = []
        }

        private let mutableState = Protected(MutableState())

        var adaptCalledCount: Int { mutableState.read(\.adaptCalledCount) }
        var adaptedCount: Int { mutableState.read(\.adaptedCount) }
        var retryCalledCount: Int { mutableState.read(\.retryCalledCount) }
        var retryCount: Int { mutableState.read(\.retryCount) }
        var retryErrors: [any Error] { mutableState.read(\.retryErrors) }

        func adapt(_ urlRequest: URLRequest,
                   using state: RequestAdapterState,
                   completion: @escaping (Result<URLRequest, any Error>) -> Void) {
            let result: Result<URLRequest, any Error> = mutableState.write { mutableState in
                mutableState.adaptCalledCount += 1

                return Result {
                    mutableState.adaptedCount += 1

                    if mutableState.adaptedCount == 1 { throw AFError.invalidURL(url: "") }

                    return urlRequest
                }
            }

            completion(result)
        }

        func retry(_ request: Request,
                   for session: Session,
                   dueTo error: any Error,
                   completion: @escaping (RetryResult) -> Void) {
            mutableState.write { mutableState in
                mutableState.retryCalledCount += 1

                mutableState.retryCount += 1
                mutableState.retryErrors.append(error)
            }

            completion(.retry)
        }
    }

    // MARK: Tests - Initialization

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func initializerWithDefaultArguments() {
        // Given, When
        let session = stored(Session.independent())

        // Then
        #expect(session.session.delegate != nil, "session delegate should not be nil")
        #expect(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        #expect(session.serverTrustManager == nil, "session server trust policy manager should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func initializerWithSpecifiedArguments() {
        // Given
        let configuration = URLSessionConfiguration.default
        let delegate = SessionDelegate()
        let serverTrustManager = ServerTrustManager(evaluators: [:])

        // When
        let session = stored(Session.independent(configuration: configuration,
                                                 delegate: delegate,
                                                 serverTrustManager: serverTrustManager))

        // Then
        #expect(session.session.delegate != nil, "session delegate should not be nil")
        #expect(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        #expect(session.serverTrustManager != nil, "session server trust policy manager should not be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionInitializerSucceedsWithDefaultArguments() {
        // Given
        let delegate = SessionDelegate()
        let underlyingQueue = DispatchQueue(label: "underlyingQueue")
        let urlSession: URLSession = {
            let configuration = URLSessionConfiguration.default
            let queue = OperationQueue(underlyingQueue: underlyingQueue, name: "delegateQueue")
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        }()

        // When
        let session = stored(Session(session: urlSession, delegate: delegate, rootQueue: underlyingQueue))

        // Then
        #expect(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        #expect(session.serverTrustManager == nil, "session server trust policy manager should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionInitializerSucceedsWithSpecifiedArguments() {
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
        let session = stored(Session(session: urlSession,
                                     delegate: delegate,
                                     rootQueue: underlyingQueue,
                                     serverTrustManager: serverTrustManager))

        // Then
        #expect(session.delegate === session.session.delegate, "manager delegate should equal session delegate")
        #expect(session.serverTrustManager != nil, "session server trust policy manager should not be nil")
    }

    // MARK: Tests - Parallel Root Queue

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionWorksCorrectlyWhenPassedAConcurrentRootQueue() async {
        // Given
        let queue = DispatchQueue(label: "ohNoAParallelQueue", attributes: .concurrent)
        let session = stored(Session.independent(rootQueue: queue))
        let didFinish = Completion("request did finish")
        let receivedResponse = Capture<TestResponse?>()

        // When
        session.request(.get).responseDecodable(of: TestResponse.self) { response in
            receivedResponse.value = response.value
            didFinish.complete()
        }

        await didFinish.wait()

        // Then
        #expect(receivedResponse.value != nil, "Should receive TestResponse.")
    }

    // MARK: Tests - Default HTTP Headers

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func defaultUserAgentHeader() {
        // Given, When
        let userAgent = HTTPHeaders.default["User-Agent"]

        // Then
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

            let osName: String = {
                #if os(iOS)
                #if targetEnvironment(macCatalyst)
                "macOS(Catalyst)"
                #else
                "iOS"
                #endif
                #elseif os(watchOS)
                "watchOS"
                #elseif os(tvOS)
                "tvOS"
                #elseif os(macOS)
                #if targetEnvironment(macCatalyst)
                "macOS(Catalyst)"
                #else
                "macOS"
                #endif
                #elseif os(visionOS)
                "visionOS"
                #elseif os(Linux)
                "Linux"
                #elseif os(Windows)
                "Windows"
                #elseif os(Android)
                "Android"
                #elseif os(WASI)
                "WASI"
                #elseif os(FreeBSD)
                "FreeBSD"
                #else
                "Unknown"
                #endif
            }()

            return "\(osName) \(versionString)"
        }()

        let alamofireVersion = "Alamofire/\(AFInfo.version)"

        #expect(userAgent?.contains(alamofireVersion) == true)
        #expect(userAgent?.contains(osNameVersion) == true)
        // The User-Agent names the test runner process: xctest, or swiftpm-testing-helper for Swift Testing in SwiftPM.
        #expect(userAgent?.contains("\(ProcessInfo.processInfo.processName)/") == true)
    }

    // MARK: Tests - Supported Accept-Encodings

    @Test(.disabled("Disabled due to HTTPBin flakiness."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func defaultAcceptEncodingSupportsAppropriateEncodingsOnAppropriateSystems() async {
        // Given
        let session = stored(Session.independent())
        let brotliExpectation = Completion("brotli request should complete")
        let gzipExpectation = Completion("gzip request should complete")
        let deflateExpectation = Completion("deflate request should complete")
        let brotliResponse = Capture<DataResponse<TestResponse, AFError>?>()
        let gzipResponse = Capture<DataResponse<TestResponse, AFError>?>()
        let deflateResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.compression(.brotli)).responseDecodable(of: TestResponse.self) { response in
            brotliResponse.value = response
            brotliExpectation.complete()
        }

        session.request(.compression(.gzip)).responseDecodable(of: TestResponse.self) { response in
            gzipResponse.value = response
            gzipExpectation.complete()
        }

        session.request(.compression(.deflate)).responseDecodable(of: TestResponse.self) { response in
            deflateResponse.value = response
            deflateExpectation.complete()
        }

        await wait(for: [brotliExpectation, gzipExpectation, deflateExpectation])

        // Then
        // The test's @available already guarantees the OS versions that support brotli.
        #expect(brotliResponse.result?.isSuccess == true)

        #expect(gzipResponse.result?.isSuccess == true)
        #expect(deflateResponse.result?.isSuccess == true)
    }

    // MARK: Tests - Start Requests Immediately

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func setStartRequestsImmediatelyToFalseAndResumeRequest() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))

        let url = Endpoint().url
        let urlRequest = URLRequest(url: url)

        let expectation = Completion("\(url)")

        let response = Capture<HTTPURLResponse?>()

        // When
        session.request(urlRequest)
            .response { resp in
                response.value = resp.response
                expectation.complete()
            }
            .resume()

        await expectation.wait()

        // Then
        #expect(response.value != nil, "response should not be nil")
        #expect(response.statusCode == 200, "response status code should be 200")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func setStartRequestsImmediatelyToFalseAndCancelledCallsResponseHandlers() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))

        let url = Endpoint().url
        let urlRequest = URLRequest(url: url)

        let expectation = Completion("\(url)")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.request(urlRequest)
            .cancel()
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.value != nil, "response should not be nil")
        #expect(request.isCancelled)
        #expect((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed),
                "task state is \(String(describing: request.task?.state.rawValue))")
        #expect(request.error?.isExplicitlyCancelledError == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func setStartRequestsImmediatelyToFalseAndResumeThenCancelRequestHasCorrectOutput() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))

        let url = Endpoint.delay(10).url
        let urlRequest = URLRequest(url: url)

        let expectation = Completion("\(url)")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.request(urlRequest)
            .response { resp in
                response.value = resp
                expectation.complete()
            }
            .resume()
            .cancel()

        await expectation.wait()

        // Then
        #expect(response.value != nil, "response should not be nil")
        #expect(request.isCancelled)
        #expect((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed),
                "task state is \(String(describing: request.task?.state.rawValue))")
        #expect(request.error?.isExplicitlyCancelledError == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func setStartRequestsImmediatelyToFalseAndCancelThenResumeRequestDoesntCreateTaskAndStaysCancelled() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))

        let url = Endpoint().url
        let urlRequest = URLRequest(url: url)

        let expectation = Completion("\(url)")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.request(urlRequest)
            .response { resp in
                response.value = resp
                expectation.complete()
            }
            .cancel()
            .resume()

        await expectation.wait()

        // Then
        #expect(response.value != nil, "response should not be nil")
        #expect(request.isCancelled)
        #expect((request.task == nil) || (request.task?.state == .canceling || request.task?.state == .completed),
                "task state is \(String(describing: request.task?.state.rawValue))")
        #expect(request.error?.isExplicitlyCancelledError == true)
    }

    // MARK: Tests - Deinitialization

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func releasingManagerWithPendingRequestDeinitializesSuccessfully() async {
        // Given
        let requestCount = 100
        let requestDidFinish = Completion("Request created", expectedCount: requestCount)
        var session: Session? = Session.independent(startRequestsImmediately: false, requestSetup: .eager)
        #if compiler(>=6.2.3) // Started emitting a diagnostic in 6.2.2, so lets conditionally use it.
        weak let weakSession = session
        #else
        weak var weakSession = session
        #endif

        // When
        let requests = (0..<requestCount).map { _ in
            session?.request(.default).response { _ in requestDidFinish.complete() }
        }
        session = nil

        await requestDidFinish.wait()

        // Then
        for request in requests {
            if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
                // On 2022 OS versions and later, URLSessionTasks are completed even if not resumed before invalidating a session.
                let state = request?.task?.state
                #expect([.canceling, .completed].contains(state), "task state isn't canceling or completed, it's \(String(describing: state))")
            } else {
                #expect(request?.task?.state == .suspended)
            }
        }
        #expect(session == nil, "session should be nil")
        #expect(weakSession == nil, "weak session should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func releasingManagerWithPendingCanceledRequestDeinitializesSuccessfully() {
        // Given
        var session: Session? = Session.independent(startRequestsImmediately: false)

        // When
        let request = session?.request(.default)
        request?.cancel()
        session = nil

        let state = request?.state

        // Then
        #expect(state == .cancelled, "state should be .cancelled")
        #expect(session == nil, "manager should be nil")
    }

    // MARK: Tests - Bad Requests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestWithInvalidURLStringThrowsResponseHandlerError() async {
        // Given
        let session = stored(Session.independent())
        let url = ""
        let expectation = Completion("Request should fail with error")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(url).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request == nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.error != nil)
        #expect(response.error?.isInvalidURLError == true)
        #expect(response.error?.urlConvertible as? String == url)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestWithInvalidURLStringThrowsResponseHandlerError() async {
        // Given
        let session = stored(Session.independent())
        let url = ""
        let expectation = Completion("Download should fail with error")

        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(url).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request == nil)
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect(response.error?.isInvalidURLError == true)
        #expect(response.error?.urlConvertible as? String == url)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadDataRequestWithInvalidURLStringThrowsResponseHandlerError() async {
        // Given
        let session = stored(Session.independent())
        let url = ""
        let expectation = Completion("Upload should fail with error")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(Data(), to: url).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request == nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.error != nil)
        #expect(response.error?.isInvalidURLError == true)
        #expect(response.error?.urlConvertible as? String == url)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadFileRequestWithInvalidURLStringThrowsResponseHandlerError() async {
        // Given
        let session = stored(Session.independent())
        let url = ""
        let expectation = Completion("Upload should fail with error")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(URL(fileURLWithPath: "/invalid"), to: url).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request == nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.error != nil)
        #expect(response.error?.isInvalidURLError == true)
        #expect(response.error?.urlConvertible as? String == url)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadStreamRequestWithInvalidURLStringThrowsResponseHandlerError() async {
        // Given
        let session = stored(Session.independent())
        let url = ""
        let expectation = Completion("Upload should fail with error")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.upload(InputStream(data: Data()), to: url).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request == nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.error != nil)
        #expect(response.error?.isInvalidURLError == true)
        #expect(response.error?.urlConvertible as? String == url)
    }

    // MARK: Tests - Request Adapter

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestAdaptersWhenCreatingDataRequest() async {
        // Given
        let endpoint = Endpoint()

        let methodAdapter = HTTPMethodAdapter(method: .post)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, interceptor: methodAdapter, eventMonitors: [monitor]))

        // When
        let expectation1 = Completion("Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.complete() }

        let request1 = session.request(endpoint)
        await expectation1.wait()

        let expectation2 = Completion("Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.complete() }

        let request2 = session.request(endpoint, interceptor: headerAdapter)
        await expectation2.wait()

        // Then
        #expect(request1.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.allHTTPHeaderFields?.count == 1)
        #expect(methodAdapter.adaptedCount.value == 2)
        #expect(headerAdapter.adaptedCount.value == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestAdaptersWhenCreatingDownloadRequest() async {
        // Given
        let endpoint = Endpoint()

        let methodAdapter = HTTPMethodAdapter(method: .post)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, interceptor: methodAdapter, eventMonitors: [monitor]))

        // When
        let expectation1 = Completion("Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.complete() }

        let request1 = session.download(endpoint)
        await expectation1.wait()

        let expectation2 = Completion("Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.complete() }

        let request2 = session.download(endpoint, interceptor: headerAdapter)
        await expectation2.wait()

        // Then
        #expect(request1.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.allHTTPHeaderFields?.count == 1)
        #expect(methodAdapter.adaptedCount.value == 2)
        #expect(headerAdapter.adaptedCount.value == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestAdaptersWhenCreatingUploadRequestWithData() async {
        // Given
        let data = Data("data".utf8)
        let endpoint = Endpoint.method(.post)

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, interceptor: methodAdapter, eventMonitors: [monitor]))

        // When
        let expectation1 = Completion("Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.complete() }

        let request1 = session.upload(data, to: endpoint)
        await expectation1.wait()

        let expectation2 = Completion("Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.complete() }

        let request2 = session.upload(data, to: endpoint, interceptor: headerAdapter)
        await expectation2.wait()

        // Then
        #expect(request1.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.allHTTPHeaderFields?.count == 1)
        #expect(methodAdapter.adaptedCount.value == 2)
        #expect(headerAdapter.adaptedCount.value == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestAdaptersWhenCreatingUploadRequestWithFile() async {
        // Given
        let fileURL = URL(fileURLWithPath: "/path/to/some/file.txt")
        let endpoint = Endpoint.method(.post)

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, interceptor: methodAdapter, eventMonitors: [monitor]))

        // When
        let expectation1 = Completion("Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.complete() }

        let request1 = session.upload(fileURL, to: endpoint)
        await expectation1.wait()

        let expectation2 = Completion("Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.complete() }

        let request2 = session.upload(fileURL, to: endpoint, interceptor: headerAdapter)
        await expectation2.wait()

        // Then
        #expect(request1.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.allHTTPHeaderFields?.count == 1)
        #expect(methodAdapter.adaptedCount.value == 2)
        #expect(headerAdapter.adaptedCount.value == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestAdaptersWhenCreatingUploadRequestWithInputStream() async {
        // Given
        let inputStream = InputStream(data: Data("data".utf8))
        let endpoint = Endpoint.method(.post)

        let methodAdapter = HTTPMethodAdapter(method: .get)
        let headerAdapter = HeaderAdapter()
        let monitor = ClosureEventMonitor()

        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, interceptor: methodAdapter, eventMonitors: [monitor]))

        // When
        let expectation1 = Completion("Request 1 created")
        monitor.requestDidCreateTask = { _, _ in expectation1.complete() }

        let request1 = session.upload(inputStream, to: endpoint)
        await expectation1.wait()

        let expectation2 = Completion("Request 2 created")
        monitor.requestDidCreateTask = { _, _ in expectation2.complete() }

        let request2 = session.upload(inputStream, to: endpoint, interceptor: headerAdapter)
        await expectation2.wait()

        // Then
        #expect(request1.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.httpMethod == methodAdapter.method.rawValue)
        #expect(request2.task?.originalRequest?.allHTTPHeaderFields?.count == 1)
        #expect(methodAdapter.adaptedCount.value == 2)
        #expect(headerAdapter.adaptedCount.value == 1)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionReturnsRequestAdaptationErrorWhenRequestAdapterThrowsError() async {
        // Given
        let endpoint = Endpoint()

        let methodAdapter = HTTPMethodAdapter(method: .post, throwsError: true)
        let headerAdapter = HeaderAdapter(throwsError: true)
        let monitor = ClosureEventMonitor()

        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, interceptor: methodAdapter, eventMonitors: [monitor]))

        // When
        let expectation1 = Completion("Request 1 created")
        monitor.requestDidFailToAdaptURLRequestWithError = { _, _, _ in expectation1.complete() }

        let request1 = session.request(endpoint)
        await expectation1.wait()

        let expectation2 = Completion("Request 2 created")
        monitor.requestDidFailToAdaptURLRequestWithError = { _, _, _ in expectation2.complete() }

        let request2 = session.request(endpoint, interceptor: headerAdapter)
        await expectation2.wait()

        let requests = [request1, request2]

        // Then
        for request in requests {
            #expect(request.error?.isRequestAdaptationError == true)
            #expect(request.error?.underlyingError?.asAFError?.urlConvertible as? String == "")
        }
    }

    // MARK: Tests - Request Retrier

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestRetrierWhenRequestInitiallyEncountersAdaptError() async {
        // Given
        let handler = RequestHandler(adaptedCount: 1, throwsErrorOnSecondAdapt: true, shouldApplyAuthorizationHeader: true)

        let session = stored(Session.independent())

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.basicAuth(), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 2)
        #expect(handler.retryCalledCount == 1)
        #expect(handler.retryCount == 1)
        #expect(response.result?.isSuccess == true)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestRetrierWhenDownloadInitiallyEncountersAdaptError() async {
        // Given
        let handler = RequestHandler(adaptedCount: 1, throwsErrorOnSecondAdapt: true, shouldApplyAuthorizationHeader: true)

        let session = stored(Session.independent())

        let expectation = Completion("request should eventually fail")
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        let destination: DownloadRequest.Destination = { _, _ in
            let fileURL = testDirectoryURL.appendingPathComponent("test-output.json")
            return (fileURL, [.removePreviousFile])
        }

        // When
        session.download(.basicAuth(), interceptor: handler, to: destination)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 2)
        #expect(handler.retryCalledCount == 1)
        #expect(handler.retryCount == 1)
        #expect(response.result?.isSuccess == true)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestRetrierWhenUploadInitiallyEncountersAdaptError() async {
        // Given
        let handler = UploadHandler()
        let session = stored(Session.independent(interceptor: handler))

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        let uploadData = Data("upload data".utf8)

        // When
        session.upload(uploadData, to: .method(.post))
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 2)
        #expect(handler.retryCalledCount == 1)
        #expect(handler.retryCount == 1)
        #expect(response.result?.isSuccess == true)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestRetrierWhenRequestEncountersError() async {
        // Given
        let handler = RequestHandler()

        let session = stored(Session.independent())

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.basicAuth(), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 2)
        #expect(handler.retryCalledCount == 3)
        #expect(handler.retryCount == 3)
        #expect(request.retryCount == 1)
        #expect(response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsSessionRetrierTheRequestRetrierWhenRequestEncountersError() async {
        // Given
        let sessionHandler = RequestHandler()
        let requestHandler = RequestHandler()

        let session = stored(Session.independent(interceptor: sessionHandler))

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.basicAuth(), interceptor: requestHandler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(sessionHandler.adaptCalledCount == 3)
        #expect(sessionHandler.adaptedCount == 3)
        #expect(sessionHandler.retryCalledCount == 4)
        #expect(sessionHandler.retryCount == 4)
        #expect(requestHandler.adaptCalledCount == 3)
        #expect(requestHandler.adaptedCount == 3)
        #expect(requestHandler.retryCalledCount == 3)
        #expect(requestHandler.retryCount == 3)
        #expect(request.retryCount == 2)
        #expect(response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsAdapterWhenRequestIsRetried() async {
        // Given
        let handler = RequestHandler(shouldApplyAuthorizationHeader: true)

        let session = stored(Session.independent(interceptor: handler))

        let expectation = Completion("request should eventually succeed")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 2)
        #expect(handler.retryCalledCount == 1)
        #expect(handler.retryCount == 1)
        #expect(request.retryCount == 1)
        #expect(response.result?.isSuccess == true)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionReturnsRequestAdaptationErrorWhenRequestIsRetried() async {
        // Given
        let handler = RequestHandler(throwsErrorOnSecondAdapt: true)

        let session = stored(Session.independent(interceptor: handler))

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 3)
        #expect(handler.retryCount == 3)
        #expect(request.retryCount == 1)
        #expect(response.result?.isSuccess == false)
        #expect(request.error?.isRequestAdaptationError == true)
        #expect(request.error?.underlyingError?.asAFError?.urlConvertible as? String == "/adapt/error/2")
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionRetriesRequestWithDelayWhenRetryResultContainsDelay() async {
        // Given
        let handler = RequestHandler(throwsErrorOnSecondAdapt: true, retryDelay: 0.01)

        let session = stored(Session.independent(interceptor: handler))

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 3)
        #expect(handler.retryCount == 3)
        #expect(request.retryCount == 1)
        #expect(response.result?.isSuccess == false)
        #expect(request.error?.isRequestAdaptationError == true)
        #expect(request.error?.underlyingError?.asAFError?.urlConvertible as? String == "/adapt/error/2")
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionReturnsRequestRetryErrorWhenRequestRetrierThrowsError() async {
        // Given
        let handler = RequestHandler(throwsErrorOnRetry: true)

        let session = stored(Session.independent(interceptor: handler))

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.basicAuth())
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 1)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 2)
        #expect(handler.retryCount == 0)
        #expect(request.retryCount == 0)
        #expect(response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }

        if let error = response.result?.failure {
            #expect(error.isRequestRetryError)
            #expect(error.underlyingError?.asAFError?.urlConvertible as? String == "/invalid/url/2")
        } else {
            Issue.record("error should not be nil")
        }
    }

    // MARK: Tests - Response Serializer Retry

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestRetrierWhenResponseSerializerThrowsError() async {
        // Given
        let handler = RequestHandler(shouldRetry: false)

        let session = stored(Session.independent())

        let expectation = Completion("request should eventually fail")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { jsonResponse in
                response.value = jsonResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 1)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 1)
        #expect(handler.retryCount == 0)
        #expect(request.retryCount == 0)
        #expect(response.result?.isSuccess == false)
        #expect(response.error?.isResponseSerializationError == true)
        #expect(response.error?.underlyingError as? DecodingError != nil)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsRequestRetrierForAllResponseSerializersThatThrowError() async {
        // Given
        let handler = RequestHandler(throwsErrorOnRetry: true)

        let session = stored(Session.independent())

        let json1Expectation = Completion("request should eventually fail")
        let json1Response = Capture<DataResponse<TestResponse, AFError>?>()

        let json2Expectation = Completion("request should eventually fail")
        let json2Response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response.value = response
                json1Expectation.complete()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response.value = response
                json2Expectation.complete()
            }

        await wait(for: [json1Expectation, json2Expectation])

        // Then
        #expect(handler.adaptCalledCount == 1)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 2)
        #expect(handler.retryCount == 0)
        #expect(request.retryCount == 0)
        #expect(json1Response.result?.isSuccess == false)
        #expect(json2Response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }

        let errors = [json1Response.value, json2Response.value].compactMap { $0?.error }

        #expect(errors.count == 2)

        for (index, error) in errors.enumerated() {
            #expect(error.isRequestRetryError)
            if case let .requestRetryFailed(retryError, originalError) = error {
                #expect(retryError.asAFError?.urlConvertible as? String == "/invalid/url/\(index + 1)")
                #expect(originalError.asAFError?.underlyingError as? DecodingError != nil)
            } else {
                Issue.record("Error failure reason should be response serialization failure")
            }
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionRetriesRequestImmediatelyWhenResponseSerializerRequestsRetry() async {
        // Given
        let handler = RequestHandler()
        let session = stored(Session.independent())

        let json1Expectation = Completion("request should eventually fail")
        let json1Response = Capture<DataResponse<TestResponse, AFError>?>()

        let json2Expectation = Completion("request should eventually fail")
        let json2Response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response.value = response
                json1Expectation.complete()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response.value = response
                json2Expectation.complete()
            }

        await wait(for: [json1Expectation, json2Expectation])

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 2)
        #expect(handler.retryCalledCount == 3)
        #expect(handler.retryCount == 3)
        #expect(request.retryCount == 1)
        #expect(json1Response.result?.isSuccess == false)
        #expect(json2Response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }

        let errors = [json1Response.value, json2Response.value].compactMap { $0?.error }
        #expect(errors.count == 2)

        for error in errors {
            #expect(error.isResponseSerializationError)
            #expect(error.underlyingError as? DecodingError != nil)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsResponseSerializerCompletionsWhenAdapterThrowsErrorDuringRetry() async {
        // Four retries should occur given this scenario:
        // 1) Retrier is called from first response serializer failure (trips retry)
        // 2) Retrier is called by Session for adapt error thrown
        // 3) Retrier is called again from first response serializer failure
        // 4) Retrier is called from second response serializer failure

        // Given
        let handler = RequestHandler(throwsErrorOnSecondAdapt: true)

        let session = stored(Session.independent())

        let json1Expectation = Completion("request should eventually fail")
        let json1Response = Capture<DataResponse<TestResponse, AFError>?>()

        let json2Expectation = Completion("request should eventually fail")
        let json2Response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response.value = response
                json1Expectation.complete()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response.value = response
                json2Expectation.complete()
            }

        await wait(for: [json1Expectation, json2Expectation])

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 4)
        #expect(handler.retryCount == 4)
        #expect(request.retryCount == 1)
        #expect(json1Response.result?.isSuccess == false)
        #expect(json2Response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }

        let errors = [json1Response.value, json2Response.value].compactMap { $0?.error }
        #expect(errors.count == 2)

        for error in errors {
            #expect(error.isRequestAdaptationError)
            #expect(error.underlyingError?.asAFError?.urlConvertible as? String == "/adapt/error/2")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCallsResponseSerializerCompletionsWhenAdapterThrowsErrorDuringRetryForDownloads() async {
        // Four retries should occur given this scenario:
        // 1) Retrier is called from first response serializer failure (trips retry)
        // 2) Retrier is called by Session for adapt error thrown
        // 3) Retrier is called again from first response serializer failure
        // 4) Retrier is called from second response serializer failure

        // Given
        let handler = RequestHandler(throwsErrorOnSecondAdapt: true)

        let session = stored(Session.independent())

        let json1Expectation = Completion("request should eventually fail")
        let json1Response = Capture<DownloadResponse<TestResponse, AFError>?>()

        let json2Expectation = Completion("request should eventually fail")
        let json2Response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        let request = session.download(.image(.jpeg), interceptor: handler)
            .validate()
            .responseDecodable(of: TestResponse.self) { response in
                json1Response.value = response
                json1Expectation.complete()
            }
            .responseDecodable(of: TestResponse.self) { response in
                json2Response.value = response
                json2Expectation.complete()
            }

        await wait(for: [json1Expectation, json2Expectation])

        // Then
        #expect(handler.adaptCalledCount == 2)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 4)
        #expect(handler.retryCount == 4)
        #expect(request.retryCount == 1)
        #expect(json1Response.result?.isSuccess == false)
        #expect(json2Response.result?.isSuccess == false)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }

        let errors = [json1Response.value, json2Response.value].compactMap { $0?.error }
        #expect(errors.count == 2)

        for error in errors {
            #expect(error.isRequestAdaptationError)
            #expect(error.underlyingError?.asAFError?.urlConvertible as? String == "/adapt/error/2")
        }
    }

    // MARK: Tests - Session Invalidation

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionIsInvalidatedAndAllRequestsCompleteWhenSessionIsDeinitialized() async {
        // Given
        let invalidationExpectation = Completion("sessionDidBecomeInvalidWithError should be called")
        let events = ClosureEventMonitor()
        events.sessionDidBecomeInvalidWithError = { _, _ in
            invalidationExpectation.complete()
        }
        var session: Session? = Session.independent(startRequestsImmediately: false, requestSetup: .eager, eventMonitors: [events])
        let error = Capture<AFError?>()
        let requestExpectation = Completion("request should complete")

        // When
        session?.request(.default).response { response in
            error.value = response.error
            requestExpectation.complete()
        }
        session = nil

        await wait(for: [invalidationExpectation, requestExpectation])

        // Then
        #expect(error.isSessionDeinitializedError == true)
    }

    // MARK: Tests - Request Cancellation

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionOnlyCallsResponseSerializerCompletionWhenCancellingInsideCompletion() async {
        // Given
        let handler = RequestHandler()
        let session = stored(Session.independent())

        let expectation = Completion("request should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()
        let completionCallCount = Capture(0)

        // When
        let request = session.request(.default, interceptor: handler)
        request.validate()

        request.responseDecodable(of: TestResponse.self) { resp in
            request.cancel()

            response.value = resp
            completionCallCount.write { $0 += 1 }

            DispatchQueue.main.after(0.01) { expectation.complete() }
        }

        await expectation.wait()

        // Then
        #expect(handler.adaptCalledCount == 1)
        #expect(handler.adaptedCount == 1)
        #expect(handler.retryCalledCount == 0)
        #expect(handler.retryCount == 0)
        #expect(request.retryCount == 0)
        #expect(response.result?.isSuccess == true)
        #expect(completionCallCount.value == 1)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    // MARK: Tests - Request State

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionSetsRequestStateWhenStartRequestsImmediatelyIsTrue() async {
        // Given
        let session = stored(Session.independent())

        let expectation = Completion("request should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.default).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.state == .finished)
        #expect(response.result?.isSuccess == true)
    }

    // MARK: Invalid Requests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getRequestsWithBodyDataAreConsideredInvalid() async {
        // Given
        let session = stored(Session.independent())
        var request = Endpoint().urlRequest
        request.httpBody = Data("invalid".utf8)
        let expect = Completion("request should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(request).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isBodyDataInGETRequest == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func adaptedGETRequestsWithBodyDataAreConsideredInvalid() async {
        // Given
        struct InvalidAdapter: RequestInterceptor {
            func adapt(_ urlRequest: URLRequest,
                       for session: Session,
                       completion: @escaping (Result<URLRequest, any Error>) -> Void) {
                var request = urlRequest
                request.httpBody = Data("invalid".utf8)

                completion(.success(request))
            }
        }
        let session = stored(Session.independent(interceptor: InvalidAdapter()))
        let expect = Completion("request should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.default).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expect.complete()
        }

        await expect.wait()

        // Then
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isRequestAdaptationError == true)
        #expect(response.error?.underlyingError?.asAFError?.isBodyDataInGETRequest == true)
    }
}

// MARK: -

@Suite(.storesInstances)
struct SessionMassActionTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestsCanHaveMassActionsPerformed() async {
        // Given
        let count = 10
        let createdTasks = Completion("all tasks created", expectedCount: count)
        let massActions = Completion("cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.complete() }
        let session = stored(Session.independent(requestSetup: .eager, eventMonitors: [monitor]))
        let request = Endpoint.delay(1)
        let requests = Capture<[DataRequest]>([])

        // When
        requests.value = (0..<count).map { _ in session.request(request) }

        await wait(for: [createdTasks])

        session.withAllRequests { $0.forEach { $0.suspend() }; massActions.complete() }

        await wait(for: [massActions])

        // Then
        // #expect treats a key path passed to rethrowing allSatisfy as a throwing call.
        // swiftformat:disable:next preferKeyPath
        #expect(requests.value.allSatisfy { $0.isSuspended })
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func automaticallyResumedRequestsCanBeMassCancelled() async {
        // Given
        let count = 100
        let completion = Completion("all requests should finish", expectedCount: count)
        let createdTasks = Completion("all tasks created", expectedCount: count)
        let gatheredMetrics = Completion("metrics gathered for all tasks", expectedCount: count)
        let cancellation = Completion("cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.complete() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.complete() }
        let session = stored(Session.independent(requestSetup: .eager, eventMonitors: [monitor]))
        let request = Endpoint.delay(1)
        let requests = Capture<[DataRequest]>([])
        let responses = Capture<[DataResponse<Data?, AFError>]>([])

        // When
        requests.value = (0..<count).map { _ in session.request(request) }

        await wait(for: [createdTasks])

        for request in requests.value {
            request.response { response in
                responses.write { $0.append(response) }
                completion.complete()
            }
        }

        session.cancelAllRequests {
            cancellation.complete()
        }

        await wait(for: [gatheredMetrics, cancellation, completion])

        // Then
        #expect(responses.value.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func lazyAutomaticallyResumedRequestsCanBeMassCancelled() async {
        // Given
        let count = 100
        let completion = Completion("all requests should finish", expectedCount: count)
        let createdTasks = Completion("all tasks created", expectedCount: count)
        let gatheredMetrics = Completion("metrics gathered for all tasks", expectedCount: count)
        let cancellation = Completion("cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.complete() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.complete() }
        let session = stored(Session.independent(eventMonitors: [monitor]))
        let request = Endpoint.delay(1)
        let requests = Capture<[DataRequest]>([])
        let responses = Capture<[DataResponse<Data?, AFError>]>([])

        // When
        requests.value = (0..<count).map { _ in session.request(request) }

        for request in requests.value {
            request.response { response in
                responses.write { $0.append(response) }
                completion.complete()
            }
        }

        await wait(for: [createdTasks])

        session.cancelAllRequests {
            cancellation.complete()
        }

        await wait(for: [gatheredMetrics, cancellation, completion])

        // Then
        #expect(responses.value.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func instanceAutomaticallyResumedRequestsCanBeMassCancelled() async {
        // Given
        let count = 100
        let completion = Completion("all requests should finish", expectedCount: count)
        let createdTasks = Completion("all tasks created", expectedCount: count)
        let gatheredMetrics = Completion("metrics gathered for all tasks", expectedCount: count)
        let cancellation = Completion("cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.complete() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.complete() }
        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, eventMonitors: [monitor]))
        let request = Endpoint.delay(1)
        let requests = Capture<[DataRequest]>([])
        let responses = Capture<[DataResponse<Data?, AFError>]>([])

        // When
        requests.value = (0..<count).map { _ in session.request(request, shouldAutomaticallyResume: true) }

        await wait(for: [createdTasks])

        for request in requests.value {
            request.response { response in
                responses.write { $0.append(response) }
                completion.complete()
            }
        }

        session.cancelAllRequests {
            cancellation.complete()
        }

        await wait(for: [gatheredMetrics, cancellation, completion])

        // Then
        #expect(responses.value.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func manuallyResumedRequestsCanBeMassCancelled() async {
        // Given
        let count = 100
        let completion = Completion("all requests should finish", expectedCount: count)
        let createdTasks = Completion("all tasks created", expectedCount: count)
        let gatheredMetrics = Completion("metrics gathered for all tasks", expectedCount: count)
        let cancellation = Completion("cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.complete() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.complete() }
        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, eventMonitors: [monitor]))
        let request = Endpoint.delay(1)
        let responses = Capture<[DataResponse<Data?, AFError>]>([])

        // When
        for _ in 0..<count {
            session.request(request).response { response in
                responses.write { $0.append(response) }
                completion.complete()
            }
        }

        await wait(for: [createdTasks])

        session.cancelAllRequests {
            cancellation.complete()
        }

        await wait(for: [gatheredMetrics, cancellation, completion])

        // Then
        #expect(responses.value.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func lazyManuallyResumedRequestsCanBeMassCancelled() async {
        // Given
        let count = 100
        let completion = Completion("all requests should finish", expectedCount: count)
        let createdTasks = Completion("all tasks created", expectedCount: count)
        let gatheredMetrics = Completion("metrics gathered for all tasks", expectedCount: count)
        let cancellation = Completion("cancel all requests should be called")
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in createdTasks.complete() }
        monitor.requestDidGatherMetrics = { _, _ in gatheredMetrics.complete() }
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [monitor]))
        let request = Endpoint.delay(1)
        let responses = Capture<[DataResponse<Data?, AFError>]>([])

        // When
        for _ in 0..<count {
            session.request(request).response { response in
                responses.write { $0.append(response) }
                completion.complete()
            }
            .resume()
        }

        await wait(for: [createdTasks])

        session.cancelAllRequests {
            cancellation.complete()
        }

        await wait(for: [gatheredMetrics, cancellation, completion])

        // Then
        #expect(responses.value.allSatisfy { $0.error?.isExplicitlyCancelledError == true })
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func retriedRequestsCanBeMassCancelled() async {
        // Given
        final class OnceRetrier: RequestInterceptor {
            private let hasRetried = Protected(false)

            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
                if hasRetried.read({ $0 }) {
                    var request = urlRequest
                    request.url = Endpoint.delay(1).url
                    completion(.success(request))
                } else {
                    completion(.success(urlRequest))
                }
            }

            func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping (RetryResult) -> Void) {
                completion(hasRetried.read { $0 } ? .doNotRetry : .retry)
                hasRetried.write(true)
            }
        }

        let queue = DispatchQueue(label: "com.alamofire.testQueue")
        let monitor = ClosureEventMonitor(queue: queue)
        let session = stored(Session.independent(interceptor: OnceRetrier(), eventMonitors: [monitor]))
        let request = Endpoint.status(401)
        let completion = Completion("all requests should finish")
        let cancellation = Completion("cancel all requests should be called")
        let createTask = Completion("should create task twice", expectedCount: 2)
        let tasksCreated = Capture(0)
        monitor.requestDidCreateTask = { [unowned session] _, _ in
            tasksCreated.write { $0 += 1 }
            createTask.complete()
            // Cancel after the second task is created to ensure proper lifetime events.
            if tasksCreated.value == 2 {
                session.cancelAllRequests {
                    cancellation.complete()
                }
            }
        }

        let received = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(request).validate().response { response in
            received.value = response
            completion.complete()
        }

        await wait(for: [completion, cancellation, createTask])

        // Then
        #expect(received.error?.isExplicitlyCancelledError == true)
        assert(on: session.rootQueue) {
            let (isTaskMapEmpty, isActiveRequestsEmpty) = session.mutableState.read {
                ($0.requestTaskMap.isEmpty, $0.activeRequests.isEmpty)
            }
            #expect(isTaskMapEmpty)
            #expect(isActiveRequestsEmpty)
        }
    }
}

// MARK: -

@Suite(.storesInstances)
struct SessionConfigurationHeadersTestCase {
    enum ConfigurationType {
        case `default`, ephemeral
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func defaultConfigurationHeadersAreSentWithRequest() async {
        // Given, When, Then
        await executeAuthorizationHeaderTest(for: .default)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func ephemeralConfigurationHeadersAreSentWithRequest() async {
        // Given, When, Then
        await executeAuthorizationHeaderTest(for: .ephemeral)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func executeAuthorizationHeaderTest(for type: ConfigurationType) async {
        // Given
        let session: Session = {
            let configuration: URLSessionConfiguration = {
                let configuration: URLSessionConfiguration = switch type {
                case .default:
                    .default
                case .ephemeral:
                    .ephemeral
                }

                var headers = HTTPHeaders.default
                headers["Authorization"] = "Bearer 123456"
                configuration.headers = headers

                return configuration
            }()

            return stored(Session.independent(configuration: configuration))
        }()

        let expectation = Completion("request should complete successfully")

        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.default)
            .responseDecodable(of: TestResponse.self) { closureResponse in
                response.value = closureResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil, "request should not be nil")
        #expect(response.response != nil, "response should not be nil")
        #expect(response.data != nil, "data should not be nil")
        #expect(response.result?.isSuccess == true)
        #expect(response.value?.value?.headers["Authorization"] == "Bearer 123456", "Authorization header should match")
    }
}
