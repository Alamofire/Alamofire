//
//  DataStreamTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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

@testable import Alamofire
import Foundation
import Testing

@Suite(.storesInstances)
struct DataStreamTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedOnMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 5
        let accumulatedData = Capture(Data())
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didReceiveResponse = Completion("stream should receive response once")
        let didReceive = Completion("stream should receive once")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.bytes(expectedSize))
            .onHTTPResponse { response in
                initialResponse.value = response
                didReceiveResponse.complete()
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.write { $0.append(data) }
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(initialResponse.value == response.value)
        #expect(accumulatedData.count == expectedSize)
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedOnArbitraryQueue() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 5
        let accumulatedData = Capture(Data())
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let streamQueue = DispatchQueue(label: "com.alamofire.tests.ArbitraryQueue")
        let didReceiveResponse = Completion("stream should receive response once")
        let didReceive = Completion("stream should receive once")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.bytes(expectedSize))
            .onHTTPResponse { response in
                initialResponse.value = response
                didReceiveResponse.complete()
            }
            .responseStream(on: streamQueue) { stream in
                dispatchPrecondition(condition: .onQueue(streamQueue))
                switch stream.event {
                case let .stream(result):
                    switch result {
                    case let .success(data):
                        accumulatedData.write { $0.append(data) }
                    }
                    didReceive.complete()
                case let .complete(completion):
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(initialResponse.value == response.value)
        #expect(accumulatedData.count == expectedSize)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedByByte() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 5
        let accumulatedData = Capture(Data())
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let streamCalled = Capture(0)
        let didReceiveResponse = Completion("stream should receive response once")
        let didReceive = Completion("stream should receive once", expectedCount: expectedSize)
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.chunked(expectedSize))
            .onHTTPResponse { response in
                initialResponse.value = response
                didReceiveResponse.complete()
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.write { $0.append(data) }
                    }
                    streamCalled.write { $0 += 1 }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(streamCalled.value == expectedSize)
        #expect(initialResponse.value == response.value)
        #expect(accumulatedData.count == expectedSize)
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedAsMultipleJSONPayloads() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 5
        let responses = Capture<[TestResponse]>([])
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let streamCalled = Capture(0)
        let didReceiveResponse = Completion("stream should receive response once")
        let didReceive = Completion("stream should receive once", expectedCount: expectedSize)
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.payloads(expectedSize))
            .onHTTPResponse { response in
                initialResponse.value = response
                didReceiveResponse.complete()
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        responses.write { $0.append(value) }
                    case let .failure(error):
                        Issue.record("JSON stream failed due to error: \(error.localizedDescription)")
                    }
                    streamCalled.write { $0 += 1 }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(streamCalled.value == expectedSize)
        #expect(responses.count == expectedSize)
        #expect(initialResponse.value == response.value)
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedFromURL() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 1
        let accumulatedData = Capture(Data())
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didReceiveResponse = Completion("stream should receive response once")
        let didReceive = Completion("stream should receive")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.bytes(expectedSize))
            .onHTTPResponse { response in
                initialResponse.value = response
                didReceiveResponse.complete()
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.write { $0.append(data) }
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(accumulatedData.count == expectedSize)
        #expect(initialResponse.value == response.value)
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedManyTimes() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 1
        let initialResponse = Capture<HTTPURLResponse?>()
        let onHTTPResponse = Completion("onHTTPResponse should be called")
        let firstAccumulatedData = Capture(Data())
        let firstResponse = Capture<HTTPURLResponse?>()
        let firstStreamOnMain = Capture(false)
        let firstCompleteOnMain = Capture(false)
        let firstReceive = Completion("first stream should receive")
        let firstCompletion = Completion("first stream should complete")
        let secondAccumulatedData = Capture(Data())
        let secondResponse = Capture<HTTPURLResponse?>()
        let secondStreamOnMain = Capture(false)
        let secondCompleteOnMain = Capture(false)
        let secondReceive = Completion("second stream should receive")
        let secondCompletion = Completion("second stream should complete")

        // When
        session.streamRequest(.bytes(expectedSize))
            .onHTTPResponse { response in
                initialResponse.value = response
                onHTTPResponse.complete()
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        firstAccumulatedData.write { $0.append(data) }
                    }
                    firstReceive.complete()
                case let .complete(completion):
                    firstCompleteOnMain.value = Thread.isMainThread
                    firstResponse.value = completion.response
                    firstCompletion.complete()
                }
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        secondAccumulatedData.write { $0.append(data) }
                    }
                    secondReceive.complete()
                case let .complete(completion):
                    secondCompleteOnMain.value = Thread.isMainThread
                    secondResponse.value = completion.response
                    secondCompletion.complete()
                }
            }

        await wait(for: [onHTTPResponse, firstReceive, firstCompletion], enforceOrder: true)
        await wait(for: [secondReceive, secondCompletion], enforceOrder: true)

        // Then
        #expect(initialResponse.value == firstResponse.value)
        #expect(initialResponse.value == secondResponse.value)
        #expect(firstStreamOnMain.value)
        #expect(firstCompleteOnMain.value)
        #expect(firstResponse.statusCode == 200)
        #expect(firstAccumulatedData.count == expectedSize)
        #expect(secondStreamOnMain.value)
        #expect(secondCompleteOnMain.value)
        #expect(secondResponse.statusCode == 200)
        #expect(secondAccumulatedData.count == expectedSize)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataCanBeStreamedAndDecodedAtTheSameTime() async {
        // Given
        let session = stored(Session.independent())
        let initialResponse = Capture<HTTPURLResponse?>()
        let onHTTPResponse = Completion("onHTTPResponse should be called")
        let firstAccumulatedData = Capture(Data())
        let firstResponse = Capture<HTTPURLResponse?>()
        let firstStreamOnMain = Capture(false)
        let firstCompleteOnMain = Capture(false)
        let firstReceive = Completion("first stream should receive")
        let firstCompletion = Completion("first stream should complete")
        let decodedResponse = Capture<TestResponse?>()
        let decodingError = Capture<AFError?>()
        let secondResponse = Capture<HTTPURLResponse?>()
        let secondStreamOnMain = Capture(false)
        let secondCompleteOnMain = Capture(false)
        let secondReceive = Completion("second stream should receive")
        let secondCompletion = Completion("second stream should complete")

        // When
        session.streamRequest(.stream(1))
            .onHTTPResponse { response in
                initialResponse.value = response
                onHTTPResponse.complete()
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        firstAccumulatedData.write { $0.append(data) }
                    }
                    firstReceive.complete()
                case let .complete(completion):
                    firstCompleteOnMain.value = Thread.isMainThread
                    firstResponse.value = completion.response
                    firstCompletion.complete()
                }
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse.value = value
                    case let .failure(error):
                        decodingError.value = error
                    }
                    secondReceive.complete()
                case let .complete(completion):
                    secondCompleteOnMain.value = Thread.isMainThread
                    secondResponse.value = completion.response
                    secondCompletion.complete()
                }
            }

        await wait(for: [onHTTPResponse, firstReceive, firstCompletion], enforceOrder: true)
        await wait(for: [secondReceive, secondCompletion], enforceOrder: true)

        // Then
        #expect(initialResponse.value == firstResponse.value)
        #expect(initialResponse.value == secondResponse.value)
        #expect(firstStreamOnMain.value)
        #expect(firstCompleteOnMain.value)
        #expect(firstResponse.statusCode == 200)
        #expect(!firstAccumulatedData.isEmpty)
        #expect(secondStreamOnMain.value)
        #expect(secondCompleteOnMain.value)
        #expect(secondResponse.statusCode == 200)
        #expect(decodedResponse.value != nil)
        #expect(decodingError.value == nil)
    }

    #if !canImport(FoundationNetworking) // If we not using swift-corelibs-foundation.
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestProducesWorkingInputStream() async {
        // Given
        let session = stored(Session.independent())
        let expect = Completion("stream complete")

        // When
        let stream = session.streamRequest(.xml)
            .responseStream { stream in
                switch stream.event {
                case .complete:
                    expect.complete()
                default: break
                }
            }
            .asInputStream()

        await expect.wait()

        // Then
        let parser = XMLParser(stream: stream!)
        let parsed = parser.parse()
        #expect(parsed)
        #expect(parser.parserError == nil)
    }
    #endif

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCanBeManuallyResumed() async {
        // Given
        let session = Session.independent(startRequestsImmediately: false)
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    streamOnMain.value = Thread.isMainThread
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }.resume()

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(response.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamIsAutomaticallyCanceledOnStreamErrorWhenEnabled() async {
        let session = stored(Session.independent())
        let response = Capture<HTTPURLResponse?>()
        let complete = Capture<DataStreamRequest.Completion?>()
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.bytes(50), automaticallyCancelOnStreamError: true)
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .complete(completion):
                    complete.value = completion
                    response.value = completion.response
                    didComplete.complete()
                default: break
                }
            }

        await didComplete.wait()

        // Then
        #expect(response.statusCode == 200)
        #expect(complete.error?.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(complete.error?.localizedDescription ?? "None")")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamIsAutomaticallyCanceledOnStreamClosureError() async {
        // Given
        let session = stored(Session.independent())
        enum LocalError: Error { case failed }

        let response = Capture<HTTPURLResponse?>()
        let complete = Capture<DataStreamRequest.Completion?>()
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.bytes(50))
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    didReceive.complete()
                    throw LocalError.failed
                case let .complete(completion):
                    complete.value = completion
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(complete.error?.isExplicitlyCancelledError == false)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCanBeCancelledInClosure() async {
        // Given
        let session = stored(Session.independent())
        let completion = Capture<DataStreamRequest.Completion?>()
        let didReceive = Completion("stream should receive")
        let didComplete = Completion("stream should complete")

        // When
        // The 250 ms pause after the first chunk keeps the request running until the stream cancels it.
        session.streamRequest(.chunked(2, delay: 250)).responseStream { stream in
            switch stream.event {
            case .stream:
                didReceive.complete()
                stream.cancel()
            case .complete:
                completion.value = stream.completion
                didComplete.complete()
            }
        }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(completion.error?.isExplicitlyCancelledError == true, """
        error is not explicitly cancelled, instead: \(completion.error?.localizedDescription ?? "none").
        response is: \(completion.response?.description ?? "none").
        """)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCanBeCancelledByToken() async {
        // Given
        let session = stored(Session.independent())
        let completion = Capture<DataStreamRequest.Completion?>()
        let didReceive = Completion("stream should receive")
        let didComplete = Completion("stream should complete")

        // When
        // The 250 ms pause after the first chunk keeps the request running until the stream cancels it.
        session.streamRequest(.chunked(2, delay: 250)).responseStream { stream in
            switch stream.event {
            case .stream:
                didReceive.complete()
                stream.token.cancel()
            case .complete:
                completion.value = stream.completion
                didComplete.complete()
            }
        }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(completion.error?.isExplicitlyCancelledError == true, """
        error is not explicitly cancelled, instead: \(completion.error?.localizedDescription ?? "none").
        response is: \(completion.response?.description ?? "none").
        """)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func onHTTPResponseCanContinueStream() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 5
        let accumulatedData = Capture(Data())
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didReceiveResponse = Completion("stream should receive response once")
        let didReceive = Completion("stream should receive once")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.bytes(expectedSize))
            .onHTTPResponse { response, completionHandler in
                initialResponse.value = response
                didReceiveResponse.complete()
                completionHandler(.allow)
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.write { $0.append(data) }
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(initialResponse.value == response.value)
        #expect(accumulatedData.count == expectedSize)
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func onHTTPResponseCanCancelStream() async {
        // Given
        let session = stored(Session.independent())
        let expectedSize = 5
        let initialResponse = Capture<HTTPURLResponse?>()
        let response = Capture<HTTPURLResponse?>()
        let completion = Capture<DataStreamRequest.Completion?>()
        let didCompleteOnMain = Capture(false)
        let didReceiveResponse = Completion("stream should receive response once")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.bytes(expectedSize))
            .onHTTPResponse { response, completionHandler in
                initialResponse.value = response
                didReceiveResponse.complete()
                completionHandler(.cancel)
            }
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    Issue.record("should never receive stream in a cancelled request")
                case let .complete(comp):
                    didCompleteOnMain.value = Thread.isMainThread
                    completion.value = comp
                    response.value = comp.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceiveResponse, didComplete], enforceOrder: true)

        // Then
        #expect(response.statusCode == 200)
        #expect(initialResponse.value == response.value)
        #expect(didCompleteOnMain.value)
        #expect(completion.error?.isExplicitlyCancelledError == true, "onHTTPResponse cancelled stream should be explicitly cancelled")
    }
}

