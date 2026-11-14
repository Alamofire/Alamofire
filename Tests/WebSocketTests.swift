//
//  WebSocketTests.swift
//  Alamofire
//
//  Created by Jon Shier on 1/17/21.
//  Copyright © 2021 Alamofire. All rights reserved.
//

#if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.

@_spi(WebSocket) import Alamofire
import Foundation
import Testing

@Suite(.storesInstances)
struct WebSocketTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveMessageEvents() async {
        // Given
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocket()).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveMessageEventsWithParameters() async {
        // Given
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocket()).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveAMessage() async {
        // Given
        let didReceiveMessage = Completion("didReceiveMessage")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let receivedMessage = Capture<URLSessionWebSocketTask.Message?>()

        // When
        session.webSocketRequest(.websocket()).streamMessages { message in
            receivedMessage.value = message
            didReceiveMessage.complete()
        }
        .onCompletion {
            didComplete.complete()
        }

        await wait(for: [didReceiveMessage, didComplete], enforceOrder: true)

        // Then
        #expect(receivedMessage.value != nil)
        #expect(receivedMessage.data != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveADecodableMessage() async {
        // Given
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let message = Capture<TestResponse?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocketCount(1)).streamDecodableEvents(TestResponse.self) { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                didReceiveMessage.complete()
            case let .serializerFailed(error):
                Issue.record("websocket message serialization failed with error: \(error)")
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveADecodableValue() async {
        // Given
        let didReceiveValue = Completion("didReceiveMessage")
        let didComplete = Completion("didComplete")

        let session = stored(Session.independent())

        let receivedValue = Capture<TestResponse?>()

        // When
        session.webSocketRequest(.websocket()).streamDecodable(TestResponse.self) { value in
            receivedValue.value = value
            didReceiveValue.complete()
        }
        .onCompletion {
            didComplete.complete()
        }

        await wait(for: [didReceiveValue, didComplete], enforceOrder: true)

        // Then
        #expect(receivedValue.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveAMessageWithAProtocol() async {
        // Given
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let `protocol` = "protocol"
        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocket(), configuration: .protocol(`protocol`)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == `protocol`)
        #expect(message.value != nil)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveMultipleMessages() async {
        // Given
        let count = 5
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage", expectedCount: count)
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")

        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let messages = Capture<[URLSessionWebSocketTask.Message]>([])
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocketCount(count)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                messages.write { $0.append(receivedMessage) }
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(messages.count == count)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanSendAndReceiveMessages() async {
        // Given
        let didConnect = Completion("didConnect")
        let didSend = Completion("didSend")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())
        let sentMessage = URLSessionWebSocketTask.Message.string("Echo")

        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
                request.send(sentMessage) { _ in didSend.complete() }
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                event.close(sending: .normalClosure)
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didSend, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(sentMessage == message.value)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanBeCancelled() async {
        // Given
        let didConnect = Completion("didConnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
                request.cancel()
            case let .receivedMessage(receivedMessage):
                Issue.record("cancelled socket received message: \(receivedMessage)")
            case .disconnected:
                Issue.record("cancelled socket shouldn't receive disconnected event")
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(receivedCompletion.error?.isExplicitlyCancelledError == true)
        #expect(request.error?.isExplicitlyCancelledError == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func onePingOnly() async {
        // Given
        let didConnect = Completion("didConnect")
        let didSend = Completion("didSend")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didReceivePong = Completion("didReceivePong", expectedCount: 100)
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())
        let sentMessage = URLSessionWebSocketTask.Message.string("Echo")

        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let receivedPong = Capture<WebSocketRequest.PingResponse.Pong?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
                request.send(sentMessage) { _ in didSend.complete() }
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                didReceiveMessage.complete()
                for count in 0..<100 {
                    request.sendPing { response in
                        switch response {
                        case let .pong(pong):
                            receivedPong.value = pong
                        default:
                            break
                        }
                        didReceivePong.complete()
                        if count == 99 {
                            request.close(sending: .normalClosure)
                        }
                    }
                }
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didSend, didReceiveMessage, didReceivePong, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(sentMessage == message.value)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.value != nil)
        #expect(receivedCompletion.error == nil)
        #expect(receivedPong.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func timePingsOccur() async {
        // Given
        let didConnect = Completion("didConnect")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        let request = session.webSocketRequest(.websocketPings(), configuration: .pingInterval(0.01))
        request.streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case .receivedMessage:
                break
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(closeCode.value == .goingAway) // Default Vapor close() code.
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.value != nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketFailsWithTooSmallMaximumMessageSize() async {
        // Given
        let didConnect = Completion("didConnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocket(), configuration: .maximumMessageSize(1)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case .receivedMessage, .disconnected:
                break
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(receivedCompletion.error != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsFinishAfterNonNormalResponseCode() async {
        // Given
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocket(closeCode: .goingAway)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                message.value = receivedMessage
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                closeCode.value = code
                closeReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                receivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(closeCode.value == .goingAway)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanHaveMultipleHandlers() async {
        // Given
        let didConnect = Completion("didConnect", expectedCount: 2)
        let didReceiveMessage = Completion("didReceiveMessage", expectedCount: 2)
        let didDisconnect = Completion("didDisconnect", expectedCount: 2)
        let didComplete = Completion("didComplete", expectedCount: 2)
        let session = stored(Session.independent())

        let firstConnectedProtocol = Capture<String?>()
        let firstMessage = Capture<URLSessionWebSocketTask.Message?>()
        let firstCloseCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let firstCloseReason = Capture<Data?>()
        let firstReceivedCompletion = Capture<WebSocketRequest.Completion?>()
        let secondConnectedProtocol = Capture<String?>()
        let secondMessage = Capture<URLSessionWebSocketTask.Message?>()
        let secondCloseCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let secondCloseReason = Capture<Data?>()
        let secondReceivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(.websocket(closeCode: .goingAway)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                firstConnectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                firstMessage.value = receivedMessage
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                firstCloseCode.value = code
                firstCloseReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                firstReceivedCompletion.value = completion
                didComplete.complete()
            }
        }
        .streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                secondConnectedProtocol.value = `protocol`
                didConnect.complete()
            case let .receivedMessage(receivedMessage):
                secondMessage.value = receivedMessage
                didReceiveMessage.complete()
            case let .disconnected(code, reason):
                secondCloseCode.value = code
                secondCloseReason.value = reason
                didDisconnect.complete()
            case let .completed(completion):
                secondReceivedCompletion.value = completion
                didComplete.complete()
            }
        }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(firstConnectedProtocol.value == nil)
        #expect(firstConnectedProtocol.value == secondConnectedProtocol.value)
        #expect(firstMessage.value != nil)
        #expect(firstMessage.value == secondMessage.value)
        #expect(firstCloseCode.value == .goingAway)
        #expect(firstCloseCode.value == secondCloseCode.value)
        #expect(firstCloseReason.value == nil)
        #expect(firstCloseReason.value == secondCloseReason.value)
        #expect(firstReceivedCompletion.error == nil)
        #expect(secondReceivedCompletion.error == nil)
    }
}

@Suite(.storesInstances)
struct WebSocketIntegrationTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketsCanReceiveMessageEventsAfterRetry() async {
        // Given
        let didConnect = Completion("didConnect")
        let didReceiveMessage = Completion("didReceiveMessage")
        let didDisconnect = Completion("didDisconnect")
        let didComplete = Completion("didComplete")
        let session = stored(Session.independent())

        let connectedProtocol = Capture<String?>()
        let message = Capture<URLSessionWebSocketTask.Message?>()
        let closeCode = Capture<URLSessionWebSocketTask.CloseCode?>()
        let closeReason = Capture<Data?>()
        let receivedCompletion = Capture<WebSocketRequest.Completion?>()

        // When
        session.webSocketRequest(performing: .endpoints(.status(500), .websocket()), interceptor: .retryPolicy)
            .streamMessageEvents { event in
                switch event.kind {
                case let .connected(`protocol`):
                    connectedProtocol.value = `protocol`
                    didConnect.complete()
                case let .receivedMessage(receivedMessage):
                    message.value = receivedMessage
                    didReceiveMessage.complete()
                case let .disconnected(code, reason):
                    closeCode.value = code
                    closeReason.value = reason
                    didDisconnect.complete()
                case let .completed(completion):
                    receivedCompletion.value = completion
                    didComplete.complete()
                }
            }

        await wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], enforceOrder: true)

        // Then
        #expect(connectedProtocol.value == nil)
        #expect(message.value != nil)
        #expect(closeCode.value == .normalClosure)
        #expect(closeReason.value == nil)
        #expect(receivedCompletion.error == nil)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension WebSocketRequest {
    @discardableResult
    func onCompletion(queue: DispatchQueue = .main, handler: @escaping @Sendable () -> Void) -> Self {
        streamMessageEvents(on: queue) { event in
            guard case .completed = event.kind else { return }

            handler()
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Session {
    func webSocketRequest(_ endpoint: Endpoint,
                          configuration: WebSocketRequest.Configuration = .default,
                          interceptor: (any RequestInterceptor)? = nil) -> WebSocketRequest {
        webSocketRequest(performing: endpoint as (any URLRequestConvertible),
                         configuration: configuration,
                         interceptor: interceptor)
    }
}

#endif
