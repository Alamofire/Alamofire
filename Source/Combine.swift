//
//  Combine.swift
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

import Combine

// MARK: - DataRequest / UploadRequest

/// A Combine `Publisher` that publishes the `DataResponse<Value, AFError>` of the provided `DataRequest`.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
public struct DataResponsePublisher<Value>: Publisher {
    public typealias Output = DataResponse<Value, AFError>
    public typealias Failure = Never

    private typealias Handler = (@escaping (_ response: DataResponse<Value, AFError>) -> Void) -> DataRequest

    private let request: DataRequest
    private let responseHandler: Handler

    /// Create an instance which will serialize responses using the provided `ResponseSerializer`.
    ///
    /// - Parameters:
    ///   - request:    `DataRequest` for which to publish the response.
    ///   - queue:      `DispatchQueue` on which the `DataResponse` value will be published. `.main` by default.
    ///   - serializer: `ResponseSerializer` used to produce the published `DataResponse`.
    public init<Serializer: ResponseSerializer>(_ request: DataRequest, queue: DispatchQueue, serializer: Serializer)
        where Value == Serializer.SerializedObject {
        self.request = request
        responseHandler = { request.response(queue: queue, responseSerializer: serializer, completionHandler: $0) }
    }

    /// Publish only the `Result` of the `DataResponse` value.
    ///
    /// - Returns: The `AnyPublisher` publishing the `Result<Value, AFError>` value.
    public func result() -> AnyPublisher<Result<Value, AFError>, Never> {
        map { $0.result }.eraseToAnyPublisher()
    }

    /// Publish the `Result` of the `DataResponse` as a single `Value` or fail with the `AFError` instance.
    ///
    /// - Returns: The `AnyPublisher<Value, AFError>` publishing the stream.
    public func value() -> AnyPublisher<Value, AFError> {
        setFailureType(to: AFError.self).flatMap { $0.result.publisher }.eraseToAnyPublisher()
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        subscriber.receive(subscription: Inner(request: request,
                                               responseHandler: responseHandler,
                                               downstream: subscriber))
    }

