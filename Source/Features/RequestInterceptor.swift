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

/// Stores all state associated with a `URLRequest` being adapted.
public struct RequestAdapterState: Sendable {
    /// The `UUID` of the `Request` associated with the `URLRequest` to adapt.
    public let requestID: UUID

    /// The `Session` associated with the `URLRequest` to adapt.
    public let session: Session
}

// MARK: -

/// A type that can inspect and optionally adapt a `URLRequest` in some manner if necessary.
public protocol RequestAdapter: Sendable {
    /// Inspects and adapts the specified `URLRequest` in some manner and calls the completion handler with the Result.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` to adapt.
    ///   - session:    The `Session` that will execute the `URLRequest`.
    ///   - completion: The completion handler that must be called when adaptation is complete.
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (_ result: Result<URLRequest, any Error>) -> Void)

    /// Inspects and adapts the specified `URLRequest` in some manner and calls the completion handler with the Result.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` to adapt.
    ///   - state:      The `RequestAdapterState` associated with the `URLRequest`.
    ///   - completion: The completion handler that must be called when adaptation is complete.
    func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping @Sendable (_ result: Result<URLRequest, any Error>) -> Void)
}

extension RequestAdapter {
    @preconcurrency
    public func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping @Sendable (_ result: Result<URLRequest, any Error>) -> Void) {
        adapt(urlRequest, for: state.session, completion: completion)
    }
}

// MARK: -

/// Outcome of determination whether retry is necessary.
public enum RetryResult: Sendable {
    /// Retry should be attempted immediately.
    case retry
    /// Retry should be attempted after the associated `TimeInterval`.
    case retryWithDelay(TimeInterval)
    /// Do not retry.
    case doNotRetry
    /// Do not retry due to the associated `Error`.
    case doNotRetryWithError(any Error)
}

extension RetryResult {
    var retryRequired: Bool {
        switch self {
        case .retry, .retryWithDelay: true
        default: false
        }
    }

    var delay: TimeInterval? {
        switch self {
        case let .retryWithDelay(delay): delay
        default: nil
        }
    }

    var error: (any Error)? {
        guard case let .doNotRetryWithError(error) = self else { return nil }
        return error
    }
}

/// A type that determines whether a request should be retried after being executed by the specified session manager
/// and encountering an error.
public protocol RequestRetrier: Sendable {
    /// Determines whether the `Request` should be retried by calling the `completion` closure.
    ///
    /// This operation is fully asynchronous. Any amount of time can be taken to determine whether the request needs
    /// to be retried. The one requirement is that the completion closure is called to ensure the request is properly
    /// cleaned up after.
    ///
    /// - Parameters:
    ///   - request:    `Request` that failed due to the provided `Error`.
    ///   - session:    `Session` that produced the `Request`.
    ///   - error:      `Error` encountered while executing the `Request`.
    ///   - completion: Completion closure to be executed when a retry decision has been determined.
    func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping @Sendable (RetryResult) -> Void)
}

// MARK: -

/// Type that provides both `RequestAdapter` and `RequestRetrier` functionality.
public protocol RequestInterceptor: RequestAdapter, RequestRetrier {}

extension RequestInterceptor {
    @preconcurrency
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        completion(.success(urlRequest))
    }

    @preconcurrency
    public func retry(_ request: Request,
                      for session: Session,
                      dueTo error: any Error,
                      completion: @escaping @Sendable (RetryResult) -> Void) {
        completion(.doNotRetry)
    }
}

/// `RequestAdapter` closure definition.
public typealias AdaptHandler = @Sendable (_ request: URLRequest,
                                           _ session: Session,
                                           _ completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) -> Void

/// `RequestRetrier` closure definition.
public typealias RetryHandler = @Sendable (_ request: Request,
                                           _ session: Session,
                                           _ error: any Error,
                                           _ completion: @escaping @Sendable (RetryResult) -> Void) -> Void

// MARK: -

/// Closure-based `RequestAdapter`.
open class Adapter: @unchecked Sendable, RequestInterceptor {
    private let adaptHandler: AdaptHandler

