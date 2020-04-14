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

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
public struct DataResponsePublisher<Serializer>: Publisher where Serializer: ResponseSerializer {
    public typealias Output = DataResponse<Serializer.SerializedObject, AFError>
    public typealias Failure = Never

    private let request: DataRequest
    private let queue: DispatchQueue
    private let serializer: Serializer

    init(_ request: DataRequest, queue: DispatchQueue, serializer: Serializer) {
        self.request = request
        self.queue = queue
        self.serializer = serializer
    }

    public func result() -> AnyPublisher<Result<Serializer.SerializedObject, AFError>, Never> {
        map { $0.result }.eraseToAnyPublisher()
    }

    public func value() -> AnyPublisher<Serializer.SerializedObject, AFError> {
        setFailureType(to: AFError.self).flatMap { $0.result.publisher }.eraseToAnyPublisher()
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        subscriber.receive(subscription: Inner(request: request,
                                               queue: queue,
                                               serializer: serializer,
                                               downstream: subscriber))
    }

    private final class Inner<Downstream: Subscriber>: Subscription, Cancellable
        where Downstream.Input == Output {
        typealias Input = DataRequest
        typealias Failure = Downstream.Failure

        @Protected
        private var downstream: Downstream?
        private let request: DataRequest
        private let queue: DispatchQueue
        private let serializer: Serializer

        init(request: DataRequest, queue: DispatchQueue, serializer: Serializer, downstream: Downstream) {
            self.request = request
            self.queue = queue
            self.serializer = serializer
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {
            assert(demand > 0)

            guard let downstream = downstream else { return }

            self.downstream = nil

            request.response(queue: queue, responseSerializer: serializer) { response in
                _ = downstream.receive(response)
                downstream.receive(completion: .finished)
            }
        }

        func cancel() {
            request.cancel()
            downstream = nil
        }
    }
}

extension DataRequest {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func responsePublisher<T: Decodable>(of: T.Type = T.self,
                                                queue: DispatchQueue = .main,
                                                preprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                                decoder: DataDecoder = JSONDecoder(),
                                                emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                                emptyResponseMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods) -> DataResponsePublisher<DecodableResponseSerializer<T>> {
        DataResponsePublisher(self, queue: queue, serializer: DecodableResponseSerializer(dataPreprocessor: preprocessor,
                                                                                          decoder: decoder,
                                                                                          emptyResponseCodes: emptyResponseCodes,
                                                                                          emptyRequestMethods: emptyResponseMethods))
    }
}

#endif
