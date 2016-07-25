//
//  Manager.swift
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
    Responsible for creating and managing `Request` objects, as well as their underlying `NSURLSession`.
*/
public class Manager {

    // MARK: - Properties

    /**
        A shared instance of `Manager`, used by top-level Alamofire request methods, and suitable for use directly
        for any ad hoc requests.
    */
    public static let sharedInstance: Manager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = Manager.defaultHTTPHeaders

        return Manager(configuration: configuration)
    }()

    /**
        Creates default values for the "Accept-Encoding", "Accept-Language" and "User-Agent" headers.
    */
    public static let defaultHTTPHeaders: [String: String] = {
        // Accept-Encoding HTTP Header; see https://tools.ietf.org/html/rfc7230#section-4.2.3
        let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"

        // Accept-Language HTTP Header; see https://tools.ietf.org/html/rfc7231#section-5.3.5
        let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(languageCode);q=\(quality)"
        }.joined(separator: ", ")

        // User-Agent Header; see https://tools.ietf.org/html/rfc7231#section-5.5.3
        let userAgent: String = {
            if let info = Bundle.main.infoDictionary {
                let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
                let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
                let version = info[kCFBundleVersionKey as String] as? String ?? "Unknown"

                let osNameVersion: String = {
                    let version = ProcessInfo.processInfo.operatingSystemVersion
                    let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

                    let osName: String = {
                        #if os(iOS)
                            return "iOS"
                        #elseif os(watchOS)
                            return "watchOS"
                        #elseif os(tvOS)
                            return "tvOS"
                        #elseif os(OSX)
                            return "OS X"
                        #elseif os(Linux)
                            return "Linux"
                        #else
                            return "Unknown"
                        #endif
                    }()

                    return "\(osName) \(versionString)"
                }()

                return "\(executable)/\(bundle) (\(version); \(osNameVersion))"
            }

            return "Alamofire"
        }()

        return [
            "Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent
        ]
    }()

    let queue = DispatchQueue(label: "Alamofire Manager Queue", attributes: DispatchQueueAttributes.serial)

    /// The underlying session.
    public let session: URLSession

    /// The session delegate handling all the task and session delegate callbacks.
    public let delegate: SessionDelegate

    /// Whether to start requests immediately after being constructed. `true` by default.
    public var startRequestsImmediately: Bool = true

    /**
        The background completion handler closure provided by the UIApplicationDelegate
        `application:handleEventsForBackgroundURLSession:completionHandler:` method. By setting the background
        completion handler, the SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` closure implementation
        will automatically call the handler.

        If you need to handle your own events before the handler is called, then you need to override the
        SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` and manually call the handler when finished.

        `nil` by default.
    */
    public var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Lifecycle

    /**
        Initializes the `Manager` instance with the specified configuration, delegate and server trust policy.

        - parameter configuration:            The configuration used to construct the managed session.
                                              `NSURLSessionConfiguration.defaultSessionConfiguration()` by default.
        - parameter delegate:                 The delegate used when initializing the session. `SessionDelegate()` by
                                              default.
        - parameter serverTrustPolicyManager: The server trust policy manager to use for evaluating all server trust
                                              challenges. `nil` by default.

        - returns: The new `Manager` instance.
    */
    public init(
        configuration: URLSessionConfiguration = URLSessionConfiguration.default,
        delegate: SessionDelegate = SessionDelegate(),
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
    {
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }

    /**
        Initializes the `Manager` instance with the specified session, delegate and server trust policy.

        - parameter session:                  The URL session.
        - parameter delegate:                 The delegate of the URL session. Must equal the URL session's delegate.
        - parameter serverTrustPolicyManager: The server trust policy manager to use for evaluating all server trust
                                              challenges. `nil` by default.

        - returns: The new `Manager` instance if the URL session's delegate matches the delegate parameter.
    */
    public init?(
        session: URLSession,
        delegate: SessionDelegate,
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
    {
        guard delegate === session.delegate else { return nil }

        self.delegate = delegate
        self.session = session

        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }

    private func commonInit(serverTrustPolicyManager: ServerTrustPolicyManager?) {
        session.serverTrustPolicyManager = serverTrustPolicyManager

        delegate.sessionDidFinishEventsForBackgroundURLSession = { [weak self] session in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async { strongSelf.backgroundCompletionHandler?() }
        }
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: - Request

    /**
        Creates a request for the specified method, URL string, parameters, parameter encoding and headers.

        - parameter method:     The HTTP method.
        - parameter URLString:  The URL string.
        - parameter parameters: The parameters. `nil` by default.
        - parameter encoding:   The parameter encoding. `.URL` by default.
        - parameter headers:    The HTTP headers. `nil` by default.

        - returns: The created request.
    */
    @discardableResult
    public func request(
        _ method: Method,
        _ URLString: URLStringConvertible,
        parameters: [String: AnyObject]? = nil,
        encoding: ParameterEncoding = .url,
        headers: [String: String]? = nil)
        -> Request
    {
        let mutableURLRequest = URLRequest(method, URLString, headers: headers)
        let encodedURLRequest = encoding.encode(mutableURLRequest, parameters: parameters).0
        return request(encodedURLRequest)
    }

    /**
        Creates a request for the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter URLRequest: The URL request

        - returns: The created request.
    */
    public func request(_ urlRequest: URLRequestConvertible) -> Request {
        var dataTask: URLSessionDataTask!
        queue.sync { dataTask = self.session.dataTask(with: urlRequest.urlRequest) }

        let request = Request(session: session, task: dataTask)
        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: - SessionDelegate

    /**
        Responsible for handling all delegate callbacks for the underlying session.
    */
    public class SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
        private var subdelegates: [Int: Request.TaskDelegate] = [:]
        private let subdelegateQueue = DispatchQueue(label: "Alamofire Sub Delegate Queue", attributes: DispatchQueueAttributes.concurrent)

        /// Access the task delegate for the specified task in a thread-safe manner.
        public subscript(task: URLSessionTask) -> Request.TaskDelegate? {
            get {
                var subdelegate: Request.TaskDelegate?
                subdelegateQueue.sync { subdelegate = self.subdelegates[task.taskIdentifier] }

                return subdelegate
            }
            set {
                subdelegateQueue.async { self.subdelegates[task.taskIdentifier] = newValue }
            }
        }

        /**
            Initializes the `SessionDelegate` instance.

            - returns: The new `SessionDelegate` instance.
        */
        public override init() {
            super.init()
        }

        // MARK: - NSURLSessionDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionDelegate method `URLSession:didBecomeInvalidWithError:`.
        public var sessionDidBecomeInvalidWithError: ((Foundation.URLSession, NSError?) -> Void)?

        /// Overrides default behavior for NSURLSessionDelegate method `URLSession:didReceiveChallenge:completionHandler:`.
        public var sessionDidReceiveChallenge: ((Foundation.URLSession, URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?

        /// Overrides all behavior for NSURLSessionDelegate method `URLSession:didReceiveChallenge:completionHandler:` and requires the caller to call the `completionHandler`.
        public var sessionDidReceiveChallengeWithCompletion: ((Foundation.URLSession, URLAuthenticationChallenge, (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?

        /// Overrides default behavior for NSURLSessionDelegate method `URLSessionDidFinishEventsForBackgroundURLSession:`.
        public var sessionDidFinishEventsForBackgroundURLSession: ((Foundation.URLSession) -> Void)?

        // MARK: Delegate Methods

        /**
            Tells the delegate that the session has been invalidated.

            - parameter session: The session object that was invalidated.
            - parameter error:   The error that caused invalidation, or nil if the invalidation was explicit.
        */
        public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: NSError?) {
            sessionDidBecomeInvalidWithError?(session, error)
        }

        /**
            Requests credentials from the delegate in response to a session-level authentication request from the remote server.

            - parameter session:           The session containing the task that requested authentication.
            - parameter challenge:         An object that contains the request for authentication.
            - parameter completionHandler: A handler that your delegate method must call providing the disposition and credential.
        */
        public func urlSession(
            _ session: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: ((Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void))
        {
            guard sessionDidReceiveChallengeWithCompletion == nil else {
                sessionDidReceiveChallengeWithCompletion?(session, challenge, completionHandler)
                return
            }

            var disposition: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?

            if let sessionDidReceiveChallenge = sessionDidReceiveChallenge {
                (disposition, credential) = sessionDidReceiveChallenge(session, challenge)
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
            }

            completionHandler(disposition, credential)
        }

        /**
            Tells the delegate that all messages enqueued for a session have been delivered.

            - parameter session: The session that no longer has any outstanding requests.
        */
#if !os(OSX)
        public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            sessionDidFinishEventsForBackgroundURLSession?(session)
        }
#endif

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:`.
        public var taskWillPerformHTTPRedirection: ((Foundation.URLSession, URLSessionTask, HTTPURLResponse, Foundation.URLRequest) -> Foundation.URLRequest?)?

        /// Overrides all behavior for NSURLSessionTaskDelegate method `URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:` and
        /// requires the caller to call the `completionHandler`.
        public var taskWillPerformHTTPRedirectionWithCompletion: ((Foundation.URLSession, URLSessionTask, HTTPURLResponse, Foundation.URLRequest, (Foundation.URLRequest?) -> Void) -> Void)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:didReceiveChallenge:completionHandler:`.
        public var taskDidReceiveChallenge: ((Foundation.URLSession, URLSessionTask, URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?

        /// Overrides all behavior for NSURLSessionTaskDelegate method `URLSession:task:didReceiveChallenge:completionHandler:` and
        /// requires the caller to call the `completionHandler`.
        public var taskDidReceiveChallengeWithCompletion: ((Foundation.URLSession, URLSessionTask, URLAuthenticationChallenge, (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:session:task:needNewBodyStream:`.
        public var taskNeedNewBodyStream: ((Foundation.URLSession, URLSessionTask) -> InputStream?)?

        /// Overrides all behavior for NSURLSessionTaskDelegate method `URLSession:session:task:needNewBodyStream:` and
        /// requires the caller to call the `completionHandler`.
        public var taskNeedNewBodyStreamWithCompletion: ((Foundation.URLSession, URLSessionTask, (InputStream?) -> Void) -> Void)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:`.
        public var taskDidSendBodyData: ((Foundation.URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:didCompleteWithError:`.
        public var taskDidComplete: ((Foundation.URLSession, URLSessionTask, NSError?) -> Void)?

        // MARK: Delegate Methods

        /**
            Tells the delegate that the remote server requested an HTTP redirect.

            - parameter session:           The session containing the task whose request resulted in a redirect.
            - parameter task:              The task whose request resulted in a redirect.
            - parameter response:          An object containing the server’s response to the original request.
            - parameter request:           A URL request object filled out with the new location.
            - parameter completionHandler: A closure that your handler should call with either the value of the request
                                           parameter, a modified URL request object, or NULL to refuse the redirect and
                                           return the body of the redirect response.
        */
        public func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: (URLRequest?) -> Void)
        {
            guard taskWillPerformHTTPRedirectionWithCompletion == nil else {
                taskWillPerformHTTPRedirectionWithCompletion?(session, task, response, request, completionHandler)
                return
            }

            var redirectRequest: Foundation.URLRequest? = request

            if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
                redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
            }

            completionHandler(redirectRequest)
        }

        /**
            Requests credentials from the delegate in response to an authentication request from the remote server.

            - parameter session:           The session containing the task whose request requires authentication.
            - parameter task:              The task whose request requires authentication.
            - parameter challenge:         An object that contains the request for authentication.
            - parameter completionHandler: A handler that your delegate method must call providing the disposition and credential.
        */
        public func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
        {
            guard taskDidReceiveChallengeWithCompletion == nil else {
                taskDidReceiveChallengeWithCompletion?(session, task, challenge, completionHandler)
                return
            }

            if let taskDidReceiveChallenge = taskDidReceiveChallenge {
                let result = taskDidReceiveChallenge(session, task, challenge)
                completionHandler(result.0, result.1)
            } else if let delegate = self[task] {
                delegate.urlSession(
                    session,
                    task: task,
                    didReceive: challenge,
                    completionHandler: completionHandler
                )
            } else {
                urlSession(session, didReceive: challenge, completionHandler: completionHandler)
            }
        }

        /**
            Tells the delegate when a task requires a new request body stream to send to the remote server.

            - parameter session:           The session containing the task that needs a new body stream.
            - parameter task:              The task that needs a new body stream.
            - parameter completionHandler: A completion handler that your delegate method should call with the new body stream.
        */
        public func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            needNewBodyStream completionHandler: (InputStream?) -> Void)
        {
            guard taskNeedNewBodyStreamWithCompletion == nil else {
                taskNeedNewBodyStreamWithCompletion?(session, task, completionHandler)
                return
            }

            if let taskNeedNewBodyStream = taskNeedNewBodyStream {
                completionHandler(taskNeedNewBodyStream(session, task))
            } else if let delegate = self[task] {
                delegate.urlSession(session, task: task, needNewBodyStream: completionHandler)
            }
        }

        /**
            Periodically informs the delegate of the progress of sending body content to the server.

            - parameter session:                  The session containing the data task.
            - parameter task:                     The data task.
            - parameter bytesSent:                The number of bytes sent since the last time this delegate method was called.
            - parameter totalBytesSent:           The total number of bytes sent so far.
            - parameter totalBytesExpectedToSend: The expected length of the body data.
        */
        public func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didSendBodyData bytesSent: Int64,
            totalBytesSent: Int64,
            totalBytesExpectedToSend: Int64)
        {
            if let taskDidSendBodyData = taskDidSendBodyData {
                taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
            } else if let delegate = self[task] as? Request.UploadTaskDelegate {
                delegate.URLSession(
                    session,
                    task: task,
                    didSendBodyData: bytesSent,
                    totalBytesSent: totalBytesSent,
                    totalBytesExpectedToSend: totalBytesExpectedToSend
                )
            }
        }

        /**
            Tells the delegate that the task finished transferring data.

            - parameter session: The session containing the task whose request finished transferring data.
            - parameter task:    The task whose request finished transferring data.
            - parameter error:   If an error occurred, an error object indicating how the transfer failed, otherwise nil.
        */
        public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: NSError?) {
            if let taskDidComplete = taskDidComplete {
                taskDidComplete(session, task, error)
            } else if let delegate = self[task] {
                delegate.urlSession(session, task: task, didCompleteWithError: error)
            }

            NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.Task.DidComplete), object: task)

            self[task] = nil
        }

        // MARK: - NSURLSessionDataDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didReceiveResponse:completionHandler:`.
        public var dataTaskDidReceiveResponse: ((Foundation.URLSession, URLSessionDataTask, URLResponse) -> Foundation.URLSession.ResponseDisposition)?

        /// Overrides all behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didReceiveResponse:completionHandler:` and
        /// requires caller to call the `completionHandler`.
        public var dataTaskDidReceiveResponseWithCompletion: ((Foundation.URLSession, URLSessionDataTask, URLResponse, (Foundation.URLSession.ResponseDisposition) -> Void) -> Void)?

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didBecomeDownloadTask:`.
        public var dataTaskDidBecomeDownloadTask: ((Foundation.URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didReceiveData:`.
        public var dataTaskDidReceiveData: ((Foundation.URLSession, URLSessionDataTask, Data) -> Void)?

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:willCacheResponse:completionHandler:`.
        public var dataTaskWillCacheResponse: ((Foundation.URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?

        /// Overrides all behavior for NSURLSessionDataDelegate method `URLSession:dataTask:willCacheResponse:completionHandler:` and
        /// requires caller to call the `completionHandler`.
        public var dataTaskWillCacheResponseWithCompletion: ((Foundation.URLSession, URLSessionDataTask, CachedURLResponse, (CachedURLResponse?) -> Void) -> Void)?

        // MARK: Delegate Methods

        /**
            Tells the delegate that the data task received the initial reply (headers) from the server.

            - parameter session:           The session containing the data task that received an initial reply.
            - parameter dataTask:          The data task that received an initial reply.
            - parameter response:          A URL response object populated with headers.
            - parameter completionHandler: A completion handler that your code calls to continue the transfer, passing a
                                           constant to indicate whether the transfer should continue as a data task or
                                           should become a download task.
        */
        public func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: (URLSession.ResponseDisposition) -> Void)
        {
            guard dataTaskDidReceiveResponseWithCompletion == nil else {
                dataTaskDidReceiveResponseWithCompletion?(session, dataTask, response, completionHandler)
                return
            }

            var disposition: Foundation.URLSession.ResponseDisposition = .allow

            if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
                disposition = dataTaskDidReceiveResponse(session, dataTask, response)
            }

            completionHandler(disposition)
        }

        /**
            Tells the delegate that the data task was changed to a download task.

            - parameter session:      The session containing the task that was replaced by a download task.
            - parameter dataTask:     The data task that was replaced by a download task.
            - parameter downloadTask: The new download task that replaced the data task.
        */
        public func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didBecome downloadTask: URLSessionDownloadTask)
        {
            if let dataTaskDidBecomeDownloadTask = dataTaskDidBecomeDownloadTask {
                dataTaskDidBecomeDownloadTask(session, dataTask, downloadTask)
            } else {
                let downloadDelegate = Request.DownloadTaskDelegate(task: downloadTask)
                self[downloadTask] = downloadDelegate
            }
        }

        /**
            Tells the delegate that the data task has received some of the expected data.

            - parameter session:  The session containing the data task that provided data.
            - parameter dataTask: The data task that provided data.
            - parameter data:     A data object containing the transferred data.
        */
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if let dataTaskDidReceiveData = dataTaskDidReceiveData {
                dataTaskDidReceiveData(session, dataTask, data)
            } else if let delegate = self[dataTask] as? Request.DataTaskDelegate {
                delegate.urlSession(session, dataTask: dataTask, didReceive: data)
            }
        }

        /**
            Asks the delegate whether the data (or upload) task should store the response in the cache.

            - parameter session:           The session containing the data (or upload) task.
            - parameter dataTask:          The data (or upload) task.
            - parameter proposedResponse:  The default caching behavior. This behavior is determined based on the current
                                           caching policy and the values of certain received headers, such as the Pragma
                                           and Cache-Control headers.
            - parameter completionHandler: A block that your handler must call, providing either the original proposed
                                           response, a modified version of that response, or NULL to prevent caching the
                                           response. If your delegate implements this method, it must call this completion
                                           handler; otherwise, your app leaks memory.
        */
        public func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            willCacheResponse proposedResponse: CachedURLResponse,
            completionHandler: (CachedURLResponse?) -> Void)
        {
            guard dataTaskWillCacheResponseWithCompletion == nil else {
                dataTaskWillCacheResponseWithCompletion?(session, dataTask, proposedResponse, completionHandler)
                return
            }

            if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
                completionHandler(dataTaskWillCacheResponse(session, dataTask, proposedResponse))
            } else if let delegate = self[dataTask] as? Request.DataTaskDelegate {
                delegate.urlSession(
                    session,
                    dataTask: dataTask,
                    willCacheResponse: proposedResponse,
                    completionHandler: completionHandler
                )
            } else {
                completionHandler(proposedResponse)
            }
        }

        // MARK: - NSURLSessionDownloadDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionDownloadDelegate method `URLSession:downloadTask:didFinishDownloadingToURL:`.
        public var downloadTaskDidFinishDownloadingToURL: ((Foundation.URLSession, URLSessionDownloadTask, URL) -> Void)?

        /// Overrides default behavior for NSURLSessionDownloadDelegate method `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:`.
        public var downloadTaskDidWriteData: ((Foundation.URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?

        /// Overrides default behavior for NSURLSessionDownloadDelegate method `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:`.
        public var downloadTaskDidResumeAtOffset: ((Foundation.URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?

        // MARK: Delegate Methods

        /**
            Tells the delegate that a download task has finished downloading.

            - parameter session:      The session containing the download task that finished.
            - parameter downloadTask: The download task that finished.
            - parameter location:     A file URL for the temporary file. Because the file is temporary, you must either
                                      open the file for reading or move it to a permanent location in your app’s sandbox
                                      container directory before returning from this delegate method.
        */
        public func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL)
        {
            if let downloadTaskDidFinishDownloadingToURL = downloadTaskDidFinishDownloadingToURL {
                downloadTaskDidFinishDownloadingToURL(session, downloadTask, location)
            } else if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                delegate.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
            }
        }

        /**
            Periodically informs the delegate about the download’s progress.

            - parameter session:                   The session containing the download task.
            - parameter downloadTask:              The download task.
            - parameter bytesWritten:              The number of bytes transferred since the last time this delegate
                                                   method was called.
            - parameter totalBytesWritten:         The total number of bytes transferred so far.
            - parameter totalBytesExpectedToWrite: The expected length of the file, as provided by the Content-Length
                                                   header. If this header was not provided, the value is
                                                   `NSURLSessionTransferSizeUnknown`.
        */
        public func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64)
        {
            if let downloadTaskDidWriteData = downloadTaskDidWriteData {
                downloadTaskDidWriteData(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
            } else if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                delegate.urlSession(
                    session,
                    downloadTask: downloadTask,
                    didWriteData: bytesWritten,
                    totalBytesWritten: totalBytesWritten,
                    totalBytesExpectedToWrite: totalBytesExpectedToWrite
                )
            }
        }

        /**
            Tells the delegate that the download task has resumed downloading.

            - parameter session:            The session containing the download task that finished.
            - parameter downloadTask:       The download task that resumed. See explanation in the discussion.
            - parameter fileOffset:         If the file's cache policy or last modified date prevents reuse of the
                                            existing content, then this value is zero. Otherwise, this value is an
                                            integer representing the number of bytes on disk that do not need to be
                                            retrieved again.
            - parameter expectedTotalBytes: The expected length of the file, as provided by the Content-Length header.
                                            If this header was not provided, the value is NSURLSessionTransferSizeUnknown.
        */
        public func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didResumeAtOffset fileOffset: Int64,
            expectedTotalBytes: Int64)
        {
            if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
                downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
            } else if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                delegate.urlSession(
                    session,
                    downloadTask: downloadTask,
                    didResumeAtOffset: fileOffset,
                    expectedTotalBytes: expectedTotalBytes
                )
            }
        }

        // MARK: - NSURLSessionStreamDelegate

        var _streamTaskReadClosed: Any?
        var _streamTaskWriteClosed: Any?
        var _streamTaskBetterRouteDiscovered: Any?
        var _streamTaskDidBecomeInputStream: Any?

        // MARK: - NSObject

        public override func responds(to selector: Selector) -> Bool {
            #if !os(OSX)
                if selector == #selector(URLSessionDelegate.urlSessionDidFinishEvents(forBackgroundURLSession:)) {
                    return sessionDidFinishEventsForBackgroundURLSession != nil
                }
            #endif

            switch selector {
            case #selector(URLSessionDelegate.urlSession(_:didBecomeInvalidWithError:)):
                return sessionDidBecomeInvalidWithError != nil
            case #selector(URLSessionDelegate.urlSession(_:didReceive:completionHandler:)):
                return (sessionDidReceiveChallenge != nil  || sessionDidReceiveChallengeWithCompletion != nil)
            case #selector(URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)):
                return (taskWillPerformHTTPRedirection != nil || taskWillPerformHTTPRedirectionWithCompletion != nil)
            case #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)):
                return (dataTaskDidReceiveResponse != nil || dataTaskDidReceiveResponseWithCompletion != nil)
            default:
                return self.dynamicType.instancesRespond(to: selector)
            }
        }
    }
}
