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
            // Only received if the server disconnects or we cancel with code, not if we do a simple cancel or error.
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

    public struct Completion: Sendable {
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
        public struct AutomaticPing {
            public enum FailureAction {
                /// Continue automatic pings.
                case `continue`
                /// Stop automatic ping after `count` failures.
                case stopAutomaticPing(count: Int)
                /// Cancel `WebSocketRequest` after `count` failures.
                case cancelRequest(count: Int)
            }

            public var interval: Duration
            public var failureAction: FailureAction

            public init(interval: Duration = .seconds(5), failureAction: FailureAction = .continue) {
                self.interval = interval
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
        /// Did not send the ping, the request is suspended, cancelled, or finished.
        case unsent
        /// An inflight ping was lost due to the request being cancelled or the connection closed.
        case lost
    }

    struct SocketMutableState {
        var enqueuedSends: [@Sendable () -> Void] = []
        var handlers: [@Sendable (_ event: IncomingEvent) -> Void] = []
        var automaticPingTimerItem: DispatchWorkItem?
        var inflightPingHandlers: [UUID: (queue: DispatchQueue, handler: @Sendable (_ result: PingResult) -> Void)] = [:]
    }

    let socketMutableState = Protected(SocketMutableState())
    let requestQueue: DispatchQueue

    // Ensures all sends complete before the final stream event.
    private let sendGroup = DispatchGroup()

    public let convertible: any URLRequestConvertible
    public let configuration: Configuration

    init(id: UUID = UUID(),
         convertible: any URLRequestConvertible,
         configuration: Configuration,
         requestQueue: DispatchQueue,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: (any EventMonitor)?,
         interceptor: (any RequestInterceptor)?,
         shouldAutomaticallyResume: Bool?,
         delegate: any RequestDelegate) {
        self.convertible = convertible
        self.configuration = configuration
        self.requestQueue = requestQueue

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   shouldAutomaticallyResume: shouldAutomaticallyResume,
                   delegate: delegate)
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        var copiedRequest = request
        if !configuration.protocols.isEmpty {
            copiedRequest.headers.update(.websocketProtocol(configuration.protocols.joined(separator: ", ")))
        }
        let task = session.webSocketTask(with: copiedRequest)
        task.maximumMessageSize = configuration.maximumMessageSize

        return task
    }

    override func cleanup() {
        socketMutableState.write { socketMutableState in
            socketMutableState.cancelAutomaticPing()
            socketMutableState = .init()
        }

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

        super.didCreateTask(task)

        startListening()

        performEnqueuedSends()
        // TODO: Enqueue pings?
    }

    private func performEnqueuedSends() {
        // Empty pending messages.
        let enqueuedSends: [@Sendable () -> Void] = socketMutableState.write { socketMutableState in
            guard !socketMutableState.enqueuedSends.isEmpty else { return [] }

            let sends = socketMutableState.enqueuedSends
            socketMutableState.enqueuedSends = []
            return sends
        }

        for send in enqueuedSends {
            // Calls out to send.queue immediately.
            send()
        }
    }

    func didClose() {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        mutableState.write { mutableState in
            // Check whether error is cancellation or other websocket closing error.
            // If so, remove it.
            // Otherwise keep it.
            if case let .sessionTaskFailed(error) = mutableState.error, (error as? URLError)?.code == .cancelled {
                mutableState.error = nil
            }
        }

        // TODO: Add didClose event for web sockets.
    }

    @discardableResult
    public func close(sending closeCode: URLSessionWebSocketTask.CloseCode, reason: Data? = nil) -> Self {
        withBothStates { mutableState, socketMutableState in
            guard mutableState.state.canTransitionTo(.cancelled) else { return }

            socketMutableState.cancelAutomaticPing()

            mutableState.state = .cancelled

            underlyingQueue.async { self.didClose() }

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

        return self
    }

    override func finish(error: AFError? = nil) {
        super.finish(error: error)

        performEnqueuedSends()
    }

    @discardableResult
    override public func cancel() -> Self {
        cancelAutomaticPing()

        return super.cancel()
    }

    func didConnect(protocol: String?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        socketMutableState.read { state in
            for handler in state.handlers {
                // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                handler(.connected(protocol: `protocol`))
            }
        }

        if let automaticPing = configuration.automaticPing {
            startAutomaticPing(every: automaticPing.interval)
        }
    }

    func startAutomaticPing(every pingInterval: TimeInterval) {
        withBothStates { mutableState, socketMutableState in
            guard mutableState.state.is(.resumed) else {
                socketMutableState.cancelAutomaticPing()
                return
            }

            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }

                sendPing(respondingOn: underlyingQueue) { response in
                    // TODO: Use configuration to determine behavior.
                    guard case .pong = response else { return }

                    self.startAutomaticPing(every: pingInterval)
                }
            }

            socketMutableState.automaticPingTimerItem = item
            underlyingQueue.asyncAfter(deadline: .now() + pingInterval, execute: item)
        }
    }

    /// Ensure all access to both states uses the same lock ordering to prevent deadlocks.
    @inline(__always)
    @discardableResult
    fileprivate func withBothStates<Out>(_ perform: (_ mutableState: inout WebSocketRequest.MutableState, _ socketMutableState: inout WebSocketRequest.SocketMutableState) -> Out) -> Out {
        mutableState.write { mutableState in
            socketMutableState.write { socketMutableState in
                perform(&mutableState, &socketMutableState)
            }
        }
    }

    func startAutomaticPing(every duration: Duration) {
        let interval = TimeInterval(duration.components.seconds) + (Double(duration.components.attoseconds) / 1e18)
        startAutomaticPing(every: interval)
    }

    func cancelAutomaticPing() {
        withBothStates { $1.cancelAutomaticPing() }
    }

    func didDisconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        withBothStates { _, socketMutableState in
            socketMutableState.cancelAutomaticPing()
            for handler in socketMutableState.handlers {
                // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                handler(.disconnected(closeCode: closeCode, reason: reason))
            }
        }
    }

    private func startListening() {
        withBothStates { mutableState, _ in
            #if compiler(>=6.2.1)
            weak let request = self
            #else
            weak var request = self
            #endif
            mutableState.listen(onBehalfOf: request)
        }
    }

    // MARK: - Ping

    public func sendPing(respondingOn queue: DispatchQueue = .main, onResponse: @escaping @Sendable (PingResult) -> Void) {
        withBothStates { mutableState, socketMutableState in
            guard mutableState.state.is(.resumed) else {
                queue.async { onResponse(.unsent) }
                return
            }

            let sendID = UUID()
            socketMutableState.inflightPingHandlers[sendID] = (queue: queue, handler: onResponse)
            let startTimestamp = Instant()
            mutableState.socket?.sendPing { [weak self] error in
                guard let self else { return }

                withBothStates { _, socketMutableState in
                    socketMutableState.inflightPingHandlers.removeValue(forKey: sendID)
                }
                // Calls back on delegate queue / rootQueue / underlyingQueue
                if let error {
                    queue.async {
                        onResponse(.error(error))
                    }
                } else {
                    let endTimestamp = Instant()
                    let pong = PingResult.Pong(latency: endTimestamp - startTimestamp)

                    queue.async {
                        onResponse(.pong(pong))
                    }
                }
            }
        }
    }

    public func sendPing() async -> PingResult {
        await withCheckedContinuation { continuation in
            sendPing(respondingOn: .streamCompletionQueue(forRequestID: self.id)) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Sending

    public enum SendError<EncoderFailure>: Error where EncoderFailure: Error {
        /// Attempted to send while the request was in the associated invalid state. Message was dropped.
        case state(Request.State)
        /// Send failed due to the associated encoder error.
        case encoder(EncoderFailure)
        /// Send failed due to the associated `URLSessionWebSocketTask` error.
        case socket(any Error)

        public var failedState: Request.State? {
            guard case let .state(state) = self else { return nil }

            return state
        }
    }

    // TODO: Need async sends to resume request?

    public func send(_ data: Data) async -> Result<Void, SendError<Never>> {
        await withCheckedContinuation { continuation in
            resume().send(.data(data), queue: .streamCompletionQueue(forRequestID: self.id)) { result in
                continuation.resume(returning: result)
            }
        }
    }

    public func send(_ data: Data,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<Never>>) -> Void) {
        send(.data(data), queue: queue, completionHandler: completionHandler)
    }

    public func send(_ string: String,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<Never>>) -> Void) {
        send(.string(string), queue: queue, completionHandler: completionHandler)
    }

    public func send(_ message: URLSessionWebSocketTask.Message,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<Never>>) -> Void) {
        send(message, using: PassthroughWebSocketMessageEncoder(), queue: queue, completionHandler: completionHandler)
    }

    public func send<Value: Encodable>(_ value: Value,
                                       using encoder: any DataEncoder = JSONEncoder(),
                                       queue: DispatchQueue = .main,
                                       completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<EncodableWebSocketMessageEncoder<Value>.Failure>>) -> Void) {
        send(value, using: EncodableWebSocketMessageEncoder(encoder: encoder), completionHandler: completionHandler)
    }

    public func send<Value, MessageEncoder>(_ value: Value,
                                            using encoder: MessageEncoder,
                                            queue: DispatchQueue = .main,
                                            completionHandler: @escaping @Sendable (_ result: Result<Void, SendError<MessageEncoder.Failure>>) -> Void)
    where MessageEncoder: WebSocketMessageEncoder, MessageEncoder.Input == Value {
        sendGroup.enter()
        requestQueue.async { [self] in
            let socketResult: Result<URLSessionWebSocketTask?, SendError<MessageEncoder.Failure>>
            = withBothStates { mutableState, socketMutableState in
                guard !(mutableState.state.is(.cancelled) || mutableState.state.is(.finished)) else {
                    return .failure(.state(mutableState.state))
                }

                guard let socket = mutableState.socket else {
                    // URLSessionWebSocketTask not created yet, enqueue the send.
                    socketMutableState.enqueuedSends.append { [unowned self] in
                        send(value, using: encoder, queue: queue, completionHandler: completionHandler)
                    }
                    return .success(nil)
                }

                return .success(socket)
            }

            guard let successSocket = socketResult.success, let socket = successSocket else {
                if let failure = socketResult.failure {
                    queue.async { completionHandler(.failure(failure)) }
                }
                sendGroup.leave()
                // Otherwise the send has been enqueued for later.
                return
            }

            do throws(MessageEncoder.Failure) {
                let message = try encoder.encode(value)
                socket.send(message) { error in
                    queue.async {
                        completionHandler(Result(value: (), error: error).mapError { .socket($0) })
                    }
                    self.sendGroup.leave()
                }
            } catch {
                queue.async {
                    completionHandler(.failure(.encoder(error)))
                }
                sendGroup.leave()
            }
        }
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
        streamDecodableEvents(Value.self, on: queue) { event in
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
                }
                let handlers = withBothStates { _, socketMutableState in
                    let handlers = socketMutableState.inflightPingHandlers.values
                    socketMutableState.inflightPingHandlers.removeAll()
                    return handlers
                }
                for handler in handlers {
                    handler.queue.async { handler.handler(.lost) }
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
public protocol WebSocketMessageEncoder<Input, Failure>: Sendable {
    associatedtype Input: Sendable
    associatedtype Failure: Error

    func encode(_ input: Input) throws(Failure) -> URLSessionWebSocketTask.Message
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct EncodableWebSocketMessageEncoder<Value: Encodable & Sendable>: WebSocketMessageEncoder {
    public let encoder: any DataEncoder

    public init(encoder: any DataEncoder) {
        self.encoder = encoder
    }

    public func encode(_ input: Value) throws -> URLSessionWebSocketTask.Message {
        try .data(encoder.encode(input))
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct PassthroughWebSocketMessageEncoder: WebSocketMessageEncoder<URLSessionWebSocketTask.Message, Never> {
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
                request.withBothStates { mutableState, socketMutableState in
                    for handler in socketMutableState.handlers {
                        // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                        handler(.receivedMessage(message))
                    }

                    #if compiler(>=6.2.1)
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

#endif
