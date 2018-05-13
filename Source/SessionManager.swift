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
        delegate.didCreate(sessionManager: self, with: eventMonitor)
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: - Request

    struct RequestConvertible<Convertible: URLConvertible>: URLRequestConvertible {
        let url: Convertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoding: ParameterEncoding
        let headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            let request = try URLRequest(url: url, method: method, headers: headers)
            return try encoding.encode(request, with: parameters)
        }
    }

    open func request<Convertible: URLConvertible>(_ url: Convertible,
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

    open func request<Convertible: URLRequestConvertible>(_ convertible: Convertible) -> DataRequest {
        let request = DataRequest(underlyingQueue: rootQueue, delegate: delegate, eventMonitor: eventMonitor)

        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.dataTask(with: urlRequest)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: nil, error: error)
            }
        }

        return request
    }

    // MARK: - Download

    open func download<Convertible: URLConvertible>(_ convertible: Convertible,
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

    func download<Convertible: URLRequestConvertible>(_ convertible: Convertible,
                                                      to destination: @escaping DownloadRequest.Destination = DownloadRequest.suggestedDownloadDestination()) -> DownloadRequest {
        let request = DownloadRequest(underlyingQueue: rootQueue,
                                      delegate: delegate,
                                      eventMonitor: eventMonitor,
                                      destination: destination)

        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.downloadTask(with: urlRequest)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: nil, error: error)
            }
        }

        return request
    }

    // MARK: - Upload

    struct UploadConvertible<Convertible: URLConvertible>: URLRequestConvertible {
        let url: Convertible
        let method: HTTPMethod
        let headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            return try URLRequest(url: url, method: method, headers: headers)
        }
    }

    func upload<Convertible: URLConvertible>(_ data: Data,
                                             to convertible: Convertible,
                                             method: HTTPMethod = .post,
                                             headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = UploadConvertible(url: convertible, method: method, headers: headers)

        return upload(data: data, to: convertible)
    }

    func upload<Convertible: URLRequestConvertible>(data: Data, to convertible: Convertible) -> UploadRequest {
        let request = UploadRequest(underlyingQueue: rootQueue,
                                    delegate: delegate,
                                    eventMonitor: eventMonitor,
                                    uploadable: .data(data))

        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.uploadTask(with: urlRequest, from: data)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: nil, error: error)
            }
        }

        return request
    }

    func upload<Convertible: URLConvertible>(_ fileURL: URL,
                                             to convertible: Convertible,
                                             method: HTTPMethod = .post,
                                             headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = UploadConvertible(url: convertible, method: method, headers: headers)

        return upload(fileURL, to: convertible)
    }

    func upload<Convertible: URLRequestConvertible>(_ fileURL: URL, to convertible: Convertible) -> UploadRequest {
        let request = UploadRequest(underlyingQueue: rootQueue,
                                    delegate: delegate,
                                    eventMonitor: eventMonitor,
                                    uploadable: .file(fileURL))

        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.uploadTask(with: urlRequest, fromFile: fileURL)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: nil, error: error)
            }
        }

        return request
    }

    func upload<Convertible: URLConvertible>(_ stream: InputStream,
                                             to convertible: Convertible,
                                             method: HTTPMethod = .post,
                                             headers: HTTPHeaders? = nil) -> UploadRequest {
        let convertible = UploadConvertible(url: convertible, method: method, headers: headers)

        return upload(stream, to: convertible)
    }

    func upload<Convertible: URLRequestConvertible>(_ stream: InputStream, to convertible: Convertible) -> UploadRequest {
        let request = UploadRequest(underlyingQueue: rootQueue,
                                    delegate: delegate,
                                    eventMonitor: eventMonitor,
                                    uploadable: .stream(stream))

        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.uploadTask(withStreamedRequest: urlRequest)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: nil, error: error)
            }
        }

        return request
    }
}
