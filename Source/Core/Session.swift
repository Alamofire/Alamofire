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

/// `Session` creates and manages Alamofire's `Request` types during their lifetimes. It also provides common
/// functionality for all `Request`s, including queuing, interception, trust management, redirect handling, and response
/// cache handling.
open class Session: @unchecked Sendable {
    /// Shared singleton instance used by all `AF.request` APIs. Cannot be modified.
    public static let `default` = Session()

    /// Underlying `URLSession` used to create `URLSessionTasks` for this instance, and for which this instance's
    /// `delegate` handles `URLSessionDelegate` callbacks.
    ///
    /// - Note: This instance should **NOT** be used to interact with the underlying `URLSessionTask`s. Doing so will
    ///         break internal Alamofire logic that tracks those tasks.
    ///
    public let session: URLSession
    /// Instance's `SessionDelegate`, which handles the `URLSessionDelegate` methods and `Request` interaction.
    public let delegate: SessionDelegate
    /// Root `DispatchQueue` for all internal callbacks and state update. **MUST** be a serial queue.
    public let rootQueue: DispatchQueue
    /// Value determining whether this instance automatically calls `resume()` on all created `Request`s.
    public let startRequestsImmediately: Bool
    /// `DispatchQueue` on which `URLRequest`s are created asynchronously. By default this queue uses `rootQueue` as its
    /// `target`, but a separate queue can be used if request creation is determined to be a bottleneck. Always profile
    /// and test before introducing an additional queue.
    public let requestQueue: DispatchQueue
    /// `DispatchQueue` passed to all `Request`s on which they perform their response serialization. By default this
    /// queue uses `rootQueue` as its `target` but a separate queue can be used if response serialization is determined
    /// to be a bottleneck. Always profile and test before introducing an additional queue.
    public let serializationQueue: DispatchQueue
    /// `RequestInterceptor` used for all `Request` created by the instance. `RequestInterceptor`s can also be set on a
    /// per-`Request` basis, in which case the `Request`'s interceptor takes precedence over this value.
    public let interceptor: (any RequestInterceptor)?
    /// `ServerTrustManager` instance used to evaluate all trust challenges and provide certificate and key pinning.
    public let serverTrustManager: ServerTrustManager?
    /// `RedirectHandler` instance used to provide customization for request redirection.
    public let redirectHandler: (any RedirectHandler)?
    /// `CachedResponseHandler` instance used to provide customization of cached response handling.
    public let cachedResponseHandler: (any CachedResponseHandler)?
    /// `CompositeEventMonitor` used to compose any passed `EventMonitor`s.
    public let eventMonitor: CompositeEventMonitor
    /// `EventMonitor`s included in all instances unless overwritten. `[AlamofireNotifications()]` by default.
    @available(*, deprecated, message: "Use [AlamofireNotifications()] directly.")
    public let defaultEventMonitors: [any EventMonitor] = [AlamofireNotifications()]

    /// Internal map between `Request`s and any `URLSessionTasks` that may be in flight for them.
    var requestTaskMap = RequestTaskMap()
    /// `Set` of currently active `Request`s.
    var activeRequests: Set<Request> = []
    /// Completion events awaiting `URLSessionTaskMetrics`.
    var waitingCompletions: [URLSessionTask: () -> Void] = [:]

