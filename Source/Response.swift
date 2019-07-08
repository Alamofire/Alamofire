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

/// Used to store all data associated with a serialized response of a data or upload request.
public struct FailingDataResponse<Success, Failure: Error> {
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
    public var value: Success? { return result.value }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Failure? { return result.error }

    /// Creates a `DataResponse` instance with the specified parameters derviced from the response serialization.
    ///
    /// - Parameters:
    ///   - request:               The `URLRequest` sent to the server.
    ///   - response:              The `HTTPURLResponse` from the server.
    ///   - data:                  The `Data` returned by the server.
    ///   - metrics:               The `URLSessionTaskMetrics` of the serialized response.
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

extension FailingDataResponse: CustomStringConvertible, CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        return "\(result)"
    }

    /// The debug textual representation used when written to an output stream, which includes the URL request, the URL
    /// response, the server data, the duration of the network and serializatino actions, and the response serialization
    /// result.
    public var debugDescription: String {
        let requestDescription = request.map { "\($0.httpMethod!) \($0)" } ?? "nil"
        let requestBody = request?.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? "None"
        let responseDescription = response.map { (response) in
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

extension FailingDataResponse {
    /// Evaluates the specified closure when the result of this `DataResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `map` method with a closure that returns a value. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleInt = possibleData.map { $0.count }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A `DataResponse` whose result wraps the value returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> FailingDataResponse<NewSuccess, Failure> {
        return
            FailingDataResponse<NewSuccess, Failure>(
                request: request,
                response: self.response,
                data: data,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.map(transform)
            )
    }

    /// Evaluates the specified closure when the result of this `DataResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `flatMap` method with a closure that returns a `Result`. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleLength = possibleData.flatMap { data in data.isEmpty ? .failure(CustomError.dataEmpty) : .success(data.count) }
    ///     let possibleObject = possibleData.flatMap { data in .init { try CustomObject(data) } }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result and returns a new `Result`.
    ///
    /// - returns: A `DataResponse` whose result is returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func flatMap<NewSuccess>(_ transform: (Success) -> Result<NewSuccess, Failure>) -> FailingDataResponse<NewSuccess, Failure> {
        return
            FailingDataResponse<NewSuccess, Failure>(
                request: request,
                response: self.response,
                data: data,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.flatMap(transform)
            )
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that returns an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> FailingDataResponse<Success, NewFailure> {
        return
            FailingDataResponse<Success, NewFailure>(
                request: request,
                response: self.response,
                data: data,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.mapError(transform)
            )
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `flatMapError` function with a closure that returns a `Result`. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let withDefaultData = possibleData.flatMapError { _ in .success(defaultData) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - returns: A `DataResponse` whose result is returned by the given closure. If this instance's
    ///            result is a success value, returns a response wrapping the same success value.
    public func flatMapError<NewFailure: Error>(_ transform: (Failure) -> Result<Success, NewFailure>) -> FailingDataResponse<Success, NewFailure> {
        return
            FailingDataResponse<Success, NewFailure>(
                request: request,
                response: self.response,
                data: data,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.flatMapError(transform)
            )
    }
}

public typealias DataResponse<Success> = FailingDataResponse<Success, Error>

// MARK: -

/// Used to store all data associated with a serialized response of a download request.
public struct FailingDownloadResponse<Success, Failure: Error> {
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
    public var value: Success? { return result.value }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Failure? { return result.error }

    /// Creates a `DownloadResponse` instance with the specified parameters derived from response serialization.
    ///
    /// - Parameters:
    ///   - request:               The `URLRequest` sent to the server.
    ///   - response:              The `HTTPURLResponse` from the server.
    ///   - temporaryURL:          The temporary destinatio `URL` of the data returned from the server.
    ///   - destinationURL:        The final destination `URL` of the data returned from the server, if it was moved.
    ///   - resumeData:            The resume `Data` generated if the request was cancelled.
    ///   - metrics:               The `URLSessionTaskMetrics` of the serialized response.
    ///   - serializationDuration: The duration taken by serialization.
    ///   - result:                The `Result` of response serialization.
    public init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        fileURL: URL?,
        resumeData: Data?,
        metrics: URLSessionTaskMetrics?,
        serializationDuration: TimeInterval,
        result: Result<Success, Failure>)
    {
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

extension FailingDownloadResponse: CustomStringConvertible, CustomDebugStringConvertible {
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
        let responseDescription = response.map { (response) in
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

extension FailingDownloadResponse {
    /// Evaluates the specified closure when the result of this `DownloadResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `map` method with a closure that returns a value. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleInt = possibleData.map { $0.count }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A `DownloadResponse` whose result wraps the value returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> FailingDownloadResponse<NewSuccess, Failure> {
        return
            FailingDownloadResponse<NewSuccess, Failure>(
                request: request,
                response: response,
                fileURL: fileURL,
                resumeData: resumeData,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.map(transform)
            )
    }

    /// Evaluates the specified closure when the result of this `DownloadResponse` is a success, passing the unwrapped
    /// result value as a parameter.
    ///
    /// Use the `flatMap` method with a closure that returns a `Result`. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let possibleLength = possibleData.flatMap { data in data.isEmpty ? .failure(CustomError.dataEmpty) : .success(data.count) }
    ///     let possibleObject = possibleData.flatMap { data in .init { try CustomObject(data) } }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result and returns a new `Result`.
    ///
    /// - returns: A `DownloadResponse` whose result is returned by the given closure. If this instance's
    ///            result is a failure, returns a response wrapping the same failure.
    public func flatMap<NewSuccess>(_ transform: (Success) -> Result<NewSuccess, Failure>) -> FailingDownloadResponse<NewSuccess, Failure> {
        return
            FailingDownloadResponse<NewSuccess, Failure>(
                request: request,
                response: response,
                fileURL: fileURL,
                resumeData: resumeData,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.flatMap(transform)
            )
    }

    /// Evaluates the specified closure when the `DownloadResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that returns an error. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - Returns: A `DownloadResponse` instance containing the result of the transform.
    public func mapError<NewFailure: Error>(_ transform: (Failure) -> NewFailure) -> FailingDownloadResponse<Success, NewFailure> {
        return
            FailingDownloadResponse<Success, NewFailure>(
                request: request,
                response: response,
                fileURL: fileURL,
                resumeData: resumeData,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.mapError(transform)
            )
    }

    /// Evaluates the specified closure when the `DownloadResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `flatMapError` function with a closure that returns a `Result`. For example:
    ///
    ///     let possibleData: DownloadResponse<Data> = ...
    ///     let withDefaultData = possibleData.flatMapError { _ in .success(defaultData) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    ///
    /// - returns: A `DownloadResponse` whose result is returned by the given closure. If this instance's
    ///            result is a success value, returns a response wrapping the same success value.
    public func flatMapError<NewFailure: Error>(_ transform: (Failure) -> Result<Success, NewFailure>) -> FailingDownloadResponse<Success, NewFailure> {
        return
            FailingDownloadResponse<Success, NewFailure>(
                request: request,
                response: response,
                fileURL: fileURL,
                resumeData: resumeData,
                metrics: metrics,
                serializationDuration: serializationDuration,
                result: result.flatMapError(transform)
            )
    }
}

public typealias DownloadResponse<Success> = FailingDownloadResponse<Success, Error>
