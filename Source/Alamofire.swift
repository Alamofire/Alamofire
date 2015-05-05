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

/// Alamofire errors
public let AlamofireErrorDomain = "com.alamofire.error"

// MARK: - URLStringConvertible

/**
    Types adopting the `URLStringConvertible` protocol can be used to construct URL strings, which are then used to construct URL requests.
*/
public protocol URLStringConvertible {
    /**
        A URL that conforms to RFC 2396.

        Methods accepting a `URLStringConvertible` type parameter parse it according to RFCs 1738 and 1808.

        See http://tools.ietf.org/html/rfc2396
        See http://tools.ietf.org/html/rfc1738
        See http://tools.ietf.org/html/rfc1808
    */
    var URLString: String { get }
}

extension String: URLStringConvertible {
    public var URLString: String {
        return self
    }
}

extension NSURL: URLStringConvertible {
    public var URLString: String {
        return absoluteString!
    }
}

extension NSURLComponents: URLStringConvertible {
    public var URLString: String {
        return URL!.URLString
    }
}

extension NSURLRequest: URLStringConvertible {
    public var URLString: String {
        return URL!.URLString
    }
}

// MARK: - URLRequestConvertible

/**
    Types adopting the `URLRequestConvertible` protocol can be used to construct URL requests.
*/
public protocol URLRequestConvertible {
    /// The URL request.
    var URLRequest: NSURLRequest { get }
}

extension NSURLRequest: URLRequestConvertible {
    public var URLRequest: NSURLRequest {
        return self
    }
}

// MARK: - Validation

extension Request {

    /**
        A closure used to validate a request that takes a URL request and URL response, and returns whether the request was valid.
    */
    public typealias Validation = (NSURLRequest, NSHTTPURLResponse) -> (Bool)

    /**
        Validates the request, using the specified closure.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :param: validation A closure to validate the request.

        :returns: The request.
    */
    public func validate(validation: Validation) -> Self {
        delegate.queue.addOperationWithBlock {
            if self.response != nil && self.delegate.error == nil {
                if !validation(self.request, self.response!) {
                    self.delegate.error = NSError(domain: AlamofireErrorDomain, code: -1, userInfo: nil)
                }
            }
        }

        return self
    }

    // MARK: Status Code

    /**
        Validates that the response has a status code in the specified range.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :param: range The range of acceptable status codes.

        :returns: The request.
    */
    public func validate<S : SequenceType where S.Generator.Element == Int>(statusCode acceptableStatusCode: S) -> Self {
        return validate { (_, response) in
            return contains(acceptableStatusCode, response.statusCode)
        }
    }

    // MARK: Content-Type

    private struct MIMEType {
        let type: String
        let subtype: String

        init?(_ string: String) {
            let components = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).substringToIndex(string.rangeOfString(";")?.endIndex ?? string.endIndex).componentsSeparatedByString("/")

            if let type = components.first,
                    subtype = components.last
            {
                self.type = type
                self.subtype = subtype
            } else {
                return nil
            }
        }

        func matches(MIME: MIMEType) -> Bool {
            switch (type, subtype) {
            case (MIME.type, MIME.subtype), (MIME.type, "*"), ("*", MIME.subtype), ("*", "*"):
                return true
            default:
                return false
            }
        }
    }

    /**
        Validates that the response has a content type in the specified array.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :param: contentType The acceptable content types, which may specify wildcard types and/or subtypes.

        :returns: The request.
    */
    public func validate<S : SequenceType where S.Generator.Element == String>(contentType acceptableContentTypes: S) -> Self {
        return validate {(_, response) in
            if let responseContentType = response.MIMEType,
                    responseMIMEType = MIMEType(responseContentType)
            {
                for contentType in acceptableContentTypes {
                    if let acceptableMIMEType = MIMEType(contentType)
                        where acceptableMIMEType.matches(responseMIMEType)
                    {
                        return true
                    }
                }
            }

            return false
        }
    }

    // MARK: Automatic

    /**
        Validates that the response has a status code in the default acceptable range of 200...299, and that the content type matches any specified in the Accept HTTP header field.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :returns: The request.
    */
    public func validate() -> Self {
        let acceptableStatusCodes: Range<Int> = 200..<300
        let acceptableContentTypes: [String] = {
            if let accept = self.request.valueForHTTPHeaderField("Accept") {
                return accept.componentsSeparatedByString(",")
            }

            return ["*/*"]
        }()

        return validate(statusCode: acceptableStatusCodes).validate(contentType: acceptableContentTypes)
    }
}

