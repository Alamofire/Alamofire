//
//  WebSocketTests.swift
//
//  Copyright (c) 2021-2026 Alamofire Software Foundation (http://alamofire.org/)
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

@testable import Alamofire
import Foundation
import Testing

@Suite
struct WebSocketTests {
    @Test
    func messageEventsCanBeStreamed() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket()).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected, .receivedMessage, .disconnected, .completed])
    }

    @Test
    func messagesCanBeStreamed() async {
        // Given
        let session = Session()

        // When
        let messages = await session.webSocketRequest(.websocket()).streamingMessages().collect()

        // Then
        #expect(messages.count == 1)
    }

    @Test
    func finishedRequestsGetOnlyCompletionEvent() async {
        // Given
        let session = Session()

        // When
        let socket = session.webSocketRequest(.websocket())
        let messages = await socket.streamingMessages().collect()

        // Then
        #expect(messages.count == 1)

        // When: another listener is attached.
        let moreMessages = await socket.streamingMessageEvents().collect()

        // Then
        #expect(moreMessages.count == 1)
    }

    @Test
    func webSocketsCanReceiveMessageEvents() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket()).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanReceiveMessageEventsWithParameters() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket()).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanReceiveAMessage() async throws {
        // Given
        let session = Session()

        // When
        let messages = await session.webSocketRequest(.websocket()).streamingMessages().collect()

        // Then
        try #require(messages.count == 1)
        #expect(messages[0].data != nil)
    }

    @Test
    func webSocketsCanReceiveADecodableMessage() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocketCount(1)).streamingDecodableEvents(TestResponse.self).collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanReceiveADecodableValue() async {
        // Given
        let session = Session()

        // When
        let values = await session.webSocketRequest(.websocket()).streamingDecodable(TestResponse.self).collect()

        // Then
        #expect(values.count == 1)
    }

    @Test
    func webSocketsCanReceiveADecoderFailure() async {
        // Given
        struct Unmatched: Decodable, Equatable, Sendable, TestKindReceivedValue {
            let doesNotExist: Int
        }

        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket()).streamingDecodableEvents(Unmatched.self).collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .decoderFailed,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanStreamMessagesUsingAHandler() async {
        // Given
        let session = Session()
        let messages = Protected<[URLSessionWebSocketTask.Message]>([])

        // When
        let request = session.webSocketRequest(.websocket())
        request.streamMessages { message in messages.write { $0.append(message) } }
        _ = await request.streamingMessageEvents().collect()

        // Then
        let received = messages.read { $0 }
        #expect(received.count == 1 && TestMessage.data.matches(received[0]))
    }

    @Test
    func webSocketsCanStreamDecodableValuesUsingAHandler() async {
        // Given
        let session = Session()
        let values = Protected<[TestResponse]>([])

        // When
        let request = session.webSocketRequest(.websocketCount(1))
        request.streamDecodable(TestResponse.self) { value in values.write { $0.append(value) } }
        _ = await request.streamingMessageEvents().collect()

        // Then
        #expect(values.read { $0 }.count == 1)
    }

    @Test
    func webSocketsCanReceiveAMessageWithAProtocol() async {
        // Given
        let session = Session()
        let `protocol` = "protocol"

        // When
        let events = await session.webSocketRequest(.websocket(), configuration: .protocols([`protocol`])).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: `protocol`),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanReceiveAMessageGivenMultipleProtocols() async {
        // Given
        let session = Session()
        let protocols = ["first", "second"]

        // When
        let events = await session.webSocketRequest(.websocket(), configuration: .protocols(protocols)).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: "first"),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanReceiveMultipleMessages() async {
        // Given
        let count = 5
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocketCount(count)).streamingMessageEvents().collect()

        // Then
        let expected: [TestKind<TestMessage>] = [.connected(protocol: nil)] +
            Array(repeating: .receivedMessage, count: count) +
            [.disconnected(closeCode: .normalClosure, reason: nil), .completed(error: .nil)]
        #expect(events == expected)
    }

    @Test
    func webSocketsCanSendAndReceiveMessages() async {
        // Given
        let session = Session()
        let sentMessage = URLSessionWebSocketTask.Message.string("Echo")

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            switch event.kind {
            case .connected:
                request.send(sentMessage) { _ in }
            case .receivedMessage:
                event.socket?.close(sending: .normalClosure)
            default:
                break
            }
        }
        let events = await request.streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage(.string("Echo")),
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanCloseWithAReason() async {
        // Given
        let session = Session()
        let reason = Data("bye".utf8)

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            if case .connected = event.kind {
                request.close(sending: .normalClosure, reason: reason)
            }
        }
        let events = await request.streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .disconnected(closeCode: .normalClosure, reason: reason),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanSendAndReceiveCodableMessages() async {
        // Given
        struct CodableMessage: Equatable, Codable, Sendable, TestKindReceivedValue {
            var field = "value"
        }

        let session = Session()
        let sentMessage = CodableMessage()

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamDecodableEvents(CodableMessage.self) { [unowned request] event in
            switch event.kind {
            case .connected:
                request.send(sentMessage) { _ in }
            case .receivedMessage:
                event.socket?.close(sending: .normalClosure)
            default:
                break
            }
        }
        let events = await request.streamingDecodableEvents(CodableMessage.self).collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage(sentMessage),
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanBeCancelled() async {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            if case .connected = event.kind {
                request.cancel()
            }
        }
        let events = await request.streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: nil), .completed(error: .nonNil)])

        guard case let .completed(completion) = events.last?.kind else {
            Issue.record("Expected last event to be .completed")
            return
        }
        #expect(completion.error?.isExplicitlyCancelledError == true)
        #expect(request.error?.isExplicitlyCancelledError == true)
    }

    @Test
    func webSocketsWithPendingSendsCompleteTheSendsOnCancellation() async {
        // Given
        let session = Session(startRequestsImmediately: false)

        // When
        let request = session.webSocketRequest(.websocketEcho)
        async let events = request.streamingMessageEvents().collect()
        async let sendResult: Result<Void, WebSocketRequest.SendError<Never>> = request.send("hello")
        request.cancel()
        let (collectedEvents, receivedSendResult) = await (events, sendResult)

        // Then
        #expect(collectedEvents == [.completed(error: .nonNil)])

        guard case let .completed(completion) = collectedEvents.first?.kind else {
            Issue.record("Expected event to be .completed")
            return
        }
        #expect(completion.error?.isExplicitlyCancelledError == true)
        #expect(request.error?.isExplicitlyCancelledError == true)
        #expect(receivedSendResult.failure?.failedState == .cancelled)
    }

    @Test
    func webSocketsFlushEnqueuedSendsOnceConnected() async {
        // Given
        let session = Session(startRequestsImmediately: false)
        let sentMessage = URLSessionWebSocketTask.Message.string("queued")

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            if case .receivedMessage = event.kind {
                request.close(sending: .normalClosure)
            }
        }
        async let events = request.streamingMessageEvents().collect()
        async let sendResult: Result<Void, WebSocketRequest.SendError<Never>> = request.send(sentMessage)
        request.resume()
        let (collectedEvents, receivedSendResult) = await (events, sendResult)

        // Then
        #expect(receivedSendResult.isSuccess)
        #expect(collectedEvents == [.connected(protocol: nil),
                                    .receivedMessage(.string("queued")),
                                    .disconnected(closeCode: .normalClosure, reason: nil),
                                    .completed(error: .nil)])
    }

    @Test
    func sendAfterCompletionFailsWithFinishedState() async {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocket())
        _ = await request.streamingMessageEvents().collect()
        let result: Result<Void, WebSocketRequest.SendError<Never>> = await request.send("late")

        // Then
        #expect(result.failure?.failedState == .finished)
    }

    @Test
    func sendFailsWithEncoderError() async {
        // Given
        struct EncodingFailure: Error, Equatable {}
        struct ThrowingEncoder: DataEncoder {
            func encode<Value>(_ value: Value) throws -> Data where Value: Encodable {
                throw EncodingFailure()
            }
        }

        let session = Session()

        // When
        // Attaching a stream is required to trigger the request's resume, since sending alone won't start it.
        let request = session.webSocketRequest(.websocketEcho)
        async let events = request.streamingMessageEvents().collect()
        let result: Result<Void, WebSocketRequest.SendError<any Error>> = await request.send("hello", using: ThrowingEncoder())
        request.cancel()
        _ = await events

        // Then
        let isEncoderFailure = result.failure.map { failure in
            if case .encoder = failure { true } else { false }
        } ?? false
        #expect(isEncoderFailure)
    }

    @Test
    func onePingOnly() async {
        // Given
        let session = Session()
        let sentMessage = URLSessionWebSocketTask.Message.string("Echo")
        var receivedPong: WebSocketRequest.PingResult.Pong?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        var events: [WebSocketRequest.Event<URLSessionWebSocketTask.Message, Never>] = []
        for await event in request.streamingMessageEvents() {
            events.append(event)
            switch event.kind {
            case .connected:
                let result: Result<Void, WebSocketRequest.SendError<Never>> = await request.send(sentMessage)
                _ = result
            case .receivedMessage:
                for count in 0..<100 {
                    let response = await request.sendPing()
                    if case let .pong(pong) = response {
                        receivedPong = pong
                    }
                    if count == 99 {
                        request.close(sending: .normalClosure)
                    }
                }
            default:
                break
            }
        }

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage(.string("Echo")),
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
        #expect(receivedPong != nil)
    }

    @Test
    func sendPingReturnsUnsentAfterCompletion() async {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocket())
        _ = await request.streamingMessageEvents().collect()
        let result = await request.sendPing()

        // Then
        let isUnsent = if case .unsent = result { true } else { false }
        #expect(isUnsent)
    }

    @Test
    func sendPingIsLostWhenCancelledBeforeConnecting() async {
        // Given
        let session = Session()

        // When
        // `resume()` synchronously flips the request into `.resumed`, but actual task creation happens
        // asynchronously via the session, so the ping registered immediately afterward is guaranteed to be sent
        // before any socket exists. It's therefore never actually dispatched to the OS and stays inflight until
        // `cancel()` finishes the request, at which point it's drained and reported as `.lost`.
        let request = session.webSocketRequest(.websocketEcho)
        request.resume()
        request.streamMessageEvents { _ in }
        let pingResult = await withCheckedContinuation { continuation in
            request.sendPing { result in continuation.resume(returning: result) }
            request.cancel()
        }

        // Then
        let isLost = if case .lost = pingResult { true } else { false }
        #expect(isLost)
    }

    @Test
    func timePingsOccur() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocketPings(), configuration: .pingInterval(0.01))
            .streamingMessageEvents()
            .collect()

        // Then
        #expect(events == [.connected,
                           .disconnected(closeCode: .goingAway, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketFailsWithTooSmallMaximumMessageSize() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket(), configuration: .maximumMessageSize(1))
            .streamingMessageEvents()
            .collect()

        // Then
        #expect(events == [.connected, .completed(error: .nonNil)])
    }

    @Test
    func webSocketsFinishAfterNonNormalResponseCode() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket(closeCode: .goingAway)).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected,
                           .receivedMessage(.data),
                           .disconnected(closeCode: .goingAway, reason: nil),
                           .completed(error: .nil)])
    }

    @Test
    func webSocketsCanHaveMultipleHandlers() async {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocket(closeCode: .goingAway))
        async let firstEvents = request.streamingMessageEvents().collect()
        async let secondEvents = request.streamingMessageEvents().collect()
        let (first, second) = await (firstEvents, secondEvents)

        // Then
        let expected: [TestKind<TestMessage>] = [.connected(protocol: nil),
                                                 .receivedMessage(.data),
                                                 .disconnected(closeCode: .goingAway, reason: nil),
                                                 .completed(error: .nil)]
        #expect(first == expected)
        #expect(second == expected)
        #expect(first == second)
    }

    @Test
    func completedEventCarriesRequestResponseAndMetrics() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket()).streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(request: .nonNil, response: .nonNil, metrics: .nonNil, error: .nil)])
    }

    @Test
    func streamNotAutomaticallyCancellingLeavesRequestAlive() async {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocketEcho)
        let stream = request.streamingMessageEvents(automaticallyCancelling: false)
        _ = await stream.first { if case .connected = $0.kind { true } else { false } }
        let ping = await request.sendPing()

        // Then
        let isPong = if case .pong = ping { true } else { false }
        #expect(isPong)

        // Cleanup: the request is still alive, so it must be explicitly finished.
        request.cancel()
    }

    @Test
    func webSocketsRespectBufferingPolicy() async throws {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocketCount(5))
        let stream = request.streamingMessageEvents(bufferingPolicy: .bufferingNewest(1))
        // Give the socket time to receive and buffer every event before consuming any of them, ensuring the
        // buffering policy actually drops older buffered elements rather than just keeping up in real time.
        try await Task.sleep(for: .milliseconds(200))
        let events = await stream.collect()

        // Then
        #expect(events == [.completed(error: .nil)])
    }

