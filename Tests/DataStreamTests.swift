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
        let expectedSize = 1000
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/\(expectedSize)")).responseStream { stream in
            switch stream.event {
            case let .stream(result):
                streamOnMain = Thread.isMainThread
                switch result {
                case let .success(data):
                    accumulatedData.append(data)
                }
            case let .complete(completion):
                completeOnMain = Thread.isMainThread
                response = completion.response
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedFromURL() {
        // Given
        let expectedSize = 1000
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest("https://httpbin.org/bytes/\(expectedSize)").responseStream { stream in
            switch stream.event {
            case let .stream(result):
                streamOnMain = Thread.isMainThread
                switch result {
                case let .success(data):
                    accumulatedData.append(data)
                }
            case let .complete(completion):
                completeOnMain = Thread.isMainThread
                response = completion.response
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedManyTimes() {
        // Given
        let expectedSize = 1000
        var firstAccumulatedData = Data()
        var firstResponse: HTTPURLResponse?
        var firstStreamOnMain = false
        var firstCompleteOnMain = false
        let firstExpectation = expectation(description: "first stream should complete")
        var secondAccumulatedData = Data()
        var secondResponse: HTTPURLResponse?
        var secondStreamOnMain = false
        var secondCompleteOnMain = false
        let secondExpectation = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/\(expectedSize)"))
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        firstAccumulatedData.append(data)
                    }
                case let .complete(completion):
                    firstCompleteOnMain = Thread.isMainThread
                    firstResponse = completion.response
                    firstExpectation.fulfill()
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
                case let .complete(completion):
                    secondCompleteOnMain = Thread.isMainThread
                    secondResponse = completion.response
                    secondExpectation.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

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
        let firstExpectation = expectation(description: "first stream should complete")
        var decodedResponse: HTTPBinResponse?
        var decodingError: AFError?
        var secondResponse: HTTPURLResponse?
        var secondStreamOnMain = false
        var secondCompleteOnMain = false
        let secondExpectation = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    firstStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        firstAccumulatedData.append(data)
                    }
                case let .complete(completion):
                    firstCompleteOnMain = Thread.isMainThread
                    firstResponse = completion.response
                    firstExpectation.fulfill()
                }
            }
            .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    secondStreamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                case let .complete(completion):
                    secondCompleteOnMain = Thread.isMainThread
                    secondResponse = completion.response
                    secondExpectation.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

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

    func testThatDataStreamRequestProducesWorkingInputStream() {
        // Given
        let expect = expectation(description: "stream complete")

        // When
        let stream = AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "xml",
                                                                    headers: [.contentType("application/xml")]))
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

    func testThatDataStreamCanBeManuallyResumed() {
        // Given
        let session = Session(startRequestsImmediately: false)
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream complete")

        // When
        session.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    streamOnMain = Thread.isMainThread
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }.resume()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamIsAutomaticallyCanceledOnStreamErrorWhenEnabled() {
        var response: HTTPURLResponse?
        var complete: DataStreamRequest.Completion?
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/50"), automaticallyCancelOnStreamError: true)
            .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                switch stream.event {
                case let .complete(completion):
                    complete = completion
                    response = completion.response
                    expect.fulfill()
                default: break
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(complete?.error?.isExplicitlyCancelledError == true)
    }

    func testThatDataStreamIsAutomaticallyCanceledOnStreamClosureError() {
        // Given
        enum LocalError: Error { case failed }

        var response: HTTPURLResponse?
        var complete: DataStreamRequest.Completion?
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/50"))
            .responseStream { stream in
                switch stream.event {
                case .stream: throw LocalError.failed
                case let .complete(completion):
                    complete = completion
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(complete?.error?.isExplicitlyCancelledError == false)
    }

    func testThatDataStreamCanBeCancelledInClosure() {
        // Given
        let expectedSize = 1000
        var error: AFError?
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest("https://httpbin.org/bytes/\(expectedSize)").responseStream { stream in
            switch stream.event {
            case .stream:
                stream.cancel()
            case .complete:
                error = stream.completion?.error
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(error?.isExplicitlyCancelledError == true)
    }

    func testThatDataStreamCanBeCancelledByToken() {
        // Given
        let expectedSize = 1000
        var error: AFError?
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest("https://httpbin.org/bytes/\(expectedSize)").responseStream { stream in
            switch stream.event {
            case .stream:
                stream.token.cancel()
            case .complete:
                error = stream.completion?.error
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(error?.isExplicitlyCancelledError == true)
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
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .responseStreamString { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(string):
                        responseString = string
                    }
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(responseString)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamsCanBeDecoded() {
        // Given
        // Only 1 right now, as multiple responses return invalid JSON from httpbin.org.
        let count = 1
        var responses: [HTTPBinResponse] = []
        var response: HTTPURLResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/\(count)"))
            .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        responses.append(value)
                    case let .failure(error):
                        decodingError = error
                    }
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertEqual(responses.count, count)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(decodingError)
    }

    func testThatDataStreamSerializerCanBeUsedDirectly() {
        // Given
        var response: HTTPURLResponse?
        var decodedResponse: HTTPBinResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let serializer = DecodableStreamSerializer<HTTPBinResponse>()
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
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
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

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
        let request = URLRequest.makeHTTPBinRequest(path: "status/401")
        var dataSeen = false
        var error: AFError?
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest(request).validate().responseStream { stream in
            switch stream.event {
            case .stream: dataSeen = true
            case let .complete(completion):
                error = completion.error
                expect.fulfill()
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
                    completion(.success(URLRequest.makeHTTPBinRequest(path: "bytes/1000")))
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
        let expect = expectation(description: "stream should complete")

        // When
        session.streamRequest(URLRequest.makeHTTPBinRequest(path: "status/401"))
            .validate()
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(data):
                        accumulatedData.append(data)
                    }
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertEqual(accumulatedData.count, 1000)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamCanBeRedirected() {
        // Given
        var response: HTTPURLResponse?
        var decodedResponse: HTTPBinResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let redirected = expectation(description: "stream redirected")
        let redirector = Redirector(behavior: .modify { _, _, _ in
            redirected.fulfill()
            return URLRequest.makeHTTPBinRequest(path: "stream/1")
        })
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "status/301"))
            .redirect(using: redirector)
            .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

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
        var decodedResponse: HTTPBinResponse?
        var decodingError: AFError?
        var streamOnMain = false
        var completeOnMain = false
        let cached = expectation(description: "stream called cacher")
        let cacher = ResponseCacher(behavior: .modify { _, _ in
            cached.fulfill()
            return nil
        })
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .cacheResponse(using: cacher)
            .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                switch stream.event {
                case let .stream(result):
                    streamOnMain = Thread.isMainThread
                    switch result {
                    case let .success(value):
                        decodedResponse = value
                    case let .failure(error):
                        decodingError = error
                    }
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(streamOnMain)
        XCTAssertTrue(completeOnMain)
        XCTAssertNotNil(decodedResponse)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(decodingError)
    }

    func testThatDataStreamCanAuthenticate() {
        // Given
        var response: HTTPURLResponse?
        var streamOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "basic-auth/username/password"))
            .authenticate(username: "username", password: "password")
            .responseStream { stream in
                switch stream.event {
                case .stream:
                    streamOnMain = Thread.isMainThread
                case let .complete(completion):
                    completeOnMain = Thread.isMainThread
                    response = completion.response
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

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

        let didReceiveChallenge = expectation(description: "didReceiveChallenge should fire")
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
        let responseHandler = expectation(description: "responseHandler should fire")

        var dataReceived = false

        eventMonitor.taskDidReceiveChallenge = { _, _, _ in didReceiveChallenge.fulfill() }
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
        let request = session.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .validate()
            .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                switch stream.event {
                case .complete:
                    responseHandler.fulfill()
                default: break
                }
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }
}
