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
    Responsible for creating and managing `Request` objects, as well as their underlying `NSURLSession`.
*/
public class Manager {

    // MARK: - Properties

    /**
        A shared instance of `Manager`, used by top-level Alamofire request methods, and suitable for use directly for any ad hoc requests.
    */
    public static let sharedInstance: Manager = {
        let configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders

        return Manager(configuration: configuration)
    }()

    /**
        Creates default values for the "Accept-Encoding", "Accept-Language" and "User-Agent" headers.

        :returns: The default header values.
    */
    public static let defaultHTTPHeaders: [String: String] = {
        // Accept-Encoding HTTP Header; see http://tools.ietf.org/html/rfc7230#section-4.2.3
        let acceptEncoding: String = "gzip;q=1.0,compress;q=0.5"

        // Accept-Language HTTP Header; see http://tools.ietf.org/html/rfc7231#section-5.3.5
        let acceptLanguage: String = {
            var components: [String] = []
            for (index, languageCode) in enumerate(NSLocale.preferredLanguages() as! [String]) {
                let q = 1.0 - (Double(index) * 0.1)
                components.append("\(languageCode);q=\(q)")
                if q <= 0.5 {
                    break
                }
            }

            return join(",", components)
        }()

        // User-Agent Header; see http://tools.ietf.org/html/rfc7231#section-5.5.3
        let userAgent: String = {
            if let info = NSBundle.mainBundle().infoDictionary {
                let executable: AnyObject = info[kCFBundleExecutableKey] ?? "Unknown"
                let bundle: AnyObject = info[kCFBundleIdentifierKey] ?? "Unknown"
                let version: AnyObject = info[kCFBundleVersionKey] ?? "Unknown"
                let os: AnyObject = NSProcessInfo.processInfo().operatingSystemVersionString ?? "Unknown"

                var mutableUserAgent = NSMutableString(string: "\(executable)/\(bundle) (\(version); OS \(os))") as CFMutableString
                let transform = NSString(string: "Any-Latin; Latin-ASCII; [:^ASCII:] Remove") as CFString
                if CFStringTransform(mutableUserAgent, nil, transform, 0) == 1 {
                    return mutableUserAgent as NSString as! String
                }
            }

            return "Alamofire"
        }()

        return [
            "Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent
        ]
    }()

