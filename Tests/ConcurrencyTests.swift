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

#if compiler(>=5.6.0) && canImport(_Concurrency)

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

    func testThatDataTaskIsAutomaticallyCancelledInTaskWhenEnabled() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self, automaticallyCancelling: true).result
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(result.failure?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertTrue(request.isCancelled, "Underlying DataRequest should be cancelled.")
    }

    func testThatDataTaskIsAutomaticallyCancelledInTaskGroupWhenEnabled() async {
        // Given
        let session = stored(Session())
        let request = session.request(.get)

        // When
        let task = Task {
            await withTaskGroup(of: Result<TestResponse, AFError>.self) { group -> Result<TestResponse, AFError> in
                group.addTask {
                    await request.serializingDecodable(TestResponse.self, automaticallyCancelling: true).result
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

    func testThatDownloadTaskIsAutomaticallyCancelledInTaskWhenEnabled() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)

        // When
        let task = Task {
            await request.serializingDecodable(TestResponse.self, automaticallyCancelling: true).result
        }

        task.cancel()
        let result = await task.value

        // Then
        XCTAssertTrue(result.failure?.isExplicitlyCancelledError == true)
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
        XCTAssertTrue(request.isCancelled, "Underlying DownloadRequest should be cancelled.")
    }

    func testThatDownloadTaskIsAutomaticallyCancelledInTaskGroupWhenEnabled() async {
        // Given
        let session = stored(Session())
        let request = session.download(.get)

        // When
        let task = Task {
            await withTaskGroup(of: Result<TestResponse, AFError>.self) { group -> Result<TestResponse, AFError> in
                group.addTask {
                    await request.serializingDecodable(TestResponse.self, automaticallyCancelling: true).result
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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class ClosureAPIConcurrencyTests: BaseTestCase {
    func testThatDownloadProgressStreamReturnsProgress() async {
        // Given
        let session = stored(Session())

        // When
        let request = session.request(.get)
        async let uploadProgress = request.uploadProgress().collect()
        async let downloadProgress = request.downloadProgress().collect()
        async let requests = request.urlRequests().collect()
        async let tasks = request.urlSessionTasks().collect()
        async let descriptions = request.cURLDescriptions().collect()
        async let response = request.serializingDecodable(TestResponse.self).response

        let values: (uploadProgresses: [Progress],
                     downloadProgresses: [Progress],
                     requests: [URLRequest],
                     tasks: [URLSessionTask],
                     descriptions: [String],
                     response: AFDataResponse<TestResponse>)
        values = await(uploadProgress, downloadProgress, requests, tasks, descriptions, response)

        // Then
        XCTAssertTrue(values.uploadProgresses.isEmpty)
        XCTAssertNotNil(values.downloadProgresses.last)
        XCTAssertTrue(values.downloadProgresses.last?.isFinished == true)
        XCTAssertNotNil(values.requests.last)
        XCTAssertNotNil(values.tasks.last)
        XCTAssertNotNil(values.descriptions.last)
        XCTAssertTrue(values.response.result.isSuccess)
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
