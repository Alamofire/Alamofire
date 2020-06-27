//
//  RetryPolicy.swift
//
//  Copyright (c) 2019-2020 Alamofire Software Foundation (http://alamofire.org/)
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
open class RetryPolicy: RequestInterceptor {
    /// The default retry limit for retry policies.
    public static let defaultRetryLimit: UInt = 2

    /// The default exponential backoff base for retry policies (must be a minimum of 2).
    public static let defaultExponentialBackoffBase: UInt = 2

    /// The default exponential backoff scale for retry policies.
    public static let defaultExponentialBackoffScale: Double = 0.5

    /// The default HTTP methods to retry.
    /// See [RFC 2616 - Section 9.1.2](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html) for more information.
    public static let defaultRetryableHTTPMethods: Set<HTTPMethod> = [.delete, // [Delete](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.7) - not always idempotent
                                                                      .get, // [GET](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.3) - generally idempotent
                                                                      .head, // [HEAD](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.4) - generally idempotent
                                                                      .options, // [OPTIONS](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.2) - inherently idempotent
                                                                      .put, // [PUT](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.6) - not always idempotent
                                                                      .trace // [TRACE](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.8) - inherently idempotent
    ]

    /// The default HTTP status codes to retry.
    /// See [RFC 2616 - Section 10](https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10) for more information.
    public static let defaultRetryableHTTPStatusCodes: Set<Int> = [408, // [Request Timeout](https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.4.9)
                                                                   500, // [Internal Server Error](https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.1)
                                                                   502, // [Bad Gateway](https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.3)
                                                                   503, // [Service Unavailable](https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.4)
                                                                   504 // [Gateway Timeout](https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.5.5)
    ]

