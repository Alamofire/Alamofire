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

/**
    Responsible for sending a request and receiving the response and associated data from the server, as well as managing its underlying `NSURLSessionTask`.
*/
public class Request {

    // MARK: - Properties

    let delegate: TaskDelegate

    /// The underlying task.
    public var task: NSURLSessionTask { return delegate.task }

    /// The session belonging to the underlying task.
    public let session: NSURLSession

    /// The request sent or to be sent to the server.
    public var request: NSURLRequest { return task.originalRequest }

    /// The response received from the server, if any.
    public var response: NSHTTPURLResponse? { return task.response as? NSHTTPURLResponse }

    /// The progress of the request lifecycle.
    public var progress: NSProgress { return delegate.progress }

    // MARK: - Lifecycle

    init(session: NSURLSession, task: NSURLSessionTask) {
        self.session = session

        switch task {
        case is NSURLSessionUploadTask:
            self.delegate = UploadTaskDelegate(task: task)
        case is NSURLSessionDataTask:
            self.delegate = DataTaskDelegate(task: task)
        case is NSURLSessionDownloadTask:
            self.delegate = DownloadTaskDelegate(task: task)
        default:
            self.delegate = TaskDelegate(task: task)
        }
    }

    // MARK: - Authentication

    /**
        Associates an HTTP Basic credential with the request.

        :param: user The user.
        :param: password The password.
        :param: persistence The URL credential persistence. `.ForSession` by default.

        :returns: The request.
    */
    public func authenticate(#user: String, password: String, persistence: NSURLCredentialPersistence = .ForSession) -> Self {
        let credential = NSURLCredential(user: user, password: password, persistence: persistence)

        return authenticate(usingCredential: credential)
    }

    /**
        Associates a specified credential with the request.

        :param: credential The credential.

        :returns: The request.
    */
    public func authenticate(usingCredential credential: NSURLCredential) -> Self {
        self.delegate.credential = credential

        return self
    }

    // MARK: - Progress

    /**
        Sets a closure to be called periodically during the lifecycle of the request as data is written to or read from the server.

        - For uploads, the progress closure returns the bytes written, total bytes written, and total bytes expected to write.
        - For downloads and data tasks, the progress closure returns the bytes read, total bytes read, and total bytes expected to read.

        :param: closure The code to be executed periodically during the lifecycle of the request.

        :returns: The request.
    */
    public func progress(closure: ((Int64, Int64, Int64) -> Void)? = nil) -> Self {
        if let uploadDelegate = self.delegate as? UploadTaskDelegate {
            uploadDelegate.uploadProgress = closure
        } else if let dataDelegate = self.delegate as? DataTaskDelegate {
            dataDelegate.dataProgress = closure
        } else if let downloadDelegate = self.delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadProgress = closure
        }

