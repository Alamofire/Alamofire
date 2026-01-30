//
//  ConcurrencyTests.swift
//
//  Copyright (c) 2021 Alamofire Software Foundation (http://alamofire.org/)
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

#if canImport(_Concurrency)

import Alamofire
import XCTest

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class DataRequestConcurrencyTests: BaseTestCase {
    func testThatDataTaskSerializesResponseUsingSerializer() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.request(.get)
            .serializingResponse(using: .data)
            .value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDataTaskCanBeCancelledConcurrently() async {
        // Tests fix for https://github.com/Alamofire/Alamofire/issues/3978
        // Given
        let session = Session()

        // When: a single request has multiple DataTasks attached.
        for _ in 0..<100 {
            let request = session.request(.get)
            let first = Task {
                await request
                    .serializingDecodable(TestResponse.self)
                    .response
            }
            let second = Task {
                await request
                    .serializingDecodable(TestResponse.self)
                    .response
            }

            async let firstResponse = first.value
            async let secondResponse = second.value
            // When: both tasks are cancelled concurrently.
            async let firstCancel: Void = Task { @Sendable in first.cancel() }.value
            async let secondCancel: Void = Task { @Sendable in second.cancel() }.value

            // Then: all awaits parts should complete without continuation misuse.
            _ = await (firstResponse, secondResponse, firstCancel, secondCancel)
        }
    }

    func testThat500ResponseCanBeRetried() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.request(.endpoints(.status(500), .method(.get)), interceptor: .retryPolicy)
            .serializingResponse(using: .data)
            .value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDataTaskSerializesDecodable() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.request(.get).serializingDecodable(TestResponse.self).value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDataTaskSerializesString() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.request(.get).serializingString().value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDataTaskSerializesData() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.request(.get).serializingData().value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDataTaskProducesResult() async {
        // Given
        let session = stored(Session())

        // When
        let result = await session.request(.get).serializingDecodable(TestResponse.self).result

        // Then
        XCTAssertNotNil(result.success)
    }

    func testThatDataTaskProducesValue() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.request(.get).serializingDecodable(TestResponse.self).value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDataTaskProperlySupportsConcurrentRequests() async {
        // Given
        let session = stored(Session())

        // When
        async let first = session.request(.get).serializingDecodable(TestResponse.self).response
        async let second = session.request(.get).serializingDecodable(TestResponse.self).response
        async let third = session.request(.get).serializingDecodable(TestResponse.self).response

        // Then
        let responses = await [first, second, third]
        XCTAssertEqual(responses.count, 3)
        XCTAssertTrue(responses.allSatisfy(\.result.isSuccess))
    }

    func testThatDataTaskCancellationCancelsRequest() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)
        let task = request.serializingDecodable(TestResponse.self)

        // When
        task.cancel()
        let response = await task.response

        // Then
        XCTAssertTrue(response.error?.isExplicitlyCancelledError == true)
        XCTAssertTrue(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    func testThatDataTaskIsAutomaticallyCancelledInTask() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self).result
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(result.failure?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertTrue(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    func testThatDataTaskIsNotAutomaticallyCancelledInTaskWhenDisabled() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self, automaticallyCancelling: false).result
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertFalse(request.isCancelled, "Underlying DataRequest should not be cancelled.")
        XCTAssertTrue(result.isSuccess, "DataRequest should succeed.")
    }

    func testThatDataTaskIsAutomaticallyCancelledInTaskGroup() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)

        // When
        let task = Task {
            await withTaskGroup(of: Result<TestResponse, AFError>.self) { group -> Result<TestResponse, AFError> in
                group.addTask {
                    await request.serializingDecodable(TestResponse.self).result
                }

                return await group.first(where: { _ in true })!
            }
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(result.failure?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertTrue(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    func testThatDataTaskIsNotAutomaticallyCancelledInTaskGroupWhenDisabled() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)

        // When
        let task = Task {
            await withTaskGroup(of: Result<TestResponse, AFError>.self) { group -> Result<TestResponse, AFError> in
                group.addTask {
                    await request.serializingDecodable(TestResponse.self, automaticallyCancelling: false).result
                }

                return await group.first(where: { _ in true })!
            }
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertFalse(request.isCancelled, "Underlying DataRequest should not be cancelled.")
        XCTAssertTrue(result.isSuccess, "DataRequest should succeed.")
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class DownloadConcurrencyTests: BaseTestCase {
    func testThatDownloadTaskSerializesResponseFromSerializer() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.download(.get)
            .serializingDownload(using: .data)
            .value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDownloadTaskSerializesDecodable() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.download(.get).serializingDecodable(TestResponse.self).value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDownloadTaskSerializesString() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.download(.get).serializingString().value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDownloadTaskSerializesData() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.download(.get).serializingData().value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDownloadTaskSerializesURL() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.download(.get).serializingDownloadedFileURL().value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDownloadTaskProducesResult() async {
        // Given
        let session = stored(Session())

        // When
        let result = await session.download(.get).serializingDecodable(TestResponse.self).result

        // Then
        XCTAssertNotNil(result.success)
    }

    func testThatDownloadTaskProducesValue() async throws {
        // Given
        let session = stored(Session())

        // When
        let value = try await session.download(.get).serializingDecodable(TestResponse.self).value

        // Then
        XCTAssertNotNil(value)
    }

    func testThatDownloadTaskProperlySupportsConcurrentRequests() async {
        // Given
        let session = stored(Session())

        // When
        async let first = session.download(.get).serializingDecodable(TestResponse.self).response
        async let second = session.download(.get).serializingDecodable(TestResponse.self).response
        async let third = session.download(.get).serializingDecodable(TestResponse.self).response

        // Then
        let responses = await [first, second, third]
        XCTAssertEqual(responses.count, 3)
        XCTAssertTrue(responses.allSatisfy(\.result.isSuccess))
    }

    func testThatDownloadTaskCancelsRequest() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)
        let task = request.serializingDecodable(TestResponse.self)

        // When
        task.cancel()
        let response = await task.response

        // Then
        XCTAssertTrue(response.error?.isExplicitlyCancelledError == true)
    }

    func testThatDownloadTaskIsAutomaticallyCancelledInTask() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self).result
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(result.failure?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertTrue(request.isCancelled, "Underlying DownloadRequest should be cancelled.")
    }

    func testThatDownloadTaskIsNotAutomaticallyCancelledInTaskWhenDisabled() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self, automaticallyCancelling: false).result
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertFalse(request.isCancelled, "Underlying DownloadRequest should not be cancelled.")
        XCTAssertTrue(result.isSuccess, "DownloadRequest should succeed.")
    }

    func testThatDownloadTaskIsAutomaticallyCancelledInTaskGroup() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)

        // When
        let task = Task {
            await withTaskGroup(of: Result<TestResponse, AFError>.self) { group -> Result<TestResponse, AFError> in
                group.addTask {
                    await request.serializingDecodable(TestResponse.self).result
                }

                return await group.first(where: { _ in true })!
            }
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(result.failure?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertTrue(request.isCancelled, "Underlying DownloadRequest should be cancelled.")
    }

    func testThatDownloadTaskIsNotAutomaticallyCancelledInTaskGroupWhenDisabled() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)

        // When
        let task = Task {
            await withTaskGroup(of: Result<TestResponse, AFError>.self) { group -> Result<TestResponse, AFError> in
                group.addTask {
                    await request.serializingDecodable(TestResponse.self, automaticallyCancelling: false).result
                }

                return await group.first(where: { _ in true })!
            }
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertFalse(request.isCancelled, "Underlying DownloadRequest should not be cancelled.")
        XCTAssertTrue(result.isSuccess, "DownloadRequest should succeed.")
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class DataStreamConcurrencyTests: BaseTestCase {
    func testThatDataStreamTaskCanStreamData() async {
        // Given
        let session = stored(Session())

        // When
        let task = session.streamRequest(.payloads(2)).streamTask()
        var datas: [Data] = []

        for await data in task.streamingData().compactMap(\.value) {
            datas.append(data)
        }

        // Then
        XCTAssertEqual(datas.count, 2)
    }

    #if canImport(Darwin)
    func testThatDataStreamHasAsyncOnHTTPResponse() async {
        // Given
        let session = stored(Session())
        let functionCalled = expectation(description: "doNothing called")
        @Sendable @MainActor func fulfill() async {
            functionCalled.fulfill()
        }

        // When
        let task = session.streamRequest(.payloads(2))
            .onHTTPResponse { _ in
                await fulfill()
            }
            .streamTask()
        var datas: [Data] = []

        for await data in task.streamingData().compactMap(\.value) {
            datas.append(data)
        }

        await fulfillment(of: [functionCalled], timeout: timeout)

        // Then
        XCTAssertEqual(datas.count, 2)
    }

    func testThatDataOnHTTPResponseCanAllow() async {
        // Given
        let session = stored(Session())
        let functionCalled = expectation(description: "doNothing called")
        @Sendable @MainActor func fulfill() async {
            functionCalled.fulfill()
        }

        // When
        let task = session.streamRequest(.payloads(2))
            .onHTTPResponse { _ in
                await fulfill()
                return .allow
            }
            .streamTask()
        var datas: [Data] = []

        for await data in task.streamingData().compactMap(\.value) {
            datas.append(data)
        }

        await fulfillment(of: [functionCalled], timeout: timeout)

        // Then
        XCTAssertEqual(datas.count, 2)
    }

    func testThatDataOnHTTPResponseCanCancel() async {
        // Given
        let session = stored(Session())
        var receivedCompletion: DataStreamRequest.Completion?
        let functionCalled = expectation(description: "doNothing called")
        @Sendable @MainActor func fulfill() async {
            functionCalled.fulfill()
        }

        // When
        let request = session.streamRequest(.payloads(2))
            .onHTTPResponse { _ in
                await fulfill()
                return .cancel
            }
        let task = request.streamTask()

        for await stream in task.streamingResponses(serializedUsing: .passthrough) {
            switch stream.event {
            case .stream:
                XCTFail("cancelled stream should receive no data")
            case let .complete(completion):
                receivedCompletion = completion
            }
        }

        await fulfillment(of: [functionCalled], timeout: timeout)

        // Then
        XCTAssertEqual(receivedCompletion?.response?.statusCode, 200)
        XCTAssertTrue(request.isCancelled, "onHTTPResponse cancelled request isCancelled should be true")
        XCTAssertTrue(request.error?.isExplicitlyCancelledError == true, "onHTTPResponse cancelled request error should be explicitly cancelled")
    }
    #endif

    func testThatDataStreamTaskCanStreamStrings() async {
        // Given
        let session = stored(Session())

        // When
        let task = session.streamRequest(.payloads(2)).streamTask()
        var strings: [String] = []

        for await string in task.streamingStrings().compactMap(\.value) {
            strings.append(string)
        }

        // Then
        XCTAssertEqual(strings.count, 2)
    }

    func testThatDataStreamTaskCanStreamDecodable() async {
        // Given
        let session = stored(Session())

        // When
        let task = session.streamRequest(.payloads(2)).streamTask()
        let stream = task.streamingResponses(serializedUsing: DecodableStreamSerializer<TestResponse>())
        var responses: [TestResponse] = []

        for await response in stream.compactMap(\.value) {
            responses.append(response)
        }

        // Then
        XCTAssertEqual(responses.count, 2)
    }

    func testThatDataStreamTaskCanBeDirectlyCancelled() async {
        // Given
        let session = stored(Session())

        // When
        let expectedPayloads = 10
        let request = session.streamRequest(.payloads(expectedPayloads))
        let task = request.streamTask()
        var datas: [Data] = []

        for await data in task.streamingData().compactMap(\.value) {
            datas.append(data)
            if datas.count == 1 {
                task.cancel()
            }
        }

        // Then
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue(datas.count == 1)
    }

    func testThatDataStreamTaskIsCancelledByCancellingIteration() async {
        // Given
        let session = stored(Session())

        // When
        let expectedPayloads = 10
        let request = session.streamRequest(.payloads(expectedPayloads))
        let task = request.streamTask()
        var datas: [Data] = []

        for await data in task.streamingData().compactMap(\.value) {
            datas.append(data)
            if datas.count == 1 {
                break
            }
        }

        // Then
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue(datas.count == 1)
    }

    func testThatDataStreamTaskCanBeImplicitlyCancelled() async {
        // Given
        let session = stored(Session())

        // When
        let expectedPayloads = 10
        let request = session.streamRequest(.payloads(expectedPayloads))
        let task = Task<[Data], Never> {
            var datas: [Data] = []

            for await data in request.streamTask().streamingData().compactMap(\.value) {
                datas.append(data)
            }

            return datas
        }
        task.cancel()
        let datas: [Data] = await task.value

        // Then
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue(datas.isEmpty)
    }

    func testThatDataStreamTaskCanBeCancelledAfterStreamTurnsOffAutomaticCancellation() async {
        // Given
        let session = stored(Session())

        // When
        let expectedPayloads = 10
        let request = session.streamRequest(.payloads(expectedPayloads))
        let task = Task<[Data], Never> {
            var datas: [Data] = []
            let streamTask = request.streamTask()

            for await data in streamTask.streamingData(automaticallyCancelling: false).compactMap(\.value) {
                datas.append(data)
                break
            }

            for await data in streamTask.streamingData().compactMap(\.value) {
                datas.append(data)
                break
            }

            return datas
        }
        let datas: [Data] = await task.value

        // Then
        XCTAssertTrue(request.isCancelled)
        XCTAssertTrue(datas.count == 2)
    }
}

// Avoid when using swift-corelibs-foundation.
// Only Xcode 14.3+ has async fulfillment.
#if !canImport(FoundationNetworking)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class UploadConcurrencyTests: BaseTestCase {
    func testThatDelayedUploadStreamResultsInMultipleProgressValues() async throws {
        // Given
        let count = 75
        let baseString = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
        let baseData = Data(baseString.utf8)
        var request = Endpoint.upload.urlRequest
        request.headers.add(name: "Content-Length", value: "\(baseData.count * count)")
        let expectation = expectation(description: "Bytes upload progress should be reported: \(request.url!)")

        var uploadProgressValues: [Double] = []
        var downloadProgressValues: [Double] = []

        var response: DataResponse<UploadResponse, AFError>?

        var inputStream: InputStream!
        var outputStream: OutputStream!
        Stream.getBoundStreams(withBufferSize: baseData.count, inputStream: &inputStream, outputStream: &outputStream)
        CFWriteStreamSetDispatchQueue(outputStream, .main)
        outputStream.open()

        // When
        AF.upload(inputStream, with: request)
            .uploadProgress { progress in
                uploadProgressValues.append(progress.fractionCompleted)
            }
            .downloadProgress { progress in
                downloadProgressValues.append(progress.fractionCompleted)
            }
            .responseDecodable(of: UploadResponse.self) { resp in
                response = resp
                expectation.fulfill()
                inputStream.close()
            }

        func sendData() {
            baseData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                let bytesStreamed = outputStream.write(pointer.baseAddress!, maxLength: baseData.count)
                switch bytesStreamed {
                case baseData.count:
                    // Successfully sent.
                    break
                case 0:
                    XCTFail("outputStream somehow reached end")
                case -1:
                    if let streamError = outputStream.streamError {
                        XCTFail("outputStream.write failed with error: \(streamError)")
                    } else {
                        XCTFail("outputStream.write failed with unknown error")
                    }
                default:
                    XCTFail("outputStream failed to send \(baseData.count) bytes, sent \(bytesStreamed) instead.")
                }
            }
        }

        for _ in 0..<count {
            sendData()

            try await Task.sleep(nanoseconds: 3 * 1_000_000) // milliseconds
        }

        outputStream.close()

        await fulfillment(of: [expectation], timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        for (progress, nextProgress) in zip(uploadProgressValues, uploadProgressValues.dropFirst()) {
            XCTAssertGreaterThanOrEqual(nextProgress, progress)
        }

        XCTAssertGreaterThan(uploadProgressValues.count, 1, "there should more than 1 uploadProgressValues")

        for (progress, nextProgress) in zip(downloadProgressValues, downloadProgressValues.dropFirst()) {
            XCTAssertGreaterThanOrEqual(nextProgress, progress)
        }

        XCTAssertEqual(downloadProgressValues.last, 1.0, "last item in downloadProgressValues should equal 1.0")
        XCTAssertEqual(response?.value?.bytes, baseData.count * count)
    }
}
#endif

