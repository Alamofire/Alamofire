//
//  CombineTests.swift
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

#if canImport(Combine)

import Alamofire
import Combine
import XCTest

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
final class DataRequestCombineTests: CombineTestCase {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatNonAutomaticDataRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let session = Session(startRequestsImmediately: false)
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            session.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanPublishData() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let session = Session(startRequestsImmediately: false)
        var response: DataResponse<Data, AFError>?

        // When
        store {
            session.request(URLRequest.makeHTTPBinRequest())
                .publishData()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanPublishString() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let session = Session(startRequestsImmediately: false)
        var response: DataResponse<String, AFError>?

        // When
        store {
            session.request(URLRequest.makeHTTPBinRequest())
                .publishString()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanBePublishedUnserialized() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DataResponse<Data?, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishUnserialized()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanBePublishedWithMultipleHandlers() {
        // Given
        let handlerResponseReceived = expectation(description: "handler response should be received")
        let publishedResponseReceived = expectation(description: "published response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var handlerResponse: DataResponse<HTTPBinResponse, AFError>?
        var publishedResponse: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .responseDecodable(of: HTTPBinResponse.self) { handlerResponse = $0; handlerResponseReceived.fulfill() }
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { publishedResponse = $0; publishedResponseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(handlerResponse?.result.isSuccess == true)
        XCTAssertTrue(publishedResponse?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanPublishResult() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { result = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(result?.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanPublishValue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var value: HTTPBinResponse?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .value()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { value = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(value)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanPublishValueWithFailure() {
        // Given
        let completionReceived = expectation(description: "stream should complete")
        var error: AFError?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest(path: "delay/1", timeout: 0.1))
                .publishDecodable(type: HTTPBinResponse.self)
                .value()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(err):
                        error = err
                    case .finished:
                        error = nil
                    }
                    completionReceived.fulfill()
                }, receiveValue: { _ in })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error)
        XCTAssertEqual((error?.underlyingError as? URLError)?.code, .timedOut)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDataRequestIsNotResumedUnlessSubscribed() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        let request = AF.request(URLRequest.makeHTTPBinRequest())
        let publisher = request.publishDecodable(type: HTTPBinResponse.self)

        let stateAfterPublisher = request.state

        store {
            publisher.sink(receiveCompletion: { _ in completionReceived.fulfill() },
                           receiveValue: { response = $0; responseReceived.fulfill() })
        }

        let stateAfterSubscription = request.state

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertEqual(stateAfterPublisher, .initialized)
        XCTAssertEqual(stateAfterSubscription, .resumed)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanSubscribedFromNonMainQueueButPublishedOnMainQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var receivedOnMain = false
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .subscribe(on: queue)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: {
                          receivedOnMain = Thread.isMainThread
                          response = $0
                          responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertTrue(receivedOnMain)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestPublishedOnSeparateQueueIsReceivedOnThatQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self, queue: queue)
                .sink(receiveCompletion: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                    completionReceived.fulfill()
                },
                      receiveValue: {
                    dispatchPrecondition(condition: .onQueue(queue))
                    response = $0
                    responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestPublishedOnSeparateQueueCanBeReceivedOntoMainQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var receivedOnMain = false
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self, queue: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: {
                          receivedOnMain = Thread.isMainThread
                          response = $0
                          responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertTrue(receivedOnMain)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDataRequestCanBeCancelledAutomatically() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        let request = AF.request(URLRequest.makeHTTPBinRequest())
        var token: AnyCancellable? = request
            .publishDecodable(type: HTTPBinResponse.self)
            .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                  receiveValue: { response = $0; responseReceived.fulfill() })
        token = nil

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isFailure == true)
        XCTAssertTrue(response?.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled)
        XCTAssertNil(token)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDataRequestCanBeCancelledManually() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        let request = AF.request(URLRequest.makeHTTPBinRequest())
        store {
            request
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }
        request.cancel()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isFailure == true)
        XCTAssertTrue(response?.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatMultipleDataRequestPublishersCanBeCombined() {
        // Given
        let responseReceived = expectation(description: "combined response should be received")
        let completionReceived = expectation(description: "combined stream should complete")
        var firstResponse: DataResponse<HTTPBinResponse, AFError>?
        var secondResponse: DataResponse<HTTPBinResponse, AFError>?

        // When
        let first = AF.request(URLRequest.makeHTTPBinRequest())
            .publishDecodable(type: HTTPBinResponse.self)
        let second = AF.request(URLRequest.makeHTTPBinRequest())
            .publishDecodable(type: HTTPBinResponse.self)

        store {
            Publishers.CombineLatest(first, second)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() }) { first, second in
                    firstResponse = first
                    secondResponse = second
                    responseReceived.fulfill()
                }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(firstResponse?.result.isSuccess == true)
        XCTAssertTrue(secondResponse?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatMultipleDataRequestPublishersCanBeChained() {
        // Given
        let responseReceived = expectation(description: "combined response should be received")
        let completionReceived = expectation(description: "combined stream should complete")
        var firstResponse: DataResponse<HTTPBinResponse, AFError>?
        var secondResponse: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .flatMap { response -> DataResponsePublisher<HTTPBinResponse> in
                    firstResponse = response
                    let request = URLRequest.makeHTTPBinRequest(headers: ["X-Custom": response.value?.url ?? "None"])
                    return AF.request(request)
                        .publishDecodable(type: HTTPBinResponse.self)
                }
                .sink(receiveCompletion: { _ in completionReceived.fulfill() }) { response in
                    secondResponse = response
                    responseReceived.fulfill()
                }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(firstResponse?.result.isSuccess == true)
        XCTAssertTrue(secondResponse?.result.isSuccess == true)
        XCTAssertEqual(secondResponse?.value?.headers["X-Custom"], "https://httpbin.org/get")
    }
}

// MARK: - DataStreamRequest

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
final class DataStreamRequestCombineTests: CombineTestCase {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result = value
                          case .complete:
                              responseReceived.fulfill()
                          }
                      })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatNonAutomaticDataStreamRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let session = Session(startRequestsImmediately: false)
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            session.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result = value
                          case .complete:
                              responseReceived.fulfill()
                          }
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanPublishData() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<Data, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishData()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result = value
                          case .complete:
                              responseReceived.fulfill()
                          }
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanPublishString() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<String, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishString()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result = value
                          case .complete:
                              responseReceived.fulfill()
                          }
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanBePublishedWithMultipleHandlers() {
        // Given
        let handlerResponseReceived = expectation(description: "handler response should be received")
        let publishedResponseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var handlerResult: Result<HTTPBinResponse, AFError>?
        var publishedResult: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .responseStreamDecodable(of: HTTPBinResponse.self) { stream in
                    switch stream.event {
                    case let .stream(value):
                        handlerResult = value
                    case .complete:
                        handlerResponseReceived.fulfill()
                    }
                }
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              publishedResult = value
                          case .complete:
                              publishedResponseReceived.fulfill()
                          }
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(handlerResult?.success)
        XCTAssertNotNil(publishedResult?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanPublishResult() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { received in
                          result = received
                          responseReceived.fulfill()
                 })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanPublishResultWithResponseFailure() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "delay/1", timeout: 0.1))
                .publishDecodable(type: HTTPBinResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { received in
                          result = received
                          responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(result?.success)
        XCTAssertEqual((result?.failure?.underlyingError as? URLError)?.code, .timedOut)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanPublishValue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: HTTPBinResponse?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .value()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { received in
                          response = received
                          responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanPublishValueWithFailure() {
        // Given
        let completionReceived = expectation(description: "stream should complete")
        var error: AFError?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "delay/1", timeout: 0.1))
                .publishDecodable(type: HTTPBinResponse.self)
                .value()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(err):
                        error = err
                    case .finished:
                        error = nil
                    }
                    completionReceived.fulfill()
                }, receiveValue: { _ in })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error)
        XCTAssertEqual((error?.underlyingError as? URLError)?.code, .timedOut)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDataStreamRequestIsNotResumedUnlessSubscribed() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        let request = AF.streamRequest(URLRequest.makeHTTPBinRequest())
        let publisher = request.publishDecodable(type: HTTPBinResponse.self)

        let stateAfterPublisher = request.state

        store {
            publisher.sink(receiveCompletion: { _ in completionReceived.fulfill() },
                           receiveValue: { stream in
                               switch stream.event {
                               case let .stream(value):
                                   result = value
                               case .complete:
                                   responseReceived.fulfill()
                               }
                           })
        }

        let stateAfterSubscription = request.state

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(result?.isSuccess == true)
        XCTAssertEqual(stateAfterPublisher, .initialized)
        XCTAssertEqual(stateAfterSubscription, .resumed)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestCanSubscribedFromNonMainQueueButPublishedOnMainQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var receivedOnMain = false
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .subscribe(on: queue)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          receivedOnMain = Thread.isMainThread
                          switch stream.event {
                          case let .stream(value):
                              result = value
                          case .complete:
                              responseReceived.fulfill()
                          }
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
        XCTAssertTrue(receivedOnMain)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestPublishedOnSeparateQueueIsReceivedOnThatQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self, queue: queue)
                .sink(receiveCompletion: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                    completionReceived.fulfill()
                },
                      receiveValue: { stream in
                    dispatchPrecondition(condition: .onQueue(queue))
                    switch stream.event {
                    case let .stream(value):
                        result = value
                    case .complete:
                        responseReceived.fulfill()
                    }
                    })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataStreamRequestPublishedOnSeparateQueueCanBeReceivedOntoMainQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var receivedOnMain = false
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self, queue: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { stream in
                          receivedOnMain = Thread.isMainThread
                          switch stream.event {
                          case let .stream(value):
                              result = value
                          case .complete:
                              responseReceived.fulfill()
                          }
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result?.success)
        XCTAssertTrue(receivedOnMain)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDataStreamRequestCanBeCancelledAutomatically() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var error: AFError?

        // When
        let request = AF.streamRequest(URLRequest.makeHTTPBinRequest())
        var token: AnyCancellable? = request
            .publishDecodable(type: HTTPBinResponse.self)
            .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                  receiveValue: { error = $0.completion?.error; responseReceived.fulfill() })
        token = nil

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled)
        XCTAssertNil(token)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDataStreamRequestCanBeCancelledManually() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var error: AFError?

        // When
        let request = AF.streamRequest(URLRequest.makeHTTPBinRequest())
        store {
            request
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { error = $0.completion?.error; responseReceived.fulfill() })
        }
        request.cancel()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatMultipleDataStreamPublishersCanBeCombined() {
        // Given
        let responseReceived = expectation(description: "combined response should be received")
        let completionReceived = expectation(description: "combined stream should complete")
        var firstCompletion: DataStreamRequest.Completion?
        var secondCompletion: DataStreamRequest.Completion?

        // When
        let first = AF.streamRequest(URLRequest.makeHTTPBinRequest())
            .publishDecodable(type: HTTPBinResponse.self)
        let second = AF.streamRequest(URLRequest.makeHTTPBinRequest())
            .publishDecodable(type: HTTPBinResponse.self)

        store {
            Publishers.CombineLatest(first.compactMap { $0.completion }, second.compactMap { $0.completion })
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { first, second in
                          firstCompletion = first
                          secondCompletion = second
                          responseReceived.fulfill()
                      })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(firstCompletion)
        XCTAssertNotNil(secondCompletion)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatMultipleDataStreamRequestPublishersCanBeChained() {
        // Given
        let responseReceived = expectation(description: "combined response should be received")
        let completionReceived = expectation(description: "combined stream should complete")
        var firstCompletion: DataStreamRequest.Completion?
        var secondCompletion: DataStreamRequest.Completion?

        // When
        store {
            AF.streamRequest(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .compactMap { $0.completion }
                .flatMap { completion -> DataStreamPublisher<HTTPBinResponse> in
                    firstCompletion = completion
                    let request = URLRequest.makeHTTPBinRequest(headers: ["X-Custom": completion.response?.url?.absoluteString ?? "None"])
                    return AF.streamRequest(request)
                        .publishDecodable(type: HTTPBinResponse.self)
                }
                .compactMap { $0.completion }
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { secondCompletion = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(firstCompletion)
        XCTAssertNotNil(secondCompletion)
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
final class DownloadRequestCombineTests: CombineTestCase {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "publisher should complete")
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatNonAutomaticDownloadRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "publisher should complete")
        let session = Session(startRequestsImmediately: false)
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            session.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanPublishData() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "publisher should complete")
        var response: DownloadResponse<Data, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishData()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanPublishString() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "publisher should complete")
        var response: DownloadResponse<String, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishString()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanPublishUnserialized() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "publisher should complete")
        var response: DownloadResponse<URL?, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishUnserialized()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanPublishWithMultipleHandlers() {
        // Given
        let handlerResponseReceived = expectation(description: "handler response should be received")
        let publishedResponseReceived = expectation(description: "published response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var handlerResponse: DownloadResponse<HTTPBinResponse, AFError>?
        var publishedResponse: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .responseDecodable(of: HTTPBinResponse.self) { handlerResponse = $0; handlerResponseReceived.fulfill() }
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { publishedResponse = $0; publishedResponseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(handlerResponse?.result.isSuccess == true)
        XCTAssertTrue(publishedResponse?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanPublishResult() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "publisher should complete")
        var result: Result<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { result = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(result?.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanPublishValueWithFailure() {
        // Given
        let completionReceived = expectation(description: "stream should complete")
        var error: AFError?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest(path: "delay/1", timeout: 0.1))
                .publishDecodable(type: HTTPBinResponse.self)
                .value()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(err):
                        error = err
                    case .finished:
                        error = nil
                    }
                    completionReceived.fulfill()
                }, receiveValue: { _ in })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(error)
        XCTAssertEqual((error?.underlyingError as? URLError)?.code, .timedOut)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDownloadRequestIsNotResumedUnlessSubscribed() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        let request = AF.download(URLRequest.makeHTTPBinRequest())
        let publisher = request.publishDecodable(type: HTTPBinResponse.self)

        let stateAfterPublisher = request.state

        store {
            publisher.sink(receiveCompletion: { _ in completionReceived.fulfill() },
                           receiveValue: { response = $0; responseReceived.fulfill() })
        }

        let stateAfterSubscription = request.state

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertEqual(stateAfterPublisher, .initialized)
        XCTAssertEqual(stateAfterSubscription, .resumed)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestCanSubscribedFromNonMainQueueButPublishedOnMainQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var receivedOnMain = false
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .subscribe(on: queue)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: {
                          receivedOnMain = Thread.isMainThread
                          response = $0
                          responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertTrue(receivedOnMain)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestPublishedOnSeparateQueueIsReceivedOnThatQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self, queue: queue)
                .sink(receiveCompletion: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                    completionReceived.fulfill()
                },
                      receiveValue: {
                    dispatchPrecondition(condition: .onQueue(queue))
                    response = $0
                    responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDownloadRequestPublishedOnSeparateQueueCanBeReceivedOntoMainQueue() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        var receivedOnMain = false
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self, queue: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: {
                          receivedOnMain = Thread.isMainThread
                          response = $0
                          responseReceived.fulfill()
                })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
        XCTAssertTrue(receivedOnMain)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDownloadRequestCanBeCancelledAutomatically() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        let request = AF.download(URLRequest.makeHTTPBinRequest())
        var token: AnyCancellable? = request
            .publishDecodable(type: HTTPBinResponse.self)
            .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                  receiveValue: { response = $0; responseReceived.fulfill() })
        token = nil

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isFailure == true)
        XCTAssertTrue(response?.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled)
        XCTAssertNil(token)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatPublishedDownloadRequestCanBeCancelledManually() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        let request = AF.download(URLRequest.makeHTTPBinRequest())
        store {
            request
                .publishDecodable(type: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }
        request.cancel()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isFailure == true)
        XCTAssertTrue(response?.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatMultipleDownloadRequestPublishersCanBeCombined() {
        // Given
        let responseReceived = expectation(description: "combined response should be received")
        let completionReceived = expectation(description: "combined stream should complete")
        var firstResponse: DownloadResponse<HTTPBinResponse, AFError>?
        var secondResponse: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        let first = AF.download(URLRequest.makeHTTPBinRequest())
            .publishDecodable(type: HTTPBinResponse.self)
        let second = AF.download(URLRequest.makeHTTPBinRequest())
            .publishDecodable(type: HTTPBinResponse.self)

        store {
            Publishers.CombineLatest(first, second)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() }) { first, second in
                    firstResponse = first
                    secondResponse = second
                    responseReceived.fulfill()
                }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(firstResponse?.result.isSuccess == true)
        XCTAssertTrue(secondResponse?.result.isSuccess == true)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatMultipleDownloadRequestPublishersCanBeChained() {
        // Given
        let responseReceived = expectation(description: "combined response should be received")
        let completionReceived = expectation(description: "combined stream should complete")
        var firstResponse: DownloadResponse<HTTPBinResponse, AFError>?
        var secondResponse: DownloadResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.download(URLRequest.makeHTTPBinRequest())
                .publishDecodable(type: HTTPBinResponse.self)
                .flatMap { response -> DownloadResponsePublisher<HTTPBinResponse> in
                    firstResponse = response
                    let request = URLRequest.makeHTTPBinRequest(headers: ["X-Custom": response.value?.url ?? "None"])
                    return AF.download(request)
                        .publishDecodable(type: HTTPBinResponse.self)
                }
                .sink(receiveCompletion: { _ in completionReceived.fulfill() }) { response in
                    secondResponse = response
                    responseReceived.fulfill()
                }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(firstResponse?.result.isSuccess == true)
        XCTAssertTrue(secondResponse?.result.isSuccess == true)
        XCTAssertEqual(secondResponse?.value?.headers["X-Custom"], "https://httpbin.org/get")
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
class CombineTestCase: BaseTestCase {
    var storage: Set<AnyCancellable> = []

    override func tearDown() {
        storage = []

        super.tearDown()
    }

    func store(_ toStore: () -> AnyCancellable) {
        storage.insert(toStore())
    }
}

#endif
