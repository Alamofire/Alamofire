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
        var sawError = false
        var valueOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/\(expectedSize)")).responseStream { output in
            switch output {
            case let .value(data):
                accumulatedData.append(data)
                valueOnMain = Thread.isMainThread
            case .error: sawError = true
            case let .complete(_, resp, _):
                response = resp
                completeOnMain = Thread.isMainThread
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertFalse(sawError)
        XCTAssertTrue(valueOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataCanBeStreamedManyTimes() {
        // Given
        let expectedSize = 1000
        var firstAccumulatedData = Data()
        var firstResponse: HTTPURLResponse?
        var firstSawError = false
        let firstExpectation = expectation(description: "first stream should complete")
        var secondAccumulatedData = Data()
        var secondResponse: HTTPURLResponse?
        var secondSawError = false
        let secondExpectation = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/\(expectedSize)"))
            .responseStream { output in
                switch output {
                case let .value(data): firstAccumulatedData.append(data)
                case .error: firstSawError = true
                case let .complete(_, resp, _):
                    firstResponse = resp
                    firstExpectation.fulfill()
                }
            }
            .responseStream { output in
                switch output {
                case let .value(data): secondAccumulatedData.append(data)
                case .error: secondSawError = true
                case let .complete(_, resp, _):
                    secondResponse = resp
                    secondExpectation.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertEqual(firstAccumulatedData.count, expectedSize)
        XCTAssertFalse(firstSawError)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertEqual(secondAccumulatedData.count, expectedSize)
        XCTAssertFalse(secondSawError)
    }

    func testThatDataCanBeStreamedAndDecodedAtTheSameTime() {
        // Given
        var firstAccumulatedData = Data()
        var firstResponse: HTTPURLResponse?
        var firstSawError = false
        let firstExpectation = expectation(description: "first stream should complete")
        var response: HTTPBinResponse?
        var secondResponse: HTTPURLResponse?
        var secondSawError = false
        let secondExpectation = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .responseStream { output in
                switch output {
                case let .value(data): firstAccumulatedData.append(data)
                case .error: firstSawError = true
                case let .complete(_, resp, _):
                    firstResponse = resp
                    firstExpectation.fulfill()
                }
            }
            .responseStreamDecodable(of: HTTPBinResponse.self) { output in
                switch output {
                case let .value(value): response = value
                case .error: secondSawError = true
                case let .complete(_, resp, _):
                    secondResponse = resp
                    secondExpectation.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertTrue(firstAccumulatedData.count > 0)
        XCTAssertFalse(firstSawError)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertNotNil(response)
        XCTAssertFalse(secondSawError)
    }

    func testThatDataStreamCanFailValidation() {
        // Given
        let request = URLRequest.makeHTTPBinRequest(path: "status/401")
        var dataSeen = false
        var sawError = false
        var error: AFError?
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest(request).validate().responseStream { output in
            switch output {
            case .value: dataSeen = true
            case .error: sawError = true
            case let .complete(_, _, err):
                error = err
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        NSLog(error?.localizedDescription ?? "No error description.")
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertTrue(error?.isResponseValidationError == true, "error should be response validation error")
        XCTAssertFalse(dataSeen, "no data should be seen")
        XCTAssertFalse(sawError, "no stream error should be seen")
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
        var response: HTTPURLResponse?
        var sawError = false
        let expect = expectation(description: "stream should complete")

        // When
        session.streamRequest(URLRequest.makeHTTPBinRequest(path: "status/401"))
            .validate()
            .responseStream { output in
                switch output {
                case let .value(data): accumulatedData.append(data)
                case .error: sawError = true
                case let .complete(_, resp, _):
                    response = resp
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(accumulatedData.count, 1000)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertFalse(sawError)
    }

    func testThatDataStreamsCanBeAString() {
        // Given
        // Only 1 right now, as multiple responses return invalid JSON from httpbin.org.
        let count = 1
        var responses: [String] = []
        var response: HTTPURLResponse?
        var sawError = false
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/\(count)"))
            .responseStreamString { output in
                switch output {
                case let .value(value):
                    responses.append(value)
                case .error:
                    sawError = true
                case let .complete(_, resp, _):
                    response = resp
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(responses.count, count)
        XCTAssertFalse(sawError)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataStreamsCanBeDecoded() {
        // Given
        // Only 1 right now, as multiple responses return invalid JSON from httpbin.org.
        let count = 1
        var responses: [HTTPBinResponse] = []
        var response: HTTPURLResponse?
        var sawError = false
        var valueOnMain = false
        var completeOnMain = false
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/\(count)"))
            .responseStreamDecodable(of: HTTPBinResponse.self) { output in
                switch output {
                case let .value(value):
                    responses.append(value)
                    valueOnMain = Thread.isMainThread
                case .error:
                    sawError = true
                case let .complete(_, resp, _):
                    response = resp
                    completeOnMain = Thread.isMainThread
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(responses.count, count)
        XCTAssertFalse(sawError)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertTrue(valueOnMain)
        XCTAssertTrue(completeOnMain)
    }

    func testThatDataStreamRequestHasAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

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

        // When
        let request = session.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/1"))
            .validate()
            .responseStreamDecodable(of: HTTPBinResponse.self) { output in
                switch output {
                case .complete:
                    responseHandler.fulfill()
                default: break
                }
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatDataStreamRequestProducesWorkingInputStream() {
        // Given
        var accumulatedData = Data()
        let expect = expectation(description: "stream complete")

        // When
        let stream = AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "xml", headers: [.contentType("application/xml")]))
            .responseStream { output in
                switch output {
                case let .value(data):
                    accumulatedData.append(data)
                case .error:
                    break
                case .complete:
                    expect.fulfill()
                }
            }.asInputStream()

        waitForExpectations(timeout: timeout)

        // Then
        let parser = XMLParser(stream: stream)
        let parsed = parser.parse()
        XCTAssertTrue(parsed)
        XCTAssertNil(parser.parserError)
    }
}
