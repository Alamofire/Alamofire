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

import Alamofire
import XCTest

final class DataStreamTests: BaseTestCase {
    func testThatDataCanBeStreamedOnMainQueue() {
        // Given
        let expectedSize = 10
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let didReceive = expectation(description: "stream should receive once")
        let didComplete = expectation(description: "stream should complete")

        // When
        AF.streamRequest(.bytes(expectedSize)).responseStream { stream in
            switch stream.event {
            case let .stream(result):
                streamOnMain = Thread.isMainThread
                switch result {
                case let .success(data):
                    accumulatedData.append(data)
                }
                didReceive.fulfill()
            case let .complete(completion):
                completeOnMain = Thread.isMainThread
                response = completion.response
                didComplete.fulfill()
            }
        }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedByByte() {
        // Given
        let expectedSize = 10
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        var streamCalled = 0
        let didReceive = expectation(description: "stream should receive once")
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            didReceive.expectedFulfillmentCount = expectedSize
        }
        let didComplete = expectation(description: "stream should complete")

        // When
        AF.streamRequest(.chunked(expectedSize)).responseStream { stream in
            switch stream.event {
            case let .stream(result):
                streamOnMain = Thread.isMainThread
                switch result {
                case let .success(data):
                    accumulatedData.append(data)
                }
                streamCalled += 1
                didReceive.fulfill()
            case let .complete(completion):
                completeOnMain = Thread.isMainThread
                response = completion.response
                didComplete.fulfill()
            }
        }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        // Older OSes don't return individual bytes.
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            XCTAssertEqual(streamCalled, expectedSize)
        } else {
            XCTAssertEqual(streamCalled, 1)
        }
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedAsMultipleJSONPayloads() throws {
        guard #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Older OSes do not separate chunked payloads in callbacks.")
        }

        // Given
        let expectedSize = 10
        var responses: [TestResponse] = []
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        var streamCalled = 0
        let didReceive = expectation(description: "stream should receive once")
        didReceive.expectedFulfillmentCount = expectedSize
        let didComplete = expectation(description: "stream should complete")

