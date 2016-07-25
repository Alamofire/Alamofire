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

// MARK: - URLStringConvertible

/**
    Types adopting the `URLStringConvertible` protocol can be used to construct URL strings, which are then used to
    construct URL requests.
*/
public protocol URLStringConvertible {
    /**
        A URL that conforms to RFC 2396.

        Methods accepting a `URLStringConvertible` type parameter parse it according to RFCs 1738 and 1808.

        See https://tools.ietf.org/html/rfc2396
        See https://tools.ietf.org/html/rfc1738
        See https://tools.ietf.org/html/rfc1808
    */
    var urlString: String { get }
}

extension String: URLStringConvertible {
    public var urlString: String { return self }
}

extension URL: URLStringConvertible {
    public var urlString: String { return absoluteString! }
}

extension URLComponents: URLStringConvertible {
    public var urlString: String { return url!.urlString }
}

extension Foundation.URLRequest: URLStringConvertible {
    public var urlString: String { return url!.urlString }
}

// MARK: - URLRequestConvertible

/**
    Types adopting the `URLRequestConvertible` protocol can be used to construct URL requests.
*/
public protocol URLRequestConvertible {
    /// The URL request.
    var urlRequest: URLRequest { get }
}

extension URLRequest: URLRequestConvertible {
    public var urlRequest: URLRequest { return self }
}

// MARK: - Convenience

