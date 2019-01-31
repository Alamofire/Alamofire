//
//  RequestInterceptor.swift
//
//  Copyright (c) 2019 Alamofire Software Foundation (http://alamofire.org/)
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

/// A type that can inspect and optionally adapt a `URLRequest` in some manner if necessary.
public protocol RequestAdapter {
    /// Inspects and adapts the specified `URLRequest` in some manner and calls the completion handler with the Result.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` to adapt.
    ///   - completion: The completion handler that must be called when adaptation is complete.
    func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest>) -> Void)
}

// MARK: -

/// A type that determines whether a request should be retried after being executed by the specified session manager
/// and encountering an error.
public protocol RequestRetrier {
    /// Determines whether the `Request` should be retried by calling the `completion` closure.
    ///
    /// This operation is fully asynchronous. Any amount of time can be taken to determine whether the request needs
    /// to be retried. The one requirement is that the completion closure is called to ensure the request is properly
    /// cleaned up after.
    ///
    /// - parameter session:    The session the request was executed on.
    /// - parameter request:    The request that failed due to the encountered error.
    /// - parameter error:      The error encountered when executing the request.
    /// - parameter completion: The completion closure to be executed when retry decision has been determined.
    func should(_ session: Session, retry request: Request, with error: Error, completion: @escaping (Result<TimeInterval>) -> Void)
}

// MARK: -

/// A type that intercepts requests to potentially adapt and retry them.
public protocol RequestInterceptor: RequestAdapter, RequestRetrier {}

// MARK: -

open class Interceptor {
    public let adapters: [RequestAdapter]
    public let retriers: [RequestRetrier]

    public init(adapters: [RequestAdapter] = [], retriers: [RequestRetrier] = []) {
        self.adapters = adapters
        self.retriers = retriers
    }
}

// MARK: - RequestAdapter

extension Interceptor: RequestAdapter {
    open func adapt(_ urlRequest: URLRequest, completion: @escaping (_ result: Result<URLRequest>) -> Void) {
        adapt(urlRequest, using: adapters, completion: completion)
    }

    private func adapt(
        _ urlRequest: URLRequest,
        using adapters: [RequestAdapter],
        completion: @escaping (_ result: Result<URLRequest>) -> Void)
    {
        var pendingAdapters = adapters

        guard !pendingAdapters.isEmpty else { completion(.success(urlRequest)); return }

        let adapter = pendingAdapters.removeFirst()

        adapter.adapt(urlRequest) { result in
            switch result {
            case .success(let urlRequest):
                self.adapt(urlRequest, using: pendingAdapters, completion: completion)
            case .failure:
                completion(result)
            }
        }
    }
}

// MARK: - RequestRetrier

extension Interceptor: RequestRetrier {
    open func should(_ session: Session, retry request: Request, with error: Error, completion: @escaping (_ result: Result<TimeInterval>) -> Void) {
        completion(.success(0.0))
        should(session, retry: request, with: error, using: retriers, completion: completion)
    }

    private func should(
        _ session: Session,
        retry request: Request,
        with error: Error,
        using retriers: [RequestRetrier],
        completion: @escaping (_ result: Result<TimeInterval>) -> Void)
    {
        var pendingRetriers = retriers

        guard !pendingRetriers.isEmpty else { completion(.failure(error)); return }

        let retrier = pendingRetriers.removeFirst()

        retrier.should(session, retry: request, with: error) { result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                self.should(session, retry: request, with: error, using: pendingRetriers, completion: completion)
            }
        }
    }
}
