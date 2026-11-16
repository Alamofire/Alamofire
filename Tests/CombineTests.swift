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
import Foundation
import Testing

@Suite(.storesInstances)
struct DataRequestCombineTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanBePublished() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func nonAutomaticDataRequestCanBePublished() async {
        // Given
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let session = Session.independent(startRequestsImmediately: false)
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanPublishData() async {
        // Given
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let session = Session.independent(startRequestsImmediately: false)
        let response = Capture<DataResponse<Data, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishData()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanPublishString() async {
        // Given
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let session = Session.independent(startRequestsImmediately: false)
        let response = Capture<DataResponse<String, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishString()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanBePublishedUnserialized() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishUnserialized()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanBePublishedWithMultipleHandlers() async {
        // Given
        let session = stored(Session.independent())
        let handlerResponseReceived = Completion("handler response should be received")
        let publishedResponseReceived = Completion("published response should be received")
        let completionReceived = Completion("stream should complete")
        let handlerResponse = Capture<DataResponse<TestResponse, AFError>?>()
        let publishedResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .responseDecodable(of: TestResponse.self) { handlerResponse.value = $0; handlerResponseReceived.complete() }
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { publishedResponse.value = $0; publishedResponseReceived.complete() })
        }

        await wait(for: [handlerResponseReceived, publishedResponseReceived, completionReceived])

        // Then
        #expect(handlerResponse.result?.isSuccess == true)
        #expect(publishedResponse.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanPublishResult() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { result.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanPublishValue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let value = Capture<TestResponse?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self)
                .value()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { value.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(value.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanPublishValueWithFailure() async {
        // Given
        let session = stored(Session.independent())
        let completionReceived = Completion("stream should complete")
        let error = Capture<AFError?>()

        // When
        store {
            session.request(Endpoint(path: .delay(interval: 1), timeout: 0.01))
                .publishDecodable(type: TestResponse.self)
                .value()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(err):
                        error.value = err
                    case .finished:
                        error.value = nil
                    }
                    completionReceived.complete()
                }, receiveValue: { _ in })
        }

        await completionReceived.wait()

        // Then
        #expect(error.value != nil)
        #expect((error.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDataRequestIsNotResumedUnlessSubscribed() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.default)
        let publisher = request.publishDecodable(type: TestResponse.self)

        let stateAfterPublisher = request.state

        store {
            publisher.sink(receiveCompletion: { _ in completionReceived.complete() },
                           receiveValue: { response.value = $0; responseReceived.complete() })
        }

        let stateAfterSubscription = request.state

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(stateAfterPublisher == .initialized)
        #expect(stateAfterSubscription != .initialized)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestCanSubscribedFromNonMainQueueButPublishedOnMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let receivedOnMain = Capture(false)
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self)
                .subscribe(on: queue)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: {
                          receivedOnMain.value = Thread.isMainThread
                          response.value = $0
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(receivedOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestPublishedOnSeparateQueueIsReceivedOnThatQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self, queue: queue)
                .sink(receiveCompletion: { _ in
                          dispatchPrecondition(condition: .onQueue(queue))
                          completionReceived.complete()
                      },
                      receiveValue: {
                          dispatchPrecondition(condition: .onQueue(queue))
                          response.value = $0
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestPublishedOnSeparateQueueCanBeReceivedOntoMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let receivedOnMain = Capture(false)
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self, queue: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: {
                          receivedOnMain.value = Thread.isMainThread
                          response.value = $0
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(receivedOnMain.value)
    }

    @Test(.enabled(if: combineCancellationEmitsValue,
                   "Skip on 2020 OS versions, as Combine cancellation no longer emits a value."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDataRequestCanBeCancelledAutomatically() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.default)
        var token: AnyCancellable? = request
            .publishDecodable(type: TestResponse.self)
            .sink(receiveCompletion: { _ in completionReceived.complete() },
                  receiveValue: { response.value = $0; responseReceived.complete() })
        token = nil

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(response.error?.localizedDescription ?? "None")")
        #expect(request.isCancelled)
        #expect(token == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDataRequestCanBeCancelledManually() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let request = session.request(.delay(1))
        store {
            request
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }
        request.cancel()

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(response.error?.localizedDescription ?? "None")")
        #expect(request.isCancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleDataRequestPublishersCanBeCombined() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("combined response should be received")
        let completionReceived = Completion("combined stream should complete")
        let firstResponse = Capture<DataResponse<TestResponse, AFError>?>()
        let secondResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let first = session.request(.default)
            .publishDecodable(type: TestResponse.self)
        let second = session.request(.default)
            .publishDecodable(type: TestResponse.self)

        store {
            Publishers.CombineLatest(first, second)
                .sink(receiveCompletion: { _ in completionReceived.complete() }) { first, second in
                    firstResponse.value = first
                    secondResponse.value = second
                    responseReceived.complete()
                }
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(firstResponse.result?.isSuccess == true)
        #expect(secondResponse.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleDataRequestPublishersCanBeChained() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("combined response should be received")
        let completionReceived = Completion("combined stream should complete")
        let customValue = "CustomValue"
        let firstResponse = Capture<DataResponse<TestResponse, AFError>?>()
        let secondResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        store {
            session.request(.default)
                .publishDecodable(type: TestResponse.self)
                .flatMap { response -> DataResponsePublisher<TestResponse> in
                    firstResponse.value = response
                    let request = Endpoint(headers: ["X-Custom": customValue])
                    return session.request(request)
                        .publishDecodable(type: TestResponse.self)
                }
                .sink(receiveCompletion: { _ in completionReceived.complete() }) { response in
                    secondResponse.value = response
                    responseReceived.complete()
                }
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(firstResponse.result?.isSuccess == true)
        #expect(secondResponse.result?.isSuccess == true)
        #expect(secondResponse.value?.value?.headers["X-Custom"] == customValue)
    }
}

// MARK: - DataStreamRequest

@Suite(.storesInstances)
struct DataStreamRequestCombineTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanBePublished() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func nonAutomaticDataStreamRequestCanBePublished() async {
        // Given
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let session = Session.independent(startRequestsImmediately: false)
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanPublishData() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<Data, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishData()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanPublishString() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<String, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishString()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanBePublishedWithMultipleHandlers() async {
        // Given
        // Require manual start so both serializers can be added before the stream starts. Subscribing starts it.
        let session = stored(Session.independent(startRequestsImmediately: false))
        let handlerResponseReceived = Completion("handler response should be received")
        let publishedResponseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let handlerResult = Capture<Result<TestResponse, AFError>?>()
        let publishedResult = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .responseStreamDecodable(of: TestResponse.self) { stream in
                    switch stream.event {
                    case let .stream(value):
                        handlerResult.value = value
                    case .complete:
                        handlerResponseReceived.complete()
                    }
                }
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          switch stream.event {
                          case let .stream(value):
                              publishedResult.value = value
                          case .complete:
                              publishedResponseReceived.complete()
                          }
                      })
        }

        await wait(for: [handlerResponseReceived, publishedResponseReceived, completionReceived])

        // Then
        #expect(handlerResult.success != nil)
        #expect(publishedResult.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanPublishResult() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { received in
                          result.value = received
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanPublishResultWithResponseFailure() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(Endpoint.delay(1).modifying(\.timeout, to: 0.1))
                .publishDecodable(type: TestResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { received in
                          result.value = received
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success == nil)
        #expect((result.failure?.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanPublishValue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<TestResponse?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self)
                .value()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { received in
                          response.value = received
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanPublishValueWithFailure() async {
        // Given
        let session = stored(Session.independent())
        let completionReceived = Completion("stream should complete")
        let error = Capture<AFError?>()

        // When
        store {
            session.streamRequest(Endpoint.delay(1).modifying(\.timeout, to: 0.1))
                .publishDecodable(type: TestResponse.self)
                .value()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(err):
                        error.value = err
                    case .finished:
                        error.value = nil
                    }
                    completionReceived.complete()
                }, receiveValue: { _ in })
        }

        await completionReceived.wait()

        // Then
        #expect(error.value != nil)
        #expect((error.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDataStreamRequestIsNotResumedUnlessSubscribed() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        let request = session.streamRequest(.default)
        let publisher = request.publishDecodable(type: TestResponse.self)

        let stateAfterPublisher = request.state

        store {
            publisher.sink(receiveCompletion: { _ in completionReceived.complete() },
                           receiveValue: { stream in
                               switch stream.event {
                               case let .stream(value):
                                   result.value = value
                               case .complete:
                                   responseReceived.complete()
                               }
                           })
        }

        let stateAfterSubscription = request.state

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.isSuccess == true)
        #expect(stateAfterPublisher == .initialized)
        #expect(stateAfterSubscription != .initialized)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestCanSubscribedFromNonMainQueueButPublishedOnMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let receivedOnMain = Capture(false)
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self)
                .subscribe(on: queue)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          receivedOnMain.value = Thread.isMainThread
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
        #expect(receivedOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestPublishedOnSeparateQueueIsReceivedOnThatQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self, queue: queue)
                .sink(receiveCompletion: { _ in
                          dispatchPrecondition(condition: .onQueue(queue))
                          completionReceived.complete()
                      },
                      receiveValue: { stream in
                          dispatchPrecondition(condition: .onQueue(queue))
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestPublishedOnSeparateQueueCanBeReceivedOntoMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let receivedOnMain = Capture(false)
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self, queue: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { stream in
                          receivedOnMain.value = Thread.isMainThread
                          switch stream.event {
                          case let .stream(value):
                              result.value = value
                          case .complete:
                              responseReceived.complete()
                          }
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.success != nil)
        #expect(receivedOnMain.value)
    }

    @Test(.enabled(if: combineCancellationEmitsValue,
                   "Skip on 2020 OS versions, as Combine cancellation no longer emits a value."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDataStreamRequestCanBeCancelledAutomatically() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let error = Capture<AFError?>()

        // When
        let request = session.streamRequest(.default)
        var token: AnyCancellable? = request
            .publishDecodable(type: TestResponse.self)
            .sink(receiveCompletion: { _ in completionReceived.complete() },
                  receiveValue: { error.value = $0.completion?.error; responseReceived.complete() })
        token = nil

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(error.value != nil)
        #expect(error.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(error.localizedDescription ?? "None")")
        #expect(request.isCancelled)
        #expect(token == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDataStreamRequestCanBeCancelledManually() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let error = Capture<AFError?>()

        // When
        let request = session.streamRequest(.delay(1))
        store {
            request
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { error.value = $0.completion?.error; responseReceived.complete() })
        }
        request.cancel()

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(error.value != nil)
        #expect(error.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(error.localizedDescription ?? "None")")
        #expect(request.isCancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleDataStreamPublishersCanBeCombined() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("combined response should be received")
        let completionReceived = Completion("combined stream should complete")
        let firstCompletion = Capture<DataStreamRequest.Completion?>()
        let secondCompletion = Capture<DataStreamRequest.Completion?>()

        // When
        let first = session.streamRequest(.default)
            .publishDecodable(type: TestResponse.self)
        let second = session.streamRequest(.default)
            .publishDecodable(type: TestResponse.self)

        store {
            Publishers.CombineLatest(first.compactMap(\.completion), second.compactMap(\.completion))
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { first, second in
                          firstCompletion.value = first
                          secondCompletion.value = second
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(firstCompletion.value != nil)
        #expect(secondCompletion.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleDataStreamRequestPublishersCanBeChained() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("combined response should be received")
        let completionReceived = Completion("combined stream should complete")
        let firstCompletion = Capture<DataStreamRequest.Completion?>()
        let secondCompletion = Capture<DataStreamRequest.Completion?>()

        // When
        store {
            session.streamRequest(.default)
                .publishDecodable(type: TestResponse.self)
                .compactMap(\.completion)
                .flatMap { completion -> DataStreamPublisher<TestResponse> in
                    firstCompletion.value = completion
                    return session.streamRequest(.default)
                        .publishDecodable(type: TestResponse.self)
                }
                .compactMap(\.completion)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { secondCompletion.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(firstCompletion.value != nil)
        #expect(secondCompletion.value != nil)
    }
}

@Suite(.storesInstances)
struct DownloadRequestCombineTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanBePublished() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func nonAutomaticDownloadRequestCanBePublished() async {
        // Given
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let session = Session.independent(startRequestsImmediately: false)
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishData() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let response = Capture<DownloadResponse<Data, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishData()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishString() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let response = Capture<DownloadResponse<String, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishString()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishUnserialized() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishUnserialized()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishURL() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let response = Capture<DownloadResponse<URL, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishURL()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishWithMultipleHandlers() async {
        // Given
        let session = stored(Session.independent())
        let handlerResponseReceived = Completion("handler response should be received")
        let publishedResponseReceived = Completion("published response should be received")
        let completionReceived = Completion("stream should complete")
        let handlerResponse = Capture<DownloadResponse<TestResponse, AFError>?>()
        let publishedResponse = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .responseDecodable(of: TestResponse.self) { handlerResponse.value = $0; handlerResponseReceived.complete() }
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { publishedResponse.value = $0; publishedResponseReceived.complete() })
        }

        await wait(for: [handlerResponseReceived, publishedResponseReceived, completionReceived])

        // Then
        #expect(handlerResponse.result?.isSuccess == true)
        #expect(publishedResponse.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishResult() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("publisher should complete")
        let result = Capture<Result<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self)
                .result()
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { result.value = $0; responseReceived.complete() })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(result.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanPublishValueWithFailure() async {
        // Given
        let session = stored(Session.independent())
        let completionReceived = Completion("stream should complete")
        let error = Capture<AFError?>()

        // When
        store {
            session.download(Endpoint.delay(1).modifying(\.timeout, to: 0.1))
                .publishDecodable(type: TestResponse.self)
                .value()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(err):
                        error.value = err
                    case .finished:
                        error.value = nil
                    }
                    completionReceived.complete()
                }, receiveValue: { _ in })
        }

        await completionReceived.wait()

        // Then
        #expect(error.value != nil)
        #expect((error.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDownloadRequestIsNotResumedUnlessSubscribed() async {
        // Given
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        let session = stored(Session.independent())
        let request = session.download(.default)
        let publisher = request.publishDecodable(type: TestResponse.self)

        let stateAfterPublisher = request.state

        store {
            publisher.sink(receiveCompletion: { _ in completionReceived.complete() },
                           receiveValue: { response.value = $0; responseReceived.complete() })
        }

        let stateAfterSubscription = request.state

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(stateAfterPublisher == .initialized)
        #expect(stateAfterSubscription != .initialized)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestCanSubscribedFromNonMainQueueButPublishedOnMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let receivedOnMain = Capture(false)
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self)
                .subscribe(on: queue)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: {
                          receivedOnMain.value = Thread.isMainThread
                          response.value = $0
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(receivedOnMain.value)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestPublishedOnSeparateQueueIsReceivedOnThatQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self, queue: queue)
                .sink(receiveCompletion: { _ in
                          dispatchPrecondition(condition: .onQueue(queue))
                          completionReceived.complete()
                      },
                      receiveValue: {
                          dispatchPrecondition(condition: .onQueue(queue))
                          response.value = $0
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestPublishedOnSeparateQueueCanBeReceivedOntoMainQueue() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let queue = DispatchQueue(label: "org.alamofire.tests.combineEventQueue")
        let receivedOnMain = Capture(false)
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self, queue: queue)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: {
                          receivedOnMain.value = Thread.isMainThread
                          response.value = $0
                          responseReceived.complete()
                      })
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(receivedOnMain.value)
    }

