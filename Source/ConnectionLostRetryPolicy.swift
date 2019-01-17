//
//  ConnectionLostRetryPolicy.swift
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

/// A retry policy that automatically retries idempotent requests for network connection lost errors. For more
/// information about retrying network connection lost errors, please refer to Apple's
/// [technical document](https://developer.apple.com/library/content/qa/qa1941/_index.html).
public struct ConnectionLostRetryPolicy: RetryPolicy {

    // MARK: - Properties

    /// The total number of times the request is allowed to be retried.
    public let retryLimit: UInt

    /// The base of the exponential backoff policy (should always be greater than or equal to 2).
    public let exponentialBackoffBase: UInt

    /// The scale of the exponential backoff.
    public let exponentialBackoffScale: Double

    /// The idempotent http methods to retry.
    /// See [RFC 2616 - Section 9.1.2](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html) for more information.
    public let idempotentMethods: Set<HTTPMethod>

    // MARK: - Initialization

    /// Creates a `ConnectionLostRetryPolicy` instance from the specified parameters.
    ///
    /// - Parameters:
    ///   - retryLimit:              The total number of times the request is allowed to be retried. `2` by default.
    ///   - exponentialBackoffBase:  The base of the exponential backoff policy. `2` by default.
    ///   - exponentialBackoffScale: The scale of the exponential backoff. `0.25` by default.
    ///   - idempotentMethods:       The idempotent http methods to retry. `[.get, .head, .options, .trace]` by default.
    public init(
        retryLimit: UInt = 2,
        exponentialBackoffBase: UInt = 2,
        exponentialBackoffScale: Double = 0.25,
        idempotentMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options, .trace])
    {
        self.retryLimit = retryLimit
        self.exponentialBackoffBase = exponentialBackoffBase
        self.exponentialBackoffScale = exponentialBackoffScale
        self.idempotentMethods = idempotentMethods
    }

    // MARK: - Retry

    /// Returns whether the request should be retried with a time delay in seconds.
    ///
    /// - Parameters:
    ///   - request: The request to potentially retry.
    ///   - error:   The error encountered when executing the request.
    ///
    /// - Returns: `true` with a time delay if request should be retried, `false` and an ignored time delay otherwise.
    public func shouldRetry(_ request: Request, with error: Error) -> (shouldRetry: Bool, timeDelay: TimeInterval) {
        guard
            request.retryCount < retryLimit,
            isErrorConnectionLostError(error),
            let urlRequest = request.request,
            isRequestIdempotent(urlRequest)
        else { return (false, 0) }

        // Compute time delay for the exponential backoff (0.5s, 1.0s, 2.0s, 4.0s, ...)
        let timeDelay = pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale

        return (true, timeDelay)
    }

    // MARK: - Private - Helper Methods

    private func isRequestIdempotent(_ urlRequest: URLRequest) -> Bool {
        guard
            let stringMethod = urlRequest.httpMethod,
            let httpMethod = HTTPMethod(rawValue: stringMethod)
        else { return false }

        return idempotentMethods.contains(httpMethod)
    }

    private func isErrorConnectionLostError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return urlError.code == .networkConnectionLost
    }
}