    /// Creates an instance using the provided closure.
    ///
    /// - Parameter adaptHandler: `AdaptHandler` closure to be executed when handling request adaptation.
    ///
    @preconcurrency
    public init(_ adaptHandler: @escaping AdaptHandler) {
        self.adaptHandler = adaptHandler
    }

    @preconcurrency
    open func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        adaptHandler(urlRequest, session, completion)
    }

    @preconcurrency
    open func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        adaptHandler(urlRequest, state.session, completion)
    }
}

extension RequestAdapter where Self == Adapter {
    /// Creates an `Adapter` using the provided `AdaptHandler` closure.
    ///
    /// - Parameter closure: `AdaptHandler` to use to adapt the request.
    /// - Returns:           The `Adapter`.
    @preconcurrency
    public static func adapter(using closure: @escaping AdaptHandler) -> Adapter {
        Adapter(closure)
    }
}

// MARK: -

/// Closure-based `RequestRetrier`.
open class Retrier: @unchecked Sendable, RequestInterceptor {
    private let retryHandler: RetryHandler

    /// Creates an instance using the provided closure.
    ///
    /// - Parameter retryHandler: `RetryHandler` closure to be executed when handling request retry.
    @preconcurrency
    public init(_ retryHandler: @escaping RetryHandler) {
        self.retryHandler = retryHandler
    }

    @preconcurrency
    open func retry(_ request: Request,
                    for session: Session,
                    dueTo error: any Error,
                    completion: @escaping @Sendable (RetryResult) -> Void) {
        retryHandler(request, session, error, completion)
    }
}

extension RequestRetrier where Self == Retrier {
    /// Creates a `Retrier` using the provided `RetryHandler` closure.
    ///
    /// - Parameter closure: `RetryHandler` to use to retry the request.
    /// - Returns:           The `Retrier`.
    @preconcurrency
    public static func retrier(using closure: @escaping RetryHandler) -> Retrier {
        Retrier(closure)
    }
}

// MARK: -

/// `RequestInterceptor` which can use multiple `RequestAdapter` and `RequestRetrier` values.
open class Interceptor: @unchecked Sendable, RequestInterceptor {
    /// All `RequestAdapter`s associated with the instance. These adapters will be run until one fails.
    public let adapters: [any RequestAdapter]
    /// All `RequestRetrier`s associated with the instance. These retriers will be run one at a time until one triggers retry.
    public let retriers: [any RequestRetrier]

    /// Creates an instance from `AdaptHandler` and `RetryHandler` closures.
    ///
    /// - Parameters:
    ///   - adaptHandler: `AdaptHandler` closure to be used.
    ///   - retryHandler: `RetryHandler` closure to be used.
    public init(adaptHandler: @escaping AdaptHandler, retryHandler: @escaping RetryHandler) {
        adapters = [Adapter(adaptHandler)]
        retriers = [Retrier(retryHandler)]
    }

    /// Creates an instance from `RequestAdapter` and `RequestRetrier` values.
    ///
    /// - Parameters:
    ///   - adapter: `RequestAdapter` value to be used.
    ///   - retrier: `RequestRetrier` value to be used.
    public init(adapter: any RequestAdapter, retrier: any RequestRetrier) {
        adapters = [adapter]
        retriers = [retrier]
    }

    /// Creates an instance from the arrays of `RequestAdapter` and `RequestRetrier` values.
    ///
    /// - Parameters:
    ///   - adapters:     `RequestAdapter` values to be used.
    ///   - retriers:     `RequestRetrier` values to be used.
    ///   - interceptors: `RequestInterceptor`s to be used.
    public init(adapters: [any RequestAdapter] = [],
                retriers: [any RequestRetrier] = [],
                interceptors: [any RequestInterceptor] = []) {
        self.adapters = adapters + interceptors
        self.retriers = retriers + interceptors
    }

