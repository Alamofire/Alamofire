// Request.swift
//
// Copyright (c) 2014–2016 Alamofire Software Foundation (http://alamofire.org/)
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
    Responsible for sending a request and receiving the response and associated data from the server, as well as 
    managing its underlying `NSURLSessionTask`.
*/
public class Request {

    // MARK: - Properties

    /// The delegate for the underlying task.
    public let delegate: TaskDelegate

    /// The underlying task.
    public var task: NSURLSessionTask { return delegate.task }

    /// The session belonging to the underlying task.
    public let session: NSURLSession

    /// The request sent or to be sent to the server.
    public var request: NSURLRequest? { return task.originalRequest }

    /// The response received from the server, if any.
    public var response: NSHTTPURLResponse? { return task.response as? NSHTTPURLResponse }

    /// The progress of the request lifecycle.
    public var progress: NSProgress { return delegate.progress }

    var startTime: CFAbsoluteTime?
    var endTime: CFAbsoluteTime?

    // MARK: - Lifecycle

    init(session: NSURLSession, task: NSURLSessionTask) {
        self.session = session

        switch task {
        case is NSURLSessionUploadTask:
            delegate = UploadTaskDelegate(task: task)
        case is NSURLSessionDataTask:
            delegate = DataTaskDelegate(task: task)
        case is NSURLSessionDownloadTask:
            delegate = DownloadTaskDelegate(task: task)
        default:
            delegate = TaskDelegate(task: task)
        }

        delegate.queue.addOperationWithBlock { self.endTime = CFAbsoluteTimeGetCurrent() }
    }

    // MARK: - Authentication

    /**
        Associates an HTTP Basic credential with the request.

        - parameter user:        The user.
        - parameter password:    The password.
        - parameter persistence: The URL credential persistence. `.ForSession` by default.

        - returns: The request.
    */
    public func authenticate(
        user user: String,
        password: String,
        persistence: NSURLCredentialPersistence = .ForSession)
        -> Self
    {
        let credential = NSURLCredential(user: user, password: password, persistence: persistence)

        return authenticate(usingCredential: credential)
    }

    /**
        Associates a specified credential with the request.

        - parameter credential: The credential.

        - returns: The request.
    */
    public func authenticate(usingCredential credential: NSURLCredential) -> Self {
        delegate.credential = credential

        return self
    }

    // MARK: - Progress

    /**
        Sets a closure to be called periodically during the lifecycle of the request as data is written to or read 
        from the server.

        - For uploads, the progress closure returns the bytes written, total bytes written, and total bytes expected 
          to write.
        - For downloads and data tasks, the progress closure returns the bytes read, total bytes read, and total bytes 
          expected to read.

        - parameter closure: The code to be executed periodically during the lifecycle of the request.

        - returns: The request.
    */
    public func progress(closure: ((Int64, Int64, Int64) -> Void)? = nil) -> Self {
        if let uploadDelegate = delegate as? UploadTaskDelegate {
            uploadDelegate.uploadProgress = closure
        } else if let dataDelegate = delegate as? DataTaskDelegate {
            dataDelegate.dataProgress = closure
        } else if let downloadDelegate = delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadProgress = closure
        }

