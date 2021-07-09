//
//  Async.swift
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

#if swift(>=5.5)

import Foundation

/// Value used to `await` a `DataResponse` and associated values.
///
/// `DataTask` additionally exposes the read-only properties available from the underlying `DataRequest`.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
@dynamicMemberLookup
public struct DataTask<Value> {
    /// `DataResponse` produced by the `DataRequest` and its response handler.
    public var response: DataResponse<Value, AFError> {
        get async { await handle.get() }
    }

    /// `Result` of any response serialization performed for the response.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the response serialization.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let handle: Task.Handle<AFDataResponse<Value>, Never>
    private let request: DataRequest

    fileprivate init(request: DataRequest, handle: Task.Handle<AFDataResponse<Value>, Never>) {
        self.request = request
        self.handle = handle
    }

    /// Cancel the underlying `DataRequest` and `Task`.
    public func cancel() {
        handle.cancel()
    }

    /// Resume the underlying `DataRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DataRequest`.
    public func suspend() {
        request.suspend()
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DataRequest, T>) -> T {
        request[keyPath: keyPath]
    }
}

extension DispatchQueue {
    fileprivate static let asyncCompletionQueue = DispatchQueue(label: "org.alamofire.asyncCompletionQueue",
                                                                attributes: .concurrent)
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension DataRequest {
    /// Creates a `DataTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - decoder:             `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func decode<Value: Decodable>(_ type: Value.Type = Value.self,
                                         dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                         decoder: DataDecoder = JSONDecoder(),
                                         emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                         emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DataTask<Value> {
        serialize(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                            decoder: decoder,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods))
    }

    /// Creates a `DataTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func string(dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                       encoding: String.Encoding? = nil,
                       emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                       emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DataTask<String> {
        serialize(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                  encoding: encoding,
                                                  emptyResponseCodes: emptyResponseCodes,
                                                  emptyRequestMethods: emptyRequestMethods))
    }

    /// Creates a `DataTask` to `await` serialization of a `Data` value.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func data(dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                     emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                     emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataTask<Data> {
        serialize(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                emptyResponseCodes: emptyResponseCodes,
                                                emptyRequestMethods: emptyRequestMethods))
    }

    /// Creates a `DataTask` to `await` serialization using the provided `DataResponseSerializerProtocol` instance.
    ///
    /// - Parameters:
    ///    - serializer: Response serializer responsible for serializing the request, response, and data.
    ///
    /// - Returns: The `DataTask`.
    public func serialize<Serializer: DataResponseSerializerProtocol>(using serializer: Serializer) -> DataTask<Serializer.SerializedObject> {
        dataTask {
            self.response(queue: .asyncCompletionQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    private func dataTask<Value>(forResponse onResponse: @escaping (@escaping (DataResponse<Value, AFError>) -> Void) -> Void) -> DataTask<Value> {
        let handle = async {
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

        return DataTask<Value>(request: self, handle: handle)
    }
}

#endif