    @Test(.enabled(if: combineCancellationEmitsValue,
                   "Skip on 2020 OS versions, as Combine cancellation no longer emits a value."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDownloadRequestCanBeCancelledAutomatically() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        let request = session.download(.default)
        var token: AnyCancellable? = request
            .publishDecodable(type: TestResponse.self)
            .sink(receiveCompletion: { _ in completionReceived.complete() },
                  receiveValue: { response.value = $0; responseReceived.complete() })
        token = nil

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(response.error?.localizedDescription ?? "None")")
        #expect(request.isCancelled)
        #expect(token == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func publishedDownloadRequestCanBeCancelledManually() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("response should be received")
        let completionReceived = Completion("stream should complete")
        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        let request = session.download(.delay(1))
        store {
            request
                .publishDecodable(type: TestResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.complete() },
                      receiveValue: { response.value = $0; responseReceived.complete() })
        }
        request.cancel()

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isExplicitlyCancelledError == true, "error is not explicitly cancelled but \(response.error?.localizedDescription ?? "None")")
        #expect(request.isCancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleDownloadRequestPublishersCanBeCombined() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("combined response should be received")
        let completionReceived = Completion("combined stream should complete")
        let firstResponse = Capture<DownloadResponse<TestResponse, AFError>?>()
        let secondResponse = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        let first = session.download(.default)
            .publishDecodable(type: TestResponse.self)
        let second = session.download(.default)
            .publishDecodable(type: TestResponse.self)

