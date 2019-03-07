//
//  Session.swift
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

import Foundation

open class Session {
    public static let `default` = Session()

    public let delegate: SessionDelegate
    public let rootQueue: DispatchQueue
    public let requestQueue: DispatchQueue
    public let serializationQueue: DispatchQueue
    public let interceptor: RequestInterceptor?
    public let serverTrustManager: ServerTrustManager?
    public let redirectHandler: RedirectHandler?
    public let cachedResponseHandler: CachedResponseHandler?

    public let session: URLSession
    public let eventMonitor: CompositeEventMonitor
    public let defaultEventMonitors: [EventMonitor] = [AlamofireNotifications()]

    var requestTaskMap = RequestTaskMap()
    public let startRequestsImmediately: Bool

    public init(session: URLSession,
                delegate: SessionDelegate,
                rootQueue: DispatchQueue,
                startRequestsImmediately: Bool = true,
                requestQueue: DispatchQueue? = nil,
                serializationQueue: DispatchQueue? = nil,
                interceptor: RequestInterceptor? = nil,
                serverTrustManager: ServerTrustManager? = nil,
                redirectHandler: RedirectHandler? = nil,
                cachedResponseHandler: CachedResponseHandler? = nil,
                eventMonitors: [EventMonitor] = []) {
        precondition(session.delegate === delegate,
                     "SessionManager(session:) initializer must be passed the delegate that has been assigned to the URLSession as the SessionDataProvider.")
        precondition(session.delegateQueue.underlyingQueue === rootQueue,
                     "SessionManager(session:) intializer must be passed the DispatchQueue used as the delegateQueue's underlyingQueue as rootQueue.")

        self.session = session
        self.delegate = delegate
        self.rootQueue = rootQueue
        self.startRequestsImmediately = startRequestsImmediately
        self.requestQueue = requestQueue ?? DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        self.serializationQueue = serializationQueue ?? DispatchQueue(label: "\(rootQueue.label).serializationQueue", target: rootQueue)
        self.interceptor = interceptor
        self.serverTrustManager = serverTrustManager
        self.redirectHandler = redirectHandler
        self.cachedResponseHandler = cachedResponseHandler
        eventMonitor = CompositeEventMonitor(monitors: defaultEventMonitors + eventMonitors)
        delegate.eventMonitor = eventMonitor
        delegate.stateProvider = self
    }

