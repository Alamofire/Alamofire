//
//  Request.swift
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

/// `Request` is the common superclass of all Alamofire request types and provides common state, delegate, and callback
/// handling.
public class Request {
    /// State of the `Request`, with managed transitions between states set when calling `resume()`, `suspend()`, or
    /// `cancel()` on the `Request`.
    ///
    /// - initialized: Initial state of the `Request`.
    /// - resumed:   Set when `resume()` is called. Any tasks created for the `Request` will have `resume()` called on
    ///              them in this state.
    /// - suspended: Set when `suspend()` is called. Any tasks created for the `Request` will have `suspend()` called on
    ///              them in this state.
    /// - cancelled: Set when `cancel()` is called. Any tasks created for the `Request` will have `cancel()` called on
    ///              them. Unlike `resumed` or `suspended`, once in the `cancelled` state, the `Request` can no longer
    ///              transition to any other state.
    /// - finished:  Set when all response serialization completion closures have been cleared on the `Request` and
    ///              queued on their respective queues.
    public enum State {
        case initialized, resumed, suspended, cancelled, finished

        /// Determines whether `self` can be transitioned to `state`.
        func canTransitionTo(_ state: State) -> Bool {
            switch (self, state) {
            case (.initialized, _):
                return true
            case (_, .initialized), (.cancelled, _), (.finished, _):
                return false
            case (.resumed, .cancelled), (.suspended, .cancelled), (.resumed, .suspended), (.suspended, .resumed):
                return true
            case (.suspended, .suspended), (.resumed, .resumed):
                return false
            case (_, .finished):
                return true
            }
        }
    }

    // MARK: - Initial State

    /// `UUID` prividing a unique identifier for the `Request`, used in the `Hashable` and `Equatable` conformances.
    public let id: UUID
    /// The serial queue for all internal async actions.
    public let underlyingQueue: DispatchQueue
    /// The queue used for all serialization actions. By default it's a serial queue that targets `underlyingQueue`.
    public let serializationQueue: DispatchQueue
    /// `EventMonitor` used for event callbacks.
    public let eventMonitor: EventMonitor?
    /// The `Request`'s interceptor.
    public let interceptor: RequestInterceptor?
    /// The `Request`'s delegate.
    public private(set) weak var delegate: RequestDelegate?

    // MARK: - Updated State

    /// Type encapsulating all mutable state that may need to be accessed from anything other than the `underlyingQueue`.
    struct MutableState {
        /// State of the `Request`.
        var state: State = .initialized
        /// `ProgressHandler` and `DispatchQueue` provided for upload progress callbacks.
        var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
        /// `ProgressHandler` and `DispatchQueue` provided for download progress callbacks.
        var downloadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
        /// `RetryHandler` provided for redirect responses.
        var redirectHandler: RedirectHandler?
        /// `CachedResponseHandler` provided to handle caching responses.
        var cachedResponseHandler: CachedResponseHandler?
        /// Response serialization closures that handle parsing responses.
        var responseSerializers: [() -> Void] = []
        /// Response serialization completion closures executed once all response serialization is complete.
        var responseSerializerCompletions: [() -> Void] = []
        /// Whether response serializer processing is finished.
        var responseSerializerProcessingFinished = false
        /// `URLCredential` used for authentication challenges.
        var credential: URLCredential?
        /// All `URLRequest`s created by Alamofire on behalf of the `Request`.
        var requests: [URLRequest] = []
        /// All `URLSessionTask`s created by Alamofire on behalf of the `Request`.
        var tasks: [URLSessionTask] = []
        /// All `URLSessionTaskMetrics` values gathered by Alamofire on behalf of the `Request`. Should correspond
        /// exactly the the `tasks` created.
        var metrics: [URLSessionTaskMetrics] = []
        /// Number of times any retriers provided retried the `Request`.
        var retryCount = 0
        /// Final `Error` for the `Request`, whether from various internal Alamofire calls or as a result of a `task`.
        var error: Error?
    }

    /// Protected `MutableState` value that provides threadsafe access to state values.
    fileprivate let protectedMutableState: Protector<MutableState> = Protector(MutableState())

    /// `State` of the `Request`.
    public var state: State { return protectedMutableState.directValue.state }
    /// Returns whether `state` is `.initialized`.
    public var isInitialized: Bool { return state == .initialized }
    /// Returns whether `state is `.resumed`.
    public var isResumed: Bool { return state == .resumed }
    /// Returns whether `state` is `.suspended`.
    public var isSuspended: Bool { return state == .suspended }
    /// Returns whether `state` is `.cancelled`.
    public var isCancelled: Bool { return state == .cancelled }
    /// Returns whether `state` is `.finished`.
    public var isFinished: Bool { return state == .finished }

