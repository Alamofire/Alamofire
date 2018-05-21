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
public struct DataResponse<Value> {
    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The data returned by the server.
    public let data: Data?

    /// The result of response serialization.
    public let result: Result<Value>

    /// The final metrics of a response.
    public let metrics: URLSessionTaskMetrics?

    /// The timeline of the complete lifecycle of the request.
//    public let timeline: Timeline

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Value? { return result.value }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Error? { return result.error }

    /// Creates a `DataResponse` instance with the specified parameters derived from response serialization.
    ///
    /// - parameter request:  The URL request sent to the server.
    /// - parameter response: The server's response to the URL request.
    /// - parameter data:     The data returned by the server.
    /// - parameter result:   The result of response serialization.
    /// - parameter timeline: The timeline of the complete lifecycle of the `Request`. Defaults to `Timeline()`.
    ///
    /// - returns: The new `DataResponse` instance.
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                data: Data?,
                metrics: URLSessionTaskMetrics?,
                result: Result<Value>) {
        self.request = request
        self.response = response
        self.data = data
        self.metrics = metrics
        self.result = result
    }
}

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
    public func map<T>(_ transform: (Value) -> T) -> DataResponse<T> {
        return DataResponse<T>(request: request,
                               response: self.response,
                               data: data,
                               metrics: metrics,
                               result: result.map(transform))
    }

    /// Evaluates the given closure when the result of this `DataResponse` is a success, passing the unwrapped result
    /// value as a parameter.
    ///
    /// Use the `flatMap` method with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleObject = possibleData.flatMap {
    ///         try JSONSerialization.jsonObject(with: $0)
    ///     }
    ///
    /// - parameter transform: A closure that takes the success value of the instance's result.
    ///
    /// - returns: A success or failure `DataResponse` depending on the result of the given closure. If this instance's
    ///            result is a failure, returns the same failure.
    public func flatMap<T>(_ transform: (Value) throws -> T) -> DataResponse<T> {
        return DataResponse<T>(request: request,
                               response: self.response,
                               data: data,
                               metrics: metrics,
                               result: result.flatMap(transform))
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `mapError` function with a closure that does not throw. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let withMyError = possibleData.mapError { MyError.error($0) }
    ///
    /// - Parameter transform: A closure that takes the error of the instance.
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func mapError<E: Error>(_ transform: (Error) -> E) -> DataResponse {
        return DataResponse(request: request,
                            response: self.response,
                            data: data,
                            metrics: metrics,
                            result: result.mapError(transform))
    }

    /// Evaluates the specified closure when the `DataResponse` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `flatMapError` function with a closure that may throw an error. For example:
    ///
    ///     let possibleData: DataResponse<Data> = ...
    ///     let possibleObject = possibleData.flatMapError {
    ///         try someFailableFunction(taking: $0)
    ///     }
    ///
    /// - Parameter transform: A throwing closure that takes the error of the instance.
    ///
    /// - Returns: A `DataResponse` instance containing the result of the transform.
    public func flatMapError<E: Error>(_ transform: (Error) throws -> E) -> DataResponse {
        return DataResponse(request: request,
                            response: self.response,
                            data: data,
                            metrics: metrics,
                            result: result.flatMapError(transform))
    }
}

// MARK: -

/// Used to store all data associated with a serialized response of a download request.
public struct DownloadResponse<Value> {
    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The temporary destination URL of the data returned from the server.
    public let temporaryURL: URL?

    /// The final destination URL of the data returned from the server if it was moved.
    public let destinationURL: URL?

    /// The resume data generated if the request was cancelled.
    public let resumeData: Data?

    /// The result of response serialization.
    public let result: Result<Value>

    /// The timeline of the complete lifecycle of the request.
//    public let timeline: Timeline

    public let metrics: URLSessionTaskMetrics?

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Value? { return result.value }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Error? { return result.error }

//    var _metrics: AnyObject?

    /// Creates a `DownloadResponse` instance with the specified parameters derived from response serialization.
    ///
    /// - parameter request:        The URL request sent to the server.
    /// - parameter response:       The server's response to the URL request.
    /// - parameter temporaryURL:   The temporary destination URL of the data returned from the server.
    /// - parameter destinationURL: The final destination URL of the data returned from the server if it was moved.
    /// - parameter resumeData:     The resume data generated if the request was cancelled.
    /// - parameter result:         The result of response serialization.
    /// - parameter timeline:       The timeline of the complete lifecycle of the `Request`. Defaults to `Timeline()`.
    ///
    /// - returns: The new `DownloadResponse` instance.
    public init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        temporaryURL: URL?,
        destinationURL: URL?,
        resumeData: Data?,
        metrics: URLSessionTaskMetrics?,
        result: Result<Value>)
    {
        self.request = request
        self.response = response
        self.temporaryURL = temporaryURL
        self.destinationURL = destinationURL
        self.resumeData = resumeData
        self.metrics = metrics
        self.result = result

//        self.timeline = timeline
    }
}