// MARK: - Upload

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
            dispatch_sync(queue) {
                uploadTask = self.session.uploadTaskWithRequest(request, fromData: data)
            }
        case .File(let request, let fileURL):
            dispatch_sync(queue) {
                uploadTask = self.session.uploadTaskWithRequest(request, fromFile: fileURL)
            }
        case .Stream(let request, var stream):
            dispatch_sync(queue) {
                uploadTask = self.session.uploadTaskWithStreamedRequest(request)
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
        :param: file The file to upload

        :returns: The created upload request.
    */
    public func upload(method: Method, _ URLString: URLStringConvertible, file: NSURL) -> Request {
        return upload(URLRequest(method, URLString), file: file)
    }

    // MARK: Data

    /**
        Creates a request for uploading data to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request
        :param: data The data to upload

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
        :param: data The data to upload

        :returns: The created upload request.
    */
    public func upload(method: Method, _ URLString: URLStringConvertible, data: NSData) -> Request {
        return upload(URLRequest(method, URLString), data: data)
    }

    // MARK: Stream

    /**
        Creates a request for uploading a stream to the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request
        :param: stream The stream to upload

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
        :param: stream The stream to upload.

        :returns: The created upload request.
    */
    public func upload(method: Method, _ URLString: URLStringConvertible, stream: NSInputStream) -> Request {
        return upload(URLRequest(method, URLString), stream: stream)
    }
}

extension Request {
    class UploadTaskDelegate: DataTaskDelegate {
        var uploadTask: NSURLSessionUploadTask! { return task as! NSURLSessionUploadTask }
        var uploadProgress: ((Int64, Int64, Int64) -> Void)!

        // MARK: NSURLSessionTaskDelegate

        func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            progress.totalUnitCount = totalBytesExpectedToSend
            progress.completedUnitCount = totalBytesSent

            uploadProgress?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
        }
    }
}

// MARK: - Download

extension Manager {
    private enum Downloadable {
        case Request(NSURLRequest)
        case ResumeData(NSData)
    }

