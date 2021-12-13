//
//  Concurrency.swift
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

#if compiler(>=5.5.2) && canImport(_Concurrency)

import Foundation

// MARK: - Request Event Streams

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Request {
    /// Creates a `StreamOf<Progress>` for the instance's upload progress.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<Progress>`.
    public func uploadProgress(bufferingPolicy: StreamOf<Progress>.BufferingPolicy = .unbounded) -> StreamOf<Progress> {
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            uploadProgress(queue: .singleEventQueue) { progress in
                continuation.yield(progress)
            }
        }
    }

    /// Creates a `StreamOf<Progress>` for the instance's download progress.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<Progress>`.
    public func downloadProgress(bufferingPolicy: StreamOf<Progress>.BufferingPolicy = .unbounded) -> StreamOf<Progress> {
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            downloadProgress(queue: .singleEventQueue) { progress in
                continuation.yield(progress)
            }
        }
    }

    /// Creates a `StreamOf<URLRequest>` for the `URLRequest`s produced for the instance.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<URLRequest>`.
    public func urlRequests(bufferingPolicy: StreamOf<URLRequest>.BufferingPolicy = .unbounded) -> StreamOf<URLRequest> {
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            onURLRequestCreation(on: .singleEventQueue) { request in
                continuation.yield(request)
            }
        }
    }

    /// Creates a `StreamOf<URLSessionTask>` for the `URLSessionTask`s produced for the instance.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<URLSessionTask>`.
    public func urlSessionTasks(bufferingPolicy: StreamOf<URLSessionTask>.BufferingPolicy = .unbounded) -> StreamOf<URLSessionTask> {
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            onURLSessionTaskCreation(on: .singleEventQueue) { task in
                continuation.yield(task)
            }
        }
    }

    /// Creates a `StreamOf<String>` for the cURL descriptions produced for the instance.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<String>`.
    public func cURLDescriptions(bufferingPolicy: StreamOf<String>.BufferingPolicy = .unbounded) -> StreamOf<String> {
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            cURLDescription(on: .singleEventQueue) { description in
                continuation.yield(description)
            }
        }
    }

    private func stream<T>(of type: T.Type = T.self,
                           bufferingPolicy: StreamOf<T>.BufferingPolicy = .unbounded,
                           yielder: @escaping (StreamOf<T>.Continuation) -> Void) -> StreamOf<T> {
        StreamOf<T>(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            yielder(continuation)
            // Must come after serializers run in order to catch retry progress.
            onFinish {
                continuation.finish()
            }
        }
    }
}

// MARK: - DataTask

