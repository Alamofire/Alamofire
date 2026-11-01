//
//  WebSocketRequest.swift
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

#if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.

import Foundation

/// `Request` subclass which manages a WebSocket connection using `URLSessionWebSocketTask`.
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public final class WebSocketRequest: Request, @unchecked Sendable {
    enum IncomingEvent {
        case connected(protocol: String?)
        case receivedMessage(URLSessionWebSocketTask.Message)
        case disconnected(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
        case completed(Completion)
    }

    public struct Event<Success: Sendable, Failure: Error>: Sendable {
        public enum Kind: Sendable {
            case connected(protocol: String?)
            case receivedMessage(Success)
            case decoderFailed(Failure)
            /// Server disconnected or WebSocketRequest was cancelled with a specific code.
            ///
            /// - Note: This event is not received when cancelling without a code or when a error is produced.
            ///
            case disconnected(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
            case completed(Completion)
        }

        public weak var socket: WebSocketRequest?

        public let kind: Kind
        public var message: Success? {
            guard case let .receivedMessage(message) = kind else { return nil }

            return message
        }

        init(socket: WebSocketRequest, kind: Kind) {
            self.socket = socket
            self.kind = kind
        }
    }

    public struct Completion: Equatable, Sendable {
        /// Last `URLRequest` issued by the instance.
        public let request: URLRequest?
        /// Last `HTTPURLResponse` received by the instance.
        public let response: HTTPURLResponse?
        /// Last `URLSessionTaskMetrics` produced for the instance.
        public let metrics: URLSessionTaskMetrics?
        /// `AFError` produced for the instance, if any.
        public let error: AFError?
    }

    public struct Configuration {
        public struct AutomaticPing: Sendable {
            public enum FailureAction: Sendable {
                /// Continue automatic pings.
                case `continue`
                /// Stop automatic ping after `count` failures.
                case stopAutomaticPing(count: Int)
                /// Cancel `WebSocketRequest` after `count` failures.
                case cancelRequest(count: Int)
            }

            public var interval: Duration
            public var timeout: Duration?
            public var failureAction: FailureAction

            /// Creates an instance.
            ///
            /// - Parameters:
            ///   - interval:      `Duration` between each ping. Defaults to `.seconds(5)`.
            ///   - timeout:       `Duration` to wait for each pong before the ping is considered failed. `nil` by
            ///                    default, which waits indefinitely.
            ///   - failureAction: `FailureAction` to take when pings fail. `.continue` by default.
            public init(interval: Duration = .seconds(5), timeout: Duration? = nil, failureAction: FailureAction = .continue) {
                self.interval = interval
                self.timeout = timeout
                self.failureAction = failureAction
            }
        }

        public static var `default`: Self { Self() }

        public static func protocols(_ protocols: [String]) -> Self {
            Self(protocols: protocols)
        }

        public static func maximumMessageSize(_ maximumMessageSize: Int) -> Self {
            Self(maximumMessageSize: maximumMessageSize)
        }

        public static func pingInterval(_ pingInterval: TimeInterval) -> Self {
            Self(automaticPing: .init(interval: .seconds(pingInterval)))
        }

        public let protocols: [String]
        public let maximumMessageSize: Int
        public let automaticPing: AutomaticPing?

        public init(protocols: [String] = [], maximumMessageSize: Int = 1_048_576, automaticPing: AutomaticPing? = nil) {
            self.protocols = protocols
            self.maximumMessageSize = maximumMessageSize
            self.automaticPing = automaticPing
        }
    }

    /// Result of sending a ping.
    public enum PingResult: Sendable {
        /// Pong received from the server.
        public struct Pong: Sendable {
            /// Interval between ping and pong.
            public let latency: TimeInterval
        }

        /// Received a pong with the associated state.
        case pong(Pong)
        /// Received an error.
        case error(any Error)
        /// No pong was received within the timeout provided when the ping was sent.
        case timedOut
        /// Did not send the ping, the request is not resumed, or is cancelled, finishing, or finished.
        case unsent
        /// A pending or inflight ping was lost due to the request being cancelled, closed, or finished before a pong
        /// was received, or the calling `Task` being cancelled.
        case lost
    }

    /// A ping that has been accepted, either waiting for the socket to connect or inflight.
    struct PendingPing {
        let queue: DispatchQueue
        let timeout: Duration?
        let handler: @Sendable (_ result: PingResult) -> Void
        /// Whether the ping has been handed to the `URLSessionWebSocketTask`.
        var isSent = false
        /// Fires the `.timedOut` result, only set once the ping has been sent.
        var timeoutItem: DispatchWorkItem?
    }

    /// The outcome of a message send, mapped to the caller's `Result` by `PendingMessage.complete`.
    enum MessageOutcome {
        case sent
        case failed(any Error)
        case lost
    }

    /// A message that has been accepted and encoded, either waiting for the socket to connect or inflight.
    struct PendingMessage {
        let id: UUID
        let message: URLSessionWebSocketTask.Message
        /// Calls the caller's completion handler and event monitor, then leaves `sendGroup`. Must only be called once.
        let complete: @Sendable (_ outcome: MessageOutcome) -> Void
        /// Whether the message has been handed to the `URLSessionWebSocketTask`.
        var isSent = false
    }

    struct SocketMutableState {
        /// Accepted messages, in send order.
        var messages: [PendingMessage] = []
        var handlers: [@Sendable (_ event: IncomingEvent) -> Void] = []
        /// Whether the current `URLSessionWebSocketTask` has connected and not yet disconnected.
        var isConnected = false
        var automaticPingTimerItem: DispatchWorkItem?
        /// Identifies the active automatic ping chain, so stale chains (e.g. from a previous connection) stop.
        var automaticPingChainID: UUID?
        var pings: [UUID: PendingPing] = [:]
    }

    let socketMutableState = Protected(SocketMutableState())

    // Ensures all accepted sends complete before the final stream event.
    private let sendGroup = DispatchGroup()

    // Ensures the final `.completed` stream event has been delivered to every registered handler before
    // `requestDidFinish` fires, guaranteeing it's always the last event received for a `WebSocketRequest`.
    private let streamCompletionGroup = DispatchGroup()

    public let convertible: any URLRequestConvertible
    public let configuration: Configuration

    init(id: UUID = UUID(),
         convertible: any URLRequestConvertible,
         configuration: Configuration,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: (any EventMonitor)?,
         interceptor: (any RequestInterceptor)?,
         shouldAutomaticallyResume: Bool?,
         delegate: any RequestDelegate) {
        self.convertible = convertible
        self.configuration = configuration

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   shouldAutomaticallyResume: shouldAutomaticallyResume,
                   delegate: delegate)
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        var request = request
        if !configuration.protocols.isEmpty {
            request.headers.update(.websocketProtocol(configuration.protocols.joined(separator: ", ")))
        }
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = configuration.maximumMessageSize

        return task
    }

    override func cleanup() {
        // Anything accepted after the drain in `finish()` but before `isFinishing` was set is completed here.
        let (messages, pings) = socketMutableState.write { $0.resetReturningPendingWork() }
        completeAsLost(messages, pings)

        super.cleanup()
    }

    override func didCreateTask(_ task: URLSessionTask) {
        // Can only close previous socket by canceling, which would close that connection.
        // Do we only allow new tasks if the previous one is cancelled or finished?
        // didCreateTask means we already resumed it if we're in that state
        // Technically, at that point, we have two sockets open.
        // However, we should only trigger a new task on retry, which means the previous one has to have failed in some way.
        // So no need to handle old socket?
        // let previousSocket = socket

        // A new task hasn't connected yet, so pending messages and pings must wait for its `didConnect`.
        socketMutableState.write { $0.isConnected = false }

        super.didCreateTask(task)

        startListening()
    }

    func didClose(sending closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        let eventMonitor = mutableState.write { mutableState in
            // Check whether error is cancellation or other websocket closing error.
            // If so, remove it.
            // Otherwise keep it.
            if case let .sessionTaskFailed(error) = mutableState.error, (error as? URLError)?.code == .cancelled {
                mutableState.error = nil
            }

            return mutableState.eventMonitor
        }

        eventMonitor?.request(self, didCloseWithCloseCode: closeCode, reason: reason)
    }

    @discardableResult
    public func close(sending closeCode: URLSessionWebSocketTask.CloseCode, reason: Data? = nil) -> Self {
        withBothStates { mutableState, socketMutableState in
            guard mutableState.state.canTransitionTo(.cancelled) else { return }

            socketMutableState.cancelAutomaticPing()

            mutableState.state = .cancelled

            underlyingQueue.async { self.didClose(sending: closeCode, reason: reason) }

            // Ensure we have a task. If we do, didCreateTask has been called but wouldn't have changed the task state
            // since we just transitioned to cancelled. If we don't, didCreateTask hasn't been called yet, so we can
            // start the finish process and return early, as didCreateTask will perform the task changes but we won't
            // receive any task delegate callback.
            guard let socket = mutableState.socket else {
                underlyingQueue.async { self.finish() }
                return
            }
            // We have a task, if it's completed, return early, as the delegate callbacks should be in flight and
            // cancelling it will have no effect.
            guard socket.state != .completed else { return }

            // Resume to ensure metrics are gathered.
            socket.resume()
            // Cast from state directly, not the property, otherwise the lock is recursive.
            socket.cancel(with: closeCode, reason: reason)
            underlyingQueue.async { self.didCancelTask(socket) }
        }

        // State is no longer `.resumed`, so no new messages or pings can be added after this drain.
        drainPendingWork()

        return self
    }

    override func finish(error: AFError? = nil) {
        super.finish(error: error)

        // `isFinishing` is now set, so no new messages or pings can be added after this drain. Any added in the window
        // before `isFinishing` is set are drained in `cleanup()`.
        drainPendingWork()
    }

    // Delay `requestDidFinish` until every registered stream handler has received the final `.completed` event,
    // guaranteeing it's the last event fired for a `WebSocketRequest`, unlike the default `Request` behavior.
    override func notifyRequestDidFinish() {
        streamCompletionGroup.notify(queue: underlyingQueue) {
            self.eventMonitor?.requestDidFinish(self)
        }
    }

    @discardableResult
    override public func cancel() -> Self {
        cancelAutomaticPing()

        super.cancel()

        // Drain after the state transition so no new messages or pings can be added after the drain.
        drainPendingWork()

        return self
    }

    func didConnect(protocol: String?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        let (eventMonitor, socket, pingsToSend) = withBothStates { mutableState, socketMutableState in
            socketMutableState.isConnected = true

            for handler in socketMutableState.handlers {
                // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                handler(.connected(protocol: `protocol`))
            }

            // Send messages while holding the lock so they're handed to the socket in order, before any new sends.
            if let socket = mutableState.socket {
                for index in socketMutableState.messages.indices where !socketMutableState.messages[index].isSent {
                    socketMutableState.messages[index].isSent = true
                    performSend(socketMutableState.messages[index], on: socket)
                }
            }

            return (mutableState.eventMonitor, mutableState.socket, socketMutableState.markUnsentPingsSent())
        }
        eventMonitor?.request(self, didConnectWithProtocol: `protocol`)

        if let socket {
            for (id, timeout) in pingsToSend {
                performPing(id, timeout: timeout, on: socket)
            }
        }

        if let automaticPing = configuration.automaticPing {
            startAutomaticPing(configuration: automaticPing)
        }
    }

    /// Starts a new automatic ping chain, replacing any existing one.
    func startAutomaticPing(configuration: Configuration.AutomaticPing) {
        let chainID = UUID()
        socketMutableState.write { socketMutableState in
            socketMutableState.cancelAutomaticPing()
            socketMutableState.automaticPingChainID = chainID
        }

        scheduleAutomaticPing(configuration: configuration, chainID: chainID, failureCount: 0)
    }

    private func scheduleAutomaticPing(configuration: Configuration.AutomaticPing, chainID: UUID, failureCount: Int) {
        withBothStates { mutableState, socketMutableState in
            // A newer chain has replaced this one, or the chain was cancelled.
            guard socketMutableState.automaticPingChainID == chainID else { return }

            // Keep the chain alive while suspended so it continues once resumed. Stop once disconnected or terminal.
            guard socketMutableState.isConnected,
                  mutableState.state.is(.resumed) || mutableState.state.is(.suspended) else {
                socketMutableState.cancelAutomaticPing()
                return
            }

            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }

                sendPing(timeout: configuration.timeout, respondingOn: underlyingQueue) { [weak self] response in
                    guard let self else { return }

                    switch response {
                    case .pong:
                        scheduleAutomaticPing(configuration: configuration, chainID: chainID, failureCount: 0)
                    case .error, .timedOut:
                        let failureCount = failureCount + 1
                        switch configuration.failureAction {
                        case .continue:
                            scheduleAutomaticPing(configuration: configuration, chainID: chainID, failureCount: failureCount)
                        case let .stopAutomaticPing(count):
                            if failureCount < count {
                                scheduleAutomaticPing(configuration: configuration, chainID: chainID, failureCount: failureCount)
                            }
                        case let .cancelRequest(count):
                            if failureCount < count {
                                scheduleAutomaticPing(configuration: configuration, chainID: chainID, failureCount: failureCount)
                            } else {
                                cancel()
                            }
                        }
                    case .unsent:
                        // Likely suspended, try again next interval. Rescheduling stops if the request is terminal.
                        scheduleAutomaticPing(configuration: configuration, chainID: chainID, failureCount: failureCount)
                    case .lost:
                        // Request is cancelled, closed, or finished.
                        break
                    }
                }
            }

            socketMutableState.automaticPingTimerItem?.cancel()
            socketMutableState.automaticPingTimerItem = item
            underlyingQueue.asyncAfter(deadline: .now() + configuration.interval.timeInterval, execute: item)
        }
    }

    /// Ensure all access to both states uses the same lock ordering to prevent deadlocks.
    @inline(__always)
    @discardableResult
    fileprivate func withBothStates<Out>(
        _ perform: (_ mutableState: inout WebSocketRequest.MutableState,
                    _ socketMutableState: inout WebSocketRequest.SocketMutableState) -> Out
    ) -> Out {
        mutableState.write { mutableState in
            socketMutableState.write { socketMutableState in
                perform(&mutableState, &socketMutableState)
            }
        }
    }

    func cancelAutomaticPing() {
        withBothStates { $1.cancelAutomaticPing() }
    }

    func didDisconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        let eventMonitor = withBothStates { mutableState, socketMutableState in
            socketMutableState.isConnected = false
            socketMutableState.cancelAutomaticPing()
            for handler in socketMutableState.handlers {
                // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                handler(.disconnected(closeCode: closeCode, reason: reason))
            }
            return mutableState.eventMonitor
        }

        eventMonitor?.request(self, didDisconnectWithCloseCode: closeCode, reason: reason)
    }

    private func startListening() {
        withBothStates { mutableState, _ in
            #if compiler(>=6.2.3)
            weak let request = self
            #else
            weak var request = self
            #endif
            mutableState.listen(onBehalfOf: request)
        }
    }

    // MARK: - Sending Pings

    /// Sends a ping to the server, calling `onResponse` with the result.
    ///
    /// - If the instance isn't `.resumed`, or is finishing or finished, the ping isn't sent and `.unsent` is returned
    ///   immediately. An instance which will be automatically resumed because a stream handler has been added is
    ///   treated as `.resumed`.
    /// - If the instance is `.resumed` but the socket hasn't connected yet, the ping is held until the socket connects,
    ///   at which point it's sent. If the instance is cancelled, closed, or finishes before connecting, the ping is
    ///   `.lost`.
    ///
    /// - Parameters:
    ///   - timeout:    `Duration` to wait for a pong once the ping has been sent, after which `.timedOut` is returned.
    ///                 Time spent waiting for the socket to connect doesn't count toward the timeout. `nil` by default,
    ///                 which waits indefinitely.
    ///   - queue:      `DispatchQueue` on which to call `onResponse`. `.main` by default.
    ///   - onResponse: Closure called with the `PingResult`.
    public func sendPing(timeout: Duration? = nil,
                         respondingOn queue: DispatchQueue = .main,
                         onResponse: @escaping @Sendable (PingResult) -> Void) {
        sendPing(id: UUID(), timeout: timeout, respondingOn: queue, onResponse: onResponse)
    }

    /// Sends a ping to the server, returning the result.
    ///
    /// - Note: Cancelling the calling `Task` returns `.lost` but doesn't cancel the instance.
    ///
    /// - Parameter timeout: `Duration` to wait for a pong once the ping has been sent, after which `.timedOut` is
    ///                      returned. Time spent waiting for the socket to connect doesn't count toward the timeout.
    ///                      `nil` by default, which waits indefinitely.
    ///
    /// - Returns: The `PingResult`.
    public func sendPing(timeout: Duration? = nil) async -> PingResult {
        let pingID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                sendPing(id: pingID, timeout: timeout, respondingOn: .streamCompletionQueue(forRequestID: self.id)) { result in
                    continuation.resume(returning: result)
                }

                // Cancellation may have occurred before the ping was registered, so the handler would have done nothing.
                if Task.isCancelled {
                    completePing(pingID, with: .lost)
                }
            }
        } onCancel: {
            completePing(pingID, with: .lost)
        }
    }

    private func sendPing(id: UUID,
                          timeout: Duration?,
                          respondingOn queue: DispatchQueue,
                          onResponse: @escaping @Sendable (PingResult) -> Void) {
        let socket: URLSessionWebSocketTask? = withBothStates { mutableState, socketMutableState in
            guard acceptsPendingWork(mutableState) else {
                queue.async { onResponse(.unsent) }
                return nil
            }

            var ping = PendingPing(queue: queue, timeout: timeout, handler: onResponse)

            // Not connected yet, hold the ping until `didConnect`.
            guard socketMutableState.isConnected, let socket = mutableState.socket else {
                socketMutableState.pings[id] = ping
                return nil
            }

            ping.isSent = true
            socketMutableState.pings[id] = ping

            return socket
        }

        if let socket {
            performPing(id, timeout: timeout, on: socket)
        }
    }

    /// Sends an already registered ping using `socket`. Must not be called while holding either lock.
    private func performPing(_ id: UUID, timeout: Duration?, on socket: URLSessionWebSocketTask) {
        if let timeout {
            // Strongly capture self so the handler is always called.
            let timeoutItem = DispatchWorkItem { self.completePing(id, with: .timedOut) }
            // If the ping has already completed there's no entry to update, so the item fires as a no-op.
            socketMutableState.write { $0.pings[id]?.timeoutItem = timeoutItem }
            underlyingQueue.asyncAfter(deadline: .now() + timeout.timeInterval, execute: timeoutItem)
        }

        let startTimestamp = Instant()
        // Strongly capture self so the handler is always called, even if the request is otherwise released.
        socket.sendPing { error in
            if let error {
                self.completePing(id, with: .error(error))
            } else {
                let latency = Instant() - startTimestamp
                self.completePing(id, with: .pong(.init(latency: latency)))
            }
        }
    }

    /// Removes the ping for `id` and calls its handler with `result`. Does nothing if the ping was already completed.
    private func completePing(_ id: UUID, with result: PingResult) {
        guard let ping = socketMutableState.write({ $0.pings.removeValue(forKey: id) }) else { return }

        ping.timeoutItem?.cancel()
        ping.queue.async { ping.handler(result) }
    }

    /// Whether new messages and pings can be accepted. They're accepted while the instance is `.resumed`, or is
    /// `.initialized` but has already scheduled its automatic resume by adding a stream handler, and isn't finishing or
    /// finished. Must be called while holding the `mutableState` lock.
    private func acceptsPendingWork(_ mutableState: MutableState) -> Bool {
        guard !mutableState.isFinishing, !mutableState.responseSerializerProcessingFinished else { return false }

        if mutableState.state.is(.resumed) { return true }

        // Adding a stream handler resumes the instance asynchronously, so treat it as resumed in the meantime.
        return mutableState.state.is(.initialized)
            && !mutableState.responseSerializers.isEmpty
            && (shouldAutomaticallyResume ?? delegate?.startImmediately) == true
    }

    /// Removes all pending and inflight messages and pings, completing them with `.lost`.
    private func drainPendingWork() {
        let (messages, pings) = socketMutableState.write { socketMutableState in
            defer {
                socketMutableState.messages.removeAll()
                socketMutableState.pings.removeAll()
            }
            return (socketMutableState.messages, Array(socketMutableState.pings.values))
        }

        completeAsLost(messages, pings)
    }

    private func completeAsLost(_ messages: [PendingMessage], _ pings: [PendingPing]) {
        for message in messages {
            message.complete(.lost)
        }

        for ping in pings {
            ping.timeoutItem?.cancel()
            ping.queue.async { ping.handler(.lost) }
        }
    }

    // MARK: - Sending Messages

    public enum SendError<EncoderFailure>: Error where EncoderFailure: Error {
        /// Attempted to send while the request wasn't `.resumed`, or was finishing or finished. The associated state is
        /// the state at the time of sending. Message was dropped.
        case state(Request.State)
        /// Send failed due to the associated encoder error.
        case encoder(EncoderFailure)
        /// Send failed due to the associated `URLSessionWebSocketTask` error.
        case socket(any Error)
        /// A pending or inflight message was lost due to the request being cancelled, closed, or finished before the
        /// send completed, or the calling `Task` being cancelled before the message was sent.
        case lost

        public var failedState: Request.State? {
            guard case let .state(state) = self else { return nil }

            return state
        }
    }

    public func send(_ data: Data) async throws(SendError<Never>) {
        try await send(data).get()
    }

    public func send(_ data: Data) async -> Result<Void, SendError<Never>> {
        await send(.data(data))
    }

    public func send(_ data: Data,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<Never>>) -> Void) {
        send(.data(data), queue: queue, completionHandler: completionHandler)
    }

    public func send(_ string: String) async throws(SendError<Never>) {
        try await send(string).get()
    }

    public func send(_ string: String) async -> Result<Void, SendError<Never>> {
        await send(.string(string))
    }

    public func send(_ string: String,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<Never>>) -> Void) {
        send(.string(string), queue: queue, completionHandler: completionHandler)
    }

    public func send(_ message: URLSessionWebSocketTask.Message) async throws(SendError<Never>) {
        try await send(message).get()
    }

    public func send(_ message: URLSessionWebSocketTask.Message) async -> Result<Void, SendError<Never>> {
        await send(message, using: PassthroughWebSocketMessageEncoder())
    }

    public func send(_ message: URLSessionWebSocketTask.Message,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<Never>>) -> Void) {
        send(message, using: PassthroughWebSocketMessageEncoder(), queue: queue, completionHandler: completionHandler)
    }

    public func send<Value: Encodable>(_ value: Value, using encoder: any DataEncoder = JSONEncoder()) async throws(SendError<any Error>) {
        try await send(value, using: encoder).get()
    }

    public func send<Value: Encodable>(_ value: Value, using encoder: any DataEncoder = JSONEncoder()) async -> Result<Void, SendError<any Error>> {
        await send(value, using: EncodableWebSocketMessageEncoder(encoder: encoder))
    }

    public func send<Value: Encodable>(_ value: Value,
                                       using encoder: any DataEncoder = JSONEncoder(),
                                       queue: DispatchQueue = .main,
                                       completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<any Error>>) -> Void) {
        send(value, using: EncodableWebSocketMessageEncoder(encoder: encoder), queue: queue, completionHandler: completionHandler)
    }

    func send<Value, MessageEncoder>(_ value: Value,
                                     using encoder: MessageEncoder) async throws(SendError<MessageEncoder.Failure>)
    where MessageEncoder: WebSocketMessageEncoder, MessageEncoder.Input == Value {
        try await send(value, using: encoder).get()
    }

    /// Sends `value`, encoded using `encoder`, returning the result.
    ///
    /// - Note: Cancelling the calling `Task` before the message has been handed to the socket prevents it from being sent
    ///         and returns `.lost`. Once handed to the socket, the send completes normally.
    func send<Value, MessageEncoder>(_ value: Value,
                                     using encoder: MessageEncoder) async -> Result<Void, SendError<MessageEncoder.Failure>>
        where MessageEncoder: WebSocketMessageEncoder, MessageEncoder.Input == Value {
        let messageID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                send(id: messageID, value, using: encoder, queue: .streamCompletionQueue(forRequestID: self.id)) { result in
                    continuation.resume(returning: result)
                }

                // Cancellation may have occurred before the message was registered, so the handler would have done nothing.
                if Task.isCancelled {
                    cancelUnsentMessage(messageID)
                }
            }
        } onCancel: {
            cancelUnsentMessage(messageID)
        }
    }

    /// Sends `value`, encoded using `encoder`, calling `completionHandler` with the result.
    ///
    /// - If the instance isn't `.resumed`, or is finishing or finished, the message isn't sent and `.state` is returned
    ///   immediately. An instance which will be automatically resumed because a stream handler has been added is
    ///   treated as `.resumed`.
    /// - If the instance is `.resumed` but the socket hasn't connected yet, the message is held until the socket
    ///   connects, at which point messages are sent in the order they were accepted. If the instance is cancelled,
    ///   closed, or finishes before the send completes, `.lost` is returned.
    ///
    /// - Parameters:
    ///   - value:             Value to send.
    ///   - encoder:           `WebSocketMessageEncoder` used to encode `value`.
    ///   - queue:             `DispatchQueue` on which to call `completionHandler`. `.main` by default.
    ///   - completionHandler: Closure called with the result of the send.
    public func send<Value, MessageEncoder>(_ value: Value,
                                            using encoder: MessageEncoder,
                                            queue: DispatchQueue = .main,
                                            completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<MessageEncoder.Failure>>) -> Void)
    where MessageEncoder: WebSocketMessageEncoder, MessageEncoder.Input == Value {
        send(id: UUID(), value, using: encoder, queue: queue, completionHandler: completionHandler)
    }

    private func send<Value, MessageEncoder>(id: UUID,
                                             _ value: Value,
                                             using encoder: MessageEncoder,
                                             queue: DispatchQueue,
                                             completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<MessageEncoder.Failure>>) -> Void)
    where MessageEncoder: WebSocketMessageEncoder, MessageEncoder.Input == Value {
        @Sendable
        func fail(_ error: SendError<MessageEncoder.Failure>) {
            queue.async { completionHandler(.failure(error)) }
            eventMonitor?.request(self, didFailToSendMessage: value, dueToError: error)
        }

        let message: URLSessionWebSocketTask.Message
        do throws(MessageEncoder.Failure) {
            message = try encoder.encode(value)
        } catch {
            fail(.encoder(error))
            return
        }

        let pendingMessage = PendingMessage(id: id, message: message) { [self] outcome in
            let result: Result<Void, SendError<MessageEncoder.Failure>>
            switch outcome {
            case .sent:
                result = .success(())
                eventMonitor?.request(self, didSendMessage: message)
            case let .failed(error):
                result = .failure(.socket(error))
            case .lost:
                result = .failure(.lost)
            }

            if case let .failure(error) = result {
                eventMonitor?.request(self, didFailToSendMessage: value, dueToError: error)
            }

            // Leave in the same work item as the handler, after it has run, so it's always called before the final
            // `.completed` event, even on concurrent queues.
            queue.async {
                completionHandler(result)
                self.sendGroup.leave()
            }
        }

        let rejectedState: Request.State? = withBothStates { mutableState, socketMutableState in
            guard acceptsPendingWork(mutableState) else {
                return mutableState.state.is(.resumed) ? .finished : mutableState.state
            }

            sendGroup.enter()
            socketMutableState.messages.append(pendingMessage)

            // Send while holding the lock so messages are handed to the socket in the order they're accepted.
            if socketMutableState.isConnected, let socket = mutableState.socket {
                socketMutableState.messages[socketMutableState.messages.count - 1].isSent = true
                performSend(pendingMessage, on: socket)
            }

            return nil
        }

        if let rejectedState {
            fail(.state(rejectedState))
        }
    }

    /// Hands `pendingMessage` to `socket`. Safe to call while holding the locks, as `socket` calls back asynchronously.
    private func performSend(_ pendingMessage: PendingMessage, on socket: URLSessionWebSocketTask) {
        let id = pendingMessage.id
        // Strongly capture self so the handler is always called, even if the request is otherwise released.
        socket.send(pendingMessage.message) { error in
            self.completeMessage(id, with: error.map { .failed($0) } ?? .sent)
        }
    }

    /// Removes the message for `id` and completes it with `outcome`. Does nothing if the message was already completed.
    private func completeMessage(_ id: UUID, with outcome: MessageOutcome) {
        let pendingMessage = socketMutableState.write { socketMutableState in
            socketMutableState.messages.firstIndex { $0.id == id }.map { socketMutableState.messages.remove(at: $0) }
        }

        pendingMessage?.complete(outcome)
    }

    /// Removes the message for `id` and completes it with `.lost`, only if it hasn't been handed to the socket yet.
    private func cancelUnsentMessage(_ id: UUID) {
        let pendingMessage = socketMutableState.write { socketMutableState -> PendingMessage? in
            guard let index = socketMutableState.messages.firstIndex(where: { $0.id == id }),
                  !socketMutableState.messages[index].isSent else { return nil }

            return socketMutableState.messages.remove(at: index)
        }

        pendingMessage?.complete(.lost)
    }

    // MARK: - Receiving

    @discardableResult
    public func streamSerializer<Serializer>(
        _ serializer: Serializer,
        on queue: DispatchQueue = .main,
        handler: @escaping @Sendable (_ event: Event<Serializer.Output, Serializer.Failure>) -> Void
    ) -> Self where Serializer: WebSocketMessageDecoder {
        forIncomingEvent { [self] incomingEvent in
            let event: Event<Serializer.Output, Serializer.Failure>
            switch incomingEvent {
            case let .connected(`protocol`):
                event = .init(socket: self, kind: .connected(protocol: `protocol`))
            case let .receivedMessage(message):
                do throws(Serializer.Failure) {
                    let serializedMessage = try serializer.decode(message)
                    event = .init(socket: self, kind: .receivedMessage(serializedMessage))
                } catch {
                    event = .init(socket: self, kind: .decoderFailed(error))
                }
            case let .disconnected(closeCode, reason):
                event = .init(socket: self, kind: .disconnected(closeCode: closeCode, reason: reason))
            case let .completed(completion):
                event = .init(socket: self, kind: .completed(completion))
            }

            eventMonitor?.request(self, didReceiveEvent: event)

            queue.async { handler(event) }
        }
    }

    @discardableResult
    public func streamDecodableEvents<Value>(
        _ type: Value.Type = Value.self,
        using decoder: any DataDecoder = JSONDecoder(),
        on queue: DispatchQueue = .main,
        handler: @escaping @Sendable (_ event: Event<Value, DecodableWebSocketMessageDecoder<Value>.Error>) -> Void
    ) -> Self where Value: Decodable {
        streamSerializer(DecodableWebSocketMessageDecoder<Value>(decoder: decoder), on: queue, handler: handler)
    }

    @discardableResult
    public func streamDecodable<Value>(
        _ type: Value.Type = Value.self,
        using decoder: any DataDecoder = JSONDecoder(),
        on queue: DispatchQueue = .main,
        handler: @escaping @Sendable (_ value: Value) -> Void
    ) -> Self where Value: Decodable & Sendable {
        streamDecodableEvents(Value.self, using: decoder, on: queue) { event in
            event.message.map(handler)
        }
    }

    @discardableResult
    public func streamMessageEvents(
        on queue: DispatchQueue = .main,
        handler: @escaping @Sendable (_ event: Event<URLSessionWebSocketTask.Message, Never>) -> Void
    ) -> Self {
        forIncomingEvent { [self] incomingEvent in
            let event: Event<URLSessionWebSocketTask.Message, Never> = switch incomingEvent {
            case let .connected(`protocol`):
                .init(socket: self, kind: .connected(protocol: `protocol`))
            case let .receivedMessage(message):
                .init(socket: self, kind: .receivedMessage(message))
            case let .disconnected(closeCode, reason):
                .init(socket: self, kind: .disconnected(closeCode: closeCode, reason: reason))
            case let .completed(completion):
                .init(socket: self, kind: .completed(completion))
            }

            eventMonitor?.request(self, didReceiveEvent: event)

            queue.async { handler(event) }
        }
    }

    @discardableResult
    public func streamMessages(
        on queue: DispatchQueue = .main,
        handler: @escaping @Sendable (_ message: URLSessionWebSocketTask.Message) -> Void
    ) -> Self {
        streamMessageEvents(on: queue) { event in
            event.message.map(handler)
        }
    }

    func forIncomingEvent(handler: @escaping @Sendable (IncomingEvent) -> Void) -> Self {
        socketMutableState.write { socketMutableState in
            socketMutableState.handlers.append { [self] incomingEvent in
                serializationQueue.async {
                    handler(incomingEvent)
                }
            }
        }

        // Entered here and left only once the final `.completed` event below has been delivered to this handler,
        // so `notifyRequestDidFinish()` can delay `requestDidFinish` until every registered handler has received it.
        streamCompletionGroup.enter()

        appendResponseSerializer {
            self.responseSerializerDidComplete { [self] in
                let request = request
                let response = response
                let metrics = metrics
                let error = error
                sendGroup.notify(queue: serializationQueue) {
                    handler(.completed(.init(request: request,
                                             response: response,
                                             metrics: metrics,
                                             error: error)))
                    self.streamCompletionGroup.leave()
                }
            }
        }

        return self
    }
}

