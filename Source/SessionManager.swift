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
    static let `default` = SessionManager()
    
    let configuration: URLSessionConfiguration
    let delegate: SessionDelegate
    let rootQueue: DispatchQueue
    let requestQueue: DispatchQueue
    let adapter: RequestAdapter?
    let retrier: RequestRetrier?
    let trustManager: ServerTrustManager?
    
    let session: URLSession
    
    public init(configuration: URLSessionConfiguration = .default,
                delegate: SessionDelegate = SessionDelegate(),
                rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.sessionManager"),
                requestAdapter: RequestAdapter? = nil,
                trustManager: ServerTrustManager? = nil,
                requestRetrier: RequestRetrier? = nil) {
        self.configuration = configuration
        self.delegate = delegate
        self.rootQueue = rootQueue
        adapter = requestAdapter
        retrier = requestRetrier
        self.trustManager = trustManager
        requestQueue = DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: rootQueue, name: "org.alamofire.sessionManager.sessionDelegateQueue")
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        delegate.didCreate(sessionManager: self)
    }
    
    // MARK: - Request
    
    struct DataConvertible<Convertible: URLConvertible>: URLRequestConvertible {
        let url: Convertible
        let method: HTTPMethod
        let parameters: Parameters?
        let parameterEncoding: ParameterEncoding
        let headers: HTTPHeaders?
        
        func asURLRequest() throws -> URLRequest {
            let request = try URLRequest(url: url, method: method, headers: headers)
            return try parameterEncoding.encode(request, with: parameters)
        }
    }
    
    open func request<Convertible: URLConvertible>(_ url: Convertible,
                                                   method: HTTPMethod = .get,
                                                   parameters: Parameters? = nil,
                                                   parameterEncoding: ParameterEncoding = URLEncoding.default,
                                                   headers: HTTPHeaders? = nil) -> DataRequest {
        let convertible = DataConvertible(url: url,
                                          method: method,
                                          parameters: parameters,
                                          parameterEncoding: parameterEncoding,
                                          headers: headers)
        return request(convertible)
    }
    
    open func request<Convertible: URLRequestConvertible>(_ convertible: Convertible) -> DataRequest {
        let request = DataRequest(underlyingQueue: rootQueue, delegate: delegate)
        
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
    
//    func download<Convertible: URLRequestConvertible>(_ convertible: Convertible) -> DownloadRequest {
//        let request = DownloadRequest(underlyingQueue: rootQueue, delegate: delegate)
//
//        requestQueue.async {
//            do {
//                let initialRequest = try convertible.asURLRequest()
//                let adaptedRequest = try self.adapter?.adapt(initialRequest)
//                let urlRequest = adaptedRequest ?? initialRequest
//                let task = self.session.downloadTask(with: urlRequest)
//                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
//            } catch {
//                request.didFail(with: nil, error: error)
//            }
//        }
//
//        return request
//    }
    
    // MARK: - Upload
    
    func upload<Convertible: URLRequestConvertible>(data: Data, with convertible: Convertible) -> UploadRequest {
        let request = UploadRequest(underlyingQueue: rootQueue, delegate: delegate, uploadable: .data(data))
        
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
    
    func upload<Convertible: URLRequestConvertible>(file fileURL: URL, with convertible: Convertible) -> UploadRequest {
        let request = UploadRequest(underlyingQueue: rootQueue, delegate: delegate, uploadable: .file(fileURL))
        
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
    
    func upload<Convertible: URLRequestConvertible>(stream: InputStream, with convertible: Convertible) -> UploadRequest {
        let request = UploadRequest(underlyingQueue: rootQueue, delegate: delegate, uploadable: .stream(stream))
        
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
