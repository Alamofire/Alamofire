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

import Alamofire
import Foundation
import Testing
import XCTest

final class WebSocketTests: BaseTestCase {
    func testThatWebSocketsCanReceiveMessageEvents() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session(eventMonitors: [NSLoggingEventMonitor()]))

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
            case let .decoderFailed(error):
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
        session.webSocketRequest(.websocket(), configuration: .protocols([`protocol`])).streamMessageEvents { event in
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

    func testThatWebSocketsCanReceiveAMessageGivenMultipleProtocols() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())

        let protocols = ["first", "second"]
        var connectedProtocol: String?
        var message: URLSessionWebSocketTask.Message?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        session.webSocketRequest(.websocket(), configuration: .protocols(protocols)).streamMessageEvents { event in
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
        XCTAssertEqual(connectedProtocol, "first")
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
        request.streamMessageEvents { [unowned request] event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
                request.send(sentMessage) { _ in didSend.fulfill() }
            case let .receivedMessage(receivedMessage):
                message = receivedMessage
                event.socket?.close(sending: .normalClosure)
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

    func testThatWebSocketsCanSendAndReceiveCodableMessages() {
        // Given
        let didConnect = expectation(description: "didConnect")
        let didSend = expectation(description: "didSend")
        let didReceiveMessage = expectation(description: "didReceiveMessage")
        let didDisconnect = expectation(description: "didDisconnect")
        let didComplete = expectation(description: "didComplete")
        let session = stored(Session())
        struct CodableMessage: Equatable, Codable {
            var field = "value"
        }
        let sentMessage = CodableMessage()

        var connectedProtocol: String?
        var receivedMessage: CodableMessage?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamDecodableEvents(CodableMessage.self) { [unowned request] event in
            switch event.kind {
            case let .connected(`protocol`):
                connectedProtocol = `protocol`
                didConnect.fulfill()
                request.send(sentMessage) { _ in didSend.fulfill() }
            case let .receivedMessage(message):
                receivedMessage = message
                event.socket?.close(sending: .normalClosure)
                didReceiveMessage.fulfill()
            case let .disconnected(code, reason):
                closeCode = code
                closeReason = reason
                didDisconnect.fulfill()
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            case let .decoderFailed(error):
                XCTFail("Failed to decode message due to error: \(error) ")
            }
        }

        wait(for: [didConnect, didSend, didReceiveMessage, didDisconnect, didComplete],
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(sentMessage, receivedMessage)
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
        request.streamMessageEvents { [unowned request] event in
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

    func testThatWebSocketsWithPendingSendsCompleteTheSendsOnCancellation() {
        // Given
        let didComplete = expectation(description: "didComplete")
        let didSend = expectation(description: "didSend")
        let session = stored(Session(startRequestsImmediately: false))

        var receivedSendResult: Result<Void, WebSocketRequest.SendError<Never>>?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
            switch event.kind {
            case let .completed(completion):
                receivedCompletion = completion
                didComplete.fulfill()
            default:
                break
            }
        }
        request.send("hello") { result in
            receivedSendResult = result
            didSend.fulfill()
        }
        request.cancel()

        wait(for: [didSend, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(receivedCompletion?.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.error?.isExplicitlyCancelledError == true)
        XCTAssertEqual(receivedSendResult?.failure?.failedState, .cancelled)
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
        var receivedPong: WebSocketRequest.PingResult.Pong?
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var closeReason: Data?
        var receivedCompletion: WebSocketRequest.Completion?

        // When
        let request = session.webSocketRequest(.websocketEcho)
        request.streamMessageEvents { [unowned request] event in
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
             timeout: timeout,
             enforceOrder: true)

        // Then
        XCTAssertNil(connectedProtocol)
        XCTAssertNotNil(message)
        XCTAssertEqual(closeCode, .normalClosure)
        XCTAssertNil(closeReason)
        XCTAssertNil(receivedCompletion?.error)
    }
}

@Suite
struct WebSocketConcurrencyTests {
    @Test
    func messageEventsCanBeStreamed() async {
        // Given
        let session = Session()

        // When
        let events = await session.webSocketRequest(.websocket()).streamingMessageEvents().collect()

        // Then
        #expect(events.count == 4)
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

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension WebSocketRequest {
    @discardableResult
    func onCompletion(queue: DispatchQueue = .main, handler: @escaping @Sendable () -> Void) -> Self {
        streamMessageEvents(on: queue) { event in
            guard case .completed = event.kind else { return }

            handler()
        }
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

extension Session {
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func webSocketRequest(_ endpoint: Endpoint,
                          configuration: WebSocketRequest.Configuration = .default,
                          interceptor: (any RequestInterceptor)? = nil) -> WebSocketRequest {
        webSocketRequest(performing: endpoint as (any URLRequestConvertible),
                         configuration: configuration,
                         interceptor: interceptor)
    }
}

#endif