//    @Test
//    func sendingBeforeListening() async {
//        // Given
//        let session = Session()
//
//        // When
//        let socket = session.webSocketRequest(.websocket())
//        let send = await socket.send(Data("hello".utf8))
//        #expect(send.isSuccess)
//        let events = await socket.streamingMessageEvents().collect()
//        let otherSend = await socket.send(Data("hello".utf8))
//
//        // Then
//        #expect(events.count == 4)
//    }
//
//    @Test
//    func multiplePingsWithClose() async {
//        // Given
//        let session = Session()
//
//        // When
//        let socket = session.webSocketRequest(.websocketPings(count: 2))
//        let eventStream = socket.streamingMessageEvents(automaticallyCancelling: false)
////        async let _events = eventStream.collect()
//        _ = await eventStream.first { if case .connected = $0.kind { true } else { false } }
//        let firstPing = await socket.sendPing()
//        let secondPing = await socket.sendPing()
////        let events = await _events
//        // Then
////        #expect(events.count == 4)
//        let isFirstPong = if case .pong = firstPing { true } else { false }
//        let isSecondLost = if case .lost = secondPing { true } else { false }
//        #expect(isFirstPong == true)
//        #expect(isSecondLost == true)
//        print(firstPing, secondPing)
//    }
}

@Suite
struct WebSocketIntegrationTests {
    @Test
    func webSocketsCanReceiveMessageEventsAfterRetry() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(performing: .endpoints(.status(500), .websocket()),
                                                    interceptor: .retryPolicy)
            .streamingMessageEvents()
            .collect()