    private func download(downloadable: Downloadable, destination: Request.DownloadFileDestination) -> Request {
        var downloadTask: NSURLSessionDownloadTask!

        switch downloadable {
        case .Request(let request):
            dispatch_sync(queue) {
                downloadTask = self.session.downloadTaskWithRequest(request)
            }
        case .ResumeData(let resumeData):
            dispatch_sync(queue) {
                downloadTask = self.session.downloadTaskWithResumeData(resumeData)
            }
        }

        let request = Request(session: session, task: downloadTask)
        if let downloadDelegate = request.delegate as? Request.DownloadTaskDelegate {
            downloadDelegate.downloadTaskDidFinishDownloadingToURL = { (session, downloadTask, URL) in
                return destination(URL, downloadTask.response as! NSHTTPURLResponse)
            }
        }
        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: Request

    /**
        Creates a download request using the shared manager instance for the specified method and URL string.

        :param: method The HTTP method.
        :param: URLString The URL string.
        :param: destination The closure used to determine the destination of the downloaded file.

        :returns: The created download request.
    */
    public func download(method: Method, _ URLString: URLStringConvertible, destination: Request.DownloadFileDestination) -> Request {
        return download(URLRequest(method, URLString), destination: destination)
    }

    /**
        Creates a request for downloading from the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request
        :param: destination The closure used to determine the destination of the downloaded file.

        :returns: The created download request.
    */
    public func download(URLRequest: URLRequestConvertible, destination: Request.DownloadFileDestination) -> Request {
        return download(.Request(URLRequest.URLRequest), destination: destination)
    }

    // MARK: Resume Data

    /**
        Creates a request for downloading from the resume data produced from a previous request cancellation.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: resumeData The resume data. This is an opaque data blob produced by `NSURLSessionDownloadTask` when a task is cancelled. See `NSURLSession -downloadTaskWithResumeData:` for additional information.
        :param: destination The closure used to determine the destination of the downloaded file.

        :returns: The created download request.
    */
    public func download(resumeData: NSData, destination: Request.DownloadFileDestination) -> Request {
        return download(.ResumeData(resumeData), destination: destination)
    }
}

extension Request {
    /**
        A closure executed once a request has successfully completed in order to determine where to move the temporary file written to during the download process. The closure takes two arguments: the temporary file URL and the URL response, and returns a single argument: the file URL where the temporary file should be moved.
    */
    public typealias DownloadFileDestination = (NSURL, NSHTTPURLResponse) -> (NSURL)

    /**
        Creates a download file destination closure which uses the default file manager to move the temporary file to a file URL in the first available directory with the specified search path directory and search path domain mask.

        :param: directory The search path directory. `.DocumentDirectory` by default.
        :param: domain The search path domain mask. `.UserDomainMask` by default.

        :returns: A download file destination closure.
    */
    public class func suggestedDownloadDestination(directory: NSSearchPathDirectory = .DocumentDirectory, domain: NSSearchPathDomainMask = .UserDomainMask) -> DownloadFileDestination {

        return { (temporaryURL, response) -> (NSURL) in
            if let directoryURL = NSFileManager.defaultManager().URLsForDirectory(directory, inDomains: domain)[0] as? NSURL {
                return directoryURL.URLByAppendingPathComponent(response.suggestedFilename!)
            }

            return temporaryURL
        }
    }

    class DownloadTaskDelegate: TaskDelegate, NSURLSessionDownloadDelegate {
        var downloadTask: NSURLSessionDownloadTask! { return task as! NSURLSessionDownloadTask }
        var downloadProgress: ((Int64, Int64, Int64) -> Void)?

        var resumeData: NSData?
        override var data: NSData? { return resumeData }

        var downloadTaskDidFinishDownloadingToURL: ((NSURLSession!, NSURLSessionDownloadTask!, NSURL) -> (NSURL))?
        var downloadTaskDidWriteData: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64, Int64) -> Void)?
        var downloadTaskDidResumeAtOffset: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64) -> Void)?

        // MARK: NSURLSessionDownloadDelegate

        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
            if downloadTaskDidFinishDownloadingToURL != nil {
                let destination = downloadTaskDidFinishDownloadingToURL!(session, downloadTask, location)
                var fileManagerError: NSError?

                NSFileManager.defaultManager().moveItemAtURL(location, toURL: destination, error: &fileManagerError)
                if fileManagerError != nil {
                    error = fileManagerError
                }
            }
        }

        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten

            downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)

            downloadProgress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        }

        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
            progress.totalUnitCount = expectedTotalBytes
            progress.completedUnitCount = fileOffset

            downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
        }
    }
}

// MARK: - Response Serializers

// MARK: String

extension Request {
    /**
        Creates a response serializer that returns a string initialized from the response data with the specified string encoding.

        :param: encoding The string encoding. If `nil`, the string encoding will be determined from the server response, falling back to the default HTTP default character set, ISO-8859-1.

        :returns: A string response serializer.
    */
    public class func stringResponseSerializer(var encoding: NSStringEncoding? = nil) -> Serializer {
        return { (_, response, data) in
            if data == nil || data?.length == 0 {
                return (nil, nil)
            }

            if encoding == nil {
                if let encodingName = response?.textEncodingName {
                    encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingName))
                }
            }