        // When
        AF.streamRequest(.payloads(expectedSize))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        responses.append(value)
                    case let .failure(error):
                        XCTFail("JSON stream failed due to error: \(error.localizedDescription)")
                    }
                    streamCalled += 1
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(streamCalled, expectedSize)
        XCTAssertEqual(responses.count, expectedSize)
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedFromURL() {
        // Given
        let expectedSize = 1
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let didReceive = expectation(description: "stream should receive")
        let didComplete = expectation(description: "stream should complete")

        // When
        AF.streamRequest(.bytes(expectedSize)).responseStream { stream in
            switch stream.event {
            case let .stream(result):
                streamOnMain = Thread.isMainThread
                switch result {
                case let .success(data):
                    accumulatedData.append(data)
                }
                didReceive.fulfill()
            case let .complete(completion):
                completeOnMain = Thread.isMainThread
                response = completion.response
                didComplete.fulfill()
            }
        }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedManyTimes() {
        // Given
        let expectedSize = 1
        var firstAccumulatedData = Data()
        var firstResponse: HTTPURLResponse?
        var firstStreamOnMain = false
        var firstCompleteOnMain = false
        let firstReceive = expectation(description: "first stream should receive")
        let firstCompletion = expectation(description: "first stream should complete")
        var secondAccumulatedData = Data()
        var secondResponse: HTTPURLResponse?
        var secondStreamOnMain = false
        var secondCompleteOnMain = false
        let secondReceive = expectation(description: "second stream should receive")
        let secondCompletion = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(.bytes(expectedSize))
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        firstAccumulatedData.append(data)
                    }
                    firstReceive.fulfill()
                case let .complete(completion):
                    firstCompleteOnMain = Thread.isMainThread
                    firstResponse = completion.response
                    firstCompletion.fulfill()
                }
            }
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        secondAccumulatedData.append(data)
                    }
                    secondReceive.fulfill()
                case let .complete(completion):
                    secondCompleteOnMain = Thread.isMainThread
                    secondResponse = completion.response
                    secondCompletion.fulfill()
                }
            }

        wait(for: [firstReceive, firstCompletion], timeout: timeout, enforceOrder: true)
        wait(for: [secondReceive, secondCompletion], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(firstStreamOnMain)
        XCTAssertTrue(firstCompleteOnMain)
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertEqual(firstAccumulatedData.count, expectedSize)
        XCTAssertTrue(secondStreamOnMain)
        XCTAssertTrue(secondCompleteOnMain)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertEqual(secondAccumulatedData.count, expectedSize)
    }

    func testThatDataCanBeStreamedAndDecodedAtTheSameTime() {
        // Given
        var firstAccumulatedData = Data()
        var firstResponse: HTTPURLResponse?
        var firstStreamOnMain = false
        var firstCompleteOnMain = false
        let firstReceive = expectation(description: "first stream should receive")
        let firstCompletion = expectation(description: "first stream should complete")
        var decodedResponse: TestResponse?
        var decodingError: AFError?
        var secondResponse: HTTPURLResponse?
        var secondStreamOnMain = false
        var secondCompleteOnMain = false
        let secondReceive = expectation(description: "second stream should receive")
        let secondCompletion = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(.stream(1))
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        firstAccumulatedData.append(data)
                    }
                    firstReceive.fulfill()
                case let .complete(completion):
                    firstCompleteOnMain = Thread.isMainThread
                    firstResponse = completion.response
                    firstCompletion.fulfill()
                }
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                    secondReceive.fulfill()
                case let .complete(completion):
                    secondCompleteOnMain = Thread.isMainThread
                    secondResponse = completion.response
                    secondCompletion.fulfill()
                }
            }

        wait(for: [firstReceive, firstCompletion], timeout: timeout, enforceOrder: true)
        wait(for: [secondReceive, secondCompletion], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(firstStreamOnMain)
        XCTAssertTrue(firstCompleteOnMain)
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertTrue(!firstAccumulatedData.isEmpty)
        XCTAssertTrue(secondStreamOnMain)
        XCTAssertTrue(secondCompleteOnMain)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertNotNil(decodedResponse)
        XCTAssertNil(decodingError)
    }

    #if !(os(Linux) || os(Windows))
    func testThatDataStreamRequestProducesWorkingInputStream() {
        // Given
        let expect = expectation(description: "stream complete")

        // When
        let stream = AF.streamRequest(.xml)
            .responseStream { stream in
                switch stream.event {
                case .complete:
                    expect.fulfill()
                default: break
                }
            }.asInputStream()

        waitForExpectations(timeout: timeout)

        // Then
        let parser = XMLParser(stream: stream!)
        let parsed = parser.parse()
        XCTAssertTrue(parsed)
        XCTAssertNil(parser.parserError)
    }
    #endif

    func testThatDataStreamCanBeManuallyResumed() {
        // Given
        let session = Session(startRequestsImmediately: false)
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let didReceive = expectation(description: "stream did receive")
        let didComplete = expectation(description: "stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    streamOnMain = Thread.isMainThread
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }.resume()

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamIsAutomaticallyCanceledOnStreamErrorWhenEnabled() {
        var response: HTTPURLResponse?
        var complete: DataStreamRequest.Completion?
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.bytes(50), automaticallyCancelOnStreamError: true)
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .complete(completion):
                    complete = completion
                    response = completion.response
                    didComplete.fulfill()
                default: break
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(complete?.error?.isExplicitlyCancelledError == true,
                      "error is not explicitly cancelled but \(complete?.error?.localizedDescription ?? "None")")
    }

    func testThatDataStreamIsAutomaticallyCanceledOnStreamClosureError() {
        // Given
        enum LocalError: Error { case failed }

        var response: HTTPURLResponse?
        var complete: DataStreamRequest.Completion?
        let didReceive = expectation(description: "stream did receieve")
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.bytes(50))
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    didReceive.fulfill()
                    throw LocalError.failed
                case let .complete(completion):
                    complete = completion
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(complete?.error?.isExplicitlyCancelledError == false)
    }

    func testThatDataStreamCanBeCancelledInClosure() {
        // Given
        // Use .main so that completion can't beat cancellation.
        let session = Session(rootQueue: .main)
        var completion: DataStreamRequest.Completion?
        let didReceive = expectation(description: "stream should receive")
        let didComplete = expectation(description: "stream should complete")

        // When
        session.streamRequest(.bytes(1)).responseStream { stream in
            switch stream.event {
            case .stream:
                didReceive.fulfill()
                stream.cancel()
            case .complete:
                completion = stream.completion
                didComplete.fulfill()
            }
        }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(completion?.error?.isExplicitlyCancelledError == true,
                      """
                      error is not explicitly cancelled, instead: \(completion?.error?.localizedDescription ?? "none").
                      response is: \(completion?.response?.description ?? "none").
                      """)
    }

    func testThatDataStreamCanBeCancelledByToken() {
        // Given
        // Use .main so that completion can't beat cancellation.
        let session = Session(rootQueue: .main)
        var completion: DataStreamRequest.Completion?
        let didReceive = expectation(description: "stream should receive")
        let didComplete = expectation(description: "stream should complete")

        // When
        session.streamRequest(.bytes(1)).responseStream { stream in
            switch stream.event {
            case .stream:
                didReceive.fulfill()
                stream.token.cancel()
            case .complete:
                completion = stream.completion
                didComplete.fulfill()
            }
        }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(completion?.error?.isExplicitlyCancelledError == true,
                      """
                      error is not explicitly cancelled, instead: \(completion?.error?.localizedDescription ?? "none").
                      response is: \(completion?.response?.description ?? "none").
                      """)
    }
}

