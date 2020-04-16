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
public struct DataResponsePublisher<Value>: Publisher {
    public typealias Output = DataResponse<Value, AFError>
    public typealias Failure = Never

    private typealias Handler = (@escaping (_ response: DataResponse<Value, AFError>) -> Void) -> DataRequest

    private let request: DataRequest
    private let responseHandler: Handler
//
//    init(_ request: DataRequest, queue: DispatchQueue) {
//        self.request = request
//        responseHandler = { (handler: (DataResponse<Data?, AFError>) -> Void)) -> DataRequest in
//            request.response(queue: queue, completionHandler: handler)
//        }
//    }

    init<Serializer: ResponseSerializer>(_ request: DataRequest, queue: DispatchQueue, serializer: Serializer)
        where Value == Serializer.SerializedObject {
        self.request = request
        responseHandler = { request.response(queue: queue, responseSerializer: serializer, completionHandler: $0) }
    }

    public func result() -> AnyPublisher<Result<Value, AFError>, Never> {
        map { $0.result }.eraseToAnyPublisher()
    }

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

extension DataRequest {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publish<Serializer: ResponseSerializer, T>(serializer: Serializer, queue: DispatchQueue = .main) -> DataResponsePublisher<T>
        where Serializer.SerializedObject == T {
        DataResponsePublisher(self, queue: queue, serializer: serializer)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishData(queue: DispatchQueue = .main,
                            preprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                            emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                            emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataResponsePublisher<Data> {
        publish(serializer: DataResponseSerializer(dataPreprocessor: preprocessor,
                                                   emptyResponseCodes: emptyResponseCodes,
                                                   emptyRequestMethods: emptyRequestMethods),
                queue: queue)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishString(queue: DispatchQueue = .main,
                              preprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                              encoding: String.Encoding? = nil,
                              emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                              emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DataResponsePublisher<String> {
        publish(serializer: StringResponseSerializer(dataPreprocessor: preprocessor,
                                                     encoding: encoding,
                                                     emptyResponseCodes: emptyResponseCodes,
                                                     emptyRequestMethods: emptyRequestMethods),
                queue: queue)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func publishDecodable<T: Decodable>(type: T.Type = T.self,
                                               queue: DispatchQueue = .main,
                                               preprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                               decoder: DataDecoder = JSONDecoder(),
                                               emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                               emptyResponseMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods) -> DataResponsePublisher<T> {
        publish(serializer: DecodableResponseSerializer(dataPreprocessor: preprocessor,
                                                        decoder: decoder,
                                                        emptyResponseCodes: emptyResponseCodes,
                                                        emptyRequestMethods: emptyResponseMethods),
                queue: queue)
    }
}

#endif