// MARK: - Serialization Tests

@Suite(.storesInstances)
struct DataStreamSerializationTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamsCanBeAString() async {
        // Given
        let session = stored(Session.independent())
        let responseString = Capture<String?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let response = Capture<HTTPURLResponse?>()
        let didStream = Completion("did stream")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamString { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(string):
                        responseString.value = string
                    }
                    didStream.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didStream, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(responseString.value != nil)
        #expect(response.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamsCanBeAStringOnAnArbitraryQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseString = Capture<String?>()
        let response = Capture<HTTPURLResponse?>()
        let streamQueue = DispatchQueue(label: "com.alamofire.tests.ArbitraryQueue")
        let didStream = Completion("did stream")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamString(on: streamQueue) { stream in
                dispatchPrecondition(condition: .onQueue(streamQueue))
                switch stream.event {
                case let .stream(result):
                    switch result {
                    case let .success(string):
                        responseString.value = string
                    }
                    didStream.complete()
                case let .complete(completion):
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didStream, didComplete], enforceOrder: true)

        // Then
        #expect(responseString.value != nil)
        #expect(response.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamsCanBeDecoded() async {
        // Given
        let session = stored(Session.independent())
        let response = Capture<TestResponse?>()
        let httpResponse = Capture<HTTPURLResponse?>()
        let decodingError = Capture<AFError?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        response.value = value
                    case let .failure(error):
                        decodingError.value = error
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    httpResponse.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(response.value != nil)
        #expect(httpResponse.statusCode == 200)
        #expect(decodingError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamsCanBeDecodedOnAnArbitraryQueue() async {
        // Given
        let session = stored(Session.independent())
        let response = Capture<TestResponse?>()
        let httpResponse = Capture<HTTPURLResponse?>()
        let decodingError = Capture<AFError?>()
        let streamQueue = DispatchQueue(label: "com.alamofire.tests.ArbitraryQueue")
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self, on: streamQueue) { stream in
                dispatchPrecondition(condition: .onQueue(streamQueue))
                switch stream.event {
                case let .stream(result):
                    switch result {
                    case let .success(value):
                        response.value = value
                    case let .failure(error):
                        decodingError.value = error
                    }
                    didReceive.complete()
                case let .complete(completion):
                    httpResponse.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(response.value != nil)
        #expect(httpResponse.statusCode == 200)
        #expect(decodingError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamSerializerCanBeUsedDirectly() async {
        // Given
        let session = stored(Session.independent())
        let response = Capture<HTTPURLResponse?>()
        let decodedResponse = Capture<TestResponse?>()
        let decodingError = Capture<AFError?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let serializer = DecodableStreamSerializer<TestResponse>()
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStream(using: serializer) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse.value = value
                    case let .failure(error):
                        decodingError.value = error
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(decodedResponse.value != nil)
        #expect(response.statusCode == 200)
        #expect(decodingError.value == nil)
    }
}