        return self
    }

    /**
        Sets a closure to be called periodically during the lifecycle of the request as data is read from the server.

        This closure returns the bytes most recently received from the server, not including data from previous calls. 
        If this closure is set, data will only be available within this closure, and will not be saved elsewhere. It is 
        also important to note that the `response` closure will be called with nil `responseData`.

        - parameter closure: The code to be executed periodically during the lifecycle of the request.

        - returns: The request.
    */
    public func stream(closure: (NSData -> Void)? = nil) -> Self {
        if let dataDelegate = delegate as? DataTaskDelegate {
            dataDelegate.dataStream = closure
        }

        return self
    }

    // MARK: - State

    /**
        Resumes the request.
    */
    public func resume() {
        if startTime == nil { startTime = CFAbsoluteTimeGetCurrent() }

        task.resume()
        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.Task.DidResume, object: task)
    }

    /**
        Suspends the request.
    */
    public func suspend() {
        task.suspend()
        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.Task.DidSuspend, object: task)
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
            task.cancel()
        }

        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.Task.DidCancel, object: task)
    }

    // MARK: - TaskDelegate

    /**
        The task delegate is responsible for handling all delegate callbacks for the underlying task as well as 
        executing all operations attached to the serial operation queue upon task completion.
    */
    public class TaskDelegate: NSObject {

        /// The serial operation queue used to execute all operations after the task completes.
        public let queue: NSOperationQueue

        let task: NSURLSessionTask
        let progress: NSProgress

        var data: NSData? { return nil }
        var error: NSError?

        var initialResponseTime: CFAbsoluteTime?
        var credential: NSURLCredential?

        init(task: NSURLSessionTask) {
            self.task = task
            self.progress = NSProgress(totalUnitCount: 0)
            self.queue = {
                let operationQueue = NSOperationQueue()
                operationQueue.maxConcurrentOperationCount = 1
                operationQueue.suspended = true

                if #available(OSX 10.10, *) {
                    operationQueue.qualityOfService = NSQualityOfService.Utility
                }

                return operationQueue
            }()
        }

        deinit {
            queue.cancelAllOperations()
            queue.suspended = false
        }

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        var taskWillPerformHTTPRedirection: ((NSURLSession, NSURLSessionTask, NSHTTPURLResponse, NSURLRequest) -> NSURLRequest?)?
        var taskDidReceiveChallenge: ((NSURLSession, NSURLSessionTask, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential?))?
        var taskNeedNewBodyStream: ((NSURLSession, NSURLSessionTask) -> NSInputStream?)?
        var taskDidCompleteWithError: ((NSURLSession, NSURLSessionTask, NSError?) -> Void)?

        // MARK: Delegate Methods

        func URLSession(
            session: NSURLSession,
            task: NSURLSessionTask,
            willPerformHTTPRedirection response: NSHTTPURLResponse,
            newRequest request: NSURLRequest,
            completionHandler: ((NSURLRequest?) -> Void))
        {
            var redirectRequest: NSURLRequest? = request

            if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
                redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
            }

            completionHandler(redirectRequest)
        }

        func URLSession(
            session: NSURLSession,
            task: NSURLSessionTask,
            didReceiveChallenge challenge: NSURLAuthenticationChallenge,
            completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void))
        {
            var disposition: NSURLSessionAuthChallengeDisposition = .PerformDefaultHandling
            var credential: NSURLCredential?

            if let taskDidReceiveChallenge = taskDidReceiveChallenge {
                (disposition, credential) = taskDidReceiveChallenge(session, task, challenge)
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                let host = challenge.protectionSpace.host

                if let
                    serverTrustPolicy = session.serverTrustPolicyManager?.serverTrustPolicyForHost(host),
                    serverTrust = challenge.protectionSpace.serverTrust
                {
                    if serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host) {
                        disposition = .UseCredential
                        credential = NSURLCredential(forTrust: serverTrust)
                    } else {
                        disposition = .CancelAuthenticationChallenge
                    }
                }
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

        func URLSession(
            session: NSURLSession,
            task: NSURLSessionTask,
            needNewBodyStream completionHandler: ((NSInputStream?) -> Void))
        {
            var bodyStream: NSInputStream?

            if let taskNeedNewBodyStream = taskNeedNewBodyStream {
                bodyStream = taskNeedNewBodyStream(session, task)
            }

            completionHandler(bodyStream)
        }

        func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
            if let taskDidCompleteWithError = taskDidCompleteWithError {
                taskDidCompleteWithError(session, task, error)
            } else {
                if let error = error {
                    self.error = error

                    if let
                        downloadDelegate = self as? DownloadTaskDelegate,
                        userInfo = error.userInfo as? [String: AnyObject],
                        resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? NSData
                    {
                        downloadDelegate.resumeData = resumeData
                    }
                }

                queue.suspended = false
            }
        }
    }

    // MARK: - DataTaskDelegate

    class DataTaskDelegate: TaskDelegate, NSURLSessionDataDelegate {
        var dataTask: NSURLSessionDataTask? { return task as? NSURLSessionDataTask }

        private var totalBytesReceived: Int64 = 0
        private var mutableData: NSMutableData
        override var data: NSData? {
            if dataStream != nil {
                return nil
            } else {
                return mutableData
            }
        }

        private var expectedContentLength: Int64?
        private var dataProgress: ((bytesReceived: Int64, totalBytesReceived: Int64, totalBytesExpectedToReceive: Int64) -> Void)?
        private var dataStream: ((data: NSData) -> Void)?

        override init(task: NSURLSessionTask) {
            mutableData = NSMutableData()
            super.init(task: task)
        }

        // MARK: - NSURLSessionDataDelegate

        // MARK: Override Closures

        var dataTaskDidReceiveResponse: ((NSURLSession, NSURLSessionDataTask, NSURLResponse) -> NSURLSessionResponseDisposition)?
        var dataTaskDidBecomeDownloadTask: ((NSURLSession, NSURLSessionDataTask, NSURLSessionDownloadTask) -> Void)?
        var dataTaskDidReceiveData: ((NSURLSession, NSURLSessionDataTask, NSData) -> Void)?
        var dataTaskWillCacheResponse: ((NSURLSession, NSURLSessionDataTask, NSCachedURLResponse) -> NSCachedURLResponse?)?

        // MARK: Delegate Methods

        func URLSession(
            session: NSURLSession,
            dataTask: NSURLSessionDataTask,
            didReceiveResponse response: NSURLResponse,
            completionHandler: (NSURLSessionResponseDisposition -> Void))
        {
            var disposition: NSURLSessionResponseDisposition = .Allow

            expectedContentLength = response.expectedContentLength

            if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
                disposition = dataTaskDidReceiveResponse(session, dataTask, response)
            }

            completionHandler(disposition)
        }

        func URLSession(
            session: NSURLSession,
            dataTask: NSURLSessionDataTask,
            didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask)
        {
            dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
        }

        func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
            if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }

            if let dataTaskDidReceiveData = dataTaskDidReceiveData {
                dataTaskDidReceiveData(session, dataTask, data)
            } else {
                if let dataStream = dataStream {
                    dataStream(data: data)
                } else {
                    mutableData.appendData(data)
                }

                totalBytesReceived += data.length
                let totalBytesExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown

                progress.totalUnitCount = totalBytesExpected
                progress.completedUnitCount = totalBytesReceived

                dataProgress?(
                    bytesReceived: Int64(data.length),
                    totalBytesReceived: totalBytesReceived,
                    totalBytesExpectedToReceive: totalBytesExpected
                )
            }
        }

        func URLSession(
            session: NSURLSession,
            dataTask: NSURLSessionDataTask,
            willCacheResponse proposedResponse: NSCachedURLResponse,
            completionHandler: ((NSCachedURLResponse?) -> Void))
        {
            var cachedResponse: NSCachedURLResponse? = proposedResponse

            if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
                cachedResponse = dataTaskWillCacheResponse(session, dataTask, proposedResponse)
            }

            completionHandler(cachedResponse)
        }
    }
}

