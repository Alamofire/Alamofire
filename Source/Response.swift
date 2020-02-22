//
//  Response.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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

import Foundation

/// Default type of `DataResponse` returned by Alamofire, with an `AFError` `Failure` type.
public typealias AFDataResponse<Success> = DataResponse<Success, AFError>
/// Default type of `DownloadResponse` returned by Alamofire, with an `AFError` `Failure` type.
public typealias AFDownloadResponse<Success> = DownloadResponse<Success, AFError>

/// Type used to store all values associated with a serialized response of a `DataRequest` or `UploadRequest`.
public struct DataResponse<Success, Failure: Error> {
    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The data returned by the server.
    public let data: Data?

    /// The final metrics of the response.
    public let metrics: URLSessionTaskMetrics?

    /// The time taken to serialize the response.
    public let serializationDuration: TimeInterval

    /// The result of response serialization.
    public let result: Result<Success, Failure>

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Success? { return result.success }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Failure? { return result.failure }

    /// Creates a `DataResponse` instance with the specified parameters derived from the response serialization.
    ///
    /// - Parameters:
    ///   - request:               The `URLRequest` sent to the server.
    ///   - response:              The `HTTPURLResponse` from the server.
    ///   - data:                  The `Data` returned by the server.
    ///   - metrics:               The `URLSessionTaskMetrics` of the `DataRequest` or `UploadRequest`.
    ///   - serializationDuration: The duration taken by serialization.
    ///   - result:                The `Result` of response serialization.
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                data: Data?,
                metrics: URLSessionTaskMetrics?,
                serializationDuration: TimeInterval,
                result: Result<Success, Failure>) {
        self.request = request
        self.response = response
        self.data = data
        self.metrics = metrics
        self.serializationDuration = serializationDuration
        self.result = result
    }
}

// MARK: -

extension DataResponse: CustomStringConvertible, CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        return "\(result)"
    }

    /// The debug textual representation used when written to an output stream, which includes the URL request, the URL
    /// response, the server data, the duration of the network and serialization actions, and the response serialization
    /// result.
    public var debugDescription: String {
        let requestDescription = request.map { "\($0.httpMethod!) \($0)" } ?? "nil"
        let requestBody = request?.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? "None"
        let responseDescription = response.map { response in
            let sortedHeaders = response.headers.sorted()

            return """
            [Status Code]: \(response.statusCode)
            [Headers]:
            \(sortedHeaders)
            """
        } ?? "nil"
        let responseBody = data.map { String(decoding: $0, as: UTF8.self) } ?? "None"
        let metricsDescription = metrics.map { "\($0.taskInterval.duration)s" } ?? "None"

        return """
        [Request]: \(requestDescription)
        [Request Body]: \n\(requestBody)
        [Response]: \n\(responseDescription)
        [Response Body]: \n\(responseBody)
        [Data]: \(data?.description ?? "None")
        [Network Duration]: \(metricsDescription)
        [Serialization Duration]: \(serializationDuration)s
        [Result]: \(result)
        """
    }
}

// MARK: -

