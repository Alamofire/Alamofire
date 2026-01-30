//
//  Request.swift
//
//  Copyright (c) 2014-2024 Alamofire Software Foundation (http://alamofire.org/)
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
public class Request: @unchecked Sendable {
    /// State of the `Request`, with managed transitions between states set when calling `resume()`, `suspend()`, or
    /// `cancel()` on the `Request`.
    public enum State {
        /// Initial state of the `Request`.
        case initialized
        /// `State` set when `resume()` is called. Any tasks created for the `Request` will have `resume()` called on
        /// them in this state.
        case resumed
        /// `State` set when `suspend()` is called. Any tasks created for the `Request` will have `suspend()` called on
        /// them in this state.
        case suspended
        /// `State` set when `cancel()` is called. Any tasks created for the `Request` will have `cancel()` called on
        /// them. Unlike `resumed` or `suspended`, once in the `cancelled` state, the `Request` can no longer transition
        /// to any other state.
        case cancelled
        /// `State` set when all response serialization completion closures have been cleared on the `Request` and
        /// enqueued on their respective queues.
        case finished

        /// Determines whether `self` can be transitioned to the provided `State`.
        func canTransitionTo(_ state: State) -> Bool {
            switch (self, state) {
            case (.initialized, _):
                true
            case (_, .initialized), (.cancelled, _), (.finished, _):
                false
            case (.resumed, .cancelled), (.suspended, .cancelled), (.resumed, .suspended), (.suspended, .resumed):
                true
            case (.suspended, .suspended), (.resumed, .resumed):
                false
            case (_, .finished):
                true
            }
        }
    }

    // MARK: - Initial State

    /// `UUID` providing a unique identifier for the `Request`, used in the `Hashable` and `Equatable` conformances.
    public let id: UUID
    /// The serial queue for all internal async actions.
    public let underlyingQueue: DispatchQueue
    /// The queue used for all serialization actions. By default it's a serial queue that targets `underlyingQueue`.
    public let serializationQueue: DispatchQueue
    /// `EventMonitor` used for event callbacks.
    public var eventMonitor: (any EventMonitor)? {
        mutableState.read(\.eventMonitor)
    }

    /// The `Request`'s interceptor.
    public var interceptor: (any RequestInterceptor)? {
        mutableState.read(\.interceptor)
    }

    /// Whether the instance should call `resume()` automatically once the first response handler has been added.
    /// Overrides the same setting from `Session`, if set. `nil` by default (defers to the `Session`).
    public let shouldAutomaticallyResume: Bool?
    /// The `Request`'s delegate.
    public private(set) weak var delegate: (any RequestDelegate)?

    // MARK: - Mutable State

    /// Type encapsulating all mutable state that may need to be accessed from anything other than the `underlyingQueue`.
    struct MutableState {
        /// State of the `Request`.
        var state: State = .initialized
        /// `ProgressHandler` and `DispatchQueue` provided for upload progress callbacks.
        var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
        /// `ProgressHandler` and `DispatchQueue` provided for download progress callbacks.
        var downloadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
        /// `RedirectHandler` provided for to handle request redirection.
        var redirectHandler: (any RedirectHandler)?
        /// `CachedResponseHandler` provided to handle response caching.
        var cachedResponseHandler: (any CachedResponseHandler)?
        /// Queue and closure called when the `Request` is able to create a cURL description of itself.
        var cURLHandler: (queue: DispatchQueue, handler: @Sendable (String) -> Void)?
        /// Queue and closure called when the `Request` creates a `URLRequest`.
        var urlRequestHandler: (queue: DispatchQueue, handler: @Sendable (URLRequest) -> Void)?
        /// Queue and closure called when the `Request` creates a `URLSessionTask`.
        var urlSessionTaskHandler: (queue: DispatchQueue, handler: @Sendable (URLSessionTask) -> Void)?
        /// Response serialization closures that handle response parsing.
        var responseSerializers: [@Sendable () -> Void] = []
        /// Whether a serializer has been enqueued for execution. Ensure only one can be enqueued at a time.
        /// Should be set back to false only when the serializer has completed successfully or will be retried.
        var isResponseSerializerEnqueued = false
        /// Response serialization completion closures for successful serializers, executed once all response serializers are complete.
        var responseSerializerCompletions: [@Sendable () -> Void] = []
        /// Whether response serializer processing is finished.
        var responseSerializerProcessingFinished = false
        /// Instance's `EventMonitor`. Receives only `Request`-level events.
        var eventMonitor: (any EventMonitor)?
        /// Instance's `RequestInterceptor` composed of the `Session`'s interceptor and any added to the instance.
        var interceptor: (any RequestInterceptor)?
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
        /// Final `AFError` for the `Request`, whether from various internal Alamofire calls or as a result of a `task`.
        var error: AFError?
        /// Whether the instance has had `finish()` called and is running the serializers. Should be replaced with a
        /// representation in the state machine in the future.
        var isFinishing = false
        /// Actions to run when requests are finished. Use for concurrency support.
        var finishHandlers: [() -> Void] = []
    }

