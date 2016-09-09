//
//  Alamofire.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

/// Types adopting the `URLStringConvertible` protocol can be used to construct URL strings, which are then used to
/// construct URL requests.
public protocol URLStringConvertible {
    /// A URL that conforms to RFC 2396.
    ///
    /// Methods accepting a `URLStringConvertible` type parameter parse it according to RFCs 1738 and 1808.
    ///
    /// See https://tools.ietf.org/html/rfc2396
    /// See https://tools.ietf.org/html/rfc1738
    /// See https://tools.ietf.org/html/rfc1808
    var urlString: String { get }
}

extension String: URLStringConvertible {
    /// The URL string.
    public var urlString: String { return self }
}

extension URL: URLStringConvertible {
    /// The URL string.
    public var urlString: String { return absoluteString }
}

extension URLComponents: URLStringConvertible {
    /// The URL string.
    public var urlString: String { return url!.urlString }
}

// MARK: -

/// Types adopting the `URLRequestConvertible` protocol can be used to construct URL requests.
public protocol URLRequestConvertible {
    /// The URL request.
    var urlRequest: URLRequest { get }
}

extension URLRequest: URLRequestConvertible {
    /// The URL request.
    public var urlRequest: URLRequest { return self }
}

// MARK: -

extension URLRequest {
    /// Creates an instance with the specified `method`, `urlString` and `headers`.
    ///
    /// - parameter urlString: The URL string.
    /// - parameter method:    The HTTP method.
    /// - parameter headers:   The HTTP headers. `nil` by default.
    ///
    /// - returns: The new `URLRequest` instance.
    public init(urlString: URLStringConvertible, method: HTTPMethod, headers: [String: String]? = nil) {
        self.init(url: URL(string: urlString.urlString)!)

        if let request = urlString as? URLRequest { self = request }

        httpMethod = method.rawValue

        if let headers = headers {
            for (headerField, headerValue) in headers {
                setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
    }

    func adapt(using adapter: RequestAdapter?) -> URLRequest {
        guard let adapter = adapter else { return self }
        return adapter.adapt(self)
    }
}

// MARK: - Data Request

/// Creates a `DataRequest` using the default `SessionManager` to retrieve the contents of a URL based on the
/// specified `urlString`, `method`, `parameters`, `encoding` and `headers`.
///
/// - parameter urlString:  The URL string.
/// - parameter method:     The HTTP method. `.get` by default.
/// - parameter parameters: The parameters. `nil` by default.
/// - parameter encoding:   The parameter encoding. `URLEncoding.default` by default.
/// - parameter headers:    The HTTP headers. `nil` by default.
///
/// - returns: The created `DataRequest`.
@discardableResult
public func request(
    _ urlString: URLStringConvertible,
    method: HTTPMethod = .get,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.default,
    headers: [String: String]? = nil)
    -> DataRequest
{
    return SessionManager.default.request(
        urlString,
        method: method,
        parameters: parameters,
        encoding: encoding,
        headers: headers
    )
}

/// Creates a `DataRequest` using the default `SessionManager` to retrieve the contents of a URL based on the
/// specified `urlRequest`.
///
/// - parameter urlRequest: The URL request
///
/// - returns: The created `DataRequest`.
@discardableResult
public func request(resource urlRequest: URLRequestConvertible) -> DataRequest {
    return SessionManager.default.request(resource: urlRequest)
}

// MARK: - Download Request

// MARK: URL Request

/// Creates a `DownloadRequest` using the default `SessionManager` to retrieve the contents of a URL based on the
/// specified `urlString`, `method`, `parameters`, `encoding`, `headers` and save them to the `destination`.
///
/// If `destination` is not specified, the contents will remain in the temporary location determined by the
/// underlying URL session.
///
/// - parameter urlString:   The URL string.
/// - parameter method:      The HTTP method. `.get` by default.
/// - parameter parameters:  The parameters. `nil` by default.
/// - parameter encoding:    The parameter encoding. `URLEncoding.default` by default.
/// - parameter headers:     The HTTP headers. `nil` by default.
/// - parameter destination: The closure used to determine the destination of the downloaded file. `nil` by default.
///
/// - returns: The created `DownloadRequest`.
@discardableResult
public func download(
    _ urlString: URLStringConvertible,
    method: HTTPMethod = .get,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.default,
    headers: [String: String]? = nil,
    to destination: DownloadRequest.DownloadFileDestination? = nil)
    -> DownloadRequest
{
    return SessionManager.default.download(
        urlString,
        method: method,
        parameters: parameters,
        encoding: encoding,
        headers: headers,
        to: destination
    )
}

/// Creates a `DownloadRequest` using the default `SessionManager` to retrieve the contents of a URL based on the
/// specified `urlRequest` and save them to the `destination`.
///
/// If `destination` is not specified, the contents will remain in the temporary location determined by the
/// underlying URL session.
///
/// - parameter urlRequest:  The URL request.
/// - parameter destination: The closure used to determine the destination of the downloaded file. `nil` by default.
///
/// - returns: The created `DownloadRequest`.
@discardableResult
public func download(
    resource urlRequest: URLRequestConvertible,
    to destination: DownloadRequest.DownloadFileDestination? = nil)
    -> DownloadRequest
{
    return SessionManager.default.download(resource: urlRequest, to: destination)
}

// MARK: Resume Data

/// Creates a `DownloadRequest` using the default `SessionManager` from the `resumeData` produced from a
/// previous request cancellation to retrieve the contents of the original request and save them to the `destination`.
///
/// If `destination` is not specified, the contents will remain in the temporary location determined by the
/// underlying URL session.
///
/// - parameter resumeData:  The resume data. This is an opaque data blob produced by `URLSessionDownloadTask`
///                          when a task is cancelled. See `URLSession -downloadTask(withResumeData:)` for additional
///                          information.
/// - parameter destination: The closure used to determine the destination of the downloaded file. `nil` by default.
///
/// - returns: The created `DownloadRequest`.
@discardableResult
public func download(
    resourceWithin resumeData: Data,
    to destination: DownloadRequest.DownloadFileDestination? = nil)
    -> DownloadRequest
{
    return SessionManager.default.download(resourceWithin: resumeData, to: destination)
}

// MARK: - Upload Request

// MARK: File

/// Creates an `UploadRequest` using the default `SessionManager` from the specified `method`, `urlString`
/// and `headers` for uploading the `file`.
///
/// - parameter file:      The file to upload.
/// - parameter urlString: The URL string.
/// - parameter method:    The HTTP method. `.post` by default.
/// - parameter headers:   The HTTP headers. `nil` by default.
///
/// - returns: The created `UploadRequest`.
@discardableResult
public func upload(
    _ fileURL: URL,
    to urlString: URLStringConvertible,
    method: HTTPMethod = .post,
    headers: [String: String]? = nil)
    -> UploadRequest
{
    return SessionManager.default.upload(fileURL, to: urlString, method: method, headers: headers)
}

/// Creates a `UploadRequest` using the default `SessionManager` from the specified `urlRequest` for
/// uploading the `file`.
///
/// - parameter file:       The file to upload.
/// - parameter urlRequest: The URL request.
///
/// - returns: The created `UploadRequest`.
@discardableResult
public func upload(_ fileURL: URL, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(fileURL, with: urlRequest)
}

// MARK: Data

/// Creates an `UploadRequest` using the default `SessionManager` from the specified `method`, `urlString`
/// and `headers` for uploading the `data`.
///
/// - parameter data:      The data to upload.
/// - parameter urlString: The URL string.
/// - parameter method:    The HTTP method. `.post` by default.
/// - parameter headers:   The HTTP headers. `nil` by default.
///
/// - returns: The created `UploadRequest`.
@discardableResult
public func upload(
    _ data: Data,
    to urlString: URLStringConvertible,
    method: HTTPMethod = .post,
    headers: [String: String]? = nil)
    -> UploadRequest
{
    return SessionManager.default.upload(data, to: urlString, method: method, headers: headers)
}

/// Creates an `UploadRequest` using the default `SessionManager` from the specified `urlRequest` for
/// uploading the `data`.
///
/// - parameter data:       The data to upload.
/// - parameter urlRequest: The URL request.
///
/// - returns: The created `UploadRequest`.
@discardableResult
public func upload(_ data: Data, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(data, with: urlRequest)
}

// MARK: InputStream

/// Creates an `UploadRequest` using the default `SessionManager` from the specified `method`, `urlString`
/// and `headers` for uploading the `stream`.
///
/// - parameter stream:    The stream to upload.
/// - parameter urlString: The URL string.
/// - parameter method:    The HTTP method. `.post` by default.
/// - parameter headers:   The HTTP headers. `nil` by default.
///
/// - returns: The created `UploadRequest`.
@discardableResult
public func upload(
    _ stream: InputStream,
    to urlString: URLStringConvertible,
    method: HTTPMethod = .post,
    headers: [String: String]? = nil)
    -> UploadRequest
{
    return SessionManager.default.upload(stream, to: urlString, method: method, headers: headers)
}

/// Creates an `UploadRequest` using the default `SessionManager` from the specified `urlRequest` for
/// uploading the `stream`.
///
/// - parameter urlRequest: The URL request.
/// - parameter stream:     The stream to upload.
///
/// - returns: The created `UploadRequest`.
@discardableResult
public func upload(_ stream: InputStream, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(stream, with: urlRequest)
}

// MARK: MultipartFormData

/// Encodes `multipartFormData` using `encodingMemoryThreshold` with the default `SessionManager` and calls
/// `encodingCompletion` with new `UploadRequest` using the `method`, `urlString` and `headers`.
///
/// It is important to understand the memory implications of uploading `MultipartFormData`. If the cummulative
/// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
/// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
/// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
/// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
/// used for larger payloads such as video content.
///
/// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
/// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
/// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
/// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
/// technique was used.
///
/// - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
/// - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
///                                      `multipartFormDataEncodingMemoryThreshold` by default.
/// - parameter urlString:               The URL string.
/// - parameter method:                  The HTTP method. `.post` by default.
/// - parameter headers:                 The HTTP headers. `nil` by default.
/// - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
public func upload(
    multipartFormData: @escaping (MultipartFormData) -> Void,
    usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
    to urlString: URLStringConvertible,
    method: HTTPMethod = .post,
    headers: [String: String]? = nil,
    encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?)
{
    return SessionManager.default.upload(
        multipartFormData: multipartFormData,
        usingThreshold: encodingMemoryThreshold,
        to: urlString,
        method: method,
        headers: headers,
        encodingCompletion: encodingCompletion
    )
}

/// Encodes `multipartFormData` using `encodingMemoryThreshold` and the default `SessionManager` and
/// calls `encodingCompletion` with new `UploadRequest` using the `urlRequest`.
///
/// It is important to understand the memory implications of uploading `MultipartFormData`. If the cummulative
/// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
/// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
/// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
/// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
/// used for larger payloads such as video content.
///
/// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
/// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
/// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
/// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
/// technique was used.
///
/// - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
/// - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
///                                      `multipartFormDataEncodingMemoryThreshold` by default.
/// - parameter urlRequest:              The URL request.
/// - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
public func upload(
    multipartFormData: @escaping (MultipartFormData) -> Void,
    usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
    with urlRequest: URLRequestConvertible,
    encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?)
{
    return SessionManager.default.upload(
        multipartFormData: multipartFormData,
        usingThreshold: encodingMemoryThreshold,
        with: urlRequest,
        encodingCompletion: encodingCompletion
    )
}

#if !os(watchOS)

// MARK: - Stream Request

// MARK: Hostname and Port

/// Creates a `StreamRequest` using the default `SessionManager` for bidirectional streaming with the `hostname`
/// and `port`.
///
/// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
///
/// - parameter hostName: The hostname of the server to connect to.
/// - parameter port:     The port of the server to connect to.
///
/// - returns: The created `StreamRequest`.
@discardableResult
public func stream(withHostName hostName: String, port: Int) -> StreamRequest {
    return SessionManager.default.stream(withHostName: hostName, port: port)
}

// MARK: NetService

/// Creates a `StreamRequest` using the default `SessionManager` for bidirectional streaming with the `netService`.
///
/// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
///
/// - parameter netService: The net service used to identify the endpoint.
///
/// - returns: The created `StreamRequest`.
@discardableResult
public func stream(with netService: NetService) -> StreamRequest {
    return SessionManager.default.stream(with: netService)
}

#endif