// MARK: - Integration Tests

@Suite(.storesInstances)
struct DataStreamIntegrationTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCanFailValidation() async {
        // Given
        let session = stored(Session.independent())
        let dataSeen = Capture(false)
        let error = Capture<AFError?>()
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.status(401))
            .validate()
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    dataSeen.value = true
                case let .complete(completion):
                    error.value = completion.error
                    didComplete.complete()
                }
            }

        await didComplete.wait()

        // Then
        #expect(error.value != nil, "error should not be nil")
        #expect(error.isResponseValidationError == true, "error should be response validation error")
        #expect(!dataSeen.value, "no data should be seen")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamsCanBeRetried() async {
        // Given
        final class GoodRetry: RequestInterceptor {
            let hasRetried = Protected(false)

            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
                if hasRetried.read({ $0 }) {
                    completion(.success(Endpoint.bytes(1000).urlRequest))
                } else {
                    completion(.success(urlRequest))
                }
            }

            func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping (RetryResult) -> Void) {
                hasRetried.write(true)
                completion(.retry)
            }
        }

        let session = Session.independent(interceptor: GoodRetry())
        let accumulatedData = Capture(Data())
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let response = Capture<HTTPURLResponse?>()
        let didReceive = Completion("stream should receive")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.status(401))
            .validate()
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.write { $0.append(data) }
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(accumulatedData.count == 1000)
        #expect(response.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCanBeRedirected() async {
        // Given
        let session = stored(Session.independent())
        let response = Capture<HTTPURLResponse?>()
        let decodedResponse = Capture<TestResponse?>()
        let decodingError = Capture<AFError?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didRedirect = Completion("stream redirected")
        let redirector = Redirector(behavior: .modify { _, _, _ in
            didRedirect.complete()
            return Endpoint.stream(1).urlRequest
        })
        let didReceive = Completion("stream should receive")
        let didComplete = Completion("stream should complete")

        // When
        session.streamRequest(.status(301))
            .redirect(using: redirector)
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse.value = value
                    case let .failure(error):
                        decodingError.value = error
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didRedirect, didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(decodedResponse.value != nil)
        #expect(response.statusCode == 200)
        #expect(decodingError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCallsCachedResponseHandler() async {
        // Given
        let session = stored(Session.independent())
        let response = Capture<HTTPURLResponse?>()
        let decodedResponse = Capture<TestResponse?>()
        let decodingError = Capture<AFError?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let cached = Completion("stream called cacher")
        let cacher = ResponseCacher(behavior: .modify { _, _ in
            cached.complete()
            return nil
        })
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.stream(1))
            .cacheResponse(using: cacher)
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse.value = value
                    case let .failure(error):
                        decodingError.value = error
                    }
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        // willCacheResponse called after receiving all Data, so may be called before or after the asynchronous stream
        // handlers.
        await wait(for: [cached])
        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(decodedResponse.value != nil)
        #expect(response.statusCode == 200)
        #expect(decodingError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamWorksCorrectlyWithMultipleSerialQueues() async {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue")
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        // Require manual start so both serializers can be added before the stream starts.
        let session = Session.independent(startRequestsImmediately: false,
                                          requestQueue: requestQueue,
                                          serializationQueue: serializationQueue)
        let firstResponse = Capture<HTTPURLResponse?>()
        let firstDecodedResponse = Capture<TestResponse?>()
        let firstDecodingError = Capture<AFError?>()
        let firstStreamOnMain = Capture(false)
        let firstCompleteOnMain = Capture(false)
        let firstStream = Completion("first stream")
        let firstDidReceive = Completion("first stream did receive")
        let firstDidComplete = Completion("first stream complete")
        let secondResponse = Capture<HTTPURLResponse?>()
        let secondDecodedResponse = Capture<TestResponse?>()
        let secondDecodingError = Capture<AFError?>()
        let secondStreamOnMain = Capture(false)
        let secondCompleteOnMain = Capture(false)
        let secondStream = Completion("second stream")
        let secondDidReceive = Completion("second stream did receive")
        let secondDidComplete = Completion("second stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        firstDecodedResponse.value = value
                    case let .failure(error):
                        firstDecodingError.value = error
                    }
                    firstStream.complete()
                    firstDidReceive.complete()
                case let .complete(completion):
                    firstCompleteOnMain.value = Thread.isMainThread
                    firstResponse.value = completion.response
                    firstDidComplete.complete()
                }
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        secondDecodedResponse.value = value
                    case let .failure(error):
                        secondDecodingError.value = error
                    }
                    secondStream.complete()
                    secondDidReceive.complete()
                case let .complete(completion):
                    secondCompleteOnMain.value = Thread.isMainThread
                    secondResponse.value = completion.response
                    secondDidComplete.complete()
                }
            }
            .resume()

        await wait(for: [firstStream, secondStream], enforceOrder: true)
        // Cannot test order of completion events, as one may have been enqueued while the other executed directly.
        await wait(for: [firstDidReceive, firstDidComplete], enforceOrder: true)
        await wait(for: [secondDidReceive, secondDidComplete], enforceOrder: true)

        // Then
        #expect(firstStreamOnMain.value)
        #expect(firstCompleteOnMain.value)
        #expect(firstDecodedResponse.value != nil)
        #expect(firstResponse.statusCode == 200)
        #expect(firstDecodingError.value == nil)
        #expect(secondStreamOnMain.value)
        #expect(secondCompleteOnMain.value)
        #expect(secondDecodedResponse.value != nil)
        #expect(secondResponse.statusCode == 200)
        #expect(secondDecodingError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamWorksCorrectlyWithMultipleConcurrentQueues() async {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue", attributes: .concurrent)
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue", attributes: .concurrent)
        let session = Session.independent(requestQueue: requestQueue, serializationQueue: serializationQueue)
        let firstResponse = Capture<HTTPURLResponse?>()
        let firstDecodedResponse = Capture<TestResponse?>()
        let firstDecodingError = Capture<AFError?>()
        let firstStreamOnMain = Capture(false)
        let firstCompleteOnMain = Capture(false)
        let firstDidReceive = Completion("first stream did receive")
        let firstDidComplete = Completion("first stream complete")
        let secondResponse = Capture<HTTPURLResponse?>()
        let secondDecodedResponse = Capture<TestResponse?>()
        let secondDecodingError = Capture<AFError?>()
        let secondStreamOnMain = Capture(false)
        let secondCompleteOnMain = Capture(false)
        let secondDidReceive = Completion("second stream did receive")
        let secondDidComplete = Completion("second stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        firstDecodedResponse.value = value
                    case let .failure(error):
                        firstDecodingError.value = error
                    }
                    firstDidReceive.complete()
                case let .complete(completion):
                    firstCompleteOnMain.value = Thread.isMainThread
                    firstResponse.value = completion.response
                    firstDidComplete.complete()
                }
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain.value = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        secondDecodedResponse.value = value
                    case let .failure(error):
                        secondDecodingError.value = error
                    }
                    secondDidReceive.complete()
                case let .complete(completion):
                    secondCompleteOnMain.value = Thread.isMainThread
                    secondResponse.value = completion.response
                    secondDidComplete.complete()
                }
            }

        await wait(for: [firstDidReceive, firstDidComplete], enforceOrder: true)
        await wait(for: [secondDidReceive, secondDidComplete], enforceOrder: true)

        // Then
        #expect(firstStreamOnMain.value)
        #expect(firstCompleteOnMain.value)
        #expect(firstDecodedResponse.value != nil)
        #expect(firstResponse.statusCode == 200)
        #expect(firstDecodingError.value == nil)
        #expect(secondStreamOnMain.value)
        #expect(secondCompleteOnMain.value)
        #expect(secondDecodedResponse.value != nil)
        #expect(secondResponse.statusCode == 200)
        #expect(secondDecodingError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamCanAuthenticate() async {
        // Given
        let session = stored(Session.independent())
        let user = "userstream", password = "password"
        let response = Capture<HTTPURLResponse?>()
        let streamOnMain = Capture(false)
        let completeOnMain = Capture(false)
        let didReceive = Completion("stream did receive")
        let didComplete = Completion("stream complete")

        // When
        session.streamRequest(.basicAuth(forUser: user, password: password))
            .authenticate(username: user, password: password)
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    streamOnMain.value = Thread.isMainThread
                    didReceive.complete()
                case let .complete(completion):
                    completeOnMain.value = Thread.isMainThread
                    response.value = completion.response
                    didComplete.complete()
                }
            }

        await wait(for: [didReceive, didComplete], enforceOrder: true)

        // Then
        #expect(streamOnMain.value)
        #expect(completeOnMain.value)
        #expect(response.statusCode == 200)
    }
}

