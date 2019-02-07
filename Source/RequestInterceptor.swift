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
    ///   - session:    The `Session` that will execute the `URLRequest`.
    ///   - completion: The completion handler that must be called when adaptation is complete.
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest>) -> Void)
}

// MARK: -

public enum RetryResult {
    case retry
    case retryWithDelay(TimeInterval)
    case doNotRetry
    case doNotRetryWithError(Error)
}

extension RetryResult {
    var retryRequired: Bool {
        switch self {
        case .retry, .retryWithDelay: return true
        default:                      return false
        }
    }

    var delay: TimeInterval? {
        switch self {
        case .retryWithDelay(let delay): return delay
        default:                         return nil
        }
    }

    var error: Error? {
        guard case .doNotRetryWithError(let error) = self else { return nil }
        return error
    }
}

/// A type that determines whether a request should be retried after being executed by the specified session manager
/// and encountering an error.
public protocol RequestRetrier {
    /// Determines whether the `Request` should be retried by calling the `completion` closure.
    ///
    /// This operation is fully asynchronous. Any amount of time can be taken to determine whether the request needs
    /// to be retried. The one requirement is that the completion closure is called to ensure the request is properly
    /// cleaned up after.
    ///
    /// - parameter request:    The `Request` that failed due to the encountered error.
    /// - parameter session:    The `Session` the request was executed on.
    /// - parameter error:      The `Error` encountered when executing the request.
    /// - parameter completion: The completion closure to be executed when retry decision has been determined.
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void)
}

// MARK: -

/// A type that intercepts requests to potentially adapt and retry them.
public protocol RequestInterceptor: RequestAdapter, RequestRetrier {}

extension RequestInterceptor {
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest>) -> Void) {
        completion(.success(urlRequest))
    }

    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void)
    {
        completion(.doNotRetry)
    }
}

public typealias AdaptHandler = (URLRequest, Session, _ completion: (Result<URLRequest>) -> Void) -> Void
public typealias RetryHandler = (Request, Session, Error, _ completion: (RetryResult) -> Void) -> Void

// MARK: -

open class Adapter: RequestInterceptor {
    private let adaptHandler: AdaptHandler

    public init(_ adaptHandler: @escaping AdaptHandler) {
        self.adaptHandler = adaptHandler
    }

    open func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest>) -> Void) {
        adaptHandler(urlRequest, session, completion)
    }
}

// MARK: -

open class Retrier: RequestInterceptor {
    private let retryHandler: RetryHandler

    public init(_ retryHandler: @escaping RetryHandler) {
        self.retryHandler = retryHandler
    }

    open func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void)
    {
        retryHandler(request, session, error, completion)
    }
}

// MARK: -

open class Interceptor: RequestInterceptor {
    public let adapters: [RequestAdapter]
    public let retriers: [RequestRetrier]

    public init(adaptHandler: @escaping AdaptHandler, retryHandler: @escaping RetryHandler) {
        self.adapters = [Adapter(adaptHandler)]
        self.retriers = [Retrier(retryHandler)]
    }

    public init(adapter: RequestAdapter, retrier: RequestRetrier) {
        self.adapters = [adapter]
        self.retriers = [retrier]
    }

    public init(adapters: [RequestAdapter] = [], retriers: [RequestRetrier] = []) {
        self.adapters = adapters
        self.retriers = retriers
    }

    open func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest>) -> Void) {
        adapt(urlRequest, for: session, using: adapters, completion: completion)
    }

    private func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        using adapters: [RequestAdapter],
        completion: @escaping (Result<URLRequest>) -> Void)
    {
        var pendingAdapters = adapters

        guard !pendingAdapters.isEmpty else { completion(.success(urlRequest)); return }

        let adapter = pendingAdapters.removeFirst()

        adapter.adapt(urlRequest, for: session) { result in
            switch result {
            case .success(let urlRequest):
                self.adapt(urlRequest, for: session, using: pendingAdapters, completion: completion)
            case .failure:
                completion(result)
            }
        }
    }

    open func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void)
    {
        retry(request, for: session, dueTo: error, using: retriers, completion: completion)
    }

    private func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        using retriers: [RequestRetrier],
        completion: @escaping (RetryResult) -> Void)
    {
        var pendingRetriers = retriers

        guard !pendingRetriers.isEmpty else { completion(.doNotRetry); return }

        let retrier = pendingRetriers.removeFirst()

        retrier.retry(request, for: session, dueTo: error) { result in
            switch result {
            case .retry, .retryWithDelay, .doNotRetryWithError:
                completion(result)
            case .doNotRetry:
                // Only continue to the next retrier if retry was not triggered and no error was encountered
                self.retry(request, for: session, dueTo: error, using: pendingRetriers, completion: completion)
            }
        }
    }
}