        // Then
        #expect(events == [.connected(protocol: nil),
                           .receivedMessage,
                           .disconnected(closeCode: .normalClosure, reason: nil),
                           .completed(error: .nil)])
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Foundation.URLSessionWebSocketTask.Message: Swift.Equatable {
    public static func ==(lhs: URLSessionWebSocketTask.Message, rhs: URLSessionWebSocketTask.Message) -> Bool {
        switch (lhs, rhs) {
        case let (.string(left), .string(right)):
            left == right
        case let (.data(left), .data(right)):
            left == right
        default:
            false
        }
    }

    var string: String? {
        guard case let .string(string) = self else { return nil }

        return string
    }

    var data: Data? {
        guard case let .data(data) = self else { return nil }

        return data
    }
}

/// Marker protocol opting a decoded event payload into direct-equality comparisons via `TestKind.receivedMessage`.
/// Conform a type used as a `WebSocketRequest.Event`'s `Success` (e.g. with `streamDecodableEvents`) to enable
/// `TestKind<YourType>` comparisons. `URLSessionWebSocketTask.Message` intentionally does not conform: its raw
/// message payloads are compared via `TestMessage` instead, which supports wildcard/partial matching rather than
/// requiring an exact value.
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate protocol TestKindReceivedValue: Equatable, Sendable {}