    /// Creates a `Session` from a `URLSession` and other parameters.
    ///
    /// - Note: When passing a `URLSession`, you must create the `URLSession` with a specific `delegateQueue` value and
    ///         pass the `delegateQueue`'s `underlyingQueue` as the `rootQueue` parameter of this initializer.
    ///
    /// - Parameters:
    ///   - session:                  Underlying `URLSession` for this instance.
    ///   - delegate:                 `SessionDelegate` that handles `session`'s delegate callbacks as well as `Request`
    ///                               interaction.
    ///   - rootQueue:                Root `DispatchQueue` for all internal callbacks and state updates. **MUST** be a
    ///                               serial queue.
    ///   - startRequestsImmediately: Determines whether this instance will automatically start all `Request`s. `true`
    ///                               by default. If set to `false`, all `Request`s created must have `.resume()` called.
    ///                               on them for them to start.
    ///   - requestQueue:             `DispatchQueue` on which to perform `URLRequest` creation. By default this queue
    ///                               will use the `rootQueue` as its `target`. A separate queue can be used if it's
    ///                               determined request creation is a bottleneck, but that should only be done after
    ///                               careful testing and profiling. `nil` by default.
    ///   - serializationQueue:       `DispatchQueue` on which to perform all response serialization. By default this
    ///                               queue will use the `rootQueue` as its `target`. A separate queue can be used if
    ///                               it's determined response serialization is a bottleneck, but that should only be
    ///                               done after careful testing and profiling. `nil` by default.
    ///   - interceptor:              `RequestInterceptor` to be used for all `Request`s created by this instance. `nil`
    ///                               by default.
    ///   - serverTrustManager:       `ServerTrustManager` to be used for all trust evaluations by this instance. `nil`
    ///                               by default.
    ///   - redirectHandler:          `RedirectHandler` to be used by all `Request`s created by this instance. `nil` by
    ///                               default.
    ///   - cachedResponseHandler:    `CachedResponseHandler` to be used by all `Request`s created by this instance.
    ///                               `nil` by default.
    ///   - eventMonitors:            `EventMonitor`s used by the instance. `[AlamofireNotifications()]` by default.
    public init(session: URLSession,
                delegate: SessionDelegate,
                rootQueue: DispatchQueue,
                startRequestsImmediately: Bool = true,
                requestQueue: DispatchQueue? = nil,
                serializationQueue: DispatchQueue? = nil,
                interceptor: (any RequestInterceptor)? = nil,
                serverTrustManager: ServerTrustManager? = nil,
                redirectHandler: (any RedirectHandler)? = nil,
                cachedResponseHandler: (any CachedResponseHandler)? = nil,
                eventMonitors: [any EventMonitor] = [AlamofireNotifications()]) {
        precondition(session.configuration.identifier == nil,
                     "Alamofire does not support background URLSessionConfigurations.")
        precondition(session.delegateQueue.underlyingQueue === rootQueue,
                     "Session(session:) initializer must be passed the DispatchQueue used as the delegateQueue's underlyingQueue as rootQueue.")

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
        eventMonitor = CompositeEventMonitor(monitors: eventMonitors)
        delegate.eventMonitor = eventMonitor
        delegate.stateProvider = self
    }

