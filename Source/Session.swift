//
//  SessionManager.swift
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
    public let adapter: RequestAdapter?
    public let retrier: RequestRetrier?
    public let serverTrustManager: ServerTrustManager?

    public let session: URLSession
    public let eventMonitor: CompositeEventMonitor
    public let defaultEventMonitors: [EventMonitor] = [AlamofireNotifications()]

    var requestTaskMap = RequestTaskMap()
    public let startRequestsImmediately: Bool

    public init(startRequestsImmediately: Bool = true,
                session: URLSession,
                delegate: SessionDelegate,
                rootQueue: DispatchQueue,
                requestQueue: DispatchQueue? = nil,
                serializationQueue: DispatchQueue? = nil,
                adapter: RequestAdapter? = nil,
                serverTrustManager: ServerTrustManager? = nil,
                retrier: RequestRetrier? = nil,
                eventMonitors: [EventMonitor] = []) {
        precondition(session.delegate === delegate,
                     "SessionManager(session:) initializer must be passed the delegate that has been assigned to the URLSession as the SessionDataProvider.")
        precondition(session.delegateQueue.underlyingQueue === rootQueue,
                     "SessionManager(session:) intializer must be passed the DispatchQueue used as the delegateQueue's underlyingQueue as rootQueue.")

        self.startRequestsImmediately = startRequestsImmediately
        self.session = session
        self.delegate = delegate
        self.rootQueue = rootQueue
        self.requestQueue = requestQueue ?? DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        self.serializationQueue = serializationQueue ?? DispatchQueue(label: "\(rootQueue.label).serializationQueue", target: rootQueue)
        self.adapter = adapter
        self.retrier = retrier
        self.serverTrustManager = serverTrustManager
        eventMonitor = CompositeEventMonitor(monitors: defaultEventMonitors + eventMonitors)
        delegate.eventMonitor = eventMonitor
        delegate.stateProvider = self
    }

    public convenience init(startRequestsImmediately: Bool = true,
                            configuration: URLSessionConfiguration = .alamofireDefault,
                            delegate: SessionDelegate = SessionDelegate(),
                            rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.sessionManager.rootQueue"),
                            requestQueue: DispatchQueue? = nil,
                            serializationQueue: DispatchQueue? = nil,
                            adapter: RequestAdapter? = nil,
                            serverTrustManager: ServerTrustManager? = nil,
                            retrier: RequestRetrier? = nil,
                            eventMonitors: [EventMonitor] = []) {
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: rootQueue, name: "org.alamofire.sessionManager.sessionDelegateQueue")
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        self.init(startRequestsImmediately: startRequestsImmediately,
                  session: session,
                  delegate: delegate,
                  rootQueue: rootQueue,
                  requestQueue: requestQueue,
                  serializationQueue: serializationQueue,
                  adapter: adapter,
                  serverTrustManager: serverTrustManager,
                  retrier: retrier,
                  eventMonitors: eventMonitors)
    }

    deinit {
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
                      headers: HTTPHeaders? = nil) -> DataRequest {
        let convertible = RequestConvertible(url: url,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)
        return request(convertible)
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
                                             headers: HTTPHeaders? = nil) -> DataRequest {
        let convertible = RequestEncodableConvertible(url: url,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers)

        return request(convertible)
    }

    open func request(_ convertible: URLRequestConvertible) -> DataRequest {
        let request = DataRequest(convertible: convertible,
                                  underlyingQueue: rootQueue,
                                  serializationQueue: serializationQueue,
                                  eventMonitor: eventMonitor,
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
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)

        return download(convertible, to: destination)
    }

    open func download<Parameters: Encodable>(_ convertible: URLConvertible,
                                              method: HTTPMethod = .get,
                                              parameters: Parameters? = nil,
                                              encoder: ParameterEncoder = JSONParameterEncoder.default,
                                              headers: HTTPHeaders? = nil,
                                              to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers)

        return download(convertible, to: destination)
    }

    open func download(_ convertible: URLRequestConvertible,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .request(convertible),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      delegate: self,
                                      destination: destination)

        perform(request)

        return request
    }

    open func download(resumingWith data: Data,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .resumeData(data),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
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
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(data, with: convertible)
    }

    open func upload(_ data: Data, with convertible: URLRequestConvertible) -> UploadRequest {
        return upload(.data(data), with: convertible)
    }

    open func upload(_ fileURL: URL,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(fileURL, with: convertible)
    }

    open func upload(_ fileURL: URL, with convertible: URLRequestConvertible) -> UploadRequest {
        return upload(.file(fileURL, shouldRemove: false), with: convertible)
    }

    open func upload(_ stream: InputStream,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(stream, with: convertible)
    }

    open func upload(_ stream: InputStream, with convertible: URLRequestConvertible) -> UploadRequest {
        return upload(.stream(stream), with: convertible)
    }

    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartUpload.encodingMemoryThreshold,
                     fileManager: FileManager = .default,
                     to url: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url, method: method, headers: headers)

        return upload(multipartFormData: multipartFormData, usingThreshold: encodingMemoryThreshold, with: convertible)
    }

    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartUpload.encodingMemoryThreshold,
                     fileManager: FileManager = .default,
                     with request: URLRequestConvertible) -> UploadRequest {
        let multipartUpload = MultipartUpload(isInBackgroundSession: (session.configuration.identifier != nil),
                                              encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: request,
                                              fileManager: fileManager,
                                              multipartBuilder: multipartFormData)

        return upload(multipartUpload)
    }

    // MARK: - Internal API

    // MARK: Uploadable

    func upload(_ uploadable: UploadRequest.Uploadable, with convertible: URLRequestConvertible) -> UploadRequest {
        let uploadable = Upload(request: convertible, uploadable: uploadable)

        return upload(uploadable)
    }

    func upload(_ upload: UploadConvertible) -> UploadRequest {
        let request = UploadRequest(convertible: upload,
                                    underlyingQueue: rootQueue,
                                    serializationQueue: serializationQueue,
                                    eventMonitor: eventMonitor,
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

            if let adapter = adapter {
                adapter.adapt(initialRequest) { (result) in
                    do {
                        let adaptedRequest = try result.unwrap()
                        self.rootQueue.async {
                            request.didAdaptInitialRequest(initialRequest, to: adaptedRequest)
                            self.didCreateURLRequest(adaptedRequest, for: request)
                        }
                    } catch {
                        self.rootQueue.async { request.didFailToAdaptURLRequest(initialRequest, withError: error) }
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
}

// MARK: - RequestDelegate

extension Session: RequestDelegate {
    public var sessionConfiguration: URLSessionConfiguration {
        return session.configuration
    }

    public func willRetryRequest(_ request: Request) -> Bool {
        return (retrier != nil)
    }

    public func retryRequest(_ request: Request, ifNecessaryWithError error: Error) {
        guard let retrier = retrier else { return }

        retrier.should(self, retry: request, with: error) { (shouldRetry, retryInterval) in
            guard !request.isCancelled else { return }

            self.rootQueue.async {
                guard !request.isCancelled else { return }

                guard shouldRetry else { request.finish(); return }

                self.rootQueue.after(retryInterval) {
                    guard !request.isCancelled else { return }

                    request.requestIsRetrying()
                    self.perform(request)
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

// MARK: - SessionDelegateDelegate

extension Session: SessionStateProvider {
    public func request(for task: URLSessionTask) -> Request? {
        return requestTaskMap[task]
    }

    public func didCompleteTask(_ task: URLSessionTask) {
        requestTaskMap[task] = nil
    }

    public func credential(for task: URLSessionTask, protectionSpace: URLProtectionSpace) -> URLCredential? {
        return requestTaskMap[task]?.credential ??
               session.configuration.urlCredentialStorage?.defaultCredential(for: protectionSpace)
    }
}
