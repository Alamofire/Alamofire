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
import Testing
import XCTest

@Suite
struct DataRequestConcurrencyTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskSerializesResponseUsingSerializer() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.request(.get)
            .serializingResponse(using: .data)
            .value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskCanBeCancelledConcurrently() async {
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

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func status500ResponseCanBeRetried() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.request(.endpoints(.status(500), .method(.get)), interceptor: .retryPolicy)
            .serializingResponse(using: .data)
            .value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskSerializesDecodable() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.request(.get).serializingDecodable(TestResponse.self).value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskSerializesString() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.request(.get).serializingString().value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskSerializesData() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.request(.get).serializingData().value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskProducesResult() async {
        // Given
        let session = Session()

        // When
        let result = await session.request(.get).serializingDecodable(TestResponse.self).result

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskProducesValue() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.request(.get).serializingDecodable(TestResponse.self).value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskProperlySupportsConcurrentRequests() async {
        // Given
        let session = Session()

        // When
        async let first = session.request(.get).serializingDecodable(TestResponse.self).response
        async let second = session.request(.get).serializingDecodable(TestResponse.self).response
        async let third = session.request(.get).serializingDecodable(TestResponse.self).response

        // Then
        let responses = await [first, second, third]
        #expect(responses.count == 3)
        // #expect treats a key path passed to rethrowing allSatisfy as a throwing call.
        // swiftformat:disable:next preferKeyPath
        #expect(responses.allSatisfy { $0.result.isSuccess })
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskCancellationCancelsRequest() async {
        // Given
        let session = Session()
        let request = session.request(.get)
        let task = request.serializingDecodable(TestResponse.self)

        // When
        task.cancel()
        let response = await task.response

        // Then
        #expect(response.error?.isExplicitlyCancelledError == true)
        #expect(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskIsAutomaticallyCancelledInTask() async {
        // Given
        let session = Session()
        let request = session.request(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self).result
        }

        task.cancel()
        let result = await task.value

        // Then
        #expect(result.failure?.isExplicitlyCancelledError == true)
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskIsNotAutomaticallyCancelledInTaskWhenDisabled() async {
        // Given
        let session = Session()
        let request = session.request(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self, automaticallyCancelling: false).result
        }

        task.cancel()
        let result = await task.value

        // Then
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(!request.isCancelled, "Underlying DataRequest should not be cancelled.")
        #expect(result.isSuccess, "DataRequest should succeed.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskIsAutomaticallyCancelledInTaskGroup() async {
        // Given
        let session = Session()
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
        #expect(result.failure?.isExplicitlyCancelledError == true)
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataTaskIsNotAutomaticallyCancelledInTaskGroupWhenDisabled() async {
        // Given
        let session = Session()
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
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(!request.isCancelled, "Underlying DataRequest should not be cancelled.")
        #expect(result.isSuccess, "DataRequest should succeed.")
    }
}

@Suite
struct DownloadConcurrencyTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskSerializesResponseFromSerializer() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.download(.get)
            .serializingDownload(using: .data)
            .value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskSerializesDecodable() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.download(.get).serializingDecodable(TestResponse.self).value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskSerializesString() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.download(.get).serializingString().value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskSerializesData() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.download(.get).serializingData().value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskSerializesURL() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.download(.get).serializingDownloadedFileURL().value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskProducesResult() async {
        // Given
        let session = Session()

        // When
        let result = await session.download(.get).serializingDecodable(TestResponse.self).result

        // Then
        #expect(result.success != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskProducesValue() async throws {
        // Given
        let session = Session()

        // When
        let value = try await session.download(.get).serializingDecodable(TestResponse.self).value

        // Then
        #expect(value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskProperlySupportsConcurrentRequests() async {
        // Given
        let session = Session()

        // When
        async let first = session.download(.get).serializingDecodable(TestResponse.self).response
        async let second = session.download(.get).serializingDecodable(TestResponse.self).response
        async let third = session.download(.get).serializingDecodable(TestResponse.self).response

        // Then
        let responses = await [first, second, third]
        #expect(responses.count == 3)
        // #expect treats a key path passed to rethrowing allSatisfy as a throwing call.
        // swiftformat:disable:next preferKeyPath
        #expect(responses.allSatisfy { $0.result.isSuccess })
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskCancelsRequest() async {
        // Given
        let session = Session()
        let request = session.download(.get)
        let task = request.serializingDecodable(TestResponse.self)

        // When
        task.cancel()
        let response = await task.response

        // Then
        #expect(response.error?.isExplicitlyCancelledError == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskIsAutomaticallyCancelledInTask() async {
        // Given
        let session = Session()
        let request = session.download(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self).result
        }

        task.cancel()
        let result = await task.value

        // Then
        #expect(result.failure?.isExplicitlyCancelledError == true)
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(request.isCancelled, "Underlying DownloadRequest should be cancelled.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskIsNotAutomaticallyCancelledInTaskWhenDisabled() async {
        // Given
        let session = Session()
        let request = session.download(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self, automaticallyCancelling: false).result
        }

        task.cancel()
        let result = await task.value

        // Then
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(!request.isCancelled, "Underlying DownloadRequest should not be cancelled.")
        #expect(result.isSuccess, "DownloadRequest should succeed.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskIsAutomaticallyCancelledInTaskGroup() async {
        // Given
        let session = Session()
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
        #expect(result.failure?.isExplicitlyCancelledError == true)
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(request.isCancelled, "Underlying DownloadRequest should be cancelled.")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadTaskIsNotAutomaticallyCancelledInTaskGroupWhenDisabled() async {
        // Given
        let session = Session()
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
        #expect(task.isCancelled, "Task should be cancelled.")
        #expect(!request.isCancelled, "Underlying DownloadRequest should not be cancelled.")
        #expect(result.isSuccess, "DownloadRequest should succeed.")
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
        let session = stored(Session())
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
        session.upload(inputStream, with: request)
            .uploadProgress(queue: session.rootQueue) { progress in
                uploadProgressValues.append(progress.fractionCompleted)
            }
            .downloadProgress(queue: session.rootQueue) { progress in
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

        await fulfillment(of: [receivedEvent], timeout: timeout)

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

@Suite
struct ClosureAPIConcurrencyTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadProgressStreamReturnsProgress() async {
        // Given
        let session = Session()

        // When
        let request = session.request(.get)
        // Start streams outside async let so the asynchrony starts later.
        let _httpResponses = request.httpResponses()
        let _uploadProgress = request.uploadProgress()
        let _downloadProgress = request.downloadProgress()
        let _requests = request.urlRequests()
        let _tasks = request.urlSessionTasks()
        let _descriptions = request.cURLDescriptions()
        // Start collecting in parallel.
        async let httpResponses = _httpResponses.collect()
        async let uploadProgress = _uploadProgress.collect()
        async let downloadProgress = _downloadProgress.collect()
        async let requests = _requests.collect()
        async let tasks = _tasks.collect()
        async let descriptions = _descriptions.collect()
        // Start request in parallel as well.
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
        #expect(values.httpResponses.count == 1, "httpResponses should have one response")
        #expect(values.uploadProgresses.isEmpty, "uploadProgresses should be empty")
        #expect(values.downloadProgresses.last != nil, "downloadProgresses should not be empty")
        #expect(values.downloadProgresses.last?.isFinished == true, "last download progression should be finished")
        #expect(values.requests.last != nil, "requests should not be empty")
        #expect(values.tasks.last != nil, "tasks should not be empty")
        #expect(values.descriptions.last != nil, "descriptions should not be empty")
        #expect(values.response.result.isSuccess, "request should succeed")
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