    /// Protected `MutableState` value that provides thread-safe access to state values.
    let mutableState: Protected<MutableState>

    /// `State` of the `Request`.
    public var state: State { mutableState.read(\.state) }
    /// Returns whether `state` is `.initialized`.
    public var isInitialized: Bool { state == .initialized }
    /// Returns whether `state` is `.resumed`.
    public var isResumed: Bool { state == .resumed }
    /// Returns whether `state` is `.suspended`.
    public var isSuspended: Bool { state == .suspended }
    /// Returns whether `state` is `.cancelled`.
    public var isCancelled: Bool { state == .cancelled }
    /// Returns whether `state` is `.finished`.
    public var isFinished: Bool { state == .finished }

    // MARK: Progress

    /// Closure type executed when monitoring the upload or download progress of a request.
    public typealias ProgressHandler = @Sendable (_ progress: Progress) -> Void

    /// `Progress` of the upload of the body of the executed `URLRequest`. Reset to `0` if the `Request` is retried.
    public let uploadProgress = Progress(totalUnitCount: 0)
    /// `Progress` of the download of any response data. Reset to `0` if the `Request` is retried.
    public let downloadProgress = Progress(totalUnitCount: 0)
    /// `ProgressHandler` called when `uploadProgress` is updated, on the provided `DispatchQueue`.
    public internal(set) var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)? {
        get { mutableState.read(\.uploadProgressHandler) }
        set { mutableState.write { $0.uploadProgressHandler = newValue } }
    }

    /// `ProgressHandler` called when `downloadProgress` is updated, on the provided `DispatchQueue`.
    public internal(set) var downloadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)? {
        get { mutableState.read(\.downloadProgressHandler) }
        set { mutableState.write { $0.downloadProgressHandler = newValue } }
    }

    // MARK: Redirect Handling

    /// `RedirectHandler` set on the instance.
    public internal(set) var redirectHandler: (any RedirectHandler)? {
        get { mutableState.read(\.redirectHandler) }
        set { mutableState.write { $0.redirectHandler = newValue } }
    }

    // MARK: Cached Response Handling

    /// `CachedResponseHandler` set on the instance.
    public internal(set) var cachedResponseHandler: (any CachedResponseHandler)? {
        get { mutableState.read(\.cachedResponseHandler) }
        set { mutableState.write { $0.cachedResponseHandler = newValue } }
    }

    // MARK: URLCredential

    /// `URLCredential` used for authentication challenges. Created by calling one of the `authenticate` methods.
    public internal(set) var credential: URLCredential? {
        get { mutableState.read(\.credential) }
        set { mutableState.write { $0.credential = newValue } }
    }

    // MARK: Validators

    /// `Validator` callback closures that store the validation calls enqueued.
    let validators = Protected<[@Sendable () -> Void]>([])

    // MARK: URLRequests

    /// All `URLRequest`s created on behalf of the `Request`, including original and adapted requests.
    public var requests: [URLRequest] { mutableState.read(\.requests) }
    /// First `URLRequest` created on behalf of the `Request`. May not be the first one actually executed.
    public var firstRequest: URLRequest? { requests.first }
    /// Last `URLRequest` created on behalf of the `Request`.
    public var lastRequest: URLRequest? { requests.last }
    /// Current `URLRequest` created on behalf of the `Request`.
    public var request: URLRequest? { lastRequest }

    /// `URLRequest`s from all of the `URLSessionTask`s executed on behalf of the `Request`. May be different from
    /// `requests` due to `URLSession` manipulation.
    public var performedRequests: [URLRequest] { mutableState.read { $0.tasks.compactMap(\.currentRequest) } }

    // MARK: HTTPURLResponse

    /// `HTTPURLResponse` received from the server, if any. If the `Request` was retried, this is the response of the
    /// last `URLSessionTask`.
    public var response: HTTPURLResponse? { lastTask?.response as? HTTPURLResponse }

    // MARK: Tasks

    /// All `URLSessionTask`s created on behalf of the `Request`.
    public var tasks: [URLSessionTask] { mutableState.read(\.tasks) }
    /// First `URLSessionTask` created on behalf of the `Request`.
    public var firstTask: URLSessionTask? { tasks.first }
    /// Last `URLSessionTask` created on behalf of the `Request`.
    public var lastTask: URLSessionTask? { tasks.last }
    /// Current `URLSessionTask` created on behalf of the `Request`.
    public var task: URLSessionTask? { lastTask }

    // MARK: Metrics

    /// All `URLSessionTaskMetrics` gathered on behalf of the `Request`. Should correspond to the `tasks` created.
    public var allMetrics: [URLSessionTaskMetrics] { mutableState.read(\.metrics) }
    /// First `URLSessionTaskMetrics` gathered on behalf of the `Request`.
    public var firstMetrics: URLSessionTaskMetrics? { allMetrics.first }
    /// Last `URLSessionTaskMetrics` gathered on behalf of the `Request`.
    public var lastMetrics: URLSessionTaskMetrics? { allMetrics.last }
    /// Current `URLSessionTaskMetrics` gathered on behalf of the `Request`.
    public var metrics: URLSessionTaskMetrics? { lastMetrics }

    // MARK: Retry Count

    /// Number of times the `Request` has been retried.
    public var retryCount: Int { mutableState.read(\.retryCount) }

    // MARK: Error

    /// `Error` returned from Alamofire internally, from the network request directly, or any validators executed.
    public internal(set) var error: AFError? {
        get { mutableState.read(\.error) }
        set { mutableState.write { $0.error = newValue } }
    }

    /// Default initializer for the `Request` superclass.
    ///
    /// - Parameters:
    ///   - id:                        `UUID` used for the `Hashable` and `Equatable` implementations. `UUID()` by default.
    ///   - underlyingQueue:           `DispatchQueue` on which all internal `Request` work is performed.
    ///   - serializationQueue:        `DispatchQueue` on which all serialization work is performed. By default targets
    ///                                `underlyingQueue`, but can be passed another queue from a `Session`.
    ///   - eventMonitor:              `EventMonitor` called for event callbacks from internal `Request` actions.
    ///   - interceptor:               `RequestInterceptor` used throughout the request lifecycle.
    ///   - shouldAutomaticallyResume: Whether the instance should resume after the first response handler is added.
    ///   - delegate:                  `RequestDelegate` that provides an interface to actions not performed by the `Request`.
    init(id: UUID = UUID(),
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: (any EventMonitor)?,
         interceptor: (any RequestInterceptor)?,
         shouldAutomaticallyResume: Bool?,
         delegate: any RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        self.serializationQueue = serializationQueue
        mutableState = Protected(MutableState(eventMonitor: eventMonitor,
                                              interceptor: interceptor))
        self.shouldAutomaticallyResume = shouldAutomaticallyResume
        self.delegate = delegate
    }

    // MARK: - Internal Event API

    // All API must be called from underlyingQueue.

    /// Called when an initial `URLRequest` has been created on behalf of the instance. If a `RequestAdapter` is active,
    /// the `URLRequest` will be adapted before being issued.
    ///
    /// - Parameter request: The `URLRequest` created.
    func didCreateInitialURLRequest(_ request: URLRequest) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { $0.requests.append(request) }

        eventMonitor?.request(self, didCreateInitialURLRequest: request)
    }

    /// Called when initial `URLRequest` creation has failed, typically through a `URLRequestConvertible`.
    ///
    /// - Note: Triggers retry.
    ///
    /// - Parameter error: `AFError` thrown from the failed creation.
    func didFailToCreateURLRequest(with error: AFError) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        self.error = error

        eventMonitor?.request(self, didFailToCreateURLRequestWithError: error)

        callCURLHandlerIfNecessary()

        retryOrFinish(error: error)
    }

    /// Called when a `RequestAdapter` has successfully adapted a `URLRequest`.
    ///
    /// - Parameters:
    ///   - initialRequest: The `URLRequest` that was adapted.
    ///   - adaptedRequest: The `URLRequest` returned by the `RequestAdapter`.
    func didAdaptInitialRequest(_ initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { $0.requests.append(adaptedRequest) }

        eventMonitor?.request(self, didAdaptInitialRequest: initialRequest, to: adaptedRequest)
    }

    /// Called when a `RequestAdapter` fails to adapt a `URLRequest`.
    ///
    /// - Note: Triggers retry.
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` the adapter was called with.
    ///   - error:   The `AFError` returned by the `RequestAdapter`.
    func didFailToAdaptURLRequest(_ request: URLRequest, withError error: AFError) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        self.error = error

        eventMonitor?.request(self, didFailToAdaptURLRequest: request, withError: error)

        callCURLHandlerIfNecessary()

        retryOrFinish(error: error)
    }

    /// Final `URLRequest` has been created for the instance.
    ///
    /// - Parameter request: The `URLRequest` created.
    func didCreateURLRequest(_ request: URLRequest) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.read { state in
            guard let urlRequestHandler = state.urlRequestHandler else { return }

            urlRequestHandler.queue.async { urlRequestHandler.handler(request) }
        }

        eventMonitor?.request(self, didCreateURLRequest: request)

        callCURLHandlerIfNecessary()
    }

    /// Asynchronously calls any stored `cURLHandler` and then removes it from `mutableState`.
    private func callCURLHandlerIfNecessary() {
        mutableState.write { mutableState in
            guard let cURLHandler = mutableState.cURLHandler else { return }

            cURLHandler.queue.async { cURLHandler.handler(self.cURLDescription()) }

            mutableState.cURLHandler = nil
        }
    }

    /// Called when a `URLSessionTask` is created on behalf of the instance.
    ///
    /// - Parameter task: The `URLSessionTask` created.
    func didCreateTask(_ task: URLSessionTask) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { state in
            state.tasks.append(task)

            guard let urlSessionTaskHandler = state.urlSessionTaskHandler else { return }

            urlSessionTaskHandler.queue.async { urlSessionTaskHandler.handler(task) }
        }

        eventMonitor?.request(self, didCreateTask: task)
    }

    /// Called when resumption is completed.
    func didResume() {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        eventMonitor?.requestDidResume(self)
    }

    /// Called when a `URLSessionTask` is resumed on behalf of the instance.
    ///
    /// - Parameter task: The `URLSessionTask` resumed.
    func didResumeTask(_ task: URLSessionTask) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        eventMonitor?.request(self, didResumeTask: task)
    }

    /// Called when suspension is completed.
    func didSuspend() {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        eventMonitor?.requestDidSuspend(self)
    }

    /// Called when a `URLSessionTask` is suspended on behalf of the instance.
    ///
    /// - Parameter task: The `URLSessionTask` suspended.
    func didSuspendTask(_ task: URLSessionTask) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        eventMonitor?.request(self, didSuspendTask: task)
    }

    /// Called when cancellation is completed, sets `error` to `AFError.explicitlyCancelled`.
    func didCancel() {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { mutableState in
            mutableState.error = mutableState.error ?? AFError.explicitlyCancelled
        }

        eventMonitor?.requestDidCancel(self)
    }

    /// Called when a `URLSessionTask` is cancelled on behalf of the instance.
    ///
    /// - Parameter task: The `URLSessionTask` cancelled.
    func didCancelTask(_ task: URLSessionTask) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        eventMonitor?.request(self, didCancelTask: task)
    }

    /// Called when a `URLSessionTaskMetrics` value is gathered on behalf of the instance.
    ///
    /// - Parameter metrics: The `URLSessionTaskMetrics` gathered.
    func didGatherMetrics(_ metrics: URLSessionTaskMetrics) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { $0.metrics.append(metrics) }

        eventMonitor?.request(self, didGatherMetrics: metrics)
    }

    /// Called when a `URLSessionTask` fails before it is finished, typically during certificate pinning.
    ///
    /// - Parameters:
    ///   - task:  The `URLSessionTask` which failed.
    ///   - error: The early failure `AFError`.
    func didFailTask(_ task: URLSessionTask, earlyWithError error: AFError) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        self.error = error

        // Task will still complete, so didCompleteTask(_:with:) will handle retry.
        eventMonitor?.request(self, didFailTask: task, earlyWithError: error)
    }

    /// Called when a `URLSessionTask` completes. All tasks will eventually call this method.
    ///
    /// - Note: Response validation is synchronously triggered in this step.
    ///
    /// - Parameters:
    ///   - task:  The `URLSessionTask` which completed.
    ///   - error: The `AFError` `task` may have completed with. If `error` has already been set on the instance, this
    ///            value is ignored.
    func didCompleteTask(_ task: URLSessionTask, with error: AFError?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { $0.error = $0.error ?? error }

        let validators = validators.read(\.self)
        validators.forEach { $0() }

        eventMonitor?.request(self, didCompleteTask: task, with: error)

        retryOrFinish(error: self.error)
    }

    /// Called when the `RequestDelegate` is going to retry this `Request`. Calls `reset()`.
    func prepareForRetry() {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { $0.retryCount += 1 }

        reset()

        eventMonitor?.requestIsRetrying(self)
    }

    /// Called to determine whether retry will be triggered for the particular error, or whether the instance should
    /// call `finish()`.
    ///
    /// - Parameter error: The possible `AFError` which may trigger retry.
    func retryOrFinish(error: AFError?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        guard !isCancelled, let error, let delegate else { finish(); return }

        delegate.retryResult(for: self, dueTo: error) { retryResult in
            switch retryResult {
            case .doNotRetry:
                self.finish()
            case let .doNotRetryWithError(retryError):
                self.finish(error: retryError.asAFError(orFailWith: "Received retryError was not already AFError"))
            case .retry, .retryWithDelay:
                delegate.retryRequest(self, withDelay: retryResult.delay)
            }
        }
    }

    /// Finishes this `Request` and starts the response serializers.
    ///
    /// - Parameter error: The possible `Error` with which the instance will finish.
    func finish(error: AFError? = nil) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        let shouldStartResponseSerializers = mutableState.write { mutableState in
            guard !mutableState.isFinishing else { return false }

            mutableState.isFinishing = true

            if let error { mutableState.error = error }

            return true
        }

        guard shouldStartResponseSerializers else { return }

        // Start response handlers
        processNextResponseSerializer()

        eventMonitor?.requestDidFinish(self)
    }

    /// Appends the response serialization closure to the instance.
    ///
    ///  - Note: This method will also `resume` the instance if `delegate.startImmediately` returns `true`.
    ///
    /// - Parameter closure: The closure containing the response serialization call.
    func appendResponseSerializer(_ closure: @escaping @Sendable () -> Void) {
        mutableState.write { mutableState in
            mutableState.responseSerializers.append(closure)

            if mutableState.state == .finished {
                mutableState.state = .resumed
            }

            // If serializers have already been processed, execute the added serializer immediately.
            if mutableState.responseSerializerProcessingFinished {
                underlyingQueue.async { self.processNextResponseSerializer() }
            }

            if mutableState.state.canTransitionTo(.resumed) {
                underlyingQueue.async { [self] in
                    if (shouldAutomaticallyResume ?? delegate?.startImmediately) == true {
                        resume()
                    }
                }
            }
        }
    }

    /// Processes the next response serializer and calls all completions if response serialization is complete.
    func processNextResponseSerializer() {
        let executeOutside: (() -> Void)? = mutableState.write { mutableState in
            guard !mutableState.isResponseSerializerEnqueued else { return nil }

            let responseSerializerIndex = mutableState.responseSerializerCompletions.count
            let isAvailableSerializer = responseSerializerIndex < mutableState.responseSerializers.count
            let responseSerializer = isAvailableSerializer ? mutableState.responseSerializers[responseSerializerIndex] : nil

            if let responseSerializer {
                mutableState.isResponseSerializerEnqueued = true
                return { self.serializationQueue.async { responseSerializer() } }
            } else {
                let completions = mutableState.responseSerializerCompletions
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
                mutableState.isFinishing = false

                return {
                    completions.forEach { $0() }

                    // Cleanup the request outside the lock
                    self.cleanup()
                }
            }
        }

        executeOutside?()
    }

    /// Notifies the `Request` that the response serializer is complete.
    ///
    /// - Parameter completion: The completion handler provided with the response serializer, called when all serializers
    ///                         are complete.
    func responseSerializerDidComplete(completion: @escaping @Sendable () -> Void) {
        mutableState.write { mutableState in
            mutableState.isResponseSerializerEnqueued = false
            mutableState.responseSerializerCompletions.append(completion)
        }
        processNextResponseSerializer()
    }

    /// Resets all task and response serializer related state for retry.
    func reset() {
        uploadProgress.totalUnitCount = 0
        uploadProgress.completedUnitCount = 0
        downloadProgress.totalUnitCount = 0
        downloadProgress.completedUnitCount = 0

        mutableState.write { mutableState in
            mutableState.error = nil
            mutableState.isFinishing = false
            mutableState.responseSerializerCompletions = []
            mutableState.isResponseSerializerEnqueued = false
        }
    }

    /// Called when updating the upload progress.
    ///
    /// - Parameters:
    ///   - totalBytesSent: Total bytes sent so far.
    ///   - totalBytesExpectedToSend: Total bytes expected to send.
    func updateUploadProgress(totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        uploadProgress.totalUnitCount = totalBytesExpectedToSend
        uploadProgress.completedUnitCount = totalBytesSent

        uploadProgressHandler?.queue.async { self.uploadProgressHandler?.handler(self.uploadProgress) }
    }

    /// Perform a closure on the current `state` while locked.
    ///
    /// - Parameter perform: The closure to perform.
    func withState(perform: (State) -> Void) {
        mutableState.withState(perform: perform)
    }

    // MARK: Task Creation

    /// Called when creating a `URLSessionTask` for this `Request`. Subclasses must override.
    ///
    /// - Parameters:
    ///   - request: `URLRequest` to use to create the `URLSessionTask`.
    ///   - session: `URLSession` which creates the `URLSessionTask`.
    ///
    /// - Returns:   The `URLSessionTask` created.
    func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        fatalError("Subclasses must override.")
    }

    // MARK: - Public API

    // These APIs are callable from any queue.

    // MARK: State

    /// Cancels the instance. Once cancelled, a `Request` can no longer be resumed or suspended.
    ///
    /// - Returns: The instance.
    @discardableResult
    public func cancel() -> Self {
        mutableState.write { mutableState in
            guard mutableState.state.canTransitionTo(.cancelled) else { return }

            mutableState.state = .cancelled

            underlyingQueue.async { self.didCancel() }

            guard let task = mutableState.tasks.last, task.state != .completed else {
                underlyingQueue.async { self.finish() }
                return
            }

            // Resume to ensure metrics are gathered.
            task.resume()
            task.cancel()
            underlyingQueue.async { self.didCancelTask(task) }
        }

        return self
    }

    /// Suspends the instance.
    ///
    /// - Returns: The instance.
    @discardableResult
    public func suspend() -> Self {
        mutableState.write { mutableState in
            guard mutableState.state.canTransitionTo(.suspended) else { return }

            mutableState.state = .suspended

            underlyingQueue.async { self.didSuspend() }

            guard let task = mutableState.tasks.last, task.state != .completed else { return }

            task.suspend()
            underlyingQueue.async { self.didSuspendTask(task) }
        }

        return self
    }

    /// Resumes the instance.
    ///
    /// - Returns: The instance.
    @discardableResult
    public func resume() -> Self {
        let needsToPerform = mutableState.write { mutableState in
            guard mutableState.state.canTransitionTo(.resumed) else { return false }

            mutableState.state = .resumed

            underlyingQueue.async { self.didResume() }

            guard let task = mutableState.tasks.last, task.state != .completed else { return true }

            task.resume()
            underlyingQueue.async { self.didResumeTask(task) }
            return true
        }

        if needsToPerform {
            delegate?.readyToPerform(request: self)
        }

        return self
    }

    // MARK: - Closure API

    /// Associates a credential using the provided values with the instance.
    ///
    /// - Parameters:
    ///   - username:    The username.
    ///   - password:    The password.
    ///   - persistence: The `URLCredential.Persistence` for the created `URLCredential`. `.forSession` by default.
    ///
    /// - Returns:       The instance.
    @discardableResult
    public func authenticate(username: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Self {
        let credential = URLCredential(user: username, password: password, persistence: persistence)

        return authenticate(with: credential)
    }

    /// Associates the provided credential with the instance.
    ///
    /// - Parameter credential: The `URLCredential`.
    ///
    /// - Returns:              The instance.
    @discardableResult
    public func authenticate(with credential: URLCredential) -> Self {
        self.credential = credential

        return self
    }

    /// Sets a closure to be called periodically during the lifecycle of the instance as data is read from the server.
    ///
    /// - Note: Only the last closure provided is used.
    ///
    /// - Parameters:
    ///   - queue:   The `DispatchQueue` to execute the closure on. `.main` by default.
    ///   - closure: The closure to be executed periodically as data is read from the server.
    ///
    /// - Returns:   The instance.
    @preconcurrency
    @discardableResult
    public func downloadProgress(queue: DispatchQueue = .main, closure: @escaping ProgressHandler) -> Self {
        downloadProgressHandler = (handler: closure, queue: queue)

        return self
    }

    /// Sets a closure to be called periodically during the lifecycle of the instance as data is sent to the server.
    ///
    /// - Note: Only the last closure provided is used.
    ///
    /// - Parameters:
    ///   - queue:   The `DispatchQueue` to execute the closure on. `.main` by default.
    ///   - closure: The closure to be executed periodically as data is sent to the server.
    ///
    /// - Returns:   The instance.
    @preconcurrency
    @discardableResult
    public func uploadProgress(queue: DispatchQueue = .main, closure: @escaping ProgressHandler) -> Self {
        uploadProgressHandler = (handler: closure, queue: queue)

        return self
    }

    // MARK: Redirects

    /// Sets the redirect handler for the instance which will be used if a redirect response is encountered.
    ///
    /// - Note: Attempting to set the redirect handler more than once is a logic error and will crash.
    ///
    /// - Parameter handler: The `RedirectHandler`.
    ///
    /// - Returns:           The instance.
    @preconcurrency
    @discardableResult
    public func redirect(using handler: any RedirectHandler) -> Self {
        mutableState.write { mutableState in
            precondition(mutableState.redirectHandler == nil, "Redirect handler has already been set.")
            mutableState.redirectHandler = handler
        }

        return self
    }

    // MARK: Cached Responses

    /// Sets the cached response handler for the `Request` which will be used when attempting to cache a response.
    ///
    /// - Note: Attempting to set the cache handler more than once is a logic error and will crash.
    ///
    /// - Parameter handler: The `CachedResponseHandler`.
    ///
    /// - Returns:           The instance.
    @preconcurrency
    @discardableResult
    public func cacheResponse(using handler: any CachedResponseHandler) -> Self {
        mutableState.write { mutableState in
            precondition(mutableState.cachedResponseHandler == nil, "Cached response handler has already been set.")
            mutableState.cachedResponseHandler = handler
        }

        return self
    }

    // MARK: - Lifetime APIs

    /// Sets a handler to be called when the cURL description of the request is available.
    ///
    /// - Note: When waiting for a `Request`'s `URLRequest` to be created, only the last `handler` will be called.
    ///
    /// - Parameters:
    ///   - queue:   `DispatchQueue` on which `handler` will be called.
    ///   - handler: Closure to be called when the cURL description is available.
    ///
    /// - Returns:   The instance.
    @preconcurrency
    @discardableResult
    public func cURLDescription(on queue: DispatchQueue, calling handler: @escaping @Sendable (String) -> Void) -> Self {
        mutableState.write { mutableState in
            if mutableState.requests.last != nil {
                queue.async { handler(self.cURLDescription()) }
            } else {
                mutableState.cURLHandler = (queue, handler)
            }
        }

        return self
    }

    /// Sets a handler to be called when the cURL description of the request is available.
    ///
    /// - Note: When waiting for a `Request`'s `URLRequest` to be created, only the last `handler` will be called.
    ///
    /// - Parameter handler: Closure to be called when the cURL description is available. Called on the instance's
    ///                      `underlyingQueue` by default.
    ///
    /// - Returns:           The instance.
    @preconcurrency
    @discardableResult
    public func cURLDescription(calling handler: @escaping @Sendable (String) -> Void) -> Self {
        cURLDescription(on: underlyingQueue, calling: handler)

        return self
    }

    /// Sets a closure to called whenever Alamofire creates a `URLRequest` for this instance.
    ///
    /// - Note: This closure will be called multiple times if the instance adapts incoming `URLRequest`s or is retried.
    ///
    /// - Parameters:
    ///   - queue:   `DispatchQueue` on which `handler` will be called. `.main` by default.
    ///   - handler: Closure to be called when a `URLRequest` is available.
    ///
    /// - Returns:   The instance.
    @preconcurrency
    @discardableResult
    public func onURLRequestCreation(on queue: DispatchQueue = .main, perform handler: @escaping @Sendable (URLRequest) -> Void) -> Self {
        mutableState.write { state in
            if let request = state.requests.last {
                queue.async { handler(request) }
            }

            state.urlRequestHandler = (queue, handler)
        }

        return self
    }

    /// Sets a closure to be called whenever the instance creates a `URLSessionTask`.
    ///
    /// - Note: This API should only be used to provide `URLSessionTask`s to existing API, like `NSFileProvider`. It
    ///         **SHOULD NOT** be used to interact with tasks directly, as that may be break Alamofire features.
    ///         Additionally, this closure may be called multiple times if the instance is retried.
    ///
    /// - Parameters:
    ///   - queue:   `DispatchQueue` on which `handler` will be called. `.main` by default.
    ///   - handler: Closure to be called when the `URLSessionTask` is available.
    ///
    /// - Returns:   The instance.
    @preconcurrency
    @discardableResult
    public func onURLSessionTaskCreation(on queue: DispatchQueue = .main, perform handler: @escaping @Sendable (URLSessionTask) -> Void) -> Self {
        mutableState.write { state in
            if let task = state.tasks.last {
                queue.async { handler(task) }
            }

            state.urlSessionTaskHandler = (queue, handler)
        }

        return self
    }

    /// Adds a `RequestInterceptor` for this instance, called after the interceptors of the parent `Session`.
    ///
    /// - Parameter interceptor: `RequestInterceptor` to add.
    ///
    /// - Returns:               The instance.
    ///
    @preconcurrency
    @discardableResult
    public func interceptor(_ interceptor: any RequestInterceptor) -> Self {
        mutableState.write { mutableState in
            if let existingInterceptor = mutableState.interceptor {
                if let existingInterceptor = existingInterceptor as? Interceptor {
                    // Only Interceptor should be at the root.
                    mutableState.interceptor = Interceptor(adapters: existingInterceptor.adapters,
                                                           retriers: existingInterceptor.retriers,
                                                           interceptors: [interceptor])
                } else {
                    // Somehow we have a different root interceptor, split it back up.
                    mutableState.interceptor = Interceptor(interceptors: [existingInterceptor, interceptor])
                }
            } else {
                mutableState.interceptor = Interceptor(interceptors: [interceptor])
            }
        }

        return self
    }

    /// Adds a `RequestAdapter` for this instance, called after the adapters of the parent `Session`.
    ///
    /// - Parameter adapter: `RequestAdapter` to be called.
    ///
    /// - Returns:           The instance.
    ///
    @preconcurrency
    @discardableResult
    public func adapt(using adapter: any RequestAdapter) -> Self {
        mutableState.write { mutableState in
            if let existingInterceptor = mutableState.interceptor {
                if let existingInterceptor = existingInterceptor as? Interceptor {
                    // Only Interceptor should be at the root.
                    mutableState.interceptor = Interceptor(adapters: existingInterceptor.adapters + [adapter],
                                                           retriers: existingInterceptor.retriers)
                } else {
                    // Somehow we have a different root interceptor, split it back up.
                    mutableState.interceptor = Interceptor(adapters: [adapter], interceptors: [existingInterceptor])
                }
            } else {
                mutableState.interceptor = Interceptor(adapters: [adapter])
            }
        }

        return self
    }

    /// Adds a `RequestRetrier` for this instance, called after the retriers of the parent `Session`.
    ///
    /// - Parameter retrier: `RequestRetrier` to add.
    ///
    /// - Returns:           The instance.
    ///
    @preconcurrency
    @discardableResult
    public func retry(using retrier: any RequestRetrier) -> Self {
        mutableState.write { mutableState in
            if let existingInterceptor = mutableState.interceptor {
                if let existingInterceptor = existingInterceptor as? Interceptor {
                    // Only Interceptor should be at the root.
                    mutableState.interceptor = Interceptor(adapters: existingInterceptor.adapters,
                                                           retriers: existingInterceptor.retriers + [retrier])
                } else {
                    // Somehow we have a different root interceptor, split it back up.
                    mutableState.interceptor = Interceptor(retriers: [retrier], interceptors: [existingInterceptor])
                }
            } else {
                mutableState.interceptor = Interceptor(retriers: [retrier])
            }
        }

        return self
    }

    /// Adds an `EventMonitor` for this instance, called after the `EventMonitor`s of the parent `Session`.
    ///
    /// - Note: `Request` `EventMonitor`s only receive `Request` events (see the "Request Events" section of the `EventMonitor` protocol). `URLSession` events are only sent at the `Session` level.
    ///
    /// - Parameter eventMonitor: `EventMonitor` to add.
    ///
    /// - Returns:                The instance.
    ///
    @preconcurrency
    @discardableResult
    public func eventMonitor(_ eventMonitor: any EventMonitor) -> Self {
        mutableState.write { mutableState in
            if let existingMonitor = mutableState.eventMonitor {
                if let existingMonitor = existingMonitor as? CompositeEventMonitor {
                    // Only CompositeEventMonitor should be at the root.
                    mutableState.eventMonitor = CompositeEventMonitor(queue: existingMonitor.queue,
                                                                      monitors: existingMonitor.monitors + [eventMonitor])
                } else {
                    // Somehow we have a different root EventMonitor, compose it again.
                    mutableState.eventMonitor = CompositeEventMonitor(queue: underlyingQueue,
                                                                      monitors: [existingMonitor, eventMonitor])
                }
            } else {
                mutableState.eventMonitor = CompositeEventMonitor(queue: underlyingQueue, monitors: [eventMonitor])
            }
        }

        return self
    }

    // MARK: Cleanup

    /// Adds a `finishHandler` closure to be called when the request completes.
    ///
    /// - Parameter closure: Closure to be called when the request finishes.
    func onFinish(perform finishHandler: @escaping () -> Void) {
        let shouldImmediatelyExecute = mutableState.write { mutableState in
            if mutableState.state == .finished {
                return true
            } else {
                mutableState.finishHandlers.append(finishHandler)
                return false
            }
        }

        if shouldImmediatelyExecute {
            finishHandler()
        }
    }

    /// Final cleanup step executed when the instance finishes response serialization.
    func cleanup() {
        let finishHandlers = mutableState.write { mutableState in
            let handlers = mutableState.finishHandlers
            mutableState.finishHandlers.removeAll()
            return handlers
        }
        finishHandlers.forEach { $0() }

        delegate?.cleanup(after: self)
    }
}

extension Request {
    /// Type indicating how a `DataRequest` or `DataStreamRequest` should proceed after receiving an `HTTPURLResponse`.
    public enum ResponseDisposition: Sendable {
        /// Allow the request to continue normally.
        case allow
        /// Cancel the request, similar to calling `cancel()`.
        case cancel

        var sessionDisposition: URLSession.ResponseDisposition {
            switch self {
            case .allow: .allow
            case .cancel: .cancel
            }
        }
    }
}

// MARK: - Protocol Conformances

extension Request: Equatable {
    public static func ==(lhs: Request, rhs: Request) -> Bool {
        lhs.id == rhs.id
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

extension Request {
    /// cURL representation of the instance.
    ///
    /// - Returns: The cURL equivalent of the instance.
    public func cURLDescription() -> String {
        guard
            let request = lastRequest,
            let url = request.url,
            let host = url.host,
            let method = request.httpMethod else { return "$ curl command could not be created" }

        var components = ["$ curl -v"]

        components.append("-X \(method)")

        if let credentialStorage = delegate?.sessionConfiguration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(host: host,
                                                     port: url.port ?? 0,
                                                     protocol: url.scheme,
                                                     realm: host,
                                                     authenticationMethod: NSURLAuthenticationMethodHTTPBasic)

            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    guard let user = credential.user, let password = credential.password else { continue }
                    components.append("-u \(user):\(password)")
                }
            } else {
                if let credential, let user = credential.user, let password = credential.password {
                    components.append("-u \(user):\(password)")
                }
            }
        }

        if let configuration = delegate?.sessionConfiguration, configuration.httpShouldSetCookies {
            if
                let cookieStorage = configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty {
                let allCookies = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: ";")

                components.append("-b \"\(allCookies)\"")
            }
        }

        var headers = HTTPHeaders()

        if let sessionHeaders = delegate?.sessionConfiguration.headers {
            for header in sessionHeaders where header.name != "Cookie" {
                headers[header.name] = header.value
            }
        }

        for header in request.headers where header.name != "Cookie" {
            headers[header.name] = header.value
        }

        for header in headers {
            let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(header.name): \(escapedValue)\"")
        }

        if let httpBodyData = request.httpBody {
            let httpBody = String(decoding: httpBodyData, as: UTF8.self)
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")

            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(url.absoluteString)\"")

        return components.joined(separator: " \\\n\t")
    }
}

/// Protocol abstraction for `Request`'s communication back to the `SessionDelegate`.
public protocol RequestDelegate: AnyObject, Sendable {
    /// `URLSessionConfiguration` used to create the underlying `URLSessionTask`s.
    var sessionConfiguration: URLSessionConfiguration { get }

    /// Determines whether the `Request` should automatically call `resume()` when adding the first response handler.
    var startImmediately: Bool { get }

    func readyToPerform(request: Request)

    /// Notifies the delegate the `Request` has reached a point where it needs cleanup.
    ///
    /// - Parameter request: The `Request` to cleanup after.
    func cleanup(after request: Request)

    /// Asynchronously ask the delegate whether a `Request` will be retried.
    ///
    /// - Parameters:
    ///   - request:    `Request` which failed.
    ///   - error:      `Error` which produced the failure.
    ///   - completion: Closure taking the `RetryResult` for evaluation.
    func retryResult(for request: Request, dueTo error: AFError, completion: @escaping @Sendable (RetryResult) -> Void)

    /// Asynchronously retry the `Request`.
    ///
    /// - Parameters:
    ///   - request:   `Request` which will be retried.
    ///   - timeDelay: `TimeInterval` after which the retry will be triggered.
    func retryRequest(_ request: Request, withDelay timeDelay: TimeInterval?)
}