    private final class Inner<Downstream: Subscriber>: Subscription, Cancellable
        where Downstream.Input == Output {
        typealias Input = DataRequest
        typealias Failure = Downstream.Failure

        @Protected
        private var downstream: Downstream?
        private let request: DataRequest
        private let responseHandler: Handler

        init(request: DataRequest, responseHandler: @escaping Handler, downstream: Downstream) {
            self.request = request
            self.responseHandler = responseHandler
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {
            assert(demand > 0)

            guard let downstream = downstream else { return }

            self.downstream = nil
            responseHandler { response in
                _ = downstream.receive(response)
                downstream.receive(completion: .finished)
            }.resume()
        }

        func cancel() {
            request.cancel()
            downstream = nil
        }
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
extension DataResponsePublisher where Value == Data? {
    /// Create an instance which publishes a `DataResponse<Data?, AFError>` value without serialization.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public init(_ request: DataRequest, queue: DispatchQueue) {
        self.request = request
        responseHandler = { request.response(queue: queue, completionHandler: $0) }
    }
}

extension DataRequest {
    /// Creates a `DataResponsePublisher` for this instance using the given `ResponseSerializer` and `DispatchQueue`.
    ///
    /// - Parameters:
    ///   - serializer: `ResponseSerializer` used to serialize response `Data`.
    ///   - queue:      `DispatchQueue` on which the `DataResponse` will be published. `.main` by default.
    ///
    /// - Returns: `    The `DataResponsePublisher`.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishResponse<Serializer: ResponseSerializer, T>(using serializer: Serializer, on queue: DispatchQueue = .main) -> DataResponsePublisher<T>
        where Serializer.SerializedObject == T {
        DataResponsePublisher(self, queue: queue, serializer: serializer)
    }

    /// Creates a `DataResponsePublisher` for this instance and uses a `DataResponseSerializer` to serialize the
    /// response.
    ///
    /// - Parameters:
    ///   - queue:               `DispatchQueue` on which the `DataResponse` will be published. `.main` by default.
    ///   - preprocessor:        `DataPreprocessor` which filters the `Data` before serialization. `PassthroughPreprocessor()`
    ///                          by default.
    ///   - emptyResponseCodes:  `Set<Int>` of HTTP status codes for which empty responses are allowed. `[204, 205]` by
    ///                          default.
    ///   - emptyRequestMethods: `Set<HTTPMethod>` of `HTTPMethod`s for which empty responses are allowed, regardless of
    ///                          status code. `[.head]` by default.
    /// - Returns:               The `DataResponsePublisher`.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishData(queue: DispatchQueue = .main,
                            preprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                            emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                            emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataResponsePublisher<Data> {
        publishResponse(using: DataResponseSerializer(dataPreprocessor: preprocessor,
                                                      emptyResponseCodes: emptyResponseCodes,
                                                      emptyRequestMethods: emptyRequestMethods),
                        on: queue)
    }

    /// Creates a `DataResponsePublisher` for this instance and uses a `StringResponseSerializer` to serialize the
    /// response.
    ///
    /// - Parameters:
    ///   - queue:               `DispatchQueue` on which the `DataResponse` will be published. `.main` by default.
    ///   - preprocessor:        `DataPreprocessor` which filters the `Data` before serialization. `PassthroughPreprocessor()`
    ///                          by default.
    ///   - encoding:            `String.Encoding` to parse the response. `nil` by default, in which case the encoding
    ///                          will be determined by the server response, falling back to the default HTTP character
    ///                          set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  `Set<Int>` of HTTP status codes for which empty responses are allowed. `[204, 205]` by
    ///                          default.
    ///   - emptyRequestMethods: `Set<HTTPMethod>` of `HTTPMethod`s for which empty responses are allowed, regardless of
    ///                          status code. `[.head]` by default.
    ///
    /// - Returns:               The `DataResponsePublisher`.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishString(queue: DispatchQueue = .main,
                              preprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                              encoding: String.Encoding? = nil,
                              emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                              emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DataResponsePublisher<String> {
        publishResponse(using: StringResponseSerializer(dataPreprocessor: preprocessor,
                                                        encoding: encoding,
                                                        emptyResponseCodes: emptyResponseCodes,
                                                        emptyRequestMethods: emptyRequestMethods),
                        on: queue)
    }

    /// Creates a `DataResponsePublisher` for this instance and uses a `DecodableResponseSerializer` to serialize the
    /// response.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to which to decode response `Data`. Inferred from the context by default.
    ///   - queue:               `DispatchQueue` on which the `DataResponse` will be published. `.main` by default.
    ///   - preprocessor:        `DataPreprocessor` which filters the `Data` before serialization. `PassthroughPreprocessor()`
    ///                          by default.
    ///   - decoder:             `DataDecoder` instance used to decode response `Data`. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  `Set<Int>` of HTTP status codes for which empty responses are allowed. `[204, 205]` by
    ///                          default.
    ///   - emptyRequestMethods: `Set<HTTPMethod>` of `HTTPMethod`s for which empty responses are allowed, regardless of
    ///                          status code. `[.head]` by default.
    ///
    /// - Returns:               The `DataResponsePublisher`.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishDecodable<T: Decodable>(type: T.Type = T.self,
                                               queue: DispatchQueue = .main,
                                               preprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                               decoder: DataDecoder = JSONDecoder(),
                                               emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                               emptyResponseMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods) -> DataResponsePublisher<T> {
        publishResponse(using: DecodableResponseSerializer(dataPreprocessor: preprocessor,
                                                           decoder: decoder,
                                                           emptyResponseCodes: emptyResponseCodes,
                                                           emptyRequestMethods: emptyResponseMethods),
                        on: queue)
    }

    /// Creates a `DataResponsePublisher` for this instance which does not serialize the response before publishing.
    ///
    ///   - queue: `DispatchQueue` on which the `DataResponse` will be published. `.main` by default.
    ///
    /// - Returns: The `DataResponsePublisher`.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishUnserialized(queue: DispatchQueue = .main) -> DataResponsePublisher<Data?> {
        DataResponsePublisher(self, queue: queue)
    }
}

#endif