    // Progress

    /// Closure type executed when monitoring the upload or download progress of a request.
    public typealias ProgressHandler = (Progress) -> Void

    /// `Progress` of the upload of the body of the executed `URLRequest`. Reset to `0` if the `Request` is retried.
    public let uploadProgress = Progress(totalUnitCount: 0)
    /// `Progress` of the download of any response data. Reset to `0` if the `Request` is retried.
    public let downloadProgress = Progress(totalUnitCount: 0)
    /// `ProgressHandler` called when `uploadProgress` is updated, on the provided `DispatchQueue`.
    fileprivate var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)? {
        get { return protectedMutableState.directValue.uploadProgressHandler }
        set { protectedMutableState.write { $0.uploadProgressHandler = newValue } }
    }
    /// `ProgressHandler` called when `downloadProgress` is updated, on the provided `DispatchQueue`.
    fileprivate var downloadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)? {
        get { return protectedMutableState.directValue.downloadProgressHandler }
        set { protectedMutableState.write { $0.downloadProgressHandler = newValue } }
    }

    // Redirects

    public private(set) var redirectHandler: RedirectHandler? {
        get { return protectedMutableState.directValue.redirectHandler }
        set { protectedMutableState.write { $0.redirectHandler = newValue } }
    }

    // Cached Responses

    public private(set) var cachedResponseHandler: CachedResponseHandler? {
        get { return protectedMutableState.directValue.cachedResponseHandler }
        set { protectedMutableState.write { $0.cachedResponseHandler = newValue } }
    }

    // Credential

    /// `URLCredential` used for authentication challenges. Created by calling one of the `authenticate` methods.
    public private(set) var credential: URLCredential? {
        get { return protectedMutableState.directValue.credential }
        set { protectedMutableState.write { $0.credential = newValue } }
    }

    // Validators

    /// `Validator` callback closures that store the validation calls enqueued.
    fileprivate var protectedValidators: Protector<[() -> Void]> = Protector([])

    // Requests

    /// All `URLRequests` created on behalf of the `Request`, including original and adapted requests.
    public var requests: [URLRequest] { return protectedMutableState.directValue.requests }
    /// First `URLRequest` created on behalf of the `Request`. May not be the first one actually executed.
    public var firstRequest: URLRequest? { return requests.first }
    /// Last `URLRequest` created on behalf of the `Request`.
    public var lastRequest: URLRequest? { return requests.last }
    /// Current `URLRequest` created on behalf of the `Request`.
    public var request: URLRequest? { return lastRequest }

    /// `URLRequest`s from all of the `URLSessionTask`s executed on behalf of the `Request`.
    public var performedRequests: [URLRequest] {
        return protectedMutableState.read { $0.tasks.compactMap { $0.currentRequest } }
    }

    // Response

    /// `HTTPURLResponse` received from the server, if any. If the `Request` was retried, this is the response of the
    /// last `URLSessionTask`.
    public var response: HTTPURLResponse? { return lastTask?.response as? HTTPURLResponse }

    // Tasks

    /// All `URLSessionTask`s created on behalf of the `Request`.
    public var tasks: [URLSessionTask] { return protectedMutableState.directValue.tasks }
    /// First `URLSessionTask` created on behalf of the `Request`.
    public var firstTask: URLSessionTask? { return tasks.first }
    /// Last `URLSessionTask` crated on behalf of the `Request`.
    public var lastTask: URLSessionTask? { return tasks.last }
    /// Current `URLSessionTask` created on behalf of the `Request`.
    public var task: URLSessionTask? { return lastTask }

    // Metrics

    /// All `URLSessionTaskMetrics` gathered on behalf of the `Request`. Should correspond to the `tasks` created.
    public var allMetrics: [URLSessionTaskMetrics] { return protectedMutableState.directValue.metrics }
    /// First `URLSessionTaskMetrics` gathered on behalf of the `Request`.
    public var firstMetrics: URLSessionTaskMetrics? { return allMetrics.first }
    /// Last `URLSessionTaskMetrics` gathered on behalf of the `Request`.
    public var lastMetrics: URLSessionTaskMetrics? { return allMetrics.last }
    /// Current `URLSessionTaskMetrics` gathered on behalf of the `Request`.
    public var metrics: URLSessionTaskMetrics? { return lastMetrics }

    /// Number of times the `Request` has been retried.
    public var retryCount: Int { return protectedMutableState.directValue.retryCount }

    /// `Error` returned from Alamofire internally, from the network request directly, or any validators executed.
    fileprivate(set) public var error: Error? {
        get { return protectedMutableState.directValue.error }
        set { protectedMutableState.write { $0.error = newValue } }
    }

    /// Default initializer for the `Request` superclass.
    ///
    /// - Parameters:
    ///   - id:                 `UUID` used for the `Hashable` and `Equatable` implementations. Defaults to a random `UUID`.
    ///   - underlyingQueue:    `DispatchQueue` on which all internal `Request` work is performed.
    ///   - serializationQueue: `DispatchQueue` on which all serialization work is performed. Targets the
    ///                         `underlyingQueue` when created by a `SessionManager`.
    ///   - eventMonitor:       `EventMonitor` used for event callbacks from internal `Request` actions.
    ///   - interceptor:        `RequestInterceptor` used throughout the request lifecycle.
    ///   - delegate:           `RequestDelegate` that provides an interface to actions not performed by the `Request`.
    public init(id: UUID = UUID(),
                underlyingQueue: DispatchQueue,
                serializationQueue: DispatchQueue,
                eventMonitor: EventMonitor?,
                interceptor: RequestInterceptor?,
                delegate: RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        self.serializationQueue = serializationQueue
        self.eventMonitor = eventMonitor
        self.interceptor = interceptor
        self.delegate = delegate
    }

    // MARK: - Internal API
    // Called from underlyingQueue.

    /// Called when a `URLRequest` has been created on behalf of the `Request`.
    ///
    /// - Parameter request: `URLRequest` created.
    func didCreateURLRequest(_ request: URLRequest) {
        protectedMutableState.write { $0.requests.append(request) }

        eventMonitor?.request(self, didCreateURLRequest: request)
    }

    /// Called when initial `URLRequest` creation has failed, typically through a `URLRequestConvertible`. Triggers retry.
    ///
    /// - Parameter error: `Error` thrown from the failed creation.
    func didFailToCreateURLRequest(with error: Error) {
        self.error = error

        eventMonitor?.request(self, didFailToCreateURLRequestWithError: error)

        retryOrFinish(error: error)
    }

    /// Called when a `RequestAdapter` has successfully adapted a `URLRequest`.
    ///
    /// - Parameters:
    ///   - initialRequest: The `URLRequest` that was adapted.
    ///   - adaptedRequest: The `URLRequest` returned by the `RequestAdapter`.
    func didAdaptInitialRequest(_ initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        protectedMutableState.write { $0.requests.append(adaptedRequest) }

        eventMonitor?.request(self, didAdaptInitialRequest: initialRequest, to: adaptedRequest)
    }

    /// Called when a `RequestAdapter` fails to adapt a `URLRequest`. Triggers retry.
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` the adapter was called with.
    ///   - error:   The `Error` returned by the `RequestAdapter`.
    func didFailToAdaptURLRequest(_ request: URLRequest, withError error: Error) {
        self.error = error

        eventMonitor?.request(self, didFailToAdaptURLRequest: request, withError: error)

        retryOrFinish(error: error)
    }

    /// Called when a `URLSessionTask` is created on behalf of the `Request`.
    ///
    /// - Parameter task: The `URLSessionTask` created.
    func didCreateTask(_ task: URLSessionTask) {
        protectedMutableState.write { $0.tasks.append(task) }

        eventMonitor?.request(self, didCreateTask: task)
    }

    /// Called when resumption is completed.
    func didResume() {
        eventMonitor?.requestDidResume(self)
    }

    /// Called when a `URLSessionTask` is resumed on behalf of the instance.
    func didResumeTask(_ task: URLSessionTask) {
        eventMonitor?.request(self, didResumeTask: task)
    }

    /// Called when suspension is completed.
    func didSuspend() {
        eventMonitor?.requestDidSuspend(self)
    }

    /// Callend when a `URLSessionTask` is suspended on behalf of the instance.
    func didSuspendTask(_ task: URLSessionTask) {
        eventMonitor?.request(self, didSuspendTask: task)
    }

    /// Called when cancellation is completed, sets `error` to `AFError.explicitlyCancelled`.
    func didCancel() {
        error = AFError.explicitlyCancelled

        eventMonitor?.requestDidCancel(self)
    }

    /// Called when a `URLSessionTask` is cancelled on behalf of the instance.
    func didCancelTask(_ task: URLSessionTask) {
        eventMonitor?.request(self, didCancelTask: task)
    }

    /// Called when a `URLSessionTaskMetrics` value is gathered on behalf of the `Request`.
    func didGatherMetrics(_ metrics: URLSessionTaskMetrics) {
        protectedMutableState.write { $0.metrics.append(metrics) }

        eventMonitor?.request(self, didGatherMetrics: metrics)
    }

    /// Called when a `URLSessionTask` fails before it is finished, typically during certificate pinning.
    func didFailTask(_ task: URLSessionTask, earlyWithError error: Error) {
        self.error = error

        // Task will still complete, so didCompleteTask(_:with:) will handle retry.
        eventMonitor?.request(self, didFailTask: task, earlyWithError: error)
    }

    /// Called when a `URLSessionTask` completes. All tasks will eventually call this method.
    func didCompleteTask(_ task: URLSessionTask, with error: Error?) {
        self.error = self.error ?? error
        protectedValidators.directValue.forEach { $0() }

        eventMonitor?.request(self, didCompleteTask: task, with: error)

        retryOrFinish(error: self.error)
    }

    /// Called when the `RequestDelegate` is going to retry this `Request`. Calls `reset()`.
    func prepareForRetry() {
        protectedMutableState.write { $0.retryCount += 1 }

        reset()

        eventMonitor?.requestIsRetrying(self)
    }

    /// Called to trigger retry or finish this `Request`.
    func retryOrFinish(error: Error?) {
        guard let error = error, let delegate = delegate else { finish(); return }

        delegate.retryResult(for: self, dueTo: error) { retryResult in
            switch retryResult {
            case .doNotRetry, .doNotRetryWithError:
                self.finish(error: retryResult.error)
            case .retry, .retryWithDelay:
                delegate.retryRequest(self, withDelay: retryResult.delay)
            }
        }
    }

    /// Finishes this `Request` and starts the response serializers.
    func finish(error: Error? = nil) {
        if let error = error { self.error = error }

        // Start response handlers
        processNextResponseSerializer()

        eventMonitor?.requestDidFinish(self)
    }

    /// Appends the response serialization closure to the `Request`.
    func appendResponseSerializer(_ closure: @escaping () -> Void) {
        protectedMutableState.write { mutableState in
            mutableState.responseSerializers.append(closure)

            if mutableState.state == .finished {
                mutableState.error = AFError.responseSerializationFailed(reason: .responseSerializerAddedAfterRequestFinished)
            }

            if mutableState.responseSerializerProcessingFinished {
                underlyingQueue.async { self.processNextResponseSerializer() }
            }
        }
    }

    /// Returns the next response serializer closure to execute if there's one left.
    func nextResponseSerializer() -> (() -> Void)? {
        var responseSerializer: (() -> Void)?

        protectedMutableState.write { mutableState in
            let responseSerializerIndex = mutableState.responseSerializerCompletions.count

            if responseSerializerIndex < mutableState.responseSerializers.count {
                responseSerializer = mutableState.responseSerializers[responseSerializerIndex]
            }
        }

        return responseSerializer
    }

    /// Processes the next response serializer and calls all completions if response serialization is complete.
    func processNextResponseSerializer() {
        guard let responseSerializer = nextResponseSerializer() else {
            // Execute all response serializer completions and clear them
            var completions: [() -> Void] = []

            protectedMutableState.write { mutableState in
                completions = mutableState.responseSerializerCompletions

                // Clear out all response serializers and response serializer completions in mutable state since the
                // request is complete. It's important to do this prior to calling the completion closures in case
                // the completions call back into the request triggering a re-processing of the response serializers.
                // An example of how this can happen is by calling cancel inside a response completion closure.
                mutableState.responseSerializers.removeAll()
                mutableState.responseSerializerCompletions.removeAll()

                if mutableState.state.canTransitionTo(.finished) {
                    mutableState.state = .finished
                }

                mutableState.responseSerializerProcessingFinished = true
            }

            completions.forEach { $0() }

            // Cleanup the request
            cleanup()

            return
        }

        serializationQueue.async { responseSerializer() }
    }

    /// Notifies the `Request` that the response serializer is complete.
    func responseSerializerDidComplete(completion: @escaping () -> Void) {
        protectedMutableState.write { $0.responseSerializerCompletions.append(completion) }
        processNextResponseSerializer()
    }

    /// Resets all task and response serializer related state for retry.
    func reset() {
        error = nil

        uploadProgress.totalUnitCount = 0
        uploadProgress.completedUnitCount = 0
        downloadProgress.totalUnitCount = 0
        downloadProgress.completedUnitCount = 0

        protectedMutableState.write { $0.responseSerializerCompletions = [] }
    }

    /// Called when updating the upload progress.
    func updateUploadProgress(totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        uploadProgress.totalUnitCount = totalBytesExpectedToSend
        uploadProgress.completedUnitCount = totalBytesSent

        uploadProgressHandler?.queue.async { self.uploadProgressHandler?.handler(self.uploadProgress) }
    }
    
    /// Perform a closure on the current `state` while locked.
    ///
    /// - Parameter perform: The closure to perform.
    func withState(perform: (State) -> Void) {
        protectedMutableState.withState(perform: perform)
    }

    // MARK: Task Creation

    /// Called when creating a `URLSessionTask` for this `Request`. Subclasses must override.
    func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        fatalError("Subclasses must override.")
    }

    // MARK: - Public API

    // These APIs are callable from any queue.

    // MARK: - State

    /// Cancels the `Request`. Once cancelled, a `Request` can no longer be resumed or suspended.
    ///
    /// - Returns: The `Request`.
    @discardableResult
    public func cancel() -> Self {
        protectedMutableState.write { (mutableState) in
            guard mutableState.state.canTransitionTo(.cancelled) else { return }
            
            mutableState.state = .cancelled
            
            underlyingQueue.async { self.didCancel() }
            
            guard let task = mutableState.tasks.last, task.state != .completed else {
                underlyingQueue.async { self.finish() }
                return
            }
            
            task.cancel()
            underlyingQueue.async { self.didCancelTask(task) }
        }

        return self
    }

    /// Suspends the `Request`.
    ///
    /// - Returns: The `Request`.
    @discardableResult
    public func suspend() -> Self {
        protectedMutableState.write { (mutableState) in
            guard mutableState.state.canTransitionTo(.suspended) else { return }
            
            mutableState.state = .suspended
            
            underlyingQueue.async { self.didSuspend() }
            
            guard let task = mutableState.tasks.last, task.state != .completed else { return }
            
            task.suspend()
            underlyingQueue.async { self.didSuspendTask(task) }
        }

        return self
    }


    /// Resumes the `Request`.
    ///
    /// - Returns: The `Request`.
    @discardableResult
    public func resume() -> Self {
        protectedMutableState.write { (mutableState) in
            guard mutableState.state.canTransitionTo(.resumed) else { return }
            
            mutableState.state = .resumed
            
            underlyingQueue.async { self.didResume() }
            
            guard let task = mutableState.tasks.last, task.state != .completed else { return }
            
            task.resume()
            underlyingQueue.async { self.didResumeTask(task) }
        }

        return self
    }

    // MARK: - Closure API

    /// Associates a credential using the provided values with the `Request`.
    ///
    /// - Parameters:
    ///   - username:    The username.
    ///   - password:    The password.
    ///   - persistence: The `URLCredential.Persistence` for the created `URLCredential`.
    /// - Returns:       The `Request`.
    @discardableResult
    public func authenticate(username: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Self {
        let credential = URLCredential(user: username, password: password, persistence: persistence)

        return authenticate(with: credential)
    }

    /// Associates the provided credential with the `Request`.
    ///
    /// - Parameter credential: The `URLCredential`.
    /// - Returns:              The `Request`.
    @discardableResult
    public func authenticate(with credential: URLCredential) -> Self {
        protectedMutableState.write { $0.credential = credential }

        return self
    }

    /// Sets a closure to be called periodically during the lifecycle of the `Request` as data is read from the server.
    ///
    /// Only the last closure provided is used.
    ///
    /// - Parameters:
    ///   - queue:   The `DispatchQueue` to execute the closure on. Defaults to `.main`.
    ///   - closure: The code to be executed periodically as data is read from the server.
    /// - Returns:   The `Request`.
    @discardableResult
    public func downloadProgress(queue: DispatchQueue = .main, closure: @escaping ProgressHandler) -> Self {
        protectedMutableState.write { $0.downloadProgressHandler = (handler: closure, queue: queue) }

        return self
    }

    /// Sets a closure to be called periodically during the lifecycle of the `Request` as data is sent to the server.
    ///
    /// Only the last closure provided is used.
    ///
    /// - Parameters:
    ///   - queue:   The `DispatchQueue` to execute the closure on. Defaults to `.main`.
    ///   - closure: The closure to be executed periodically as data is sent to the server.
    /// - Returns:   The `Request`.
    @discardableResult
    public func uploadProgress(queue: DispatchQueue = .main, closure: @escaping ProgressHandler) -> Self {
        protectedMutableState.write { $0.uploadProgressHandler = (handler: closure, queue: queue) }

        return self
    }

    // MARK: - Redirects

    /// Sets the redirect handler for the `Request` which will be used if a redirect response is encountered.
    ///
    /// - Parameter handler: The `RedirectHandler`.
    /// - Returns:           The `Request`.
    @discardableResult
    public func redirect(using handler: RedirectHandler) -> Self {
        protectedMutableState.write { mutableState in
            precondition(mutableState.redirectHandler == nil, "Redirect handler has already been set")
            mutableState.redirectHandler = handler
        }

        return self
    }

    // MARK: - Cached Responses

    /// Sets the cached response handler for the `Request` which will be used when attempting to cache a response.
    ///
    /// - Parameter handler: The `CachedResponseHandler`.
    /// - Returns:           The `Request`.
    @discardableResult
    public func cacheResponse(using handler: CachedResponseHandler) -> Self {
        protectedMutableState.write { mutableState in
            precondition(mutableState.cachedResponseHandler == nil, "Cached response handler has already been set")
            mutableState.cachedResponseHandler = handler
        }

        return self
    }

    // MARK: - Cleanup

    /// Final cleanup step executed when a `Request` finishes response serialization.
    open func cleanup() {
        // No-op: override in subclass
    }
}

// MARK: - Protocol Conformances

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Request: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Request: CustomStringConvertible {
    /// A textual representation of this instance, including the `HTTPMethod` and `URL` if the `URLRequest` has been
    /// created, as well as the response status code, if a response has been received.
    public var description: String {
        guard let request = performedRequests.last ?? lastRequest,
            let url = request.url,
            let method = request.httpMethod else { return "No request created yet." }

        let requestDescription = "\(method) \(url.absoluteString)"

        return response.map { "\(requestDescription) (\($0.statusCode))" } ?? requestDescription
    }
}

extension Request: CustomDebugStringConvertible {
    /// A textual representation of this instance in the form of a cURL command.
    public var debugDescription: String {
        return cURLRepresentation()
    }

    func cURLRepresentation() -> String {
        guard
            let request = lastRequest,
            let url = request.url,
            let host = url.host,
            let method = request.httpMethod else { return "$ curl command could not be created" }

        var components = ["$ curl -v"]

        components.append("-X \(method)")

        if let credentialStorage = delegate?.sessionConfiguration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: url.port ?? 0,
                protocol: url.scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )

            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    guard let user = credential.user, let password = credential.password else { continue }
                    components.append("-u \(user):\(password)")
                }
            } else {
                if let credential = credential, let user = credential.user, let password = credential.password {
                    components.append("-u \(user):\(password)")
                }
            }
        }

        if let configuration = delegate?.sessionConfiguration, configuration.httpShouldSetCookies {
            if
                let cookieStorage = configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty
            {
                let allCookies = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: ";")

                components.append("-b \"\(allCookies)\"")
            }
        }

        var headers: [String: String] = [:]

        if let additionalHeaders = delegate?.sessionConfiguration.httpAdditionalHeaders as? [String: String] {
            for (field, value) in additionalHeaders where field != "Cookie" {
                headers[field] = value
            }
        }

        if let headerFields = request.allHTTPHeaderFields {
            for (field, value) in headerFields where field != "Cookie" {
                headers[field] = value
            }
        }

        for (field, value) in headers {
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(field): \(escapedValue)\"")
        }

        if let httpBodyData = request.httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")

            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(url.absoluteString)\"")

        return components.joined(separator: " \\\n\t")
    }
}

/// Protocol abstraction for `Request`'s communication back to the `SessionDelegate`.
public protocol RequestDelegate: AnyObject {
    var sessionConfiguration: URLSessionConfiguration { get }

    func retryResult(for request: Request, dueTo error: Error, completion: @escaping (RetryResult) -> Void)
    func retryRequest(_ request: Request, withDelay timeDelay: TimeInterval?)
}

// MARK: - Subclasses

// MARK: DataRequest

public class DataRequest: Request {
    public let convertible: URLRequestConvertible

    private var protectedData: Protector<Data?> = Protector(nil)
    public var data: Data? { return protectedData.directValue }

    init(id: UUID = UUID(),
         convertible: URLRequestConvertible,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: EventMonitor?,
         interceptor: RequestInterceptor?,
         delegate: RequestDelegate) {
        self.convertible = convertible

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   delegate: delegate)
    }

    override func reset() {
        super.reset()

        protectedData.directValue = nil
    }

    func didReceive(data: Data) {
        if self.data == nil {
            protectedData.directValue = data
        } else {
            protectedData.append(data)
        }

        updateDownloadProgress()
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        let copiedRequest = request
        return session.dataTask(with: copiedRequest)
    }

    func updateDownloadProgress() {
        let totalBytesRecieved = Int64(data?.count ?? 0)
        let totalBytesExpected = task?.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown

        downloadProgress.totalUnitCount = totalBytesExpected
        downloadProgress.completedUnitCount = totalBytesRecieved

        downloadProgressHandler?.queue.async { self.downloadProgressHandler?.handler(self.downloadProgress) }
    }

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validator: () -> Void = { [unowned self] in
            guard self.error == nil, let response = self.response else { return }

            let result = validation(self.request, response, self.data)

            if case .failure(let error) = result { self.error = error }

            self.eventMonitor?.request(self,
                                       didValidateRequest: self.request,
                                       response: response,
                                       data: self.data,
                                       withResult: result)
        }

        protectedValidators.append(validator)

        return self
    }
}

public class DownloadRequest: Request {
    /// A collection of options to be executed prior to moving a downloaded file from the temporary URL to the
    /// destination URL.
    public struct Options: OptionSet {
        /// A `DownloadOptions` flag that creates intermediate directories for the destination URL if specified.
        public static let createIntermediateDirectories = Options(rawValue: 1 << 0)

        /// A `DownloadOptions` flag that removes a previous file from the destination URL if specified.
        public static let removePreviousFile = Options(rawValue: 1 << 1)

        /// Returns the raw bitmask value of the option and satisfies the `RawRepresentable` protocol.
        public let rawValue: Int

        /// Creates a `DownloadRequest.Options` instance with the specified raw value.
        ///
        /// - parameter rawValue: The raw bitmask value for the option.
        ///
        /// - returns: A new `DownloadRequest.Options` instance.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// A closure executed once a download request has successfully completed in order to determine where to move the
    /// temporary file written to during the download process. The closure takes two arguments: the temporary file URL
    /// and the URL response, and returns a two arguments: the file URL where the temporary file should be moved and
    /// the options defining how the file should be moved.
    public typealias Destination = (_ temporaryURL: URL,
                                    _ response: HTTPURLResponse) -> (destinationURL: URL, options: Options)

    // MARK: Destination

    /// Creates a download file destination closure which uses the default file manager to move the temporary file to a
    /// file URL in the first available directory with the specified search path directory and search path domain mask.
    ///
    /// - parameter directory: The search path directory. `.documentDirectory` by default.
    /// - parameter domain:    The search path domain mask. `.userDomainMask` by default.
    ///
    /// - returns: A download file destination closure.
    public class func suggestedDownloadDestination(for directory: FileManager.SearchPathDirectory = .documentDirectory,
                                                   in domain: FileManager.SearchPathDomainMask = .userDomainMask,
                                                   options: Options = []) -> Destination {
        return { temporaryURL, response in
            let directoryURLs = FileManager.default.urls(for: directory, in: domain)
            let url = directoryURLs.first?.appendingPathComponent(response.suggestedFilename!) ?? temporaryURL

            return (url, options)
        }
    }

    static let defaultDestination: Destination = { (url, _) in
        let filename = "Alamofire_\(url.lastPathComponent)"
        let destination = url.deletingLastPathComponent().appendingPathComponent(filename)

        return (destination, [])
    }

    public enum Downloadable {
        case request(URLRequestConvertible)
        case resumeData(Data)
    }

    // MARK: Initial State
    public let downloadable: Downloadable
    let destination: Destination?

    // MARK: Updated State

    private struct DownloadRequestMutableState {
        var resumeData: Data?
        var fileURL: URL?
    }

    private let protectedDownloadMutableState: Protector<DownloadRequestMutableState> = Protector(DownloadRequestMutableState())

    public var resumeData: Data? { return protectedDownloadMutableState.directValue.resumeData }
    public var fileURL: URL? { return protectedDownloadMutableState.directValue.fileURL }

    // MARK: Init

    init(id: UUID = UUID(),
         downloadable: Downloadable,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: EventMonitor?,
         interceptor: RequestInterceptor?,
         delegate: RequestDelegate,
         destination: Destination? = nil) {
        self.downloadable = downloadable
        self.destination = destination

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   delegate: delegate)
    }

    override func reset() {
        super.reset()

        protectedDownloadMutableState.write { $0.resumeData = nil }
        protectedDownloadMutableState.write { $0.fileURL = nil }
    }

    func didFinishDownloading(using task: URLSessionTask, with result: AFResult<URL>) {
        eventMonitor?.request(self, didFinishDownloadingUsing: task, with: result)

        switch result {
        case .success(let url):   protectedDownloadMutableState.write { $0.fileURL = url }
        case .failure(let error): self.error = error
        }
    }

    func updateDownloadProgress(bytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadProgress.totalUnitCount = totalBytesExpectedToWrite
        downloadProgress.completedUnitCount += bytesWritten

        downloadProgressHandler?.queue.async { self.downloadProgressHandler?.handler(self.downloadProgress) }
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        return session.downloadTask(with: request)
    }

    public func task(forResumeData data: Data, using session: URLSession) -> URLSessionTask {
        return session.downloadTask(withResumeData: data)
    }

    @discardableResult
    public override func cancel() -> Self {
        protectedMutableState.write { (mutableState) in
            guard mutableState.state.canTransitionTo(.cancelled) else { return }
            
            mutableState.state = .cancelled
            
            underlyingQueue.async { self.didCancel() }
            
            guard let task = mutableState.tasks.last as? URLSessionDownloadTask, task.state != .completed else {
                underlyingQueue.async { self.finish() }
                return
            }
            
            task.cancel { (resumeData) in
                self.protectedDownloadMutableState.write { $0.resumeData = resumeData }
                self.underlyingQueue.async { self.didCancelTask(task) }
            }
        }

        return self
    }

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validator: () -> Void = { [unowned self] in
            guard self.error == nil, let response = self.response else { return }

            let result = validation(self.request, response, self.fileURL)

            if case .failure(let error) = result { self.error = error }

            self.eventMonitor?.request(self,
                                       didValidateRequest: self.request,
                                       response: response,
                                       fileURL: self.fileURL,
                                       withResult: result)
        }

        protectedValidators.append(validator)

        return self
    }
}

public class UploadRequest: DataRequest {
    public enum Uploadable {
        case data(Data)
        case file(URL, shouldRemove: Bool)
        case stream(InputStream)
    }

    // MARK: - Initial State

    public let upload: UploadableConvertible

    // MARK: - Updated State

    public var uploadable: Uploadable?

    init(id: UUID = UUID(),
         convertible: UploadConvertible,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: EventMonitor?,
         interceptor: RequestInterceptor?,
         delegate: RequestDelegate) {
        self.upload = convertible

        super.init(id: id,
                   convertible: convertible,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   delegate: delegate)
    }

    func didCreateUploadable(_ uploadable: Uploadable) {
        self.uploadable = uploadable

        eventMonitor?.request(self, didCreateUploadable: uploadable)
    }

    func didFailToCreateUploadable(with error: Error) {
        self.error = error

        eventMonitor?.request(self, didFailToCreateUploadableWithError: error)

        retryOrFinish(error: error)
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        guard let uploadable = uploadable else {
            fatalError("Attempting to create a URLSessionUploadTask when Uploadable value doesn't exist.")
        }

        switch uploadable {
        case let .data(data): return session.uploadTask(with: request, from: data)
        case let .file(url, _): return session.uploadTask(with: request, fromFile: url)
        case .stream: return session.uploadTask(withStreamedRequest: request)
        }
    }

    func inputStream() -> InputStream {
        guard let uploadable = uploadable else {
            fatalError("Attempting to access the input stream but the uploadable doesn't exist.")
        }

        guard case let .stream(stream) = uploadable else {
            fatalError("Attempted to access the stream of an UploadRequest that wasn't created with one.")
        }

        eventMonitor?.request(self, didProvideInputStream: stream)

        return stream
    }

    public override func cleanup() {
        super.cleanup()

        guard
            let uploadable = self.uploadable,
            case let .file(url, shouldRemove) = uploadable,
            shouldRemove
        else { return }

        // TODO: Abstract file manager
        try? FileManager.default.removeItem(at: url)
    }
}

public protocol UploadableConvertible {
    func createUploadable() throws -> UploadRequest.Uploadable
}

extension UploadRequest.Uploadable: UploadableConvertible {
    public func createUploadable() throws -> UploadRequest.Uploadable {
        return self
    }
}

public protocol UploadConvertible: UploadableConvertible & URLRequestConvertible { }