/// Value used to `await` a `DataResponse` and associated values.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DataTask<Value> {
    /// `DataResponse` produced by the `DataRequest` and its response handler.
    public var response: DataResponse<Value, AFError> {
        get async {
            if shouldAutomaticallyCancel {
                return await withTaskCancellationHandler {
                    self.cancel()
                } operation: {
                    await task.value
                }
            } else {
                return await task.value
            }
        }
    }

    /// `Result` of any response serialization performed for the `response`.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the `response`.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let request: DataRequest
    private let task: Task<DataResponse<Value, AFError>, Never>
    private let shouldAutomaticallyCancel: Bool

    fileprivate init(request: DataRequest, task: Task<DataResponse<Value, AFError>, Never>, shouldAutomaticallyCancel: Bool) {
        self.request = request
        self.task = task
        self.shouldAutomaticallyCancel = shouldAutomaticallyCancel
    }

    /// Cancel the underlying `DataRequest` and `Task`.
    public func cancel() {
        task.cancel()
    }

    /// Resume the underlying `DataRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DataRequest`.
    public func suspend() {
        request.suspend()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DataRequest {
    /// Creates a `DataTask` to `await` a `Data` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `false` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before completion.
    ///   - emptyResponseCodes:        HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataTask<Data> {
        serializingResponse(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                          emptyResponseCodes: emptyResponseCodes,
                                                          emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Parameters:
    ///   - type:                      `Decodable` type to decode from response data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `false` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                                `PassthroughPreprocessor()` by default.
    ///   - decoder:                   `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingDecodable<Value: Decodable>(_ type: Value.Type = Value.self,
                                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                                       dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                                       decoder: DataDecoder = JSONDecoder(),
                                                       emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                                       emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DataTask<Value> {
        serializingResponse(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                                      decoder: decoder,
                                                                      emptyResponseCodes: emptyResponseCodes,
                                                                      emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `false` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                                `PassthroughPreprocessor()` by default.
    ///   - encoding:                  `String.Encoding` to use during serialization. Defaults to `nil`, in which case
    ///                                the encoding will be determined from the server response, falling back to the
    ///                                default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingString(automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                  dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                                  encoding: String.Encoding? = nil,
                                  emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                                  emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DataTask<String> {
        serializingResponse(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            encoding: encoding,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization using the provided `ResponseSerializer` instance.
    ///
    /// - Parameters:
    ///   - serializer:                `ResponseSerializer` responsible for serializing the request, response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `false` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingResponse<Serializer: ResponseSerializer>(using serializer: Serializer,
                                                                    automaticallyCancelling shouldAutomaticallyCancel: Bool = false)
        -> DataTask<Serializer.SerializedObject> {
        dataTask(automaticallyCancelling: shouldAutomaticallyCancel) {
            self.response(queue: .singleEventQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    /// Creates a `DataTask` to `await` serialization using the provided `DataResponseSerializerProtocol` instance.
    ///
    /// - Parameters:
    ///   - serializer:                `DataResponseSerializerProtocol` responsible for serializing the request,
    ///                                response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `false` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingResponse<Serializer: DataResponseSerializerProtocol>(using serializer: Serializer,
                                                                                automaticallyCancelling shouldAutomaticallyCancel: Bool = false)
        -> DataTask<Serializer.SerializedObject> {
        dataTask(automaticallyCancelling: shouldAutomaticallyCancel) {
            self.response(queue: .singleEventQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    private func dataTask<Value>(automaticallyCancelling shouldAutomaticallyCancel: Bool,
                                 forResponse onResponse: @escaping (@escaping (DataResponse<Value, AFError>) -> Void) -> Void)
        -> DataTask<Value> {
        let task = Task {
            await withTaskCancellationHandler {
                self.cancel()
            } operation: {
                await withCheckedContinuation { continuation in
                    onResponse {
                        continuation.resume(returning: $0)
                    }
                }
            }
        }

        return DataTask<Value>(request: self, task: task, shouldAutomaticallyCancel: shouldAutomaticallyCancel)
    }
}

// MARK: - DownloadTask

/// Value used to `await` a `DownloadResponse` and associated values.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DownloadTask<Value> {
    /// `DownloadResponse` produced by the `DownloadRequest` and its response handler.
    public var response: DownloadResponse<Value, AFError> {
        get async {
            if shouldAutomaticallyCancel {
                return await withTaskCancellationHandler {
                    self.cancel()
                } operation: {
                    await task.value
                }
            } else {
                return await task.value
            }
        }
    }

    /// `Result` of any response serialization performed for the `response`.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the `response`.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let task: Task<AFDownloadResponse<Value>, Never>
    private let request: DownloadRequest
    private let shouldAutomaticallyCancel: Bool

    fileprivate init(request: DownloadRequest, task: Task<AFDownloadResponse<Value>, Never>, shouldAutomaticallyCancel: Bool) {
        self.request = request
        self.task = task
        self.shouldAutomaticallyCancel = shouldAutomaticallyCancel
    }

    /// Cancel the underlying `DownloadRequest` and `Task`.
    public func cancel() {
        task.cancel()
    }

    /// Resume the underlying `DownloadRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DownloadRequest`.
    public func suspend() {
        request.suspend()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DownloadRequest {
    /// Creates a `DownloadTask` to `await` a `Data` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `false` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before completion.
    ///   - emptyResponseCodes:        HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns:                   The `DownloadTask`.
    public func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DownloadTask<Data> {
        serializingDownload(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                          emptyResponseCodes: emptyResponseCodes,
                                                          emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DownloadTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Note: This serializer reads the entire response into memory before parsing.
    ///
    /// - Parameters:
    ///   - type:                      `Decodable` type to decode from response data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `false` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                                `PassthroughPreprocessor()` by default.
    ///   - decoder:                   `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns:                   The `DownloadTask`.
    public func serializingDecodable<Value: Decodable>(_ type: Value.Type = Value.self,
                                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                                       dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                                       decoder: DataDecoder = JSONDecoder(),
                                                       emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                                       emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DownloadTask<Value> {
        serializingDownload(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                                      decoder: decoder,
                                                                      emptyResponseCodes: emptyResponseCodes,
                                                                      emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DownloadTask` to `await` serialization of the downloaded file's `URL` on disk.
    ///
    /// - Returns: The `DownloadTask`.
    public func serializingDownloadedFileURL() -> DownloadTask<URL> {
        serializingDownload(using: URLResponseSerializer())
    }

    /// Creates a `DownloadTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `false` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the
    ///                                serializer. `PassthroughPreprocessor()` by default.
    ///   - encoding:                  `String.Encoding` to use during serialization. Defaults to `nil`, in which case
    ///                                the encoding will be determined from the server response, falling back to the
    ///                                default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns:                   The `DownloadTask`.
    public func serializingString(automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                  dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                                  encoding: String.Encoding? = nil,
                                  emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                                  emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DownloadTask<String> {
        serializingDownload(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            encoding: encoding,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DownloadTask` to `await` serialization using the provided `ResponseSerializer` instance.
    ///
    /// - Parameters:
    ///   - serializer:                `ResponseSerializer` responsible for serializing the request, response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `false` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func serializingDownload<Serializer: ResponseSerializer>(using serializer: Serializer,
                                                                    automaticallyCancelling shouldAutomaticallyCancel: Bool = false)
        -> DownloadTask<Serializer.SerializedObject> {
        downloadTask(automaticallyCancelling: shouldAutomaticallyCancel) {
            self.response(queue: .singleEventQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    /// Creates a `DownloadTask` to `await` serialization using the provided `DownloadResponseSerializerProtocol`
    /// instance.
    ///
    /// - Parameters:
    ///   - serializer:                `DownloadResponseSerializerProtocol` responsible for serializing the request,
    ///                                response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `false` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func serializingDownload<Serializer: DownloadResponseSerializerProtocol>(using serializer: Serializer,
                                                                                    automaticallyCancelling shouldAutomaticallyCancel: Bool = false)
        -> DownloadTask<Serializer.SerializedObject> {
        downloadTask(automaticallyCancelling: shouldAutomaticallyCancel) {
            self.response(queue: .singleEventQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    private func downloadTask<Value>(automaticallyCancelling shouldAutomaticallyCancel: Bool,
                                     forResponse onResponse: @escaping (@escaping (DownloadResponse<Value, AFError>) -> Void) -> Void)
        -> DownloadTask<Value> {
        let task = Task {
            await withTaskCancellationHandler {
                self.cancel()
            } operation: {
                await withCheckedContinuation { continuation in
                    onResponse {
                        continuation.resume(returning: $0)
                    }
                }
            }
        }

        return DownloadTask<Value>(request: self, task: task, shouldAutomaticallyCancel: shouldAutomaticallyCancel)
    }
}

// MARK: - DataStreamTask

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DataStreamTask {
    // Type of created streams.
    public typealias Stream<Success, Failure: Error> = StreamOf<DataStreamRequest.Stream<Success, Failure>>

    private let request: DataStreamRequest

    fileprivate init(request: DataStreamRequest) {
        self.request = request
    }

    /// Creates a `Stream` of `Data` values from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy: `         BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `Stream`.
    public func streamingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = true, bufferingPolicy: Stream<Data, Never>.BufferingPolicy = .unbounded) -> Stream<Data, Never> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel, bufferingPolicy: bufferingPolicy) { onStream in
            self.request.responseStream(on: .streamCompletionQueue(forRequestID: request.id), stream: onStream)
        }
    }

    /// Creates a `Stream` of `UTF-8` `String`s from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy: `         BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    /// - Returns:
    public func streamingStrings(automaticallyCancelling shouldAutomaticallyCancel: Bool = true, bufferingPolicy: Stream<String, Never>.BufferingPolicy = .unbounded) -> Stream<String, Never> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel, bufferingPolicy: bufferingPolicy) { onStream in
            self.request.responseStreamString(on: .streamCompletionQueue(forRequestID: request.id), stream: onStream)
        }
    }

    /// Creates a `Stream` of `Decodable` values from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - type:                      `Decodable` type to be serialized from stream payloads.
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy:           `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:            The `Stream`.
    public func streamingDecodables<T>(_ type: T.Type = T.self,
                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                       bufferingPolicy: Stream<T, AFError>.BufferingPolicy = .unbounded)
        -> Stream<T, AFError> where T: Decodable {
        streamingResponses(serializedUsing: DecodableStreamSerializer<T>(),
                           automaticallyCancelling: shouldAutomaticallyCancel,
                           bufferingPolicy: bufferingPolicy)
    }

    /// Creates a `Stream` of values using the provided `DataStreamSerializer` from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - serializer:                `DataStreamSerializer` to use to serialize incoming `Data`.
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy:           `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:           The `Stream`.
    public func streamingResponses<Serializer: DataStreamSerializer>(serializedUsing serializer: Serializer,
                                                                     automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                                                     bufferingPolicy: Stream<Serializer.SerializedObject, AFError>.BufferingPolicy = .unbounded)
        -> Stream<Serializer.SerializedObject, AFError> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel, bufferingPolicy: bufferingPolicy) { onStream in
            self.request.responseStream(using: serializer,
                                        on: .streamCompletionQueue(forRequestID: request.id),
                                        stream: onStream)
        }
    }

    private func createStream<Success, Failure: Error>(automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                                       bufferingPolicy: Stream<Success, Failure>.BufferingPolicy = .unbounded,
                                                       forResponse onResponse: @escaping (@escaping (DataStreamRequest.Stream<Success, Failure>) -> Void) -> Void)
        -> Stream<Success, Failure> {
        StreamOf(bufferingPolicy: bufferingPolicy) {
            guard shouldAutomaticallyCancel,
                  request.isInitialized || request.isResumed || request.isSuspended else { return }

            cancel()
        } builder: { continuation in
            onResponse { stream in
                continuation.yield(stream)
                if case .complete = stream.event {
                    continuation.finish()
                }
            }
        }
    }

    /// Cancel the underlying `DataStreamRequest`.
    public func cancel() {
        request.cancel()
    }

    /// Resume the underlying `DataStreamRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DataStreamRequest`.
    public func suspend() {
        request.suspend()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DataStreamRequest {
    /// Creates a `DataStreamTask` used to `await` streams of serialized values.
    ///
    /// - Returns: The `DataStreamTask`.
    public func streamTask() -> DataStreamTask {
        DataStreamTask(request: self)
    }
}

extension DispatchQueue {
    fileprivate static let singleEventQueue = DispatchQueue(label: "org.alamofire.concurrencySingleEventQueue",
                                                            attributes: .concurrent)

    fileprivate static func streamCompletionQueue(forRequestID id: UUID) -> DispatchQueue {
        DispatchQueue(label: "org.alamofire.concurrencyStreamCompletionQueue-\(id)", target: .singleEventQueue)
    }
}

/// An asynchronous sequence generated from an underlying `AsyncStream`. Only produced by Alamofire.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct StreamOf<Element>: AsyncSequence {
    public typealias AsyncIterator = Iterator
    public typealias BufferingPolicy = AsyncStream<Element>.Continuation.BufferingPolicy
    fileprivate typealias Continuation = AsyncStream<Element>.Continuation

    private let bufferingPolicy: BufferingPolicy
    private let onTermination: (() -> Void)?
    private let builder: (Continuation) -> Void

    fileprivate init(bufferingPolicy: BufferingPolicy = .unbounded,
                     onTermination: (() -> Void)? = nil,
                     builder: @escaping (Continuation) -> Void) {
        self.bufferingPolicy = bufferingPolicy
        self.onTermination = onTermination
        self.builder = builder
    }

    public func makeAsyncIterator() -> Iterator {
        var continuation: AsyncStream<Element>.Continuation?
        let stream = AsyncStream<Element> { innerContinuation in
            continuation = innerContinuation
            builder(innerContinuation)
        }

        return Iterator(iterator: stream.makeAsyncIterator()) {
            continuation?.finish()
            self.onTermination?()
        }
    }

    public struct Iterator: AsyncIteratorProtocol {
        private final class Token {
            private let onDeinit: () -> Void

            init(onDeinit: @escaping () -> Void) {
                self.onDeinit = onDeinit
            }

            deinit {
                onDeinit()
            }
        }

        private var iterator: AsyncStream<Element>.AsyncIterator
        private let token: Token

        init(iterator: AsyncStream<Element>.AsyncIterator, onCancellation: @escaping () -> Void) {
            self.iterator = iterator
            token = Token(onDeinit: onCancellation)
        }

        public mutating func next() async -> Element? {
            await iterator.next()
        }
    }
}

#endif