extension DataResponse {
    /// Evaluates the specified closure when the result of this `DataResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `map` method with a closure that does not throw. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleInt = possibleData.map { $0.count }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A `DataResponse` whose result wraps the value returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> DataResponse<NewSuccess, Failure> {
        return DataResponse<NewSuccess, Failure>(request: request,
                                                 response: response,
                                                 data: data,
                                                 metrics: metrics,
                                                 serializationDuration: serializationDuration,
                                                 result: result.map(transform))
    }

    /// Evaluates the given closure when the result of this `DataResponse` is a success, passing the unwrapped result
    /// value as a parameter.
    ///
    /// Use the `tryMap` method with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMap {
    ///         try JSONSerialization.jsonObject(with: $0)
    ///     }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A success or failure `DataResponse` depending on the result of the given closure. If this instance's
    ///            result is a failure, returns the same failure.
    public func tryMap<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> DataResponse<NewSuccess, Error> {
        return DataResponse<NewSuccess, Error>(request: request,
                                               response: response,
                                               data: data,
                                               metrics: metrics,
                                               serializationDuration: serializationDuration,
                                               result: result.tryMap(transform))
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that does not throw. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> DataResponse<Success, NewFailure> {
        return DataResponse<Success, NewFailure>(request: request,
                                                 response: response,
                                                 data: data,
                                                 metrics: metrics,
                                                 serializationDuration: serializationDuration,
                                                 result: result.mapError(transform))
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `tryMapError` function with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMapError {
    ///         try someFailableFunction(taking: $0)
    ///     }
    ///
    /// - Parameter transform: A throwing closure that takes the error of the instance.
    ///
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func tryMapError<NewFailure: Error>(_ transform: (Failure) throws -> NewFailure) -> DataResponse<Success, Error> {
        return DataResponse<Success, Error>(request: request,
                                            response: response,
                                            data: data,
                                            metrics: metrics,
                                            serializationDuration: serializationDuration,
                                            result: result.tryMapError(transform))
    }
}

// MARK: -

/// Used to store all data associated with a serialized response of a download request.
public struct DownloadResponse<Success, Failure: Error> {
    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The final destination URL of the data returned from the server after it is moved.
    public let fileURL: URL?

    /// The resume data generated if the request was cancelled.
    public let resumeData: Data?

    /// The final metrics of the response.
    public let metrics: URLSessionTaskMetrics?

    /// The time taken to serialize the response.
    public let serializationDuration: TimeInterval

    /// The result of response serialization.
    public let result: Result<Success, Failure>

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Success? { return result.success }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Failure? { return result.failure }

    /// Creates a `DownloadResponse` instance with the specified parameters derived from response serialization.
    ///
    /// - Parameters:
    ///   - request:               The `URLRequest` sent to the server.
    ///   - response:              The `HTTPURLResponse` from the server.
    ///   - temporaryURL:          The temporary destination `URL` of the data returned from the server.
    ///   - destinationURL:        The final destination `URL` of the data returned from the server, if it was moved.
    ///   - resumeData:            The resume `Data` generated if the request was cancelled.
    ///   - metrics:               The `URLSessionTaskMetrics` of the `DownloadRequest`.
    ///   - serializationDuration: The duration taken by serialization.
    ///   - result:                The `Result` of response serialization.
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                fileURL: URL?,
                resumeData: Data?,
                metrics: URLSessionTaskMetrics?,
                serializationDuration: TimeInterval,
                result: Result<Success, Failure>) {
        self.request = request
        self.response = response
        self.fileURL = fileURL
        self.resumeData = resumeData
        self.metrics = metrics
        self.serializationDuration = serializationDuration
        self.result = result
    }
}

// MARK: -

extension DownloadResponse: CustomStringConvertible, CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        return "\(result)"
    }

    /// The debug textual representation used when written to an output stream, which includes the URL request, the URL
    /// response, the temporary and destination URLs, the resume data, the durations of the network and serialization
    /// actions, and the response serialization result.
    public var debugDescription: String {
        let requestDescription = request.map { "\($0.httpMethod!) \($0)" } ?? "nil"
        let requestBody = request?.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? "None"
        let responseDescription = response.map { response in
            let sortedHeaders = response.headers.sorted()

            return """
            [Status Code]: \(response.statusCode)
            [Headers]:
            \(sortedHeaders)
            """
        } ?? "nil"
        let metricsDescription = metrics.map { "\($0.taskInterval.duration)s" } ?? "None"
        let resumeDataDescription = resumeData.map { "\($0)" } ?? "None"

        return """
        [Request]: \(requestDescription)
        [Request Body]: \n\(requestBody)
        [Response]: \n\(responseDescription)
        [File URL]: \(fileURL?.path ?? "nil")
        [ResumeData]: \(resumeDataDescription)
        [Network Duration]: \(metricsDescription)
        [Serialization Duration]: \(serializationDuration)s
        [Result]: \(result)
        """
    }
}

// MARK: -

extension DownloadResponse {
    /// Evaluates the given closure when the result of this `DownloadResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `map` method with a closure that does not throw. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleInt = possibleData.map { $0.count }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A `DownloadResponse` whose result wraps the value returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> DownloadResponse<NewSuccess, Failure> {
        return DownloadResponse<NewSuccess, Failure>(request: request,
                                                     response: response,
                                                     fileURL: fileURL,
                                                     resumeData: resumeData,
                                                     metrics: metrics,
                                                     serializationDuration: serializationDuration,
                                                     result: result.map(transform))
    }

    /// Evaluates the given closure when the result of this `DownloadResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `tryMap` method with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMap {
    ///         try JSONSerialization.jsonObject(with: $0)
    ///     }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A success or failure `DownloadResponse` depending on the result of the given closure. If this
    /// instance's result is a failure, returns the same failure.
    public func tryMap<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> DownloadResponse<NewSuccess, Error> {
        return DownloadResponse<NewSuccess, Error>(request: request,
                                                   response: response,
                                                   fileURL: fileURL,
                                                   resumeData: resumeData,
                                                   metrics: metrics,
                                                   serializationDuration: serializationDuration,
                                                   result: result.tryMap(transform))
    }

    /// Evaluates the specified closure when the `DownloadResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that does not throw. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - Returns: A `DownloadResponse` instance containing the result of the transform.
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> DownloadResponse<Success, NewFailure> {
        return DownloadResponse<Success, NewFailure>(request: request,
                                                     response: response,
                                                     fileURL: fileURL,
                                                     resumeData: resumeData,
                                                     metrics: metrics,
                                                     serializationDuration: serializationDuration,
                                                     result: result.mapError(transform))
    }

    /// Evaluates the specified closure when the `DownloadResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `tryMapError` function with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleObject = possibleData.tryMapError {
    ///         try someFailableFunction(taking: $0)
    ///     }
    ///
    /// - Parameter transform: A throwing closure that takes the error of the instance.
    ///
    /// - Returns: A `DownloadResponse` instance containing the result of the transform.
    public func tryMapError<NewFailure: Error>(_ transform: (Failure) throws -> NewFailure) -> DownloadResponse<Success, Error> {
        return DownloadResponse<Success, Error>(request: request,
                                                response: response,
                                                fileURL: fileURL,
                                                resumeData: resumeData,
                                                metrics: metrics,
                                                serializationDuration: serializationDuration,
                                                result: result.tryMapError(transform))
    }
}
