//
//  Upload.swift
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

extension Manager {
    private enum Uploadable {
        case data(Foundation.URLRequest, Foundation.Data)
        case file(Foundation.URLRequest, URL)
        case stream(Foundation.URLRequest, InputStream)
    }

    private func upload(_ uploadable: Uploadable) -> Request {
        var uploadTask: URLSessionUploadTask!
        var HTTPBodyStream: InputStream?

        switch uploadable {
        case .data(let request, let data):
            queue.sync {
                uploadTask = self.session.uploadTask(with: request, from: data)
            }
        case .file(let request, let fileURL):
            queue.sync {
                uploadTask = self.session.uploadTask(with: request, fromFile: fileURL)
            }
        case .stream(let request, let stream):
            queue.sync {
                uploadTask = self.session.uploadTask(withStreamedRequest: request)
            }

            HTTPBodyStream = stream
        }

        let request = Request(session: session, task: uploadTask)

        if HTTPBodyStream != nil {
            request.delegate.taskNeedNewBodyStream = { _, _ in
                return HTTPBodyStream
            }
        }

        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: File

    /**
        Creates a request for uploading a file to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter URLRequest: The URL request
        - parameter file:       The file to upload

        - returns: The created upload request.
    */
    public func upload(_ URLRequest: URLRequestConvertible, file: URL) -> Request {
        return upload(.file(URLRequest.urlRequest as Foundation.URLRequest, file))
    }

    /**
        Creates a request for uploading a file to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter method:    The HTTP method.
        - parameter URLString: The URL string.
        - parameter headers:   The HTTP headers. `nil` by default.
        - parameter file:      The file to upload

        - returns: The created upload request.
    */
    public func upload(
        _ method: Method,
        _ urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        file: URL)
        -> Request
    {
        let urlRequest = URLRequest(method, urlString , headers: headers)
        return upload(urlRequest, file: file)
    }

    // MARK: Data

    /**
        Creates a request for uploading data to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter URLRequest: The URL request.
        - parameter data:       The data to upload.

        - returns: The created upload request.
    */
    public func upload(_ urlRequest: URLRequestConvertible, data: Data) -> Request {
        return upload(.data(urlRequest.urlRequest as URLRequest, data))
    }

    /**
        Creates a request for uploading data to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter method:    The HTTP method.
        - parameter URLString: The URL string.
        - parameter headers:   The HTTP headers. `nil` by default.
        - parameter data:      The data to upload

        - returns: The created upload request.
    */
    public func upload(
        _ method: Method,
        _ urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        data: Data)
        -> Request
    {
        let mutableURLRequest = URLRequest(method, urlString, headers: headers)

        return upload(mutableURLRequest, data: data)
    }

    // MARK: Stream

    /**
        Creates a request for uploading a stream to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter URLRequest: The URL request.
        - parameter stream:     The stream to upload.

        - returns: The created upload request.
    */
    public func upload(urlRequest: URLRequestConvertible, stream: InputStream) -> Request {
        return upload(.stream(urlRequest.urlRequest as URLRequest, stream))
    }

    /**
        Creates a request for uploading a stream to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter method:    The HTTP method.
        - parameter URLString: The URL string.
        - parameter headers:   The HTTP headers. `nil` by default.
        - parameter stream:    The stream to upload.

        - returns: The created upload request.
    */
    public func upload(
        _ method: Method,
        _ urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        stream: InputStream)
        -> Request
    {
        let mutableURLRequest = URLRequest(method, urlString, headers: headers)

        return upload(urlRequest: mutableURLRequest, stream: stream)
    }

    // MARK: MultipartFormData

    /// Default memory threshold used when encoding `MultipartFormData`.
    public static let MultipartFormDataEncodingMemoryThreshold: UInt64 = 10 * 1024 * 1024

    /**
        Defines whether the `MultipartFormData` encoding was successful and contains result of the encoding as
        associated values.

        - Success: Represents a successful `MultipartFormData` encoding and contains the new `Request` along with
                   streaming information.
        - Failure: Used to represent a failure in the `MultipartFormData` encoding and also contains the encoding
                   error.
    */
    public enum MultipartFormDataEncodingResult {
        case success(request: Request, streamingFromDisk: Bool, streamFileURL: URL?)
        case failure(ErrorProtocol)
    }

    /**
        Encodes the `MultipartFormData` and creates a request to upload the result to the specified URL request.

        It is important to understand the memory implications of uploading `MultipartFormData`. If the cummulative
        payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
        efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
        be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
        footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
        used for larger payloads such as video content.

        The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
        or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
        encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
        during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
        technique was used.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

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
        encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?)
    {
        let mutableURLRequest = URLRequest(method, URLString, headers: headers)

        return upload(
            mutableURLRequest,
            multipartFormData: multipartFormData,
            encodingMemoryThreshold: encodingMemoryThreshold,
            encodingCompletion: encodingCompletion
        )
    }

    /**
        Encodes the `MultipartFormData` and creates a request to upload the result to the specified URL request.

        It is important to understand the memory implications of uploading `MultipartFormData`. If the cummulative
        payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
        efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
        be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
        footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
        used for larger payloads such as video content.

        The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
        or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
        encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
        during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
        technique was used.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter URLRequest:              The URL request.
        - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
        - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
                                             `MultipartFormDataEncodingMemoryThreshold` by default.
        - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
    */
    public func upload(
        _ urlRequest: URLRequestConvertible,
        multipartFormData: (MultipartFormData) -> Void,
        encodingMemoryThreshold: UInt64 = Manager.MultipartFormDataEncodingMemoryThreshold,
        encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?)
    {
        DispatchQueue.global(attributes: .qosUtility).async {
            let formData = MultipartFormData()
            multipartFormData(formData)

            var URLRequestWithContentType = urlRequest.urlRequest
            URLRequestWithContentType.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")

            let isBackgroundSession = self.session.configuration.identifier != nil

            if formData.contentLength < encodingMemoryThreshold && !isBackgroundSession {
                do {
                    let data = try formData.encode()
                    let encodingResult = MultipartFormDataEncodingResult.success(
                        request: self.upload(URLRequestWithContentType, data: data as Data),
                        streamingFromDisk: false,
                        streamFileURL: nil
                    )

                    DispatchQueue.main.async {
                        encodingCompletion?(encodingResult)
                    }
                } catch {
                    DispatchQueue.main.async {
                        encodingCompletion?(.failure(error as NSError))
                    }
                }
            } else {
                let fileManager = FileManager.default
                let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                let directoryURL = try! tempDirectoryURL.appendingPathComponent("com.alamofire.manager/multipart.form.data")
                let fileName = UUID().uuidString
                let fileURL = try! directoryURL.appendingPathComponent(fileName)

                do {
                    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                    try formData.writeEncodedDataToDisk(fileURL)

                    DispatchQueue.main.async {
                        let encodingResult = MultipartFormDataEncodingResult.success(
                            request: self.upload(URLRequestWithContentType, file: fileURL),
                            streamingFromDisk: true,
                            streamFileURL: fileURL
                        )
                        encodingCompletion?(encodingResult)
                    }
                } catch {
                    DispatchQueue.main.async {
                        encodingCompletion?(.failure(error as NSError))
                    }
                }
            }
        }
    }
}

// MARK: -

extension Request {

    // MARK: - UploadTaskDelegate

    class UploadTaskDelegate: DataTaskDelegate {
        var uploadTask: URLSessionUploadTask? { return task as? URLSessionUploadTask }
        var uploadProgress: ((Int64, Int64, Int64) -> Void)!

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        var taskDidSendBodyData: ((Foundation.URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?

        // MARK: Delegate Methods

        func URLSession(
            _ session: Foundation.URLSession,
            task: URLSessionTask,
            didSendBodyData bytesSent: Int64,
            totalBytesSent: Int64,
            totalBytesExpectedToSend: Int64)
        {
            if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }

            if let taskDidSendBodyData = taskDidSendBodyData {
                taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
            } else {
                progress.totalUnitCount = totalBytesExpectedToSend
                progress.completedUnitCount = totalBytesSent

                uploadProgress?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
            }
        }
    }
}
