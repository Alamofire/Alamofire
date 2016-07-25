//
//  Request.swift
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

/**
    Responsible for sending a request and receiving the response and associated data from the server, as well as
    managing its underlying `NSURLSessionTask`.
*/
public class Request {

    // MARK: - Properties

    /// The delegate for the underlying task.
    public let delegate: TaskDelegate

    /// The underlying task.
    public var task: URLSessionTask { return delegate.task }

    /// The session belonging to the underlying task.
    public let session: URLSession

    /// The request sent or to be sent to the server.
    public var request: Foundation.URLRequest? { return task.originalRequest }

    /// The response received from the server, if any.
    public var response: HTTPURLResponse? { return task.response as? HTTPURLResponse }

    /// The progress of the request lifecycle.
    public var progress: Progress { return delegate.progress }

    var startTime: CFAbsoluteTime?
    var endTime: CFAbsoluteTime?

    // MARK: - Lifecycle

    init(session: URLSession, task: URLSessionTask) {
        self.session = session

        switch task {
        case is URLSessionUploadTask:
            delegate = UploadTaskDelegate(task: task)
        case is URLSessionDataTask:
            delegate = DataTaskDelegate(task: task)
        case is URLSessionDownloadTask:
            delegate = DownloadTaskDelegate(task: task)
        default:
            delegate = TaskDelegate(task: task)
        }

        delegate.queue.addOperation { self.endTime = CFAbsoluteTimeGetCurrent() }
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
        user: String,
        password: String,
        persistence: URLCredential.Persistence = .forSession)
        -> Self
    {
        let credential = URLCredential(user: user, password: password, persistence: persistence)

        return authenticate(usingCredential: credential)
    }

    /**
        Associates a specified credential with the request.

        - parameter credential: The credential.

        - returns: The request.
    */
    public func authenticate(usingCredential credential: URLCredential) -> Self {
        delegate.credential = credential

        return self
    }

    /**
        Returns a base64 encoded basic authentication credential as an authorization header dictionary.

        - parameter user:     The user.
        - parameter password: The password.

        - returns: A dictionary with Authorization key and credential value or empty dictionary if encoding fails.
    */
    public static func authorizationHeader(user: String, password: String) -> [String: String] {
        guard let data = "\(user):\(password)".data(using: String.Encoding.utf8) else { return [:] }

        let credential = data.base64EncodedString(options: [])

        return ["Authorization": "Basic \(credential)"]
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
    @discardableResult
    public func progress(_ closure: ((Int64, Int64, Int64) -> Void)? = nil) -> Self {
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
    @discardableResult
    public func stream(_ closure: ((Data) -> Void)? = nil) -> Self {
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
        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.Task.DidResume), object: task)
    }