    @preconcurrency
    open func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        adapt(urlRequest, for: session, using: adapters, completion: completion)
    }

    private func adapt(_ urlRequest: URLRequest,
                       for session: Session,
                       using adapters: [any RequestAdapter],
                       completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        var pendingAdapters = adapters

        guard !pendingAdapters.isEmpty else { completion(.success(urlRequest)); return }

        let adapter = pendingAdapters.removeFirst()

        adapter.adapt(urlRequest, for: session) { [pendingAdapters] result in
            switch result {
            case let .success(urlRequest):
                self.adapt(urlRequest, for: session, using: pendingAdapters, completion: completion)
            case .failure:
                completion(result)
            }
        }
    }

    @preconcurrency
    open func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        adapt(urlRequest, using: state, adapters: adapters, completion: completion)
    }

    private func adapt(_ urlRequest: URLRequest,
                       using state: RequestAdapterState,
                       adapters: [any RequestAdapter],
                       completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        var pendingAdapters = adapters

        guard !pendingAdapters.isEmpty else { completion(.success(urlRequest)); return }

        let adapter = pendingAdapters.removeFirst()

        adapter.adapt(urlRequest, using: state) { [pendingAdapters] result in
            switch result {
            case let .success(urlRequest):
                self.adapt(urlRequest, using: state, adapters: pendingAdapters, completion: completion)
            case .failure:
                completion(result)
            }
        }
    }

    @preconcurrency
    open func retry(_ request: Request,
                    for session: Session,
                    dueTo error: any Error,
                    completion: @escaping @Sendable (RetryResult) -> Void) {
        retry(request, for: session, dueTo: error, using: retriers, completion: completion)
    }

    private func retry(_ request: Request,
                       for session: Session,
                       dueTo error: any Error,
                       using retriers: [any RequestRetrier],
                       completion: @escaping @Sendable (RetryResult) -> Void) {
        var pendingRetriers = retriers

        guard !pendingRetriers.isEmpty else { completion(.doNotRetry); return }

        let retrier = pendingRetriers.removeFirst()

        retrier.retry(request, for: session, dueTo: error) { [pendingRetriers] result in
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

extension RequestInterceptor where Self == Interceptor {
    /// Creates an `Interceptor` using the provided `AdaptHandler` and `RetryHandler` closures.
    ///
    /// - Parameters:
    ///   - adapter: `AdapterHandler`to use to adapt the request.
    ///   - retrier: `RetryHandler` to use to retry the request.
    /// - Returns:   The `Interceptor`.
    @preconcurrency
    public static func interceptor(adapter: @escaping AdaptHandler, retrier: @escaping RetryHandler) -> Interceptor {
        Interceptor(adaptHandler: adapter, retryHandler: retrier)
    }

    /// Creates an `Interceptor` using the provided `RequestAdapter` and `RequestRetrier` instances.
    /// - Parameters:
    ///   - adapter: `RequestAdapter` to use to adapt the request
    ///   - retrier: `RequestRetrier` to use to retry the request.
    /// - Returns:   The `Interceptor`.
    @preconcurrency
    public static func interceptor(adapter: any RequestAdapter, retrier: any RequestRetrier) -> Interceptor {
        Interceptor(adapter: adapter, retrier: retrier)
    }

    /// Creates an `Interceptor` using the provided `RequestAdapter`s, `RequestRetrier`s, and `RequestInterceptor`s.
    /// - Parameters:
    ///   - adapters:     `RequestAdapter`s to use to adapt the request. These adapters will be run until one fails.
    ///   - retriers:     `RequestRetrier`s to use to retry the request. These retriers will be run one at a time until
    ///                   a retry is triggered.
    ///   - interceptors: `RequestInterceptor`s to use to intercept the request.
    /// - Returns:        The `Interceptor`.
    @preconcurrency
    public static func interceptor(adapters: [any RequestAdapter] = [],
                                   retriers: [any RequestRetrier] = [],
                                   interceptors: [any RequestInterceptor] = []) -> Interceptor {
        Interceptor(adapters: adapters, retriers: retriers, interceptors: interceptors)
    }
}