    public convenience init(configuration: URLSessionConfiguration = .alamofireDefault,
                            delegate: SessionDelegate = SessionDelegate(),
                            rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.sessionManager.rootQueue"),
                            startRequestsImmediately: Bool = true,
                            requestQueue: DispatchQueue? = nil,
                            serializationQueue: DispatchQueue? = nil,
                            interceptor: RequestInterceptor? = nil,
                            serverTrustManager: ServerTrustManager? = nil,
                            redirectHandler: RedirectHandler? = nil,
                            cachedResponseHandler: CachedResponseHandler? = nil,
                            eventMonitors: [EventMonitor] = []) {
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: rootQueue, name: "org.alamofire.sessionManager.sessionDelegateQueue")
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)

        self.init(session: session,
                  delegate: delegate,
                  rootQueue: rootQueue,
                  startRequestsImmediately: startRequestsImmediately,
                  requestQueue: requestQueue,
                  serializationQueue: serializationQueue,
                  interceptor: interceptor,
                  serverTrustManager: serverTrustManager,
                  redirectHandler: redirectHandler,
                  cachedResponseHandler: cachedResponseHandler,
                  eventMonitors: eventMonitors)
    }

    deinit {
        finishRequestsForDeinit()
        session.invalidateAndCancel()
    }

    // MARK: - Request

    struct RequestConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoding: ParameterEncoding
        let headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            let request = try URLRequest(url: url, method: method, headers: headers)
            return try encoding.encode(request, with: parameters)
        }
    }

    open func request(_ url: URLConvertible,
                      method: HTTPMethod = .get,
                      parameters: Parameters? = nil,
                      encoding: ParameterEncoding = URLEncoding.default,
                      headers: HTTPHeaders? = nil,
                      interceptor: RequestInterceptor? = nil) -> DataRequest {
        let convertible = RequestConvertible(url: url,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)

        return request(convertible, interceptor: interceptor)
    }

    struct RequestEncodableConvertible<Parameters: Encodable>: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoder: ParameterEncoder
        let headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            let request = try URLRequest(url: url, method: method, headers: headers)

            return try parameters.map { try encoder.encode($0, into: request) } ?? request
        }
    }

    open func request<Parameters: Encodable>(_ url: URLConvertible,
                                             method: HTTPMethod = .get,
                                             parameters: Parameters? = nil,
                                             encoder: ParameterEncoder = JSONParameterEncoder.default,
                                             headers: HTTPHeaders? = nil,
                                             interceptor: RequestInterceptor? = nil) -> DataRequest {
        let convertible = RequestEncodableConvertible(url: url,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers)

        return request(convertible, interceptor: interceptor)
    }

    open func request(_ convertible: URLRequestConvertible, interceptor: RequestInterceptor? = nil) -> DataRequest {
        let request = DataRequest(convertible: convertible,
                                  underlyingQueue: rootQueue,
                                  serializationQueue: serializationQueue,
                                  eventMonitor: eventMonitor,
                                  interceptor: interceptor,
                                  delegate: self)

        perform(request)

        return request
    }

    // MARK: - Download

    open func download(_ convertible: URLConvertible,
                       method: HTTPMethod = .get,
                       parameters: Parameters? = nil,
                       encoding: ParameterEncoding = URLEncoding.default,
                       headers: HTTPHeaders? = nil,
                       interceptor: RequestInterceptor? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)

        return download(convertible, interceptor: interceptor, to: destination)
    }

    open func download<Parameters: Encodable>(_ convertible: URLConvertible,
                                              method: HTTPMethod = .get,
                                              parameters: Parameters? = nil,
                                              encoder: ParameterEncoder = JSONParameterEncoder.default,
                                              headers: HTTPHeaders? = nil,
                                              interceptor: RequestInterceptor? = nil,
                                              to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers)

        return download(convertible, interceptor: interceptor, to: destination)
    }

    open func download(_ convertible: URLRequestConvertible,
                       interceptor: RequestInterceptor? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .request(convertible),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      interceptor: interceptor,
                                      delegate: self,
                                      destination: destination)

        perform(request)

        return request
    }

    open func download(resumingWith data: Data,
                       interceptor: RequestInterceptor? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .resumeData(data),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      interceptor: interceptor,
                                      delegate: self,
                                      destination: destination)

        perform(request)

        return request
    }

    // MARK: - Upload

    struct ParameterlessRequestConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            return try URLRequest(url: url, method: method, headers: headers)
        }
    }

    struct Upload: UploadConvertible {
        let request: URLRequestConvertible
        let uploadable: UploadableConvertible

        func createUploadable() throws -> UploadRequest.Uploadable {
            return try uploadable.createUploadable()
        }

        func asURLRequest() throws -> URLRequest {
            return try request.asURLRequest()
        }
    }

    open func upload(_ data: Data,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(data, with: convertible, interceptor: interceptor)
    }

    open func upload(_ data: Data,
                     with convertible: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return upload(.data(data), with: convertible, interceptor: interceptor)
    }

    open func upload(_ fileURL: URL,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(fileURL, with: convertible, interceptor: interceptor)
    }

    open func upload(_ fileURL: URL,
                     with convertible: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return upload(.file(fileURL, shouldRemove: false), with: convertible, interceptor: interceptor)
    }

    open func upload(_ stream: InputStream,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(stream, with: convertible, interceptor: interceptor)
    }

    open func upload(_ stream: InputStream,
                     with convertible: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return upload(.stream(stream), with: convertible, interceptor: interceptor)
    }

    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartUpload.encodingMemoryThreshold,
                     fileManager: FileManager = .default,
                     to url: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url, method: method, headers: headers)

        return upload(multipartFormData: multipartFormData,
                      usingThreshold: encodingMemoryThreshold,
                      with: convertible,
                      interceptor: interceptor)
    }

    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartUpload.encodingMemoryThreshold,
                     fileManager: FileManager = .default,
                     with request: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let multipartUpload = MultipartUpload(isInBackgroundSession: (session.configuration.identifier != nil),
                                              encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: request,
                                              fileManager: fileManager,
                                              multipartBuilder: multipartFormData)

        return upload(multipartUpload, interceptor: interceptor)
    }

    // MARK: - Internal API

    // MARK: Uploadable

    func upload(_ uploadable: UploadRequest.Uploadable,
                with convertible: URLRequestConvertible,
                interceptor: RequestInterceptor?) -> UploadRequest {
        let uploadable = Upload(request: convertible, uploadable: uploadable)

        return upload(uploadable, interceptor: interceptor)
    }

    func upload(_ upload: UploadConvertible, interceptor: RequestInterceptor?) -> UploadRequest {
        let request = UploadRequest(convertible: upload,
                                    underlyingQueue: rootQueue,
                                    serializationQueue: serializationQueue,
                                    eventMonitor: eventMonitor,
                                    interceptor: interceptor,
                                    delegate: self)

        perform(request)

        return request
    }

    // MARK: Perform

    func perform(_ request: Request) {
        switch request {
        case let r as DataRequest: perform(r)
        case let r as UploadRequest: perform(r)
        case let r as DownloadRequest: perform(r)
        default: fatalError("Attempted to perform unsupported Request subclass: \(type(of: request))")
        }
    }

    func perform(_ request: DataRequest) {
        requestQueue.async {
            guard !request.isCancelled else { return }

            self.performSetupOperations(for: request, convertible: request.convertible)
        }
    }

    func perform(_ request: UploadRequest) {
        requestQueue.async {
            guard !request.isCancelled else { return }

            do {
                let uploadable = try request.upload.createUploadable()
                self.rootQueue.async { request.didCreateUploadable(uploadable) }

                self.performSetupOperations(for: request, convertible: request.convertible)
            } catch {
                self.rootQueue.async { request.didFailToCreateUploadable(with: error) }
            }
        }
    }

    func perform(_ request: DownloadRequest) {
        requestQueue.async {
            guard !request.isCancelled else { return }

            switch request.downloadable {
            case let .request(convertible):
                self.performSetupOperations(for: request, convertible: convertible)
            case let .resumeData(resumeData):
                self.rootQueue.async { self.didReceiveResumeData(resumeData, for: request) }
            }
        }
    }

    func performSetupOperations(for request: Request, convertible: URLRequestConvertible) {
        do {
            let initialRequest = try convertible.asURLRequest()
            rootQueue.async { request.didCreateURLRequest(initialRequest) }

            guard !request.isCancelled else { return }

            if let adapter = adapter(for: request) {
                adapter.adapt(initialRequest, for: self) { result in
                    do {
                        let adaptedRequest = try result.unwrap()

                        self.rootQueue.async {
                            request.didAdaptInitialRequest(initialRequest, to: adaptedRequest)
                            self.didCreateURLRequest(adaptedRequest, for: request)
                        }
                    } catch {
                        let adaptError = AFError.requestAdaptationFailed(error: error)
                        self.rootQueue.async { request.didFailToAdaptURLRequest(initialRequest, withError: adaptError) }
                    }
                }
            } else {
                rootQueue.async { self.didCreateURLRequest(initialRequest, for: request) }
            }
        } catch {
            rootQueue.async { request.didFailToCreateURLRequest(with: error) }
        }
    }

    // MARK: - Task Handling

    func didCreateURLRequest(_ urlRequest: URLRequest, for request: Request) {
        guard !request.isCancelled else { return }

        let task = request.task(for: urlRequest, using: session)
        requestTaskMap[request] = task
        request.didCreateTask(task)

        resumeOrSuspendTask(task, ifNecessaryForRequest: request)
    }

    func didReceiveResumeData(_ data: Data, for request: DownloadRequest) {
        guard !request.isCancelled else { return }

        let task = request.task(forResumeData: data, using: session)
        requestTaskMap[request] = task
        request.didCreateTask(task)

        resumeOrSuspendTask(task, ifNecessaryForRequest: request)
    }

    func resumeOrSuspendTask(_ task: URLSessionTask, ifNecessaryForRequest request: Request) {
        if startRequestsImmediately || request.isResumed {
            task.resume()
            request.didResume()
        }

        if request.isSuspended {
            task.suspend()
            request.didSuspend()
        }
    }

    // MARK: - Adapters and Retriers

    func adapter(for request: Request) -> RequestAdapter? {
        if let requestInterceptor = request.interceptor, let sessionInterceptor = interceptor {
            return Interceptor(adapters: [requestInterceptor, sessionInterceptor])
        } else {
            return request.interceptor ?? interceptor
        }
    }

    func retrier(for request: Request) -> RequestRetrier? {
        if let requestInterceptor = request.interceptor, let sessionInterceptor = interceptor {
            return Interceptor(retriers: [requestInterceptor, sessionInterceptor])
        } else {
            return request.interceptor ?? interceptor
        }
    }

    // MARK: - Invalidation

    func finishRequestsForDeinit() {
        requestTaskMap.requests.forEach { $0.finish(error: AFError.sessionDeinitialized) }
    }
}

