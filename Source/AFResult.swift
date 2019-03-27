//
//  AFResult.swift
//
//  Copyright (c) 2014-2019 Alamofire Software Foundation (http://alamofire.org/)
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

public typealias AFResult<T> = Result<T, Error>

// MARK: - CustomStringConvertible

extension AFResult: CustomStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        switch self {
        case .success:
            return "SUCCESS"
        case .failure:
            return "FAILURE"
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension AFResult: CustomDebugStringConvertible {
    /// The debug textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure in addition to the value or error.
    public var debugDescription: String {
        switch self {
        case .success(let value):
            return "SUCCESS: \(value)"
        case .failure(let error):
            return "FAILURE: \(error)"
        }
    }
}

// MARK: - Functional APIs

extension AFResult {
    /// Initializes an `AFResult` from value or error. Returns `.failure` if the error is non-nil, `.success` otherwise.
    ///
    /// - Parameters:
    ///   - value: A value.
    ///   - error: An `Error`.
    init(value: Success, error: Failure?) {
        if let error = error {
            self = .failure(error)
        } else {
            self = .success(value)
        }
    }

    /// Returns `true` if the result is a success, `false` otherwise.
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    /// Returns `true` if the result is a failure, `false` otherwise.
    var isFailure: Bool {
        return !isSuccess
    }

    /// Returns the success value, or throws the failure error.
    ///
    ///     let possibleString: AFResult<String> = .success("success")
    ///     try print(possibleString.unwrap())
    ///     // Prints "success"
    ///
    ///     let noString: AFResult<String> = .failure(error)
    ///     try print(noString.unwrap())
    ///     // Throws error
    func unwrap() throws -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    /// Evaluates the specified closure when the `AFResult` is a success, passing the unwrapped value as a parameter.
    ///
    /// Use the `flatMap` method with a closure that may throw an error. For example:
    ///
    ///     let possibleData: AFResult<Data> = .success(Data(...))
    ///     let possibleObject = possibleData.flatMap {
    ///         try JSONSerialization.jsonObject(with: $0)
    ///     }
    ///
    /// - parameter transform: A closure that takes the success value of the instance.
    ///
    /// - returns: An `AFResult` containing the result of the given closure. If this instance is a failure, returns the
    ///            same failure.
    func flatMap<T>(_ transform: (Success) throws -> T) -> AFResult<T> {
        switch self {
        case .success(let value):
            do {
                return try .success(transform(value))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Evaluates the specified closure when the `AFResult` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `flatMapError` function with a closure that may throw an error. For example:
    ///
    ///     let possibleData: AFResult<Data> = .success(Data(...))
    ///     let possibleObject = possibleData.flatMapError {
    ///         try someFailableFunction(taking: $0)
    ///     }
    ///
    /// - Parameter transform: A throwing closure that takes the error of the instance.
    ///
    /// - Returns: An `AFResult` instance containing the result of the transform. If this instance is a success, returns
    ///            the same success.
    func flatMapError<T: Error>(_ transform: (Failure) throws -> T) -> AFResult<Success> {
        switch self {
        case .failure(let error):
            do {
                return try .failure(transform(error))
            } catch {
                return .failure(error)
            }
        case .success(let value):
            return .success(value)
        }
    }

    /// Evaluates the specified closure when the `AFResult` is a success, passing the unwrapped value as a parameter.
    ///
    /// Use the `withValue` function to evaluate the passed closure.
    ///
    /// - Parameter closure: A closure that takes the success value of this instance.
    /// - Returns: An `AFResult` instance, unmodified.
    @discardableResult
    func withValue(_ closure: (Success) throws -> Void) rethrows -> AFResult<Success> {
        switch self {
        case .success(let value):
            try closure(value)
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Evaluates the specified closure when the `AFResult` is a failure, passing the unwrapped error as a parameter.
    ///
    /// Use the `withError` function to evaluate the passed closure.
    ///
    /// - Parameter closure: A closure that takes the success value of this instance.
    /// - Returns: An `AFResult` instance, unmodified.
    @discardableResult
    func withError(_ closure: (Failure) throws -> Void) rethrows -> AFResult<Success> {
        switch self {
        case .failure(let error):
            try closure(error)
            return .failure(error)
        case .success(let value):
            return .success(value)
        }
    }

    /// Evaluates the specified closure when the `AFResult` is a success.
    ///
    /// Use the `ifSuccess` function to evaluate the passed closure without modifying the `AFResult` instance.
    ///
    /// - Parameter closure: A `Void` closure.
    /// - Returns: This `AFResult` instance, unmodified.
    @discardableResult
    func ifSuccess(_ closure: () throws -> Void) rethrows -> AFResult<Success> {
        switch self {
        case .success(let value):
            try closure()
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Evaluates the specified closure when the `AFResult` is a failure.
    ///
    /// Use the `ifFailure` function to evaluate the passed closure without modifying the `AFResult` instance.
    ///
    /// - Parameter closure: A `Void` closure.
    /// - Returns: This `AFResult` instance, unmodified.
    @discardableResult
    func ifFailure(_ closure: () throws -> Void) rethrows -> AFResult<Success> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            try closure()
            return .failure(error)
        }
    }

    /// Returns the associated value if the result is a success, `nil` otherwise.
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    /// Returns the associated error value if the result is a failure, `nil` otherwise.
    var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