// MARK: - Serialization Tests

final class DataStreamSerializationTests: BaseTestCase {
    func testThatDataStreamsCanBeAString() {
        // Given
        var responseString: String?
        var streamOnMain = false
        var completeOnMain = false
        var response: HTTPURLResponse?
        let didStream = expectation(description: "did stream")
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.stream(1))
            .responseStreamString { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(string):
                        responseString = string
                    }
                    didStream.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didStream, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(responseString)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamsCanBeDecoded() {
        // Given
        var response: TestResponse?
        var httpResponse: HTTPURLResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let didReceive = expectation(description: "stream did receive")
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        response = value
                    case let .failure(error):
                        decodingError = error
                    }
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    httpResponse = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(response)
        XCTAssertEqual(httpResponse?.statusCode, 200)
        XCTAssertNil(decodingError)
    }

    func testThatDataStreamSerializerCanBeUsedDirectly() {
        // Given
        var response: HTTPURLResponse?
        var decodedResponse: TestResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let serializer = DecodableStreamSerializer<TestResponse>()
        let didReceive = expectation(description: "stream did receive")
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.stream(1))
            .responseStream(using: serializer) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(decodedResponse)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(decodingError)
    }
}

// MARK: - Integration Tests

final class DataStreamIntegrationTests: BaseTestCase {
    func testThatDataStreamCanFailValidation() {
        // Given
        var dataSeen = false
        var error: AFError?
        let didComplete = expectation(description: "stream should complete")

        // When
        AF.streamRequest(.status(401))
            .validate()
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    dataSeen = true
                case let .complete(completion):
                    error = completion.error
                    didComplete.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertTrue(error?.isResponseValidationError == true, "error should be response validation error")
        XCTAssertFalse(dataSeen, "no data should be seen")
    }