        store {
            Publishers.CombineLatest(first, second)
                .sink(receiveCompletion: { _ in completionReceived.complete() }) { first, second in
                    firstResponse.value = first
                    secondResponse.value = second
                    responseReceived.complete()
                }
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(firstResponse.result?.isSuccess == true)
        #expect(secondResponse.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleDownloadRequestPublishersCanBeChained() async {
        // Given
        let session = stored(Session.independent())
        let responseReceived = Completion("combined response should be received")
        let completionReceived = Completion("combined stream should complete")
        let customValue = "CustomValue"
        let firstResponse = Capture<DownloadResponse<TestResponse, AFError>?>()
        let secondResponse = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        store {
            session.download(.default)
                .publishDecodable(type: TestResponse.self)
                .flatMap { response -> DownloadResponsePublisher<TestResponse> in
                    firstResponse.value = response
                    let request = Endpoint(headers: ["X-Custom": customValue])
                    return session.download(request)
                        .publishDecodable(type: TestResponse.self)
                }
                .sink(receiveCompletion: { _ in completionReceived.complete() }) { response in
                    secondResponse.value = response
                    responseReceived.complete()
                }
        }

        await wait(for: [responseReceived, completionReceived])

        // Then
        #expect(firstResponse.result?.isSuccess == true)
        #expect(secondResponse.result?.isSuccess == true)
        #expect(secondResponse.value?.value?.headers["X-Custom"] == customValue)
    }
}

/// Keeps the cancellable `toStore` returns alive until the end of the current test, the Swift Testing counterpart of
/// `CombineTestCase.store(_:)`. Requires the `.storesInstances` trait on the test or its suite.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
func store(_ toStore: () -> AnyCancellable) {
    stored(toStore())
}

/// Whether cancelling a Combine subscription still emits a value, which stopped with the 2020 OS versions.
let combineCancellationEmitsValue: Bool = if #available(macOS 11, iOS 14, watchOS 7, tvOS 14, *) {
        false
    } else {
        true
    }

#endif