#if canImport(Darwin) && !canImport(FoundationNetworking)
@_spi(WebSocket) import Alamofire

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class WebSocketConcurrencyTests: BaseTestCase {
    func testThatMessageEventsCanBeStreamed() async {
        // Given
        let session = stored(Session())
        let receivedEvent = expectation(description: "receivedEvent")
        receivedEvent.expectedFulfillmentCount = 4

        // When
        for await _ in session.webSocketRequest(.websocket()).webSocketTask().streamingMessageEvents() {
            receivedEvent.fulfill()
        }

        await fulfillment(of: [receivedEvent])

        // Then
    }

    func testThatMessagesCanBeStreamed() async {
        // Given
        let session = stored(Session())

        // When
        let messages = await session.webSocketRequest(.websocket()).webSocketTask().streamingMessages().collect()

        // Then
        XCTAssertTrue(messages.count == 1)
    }
}
#endif

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class ClosureAPIConcurrencyTests: BaseTestCase {
    func testThatDownloadProgressStreamReturnsProgress() async {
        // Given
        let session = stored(Session())

        // When
        let request = session.request(.get)
        async let httpResponses = request.httpResponses().collect()
        async let uploadProgress = request.uploadProgress().collect()
        async let downloadProgress = request.downloadProgress().collect()
        async let requests = request.urlRequests().collect()
        async let tasks = request.urlSessionTasks().collect()
        async let descriptions = request.cURLDescriptions().collect()
        async let response = request.serializingDecodable(TestResponse.self).response

        let values: (httpResponses: [HTTPURLResponse],
                     uploadProgresses: [Progress],
                     downloadProgresses: [Progress],
                     requests: [URLRequest],
                     tasks: [URLSessionTask],
                     descriptions: [String],
                     response: AFDataResponse<TestResponse>)
        values = await (httpResponses, uploadProgress, downloadProgress, requests, tasks, descriptions, response)

        // Then
        XCTAssertTrue(values.httpResponses.count == 1, "httpResponses should have one response")
        XCTAssertTrue(values.uploadProgresses.isEmpty, "uploadProgresses should be empty")
        XCTAssertNotNil(values.downloadProgresses.last, "downloadProgresses should not be empty")
        XCTAssertTrue(values.downloadProgresses.last?.isFinished == true, "last download progression should be finished")
        XCTAssertNotNil(values.requests.last, "requests should not be empty")
        XCTAssertNotNil(values.tasks.last, "tasks should not be empty")
        XCTAssertNotNil(values.descriptions.last, "descriptions should not be empty")
        XCTAssertTrue(values.response.result.isSuccess, "request should succeed")
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension AsyncSequence {
    func collect() async rethrows -> [Element] {
        var elements: [Element] = []
        for try await element in self {
            elements.append(element)
        }

        return elements
    }
}

#endif