    /// The default URL error codes to retry.
    public static let defaultRetryableURLErrorCodes: Set<URLError.Code> = [// [Security] App Transport Security disallowed a connection because there is no secure network connection.
        //   - [Disabled] ATS settings do not change at runtime.
        // .appTransportSecurityRequiresSecureConnection,

        // [System] An app or app extension attempted to connect to a background session that is already connected to a
        // process.
        //   - [Enabled] The other process could release the background session.
        .backgroundSessionInUseByAnotherProcess,
                                                                           
        // [System] The shared container identifier of the URL session configuration is needed but has not been set.
        //   - [Disabled] Cannot change at runtime.
        // .backgroundSessionRequiresSharedContainer,

        // [System] The app is suspended or exits while a background data task is processing.
        //   - [Enabled] App can be foregrounded or launched to recover.
        .backgroundSessionWasDisconnected,
                                                                           
        // [Network] The URL Loading system received bad data from the server.
        //   - [Enabled] Server could return valid data when retrying.
        .badServerResponse,
                                                                           
        // [Resource] A malformed URL prevented a URL request from being initiated.
        //   - [Disabled] URL was most likely constructed incorrectly.
        // .badURL,

        // [System] A connection was attempted while a phone call is active on a network that does not support
        // simultaneous phone and data communication (EDGE or GPRS).
        //   - [Enabled] Phone call could be ended to allow request to recover.
        .callIsActive,
                                                                           
        // [Client] An asynchronous load has been canceled.
        //   - [Disabled] Request was cancelled by the client.
        // .cancelled,

        // [File System] A download task couldn’t close the downloaded file on disk.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .cannotCloseFile,

        // [Network] An attempt to connect to a host failed.
        //   - [Enabled] Server or DNS lookup could recover during retry.
        .cannotConnectToHost,
                                                                           
        // [File System] A download task couldn’t create the downloaded file on disk because of an I/O failure.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .cannotCreateFile,

        // [Data] Content data received during a connection request had an unknown content encoding.
        //   - [Disabled] Server is unlikely to modify the content encoding during a retry.
        // .cannotDecodeContentData,

        // [Data] Content data received during a connection request could not be decoded for a known content encoding.
        //   - [Disabled] Server is unlikely to modify the content encoding during a retry.
        // .cannotDecodeRawData,

        // [Network] The host name for a URL could not be resolved.
        //   - [Enabled] Server or DNS lookup could recover during retry.
        .cannotFindHost,
                                                                           
        // [Network] A request to load an item only from the cache could not be satisfied.
        //   - [Enabled] Cache could be populated during a retry.
        .cannotLoadFromNetwork,
                                                                           
        // [File System] A download task was unable to move a downloaded file on disk.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .cannotMoveFile,

        // [File System] A download task was unable to open the downloaded file on disk.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .cannotOpenFile,

        // [Data] A task could not parse a response.
        //   - [Disabled] Invalid response is unlikely to recover with retry.
        // .cannotParseResponse,

        // [File System] A download task was unable to remove a downloaded file from disk.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .cannotRemoveFile,

        // [File System] A download task was unable to write to the downloaded file on disk.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .cannotWriteToFile,

        // [Security] A client certificate was rejected.
        //   - [Disabled] Client certificate is unlikely to change with retry.
        // .clientCertificateRejected,

        // [Security] A client certificate was required to authenticate an SSL connection during a request.
        //   - [Disabled] Client certificate is unlikely to be provided with retry.
        // .clientCertificateRequired,

        // [Data] The length of the resource data exceeds the maximum allowed.
        //   - [Disabled] Resource will likely still exceed the length maximum on retry.
        // .dataLengthExceedsMaximum,

        // [System] The cellular network disallowed a connection.
        //   - [Enabled] WiFi connection could be established during retry.
        .dataNotAllowed,
                                                                           
        // [Network] The host address could not be found via DNS lookup.
        //   - [Enabled] DNS lookup could succeed during retry.
        .dnsLookupFailed,
                                                                           
        // [Data] A download task failed to decode an encoded file during the download.
        //   - [Enabled] Server could correct the decoding issue with retry.
        .downloadDecodingFailedMidStream,
                                                                           
        // [Data] A download task failed to decode an encoded file after downloading.
        //   - [Enabled] Server could correct the decoding issue with retry.
        .downloadDecodingFailedToComplete,
                                                                           
        // [File System] A file does not exist.
        //   - [Disabled] File system error is unlikely to recover with retry.
        // .fileDoesNotExist,

        // [File System] A request for an FTP file resulted in the server responding that the file is not a plain file,
        // but a directory.
        //   - [Disabled] FTP directory is not likely to change to a file during a retry.
        // .fileIsDirectory,

        // [Network] A redirect loop has been detected or the threshold for number of allowable redirects has been
        // exceeded (currently 16).
        //   - [Disabled] The redirect loop is unlikely to be resolved within the retry window.
        // .httpTooManyRedirects,

        // [System] The attempted connection required activating a data context while roaming, but international roaming
        // is disabled.
        //   - [Enabled] WiFi connection could be established during retry.
        .internationalRoamingOff,
                                                                           
        // [Connectivity] A client or server connection was severed in the middle of an in-progress load.
        //   - [Enabled] A network connection could be established during retry.
        .networkConnectionLost,
                                                                           
        // [File System] A resource couldn’t be read because of insufficient permissions.
        //   - [Disabled] Permissions are unlikely to be granted during retry.
        // .noPermissionsToReadFile,

        // [Connectivity] A network resource was requested, but an internet connection has not been established and
        // cannot be established automatically.
        //   - [Enabled] A network connection could be established during retry.
        .notConnectedToInternet,
                                                                           
        // [Resource] A redirect was specified by way of server response code, but the server did not accompany this
        // code with a redirect URL.
        //   - [Disabled] The redirect URL is unlikely to be supplied during a retry.
        // .redirectToNonExistentLocation,

        // [Client] A body stream is needed but the client did not provide one.
        //   - [Disabled] The client will be unlikely to supply a body stream during retry.
        // .requestBodyStreamExhausted,

        // [Resource] A requested resource couldn’t be retrieved.
        //   - [Disabled] The resource is unlikely to become available during the retry window.
        // .resourceUnavailable,

        // [Security] An attempt to establish a secure connection failed for reasons that can’t be expressed more
        // specifically.
        //   - [Enabled] The secure connection could be established during a retry given the lack of specificity
        //     provided by the error.
        .secureConnectionFailed,
                                                                           
        // [Security] A server certificate had a date which indicates it has expired, or is not yet valid.
        //   - [Enabled] The server certificate could become valid within the retry window.
        .serverCertificateHasBadDate,
                                                                           
        // [Security] A server certificate was not signed by any root server.
        //   - [Disabled] The server certificate is unlikely to change during the retry window.
        // .serverCertificateHasUnknownRoot,

        // [Security] A server certificate is not yet valid.
        //   - [Enabled] The server certificate could become valid within the retry window.
        .serverCertificateNotYetValid,
                                                                           
        // [Security] A server certificate was signed by a root server that isn’t trusted.
        //   - [Disabled] The server certificate is unlikely to become trusted within the retry window.
        // .serverCertificateUntrusted,

        // [Network] An asynchronous operation timed out.
        //   - [Enabled] The request timed out for an unknown reason and should be retried.
        .timedOut

        // [System] The URL Loading System encountered an error that it can’t interpret.
        //   - [Disabled] The error could not be interpreted and is unlikely to be recovered from during a retry.
        // .unknown,

        // [Resource] A properly formed URL couldn’t be handled by the framework.
        //   - [Disabled] The URL is unlikely to change during a retry.
        // .unsupportedURL,

        // [Client] Authentication is required to access a resource.
        //   - [Disabled] The user authentication is unlikely to be provided by retrying.
        // .userAuthenticationRequired,

        // [Client] An asynchronous request for authentication has been canceled by the user.
        //   - [Disabled] The user cancelled authentication and explicitly took action to not retry.
        // .userCancelledAuthentication,

        // [Resource] A server reported that a URL has a non-zero content length, but terminated the network connection
        // gracefully without sending any data.
        //   - [Disabled] The server is unlikely to provide data during the retry window.
        // .zeroByteResource,
    ]