// MARK: - CustomStringConvertible

extension Request: CustomStringConvertible {

    /**
        The textual representation used when written to an output stream, which includes the HTTP method and URL, as 
        well as the response status code if a response has been received.
    */
    public var description: String {
        var components: [String] = []

        if let HTTPMethod = request?.HTTPMethod {
            components.append(HTTPMethod)
        }

        if let URLString = request?.URL?.absoluteString {
            components.append(URLString)
        }

        if let response = response {
            components.append("(\(response.statusCode))")
        }

        return components.joinWithSeparator(" ")
    }
}

// MARK: - CustomDebugStringConvertible

extension Request: CustomDebugStringConvertible {
    func cURLRepresentation() -> String {
        var components = ["$ curl -i"]

        guard let
            request = self.request,
            URL = request.URL,
            host = URL.host
        else {
            return "$ curl command could not be created"
        }

        if let HTTPMethod = request.HTTPMethod where HTTPMethod != "GET" {
            components.append("-X \(HTTPMethod)")
        }

        if let credentialStorage = self.session.configuration.URLCredentialStorage {
            let protectionSpace = NSURLProtectionSpace(
                host: host,
                port: URL.port?.integerValue ?? 0,
                `protocol`: URL.scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )

            if let credentials = credentialStorage.credentialsForProtectionSpace(protectionSpace)?.values {
                for credential in credentials {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            } else {
                if let credential = delegate.credential {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            }
        }

        if session.configuration.HTTPShouldSetCookies {
            if let
                cookieStorage = session.configuration.HTTPCookieStorage,
                cookies = cookieStorage.cookiesForURL(URL) where !cookies.isEmpty
            {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value ?? String());" }
                components.append("-b \"\(string.substringToIndex(string.endIndex.predecessor()))\"")
            }
        }

        if let headerFields = request.allHTTPHeaderFields {
            for (field, value) in headerFields {
                switch field {
                case "Cookie":
                    continue
                default:
                    components.append("-H \"\(field): \(value)\"")
                }
            }
        }

        if let additionalHeaders = session.configuration.HTTPAdditionalHeaders {
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
            HTTPBodyData = request.HTTPBody,
            HTTPBody = String(data: HTTPBodyData, encoding: NSUTF8StringEncoding)
        {
            let escapedBody = HTTPBody.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(URL.absoluteString)\"")

        return components.joinWithSeparator(" \\\n\t")
    }

    /// The textual representation used when written to an output stream, in the form of a cURL command.
    public var debugDescription: String {
        return cURLRepresentation()
    }
}