        return self
    }

    /**
        Sets a closure to be called periodically during the lifecycle of the request as data is read from the server.

        This closure returns the bytes most recently received from the server, not including data from previous calls. If this closure is set, data will only be available within this closure, and will not be saved elsewhere. It is also important to note that the `response` closure will be called with nil `responseData`.

        :param: closure The code to be executed periodically during the lifecycle of the request.

        :returns: The request.
    */
    public func stream(closure: (NSData -> Void)? = nil) -> Self {
        if let dataDelegate = self.delegate as? DataTaskDelegate {
            dataDelegate.dataStream = closure
        }

        return self
    }

    // MARK: - Response

    /**
        A closure used by response handlers that takes a request, response, and data and returns a serialized object and any error that occured in the process.
    */
    public typealias Serializer = (NSURLRequest, NSHTTPURLResponse?, NSData?) -> (AnyObject?, NSError?)

    /**
        Creates a response serializer that returns the associated data as-is.

        :returns: A data response serializer.
    */
    public class func responseDataSerializer() -> Serializer {
        return { request, response, data in
            return (data, nil)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: completionHandler The code to be executed once the request has finished.

        :returns: The request.
    */
    public func response(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.responseDataSerializer(), completionHandler: completionHandler)
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: queue The queue on which the completion handler is dispatched.
        :param: serializer The closure responsible for serializing the request, response, and data.
        :param: completionHandler The code to be executed once the request has finished.

        :returns: The request.
    */
    public func response(queue: dispatch_queue_t? = nil, serializer: Serializer, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        self.delegate.queue.addOperationWithBlock {
            let (responseObject: AnyObject?, serializationError: NSError?) = serializer(self.request, self.response, self.delegate.data)

            dispatch_async(queue ?? dispatch_get_main_queue()) {
                completionHandler(self.request, self.response, responseObject, self.delegate.error ?? serializationError)
            }
        }

        return self
    }

    // MARK: - State

    /**
        Suspends the request.
    */
    public func suspend() {
        self.task.suspend()
    }

    /**
        Resumes the request.
    */
    public func resume() {
        self.task.resume()
    }

    /**
        Cancels the request.
    */
    public func cancel() {
        if let
            downloadDelegate = delegate as? DownloadTaskDelegate,
            downloadTask = downloadDelegate.downloadTask
        {
            downloadTask.cancelByProducingResumeData { data in
                downloadDelegate.resumeData = data
            }
        } else {
            self.task.cancel()
        }
    }

    // MARK: - TaskDelegate

    class TaskDelegate: NSObject, NSURLSessionTaskDelegate {
        let task: NSURLSessionTask
        let queue: NSOperationQueue
        let progress: NSProgress

        var data: NSData? { return nil }
        var error: NSError?

        var credential: NSURLCredential?

        init(task: NSURLSessionTask) {
            self.task = task
            self.progress = NSProgress(totalUnitCount: 0)
            self.queue = {
                let operationQueue = NSOperationQueue()
                operationQueue.maxConcurrentOperationCount = 1
                operationQueue.suspended = true

                if operationQueue.respondsToSelector("qualityOfService") {
                    operationQueue.qualityOfService = NSQualityOfService.Utility
                }

                return operationQueue
            }()
        }

        deinit {
            self.queue.cancelAllOperations()
            self.queue.suspended = true
        }

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        var taskWillPerformHTTPRedirection: ((NSURLSession, NSURLSessionTask, NSHTTPURLResponse, NSURLRequest) -> NSURLRequest?)?
        var taskDidReceiveChallenge: ((NSURLSession, NSURLSessionTask, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential?))?
        var taskNeedNewBodyStream: ((NSURLSession, NSURLSessionTask) -> NSInputStream?)?
        var taskDidCompleteWithError: ((NSURLSession, NSURLSessionTask, NSError?) -> Void)?

        // MARK: Delegate Methods

        func URLSession(session: NSURLSession, task: NSURLSessionTask, willPerformHTTPRedirection response: NSHTTPURLResponse, newRequest request: NSURLRequest, completionHandler: ((NSURLRequest!) -> Void)) {
            var redirectRequest: NSURLRequest? = request

            if let taskWillPerformHTTPRedirection = self.taskWillPerformHTTPRedirection {
                redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
            }

            completionHandler(redirectRequest)
        }

        func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)) {
            var disposition: NSURLSessionAuthChallengeDisposition = .PerformDefaultHandling
            var credential: NSURLCredential?

            if let taskDidReceiveChallenge = self.taskDidReceiveChallenge {
                (disposition, credential) = taskDidReceiveChallenge(session, task, challenge)
            } else {
                if challenge.previousFailureCount > 0 {
                    disposition = .CancelAuthenticationChallenge
                } else {
                    credential = self.credential ?? session.configuration.URLCredentialStorage?.defaultCredentialForProtectionSpace(challenge.protectionSpace)

                    if credential != nil {
                        disposition = .UseCredential
                    }
                }
            }

            completionHandler(disposition, credential)
        }

        func URLSession(session: NSURLSession, task: NSURLSessionTask, needNewBodyStream completionHandler: ((NSInputStream!) -> Void)) {
            var bodyStream: NSInputStream?

            if let taskNeedNewBodyStream = self.taskNeedNewBodyStream {
                bodyStream = taskNeedNewBodyStream(session, task)
            }

            completionHandler(bodyStream)
        }

        func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
            if let taskDidCompleteWithError = self.taskDidCompleteWithError {
                taskDidCompleteWithError(session, task, error)
            } else {
                if error != nil {
                    self.error = error
                }

                self.queue.suspended = false
            }
        }
    }

    // MARK: - DataTaskDelegate

    class DataTaskDelegate: TaskDelegate, NSURLSessionDataDelegate {
        var dataTask: NSURLSessionDataTask? { return self.task as? NSURLSessionDataTask }

        private var totalBytesReceived: Int64 = 0
        private var mutableData: NSMutableData
        override var data: NSData? {
            if self.dataStream != nil {
                return nil
            } else {
                return self.mutableData
            }
        }

        private var expectedContentLength: Int64?
        private var dataProgress: ((bytesReceived: Int64, totalBytesReceived: Int64, totalBytesExpectedToReceive: Int64) -> Void)?
        private var dataStream: ((data: NSData) -> Void)?

        override init(task: NSURLSessionTask) {
            self.mutableData = NSMutableData()
            super.init(task: task)
        }

        // MARK: - NSURLSessionDataDelegate

        // MARK: Override Closures

        var dataTaskDidReceiveResponse: ((NSURLSession, NSURLSessionDataTask, NSURLResponse) -> NSURLSessionResponseDisposition)?
        var dataTaskDidBecomeDownloadTask: ((NSURLSession, NSURLSessionDataTask, NSURLSessionDownloadTask) -> Void)?
        var dataTaskDidReceiveData: ((NSURLSession, NSURLSessionDataTask, NSData) -> Void)?
        var dataTaskWillCacheResponse: ((NSURLSession, NSURLSessionDataTask, NSCachedURLResponse) -> NSCachedURLResponse?)?

        // MARK: Delegate Methods

        func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
            var disposition: NSURLSessionResponseDisposition = .Allow

            self.expectedContentLength = response.expectedContentLength

            if let dataTaskDidReceiveResponse = self.dataTaskDidReceiveResponse {
                disposition = dataTaskDidReceiveResponse(session, dataTask, response)
            }

            completionHandler(disposition)
        }

        func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask) {
            self.dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
        }

        func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
            if let dataTaskDidReceiveData = self.dataTaskDidReceiveData {
                dataTaskDidReceiveData(session, dataTask, data)
            } else {
                if let dataStream = self.dataStream {
                    dataStream(data: data)
                } else {
                    self.mutableData.appendData(data)
                }

                self.totalBytesReceived += data.length
                let totalBytesExpectedToReceive = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown

                self.progress.totalUnitCount = totalBytesExpectedToReceive
                self.progress.completedUnitCount = totalBytesReceived

                self.dataProgress?(bytesReceived: Int64(data.length), totalBytesReceived: self.totalBytesReceived, totalBytesExpectedToReceive: totalBytesExpectedToReceive)
            }
        }

        func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, willCacheResponse proposedResponse: NSCachedURLResponse, completionHandler: ((NSCachedURLResponse!) -> Void)) {
            var cachedResponse: NSCachedURLResponse? = proposedResponse

            if let dataTaskWillCacheResponse = self.dataTaskWillCacheResponse {
                cachedResponse = dataTaskWillCacheResponse(session, dataTask, proposedResponse)
            }

            completionHandler(cachedResponse)
        }
    }
}