// MARK: - RequestDelegate

extension Session: RequestDelegate {
    public var sessionConfiguration: URLSessionConfiguration {
        return session.configuration
    }

    public func willAttemptToRetryRequest(_ request: Request) -> Bool {
        return retrier(for: request) != nil
    }

    public func retryRequest(_ request: Request, ifNecessaryWithError error: Error) {
        guard let retrier = retrier(for: request) else { request.finish(); return }

        retrier.retry(request, for: self, dueTo: error) { result in
            guard !request.isCancelled else { return }

            self.rootQueue.async {
                guard !request.isCancelled else { return }

                if result.retryRequired {
                    let retry: () -> Void = {
                        guard !request.isCancelled else { return }

                        request.requestIsRetrying()
                        self.perform(request)
                    }

                    if let retryDelay = result.delay {
                        self.rootQueue.after(retryDelay) { retry() }
                    } else {
                        self.rootQueue.async { retry() }
                    }
                } else {
                    var retryError = error

                    if let retryResultError = result.error {
                        retryError = AFError.requestRetryFailed(retryError: retryResultError, originalError: error)
                    }

                    request.finish(error: retryError)
                }
            }
        }
    }

    public func cancelRequest(_ request: Request) {
        rootQueue.async {
            guard let task = self.requestTaskMap[request] else {
                request.didCancel()
                request.finish()
                return
            }

            task.cancel()
            request.didCancel()
        }
    }