extension URLRequest {
    init(_ method: Method, _ urlString: URLStringConvertible, headers: [String:String]? = nil) {
        self.init(url: URL(string: urlString.urlString)!)

        if let request = urlString as? URLRequest { self = request }

        self.httpMethod = method.rawValue

        if let headers = headers {
            for (headerField, headerValue) in headers {
                setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
    }
}

// MARK: - Request Methods

/**
    Creates a request using the shared manager instance for the specified method, URL string, parameters, and
    parameter encoding.

    - parameter method:     The HTTP method.
    - parameter URLString:  The URL string.
    - parameter parameters: The parameters. `nil` by default.
    - parameter encoding:   The parameter encoding. `.URL` by default.
    - parameter headers:    The HTTP headers. `nil` by default.

    - returns: The created request.
*/
public func request(
    _ method: Method,
    _ URLString: URLStringConvertible,
    parameters: [String: AnyObject]? = nil,
    encoding: ParameterEncoding = .url,
    headers: [String: String]? = nil)
    -> Request
{
    return Manager.sharedInstance.request(
        method,
        URLString,
        parameters: parameters,
        encoding: encoding,
        headers: headers
    )
}

/**
    Creates a request using the shared manager instance for the specified URL request.

    If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

    - parameter URLRequest: The URL request

    - returns: The created request.
*/
public func request(_ urlRequest: URLRequestConvertible) -> Request {
    return Manager.sharedInstance.request(urlRequest.urlRequest)
}

// MARK: - Upload Methods

// MARK: File

/**
    Creates an upload request using the shared manager instance for the specified method, URL string, and file.

    - parameter method:    The HTTP method.
    - parameter URLString: The URL string.
    - parameter headers:   The HTTP headers. `nil` by default.
    - parameter file:      The file to upload.

    - returns: The created upload request.
*/
public func upload(
    _ method: Method,
    _ URLString: URLStringConvertible,
    headers: [String: String]? = nil,
    file: URL)
    -> Request
{
    return Manager.sharedInstance.upload(method, URLString, headers: headers, file: file)
}

/**
    Creates an upload request using the shared manager instance for the specified URL request and file.

    - parameter URLRequest: The URL request.
    - parameter file:       The file to upload.

    - returns: The created upload request.
*/
public func upload(_ URLRequest: URLRequestConvertible, file: URL) -> Request {
    return Manager.sharedInstance.upload(URLRequest, file: file)
}

// MARK: Data

/**
    Creates an upload request using the shared manager instance for the specified method, URL string, and data.

    - parameter method:    The HTTP method.
    - parameter URLString: The URL string.
    - parameter headers:   The HTTP headers. `nil` by default.
    - parameter data:      The data to upload.

    - returns: The created upload request.
*/
public func upload(
    _ method: Method,
    _ URLString: URLStringConvertible,
    headers: [String: String]? = nil,
    data: Data)
    -> Request
{
    return Manager.sharedInstance.upload(method, URLString, headers: headers, data: data)
}

/**
    Creates an upload request using the shared manager instance for the specified URL request and data.

    - parameter URLRequest: The URL request.
    - parameter data:       The data to upload.

    - returns: The created upload request.
*/
public func upload(_ URLRequest: URLRequestConvertible, data: Data) -> Request {
    return Manager.sharedInstance.upload(URLRequest, data: data)
}

// MARK: Stream

/**
    Creates an upload request using the shared manager instance for the specified method, URL string, and stream.

    - parameter method:    The HTTP method.
    - parameter URLString: The URL string.
    - parameter headers:   The HTTP headers. `nil` by default.
    - parameter stream:    The stream to upload.

    - returns: The created upload request.
*/
public func upload(
    _ method: Method,
    _ URLString: URLStringConvertible,
    headers: [String: String]? = nil,
    stream: InputStream)
    -> Request
{
    return Manager.sharedInstance.upload(method, URLString, headers: headers, stream: stream)
}

/**
    Creates an upload request using the shared manager instance for the specified URL request and stream.

    - parameter URLRequest: The URL request.
    - parameter stream:     The stream to upload.

    - returns: The created upload request.
*/
public func upload(_ URLRequest: URLRequestConvertible, stream: InputStream) -> Request {
    return Manager.sharedInstance.upload(urlRequest: URLRequest, stream: stream)
}

// MARK: MultipartFormData

/**
    Creates an upload request using the shared manager instance for the specified method and URL string.

    - parameter method:                  The HTTP method.
    - parameter URLString:               The URL string.
    - parameter headers:                 The HTTP headers. `nil` by default.
    - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
                                         `MultipartFormDataEncodingMemoryThreshold` by default.
    - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
*/
public func upload(
    _ method: Method,
    _ URLString: URLStringConvertible,
    headers: [String: String]? = nil,
    multipartFormData: (MultipartFormData) -> Void,
    encodingMemoryThreshold: UInt64 = Manager.MultipartFormDataEncodingMemoryThreshold,
    encodingCompletion: ((Manager.MultipartFormDataEncodingResult) -> Void)?)
{
    return Manager.sharedInstance.upload(
        method,
        URLString,
        headers: headers,
        multipartFormData: multipartFormData,
        encodingMemoryThreshold: encodingMemoryThreshold,
        encodingCompletion: encodingCompletion
    )
}

/**
    Creates an upload request using the shared manager instance for the specified method and URL string.

    - parameter URLRequest:              The URL request.
    - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
                                         `MultipartFormDataEncodingMemoryThreshold` by default.
    - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
*/
public func upload(
    _ URLRequest: URLRequestConvertible,
    multipartFormData: (MultipartFormData) -> Void,
    encodingMemoryThreshold: UInt64 = Manager.MultipartFormDataEncodingMemoryThreshold,
    encodingCompletion: ((Manager.MultipartFormDataEncodingResult) -> Void)?)
{
    return Manager.sharedInstance.upload(
        URLRequest,
        multipartFormData: multipartFormData,
        encodingMemoryThreshold: encodingMemoryThreshold,
        encodingCompletion: encodingCompletion
    )
}

// MARK: - Download Methods

// MARK: URL Request

/**
    Creates a download request using the shared manager instance for the specified method and URL string.

    - parameter method:      The HTTP method.
    - parameter URLString:   The URL string.
    - parameter parameters:  The parameters. `nil` by default.
    - parameter encoding:    The parameter encoding. `.URL` by default.
    - parameter headers:     The HTTP headers. `nil` by default.
    - parameter destination: The closure used to determine the destination of the downloaded file.

    - returns: The created download request.
*/
public func download(
    _ method: Method,
    _ URLString: URLStringConvertible,
    parameters: [String: AnyObject]? = nil,
    encoding: ParameterEncoding = .url,
    headers: [String: String]? = nil,
    destination: Request.DownloadFileDestination)
    -> Request
{
    return Manager.sharedInstance.download(
        method,
        URLString,
        parameters: parameters,
        encoding: encoding,
        headers: headers,
        destination: destination
    )
}

/**
    Creates a download request using the shared manager instance for the specified URL request.

    - parameter URLRequest:  The URL request.
    - parameter destination: The closure used to determine the destination of the downloaded file.

    - returns: The created download request.
*/
public func download(_ URLRequest: URLRequestConvertible, destination: Request.DownloadFileDestination) -> Request {
    return Manager.sharedInstance.download(URLRequest, destination: destination)
}

// MARK: Resume Data

/**
    Creates a request using the shared manager instance for downloading from the resume data produced from a
    previous request cancellation.

    - parameter resumeData:  The resume data. This is an opaque data blob produced by `NSURLSessionDownloadTask`
                             when a task is cancelled. See `NSURLSession -downloadTaskWithResumeData:` for additional
                             information.
    - parameter destination: The closure used to determine the destination of the downloaded file.

    - returns: The created download request.
*/
public func download(resumeData data: Data, destination: Request.DownloadFileDestination) -> Request {
    return Manager.sharedInstance.download(data, destination: destination)
}
