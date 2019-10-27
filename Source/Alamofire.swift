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
    /// Current Alamofire version. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
    static let version = "5.0.0-rc.3"

    // MARK: - Data Request

    /// Creates a `DataRequest` using `Session.default` to retrieve the contents of the specified `url` using the
    /// `method`, `parameters`, `encoding`, and `headers` provided.
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

    /// Creates a `DataRequest` using `Session.default` to retrieve the contents of the specified `url` using the
    /// `method`, `parameters`, `encoding`, and `headers` provided.
    ///
    /// - Parameters:
    ///   - url:           The `URLConvertible` value.
    ///   - method:        The `HTTPMethod`, `.get` by default.
    ///   - parameters:    The `Encodable` parameters, `nil` by default.
    ///   - encoding:      The `ParameterEncoder`, `URLEncodedFormParameterEncoder.default` by default.
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

    /// Creates a `DataRequest` using `Session.default` to execute the specified `urlRequest`.
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

    /// Creates a `DownloadRequest` using `Session.default` to download the contents of the specified `url` to
    /// the provided `destination` using the `method`, `parameters`, `encoding`, and `headers` provided.
    ///
    /// If `destination` is not specified, the download will be moved to a temporary location determined by Alamofire.
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
                                to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        return Session.default.download(url,
                                        method: method,
                                        parameters: parameters,
                                        encoding: encoding,
                                        headers: headers,
                                        interceptor: interceptor,
                                        to: destination)
    }

    /// Creates a `DownloadRequest` using `Session.default` to download the contents of the specified `url` to the
    /// provided `destination` using the `method`, encodable `parameters`, `encoder`, and `headers` provided.
    ///
    /// - Note: If `destination` is not specified, the download will be moved to a temporary location determined by
    ///         Alamofire.
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

    /// Creates a `DownloadRequest` using `Session.default` to execute the specified `urlRequest` and download
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

    /// Creates a `DownloadRequest` using the `Session.default` from the `resumeData` produced from a previous
    /// `DownloadRequest` cancellation to retrieve the contents of the original request and save them to the `destination`.
    ///
    /// - Note: If `destination` is not specified, the download will be moved to a temporary location determined by
    ///         Alamofire.
    ///
    /// - Note: On some versions of all Apple platforms (iOS 10 - 10.2, macOS 10.12 - 10.12.2, tvOS 10 - 10.1, watchOS 3 - 3.1.1),
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
    /// - Returns:         The created `DownloadRequest`.
    public static func download(resumingWith resumeData: Data,
                                interceptor: RequestInterceptor? = nil,
                                to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        return Session.default.download(resumingWith: resumeData, interceptor: interceptor, to: destination)
    }

    // MARK: - Upload Request

    // MARK: Data

    /// Creates an `UploadRequest` for the given `Data`, `URLRequest` components, and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - data:        The `Data` to upload.
    ///   - convertible: `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:      `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:     `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    public static func upload(_ data: Data,
                              to convertible: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(data,
                                      to: convertible,
                                      method: method,
                                      headers: headers,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the given `Data` using the `URLRequestConvertible` value and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - data:        The `Data` to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    public static func upload(_ data: Data,
                              with convertible: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(data, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: File

    /// Creates an `UploadRequest` for the file at the given file `URL`, using a `URLRequest` from the provided
    /// components and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - fileURL:     The `URL` of the file to upload.
    ///   - convertible: `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:      `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:     `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `UploadRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    public static func upload(_ fileURL: URL,
                              to convertible: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(fileURL,
                                      to: convertible,
                                      method: method,
                                      headers: headers,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the file at the given file `URL` using the `URLRequestConvertible` value and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - fileURL:     The `URL` of the file to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    public static func upload(_ fileURL: URL,
                              with convertible: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(fileURL, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: InputStream

    /// Creates an `UploadRequest` from the `InputStream` provided using a `URLRequest` from the provided components and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - stream:      The `InputStream` that provides the data to upload.
    ///   - convertible: `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:      `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:     `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    public static func upload(_ stream: InputStream,
                              to convertible: URLConvertible,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(stream,
                                      to: convertible,
                                      method: method,
                                      headers: headers,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` from the provided `InputStream` using the `URLRequestConvertible` value and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - stream:      The `InputStream` that provides the data to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    public static func upload(_ stream: InputStream,
                              with convertible: URLRequestConvertible,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(stream, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }

    // MARK: MultipartFormData

    /// Creates an `UploadRequest` for the multipart form data built using a closure and sent using the provided
    /// `URLRequest` components and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
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
    ///   - multipartFormData:       `MultipartFormData` building closure.
    ///   - convertible:             `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    public static func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                              to url: URLConvertible,
                              usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(multipartFormData: multipartFormData,
                                      to: url,
                                      usingThreshold: encodingMemoryThreshold,
                                      method: method,
                                      headers: headers,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` using a `MultipartFormData` building closure, the provided `URLRequestConvertible`
    /// value, and a `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
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
    ///   - multipartFormData:       `MultipartFormData` building closure.
    ///   - request:                 `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    public static func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                              with request: URLRequestConvertible,
                              usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(multipartFormData: multipartFormData,
                                      with: request,
                                      usingThreshold: encodingMemoryThreshold,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the prebuilt `MultipartFormData` value using the provided `URLRequest` components
    /// and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
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
    ///   - multipartFormData:       `MultipartFormData` instance to upload.
    ///   - url:                     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    public static func upload(multipartFormData: MultipartFormData,
                              to url: URLConvertible,
                              usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                              method: HTTPMethod = .post,
                              headers: HTTPHeaders? = nil,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(multipartFormData: multipartFormData,
                                      to: url,
                                      usingThreshold: encodingMemoryThreshold,
                                      method: method,
                                      headers: headers,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }

    /// Creates an `UploadRequest` for the prebuilt `MultipartFormData` value using the providing `URLRequestConvertible`
    /// value and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
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
    ///   - multipartFormData:       `MultipartFormData` instance to upload.
    ///   - request:                 `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                              default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    public static func upload(multipartFormData: MultipartFormData,
                              with request: URLRequestConvertible,
                              usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                              interceptor: RequestInterceptor? = nil,
                              fileManager: FileManager = .default) -> UploadRequest {
        return Session.default.upload(multipartFormData: multipartFormData,
                                      with: request,
                                      usingThreshold: encodingMemoryThreshold,
                                      interceptor: interceptor,
                                      fileManager: fileManager)
    }
}
