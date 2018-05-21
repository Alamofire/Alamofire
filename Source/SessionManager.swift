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
    open static let `default` = SessionManager()

    let configuration: URLSessionConfiguration
    let delegate: SessionDelegate
    let rootQueue: DispatchQueue
    let requestQueue: DispatchQueue
    open let adapter: RequestAdapter?
    open let retrier: RequestRetrier?
    open let trustManager: ServerTrustManager?

    let session: URLSession
    let eventMonitor: CompositeEventMonitor
    let defaultEventMonitors: [EventMonitor] = [] // TODO: Create notification event monitor, make default

    public init(configuration: URLSessionConfiguration = .default,
                delegate: SessionDelegate = SessionDelegate(),
                rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.sessionManager.rootQueue"),
                adapter: RequestAdapter? = nil,
                trustManager: ServerTrustManager? = nil,
                retrier: RequestRetrier? = nil,
                eventMonitors: [EventMonitor] = []) {
        self.configuration = configuration
        self.delegate = delegate
        self.rootQueue = rootQueue
        self.adapter = adapter
        self.retrier = retrier
        self.trustManager = trustManager
        requestQueue = DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: rootQueue, name: "org.alamofire.sessionManager.sessionDelegateQueue")
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        eventMonitor = CompositeEventMonitor(monitors: defaultEventMonitors + eventMonitors)
        delegate.didCreateSessionManager(self, withEventMonitor: eventMonitor)
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

    // TODO: Serialization Queue support?
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
                       to destination: @escaping DownloadRequest.Destination = DownloadRequest.suggestedDownloadDestination()) -> DownloadRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)

        return download(convertible, to: destination)
    }

    func download(_ convertible: URLRequestConvertible,
                  to destination: @escaping DownloadRequest.Destination = DownloadRequest.suggestedDownloadDestination()) -> DownloadRequest {
        let request = DownloadRequest(convertible: convertible,
                                      underlyingQueue: rootQueue,
                                      eventMonitor: eventMonitor,
                                      delegate: delegate,
                                      destination: destination)

        perform(request)

        return request
    }

    // MARK: - Upload

    struct UploadConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            return try URLRequest(url: url, method: method, headers: headers)
        }
    }

    func upload(_ data: Data,
                to convertible: URLConvertible,
                method: HTTPMethod = .post,
                headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = UploadConvertible(url: convertible, method: method, headers: headers)

        return upload(data: data, to: convertible)
    }

    func upload(data: Data, to convertible: URLRequestConvertible) -> UploadRequest {
        return upload(.data(data), to: convertible)
    }

    func upload(_ fileURL: URL,
                to convertible: URLConvertible,
                method: HTTPMethod = .post,
                headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = UploadConvertible(url: convertible, method: method, headers: headers)

        return upload(fileURL, to: convertible)
    }

    func upload(_ fileURL: URL, to convertible: URLRequestConvertible) -> UploadRequest {
        return upload(.file(fileURL), to: convertible)
    }

    func upload(_ stream: InputStream,
                to convertible: URLConvertible,
                method: HTTPMethod = .post,
                headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = UploadConvertible(url: convertible, method: method, headers: headers)

        return upload(stream, to: convertible)
    }

    func upload(_ stream: InputStream, to convertible: URLRequestConvertible) -> UploadRequest {
        return upload(.stream(stream), to: convertible)
    }

    // MARK: - Internal API

    // MARK: Uploadable

    func upload(_ uploadable: UploadRequest.Uploadable, to convertible: URLRequestConvertible) -> UploadRequest {
        let request = UploadRequest(convertible: convertible,
                                    underlyingQueue: rootQueue,
                                    eventMonitor: eventMonitor,
                                    delegate: delegate,
                                    uploadable: uploadable)

        perform(request)

        return request
    }

    // MARK: Perform

    func perform(_ request: Request) {
        // TODO: Threadsafe adapter access?
        requestQueue.async { [adapter = adapter] in
            guard !request.isCancelled else { return }

            do {
                let initialRequest = try request.convertible.asURLRequest()
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
}