    public func cancelDownloadRequest(_ request: DownloadRequest, byProducingResumeData: @escaping (Data?) -> Void) {
        rootQueue.async {
            guard let downloadTask = self.requestTaskMap[request] as? URLSessionDownloadTask else {
                request.didCancel()
                request.finish()
                return
            }

            downloadTask.cancel { (data) in
                self.rootQueue.async {
                    byProducingResumeData(data)
                    request.didCancel()
                }
            }
        }
    }

    public func suspendRequest(_ request: Request) {
        rootQueue.async {
            guard !request.isCancelled, let task = self.requestTaskMap[request] else { return }

            task.suspend()
            request.didSuspend()
        }
    }

    public func resumeRequest(_ request: Request) {
        rootQueue.async {
            guard !request.isCancelled, let task = self.requestTaskMap[request] else { return }

            task.resume()
            request.didResume()
        }
    }
}

// MARK: - SessionStateProvider

extension Session: SessionStateProvider {
    public func request(for task: URLSessionTask) -> Request? {
        return requestTaskMap[task]
    }

    public func didCompleteTask(_ task: URLSessionTask) {
        requestTaskMap[task] = nil
    }

    public func credential(for task: URLSessionTask, in protectionSpace: URLProtectionSpace) -> URLCredential? {
        return requestTaskMap[task]?.credential ??
               session.configuration.urlCredentialStorage?.defaultCredential(for: protectionSpace)
    }

    public func cancelRequestsForSessionInvalidation(with error: Error?) {
        requestTaskMap.requests.forEach { $0.finish(error: AFError.sessionInvalidated(error: error)) }
    }
}