    /// Creates a `Session` from a `URLSessionConfiguration`.
    ///
    /// - Note: This initializer lets Alamofire handle the creation of the underlying `URLSession` and its
    ///         `delegateQueue`, and is the recommended initializer for most uses.
    ///
    /// - Parameters:
    ///   - configuration:            `URLSessionConfiguration` to be used to create the underlying `URLSession`. Changes
    ///                               to this value after being passed to this initializer will have no effect.
    ///                               `URLSessionConfiguration.af.default` by default.
    ///   - delegate:                 `SessionDelegate` that handles `session`'s delegate callbacks as well as `Request`
    ///                               interaction. `SessionDelegate()` by default.
    ///   - rootQueue:                Root `DispatchQueue` for all internal callbacks and state updates. **MUST** be a
    ///                               serial queue. `DispatchQueue(label: "org.alamofire.session.rootQueue")` by default.
    ///   - startRequestsImmediately: Determines whether this instance will automatically start all `Request`s. `true`
    ///                               by default. If set to `false`, all `Request`s created must have `.resume()` called.
    ///                               on them for them to start.
    ///   - requestQueue:             `DispatchQueue` on which to perform `URLRequest` creation. By default this queue
    ///                               will use the `rootQueue` as its `target`. A separate queue can be used if it's
    ///                               determined request creation is a bottleneck, but that should only be done after
    ///                               careful testing and profiling. `nil` by default.
    ///   - serializationQueue:       `DispatchQueue` on which to perform all response serialization. By default this
    ///                               queue will use the `rootQueue` as its `target`. A separate queue can be used if
    ///                               it's determined response serialization is a bottleneck, but that should only be
    ///                               done after careful testing and profiling. `nil` by default.
    ///   - interceptor:              `RequestInterceptor` to be used for all `Request`s created by this instance. `nil`
    ///                               by default.
    ///   - serverTrustManager:       `ServerTrustManager` to be used for all trust evaluations by this instance. `nil`
    ///                               by default.
    ///   - redirectHandler:          `RedirectHandler` to be used by all `Request`s created by this instance. `nil` by
    ///                               default.
    ///   - cachedResponseHandler:    `CachedResponseHandler` to be used by all `Request`s created by this instance.
    ///                               `nil` by default.
    ///   - eventMonitors:            `EventMonitor`s used by the instance. `[AlamofireNotifications()]` by default.
    public convenience init(configuration: URLSessionConfiguration = URLSessionConfiguration.af.default,
                            delegate: SessionDelegate = SessionDelegate(),
                            rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.session.rootQueue"),
                            startRequestsImmediately: Bool = true,
                            requestQueue: DispatchQueue? = nil,
                            serializationQueue: DispatchQueue? = nil,
                            interceptor: (any RequestInterceptor)? = nil,
                            serverTrustManager: ServerTrustManager? = nil,
                            redirectHandler: (any RedirectHandler)? = nil,
                            cachedResponseHandler: (any CachedResponseHandler)? = nil,
                            eventMonitors: [any EventMonitor] = [AlamofireNotifications()]) {
        precondition(configuration.identifier == nil, "Alamofire does not support background URLSessionConfigurations.")

        // Retarget the incoming rootQueue for safety, unless it's the main queue, which we know is safe.
        let serialRootQueue = (rootQueue === DispatchQueue.main) ? rootQueue : DispatchQueue(label: rootQueue.label,
                                                                                             target: rootQueue)
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: serialRootQueue, name: "\(serialRootQueue.label).sessionDelegate")
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)

        self.init(session: session,
                  delegate: delegate,
                  rootQueue: serialRootQueue,
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

    // MARK: - All Requests API

    /// Perform an action on all active `Request`s.
    ///
    /// - Note: The provided `action` closure is performed asynchronously, meaning that some `Request`s may complete and
    ///         be unavailable by time it runs. Additionally, this action is performed on the instances's `rootQueue`,
    ///         so care should be taken that actions are fast. Once the work on the `Request`s is complete, any
    ///         additional work should be performed on another queue.
    ///
    /// - Parameters:
    ///   - action:     Closure to perform with all `Request`s.
    public func withAllRequests(perform action: @escaping @Sendable (Set<Request>) -> Void) {
        rootQueue.async {
            action(self.activeRequests)
        }
    }

    /// Cancel all active `Request`s, optionally calling a completion handler when complete.
    ///
    /// - Note: This is an asynchronous operation and does not block the creation of future `Request`s. Cancelled
    ///         `Request`s may not cancel immediately due internal work, and may not cancel at all if they are close to
    ///         completion when cancelled.
    ///
    /// - Parameters:
    ///   - queue:      `DispatchQueue` on which the completion handler is run. `.main` by default.
    ///   - completion: Closure to be called when all `Request`s have been cancelled.
    public func cancelAllRequests(completingOnQueue queue: DispatchQueue = .main, completion: (@Sendable () -> Void)? = nil) {
        withAllRequests { requests in
            requests.forEach { $0.cancel() }
            queue.async {
                completion?()
            }
        }
    }

    // MARK: - DataRequest

    /// Closure which provides a `URLRequest` for mutation.
    public typealias RequestModifier = @Sendable (inout URLRequest) throws -> Void

    struct RequestConvertible: URLRequestConvertible {
        let url: any URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoding: any ParameterEncoding
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?

        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)

            return try encoding.encode(request, with: parameters)
        }
    }

    /// Creates a `DataRequest` from a `URLRequest` created using the passed components and a `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:      `Parameters` (a.k.a. `[String: Any]`) value to be encoded into the `URLRequest`. `nil` by
    ///                      default.
    ///   - encoding:        `ParameterEncoding` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      `URLEncoding.default` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:       The created `DataRequest`.
    open func request(_ convertible: any URLConvertible,
                      method: HTTPMethod = .get,
                      parameters: Parameters? = nil,
                      encoding: any ParameterEncoding = URLEncoding.default,
                      headers: HTTPHeaders? = nil,
                      interceptor: (any RequestInterceptor)? = nil,
                      requestModifier: RequestModifier? = nil) -> DataRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers,
                                             requestModifier: requestModifier)

        return request(convertible, interceptor: interceptor)
    }

    struct RequestEncodableConvertible<Parameters: Encodable & Sendable>: URLRequestConvertible {
        let url: any URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoder: any ParameterEncoder
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?

        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)

            return try parameters.map { try encoder.encode($0, into: request) } ?? request
        }
    }

    /// Creates a `DataRequest` from a `URLRequest` created using the passed components, `Encodable` parameters, and a
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:      `Encodable` value to be encoded into the `URLRequest`. `nil` by default.
    ///   - encoder:         `ParameterEncoder` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      `URLEncodedFormParameterEncoder.default` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from
    ///                      the provided parameters. `nil` by default.
    ///
    /// - Returns:           The created `DataRequest`.
    open func request<Parameters: Encodable & Sendable>(_ convertible: any URLConvertible,
                                                        method: HTTPMethod = .get,
                                                        parameters: Parameters? = nil,
                                                        encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                        headers: HTTPHeaders? = nil,
                                                        interceptor: (any RequestInterceptor)? = nil,
                                                        requestModifier: RequestModifier? = nil) -> DataRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)

        return request(convertible, interceptor: interceptor)
    }

    /// Creates a `DataRequest` from a `URLRequestConvertible` value and a `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///
    /// - Returns:       The created `DataRequest`.
    open func request(_ convertible: any URLRequestConvertible, interceptor: (any RequestInterceptor)? = nil) -> DataRequest {
        let request = DataRequest(convertible: convertible,
                                  underlyingQueue: rootQueue,
                                  serializationQueue: serializationQueue,
                                  eventMonitor: eventMonitor,
                                  interceptor: interceptor,
                                  delegate: self)

        perform(request)

        return request
    }

    // MARK: - DataStreamRequest

    /// Creates a `DataStreamRequest` from the passed components, `Encodable` parameters, and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:                      `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:                           `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:                       `Encodable` value to be encoded into the `URLRequest`. `nil` by default.
    ///   - encoder:                          `ParameterEncoder` to be used to encode the `parameters` value into the
    ///                                       `URLRequest`.
    ///                                       `URLEncodedFormParameterEncoder.default` by default.
    ///   - headers:                          `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance should be canceled when an `Error`
    ///                                       is thrown while serializing stream `Data`. `false` by default.
    ///   - interceptor:                      `RequestInterceptor` value to be used by the returned `DataRequest`. `nil`
    ///                                       by default.
    ///   - requestModifier:                  `RequestModifier` which will be applied to the `URLRequest` created from
    ///                                       the provided parameters. `nil` by default.
    ///
    /// - Returns:       The created `DataStream` request.
    open func streamRequest<Parameters: Encodable & Sendable>(_ convertible: any URLConvertible,
                                                              method: HTTPMethod = .get,
                                                              parameters: Parameters? = nil,
                                                              encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                              headers: HTTPHeaders? = nil,
                                                              automaticallyCancelOnStreamError: Bool = false,
                                                              interceptor: (any RequestInterceptor)? = nil,
                                                              requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)

        return streamRequest(convertible,
                             automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                             interceptor: interceptor)
    }

    /// Creates a `DataStreamRequest` from the passed components and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:                      `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:                           `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - headers:                          `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance should be canceled when an `Error`
    ///                                       is thrown while serializing stream `Data`. `false` by default.
    ///   - interceptor:                      `RequestInterceptor` value to be used by the returned `DataRequest`. `nil`
    ///                                       by default.
    ///   - requestModifier:                  `RequestModifier` which will be applied to the `URLRequest` created from
    ///                                       the provided parameters. `nil` by default.
    ///
    /// - Returns:       The created `DataStream` request.
    open func streamRequest(_ convertible: any URLConvertible,
                            method: HTTPMethod = .get,
                            headers: HTTPHeaders? = nil,
                            automaticallyCancelOnStreamError: Bool = false,
                            interceptor: (any RequestInterceptor)? = nil,
                            requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: Empty?.none,
                                                      encoder: URLEncodedFormParameterEncoder.default,
                                                      headers: headers,
                                                      requestModifier: requestModifier)

        return streamRequest(convertible,
                             automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                             interceptor: interceptor)
    }

    /// Creates a `DataStreamRequest` from the passed `URLRequestConvertible` value and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:                      `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance should be canceled when an `Error`
    ///                                       is thrown while serializing stream `Data`. `false` by default.
    ///   - interceptor:                      `RequestInterceptor` value to be used by the returned `DataRequest`. `nil`
    ///                                        by default.
    ///
    /// - Returns:       The created `DataStreamRequest`.
    open func streamRequest(_ convertible: any URLRequestConvertible,
                            automaticallyCancelOnStreamError: Bool = false,
                            interceptor: (any RequestInterceptor)? = nil) -> DataStreamRequest {
        let request = DataStreamRequest(convertible: convertible,
                                        automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                                        underlyingQueue: rootQueue,
                                        serializationQueue: serializationQueue,
                                        eventMonitor: eventMonitor,
                                        interceptor: interceptor,
                                        delegate: self)

        perform(request)

        return request
    }

    #if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @_spi(WebSocket) open func webSocketRequest(
        to url: any URLConvertible,
        configuration: WebSocketRequest.Configuration = .default,
        headers: HTTPHeaders? = nil,
        interceptor: (any RequestInterceptor)? = nil,
        requestModifier: RequestModifier? = nil
    ) -> WebSocketRequest {
        webSocketRequest(
            to: url,
            configuration: configuration,
            parameters: Empty?.none,
            encoder: URLEncodedFormParameterEncoder.default,
            headers: headers,
            interceptor: interceptor,
            requestModifier: requestModifier
        )
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @_spi(WebSocket) open func webSocketRequest<Parameters>(
        to url: any URLConvertible,
        configuration: WebSocketRequest.Configuration = .default,
        parameters: Parameters? = nil,
        encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
        headers: HTTPHeaders? = nil,
        interceptor: (any RequestInterceptor)? = nil,
        requestModifier: RequestModifier? = nil
    ) -> WebSocketRequest where Parameters: Encodable & Sendable {
        let convertible = RequestEncodableConvertible(url: url,
                                                      method: .get,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)
        let request = WebSocketRequest(convertible: convertible,
                                       configuration: configuration,
                                       underlyingQueue: rootQueue,
                                       serializationQueue: serializationQueue,
                                       eventMonitor: eventMonitor,
                                       interceptor: interceptor,
                                       delegate: self)

        perform(request)

        return request
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @_spi(WebSocket) open func webSocketRequest(performing convertible: any URLRequestConvertible,
                                                configuration: WebSocketRequest.Configuration = .default,
                                                interceptor: (any RequestInterceptor)? = nil) -> WebSocketRequest {
        let request = WebSocketRequest(convertible: convertible,
                                       configuration: configuration,
                                       underlyingQueue: rootQueue,
                                       serializationQueue: serializationQueue,
                                       eventMonitor: eventMonitor,
                                       interceptor: interceptor,
                                       delegate: self)

        perform(request)

        return request
    }
    #endif

    // MARK: - DownloadRequest

    /// Creates a `DownloadRequest` using a `URLRequest` created using the passed components, `RequestInterceptor`, and
    /// `Destination`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:      `Parameters` (a.k.a. `[String: Any]`) value to be encoded into the `URLRequest`. `nil` by
    ///                      default.
    ///   - encoding:        `ParameterEncoding` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      Defaults to `URLEncoding.default`.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///   - destination:     `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                      should be moved. `nil` by default.
    ///
    /// - Returns:           The created `DownloadRequest`.
    open func download(_ convertible: any URLConvertible,
                       method: HTTPMethod = .get,
                       parameters: Parameters? = nil,
                       encoding: any ParameterEncoding = URLEncoding.default,
                       headers: HTTPHeaders? = nil,
                       interceptor: (any RequestInterceptor)? = nil,
                       requestModifier: RequestModifier? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers,
                                             requestModifier: requestModifier)

        return download(convertible, interceptor: interceptor, to: destination)
    }

    /// Creates a `DownloadRequest` from a `URLRequest` created using the passed components, `Encodable` parameters, and
    /// a `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:      Value conforming to `Encodable` to be encoded into the `URLRequest`. `nil` by default.
    ///   - encoder:         `ParameterEncoder` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      Defaults to `URLEncodedFormParameterEncoder.default`.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///   - destination:     `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                      should be moved. `nil` by default.
    ///
    /// - Returns:           The created `DownloadRequest`.
    open func download<Parameters: Encodable & Sendable>(_ convertible: any URLConvertible,
                                                         method: HTTPMethod = .get,
                                                         parameters: Parameters? = nil,
                                                         encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                         headers: HTTPHeaders? = nil,
                                                         interceptor: (any RequestInterceptor)? = nil,
                                                         requestModifier: RequestModifier? = nil,
                                                         to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)

        return download(convertible, interceptor: interceptor, to: destination)
    }

    /// Creates a `DownloadRequest` from a `URLRequestConvertible` value, a `RequestInterceptor`, and a `Destination`.
    ///
    /// - Parameters:
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - destination: `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                  should be moved. `nil` by default.
    ///
    /// - Returns:       The created `DownloadRequest`.
    open func download(_ convertible: any URLRequestConvertible,
                       interceptor: (any RequestInterceptor)? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .request(convertible),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      interceptor: interceptor,
                                      delegate: self,
                                      destination: destination ?? DownloadRequest.defaultDestination)

        perform(request)

        return request
    }

    /// Creates a `DownloadRequest` from the `resumeData` produced from a previously cancelled `DownloadRequest`, as
    /// well as a `RequestInterceptor`, and a `Destination`.
    ///
    /// - Note: If `destination` is not specified, the download will be moved to a temporary location determined by
    ///         Alamofire. The file will not be deleted until the system purges the temporary files.
    ///
    /// - Note: On some versions of all Apple platforms (iOS 10 - 10.2, macOS 10.12 - 10.12.2, tvOS 10 - 10.1, watchOS 3 - 3.1.1),
    /// `resumeData` is broken on background URL session configurations. There's an underlying bug in the `resumeData`
    /// generation logic where the data is written incorrectly and will always fail to resume the download. For more
    /// information about the bug and possible workarounds, please refer to the [this Stack Overflow post](http://stackoverflow.com/a/39347461/1342462).
    ///
    /// - Parameters:
    ///   - data:        The resume data from a previously cancelled `DownloadRequest` or `URLSessionDownloadTask`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - destination: `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                  should be moved. `nil` by default.
    ///
    /// - Returns:       The created `DownloadRequest`.
    open func download(resumingWith data: Data,
                       interceptor: (any RequestInterceptor)? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .resumeData(data),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      interceptor: interceptor,
                                      delegate: self,
                                      destination: destination ?? DownloadRequest.defaultDestination)

        perform(request)

        return request
    }

    // MARK: - UploadRequest

    struct ParameterlessRequestConvertible: URLRequestConvertible {
        let url: any URLConvertible
        let method: HTTPMethod
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?

        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)

            return request
        }
    }

    struct Upload: UploadConvertible {
        let request: any URLRequestConvertible
        let uploadable: any UploadableConvertible

        func createUploadable() throws -> UploadRequest.Uploadable {
            try uploadable.createUploadable()
        }

        func asURLRequest() throws -> URLRequest {
            try request.asURLRequest()
        }
    }

    // MARK: Data

    /// Creates an `UploadRequest` for the given `Data`, `URLRequest` components, and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - data:            The `Data` to upload.
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:     `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                      default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:           The created `UploadRequest`.
    open func upload(_ data: Data,
                     to convertible: any URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)

        return upload(data, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the given `Data` using the `URLRequestConvertible` value and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - data:        The `Data` to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    open func upload(_ data: Data,
                     with convertible: any URLRequestConvertible,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        upload(.data(data), with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: File

    /// Creates an `UploadRequest` for the file at the given file `URL`, using a `URLRequest` from the provided
    /// components and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - fileURL:         The `URL` of the file to upload.
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `UploadRequest`. `nil` by default.
    ///   - fileManager:     `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                      default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:           The created `UploadRequest`.
    open func upload(_ fileURL: URL,
                     to convertible: any URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)

        return upload(fileURL, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the file at the given file `URL` using the `URLRequestConvertible` value and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - fileURL:     The `URL` of the file to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    open func upload(_ fileURL: URL,
                     with convertible: any URLRequestConvertible,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        upload(.file(fileURL, shouldRemove: false), with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: InputStream

    /// Creates an `UploadRequest` from the `InputStream` provided using a `URLRequest` from the provided components and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - stream:          The `InputStream` that provides the data to upload.
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:     `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                      default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:           The created `UploadRequest`.
    open func upload(_ stream: InputStream,
                     to convertible: any URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)

        return upload(stream, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    /// Creates an `UploadRequest` from the provided `InputStream` using the `URLRequestConvertible` value and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - stream:      The `InputStream` that provides the data to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    open func upload(_ stream: InputStream,
                     with convertible: any URLRequestConvertible,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        upload(.stream(stream), with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: MultipartFormData

    /// Creates an `UploadRequest` for the multipart form data built using a closure and sent using the provided
    /// `URLRequest` components and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:      `MultipartFormData` building closure.
    ///   - url:                    `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///   - requestModifier:         `RequestModifier` which will be applied to the `URLRequest` created from the
    ///                              provided parameters. `nil` by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     to url: any URLConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)

        let formData = MultipartFormData(fileManager: fileManager)
        multipartFormData(formData)

        return upload(multipartFormData: formData,
                      with: convertible,
                      usingThreshold: encodingMemoryThreshold,
                      interceptor: interceptor,
                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` using a `MultipartFormData` building closure, the provided `URLRequestConvertible`
    /// value, and a `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` building closure.
    ///   - request:                 `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     with request: any URLRequestConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        let formData = MultipartFormData(fileManager: fileManager)
        multipartFormData(formData)

        return upload(multipartFormData: formData,
                      with: request,
                      usingThreshold: encodingMemoryThreshold,
                      interceptor: interceptor,
                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the prebuilt `MultipartFormData` value using the provided `URLRequest` components
    /// and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` instance to upload.
    ///   - url:                     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///   - requestModifier:         `RequestModifier` which will be applied to the `URLRequest` created from the
    ///                              provided parameters. `nil` by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: MultipartFormData,
                     to url: any URLConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)

        let multipartUpload = MultipartUpload(encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: convertible,
                                              multipartFormData: multipartFormData)

        return upload(multipartUpload, interceptor: interceptor, fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the prebuilt `MultipartFormData` value using the providing `URLRequestConvertible`
    /// value and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` instance to upload.
    ///   - request:                 `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                              default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: MultipartFormData,
                     with request: any URLRequestConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     interceptor: (any RequestInterceptor)? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        let multipartUpload = MultipartUpload(encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: request,
                                              multipartFormData: multipartFormData)

        return upload(multipartUpload, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: - Internal API

    // MARK: Uploadable

    func upload(_ uploadable: UploadRequest.Uploadable,
                with convertible: any URLRequestConvertible,
                interceptor: (any RequestInterceptor)?,
                fileManager: FileManager) -> UploadRequest {
        let uploadable = Upload(request: convertible, uploadable: uploadable)

        return upload(uploadable, interceptor: interceptor, fileManager: fileManager)
    }

    func upload(_ upload: any UploadConvertible, interceptor: (any RequestInterceptor)?, fileManager: FileManager) -> UploadRequest {
        let request = UploadRequest(convertible: upload,
                                    underlyingQueue: rootQueue,
                                    serializationQueue: serializationQueue,
                                    eventMonitor: eventMonitor,
                                    interceptor: interceptor,
                                    fileManager: fileManager,
                                    delegate: self)

        perform(request)

        return request
    }

    // MARK: Perform

    /// Starts performing the provided `Request`.
    ///
    /// - Parameter request: The `Request` to perform.
    func perform(_ request: Request) {
        rootQueue.async {
            guard !request.isCancelled else { return }

            self.activeRequests.insert(request)

            self.requestQueue.async {
                // Leaf types must come first, otherwise they will cast as their superclass.
                switch request {
                case let r as UploadRequest: self.performUploadRequest(r) // UploadRequest must come before DataRequest due to subtype relationship.
                case let r as DataRequest: self.performDataRequest(r)
                case let r as DownloadRequest: self.performDownloadRequest(r)
                case let r as DataStreamRequest: self.performDataStreamRequest(r)
                default:
                    #if canImport(Darwin) && !canImport(FoundationNetworking)
                    if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *),
                       let request = request as? WebSocketRequest {
                        self.performWebSocketRequest(request)
                    } else {
                        fatalError("Attempted to perform unsupported Request subclass: \(type(of: request))")
                    }
                    #else
                    fatalError("Attempted to perform unsupported Request subclass: \(type(of: request))")
                    #endif
                }
            }
        }
    }

    func performDataRequest(_ request: DataRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))

        performSetupOperations(for: request, convertible: request.convertible)
    }

    func performDataStreamRequest(_ request: DataStreamRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))

        performSetupOperations(for: request, convertible: request.convertible)
    }

    #if canImport(Darwin) && !canImport(FoundationNetworking)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func performWebSocketRequest(_ request: WebSocketRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))

        performSetupOperations(for: request, convertible: request.convertible)
    }
    #endif

    func performUploadRequest(_ request: UploadRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))

        performSetupOperations(for: request, convertible: request.convertible) {
            do {
                let uploadable = try request.upload.createUploadable()
                self.rootQueue.async { request.didCreateUploadable(uploadable) }
                return true
            } catch {
                self.rootQueue.async { request.didFailToCreateUploadable(with: error.asAFError(or: .createUploadableFailed(error: error))) }
                return false
            }
        }
    }

    func performDownloadRequest(_ request: DownloadRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))

        switch request.downloadable {
        case let .request(convertible):
            performSetupOperations(for: request, convertible: convertible)
        case let .resumeData(resumeData):
            rootQueue.async { self.didReceiveResumeData(resumeData, for: request) }
        }
    }

    func performSetupOperations(for request: Request,
                                convertible: any URLRequestConvertible,
                                shouldCreateTask: @escaping @Sendable () -> Bool = { true }) {
        dispatchPrecondition(condition: .onQueue(requestQueue))

        let initialRequest: URLRequest

        do {
            initialRequest = try convertible.asURLRequest()
            try initialRequest.validate()
        } catch {
            rootQueue.async { request.didFailToCreateURLRequest(with: error.asAFError(or: .createURLRequestFailed(error: error))) }
            return
        }

        rootQueue.async { request.didCreateInitialURLRequest(initialRequest) }

        guard !request.isCancelled else { return }

        guard let adapter = adapter(for: request) else {
            guard shouldCreateTask() else { return }
            rootQueue.async { self.didCreateURLRequest(initialRequest, for: request) }
            return
        }

        let adapterState = RequestAdapterState(requestID: request.id, session: self)

        adapter.adapt(initialRequest, using: adapterState) { result in
            do {
                let adaptedRequest = try result.get()
                try adaptedRequest.validate()

                self.rootQueue.async { request.didAdaptInitialRequest(initialRequest, to: adaptedRequest) }

                guard shouldCreateTask() else { return }

                self.rootQueue.async { self.didCreateURLRequest(adaptedRequest, for: request) }
            } catch {
                self.rootQueue.async { request.didFailToAdaptURLRequest(initialRequest, withError: .requestAdaptationFailed(error: error)) }
            }
        }
    }

    // MARK: - Task Handling

    func didCreateURLRequest(_ urlRequest: URLRequest, for request: Request) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        request.didCreateURLRequest(urlRequest)

        guard !request.isCancelled else { return }

        let task = request.task(for: urlRequest, using: session)
        requestTaskMap[request] = task
        request.didCreateTask(task)

        updateStatesForTask(task, request: request)
    }

    func didReceiveResumeData(_ data: Data, for request: DownloadRequest) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        guard !request.isCancelled else { return }

        let task = request.task(forResumeData: data, using: session)
        requestTaskMap[request] = task
        request.didCreateTask(task)

        updateStatesForTask(task, request: request)
    }

    func updateStatesForTask(_ task: URLSessionTask, request: Request) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        request.withState { state in
            switch state {
            case .initialized, .finished:
                // Do nothing.
                break
            case .resumed:
                task.resume()
                rootQueue.async { request.didResumeTask(task) }
            case .suspended:
                task.suspend()
                rootQueue.async { request.didSuspendTask(task) }
            case .cancelled:
                // Resume to ensure metrics are gathered.
                task.resume()
                task.cancel()
                rootQueue.async { request.didCancelTask(task) }
            }
        }
    }

    // MARK: - Adapters and Retriers

    func adapter(for request: Request) -> (any RequestAdapter)? {
        if let requestInterceptor = request.interceptor, let sessionInterceptor = interceptor {
            Interceptor(adapters: [requestInterceptor, sessionInterceptor])
        } else {
            request.interceptor ?? interceptor
        }
    }

    func retrier(for request: Request) -> (any RequestRetrier)? {
        if let requestInterceptor = request.interceptor, let sessionInterceptor = interceptor {
            Interceptor(retriers: [requestInterceptor, sessionInterceptor])
        } else {
            request.interceptor ?? interceptor
        }
    }

    // MARK: - Invalidation

    func finishRequestsForDeinit() {
        for request in requestTaskMap.requests {
            rootQueue.async {
                request.finish(error: AFError.sessionDeinitialized)
            }
        }
    }
}

