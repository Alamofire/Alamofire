//
//  Alamofire.swift
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

/// Global namespace containing API for the `default` `Session` instance.
public enum AF {
    // MARK: - Data Request

    /// Creates a `DataRequest` using `SessionManager.default` to retrive the contents of the specified `url`
    /// using the `method`, `parameters`, `encoding`, and `headers` provided.
    ///
    /// - Parameters:
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.get` by default.
    ///   - parameters:    The `Parameters`, `nil` by default.
    ///   - encoding:      The `ParameterEncoding`, `URLEncoding.default` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `DataRequest`.
    public static func request(_ url: URLConvertible,
                               method: HTTPMethod = .get,
                               parameters: Parameters? = nil,
                               encoding: ParameterEncoding = URLEncoding.default,
                               headers: HTTPHeaders? = nil,
                               interceptor: RequestInterceptor? = nil) -> DataRequest {
        return Session.default.request(url,
                                       method: method,
                                       parameters: parameters,
                                       encoding: encoding,
                                       headers: headers,
                                       interceptor: interceptor)
    }

    /// Creates a `DataRequest` using `SessionManager.default` to retrive the contents of the specified `url`
    /// using the `method`, `parameters`, `encoding`, and `headers` provided.
    ///
    /// - Parameters:
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.get` by default.
    ///   - parameters:    The `Encodable` parameters, `nil` by default.
    ///   - encoding:      The `ParameterEncoding`, `URLEncodedFormParameterEncoder.default` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `DataRequest`.
    public static func request<Parameters: Encodable>(_ url: URLConvertible,
                                                      method: HTTPMethod = .get,
                                                      parameters: Parameters? = nil,
                                                      encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                      headers: HTTPHeaders? = nil,
                                                      interceptor: RequestInterceptor? = nil) -> DataRequest {
        return Session.default.request(url,
                                       method: method,
                                       parameters: parameters,
                                       encoder: encoder,
                                       headers: headers,
                                       interceptor: interceptor)
    }

    /// Creates a `DataRequest` using `SessionManager.default` to execute the specified `urlRequest`.
    ///
    /// - Parameters:
    ///   - urlRequest:    The `URLRequestConvertible` value.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `DataRequest`.
    public static func request(_ urlRequest: URLRequestConvertible, interceptor: RequestInterceptor? = nil) -> DataRequest {
        return Session.default.request(urlRequest, interceptor: interceptor)
    }

    // MARK: - Download Request

    /// Creates a `DownloadRequest` using `SessionManager.default` to download the contents of the specified `url` to
    /// the provided `destination` using the `method`, `parameters`, `encoding`, and `headers` provided.
    ///
    /// If `destination` is not specified, the download will remain at the temporary location determined by the
    /// underlying `URLSession`.
    ///
    /// - Parameters:
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.get` by default.
    ///   - parameters:    The `Parameters`, `nil` by default.
    ///   - encoding:      The `ParameterEncoding`, `URLEncoding.default` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///   - destination:   The `DownloadRequest.Destination` closure used the determine the destination of the
    ///                    downloaded file. `nil` by default.
    ///
    /// - Returns: The created `DownloadRequest`.
    public static func download(_ url: URLConvertible,
                                method: HTTPMethod = .get,
                                parameters: Parameters? = nil,
                                encoding: ParameterEncoding = URLEncoding.default,
                                headers: HTTPHeaders? = nil,
                                interceptor: RequestInterceptor? = nil,
                                to destination: DownloadRequest.Destination? =  nil) -> DownloadRequest {
        return Session.default.download(url,
                                        method: method,
                                        parameters: parameters,
                                        encoding: encoding,
                                        headers: headers,
                                        interceptor: interceptor,
                                        to: destination)
    }

    /// Creates a `DownloadRequest` using `SessionManager.default` to download the contents of the specified `url` to
    /// the provided `destination` using the `method`, encodable `parameters`, `encoder`, and `headers` provided.
    ///
    /// If `destination` is not specified, the download will remain at the temporary location determined by the
    /// underlying `URLSession`.
    ///
    /// - Parameters:
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.get` by default.
    ///   - parameters:    The `Encodable` parameters, `nil` by default.
    ///   - encoder:       The `ParameterEncoder`, `URLEncodedFormParameterEncoder.default` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///   - destination:   The `DownloadRequest.Destination` closure used the determine the destination of the
    ///                    downloaded file. `nil` by default.
    ///
    /// - Returns: The created `DownloadRequest`.
    public static func download<Parameters: Encodable>(_ url: URLConvertible,
                                                       method: HTTPMethod = .get,
                                                       parameters: Parameters? = nil,
                                                       encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                       headers: HTTPHeaders? = nil,
                                                       interceptor: RequestInterceptor? = nil,
                                                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        return Session.default.download(url,
                                        method: method,
                                        parameters: parameters,
                                        encoder: encoder,
                                        headers: headers,
                                        interceptor: interceptor,
                                        to: destination)
    }