    let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)

    /// The underlying session.
    public let session: NSURLSession

    /// The session delegate handling all the task and session delegate callbacks.
    public let delegate: SessionDelegate

    /// Whether to start requests immediately after being constructed. `true` by default.
    public var startRequestsImmediately: Bool = true

    /// The background completion handler closure provided by the UIApplicationDelegate `application:handleEventsForBackgroundURLSession:completionHandler:` method. By setting the background completion handler, the SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` closure implementation will automatically call the handler. If you need to handle your own events before the handler is called, then you need to override the SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` and manually call the handler when finished. `nil` by default.
    public var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Lifecycle

    /**
        :param: configuration The configuration used to construct the managed session.
    */
    required public init(configuration: NSURLSessionConfiguration? = nil) {
        self.delegate = SessionDelegate()
        self.session = NSURLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        self.delegate.sessionDidFinishEventsForBackgroundURLSession = { [weak self] session in
            if let strongSelf = self {
                strongSelf.backgroundCompletionHandler?()
            }
        }
    }

    deinit {
        self.session.invalidateAndCancel()
    }

    // MARK: - Request

    /**
        Creates a request for the specified method, URL string, parameters, and parameter encoding.

        :param: method The HTTP method.
        :param: URLString The URL string.
        :param: parameters The parameters. `nil` by default.
        :param: encoding The parameter encoding. `.URL` by default.

        :returns: The created request.
    */
    public func request(method: Method, _ URLString: URLStringConvertible, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL) -> Request {
        return request(encoding.encode(URLRequest(method, URLString), parameters: parameters).0)
    }

    /**
        Creates a request for the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request

        :returns: The created request.
    */
    public func request(URLRequest: URLRequestConvertible) -> Request {
        var dataTask: NSURLSessionDataTask?
        dispatch_sync(queue) {
            dataTask = self.session.dataTaskWithRequest(URLRequest.URLRequest)
        }

        let request = Request(session: session, task: dataTask!)
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
    public final class SessionDelegate: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate {
        private var subdelegates: [Int: Request.TaskDelegate] = [:]
        private let subdelegateQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)

        subscript(task: NSURLSessionTask) -> Request.TaskDelegate? {
            get {
                var subdelegate: Request.TaskDelegate?
                dispatch_sync(subdelegateQueue) {
                    subdelegate = self.subdelegates[task.taskIdentifier]
                }

                return subdelegate
            }

            set {
                dispatch_barrier_async(subdelegateQueue) {
                    self.subdelegates[task.taskIdentifier] = newValue
                }
            }
        }

        // MARK: - NSURLSessionDelegate

        // MARK: Override Closures

        /// NSURLSessionDelegate override closure for `URLSession:didBecomeInvalidWithError:` method.
        public var sessionDidBecomeInvalidWithError: ((NSURLSession, NSError?) -> Void)?

        /// NSURLSessionDelegate override closure for `URLSession:didReceiveChallenge:completionHandler:` method.
        public var sessionDidReceiveChallenge: ((NSURLSession, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential!))?

        /// NSURLSessionDelegate override closure for `URLSessionDidFinishEventsForBackgroundURLSession:` method.
        public var sessionDidFinishEventsForBackgroundURLSession: ((NSURLSession) -> Void)?

        // MARK: Delegate Methods

        public func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
            sessionDidBecomeInvalidWithError?(session, error)
        }

        public func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)) {
            if sessionDidReceiveChallenge != nil {
                completionHandler(sessionDidReceiveChallenge!(session, challenge))
            } else {
                completionHandler(.PerformDefaultHandling, nil)
            }
        }

        public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
            sessionDidFinishEventsForBackgroundURLSession?(session)
        }

        // MARK: - NSURLSessionTaskDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:`.
        public var taskWillPerformHTTPRedirection: ((NSURLSession, NSURLSessionTask, NSHTTPURLResponse, NSURLRequest) -> NSURLRequest?)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:didReceiveChallenge:completionHandler:`.
        public var taskDidReceiveChallenge: ((NSURLSession, NSURLSessionTask, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential!))?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:session:task:needNewBodyStream:`.
        public var taskNeedNewBodyStream: ((NSURLSession, NSURLSessionTask) -> NSInputStream!)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:`.
        public var taskDidSendBodyData: ((NSURLSession, NSURLSessionTask, Int64, Int64, Int64) -> Void)?

        /// Overrides default behavior for NSURLSessionTaskDelegate method `URLSession:task:didCompleteWithError:`.
        public var taskDidComplete: ((NSURLSession, NSURLSessionTask, NSError?) -> Void)?

        // MARK: Delegate Methods

        public func URLSession(session: NSURLSession, task: NSURLSessionTask, willPerformHTTPRedirection response: NSHTTPURLResponse, newRequest request: NSURLRequest, completionHandler: ((NSURLRequest!) -> Void)) {
            var redirectRequest: NSURLRequest? = request

            if taskWillPerformHTTPRedirection != nil {
                redirectRequest = taskWillPerformHTTPRedirection!(session, task, response, request)
            }

            completionHandler(redirectRequest)
        }

        public func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)) {
            if taskDidReceiveChallenge != nil {
                completionHandler(taskDidReceiveChallenge!(session, task, challenge))
            } else if let delegate = self[task] {
                delegate.URLSession(session, task: task, didReceiveChallenge: challenge, completionHandler: completionHandler)
            } else {
                URLSession(session, didReceiveChallenge: challenge, completionHandler: completionHandler)
            }
        }

        public func URLSession(session: NSURLSession, task: NSURLSessionTask, needNewBodyStream completionHandler: ((NSInputStream!) -> Void)) {
            if taskNeedNewBodyStream != nil {
                completionHandler(taskNeedNewBodyStream!(session, task))
            } else if let delegate = self[task] {
                delegate.URLSession(session, task: task, needNewBodyStream: completionHandler)
            }
        }

        public func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            if taskDidSendBodyData != nil {
                taskDidSendBodyData!(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
            } else if let delegate = self[task] as? Request.UploadTaskDelegate {
                delegate.URLSession(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
            }
        }

        public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
            if taskDidComplete != nil {
                taskDidComplete!(session, task, error)
            } else if let delegate = self[task] {
                delegate.URLSession(session, task: task, didCompleteWithError: error)

                self[task] = nil
            }
        }

        // MARK: - NSURLSessionDataDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didReceiveResponse:completionHandler:`.
        public var dataTaskDidReceiveResponse: ((NSURLSession, NSURLSessionDataTask, NSURLResponse) -> NSURLSessionResponseDisposition)?

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didBecomeDownloadTask:`.
        public var dataTaskDidBecomeDownloadTask: ((NSURLSession, NSURLSessionDataTask, NSURLSessionDownloadTask) -> Void)?

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:didReceiveData:`.
        public var dataTaskDidReceiveData: ((NSURLSession, NSURLSessionDataTask, NSData) -> Void)?

        /// Overrides default behavior for NSURLSessionDataDelegate method `URLSession:dataTask:willCacheResponse:completionHandler:`.
        public var dataTaskWillCacheResponse: ((NSURLSession, NSURLSessionDataTask, NSCachedURLResponse) -> NSCachedURLResponse!)?

        // MARK: Delegate Methods

        public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
            var disposition: NSURLSessionResponseDisposition = .Allow

            if dataTaskDidReceiveResponse != nil {
                disposition = dataTaskDidReceiveResponse!(session, dataTask, response)
            }

            completionHandler(disposition)
        }

        public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask) {
            if dataTaskDidBecomeDownloadTask != nil {
                dataTaskDidBecomeDownloadTask!(session, dataTask, downloadTask)
            } else {
                let downloadDelegate = Request.DownloadTaskDelegate(task: downloadTask)
                self[downloadTask] = downloadDelegate
            }
        }

        public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
            if dataTaskDidReceiveData != nil {
                dataTaskDidReceiveData!(session, dataTask, data)
            } else if let delegate = self[dataTask] as? Request.DataTaskDelegate {
                delegate.URLSession(session, dataTask: dataTask, didReceiveData: data)
            }
        }

        public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, willCacheResponse proposedResponse: NSCachedURLResponse, completionHandler: ((NSCachedURLResponse!) -> Void)) {
            if dataTaskWillCacheResponse != nil {
                completionHandler(dataTaskWillCacheResponse!(session, dataTask, proposedResponse))
            } else if let delegate = self[dataTask] as? Request.DataTaskDelegate {
                delegate.URLSession(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler)
            } else {
                completionHandler(proposedResponse)
            }
        }

        // MARK: - NSURLSessionDownloadDelegate

        // MARK: Override Closures

        /// Overrides default behavior for NSURLSessionDownloadDelegate method `URLSession:downloadTask:didFinishDownloadingToURL:`.
        public var downloadTaskDidFinishDownloadingToURL: ((NSURLSession, NSURLSessionDownloadTask, NSURL) -> Void)?

        /// Overrides default behavior for NSURLSessionDownloadDelegate method `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:`.
        public var downloadTaskDidWriteData: ((NSURLSession, NSURLSessionDownloadTask, Int64, Int64, Int64) -> Void)?

        /// Overrides default behavior for NSURLSessionDownloadDelegate method `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:`.
        public var downloadTaskDidResumeAtOffset: ((NSURLSession, NSURLSessionDownloadTask, Int64, Int64) -> Void)?

        // MARK: Delegate Methods

        public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
            if downloadTaskDidFinishDownloadingToURL != nil {
                downloadTaskDidFinishDownloadingToURL!(session, downloadTask, location)
            } else if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                delegate.URLSession(session, downloadTask: downloadTask, didFinishDownloadingToURL: location)
            }
        }

        public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            if downloadTaskDidWriteData != nil {
                downloadTaskDidWriteData!(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
            } else if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                delegate.URLSession(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
            }
        }

        public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
            if downloadTaskDidResumeAtOffset != nil {
                downloadTaskDidResumeAtOffset!(session, downloadTask, fileOffset, expectedTotalBytes)
            } else if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                delegate.URLSession(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
            }
        }

        // MARK: - NSObject

        public override func respondsToSelector(selector: Selector) -> Bool {
            switch selector {
            case "URLSession:didBecomeInvalidWithError:":
                return (sessionDidBecomeInvalidWithError != nil)
            case "URLSession:didReceiveChallenge:completionHandler:":
                return (sessionDidReceiveChallenge != nil)
            case "URLSessionDidFinishEventsForBackgroundURLSession:":
                return (sessionDidFinishEventsForBackgroundURLSession != nil)
            case "URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:":
                return (taskWillPerformHTTPRedirection != nil)
            case "URLSession:dataTask:didReceiveResponse:completionHandler:":
                return (dataTaskDidReceiveResponse != nil)
            case "URLSession:dataTask:willCacheResponse:completionHandler:":
                return (dataTaskWillCacheResponse != nil)
            default:
                return self.dynamicType.instancesRespondToSelector(selector)
            }
        }
    }
}