    /**
        Suspends the request.
    */
    public func suspend() {
        task.suspend()
        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.Task.DidSuspend), object: task)
    }

    /**
        Cancels the request.
    */
    public func cancel() {
        if let downloadDelegate = delegate as? DownloadTaskDelegate,
           let downloadTask = downloadDelegate.downloadTask
        {
            downloadTask.cancel { data in
                downloadDelegate.resumeData = data
            }
        } else {
            task.cancel()
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.Task.DidCancel), object: task)
    }

    // MARK: - TaskDelegate

    /**
        The task delegate is responsible for handling all delegate callbacks for the underlying task as well as
        executing all operations attached to the serial operation queue upon task completion.
    */
    public class TaskDelegate: NSObject {

        /// The serial operation queue used to execute all operations after the task completes.
        public let queue: OperationQueue

        let task: URLSessionTask
        let progress: Progress

        var data: Data? { return nil }
        var error: NSError?

        var initialResponseTime: CFAbsoluteTime?
        var credential: URLCredential?

        init(task: URLSessionTask) {
            self.task = task
            self.progress = Progress(totalUnitCount: 0)
            self.queue = {
                let operationQueue = OperationQueue()

                operationQueue.maxConcurrentOperationCount = 1
                operationQueue.isSuspended = true
                operationQueue.qualityOfService = .utility

                return operationQueue
            }()
        }

        deinit {
            queue.cancelAllOperations()
            queue.isSuspended = false
        }

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        var taskWillPerformHTTPRedirection: ((Foundation.URLSession, URLSessionTask, HTTPURLResponse, Foundation.URLRequest) -> Foundation.URLRequest?)?
        var taskDidReceiveChallenge: ((Foundation.URLSession, URLSessionTask, URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?
        var taskNeedNewBodyStream: ((Foundation.URLSession, URLSessionTask) -> InputStream?)?
        var taskDidCompleteWithError: ((Foundation.URLSession, URLSessionTask, NSError?) -> Void)?

        // MARK: Delegate Methods

        // RDAR
        @objc(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
        func urlSession(
            _ session: Foundation.URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: Foundation.URLRequest,
            completionHandler: ((Foundation.URLRequest?) -> Void))
        {
            var redirectRequest: Foundation.URLRequest? = request

            if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
                redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
            }

            completionHandler(redirectRequest)
        }

        @objc(URLSession:task:didReceiveChallenge:completionHandler:)
        func urlSession(
            _ session: Foundation.URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: ((Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void))
        {
            var disposition: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?

            if let taskDidReceiveChallenge = taskDidReceiveChallenge {
                (disposition, credential) = taskDidReceiveChallenge(session, task, challenge)
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                let host = challenge.protectionSpace.host

                if let serverTrustPolicy = session.serverTrustPolicyManager?.serverTrustPolicyForHost(host),
                   let serverTrust = challenge.protectionSpace.serverTrust
                {
                    if serverTrustPolicy.evaluateServerTrust(serverTrust, isValidForHost: host) {
                        disposition = .useCredential
                        credential = URLCredential(trust: serverTrust)
                    } else {
                        disposition = .cancelAuthenticationChallenge
                    }
                }
            } else {
                if challenge.previousFailureCount > 0 {
                    disposition = .rejectProtectionSpace
                } else {
                    credential = self.credential ?? session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)

                    if credential != nil {
                        disposition = .useCredential
                    }
                }
            }

            completionHandler(disposition, credential)
        }

        @objc(URLSession:task:needNewBodyStream:)
        func urlSession(
            _ session: Foundation.URLSession,
            task: URLSessionTask,
            needNewBodyStream completionHandler: ((InputStream?) -> Void))
        {
            var bodyStream: InputStream?

            if let taskNeedNewBodyStream = taskNeedNewBodyStream {
                bodyStream = taskNeedNewBodyStream(session, task)
            }

            completionHandler(bodyStream)
        }

        @objc(URLSession:task:didCompleteWithError:)
        func urlSession(_ session: Foundation.URLSession, task: URLSessionTask, didCompleteWithError error: NSError?) {
            if let taskDidCompleteWithError = taskDidCompleteWithError {
                taskDidCompleteWithError(session, task, error)
            } else {
                if let error = error {
                    self.error = error

                    if let downloadDelegate = self as? DownloadTaskDelegate,
                       let userInfo = error.userInfo as? [String: AnyObject],
                       let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                    {
                        downloadDelegate.resumeData = resumeData
                    }
                }

                queue.isSuspended = false
            }
        }
    }

    // MARK: - DataTaskDelegate

    class DataTaskDelegate: TaskDelegate, URLSessionDataDelegate {
        var dataTask: URLSessionDataTask? { return task as? URLSessionDataTask }

        private var totalBytesReceived: Int64 = 0
        private var mutableData: NSMutableData
        override var data: Data? {
            if dataStream != nil {
                return nil
            } else {
                return mutableData as Data
            }
        }

        private var expectedContentLength: Int64?
        private var dataProgress: ((bytesReceived: Int64, totalBytesReceived: Int64, totalBytesExpectedToReceive: Int64) -> Void)?
        private var dataStream: ((data: Data) -> Void)?

        override init(task: URLSessionTask) {
            mutableData = NSMutableData()
            super.init(task: task)
        }

        // MARK: - NSURLSessionDataDelegate

        // MARK: Override Closures

        var dataTaskDidReceiveResponse: ((Foundation.URLSession, URLSessionDataTask, URLResponse) -> Foundation.URLSession.ResponseDisposition)?
        var dataTaskDidBecomeDownloadTask: ((Foundation.URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?
        var dataTaskDidReceiveData: ((Foundation.URLSession, URLSessionDataTask, Data) -> Void)?
        var dataTaskWillCacheResponse: ((Foundation.URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?

        // MARK: Delegate Methods

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: ((Foundation.URLSession.ResponseDisposition) -> Void))
        {
            var disposition: Foundation.URLSession.ResponseDisposition = .allow

            expectedContentLength = response.expectedContentLength

            if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
                disposition = dataTaskDidReceiveResponse(session, dataTask, response)
            }

            completionHandler(disposition)
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didBecome downloadTask: URLSessionDownloadTask)
        {
            dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }

            if let dataTaskDidReceiveData = dataTaskDidReceiveData {
                dataTaskDidReceiveData(session, dataTask, data)
            } else {
                if let dataStream = dataStream {
                    dataStream(data: data)
                } else {
                    mutableData.append(data)
                }

                totalBytesReceived += data.count
                let totalBytesExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown

                progress.totalUnitCount = totalBytesExpected
                progress.completedUnitCount = totalBytesReceived

                dataProgress?(
                    bytesReceived: Int64(data.count),
                    totalBytesReceived: totalBytesReceived,
                    totalBytesExpectedToReceive: totalBytesExpected
                )
            }
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            willCacheResponse proposedResponse: CachedURLResponse,
            completionHandler: ((CachedURLResponse?) -> Void))
        {
            var cachedResponse: CachedURLResponse? = proposedResponse

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

        if let HTTPMethod = request?.httpMethod {
            components.append(HTTPMethod)
        }

        if let URLString = request?.url?.absoluteString {
            components.append(URLString)
        }

        if let response = response {
            components.append("(\(response.statusCode))")
        }

        return components.joined(separator: " ")
    }
}

// MARK: - CustomDebugStringConvertible

extension Request: CustomDebugStringConvertible {
    func cURLRepresentation() -> String {
        var components = ["$ curl -i"]

        guard let request = self.request,
              let URL = request.url,
              let host = URL.host
        else {
            return "$ curl command could not be created"
        }

        if let httpMethod = request.httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }

        if let credentialStorage = self.session.configuration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: (URL as NSURL).port?.intValue ?? 0,
                protocol: URL.scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )

            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            } else {
                if let credential = delegate.credential {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            }
        }

        if session.configuration.httpShouldSetCookies {
            if let cookieStorage = session.configuration.httpCookieStorage,
               let cookies = cookieStorage.cookies(for: URL), !cookies.isEmpty
            {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value ?? String());" }
                components.append("-b \"\(string.substring(to: string.characters.index(before: string.endIndex)))\"")
            }
        }

        var headers: [NSObject: AnyObject] = [:]

        if let additionalHeaders = session.configuration.httpAdditionalHeaders {
            for (field, value) in additionalHeaders where field != "Cookie" {
                headers[field] = value
            }
        }

        if let headerFields = request.allHTTPHeaderFields {
            for (field, value) in headerFields where field != "Cookie" {
                headers[field] = value
            }
        }

        for (field, value) in headers {
            components.append("-H \"\(field): \(value)\"")
        }

        if let httpBodyData = request.httpBody,
           let httpBody = String(data: httpBodyData, encoding: String.Encoding.utf8)
        {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")

            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(URL.absoluteString!)\"")

        return components.joined(separator: " \\\n\t")
    }

    /// The textual representation used when written to an output stream, in the form of a cURL command.
    public var debugDescription: String {
        return cURLRepresentation()
    }
}