    func testThatDataStreamsCanBeRetried() {
        // Given
        final class GoodRetry: RequestInterceptor {
            var hasRetried = false

            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
                if hasRetried {
                    completion(.success(Endpoint.bytes(1000).urlRequest))
                } else {
                    completion(.success(urlRequest))
                }
            }

            func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
                hasRetried = true
                completion(.retry)
            }
        }

        let session = Session(interceptor: GoodRetry())
        var accumulatedData = Data()
        var streamOnMain = false
        var completeOnMain = false
        var response: HTTPURLResponse?
        let didReceive = expectation(description: "stream should receive")
        let didComplete = expectation(description: "stream should complete")

        // When
        session.streamRequest(.status(401))
            .validate()
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.append(data)
                    }
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertEqual(accumulatedData.count, 1000)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamCanBeRedirected() {
        // Given
        var response: HTTPURLResponse?
        var decodedResponse: TestResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let didRedirect = expectation(description: "stream redirected")
        let redirector = Redirector(behavior: .modify { _, _, _ in
            didRedirect.fulfill()
            return Endpoint.stream(1).urlRequest
        })
        let didReceive = expectation(description: "stream should receive")
        let didComplete = expectation(description: "stream should complete")

        // When
        AF.streamRequest(.status(301))
            .redirect(using: redirector)
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didRedirect, didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(decodedResponse)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(decodingError)
    }

    func testThatDataStreamCallsCachedResponseHandler() {
        // Given
        var response: HTTPURLResponse?
        var decodedResponse: TestResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let cached = expectation(description: "stream called cacher")
        let cacher = ResponseCacher(behavior: .modify { _, _ in
            cached.fulfill()
            return nil
        })
        let didReceive = expectation(description: "stream did receive")
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.stream(1))
            .cacheResponse(using: cacher)
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        // willCacheResponse called after receiving all Data, so may be called before or after the asynchronous stream
        // handlers.
        wait(for: [cached], timeout: timeout)
        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(decodedResponse)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(decodingError)
    }

    func testThatDataStreamWorksCorrectlyWithMultipleSerialQueues() {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue")
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let session = Session(requestQueue: requestQueue, serializationQueue: serializationQueue)
        var firstResponse: HTTPURLResponse?
        var firstDecodedResponse: TestResponse?
        var firstDecodingError: AFError?
        var firstStreamOnMain = false
        var firstCompleteOnMain = false
        let firstStream = expectation(description: "first stream")
        let firstDidReceive = expectation(description: "first stream did receive")
        let firstDidComplete = expectation(description: "first stream complete")
        var secondResponse: HTTPURLResponse?
        var secondDecodedResponse: TestResponse?
        var secondDecodingError: AFError?
        var secondStreamOnMain = false
        var secondCompleteOnMain = false
        let secondStream = expectation(description: "second stream")
        let secondDidReceive = expectation(description: "second stream did receive")
        let secondDidComplete = expectation(description: "second stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        firstDecodedResponse = value
                    case let .failure(error):
                        firstDecodingError = error
                    }
                    firstStream.fulfill()
                    firstDidReceive.fulfill()
                case let .complete(completion):
                    firstCompleteOnMain = Thread.isMainThread
                    firstResponse = completion.response
                    firstDidComplete.fulfill()
                }
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        secondDecodedResponse = value
                    case let .failure(error):
                        secondDecodingError = error
                    }
                    secondStream.fulfill()
                    secondDidReceive.fulfill()
                case let .complete(completion):
                    secondCompleteOnMain = Thread.isMainThread
                    secondResponse = completion.response
                    secondDidComplete.fulfill()
                }
            }

        wait(for: [firstStream, secondStream], timeout: timeout, enforceOrder: true)
        // Cannot test order of completion events, as one may have been enqueued while the other executed directly.
        wait(for: [firstDidReceive, firstDidComplete], timeout: timeout, enforceOrder: true)
        wait(for: [secondDidReceive, secondDidComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(firstStreamOnMain)
        XCTAssertTrue(firstCompleteOnMain)
        XCTAssertNotNil(firstDecodedResponse)
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertNil(firstDecodingError)
        XCTAssertTrue(secondStreamOnMain)
        XCTAssertTrue(secondCompleteOnMain)
        XCTAssertNotNil(secondDecodedResponse)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertNil(secondDecodingError)
    }

    func testThatDataStreamWorksCorrectlyWithMultipleConcurrentQueues() {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue", attributes: .concurrent)
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue", attributes: .concurrent)
        let session = Session(requestQueue: requestQueue, serializationQueue: serializationQueue)
        var firstResponse: HTTPURLResponse?
        var firstDecodedResponse: TestResponse?
        var firstDecodingError: AFError?
        var firstStreamOnMain = false
        var firstCompleteOnMain = false
        let firstDidReceive = expectation(description: "first stream did receive")
        let firstDidComplete = expectation(description: "first stream complete")
        var secondResponse: HTTPURLResponse?
        var secondDecodedResponse: TestResponse?
        var secondDecodingError: AFError?
        var secondStreamOnMain = false
        var secondCompleteOnMain = false
        let secondDidReceive = expectation(description: "second stream did receive")
        let secondDidComplete = expectation(description: "second stream complete")

        // When
        session.streamRequest(.stream(1))
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        firstDecodedResponse = value
                    case let .failure(error):
                        firstDecodingError = error
                    }
                    firstDidReceive.fulfill()
                case let .complete(completion):
                    firstCompleteOnMain = Thread.isMainThread
                    firstResponse = completion.response
                    firstDidComplete.fulfill()
                }
            }
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        secondDecodedResponse = value
                    case let .failure(error):
                        secondDecodingError = error
                    }
                    secondDidReceive.fulfill()
                case let .complete(completion):
                    secondCompleteOnMain = Thread.isMainThread
                    secondResponse = completion.response
                    secondDidComplete.fulfill()
                }
            }

        wait(for: [firstDidReceive, firstDidComplete], timeout: timeout, enforceOrder: true)
        wait(for: [secondDidReceive, secondDidComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(firstStreamOnMain)
        XCTAssertTrue(firstCompleteOnMain)
        XCTAssertNotNil(firstDecodedResponse)
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertNil(firstDecodingError)
        XCTAssertTrue(secondStreamOnMain)
        XCTAssertTrue(secondCompleteOnMain)
        XCTAssertNotNil(secondDecodedResponse)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertNil(secondDecodingError)
    }

    func testThatDataStreamCanAuthenticate() {
        // Given
        let user = "userstream", password = "password"
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let didReceive = expectation(description: "stream did receive")
        let didComplete = expectation(description: "stream complete")

        // When
        AF.streamRequest(.basicAuth(forUser: user, password: password))
            .authenticate(username: user, password: password)
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    streamOnMain = Thread.isMainThread
                    didReceive.fulfill()
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    didComplete.fulfill()
                }
            }

        wait(for: [didReceive, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertEqual(response?.statusCode, 200)
    }
}