    // MARK: URLRequest

    /// Creates a `DownloadRequest` using `SessionManager.default` to execute the specified `urlRequest` and download
    /// the result to the provided `destination`.
    ///
    /// - Parameters:
    ///   - urlRequest:    The `URLRequestConvertible` value.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///   - destination:   The `DownloadRequest.Destination` closure used the determine the destination of the
    ///                    downloaded file. `nil` by default.
    ///
    /// - Returns: The created `DownloadRequest`.
    public static func download(_ urlRequest: URLRequestConvertible,
                                interceptor: RequestInterceptor? = nil,
                                to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        return Session.default.download(urlRequest, interceptor: interceptor, to: destination)
    }

    // MARK: Resume Data

    /// Creates a `DownloadRequest` using the `SessionManager.default` from the `resumeData` produced from a previous
    /// `DownloadRequest` cancellation to retrieve the contents of the original request and save them to the `destination`.
    ///
    /// If `destination` is not specified, the contents will remain in the temporary location determined by the
    /// underlying URL session.
    ///
    /// On some versions of all Apple platforms (iOS 10 - 10.2, macOS 10.12 - 10.12.2, tvOS 10 - 10.1, watchOS 3 - 3.1.1),
    /// `resumeData` is broken on background URL session configurations. There's an underlying bug in the `resumeData`
    /// generation logic where the data is written incorrectly and will always fail to resume the download. For more
    /// information about the bug and possible workarounds, please refer to the [this Stack Overflow post](http://stackoverflow.com/a/39347461/1342462).
    ///
    /// - Parameters:
    ///   - resumeData:    The resume `Data`. This is an opaque blob produced by `URLSessionDownloadTask` when a task is
    ///                    cancelled. See [Apple's documentation](https://developer.apple.com/documentation/foundation/urlsessiondownloadtask/1411634-cancel)
    ///                    for more information.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///   - destination:   The `DownloadRequest.Destination` closure used to determine the destination of the downloaded
    ///                    file. `nil` by default.
    ///
    /// - Returns: The created `DownloadRequest`.
    public static func download(resumingWith resumeData: Data,
                                interceptor: RequestInterceptor? = nil,
                                to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        return Session.default.download(resumingWith: resumeData, interceptor: interceptor, to: destination)
    }

    // MARK: - Upload Request

    // MARK: File

