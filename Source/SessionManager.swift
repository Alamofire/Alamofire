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

open class SessionManager {
    public static let `default` = SessionManager()

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

    public init(session: URLSession,
                delegate: SessionDelegate,
                rootQueue: DispatchQueue,
                requestQueue: DispatchQueue? = nil,
                serializationQueue: DispatchQueue? = nil,
                adapter: RequestAdapter? = nil,
                serverTrustManager: ServerTrustManager? = nil,
                retrier: RequestRetrier? = nil,
                eventMonitors: [EventMonitor] = []) {
        precondition(session.delegate === delegate,
                     "URLSession SessionManager initializer must pass the SessionDelegate that has been assigned to the URLSession as its delegate.")
        precondition(session.delegateQueue.underlyingQueue === rootQueue,
                     "URLSession SessionManager intializer must pass the DispatchQueue used as the delegateQueue's underlyingQueue as the rootQueue.")

        self.session = session
        self.delegate = delegate
        self.rootQueue = rootQueue
        self.requestQueue = requestQueue ?? DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        self.serializationQueue = serializationQueue ?? DispatchQueue(label: "\(rootQueue.label).serializationQueue", target: rootQueue)
        self.adapter = adapter
        self.retrier = retrier
        self.serverTrustManager = serverTrustManager
        eventMonitor = CompositeEventMonitor(monitors: defaultEventMonitors + eventMonitors)
        delegate.didCreateSessionManager(self, withEventMonitor: eventMonitor)
    }

    public convenience init(configuration: URLSessionConfiguration = .alamofireDefault,
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
        self.init(session: session,
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

    open func request(_ convertible: URLRequestConvertible) -> DataRequest {
        let request = DataRequest(convertible: convertible,
                                  underlyingQueue: rootQueue,
                                  serializationQueue: serializationQueue,
                                  eventMonitor: eventMonitor,
                                  delegate: delegate)

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

    open func download(_ convertible: URLRequestConvertible,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .request(convertible),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      delegate: delegate,
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
                                      delegate: delegate,
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
                to url: URLConvertible,
                method: HTTPMethod = .post,
                headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url, method: method, headers: headers)

        return upload(multipartFormData: multipartFormData, usingThreshold: encodingMemoryThreshold, with: convertible)
    }

    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                usingThreshold encodingMemoryThreshold: UInt64 = MultipartUpload.encodingMemoryThreshold,
                with request: URLRequestConvertible) -> UploadRequest {
        let multipartUpload = MultipartUpload(isInBackgroundSession: (session.configuration.identifier != nil),
                                              encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: request,
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
                                    delegate: delegate)

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
                self.rootQueue.async { self.delegate.didReceiveResumeData(resumeData, for: request) }
            }
        }
    }

    func performSetupOperations(for request: Request, convertible: URLRequestConvertible) {
        do {
            let initialRequest = try convertible.asURLRequest()
            self.rootQueue.async { request.didCreateURLRequest(initialRequest) }

            guard !request.isCancelled else { return }

            if let adapter = adapter {
                do {
                    let adaptedRequest = try adapter.adapt(initialRequest)
                    self.rootQueue.async {
                        request.didAdaptInitialRequest(initialRequest, to: adaptedRequest)
                        self.delegate.didCreateURLRequest(adaptedRequest, for: request)
                    }
                } catch {
                    self.rootQueue.async { request.didFailToAdaptURLRequest(initialRequest, withError: error) }
                }
            } else {
                self.rootQueue.async { self.delegate.didCreateURLRequest(initialRequest, for: request) }
            }
        } catch {
            self.rootQueue.async { request.didFailToCreateURLRequest(with: error) }
        }
    }
}