    /// The total number of times the request is allowed to be retried.
    public let retryLimit: UInt

    /// The base of the exponential backoff policy (should always be greater than or equal to 2).
    public let exponentialBackoffBase: UInt

    /// The scale of the exponential backoff.
    public let exponentialBackoffScale: Double

    /// The HTTP methods that are allowed to be retried.
    public let retryableHTTPMethods: Set<HTTPMethod>

    /// The HTTP status codes that are automatically retried by the policy.
    public let retryableHTTPStatusCodes: Set<Int>

    /// The URL error codes that are automatically retried by the policy.
    public let retryableURLErrorCodes: Set<URLError.Code>

    /// Creates an `ExponentialBackoffRetryPolicy` from the specified parameters.
    ///
    /// - Parameters:
    ///   - retryLimit:               The total number of times the request is allowed to be retried. `2` by default.
    ///   - exponentialBackoffBase:   The base of the exponential backoff policy. `2` by default.
    ///   - exponentialBackoffScale:  The scale of the exponential backoff. `0.5` by default.
    ///   - retryableHTTPMethods:     The HTTP methods that are allowed to be retried.
    ///                               `RetryPolicy.defaultRetryableHTTPMethods` by default.
    ///   - retryableHTTPStatusCodes: The HTTP status codes that are automatically retried by the policy.
    ///                               `RetryPolicy.defaultRetryableHTTPStatusCodes` by default.
    ///   - retryableURLErrorCodes:   The URL error codes that are automatically retried by the policy.
    ///                               `RetryPolicy.defaultRetryableURLErrorCodes` by default.
    public init(retryLimit: UInt = RetryPolicy.defaultRetryLimit,
                exponentialBackoffBase: UInt = RetryPolicy.defaultExponentialBackoffBase,
                exponentialBackoffScale: Double = RetryPolicy.defaultExponentialBackoffScale,
                retryableHTTPMethods: Set<HTTPMethod> = RetryPolicy.defaultRetryableHTTPMethods,
                retryableHTTPStatusCodes: Set<Int> = RetryPolicy.defaultRetryableHTTPStatusCodes,
                retryableURLErrorCodes: Set<URLError.Code> = RetryPolicy.defaultRetryableURLErrorCodes) {
        precondition(exponentialBackoffBase >= 2, "The `exponentialBackoffBase` must be a minimum of 2.")

        self.retryLimit = retryLimit
        self.exponentialBackoffBase = exponentialBackoffBase
        self.exponentialBackoffScale = exponentialBackoffScale
        self.retryableHTTPMethods = retryableHTTPMethods
        self.retryableHTTPStatusCodes = retryableHTTPStatusCodes
        self.retryableURLErrorCodes = retryableURLErrorCodes
    }