    /// Creates an `UploadRequest` using `SessionManager.default` to upload the contents of the `fileURL` specified
    /// using the `url`, `method` and `headers` provided.
    ///
    /// - Parameters:
    ///   - fileURL:       The `URL` of the file to upload.
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.post` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(_ fileURL: URL,
                              to url: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(fileURL, to: url, method: method, headers: headers, interceptor: interceptor)
    }

    /// Creates an `UploadRequest` using the `SessionManager.default` to upload the contents of the `fileURL` specificed
    /// using the `urlRequest` provided.
    ///
    /// - Parameters:
    ///   - fileURL:       The `URL` of the file to upload.
    ///   - urlRequest:    The `URLRequestConvertible` value.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(_ fileURL: URL,
                              with urlRequest: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(fileURL, with: urlRequest, interceptor: interceptor)
    }

    // MARK: Data

    /// Creates an `UploadRequest` using `SessionManager.default` to upload the contents of the `data` specified using
    /// the `url`, `method` and `headers` provided.
    ///
    /// - Parameters:
    ///   - data:          The `Data` to upload.
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.post` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///   - retryPolicies: The `RetryPolicy` types, `[]` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(_ data: Data,
                              to url: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(data, to: url, method: method, headers: headers, interceptor: interceptor)
    }

    /// Creates an `UploadRequest` using `SessionManager.default` to upload the contents of the `data` specified using
    /// the `urlRequest` provided.
    ///
    /// - Parameters:
    ///   - data:          The `Data` to upload.
    ///   - urlRequest:    The `URLRequestConvertible` value.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(_ data: Data,
                              with urlRequest: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(data, with: urlRequest, interceptor: interceptor)
    }

    // MARK: InputStream

    /// Creates an `UploadRequest` using `SessionManager.default` to upload the content provided by the `stream`
    /// specified using the `url`, `method` and `headers` provided.
    ///
    /// - Parameters:
    ///   - stream:        The `InputStream` to upload.
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.post` by default.
    ///   - headers:       The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(_ stream: InputStream,
                              to url: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(stream, to: url, method: method, headers: headers, interceptor: interceptor)
    }

    /// Creates an `UploadRequest` using `SessionManager.default` to upload the content provided by the `stream`
    /// specified using the `urlRequest` specified.
    ///
    /// - Parameters:
    ///   - stream:        The `InputStream` to upload.
    ///   - urlRequest:    The `URLRequestConvertible` value.
    ///   - interceptor:   The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(_ stream: InputStream,
                              with urlRequest: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(stream, with: urlRequest, interceptor: interceptor)
    }

    // MARK: MultipartFormData

    /// Encodes `multipartFormData` using `encodingMemoryThreshold` and uploads the result using `SessionManager.default`
    /// with the `url`, `method`, and `headers` provided.
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
    /// - Parameters:
    ///   - multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    ///   - encodingMemoryThreshold: The encoding memory threshold in bytes. `10_000_000` bytes by default.
    ///   - fileManager:             The `FileManager` instance to use to manage streaming and encoding.
    ///   - url:                     The `URLConvertible` value.
    ///   - method:                  The `HTTPMethod`, `.post` by default.
    ///   - headers:                 The `HTTPHeaders`, `nil` by default.
    ///   - interceptor:             The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The created `UploadRequest`.
    public static func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                              usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                              fileManager: FileManager = .default,
                              to url: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(multipartFormData: multipartFormData,
                                      usingThreshold: encodingMemoryThreshold,
                                      fileManager: fileManager,
                                      to: url,
                                      method: method,
                                      headers: headers,
                                      interceptor: interceptor)
    }

    /// Encodes `multipartFormData` using `encodingMemoryThreshold` and uploads the result using `SessionManager.default`
    /// using the `urlRequest` provided.
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
    /// - Parameters:
    ///   - multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    ///   - encodingMemoryThreshold: The encoding memory threshold in bytes. `10_000_000` bytes by default.
    ///   - urlRequest:              The `URLRequestConvertible` value.
    ///   - interceptor:             The `RequestInterceptor`, `nil` by default.
    ///
    /// - Returns: The `UploadRequest` created.
    @discardableResult
    public static func upload(multipartFormData: MultipartFormData,
                              usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                              with urlRequest: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return Session.default.upload(multipartFormData: multipartFormData,
                                      usingThreshold: encodingMemoryThreshold,
                                      with: urlRequest,
                                      interceptor: interceptor)
    }
}