/// Opts `TestResponse` into `TestKind`'s generic same-type comparison path.
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension TestResponse: TestKindReceivedValue {}

/// Mirrors `URLSessionWebSocketTask.Message`, supporting wildcard matching of both its case and its payload. Used
/// as `TestKind<TestMessage>` to compare against raw message events (e.g. from `streamMessageEvents`).
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate enum TestMessage: TestKindReceivedValue {
    case data(Data?)
    case string(String?)

    /// Matches any `.data` message, regardless of its payload.
    static var data: TestMessage { .data(nil) }
    /// Matches any `.string` message, regardless of its payload.
    static var string: TestMessage { .string(nil) }

    func matches(_ message: URLSessionWebSocketTask.Message) -> Bool {
        switch (self, message) {
        case let (.data(expected), .data(actual)):
            expected == nil || expected == actual
        case let (.string(expected), .string(actual)):
            expected == nil || expected == actual
        default:
            false
        }
    }
}

/// A value which can be compared, partially or fully, against a real `WebSocketRequest.Event<Success, _>.Kind`
/// value produced while streaming events. `Success` is either `TestMessage` (for raw message events, see the
/// dedicated overloads below) or any type conforming to `TestKindReceivedValue` (for decoded events).
///
/// Every case mirrors one of `Kind`'s cases but wraps its payload (or sub-payload) in an `Optional`. A `nil`
/// payload acts as a wildcard, matching any value in that position, while a non-`nil` payload requires an exact
/// match. Each case is also available without a payload at all (as a bare `static var` shadowing the case itself),
/// which is equivalent to passing `nil` for every one of its associated values, e.g.:
///
/// ```swift
/// event.kind == .receivedMessage                       // Matches any `.receivedMessage`, regardless of payload.
/// event.kind == .receivedMessage(.data)                // Matches any `.receivedMessage(.data)`, any `Data`.
/// event.kind == .receivedMessage(.data(expectedData))  // Matches only `.receivedMessage(.data(expectedData))`.
/// event.kind == .receivedMessage(decodedValue)         // Matches only `.receivedMessage(decodedValue)`.
/// ```
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate enum TestKind<Success: TestKindReceivedValue>: Equatable {
    case connected(protocol: String??)
    case receivedMessage(Success?)
    case decoderFailed
    case disconnected(closeCode: URLSessionWebSocketTask.CloseCode?, reason: Data??)
    /// Matches a `.completed` event. Each parameter defaults to `nil`, acting as a wildcard for that field of the
    /// real `WebSocketRequest.Completion`; passing `.present` or `.absent` requires the field to be non-`nil` or
    /// `nil`, respectively, without comparing the wrapped value itself.
    case completed(request: Presence? = nil,
                   response: Presence? = nil,
                   metrics: Presence? = nil,
                   error: Presence? = nil)

    /// Whether a field on the real `WebSocketRequest.Completion` payload is expected to be `nil` or non-`nil`.
    enum Presence: Equatable {
        case nonNil, `nil`

        init<Wrapped>(_ value: Wrapped?) { self = value == nil ? .nil : .nonNil }
    }

    /// Matches any `.connected` event, regardless of negotiated protocol.
    static var connected: TestKind { .connected(protocol: nil) }
    /// Matches any `.receivedMessage` event, regardless of message.
    static var receivedMessage: TestKind { .receivedMessage(nil) }
    /// Matches any `.disconnected` event, regardless of close code or reason.
    static var disconnected: TestKind { .disconnected(closeCode: nil, reason: nil) }
    /// Matches any `.completed` event, regardless of completion payload.
    static var completed: TestKind { .completed() }

    /// Matches every case that doesn't depend on `Success` (i.e. everything but `.receivedMessage`). Returns `nil`
    /// when both sides are `.receivedMessage`, deferring that comparison to the caller, since the strategy used to
    /// compare `Success` values differs between raw-message and decoded-value flavors of `TestKind`.
    fileprivate func matchesNonMessageFields<ActualSuccess, Failure>(
        _ kind: WebSocketRequest.Event<ActualSuccess, Failure>.Kind
    ) -> Bool? {
        switch (self, kind) {
        case let (.connected(expectedProtocol), .connected(protocol: actualProtocol)):
            expectedProtocol == nil || expectedProtocol == actualProtocol
        case (.receivedMessage, .receivedMessage):
            nil
        case (.decoderFailed, .decoderFailed):
            true
        case let (.disconnected(expectedCloseCode, expectedReason), .disconnected(closeCode: actualCloseCode, reason: actualReason)):
            (expectedCloseCode == nil || expectedCloseCode == actualCloseCode) &&
                (expectedReason == nil || expectedReason == actualReason)
        case let (.completed(expectedRequest, expectedResponse, expectedMetrics, expectedError), .completed(actualCompletion)):
            (expectedRequest == nil || expectedRequest == Presence(actualCompletion.request)) &&
                (expectedResponse == nil || expectedResponse == Presence(actualCompletion.response)) &&
                (expectedMetrics == nil || expectedMetrics == Presence(actualCompletion.metrics)) &&
                (expectedError == nil || expectedError == Presence(actualCompletion.error))
        default:
            false
        }
    }

    /// Matches a decoded event whose real `Success` payload is directly `Equatable` to `Self.Success`.
    func matches<Failure>(_ kind: WebSocketRequest.Event<Success, Failure>.Kind) -> Bool {
        if let result = matchesNonMessageFields(kind) { return result }

        guard case let .receivedMessage(expected) = self, case let .receivedMessage(actual) = kind else { return false }

        return expected == nil || expected == actual
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension TestKind where Success == TestMessage {
    /// Matches a raw message event, whose real `Success` payload (`URLSessionWebSocketTask.Message`) is compared
    /// via `TestMessage`'s wildcard/partial matching rather than direct equality.
    func matches<Failure>(_ kind: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>.Kind) -> Bool {
        guard case let .receivedMessage(expected) = self else { return matchesNonMessageFields(kind) ?? false }
        guard case let .receivedMessage(actual) = kind else { return false }

        return expected == nil || expected!.matches(actual)
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>.Kind, rhs: TestKind<TestMessage>) -> Bool {
    rhs.matches(lhs)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: TestKind<TestMessage>, rhs: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>.Kind) -> Bool {
    lhs.matches(rhs)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: [WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>.Kind], rhs: [TestKind<TestMessage>]) -> Bool {
    guard lhs.count == rhs.count else { return false }

    return zip(lhs, rhs).allSatisfy { $0 == $1 }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: [TestKind<TestMessage>], rhs: [WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>.Kind]) -> Bool {
    rhs == lhs
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>, rhs: TestKind<TestMessage>) -> Bool {
    rhs.matches(lhs.kind)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: TestKind<TestMessage>, rhs: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>) -> Bool {
    lhs.matches(rhs.kind)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: [WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>], rhs: [TestKind<TestMessage>]) -> Bool {
    guard lhs.count == rhs.count else { return false }

    return zip(lhs, rhs).allSatisfy { $0 == $1 }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Failure>(lhs: [TestKind<TestMessage>], rhs: [WebSocketRequest.Event<URLSessionWebSocketTask.Message, Failure>]) -> Bool {
    rhs == lhs
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: WebSocketRequest.Event<Success, Failure>.Kind, rhs: TestKind<Success>) -> Bool {
    rhs.matches(lhs)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: TestKind<Success>, rhs: WebSocketRequest.Event<Success, Failure>.Kind) -> Bool {
    lhs.matches(rhs)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: [WebSocketRequest.Event<Success, Failure>.Kind], rhs: [TestKind<Success>]) -> Bool {
    guard lhs.count == rhs.count else { return false }

    return zip(lhs, rhs).allSatisfy { $0 == $1 }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: [TestKind<Success>], rhs: [WebSocketRequest.Event<Success, Failure>.Kind]) -> Bool {
    rhs == lhs
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: WebSocketRequest.Event<Success, Failure>, rhs: TestKind<Success>) -> Bool {
    rhs.matches(lhs.kind)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: TestKind<Success>, rhs: WebSocketRequest.Event<Success, Failure>) -> Bool {
    lhs.matches(rhs.kind)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: [WebSocketRequest.Event<Success, Failure>], rhs: [TestKind<Success>]) -> Bool {
    guard lhs.count == rhs.count else { return false }

    return zip(lhs, rhs).allSatisfy { $0 == $1 }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
fileprivate func == <Success: TestKindReceivedValue, Failure>(lhs: [TestKind<Success>], rhs: [WebSocketRequest.Event<Success, Failure>]) -> Bool {
    rhs == lhs
}

#endif
