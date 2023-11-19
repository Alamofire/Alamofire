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
import XCTest

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class WebSocketTests: BaseTestCase {
    func testThatWebSocketsCanReceiveMessageEvents() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket()).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanReceiveMessageEventsWithParameters() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket()).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanReceiveAMessage() {
        // Given
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var receivedMessage: URLSessionWebSocketTask.Message?

        // When
        session.webSocketRequest(.websocket()).streamMessages { message in
            receivedMessage = message
            didReceiveMessage.fulfill()
        }
        .onCompletion {
            didComplete.fulfill()
        }

        wait(for: [didReceiveMessage, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNotNil(receivedMessage)
        XCTAssertNotNil(receivedMessage?.data)
    }

    func testThatWebSocketsCanReceiveADecodableMessage() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var message: TestResponse?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocketCount(1)).streamDecodableEvents(TestResponse.self) { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                didReceiveMessage.fulfill()
            case let .serializerFailed(error):
                XCTFail("websocket message serialization failed with error: \(error)")
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanReceiveADecodableValue() {
        // Given
        let didReceiveValue = expectation(description: "didReceiveMessage")
        let didComplete = expectation(description: "didComplete")

        let session = stored(Session())

        var receivedValue: TestResponse?

        // When
        session.webSocketRequest(.websocket()).streamDecodable(TestResponse.self) { value in
            receivedValue = value
            didReceiveValue.fulfill()
        }
        .onCompletion {
            didComplete.fulfill()
        }

        wait(for: [didReceiveValue, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNotNil(receivedValue)
    }

    func testThatWebSocketsCanReceiveAMessageWithAProtocol() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        let `protocol` = "protocol"
        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket(), configuration: .protocol(`protocol`)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertEqual(connectedProtocol, `protocol`)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanReceiveMultipleMessages() {
        // Given
        let count = 5
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        didReceiveMessage.expectedFulfillmentCount = count
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")

        let session = stored(Session())

        var connectedProtocol: String?
        var messages: [URLSessionWebSocketTask.Message] = []
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocketCount(count)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                messages.append(receivedMessage)
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertEqual(messages.count, count)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanSendAndReceiveMessages() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didSend = expectation(description: "didSend")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())
        let sentMessage = URLSessionWebSocketTask.Message.string("Echo")

        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
                request.send(sentMessage) { _ in didSend.fulfill() }
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                event.close(sending: .normalClosure)
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didSend, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(sentMessage, message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanBeCancelled() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
                request.cancel()
            case let .receivedMessage(receivedMessage):
                XCTFail("cancelled socket received message: \(receivedMessage)")
            case .disconnected:
                XCTFail("cancelled socket shouldn't receive disconnected event")
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertTrue(receivedCompletion?.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.error?.isExplicitlyCancelledError == true)
    }

    func testOnePingOnly() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didSend = expectation(description: "didSend")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didReceivePong = expectation(description: "didReceivePong")
        didReceivePong.expectedFulfillmentCount = 100
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())
        let sentMessage = URLSessionWebSocketTask.Message.string("Echo")

        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var receivedPong: WebSocketRequest.PingResponse.Pong?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
                request.send(sentMessage) { _ in didSend.fulfill() }
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                didReceiveMessage.fulfill()
                for count in 0..<100 {
                    request.sendPing { response in
                        switch response {
                        case let .pong(pong):
                            receivedPong = pong
                        default:
                            break
                        }
                        didReceivePong.fulfill()
                        if count == 99 {
                            request.close(sending: .normalClosure)
                        }
                    }
                }
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didSend, didReceiveMessage, didReceivePong, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(sentMessage, message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNotNil(receivedCompletion)
        XCTAssertNil(receivedCompletion?.error)
        XCTAssertNotNil(receivedPong)
    }

    func testThatTimePingsOccur() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketPings(), configuration: .pingInterval(0.01))
        request.streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case .receivedMessage:
                break
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didDisconnect, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertEqual(closeCode, .goingAway) // Default Vapor close() code.
        XCTAssertNil(closeReason)
        XCTAssertNotNil(receivedCompletion)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketFailsWithTooSmallMaximumMessageSize() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket(), configuration: .maximumMessageSize(1)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case .receivedMessage, .disconnected:
                break
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(receivedCompletion?.error)
    }

    func testThatWebSocketsFinishAfterNonNormalResponseCode() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket(closeCode: .goingAway)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .goingAway)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }

    func testThatWebSocketsCanHaveMultipleHandlers() {
        // Given
        let didConnect = expectation(description: "didConnect")
        didConnect.expectedFulfillmentCount = 2
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        didReceiveMessage.expectedFulfillmentCount = 2
        let didDisconnect = expectation(description: "didDisconnect")
        didDisconnect.expectedFulfillmentCount = 2
        let didComplete = expectation(description: "didComplete")
        didComplete.expectedFulfillmentCount = 2
        let session = stored(Session())

        var firstConnectedProtocol: String?
        var firstMessage: URLSessionWebSocketTask.Message?
        var firstCloseCode: URLSessionWebSocketTask.CloseCode?
        var firstCloseReason: Data?
        var firstReceivedCompletion: WebSocketRequest.Completion?
        var secondConnectedProtocol: String?
        var secondMessage: URLSessionWebSocketTask.Message?
        var secondCloseCode: URLSessionWebSocketTask.CloseCode?
        var secondCloseReason: Data?
        var secondReceivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket(closeCode: .goingAway)).streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                firstConnectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                firstMessage = receivedMessage
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                firstCloseCode = code
                firstCloseReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                firstReceivedCompletion = completion
                didComplete.fulfill()
            }
        }
        .streamMessageEvents { event in
            switch event.kind {
            case let .connected(`protocol`):
                secondConnectedProtocol = `protocol`
                didConnect.fulfill()
            case let .receivedMessage(receivedMessage):
                secondMessage = receivedMessage
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                secondCloseCode = code
                secondCloseReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                secondReceivedCompletion = completion
                didComplete.fulfill()
            }
        }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(firstConnectedProtocol)
        XCTAssertEqual(firstConnectedProtocol, secondConnectedProtocol)
        XCTAssertNotNil(firstMessage)
        XCTAssertEqual(firstMessage, secondMessage)
        XCTAssertEqual(firstCloseCode, .goingAway)
        XCTAssertEqual(firstCloseCode, secondCloseCode)
        XCTAssertNil(firstCloseReason)
        XCTAssertEqual(firstCloseReason, secondCloseReason)
        XCTAssertNil(firstReceivedCompletion?.error)
        XCTAssertNil(secondReceivedCompletion?.error)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class WebSocketIntegrationTests: BaseTestCase {
    func testThatWebSocketsCanReceiveMessageEventsAfterRetry() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(performing: .endpoints(.status(500), .websocket()), interceptor: .retryPolicy)
            .streamMessageEvents { event in
                switch event.kind {
                case let .connected(`protocol`):
                    connectedProtocol = `protocol`
                    didConnect.fulfill()
                case let .receivedMessage(receivedMessage):
                    message = receivedMessage
                    didReceiveMessage.fulfill()
                case let .disconnected(code, reason):
                    closeCode = code
                    closeReason = reason
                    didDisconnect.fulfill()
                case let .completed(completion):
                    receivedCompletion = completion
                    didComplete.fulfill()
                }
            }

        wait(for: [didConnect, didReceiveMessage, didDisconnect, didComplete],
             timeout: 100,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension WebSocketRequest {
    @discardableResult
    func onCompletion(queue: DispatchQueue = .main, handler: @escaping () -> Void) -> Self {
        streamMessageEvents(on: queue) { event in
            guard case .completed = event.kind else { return }

            handler()
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension URLSessionWebSocketTask.Message: Equatable {
    public static func ==(lhs: URLSessionWebSocketTask.Message, rhs: URLSessionWebSocketTask.Message) -> Bool {
        switch (lhs, rhs) {
        case let (.string(left), .string(right)):
            return left == right
        case let (.data(left), .data(right)):
            return left == right
        default:
            return false
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

extension Session {
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func webSocketRequest(_ endpoint: Endpoint,
                          configuration: WebSocketRequest.Configuration = .default,
                          interceptor: RequestInterceptor? = nil) -> WebSocketRequest {
        webSocketRequest(performing: endpoint as URLRequestConvertible,
                         configuration: configuration,
                         interceptor: interceptor)
    }
}

#endif
