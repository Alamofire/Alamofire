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
        await withCheckedContinuation { continuation in
            request.streamMessages { message in
                messages.write { $0.append(message) }
                continuation.resume()
            }
        }

        // Then
        let received = messages.read { $0 }
        #expect(received.count == 1 && TestMessage.data.matches(received[0]))

        await request.cancelAndWaitForFinish()
    }

    @Test
    func webSocketsCanStreamDecodableValuesUsingAHandler() async {
        // Given
        let session = Session()
        let values = Protected<[TestResponse]>([])

        // When
        let request = session.webSocketRequest(.websocketCount(1))
        await withCheckedContinuation { continuation in
            request.streamDecodable(TestResponse.self) { value in
                values.write { $0.append(value) }
                continuation.resume()
            }
        }

        // Then
        #expect(values.read { $0 }.count == 1)

        await request.cancelAndWaitForFinish()
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
    func sendReturnsStateErrorBeforeResume() async {
        // Given
        let session = Session(startRequestsImmediately: false)
        let request = session.webSocketRequest(.websocketEcho)

        // When
        let result: Result<Void, WebSocketRequest.SendError<Never>> = await request.send("hello")

        // Then
        #expect(result.failure?.failedState == .initialized)
    }

    @Test
    func sendAndPingAreAcceptedWhileAutomaticResumeIsPending() async {
        // Given
        let rootQueue = DispatchQueue(label: "org.alamofire.testRootQueue")
        let session = Session(rootQueue: rootQueue)
        let request = session.webSocketRequest(.websocketEcho)
        // Prevent the automatic resume scheduled by adding a handler from running until after the send and ping.
        rootQueue.suspend()
        request.streamMessageEvents { _ in }

        // When
        let sendResult = Protected<Result<Void, WebSocketRequest.SendError<Never>>?>(nil)
        let pingResult = Protected<WebSocketRequest.PingResult?>(nil)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let remaining = Protected(2)
            let complete: @Sendable () -> Void = {
                if remaining.write({ $0 -= 1; return $0 }) == 0 { continuation.resume() }
            }
            request.send("hello", queue: .global()) { result in sendResult.write { $0 = result }; complete() }
            request.sendPing(respondingOn: .global()) { result in pingResult.write { $0 = result }; complete() }
            rootQueue.resume()
        }

        // Then
        #expect(sendResult.read { $0?.isSuccess } == true, "Send completed with \(String(describing: sendResult.read { $0 })).")
        let isPong = if case .pong = pingResult.read({ $0 }) { true } else { false }
        #expect(isPong, "Ping completed with \(String(describing: pingResult.read { $0 })) rather than .pong.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func webSocketsWithPendingSendsCompleteTheSendsOnCancellation() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho, interceptor: ConnectionGate())
        request.resume()

        // When
        let stream = request.streamingMessageEvents()
        async let events = stream.collect()
        let receivedSendResult = await withCheckedContinuation { continuation in
            request.send("hello") { result in continuation.resume(returning: result) }
            request.cancel()
        }
        let collectedEvents = await events

        // Then
        #expect(collectedEvents == [.completed(error: .nonNil)])

        guard case let .completed(completion) = collectedEvents.first?.kind else {
            Issue.record("Expected event to be .completed")
            return
        }
        #expect(completion.error?.isExplicitlyCancelledError == true)
        #expect(request.error?.isExplicitlyCancelledError == true)
        #expect(receivedSendResult.failure?.isLost == true)
    }

    @Test
    func pendingSendIsLostWhenCancelledWithoutStreamHandlers() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho, interceptor: ConnectionGate())
        request.resume()

        // When
        let result = await withCheckedContinuation { continuation in
            request.send("hello") { result in continuation.resume(returning: result) }
            request.cancel()
        }

        // Then
        #expect(result.failure?.isLost == true, "Send completed with \(result) rather than .lost.")
    }

    @Test
    func pendingSendIsLostWhenClosedWithoutStreamHandlers() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho, interceptor: ConnectionGate())
        request.resume()

        // When
        let result = await withCheckedContinuation { continuation in
            request.send("hello") { result in continuation.resume(returning: result) }
            request.close(sending: .normalClosure)
        }

        // Then
        #expect(result.failure?.isLost == true, "Send completed with \(result) rather than .lost.")
    }

    @Test
    func sendReturnsLostWhenTaskIsCancelledBeforeSending() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho, interceptor: ConnectionGate())
        request.resume()

        // When
        let sendTask = Task { () -> Result<Void, WebSocketRequest.SendError<Never>> in await request.send("hello") }
        sendTask.cancel()
        let result = await sendTask.value

        // Then
        #expect(result.failure?.isLost == true, "Send completed with \(result) rather than .lost.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func webSocketsFlushEnqueuedSendsOnceConnected() async {
        // Given
        let session = Session()
        let sentMessage = URLSessionWebSocketTask.Message.string("queued")

        // When
        let gate = ConnectionGate()
        let request = session.webSocketRequest(.websocketEcho, interceptor: gate)
        request.streamMessageEvents { [unowned request] event in
            if case .receivedMessage = event.kind {
                request.close(sending: .normalClosure)
            }
        }
        let stream = request.streamingMessageEvents()
        async let events = stream.collect()
        let receivedSendResult = await withCheckedContinuation { continuation in
            request.send(sentMessage) { result in continuation.resume(returning: result) }
            gate.open()
        }
        let collectedEvents = await events

        // Then
        #expect(receivedSendResult.isSuccess)
        #expect(collectedEvents == [.connected(protocol: nil),
                                    .receivedMessage(.string("queued")),
                                    .disconnected(closeCode: .normalClosure, reason: nil),
                                    .completed(error: .nil)])
    }

    @Test
    func sendsBeforeConnectingAreSentInOrder() async {
        // Given
        let session = Session()
        let messages = (0..<20).map { "\($0)" }
        let received = Protected<[String]>([])

        // When
        let gate = ConnectionGate()
        let request = session.webSocketRequest(.websocketEcho, interceptor: gate)
        request.streamMessageEvents { [unowned request] event in
            guard case let .receivedMessage(.string(string)) = event.kind else { return }

            let count = received.write { $0.append(string); return $0.count }
            if count == messages.count {
                request.close(sending: .normalClosure)
            }
        }
        let stream = request.streamingMessageEvents()
        async let events = stream.collect()
        let results = Protected<[String]>([])
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let remaining = Protected(messages.count)
            for message in messages {
                request.send(message, queue: .main) { result in
                    if result.isSuccess { results.write { $0.append(message) } }
                    if remaining.write({ $0 -= 1; return $0 }) == 0 { continuation.resume() }
                }
            }
            gate.open()
        }
        _ = await events

        // Then
        #expect(results.read { $0 } == messages)
        #expect(received.read { $0 } == messages)
    }

    @Test
    func sendCompletionHandlersAreCalledBeforeCompletion() async {
        // Given
        let session = Session()
        let sendsCompleted = Protected(0)

        // When
        let request = session.webSocketRequest(.websocketEcho, interceptor: ConnectionGate())
        let sendCountAtCompletion = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            request.streamMessageEvents { event in
                if case .completed = event.kind {
                    continuation.resume(returning: sendsCompleted.read { $0 })
                }
            }
            for index in 0..<5 {
                // Concurrent queue ensures handlers aren't ordered before `.completed` merely by queue order.
                request.send("\(index)", queue: .global()) { _ in sendsCompleted.write { $0 += 1 } }
            }
            request.close(sending: .normalClosure)
        }

        // Then
        #expect(sendCountAtCompletion == 5)
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
        let request = session.webSocketRequest(.websocketEcho)
        let stream = request.streamingMessageEvents()
        async let events = stream.collect()
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
    func sendPingReturnsUnsentBeforeResume() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho)

        // When
        let result = await request.sendPing()

        // Then
        let isUnsent = if case .unsent = result { true } else { false }
        #expect(isUnsent, "Unresumed request completed ping with \(result) rather than .unsent.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func sendPingBeforeConnectingIsSentOnceConnected() async throws {
        // Given
        let session = Session()
        let gate = ConnectionGate()
        let request = session.webSocketRequest(.websocketPings(count: 10), interceptor: gate)
        request.resume()
        let timeout = Duration.milliseconds(250)

        // When: ping is sent with a resumed request, but the socket isn't connected until after the timeout elapses.
        async let pingResult = request.sendPing(timeout: timeout)
        // Only a minimum wait, which can't cause a spurious failure, as the ping can't be sent until the gate opens.
        try await Task.sleep(for: timeout * 2)
        gate.open()
        let result = await pingResult

        // Then: the ping waits for the connection, and the timeout only applies once it's sent.
        let isPong = if case .pong = result { true } else { false }
        #expect(isPong, "Ping sent before connection completed with \(result) rather than .pong.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func sendPingTimesOutWhenPongIsDelayed() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketPings(count: 10, pongDelay: 2000))
        request.resume()

        // When
        let result = await request.sendPing(timeout: .milliseconds(100))

        // Then
        let isTimedOut = if case .timedOut = result { true } else { false }
        #expect(isTimedOut, "Ping completed with \(result) rather than .timedOut.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func sendPingWithTimeoutReceivesPong() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho)
        request.resume()

        // When
        let result = await request.sendPing(timeout: .seconds(10))

        // Then
        let isPong = if case .pong = result { true } else { false }
        #expect(isPong, "Ping completed with \(result) rather than .pong.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func pendingPingIsLostWhenCancelledWithoutStreamHandlers() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketPings(count: 10), interceptor: ConnectionGate())
        request.resume()

        // When
        let result = await withCheckedContinuation { continuation in
            request.sendPing { result in continuation.resume(returning: result) }
            request.cancel()
        }

        // Then
        let isLost = if case .lost = result { true } else { false }
        #expect(isLost, "Ping completed with \(result) rather than .lost.")
    }

    @Test
    func pendingPingIsLostWhenClosedWithoutStreamHandlers() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketPings(count: 10), interceptor: ConnectionGate())
        request.resume()

        // When
        let result = await withCheckedContinuation { continuation in
            request.sendPing { result in continuation.resume(returning: result) }
            request.close(sending: .normalClosure)
        }

        // Then
        let isLost = if case .lost = result { true } else { false }
        #expect(isLost, "Ping completed with \(result) rather than .lost.")
    }

    @Test
    func sendPingReturnsLostWhenTaskIsCancelled() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketPings(count: 10), interceptor: ConnectionGate())
        request.resume()

        // When
        let pingTask = Task { await request.sendPing() }
        pingTask.cancel()
        let result = await pingTask.value

        // Then
        let isLost = if case .lost = result { true } else { false }
        #expect(isLost, "Ping completed with \(result) rather than .lost.")

        await request.cancelAndWaitForFinish()
    }

    @Test
    func sendPingIsLostWhenCancelledBeforeConnecting() async {
        // Given
        let session = Session()

        // When
        let request = session.webSocketRequest(.websocketEcho, interceptor: ConnectionGate())
        request.resume()
        request.streamMessageEvents { _ in }
        let pingResult = await withCheckedContinuation { continuation in
            request.sendPing { result in continuation.resume(returning: result) }
            request.cancel()
        }

        // Then
        let isLost = if case .lost = pingResult { true } else { false }
        #expect(isLost)

        await request.cancelAndWaitForFinish()
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
    func automaticPingTimeoutsCancelRequest() async {
        // Given
        let session = Session()
        let automaticPing = WebSocketRequest.Configuration.AutomaticPing(interval: .milliseconds(10),
                                                                         timeout: .milliseconds(50),
                                                                         failureAction: .cancelRequest(count: 2))

        // When
        let events = await session.webSocketRequest(.websocketPings(count: 100, pongDelay: 2000),
                                                    configuration: .init(automaticPing: automaticPing))
            .streamingMessageEvents()
            .collect()

        // Then
        #expect(events == [.connected, .completed(error: .nonNil)])
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
        let firstStream = request.streamingMessageEvents()
        let secondStream = request.streamingMessageEvents()
        async let firstEvents = firstStream.collect()
        async let secondEvents = secondStream.collect()
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
        await request.cancelAndWaitForFinish()
    }

    @Test
    func closingBeforeConnectingCompletesWithoutCancellationError() async {
        // Given
        let session = Session()

        // When
        // The server doesn't accept the connection during the test, so the task never connects. The delay is never
        // waited on, as the close cancels the task.
        let request = session.webSocketRequest(.websocketEcho(openDelay: 60_000))
        request.onURLSessionTaskCreation { _ in request.close(sending: .normalClosure) }
        let events = await request.streamingMessageEvents().collect()

        // Then
        #expect(events == [.completed(error: .nil)])
        #expect(request.error == nil)
    }

    @Test
    func taskCompletingAfterFinishDoesNotFinishAgain() async {
        // Given
        let finishCount = Protected(0)
        let monitorQueue = DispatchQueue(label: "org.alamofire.tests.finishCount")
        let monitor = ClosureEventMonitor(queue: monitorQueue)
        monitor.requestDidFinish = { _ in finishCount.write { $0 += 1 } }
        let session = Session(startRequestsImmediately: false, eventMonitors: [monitor])
        let request = session.webSocketRequest(.websocketEcho)

        // When
        await withCheckedContinuation { continuation in
            request.onFinish { continuation.resume() }
            request.close(sending: .goingAway)
        }
        // Simulate a task created while `close` raced the request's start, which completes after the request has
        // already finished.
        let task = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:8080")!)
        request.underlyingQueue.async { request.didCompleteTask(task, with: nil) }
        // Wait for any finish the completion triggers: `didCompleteTask` and `notifyRequestDidFinish` each run on
        // `underlyingQueue`, then `requestDidFinish` is delivered on the monitor's queue.
        await request.underlyingQueue.pendingWork()
        await request.underlyingQueue.pendingWork()
        await monitorQueue.pendingWork()

        // Then
        #expect(finishCount.read { $0 } == 1)
    }

    @Test
    func requestDidFinishIsCalledAfterStreamHandlersReceiveCompletion() async {
        // Given
        let order = Protected<[String]>([])
        let continuation = Protected<CheckedContinuation<Void, Never>?>(nil)
        let record: @Sendable (String) -> Void = { value in
            if order.write({ $0.append(value); return $0.count }) == 2 { continuation.read { $0 }?.resume() }
        }
        let rootQueue = DispatchQueue(label: "org.alamofire.tests.rootQueue")
        let monitorQueue = DispatchQueue(label: "org.alamofire.tests.monitorQueue")
        // Holds delivery of all stream events until the final `.completed` event has been produced.
        let handlerQueue = DispatchQueue(label: "org.alamofire.tests.handlerQueue")
        handlerQueue.suspend()
        let monitor = WebSocketEventMonitor(queue: monitorQueue,
                                            didReceiveCompletedEvent: {
                                                // `.completed` is now enqueued on `handlerQueue`. Before delivering
                                                // it, let any `requestDidFinish` it doesn't wait for fire: notified on
                                                // `rootQueue`, then delivered on `monitorQueue`.
                                                rootQueue.async {
                                                    rootQueue.async { monitorQueue.async { handlerQueue.resume() } }
                                                }
                                            },
                                            requestDidFinish: { record("requestDidFinish") })
        let session = Session(rootQueue: rootQueue, eventMonitors: [monitor])

        // When
        await withCheckedContinuation { (checkedContinuation: CheckedContinuation<Void, Never>) in
            continuation.write { $0 = checkedContinuation }
            session.webSocketRequest(.websocket()).streamMessageEvents(on: handlerQueue) { event in
                if case .completed = event.kind { record("completed") }
            }
        }

        // Then
        #expect(order.read { $0 } == ["completed", "requestDidFinish"])
    }

    @Test
    func addingStreamToFinishedRequestDoesNotChangeState() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocket(closeCode: .goingAway))
        _ = await request.streamingMessageEvents().collect()

        // When
        let stream = request.streamingMessageEvents()
        let stateAfterAdding = request.state
        let events = await stream.collect()

        // Then
        #expect(stateAfterAdding == .finished)
        #expect(request.state == .finished)
        #expect(events == [.completed(error: .nil)])
    }

    @Test
    func allMessagesSentBeforeServerCloseAreReceived() async {
        // Given
        let session = Session()
        let count = 1000

        // When
        let events = await session.webSocketRequest(.websocketCount(count)).streamingMessageEvents().collect()

        // Then
        let expected: [TestKind<TestMessage>] = [.connected]
            + Array(repeating: .receivedMessage, count: count)
            + [.disconnected(closeCode: .normalClosure, reason: nil), .completed(error: .nil)]
        #expect(events.count == expected.count)
        #expect(events == expected)
    }

    @Test(arguments: [false, true], [false, true])
    func cancellingWhileRetryIsPendingFinishesRequest(closing: Bool, afterRetryDecision: Bool) async {
        // Given
        let session = Session()
        let interceptor = HeldInterceptor()
        let request = session.webSocketRequest(.status(500), interceptor: interceptor)
        let events = Task { await request.streamingMessageEvents(automaticallyCancelling: false).collect() }
        var retries = interceptor.retries.makeAsyncIterator()
        let completeRetry = await retries.next()

        // When
        if afterRetryDecision {
            // The delay is never waited on, as stopping the request finishes it immediately.
            completeRetry?(.retryWithDelay(60))
            // The retry decision is delivered on `rootQueue`, then handled by the request on `underlyingQueue`.
            await request.underlyingQueue.pendingWork()
            await request.underlyingQueue.pendingWork()
        }
        if closing {
            request.close(sending: .normalClosure)
        } else {
            request.cancel()
        }
        if !afterRetryDecision {
            completeRetry?(.retry)
        }
        let collected = await withTimeout { await events.value }

        // Then
        #expect(collected != nil)
        if let collected {
            #expect(collected == [.completed(error: .nonNil)])
        }
    }

    @Test
    func resumedSocketContinuesReceivingMessagesAfterSuspension() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho)
        let stream = request.streamingMessageEvents(automaticallyCancelling: false)
        let firstMessage = Task { await stream.first { if case .receivedMessage = $0.kind { true } else { false } } }
        // A pong means the socket has connected.
        _ = await request.sendPing()

        // When
        request.suspend()
        await request.underlyingQueue.pendingWork()
        request.resume()
        await request.underlyingQueue.pendingWork()
        let sendResult = await withTimeout { () async -> Result<Void, WebSocketRequest.SendError<Never>> in
            await request.send(.string("after resume"))
        }
        let received = await withTimeout { await firstMessage.value }

        // Then
        #expect(sendResult?.isSuccess == true)
        #expect(received??.kind == .receivedMessage(.string("after resume")))

        await request.cancelAndWaitForFinish()
    }

    @Test
    func failedAutomaticPingAfterServerCloseDoesNotCancelRequest() async {
        // Given
        let session = Session()
        // The server closes on receipt of the first ping, while its pong is delayed, so the ping fails after the
        // server has already disconnected.
        let automaticPing = WebSocketRequest.Configuration.AutomaticPing(interval: .milliseconds(1),
                                                                         timeout: nil,
                                                                         failureAction: .cancelRequest(count: 1))
        let request = session.webSocketRequest(.websocketPings(count: 1, pongDelay: 5000),
                                               configuration: .init(automaticPing: automaticPing))

        // When
        let events = await request.streamingMessageEvents().collect()

        // Then
        #expect(events == [.connected, .disconnected(closeCode: .goingAway, reason: nil), .completed(error: .nil)])
        #expect(request.error == nil)
    }

    @Test
    func suspendingWithInflightAutomaticPingDoesNotCancelRequest() async throws {
        // Given
        let session = Session()
        // Pongs are delayed long enough that a ping is almost always inflight when suspending.
        let automaticPing = WebSocketRequest.Configuration.AutomaticPing(interval: .milliseconds(1),
                                                                         timeout: .milliseconds(100),
                                                                         failureAction: .cancelRequest(count: 1))
        let request = session.webSocketRequest(.websocketPings(count: 1000, pongDelay: 50),
                                               configuration: .init(automaticPing: automaticPing))
        let stream = request.streamingMessageEvents(automaticallyCancelling: false)
        // A pong means the socket has connected and automatic pings have started.
        _ = await request.sendPing()

        // When
        request.suspend()
        // Wait past the inflight ping's timeout. Only slows the test, it can't make it fail spuriously.
        try await Task.sleep(for: .milliseconds(300))

        // Then
        #expect(request.state == .suspended)

        await request.cancelAndWaitForFinish()
    }

    @Test
    func pingSentBeforeSuspendingDoesNotTimeOutWhileSuspended() async {
        // Given
        let session = Session()
        let request = session.webSocketRequest(.websocketEcho)
        let stream = request.streamingMessageEvents(automaticallyCancelling: false)
        _ = await request.sendPing()

        // When
        let result = await withCheckedContinuation { continuation in
            request.sendPing(timeout: .milliseconds(100)) { continuation.resume(returning: $0) }
            request.suspend()
            // Stay suspended past the timeout. Only slows the test, it can't make it fail spuriously.
            request.underlyingQueue.asyncAfter(deadline: .now() + .milliseconds(300)) { request.resume() }
        }

        // Then
        let isPong = if case .pong = result { true } else { false }
        #expect(isPong, "\(result)")
        _ = stream

        await request.cancelAndWaitForFinish()
    }

    @Test
    func pausedPingTimeoutStillTimesOutAfterResuming() async {
        // Given
        let session = Session()
        // The server closes after the second ping, so it stays connected while the first pong is delayed.
        let request = session.webSocketRequest(.websocketPings(count: 2, pongDelay: 5000))
        let stream = request.streamingMessageEvents(automaticallyCancelling: false)

        // When
        let result = await withCheckedContinuation { continuation in
            request.sendPing(timeout: .milliseconds(100)) { continuation.resume(returning: $0) }
            request.suspend()
            request.resume()
        }

        // Then
        let isTimedOut = if case .timedOut = result { true } else { false }
        #expect(isTimedOut, "\(result)")
        _ = stream

        await request.cancelAndWaitForFinish()
    }

    @Test
    func addingStreamToCancelledRequestFinishesOnce() async {
        // Given
        let finishCount = Protected(0)
        let monitorQueue = DispatchQueue(label: "org.alamofire.tests.finishCount")
        let monitor = ClosureEventMonitor(queue: monitorQueue)
        monitor.requestDidFinish = { _ in finishCount.write { $0 += 1 } }
        let session = Session(eventMonitors: [monitor])
        let request = session.webSocketRequest(.websocketEcho)
        _ = await request.streamingMessageEvents().first { if case .connected = $0.kind { true } else { false } }
        await request.cancelAndWaitForFinish()

        // When
        let events = await request.streamingMessageEvents().collect()
        await request.underlyingQueue.pendingWork()
        await monitorQueue.pendingWork()

        // Then
        #expect(events == [.completed(error: .nonNil)])
        #expect(request.state == .cancelled)
        #expect(finishCount.read { $0 } == 1)
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

/// Holds requests before their `URLSessionTask` is created until `open()` is called, so a resumed `WebSocketRequest`
/// deterministically remains unconnected.
final class ConnectionGate: RequestInterceptor, Sendable {
    private let state = Protected<(isOpen: Bool, pending: [@Sendable () -> Void])>((false, []))

    func adapt(_ urlRequest: URLRequest,
               for session: Session,
               completion: @escaping @Sendable (_ result: Result<URLRequest, any Error>) -> Void) {
        let isOpen = state.write { state in
            if !state.isOpen { state.pending.append { completion(.success(urlRequest)) } }
            return state.isOpen
        }

        if isOpen { completion(.success(urlRequest)) }
    }

    func open() {
        let pending = state.write { state in
            state.isOpen = true
            defer { state.pending = [] }
            return state.pending
        }

        pending.forEach { $0() }
    }
}

/// Observes `WebSocketRequest` events not available through `ClosureEventMonitor`.
final class WebSocketEventMonitor: EventMonitor {
    let queue: DispatchQueue
    private let didReceiveCompletedEvent: @Sendable () -> Void
    private let didFinish: @Sendable () -> Void

    init(queue: DispatchQueue,
         didReceiveCompletedEvent: @escaping @Sendable () -> Void,
         requestDidFinish: @escaping @Sendable () -> Void) {
        self.queue = queue
        self.didReceiveCompletedEvent = didReceiveCompletedEvent
        didFinish = requestDidFinish
    }

    func request<Success: Sendable, Failure: Error>(_ request: WebSocketRequest,
                                                    didReceiveEvent event: WebSocketRequest.Event<Success, Failure>) {
        if case .completed = event.kind { didReceiveCompletedEvent() }
    }

    func requestDidFinish(_ request: Request) {
        didFinish()
    }
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

    @Test
    func webSocketRequestFiresAllEventMonitorEvents() async {
        // Given
        let session = Session()
        let monitor = StreamEventMonitor()
        async let _monitorEvents = monitor.stream.collect(until: "requestDidFinish(_:)")
        let streamEvents = await session.webSocketRequest(.websocket())
            .eventMonitor(monitor)
            .streamingMessageEvents()
            .collect()
        let monitorEvents = await _monitorEvents

        #expect(streamEvents == [.connected(protocol: nil),
                                 .receivedMessage,
                                 .disconnected(closeCode: .normalClosure, reason: nil),
                                 .completed(error: .nil)])
        #expect(monitorEvents == ["requestDidResume(_:)",
                                  "request(_:didCreateInitialURLRequest:)",
                                  "request(_:didCreateURLRequest:)",
                                  "request(_:didCreateTask:)",
                                  "request(_:didResumeTask:)",
                                  "request(_:didGatherMetrics:)",
                                  "request(_:didConnectWithProtocol:)",
                                  "request(_:didReceiveEvent:)",
                                  "request(_:didReceiveMessage:)",
                                  "request(_:didReceiveEvent:)",
                                  "request(_:didDisconnectWithCloseCode:reason:)",
                                  "request(_:didReceiveEvent:)",
                                  "request(_:didReceiveEvent:)",
                                  "requestDidFinish(_:)"])
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

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest.SendError {
    var isLost: Bool {
        if case .lost = self { true } else { false }
    }
}
#endif