    open func retry(_ request: Request,
                    for session: Session,
                    dueTo error: Error,
                    completion: @escaping (RetryResult) -> Void) {
        if request.retryCount < retryLimit, shouldRetry(request: request, dueTo: error) {
            completion(.retryWithDelay(pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale))
        } else {
            completion(.doNotRetry)
        }
    }

    /// Determines whether or not to retry the provided `Request`.
    ///
    /// - Parameters:
    ///     - request: `Request` that failed due to the provided `Error`.
    ///     - error:   `Error` encountered while executing the `Request`.
    ///
    /// - Returns:     `Bool` determining whether or not to retry the `Request`.
    open func shouldRetry(request: Request, dueTo error: Error) -> Bool {
        guard let httpMethod = request.request?.method, retryableHTTPMethods.contains(httpMethod) else { return false }

        if let statusCode = request.response?.statusCode, retryableHTTPStatusCodes.contains(statusCode) {
            return true
        } else {
            let errorCode = (error as? URLError)?.code
            let afErrorCode = (error.asAFError?.underlyingError as? URLError)?.code

            guard let code = errorCode ?? afErrorCode else { return false }

            return retryableURLErrorCodes.contains(code)
        }
    }
}

// MARK: -

/// A retry policy that automatically retries idempotent requests for network connection lost errors. For more
/// information about retrying network connection lost errors, please refer to Apple's
/// [technical document](https://developer.apple.com/library/content/qa/qa1941/_index.html).
open class ConnectionLostRetryPolicy: RetryPolicy {
    /// Creates a `ConnectionLostRetryPolicy` instance from the specified parameters.
    ///
    /// - Parameters:
    ///   - retryLimit:              The total number of times the request is allowed to be retried.
    ///                              `RetryPolicy.defaultRetryLimit` by default.
    ///   - exponentialBackoffBase:  The base of the exponential backoff policy.
    ///                              `RetryPolicy.defaultExponentialBackoffBase` by default.
    ///   - exponentialBackoffScale: The scale of the exponential backoff.
    ///                              `RetryPolicy.defaultExponentialBackoffScale` by default.
    ///   - retryableHTTPMethods:    The idempotent http methods to retry.
    ///                              `RetryPolicy.defaultRetryableHTTPMethods` by default.
    public init(retryLimit: UInt = RetryPolicy.defaultRetryLimit,
                exponentialBackoffBase: UInt = RetryPolicy.defaultExponentialBackoffBase,
                exponentialBackoffScale: Double = RetryPolicy.defaultExponentialBackoffScale,
                retryableHTTPMethods: Set<HTTPMethod> = RetryPolicy.defaultRetryableHTTPMethods) {
        super.init(retryLimit: retryLimit,
                   exponentialBackoffBase: exponentialBackoffBase,
                   exponentialBackoffScale: exponentialBackoffScale,
                   retryableHTTPMethods: retryableHTTPMethods,
                   retryableHTTPStatusCodes: [],
                   retryableURLErrorCodes: [.networkConnectionLost])
    }
}