// MARK: - RequestDelegate

extension Session: RequestDelegate {
    public var sessionConfiguration: URLSessionConfiguration {
        session.configuration
    }

    public var startImmediately: Bool { startRequestsImmediately }

    public func cleanup(after request: Request) {
        activeRequests.remove(request)
    }

    public func retryResult(for request: Request, dueTo error: AFError, completion: @escaping @Sendable (RetryResult) -> Void) {
        guard let retrier = retrier(for: request) else {
            rootQueue.async { completion(.doNotRetry) }
            return
        }

        retrier.retry(request, for: self, dueTo: error) { retryResult in
            self.rootQueue.async {
                guard let retryResultError = retryResult.error else { completion(retryResult); return }

                let retryError = AFError.requestRetryFailed(retryError: retryResultError, originalError: error)
                completion(.doNotRetryWithError(retryError))
            }
        }
    }

    public func retryRequest(_ request: Request, withDelay timeDelay: TimeInterval?) {
        rootQueue.async {
            let retry: @Sendable () -> Void = {
                guard !request.isCancelled else { return }

                request.prepareForRetry()
                self.perform(request)
            }

            if let retryDelay = timeDelay {
                self.rootQueue.after(retryDelay) { retry() }
            } else {
                retry()
            }
        }
    }
}

// MARK: - SessionStateProvider

extension Session: SessionStateProvider {
    func request(for task: URLSessionTask) -> Request? {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        return requestTaskMap[task]
    }

    func didGatherMetricsForTask(_ task: URLSessionTask) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        let didDisassociate = requestTaskMap.disassociateIfNecessaryAfterGatheringMetricsForTask(task)

        if didDisassociate {
            waitingCompletions[task]?()
            waitingCompletions[task] = nil
        }
    }

    func didCompleteTask(_ task: URLSessionTask, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        let didDisassociate = requestTaskMap.disassociateIfNecessaryAfterCompletingTask(task)

        if didDisassociate {
            completion()
        } else {
            waitingCompletions[task] = completion
        }
    }

    func credential(for task: URLSessionTask, in protectionSpace: URLProtectionSpace) -> URLCredential? {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        return requestTaskMap[task]?.credential ??
            session.configuration.urlCredentialStorage?.defaultCredential(for: protectionSpace)
    }

    func cancelRequestsForSessionInvalidation(with error: (any Error)?) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        requestTaskMap.requests.forEach { $0.finish(error: AFError.sessionInvalidated(error: error)) }
    }
}