final class DataStreamLifetimeEvents: BaseTestCase {
    func testThatDataStreamRequestHasAppropriateLifetimeEvents() {
        // Given
        final class Monitor: EventMonitor {
            var called: (() -> Void)?

            func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>) {
                called?()
            }
        }
        let eventMonitor = ClosureEventMonitor()
        let parseMonitor = Monitor()
        let session = Session(eventMonitors: [eventMonitor, parseMonitor])

        // Disable event test until Firewalk supports HTTPS.
        //  let didReceiveChallenge = expectation(description: "didReceiveChallenge should fire")
        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didReceiveData = expectation(description: "didReceiveData should fire")
        let willCacheResponse = expectation(description: "willCacheResponse should fire")
        let didCreateURLRequest = expectation(description: "didCreateInitialURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didValidate = expectation(description: "didValidateRequest should fire")
        didValidate.expectedFulfillmentCount = 2
        let didParse = expectation(description: "streamDidParse should fire")
        let didReceive = expectation(description: "stream should receive")
        let didCompleteStream = expectation(description: "stream should complete")

        var dataReceived = false

        // Disable event test until Firewalk supports HTTPS.
        //  eventMonitor.taskDidReceiveChallenge = { _, _, _ in didReceiveChallenge.fulfill() }
        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.fulfill() }
        eventMonitor.dataTaskDidReceiveData = { _, _, _ in
            guard !dataReceived else { return }
            // Data may be received many times, fulfill only once.
            dataReceived = true
            didReceiveData.fulfill()
        }
        eventMonitor.dataTaskWillCacheResponse = { _, _, _ in willCacheResponse.fulfill() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.fulfill() }
        eventMonitor.requestDidFinish = { _ in didFinish.fulfill() }
        eventMonitor.requestDidResume = { _ in didResume.fulfill() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.fulfill() }
        eventMonitor.requestDidValidateRequestResponseWithResult = { _, _, _, _ in didValidate.fulfill() }
        parseMonitor.called = { didParse.fulfill() }

        // When
        let request = session.streamRequest(.stream(1))
            .validate()
            .responseStreamDecodable(of: TestResponse.self) { stream in
                switch stream.event {
                case .stream:
                    didReceive.fulfill()
                case .complete:
                    didCompleteStream.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request.state, .finished)
    }
}
