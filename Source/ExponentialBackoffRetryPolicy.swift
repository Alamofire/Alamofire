//
//  ExponentialBackoffRetryPolicy.swift
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

/// A retry policy that retries requests using an exponential backoff for allowed HTTP methods and HTTP status codes
/// as well as certain types of networking errors.
public struct ExponentialBackoffRetryPolicy: RetryPolicy {

    // MARK: - Properties

    /// The total number of times the request is allowed to be retried.
    public let retryLimit: UInt

    /// The base of the exponential backoff policy (should always be greater than or equal to 2).
    public let exponentialBackoffBase: UInt

    /// The scale of the exponential backoff.
    public let exponentialBackoffScale: Double

    /// The HTTP methods that are allowed to be retried.
    public let retryableHTTPMethods: Set<HTTPMethod>

    /// The HTTP status codes that are automatically retried by the policy.
    public let retryableStatusCodes: Set<Int>

    // MARK: - Initialization

    /// Creates an `ExponentialBackoffRetryPolicy` from the specified parameters.
    ///
    /// - Parameters:
    ///   - retryLimit:              The total number of times the request is allowed to be retried. `2` by default.
    ///   - exponentialBackoffBase:  The base of the exponential backoff policy. `2` by default.
    ///   - exponentialBackoffScale: The scale of the exponential backoff. `0.5` by default.
    ///   - retryableHTTPMethods:    The HTTP methods that are allowed to be retried.
    ///                              `[.get, .head, .options, .trace]` by default.
    ///   - retryableStatusCodes:    The HTTP status codes that are automatically retried by the policy.
    ///                              `[408, 500, 502, 503, 504]` by default.
    public init(
        retryLimit: UInt = 2,
        exponentialBackoffBase: UInt = 2,
        exponentialBackoffScale: Double = 0.5,
        retryableHTTPMethods: Set<HTTPMethod> = [.get, .head, .put, .delete, .options, .trace],
        retryableStatusCodes: Set<Int> = [408, 500, 502, 503, 504])
    {
        self.retryLimit = retryLimit
        self.exponentialBackoffBase = exponentialBackoffBase
        self.exponentialBackoffScale = exponentialBackoffScale
        self.retryableHTTPMethods = retryableHTTPMethods
        self.retryableStatusCodes = retryableStatusCodes
    }

    // MARK: - Retry

    /// Returns whether the request should be retried with a time delay in seconds.
    ///
    /// - Parameters:
    ///   - request: The request to potentially retry.
    ///   - error:   The error encountered when executing the request.
    ///
    /// - Returns: `true` with a time delay if request should be retried, `false` and an ignored time delay otherwise.
    public func shouldRetry(
        _ request: Alamofire.Request,
        with error: Error)
        -> (shouldRetry: Bool, timeDelay: TimeInterval)
    {
        // Make sure the retry limit has not been met
        guard request.retryCount < retryLimit else { return (false, 0) }

        // Only retry requests with retryable HTTP methods
        if
            let httpMethodString = request.request?.httpMethod,
            let httpMethod = HTTPMethod(rawValue: httpMethodString),
            !retryableHTTPMethods.contains(httpMethod)
        {
            return (false, 0)
        }

        // Inspect the HTTP status code and error to see if the request should be retried
        guard isRetryable(request.response, with: error) else { return (false, 0) }

        // Compute time delay for the exponential backoff (0.5s, 1.0s, 2.0s, 4.0s, ...)
        let timeDelay = pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale

        return (true, timeDelay)
    }

    // MARK: - Private - Retry Helpers

    private func isRetryable(_ response: HTTPURLResponse?, with error: Error) -> Bool {
        if let statusCode = response?.statusCode, retryableStatusCodes.contains(statusCode) {
            // Check if the response status code is retriable
            return true
        } else if let urlError = error as? URLError {
            return isRetryable(urlError)
        }

        return false
    }

    private func isRetryable(_ urlError: URLError) -> Bool {
        switch urlError.code {
        case
            //.appTransportSecurityRequiresSecureConnection,
            .backgroundSessionInUseByAnotherProcess,
            //.backgroundSessionRequiresSharedContainer,
            .backgroundSessionWasDisconnected,
            .badServerResponse,
            //.badURL,
            .callIsActive,
            //.cancelled,
            //.cannotCloseFile,
            .cannotConnectToHost,
            //.cannotCreateFile,
            //.cannotDecodeContentData,
            //.cannotDecodeRawData,
            .cannotFindHost,
            .cannotLoadFromNetwork,
            //.cannotMoveFile,
            //.cannotOpenFile,
            //.cannotParseResponse,
            //.cannotRemoveFile,
            //.cannotWriteToFile,
            //.clientCertificateRejected,
            //.clientCertificateRequired,
            //.dataLengthExceedsMaximum,
            .dataNotAllowed, // Refers to cellular data
            .dnsLookupFailed,
            .downloadDecodingFailedMidStream,
            .downloadDecodingFailedToComplete,
            //.fileDoesNotExist,
            //.fileIsDirectory,
            //.httpTooManyRedirects,
            .internationalRoamingOff,
            .networkConnectionLost,
            //.noPermissionsToReadFile,
            .notConnectedToInternet,
            //.redirectToNonExistentLocation,
            //.requestBodyStreamExhausted,
            //.resourceUnavailable,
            .secureConnectionFailed,
            .serverCertificateHasBadDate,
            //.serverCertificateHasUnknownRoot,
            .serverCertificateNotYetValid,
            //.serverCertificateUntrusted,
            .timedOut:
            //.unknown,
            //.unsupportedURL,
            //.userAuthenticationRequired,
            //.userCancelledAuthentication,
            //.zeroByteResource,

            return true

        default:
            return false
        }
    }
}