// MARK: - Printable

extension Request: Printable {
    /// The textual representation used when written to an output stream, which includes the HTTP method and URL, as well as the response status code if a response has been received.
    public var description: String {
        var components: [String] = []

        if let HTTPMethod = self.request.HTTPMethod {
            components.append(HTTPMethod)
        }

        components.append(self.request.URL!.absoluteString!)

        if let response = self.response {
            components.append("(\(response.statusCode))")
        }

        return join(" ", components)
    }
}

// MARK: - DebugPrintable

extension Request: DebugPrintable {
    func cURLRepresentation() -> String {
        var components: [String] = ["$ curl -i"]

        let URL = self.request.URL

        if let HTTPMethod = self.request.HTTPMethod where HTTPMethod != "GET" {
            components.append("-X \(HTTPMethod)")
        }

        if let credentialStorage = self.session.configuration.URLCredentialStorage {
            let protectionSpace = NSURLProtectionSpace(
                host: URL!.host!,
                port: URL!.port?.integerValue ?? 0,
                `protocol`: URL!.scheme!,
                realm: URL!.host!,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )

            if let credentials = credentialStorage.credentialsForProtectionSpace(protectionSpace)?.values.array {
                for credential: NSURLCredential in (credentials as! [NSURLCredential]) {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            } else {
                if let credential = self.delegate.credential {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            }
        }

        // Temporarily disabled on OS X due to build failure for CocoaPods
        // See https://github.com/CocoaPods/swift/issues/24
        #if !os(OSX)
            if self.session.configuration.HTTPShouldSetCookies {
                if let
                    cookieStorage = self.session.configuration.HTTPCookieStorage,
                    cookies = cookieStorage.cookiesForURL(URL!) as? [NSHTTPCookie] where !cookies.isEmpty
                {
                    let string = cookies.reduce(""){ $0 + "\($1.name)=\($1.value ?? String());" }
                    components.append("-b \"\(string.substringToIndex(string.endIndex.predecessor()))\"")
                }
            }
        #endif

        if let headerFields = self.request.allHTTPHeaderFields {
            for (field, value) in headerFields {
                switch field {
                case "Cookie":
                    continue
                default:
                    components.append("-H \"\(field): \(value)\"")
                }
            }
        }

        if let additionalHeaders = self.session.configuration.HTTPAdditionalHeaders {
            for (field, value) in additionalHeaders {
                switch field {
                case "Cookie":
                    continue
                default:
                    components.append("-H \"\(field): \(value)\"")
                }
            }
        }

        if let
            HTTPBody = self.request.HTTPBody,
            escapedBody = NSString(data: HTTPBody, encoding: NSUTF8StringEncoding)?.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
        {
            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(URL!.absoluteString!)\"")

        return join(" \\\n\t", components)
    }

    /// The textual representation used when written to an output stream, in the form of a cURL command.
    public var debugDescription: String {
        return cURLRepresentation()
    }
}