@Suite(.storesInstances)
struct DataStreamLifetimeEvents {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestHasAppropriateLifetimeEvents() async {
        // Given
        final class Monitor: EventMonitor {
            private let called: (@Sendable () -> Void)?

            init(called: (@Sendable () -> Void)? = nil) {
                self.called = called
            }

            func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>) {
                called?()
            }
        }
        let eventMonitor = ClosureEventMonitor()
        // Disable event test until Firewalk supports HTTPS.
        //  let didReceiveChallenge = Completion("didReceiveChallenge should fire")
        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didReceiveData = Completion("didReceiveData should fire")
        let willCacheResponse = Completion("willCacheResponse should fire")
        let didCreateURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateTask = Completion("didCreateTask should fire")
        let didGatherMetrics = Completion("didGatherMetrics should fire")
        let didComplete = Completion("didComplete should fire")
        let didFinish = Completion("didFinish should fire")
        let didResume = Completion("didResume should fire")
        let didResumeTask = Completion("didResumeTask should fire")
        let didValidate = Completion("didValidateRequest should fire", expectedCount: 2)
        let didParse = Completion("streamDidParse should fire")
        let didReceive = Completion("stream should receive")
        let didCompleteStream = Completion("stream should complete")

        let dataReceived = Capture(false)

        // Disable event test until Firewalk supports HTTPS.
        //  eventMonitor.taskDidReceiveChallenge = { _, _, _ in didReceiveChallenge.complete() }
        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.complete() }
        eventMonitor.dataTaskDidReceiveData = { _, _, _ in
            guard !dataReceived.value else { return }
            // Data may be received many times, fulfill only once.
            dataReceived.value = true
            didReceiveData.complete()
        }
        eventMonitor.dataTaskWillCacheResponse = { _, _, _ in willCacheResponse.complete() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.complete() }
        eventMonitor.requestDidValidateRequestResponseWithResult = { _, _, _, _ in didValidate.complete() }

        let session = Session.independent(eventMonitors: [eventMonitor, Monitor { didParse.complete() }])

        // When
        let request = session.streamRequest(.stream(1))
            .validate()
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case .stream:
                    didReceive.complete()
                case .complete:
                    didCompleteStream.complete()
                }
            }

        await wait(for: [taskDidFinishCollecting, didReceiveData, willCacheResponse, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didFinish, didResume, didResumeTask, didValidate, didParse, didReceive, didCompleteStream])

        // Then
        #expect(request.state == .finished)
    }
}