            let string = NSString(data: data!, encoding: encoding ?? NSISOLatin1StringEncoding)

            return (string, nil)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: encoding The string encoding. If `nil`, the string encoding will be determined from the server response, falling back to the default HTTP default character set, ISO-8859-1.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the string, if one could be created from the URL response and data, and any error produced while creating the string.

        :returns: The request.
    */
    public func responseString(encoding: NSStringEncoding? = nil, completionHandler: (NSURLRequest, NSHTTPURLResponse?, String?, NSError?) -> Void) -> Self  {
        return response(serializer: Request.stringResponseSerializer(encoding: encoding), completionHandler: { request, response, string, error in
            completionHandler(request, response, string as? String, error)
        })
    }
}

// MARK: JSON

extension Request {
    /**
        Creates a response serializer that returns a JSON object constructed from the response data using `NSJSONSerialization` with the specified reading options.

        :param: options The JSON serialization reading options. `.AllowFragments` by default.

        :returns: A JSON object response serializer.
    */
    public class func JSONResponseSerializer(options: NSJSONReadingOptions = .AllowFragments) -> Serializer {
        return { (request, response, data) in
            if data == nil || data?.length == 0 {
                return (nil, nil)
            }

            var serializationError: NSError?
            let JSON: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!, options: options, error: &serializationError)

            return (JSON, serializationError)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: options The JSON serialization reading options. `.AllowFragments` by default.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the JSON object, if one could be created from the URL response and data, and any error produced while creating the JSON object.

        :returns: The request.
    */
    public func responseJSON(options: NSJSONReadingOptions = .AllowFragments, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.JSONResponseSerializer(options: options), completionHandler: { (request, response, JSON, error) in
            completionHandler(request, response, JSON, error)
        })
    }
}

// MARK: Property List

extension Request {
    /**
        Creates a response serializer that returns an object constructed from the response data using `NSPropertyListSerialization` with the specified reading options.

        :param: options The property list reading options. `0` by default.

        :returns: A property list object response serializer.
    */
    public class func propertyListResponseSerializer(options: NSPropertyListReadOptions = 0) -> Serializer {
        return { (request, response, data) in
            if data == nil || data?.length == 0 {
                return (nil, nil)
            }

            var propertyListSerializationError: NSError?
            let plist: AnyObject? = NSPropertyListSerialization.propertyListWithData(data!, options: options, format: nil, error: &propertyListSerializationError)

            return (plist, propertyListSerializationError)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: options The property list reading options. `0` by default.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the property list, if one could be created from the URL response and data, and any error produced while creating the property list.

        :returns: The request.
    */
    public func responsePropertyList(options: NSPropertyListReadOptions = 0, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.propertyListResponseSerializer(options: options), completionHandler: { (request, response, plist, error) in
            completionHandler(request, response, plist, error)
        })
    }
}

// MARK: - Convenience -

func URLRequest(method: Method, URL: URLStringConvertible) -> NSURLRequest {
    let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URL.URLString)!)
    mutableURLRequest.HTTPMethod = method.rawValue

    return mutableURLRequest
}

// MARK: - Request

/**
    Creates a request using the shared manager instance for the specified method, URL string, parameters, and parameter encoding.

    :param: method The HTTP method.
    :param: URLString The URL string.
    :param: parameters The parameters. `nil` by default.
    :param: encoding The parameter encoding. `.URL` by default.

    :returns: The created request.
*/
public func request(method: Method, URLString: URLStringConvertible, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL) -> Request {
    return Manager.sharedInstance.request(method, URLString, parameters: parameters, encoding: encoding)
}

