// Alamofire.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

extension Manager {
    private enum Uploadable {
        case Data(NSURLRequest, NSData)
        case File(NSURLRequest, NSURL)
        case Stream(NSURLRequest, NSInputStream)
    }

    private func upload(uploadable: Uploadable) -> Request {
        var uploadTask: NSURLSessionUploadTask!
        var HTTPBodyStream: NSInputStream?

        switch uploadable {
        case .Data(let request, let data):
            dispatch_sync(self.queue) {
                uploadTask = self.session.uploadTaskWithRequest(request, fromData: data)
            }
        case .File(let request, let fileURL):
            dispatch_sync(self.queue) {
                uploadTask = self.session.uploadTaskWithRequest(request, fromFile: fileURL)
            }
        case .Stream(let request, var stream):
            dispatch_sync(self.queue) {
                uploadTask = self.session.uploadTaskWithStreamedRequest(request)
            }

            HTTPBodyStream = stream
        }

        let request = Request(session: self.session, task: uploadTask)

        if HTTPBodyStream != nil {
            request.delegate.taskNeedNewBodyStream = { _, _ in
                return HTTPBodyStream
            }
        }

        self.delegate[request.delegate.task] = request.delegate

        if self.startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: File

    /**
        Creates a request for uploading a file to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request
        :param: file The file to upload

        :returns: The created upload request.
    */
    public func upload(URLRequest: URLRequestConvertible, file: NSURL) -> Request {
        return upload(.File(URLRequest.URLRequest, file))
    }

    /**
        Creates a request for uploading a file to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: method The HTTP method.
        :param: URLString The URL string.
        :param: headers The HTTP headers. `nil` by default.
        :param: file The file to upload.

        :returns: The created upload request.
    */
    public func upload(method: Method, _ URLString: URLStringConvertible, headers: [String: String]? = nil, file: NSURL) -> Request {
        let mutableURLRequest = URLRequest(method, URLString, headers: headers)
        return upload(mutableURLRequest, file: file)
    }

    // MARK: Data

    /**
        Creates a request for uploading data to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request.
        :param: data The data to upload.

        :returns: The created upload request.
    */
    public func upload(URLRequest: URLRequestConvertible, data: NSData) -> Request {
        return upload(.Data(URLRequest.URLRequest, data))
    }

    /**
        Creates a request for uploading data to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: method The HTTP method.
        :param: URLString The URL string.
        :param: headers The HTTP headers. `nil` by default.
        :param: data The data to upload.

        :returns: The created upload request.
    */
    public func upload(method: Method, _ URLString: URLStringConvertible, headers: [String: String]? = nil, data: NSData) -> Request {
        let mutableURLRequest = URLRequest(method, URLString, headers: headers)

        return upload(mutableURLRequest, data: data)
    }

    // MARK: Stream

    /**
        Creates a request for uploading a stream to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request.
        :param: stream The stream to upload.

        :returns: The created upload request.
    */
    public func upload(URLRequest: URLRequestConvertible, stream: NSInputStream) -> Request {
        return upload(.Stream(URLRequest.URLRequest, stream))
    }

    /**
        Creates a request for uploading a stream to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: method The HTTP method.
        :param: URLString The URL string.
        :param: headers The HTTP headers. `nil` by default.
        :param: stream The stream to upload.

        :returns: The created upload request.
    */
    public func upload(method: Method, _ URLString: URLStringConvertible, headers: [String: String]? = nil, stream: NSInputStream) -> Request {
        let mutableURLRequest = URLRequest(method, URLString, headers: headers)

        return upload(mutableURLRequest, stream: stream)
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
        case Success(request: Request, streamingFromDisk: Bool, streamFileURL: NSURL?)
        case Failure(NSError)
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

        :param: method                  The HTTP method.
        :param: URLString               The URL string.
        :param: headers                 The HTTP headers. `nil` by default.
        :param: multipartFormData       The closure used to append body parts to the `MultipartFormData`.
        :param: encodingMemoryThreshold The encoding memory threshold in bytes. `MultipartFormDataEncodingMemoryThreshold`
                                        by default.
        :param: encodingCompletion      The closure called when the `MultipartFormData` encoding is complete.
    */
    public func upload(
        method: Method,
        _ URLString: URLStringConvertible,
        headers: [String: String]? = nil,
        multipartFormData: MultipartFormData -> Void,
        encodingMemoryThreshold: UInt64 = Manager.MultipartFormDataEncodingMemoryThreshold,
        encodingCompletion: (MultipartFormDataEncodingResult -> Void)?)
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

        :param: URLRequest              The URL request.
        :param: multipartFormData       The closure used to append body parts to the `MultipartFormData`.
        :param: encodingMemoryThreshold The encoding memory threshold in bytes. `MultipartFormDataEncodingMemoryThreshold`
                                        by default.
        :param: encodingCompletion      The closure called when the `MultipartFormData` encoding is complete.
    */
    public func upload(
        URLRequest: URLRequestConvertible,
        multipartFormData: MultipartFormData -> Void,
        encodingMemoryThreshold: UInt64 = Manager.MultipartFormDataEncodingMemoryThreshold,
        encodingCompletion: (MultipartFormDataEncodingResult -> Void)?)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let formData = MultipartFormData()
            multipartFormData(formData)

            let URLRequestWithContentType = URLRequest.URLRequest.mutableCopy() as! NSMutableURLRequest
            URLRequestWithContentType.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")

            if formData.contentLength < encodingMemoryThreshold {
                let encodingResult = formData.encode()

                dispatch_async(dispatch_get_main_queue()) {
                    switch encodingResult {
                    case .Success(let data):
                        let encodingResult = MultipartFormDataEncodingResult.Success(
                            request: self.upload(URLRequestWithContentType, data: data),
                            streamingFromDisk: false,
                            streamFileURL: nil
                        )
                        encodingCompletion?(encodingResult)
                    case .Failure(let error):
                        encodingCompletion?(.Failure(error))
                    }
                }
            } else {
                let fileManager = NSFileManager.defaultManager()
                let tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory())!
                let directoryURL = tempDirectoryURL.URLByAppendingPathComponent("com.alamofire.manager/multipart.form.data")
                let fileName = NSUUID().UUIDString
                let fileURL = directoryURL.URLByAppendingPathComponent(fileName)

                var error: NSError?

                if fileManager.createDirectoryAtURL(directoryURL, withIntermediateDirectories: true, attributes: nil, error: &error) {
                    formData.writeEncodedDataToDisk(fileURL) { error in
                        dispatch_async(dispatch_get_main_queue()) {
                            if let error = error {
                                encodingCompletion?(.Failure(error))
                            } else {
                                let encodingResult = MultipartFormDataEncodingResult.Success(
                                    request: self.upload(URLRequestWithContentType, file: fileURL),
                                    streamingFromDisk: true,
                                    streamFileURL: fileURL
                                )
                                encodingCompletion?(encodingResult)
                            }
                        }
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        encodingCompletion?(.Failure(error!))
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
        var uploadTask: NSURLSessionUploadTask? { return self.task as? NSURLSessionUploadTask }
        var uploadProgress: ((Int64, Int64, Int64) -> Void)!

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        var taskDidSendBodyData: ((NSURLSession, NSURLSessionTask, Int64, Int64, Int64) -> Void)?

        // MARK: Delegate Methods

        func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            if let taskDidSendBodyData = self.taskDidSendBodyData {
                taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
            } else {
                self.progress.totalUnitCount = totalBytesExpectedToSend
                self.progress.completedUnitCount = totalBytesSent

                self.uploadProgress?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
            }
        }
    }
}