// MARK: - Concurrency

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest {
    public typealias EventStreamOf<Success, Failure: Error> = StreamOf<WebSocketRequest.Event<Success, Failure>>

    public func streamingMessageEvents(
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        bufferingPolicy: EventStreamOf<URLSessionWebSocketTask.Message, Never>.BufferingPolicy = .unbounded
    ) -> EventStreamOf<URLSessionWebSocketTask.Message, Never> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0 }) { [self] onEvent in
            streamMessageEvents(on: .streamCompletionQueue(forRequestID: id), handler: onEvent)
        }
    }

    // TODO: should we throw an error when stream can't be created due to the socket being finished?

    public func streamingMessages(
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        bufferingPolicy: StreamOf<URLSessionWebSocketTask.Message>.BufferingPolicy = .unbounded
    ) -> StreamOf<URLSessionWebSocketTask.Message> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0.message }) { [self] onEvent in
            streamMessageEvents(on: .streamCompletionQueue(forRequestID: id), handler: onEvent)
        }
    }

    public func streamingDecodableEvents<Value: Decodable & Sendable>(
        _ type: Value.Type = Value.self,
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        using decoder: any DataDecoder = JSONDecoder(),
        bufferingPolicy: EventStreamOf<Value, DecodableWebSocketMessageDecoder<Value>.Error>.BufferingPolicy = .unbounded
    ) -> EventStreamOf<Value, DecodableWebSocketMessageDecoder<Value>.Error> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: \.self) { [self] onEvent in
            streamDecodableEvents(Value.self,
                                  using: decoder,
                                  on: .streamCompletionQueue(forRequestID: id),
                                  handler: onEvent)
        }
    }

    public func streamingDecodable<Value: Decodable & Sendable>(
        _ type: Value.Type = Value.self,
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        using decoder: any DataDecoder = JSONDecoder(),
        bufferingPolicy: StreamOf<Value>.BufferingPolicy = .unbounded
    ) -> StreamOf<Value> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0.message }) { [self] onEvent in
            streamDecodableEvents(Value.self,
                                  using: decoder,
                                  on: .streamCompletionQueue(forRequestID: id),
                                  handler: onEvent)
        }
    }

    private func createStream<Success, Value, Failure: Error>(
        automaticallyCancelling shouldAutomaticallyCancel: Bool,
        bufferingPolicy: StreamOf<Value>.BufferingPolicy,
        transform: @escaping @Sendable (_ event: WebSocketRequest.Event<Success, Failure>) -> Value?,
        forResponse onResponse: @Sendable @escaping (@escaping @Sendable (_ event: WebSocketRequest.Event<Success, Failure>) -> Void) -> Void
    ) -> StreamOf<Value> {
        StreamOf(bufferingPolicy: bufferingPolicy) { [weak self] in
            guard let self else { return }

            guard shouldAutomaticallyCancel,
                  withBothStates({ mutableState, _ in
                      mutableState.state.is(.initialized)
                      || mutableState.state.is(.resumed)
                      || mutableState.state.is(.suspended)
                  }) else { return }

            cancel()
        } builder: { continuation in
            onResponse { event in
                if let value = transform(event) {
                    continuation.yield(value)
                }

                if case .completed = event.kind {
                    continuation.finish()
                }
            }
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public protocol WebSocketMessageDecoder<Output, Failure>: Sendable {
    associatedtype Output: Sendable
    associatedtype Failure: Error

    func decode(_ message: URLSessionWebSocketTask.Message) throws(Failure) -> Output
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketMessageDecoder {
    public static func json<Value>(
        decoding _: Value.Type = Value.self,
        using decoder: JSONDecoder = JSONDecoder()
    ) -> DecodableWebSocketMessageDecoder<Value> where Self == DecodableWebSocketMessageDecoder<Value> {
        Self(decoder: decoder)
    }

    public static var passthrough: PassthroughWebSocketMessageDecoder {
        PassthroughWebSocketMessageDecoder()
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct PassthroughWebSocketMessageDecoder: WebSocketMessageDecoder {
    public typealias Failure = Never

    public func decode(_ message: URLSessionWebSocketTask.Message) -> URLSessionWebSocketTask.Message {
        message
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct DecodableWebSocketMessageDecoder<Value: Decodable & Sendable>: WebSocketMessageDecoder {
    public enum Error: Swift.Error {
        case decoding(any Swift.Error)
        case unknownMessage(description: String)
    }

    public let decoder: any DataDecoder

    public init(decoder: any DataDecoder) {
        self.decoder = decoder
    }

    public func decode(_ message: URLSessionWebSocketTask.Message) throws(Error) -> Value {
        let data: Data
        switch message {
        case let .data(messageData):
            data = messageData
        case let .string(string):
            data = Data(string.utf8)
        @unknown default:
            throw Error.unknownMessage(description: String(describing: message))
        }

        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw Error.decoding(error)
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public protocol WebSocketMessageEncoder: Sendable {
    associatedtype Input: Sendable
    associatedtype Failure: Error

    func encode(_ input: Input) throws(Failure) -> URLSessionWebSocketTask.Message
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct EncodableWebSocketMessageEncoder: WebSocketMessageEncoder {
    public let encoder: any DataEncoder

    public init(encoder: any DataEncoder) {
        self.encoder = encoder
    }

    public func encode(_ input: any Encodable & Sendable) throws -> URLSessionWebSocketTask.Message {
        try .data(encoder.encode(input))
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct PassthroughWebSocketMessageEncoder: WebSocketMessageEncoder {
    public func encode(_ input: URLSessionWebSocketTask.Message) -> URLSessionWebSocketTask.Message {
        input
    }
}

public protocol DataEncoder: Sendable {
    func encode<Value>(_ value: Value) throws -> Data where Value: Encodable
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension JSONEncoder: DataEncoder {}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest.SocketMutableState {
    mutating func cancelAutomaticPing() {
        automaticPingTimerItem?.cancel()
        automaticPingTimerItem = nil
        automaticPingChainID = nil
    }

    /// Marks all pings waiting for a connection as sent, returning them so they can be sent outside the lock.
    mutating func markUnsentPingsSent() -> [(id: UUID, timeout: Duration?)] {
        var pingsToSend: [(id: UUID, timeout: Duration?)] = []
        for (id, ping) in pings where !ping.isSent {
            pings[id]?.isSent = true
            pingsToSend.append((id, ping.timeout))
        }

        return pingsToSend
    }

    mutating func resetReturningPendingWork() -> (messages: [WebSocketRequest.PendingMessage],
                                                  pings: [WebSocketRequest.PendingPing]) {
        cancelAutomaticPing()
        let pendingWork = (messages, Array(pings.values))
        self = .init()
        return pendingWork
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest.MutableState {
    var socket: URLSessionWebSocketTask? {
        tasks.last as? URLSessionWebSocketTask
    }

    func listen(onBehalfOf request: WebSocketRequest?) {
        guard let request, let socket else { return }

        socket.receive { result in
            switch result {
            case let .success(message):
                request.eventMonitor?.request(request, didReceiveMessage: message)

                request.withBothStates { mutableState, socketMutableState in
                    for handler in socketMutableState.handlers {
                        // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                        handler(.receivedMessage(message))
                    }

                    #if compiler(>=6.2.3)
                    weak let request = request
                    #else
                    weak var request = request
                    #endif
                    mutableState.listen(onBehalfOf: request)
                }
            case .failure:
                // It doesn't seem like any relevant errors are received here, just incorrect garbage, like errors when
                // the socket disconnects.
                break
            }
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest.Event: Equatable where Success: Equatable, Failure: Equatable {}
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest.Event.Kind: Equatable where Success: Equatable, Failure: Equatable {}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1e18)
    }
}

#endif