/**
    Creates a request using the shared manager instance for the specified URL request.

    If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

    :param: URLRequest The URL request

    :returns: The created request.
*/
public func request(URLRequest: URLRequestConvertible) -> Request {
    return Manager.sharedInstance.request(URLRequest.URLRequest)
}

// MARK: - Upload

// MARK: File

/**
    Creates an upload request using the shared manager instance for the specified method, URL string, and file.

    :param: method The HTTP method.
    :param: URLString The URL string.
    :param: file The file to upload.

    :returns: The created upload request.
*/
public func upload(method: Method, URLString: URLStringConvertible, file: NSURL) -> Request {
    return Manager.sharedInstance.upload(method, URLString, file: file)
}

/**
    Creates an upload request using the shared manager instance for the specified URL request and file.

    :param: URLRequest The URL request.
    :param: file The file to upload.

    :returns: The created upload request.
*/
public func upload(URLRequest: URLRequestConvertible, file: NSURL) -> Request {
    return Manager.sharedInstance.upload(URLRequest, file: file)
}

// MARK: Data

/**
    Creates an upload request using the shared manager instance for the specified method, URL string, and data.

    :param: method The HTTP method.
    :param: URLString The URL string.
    :param: data The data to upload.

    :returns: The created upload request.
*/
public func upload(method: Method, URLString: URLStringConvertible, data: NSData) -> Request {
    return Manager.sharedInstance.upload(method, URLString, data: data)
}

/**
    Creates an upload request using the shared manager instance for the specified URL request and data.

    :param: URLRequest The URL request.
    :param: data The data to upload.

    :returns: The created upload request.
*/
public func upload(URLRequest: URLRequestConvertible, data: NSData) -> Request {
    return Manager.sharedInstance.upload(URLRequest, data: data)
}

// MARK: Stream

/**
    Creates an upload request using the shared manager instance for the specified method, URL string, and stream.

    :param: method The HTTP method.
    :param: URLString The URL string.
    :param: stream The stream to upload.

    :returns: The created upload request.
*/
public func upload(method: Method, URLString: URLStringConvertible, stream: NSInputStream) -> Request {
    return Manager.sharedInstance.upload(method, URLString, stream: stream)
}

/**
    Creates an upload request using the shared manager instance for the specified URL request and stream.

    :param: URLRequest The URL request.
    :param: stream The stream to upload.

    :returns: The created upload request.
*/
public func upload(URLRequest: URLRequestConvertible, stream: NSInputStream) -> Request {
    return Manager.sharedInstance.upload(URLRequest, stream: stream)
}

// MARK: - Download

// MARK: URL Request

/**
    Creates a download request using the shared manager instance for the specified method and URL string.

    :param: method The HTTP method.
    :param: URLString The URL string.
    :param: destination The closure used to determine the destination of the downloaded file.

    :returns: The created download request.
*/
public func download(method: Method, URLString: URLStringConvertible, destination: Request.DownloadFileDestination) -> Request {
    return Manager.sharedInstance.download(method, URLString, destination: destination)
}

/**
    Creates a download request using the shared manager instance for the specified URL request.

    :param: URLRequest The URL request.
    :param: destination The closure used to determine the destination of the downloaded file.

    :returns: The created download request.
*/
public func download(URLRequest: URLRequestConvertible, destination: Request.DownloadFileDestination) -> Request {
    return Manager.sharedInstance.download(URLRequest, destination: destination)
}

// MARK: Resume Data

/**
    Creates a request using the shared manager instance for downloading from the resume data produced from a previous request cancellation.

    :param: resumeData The resume data. This is an opaque data blob produced by `NSURLSessionDownloadTask` when a task is cancelled. See `NSURLSession -downloadTaskWithResumeData:` for additional information.
    :param: destination The closure used to determine the destination of the downloaded file.

    :returns: The created download request.
*/
public func download(resumeData data: NSData, destination: Request.DownloadFileDestination) -> Request {
    return Manager.sharedInstance.download(data, destination: destination)
}
