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

/// A type that can inspect and optionally adapt a `URLRequest` in some manner if necessary.
public protocol RequestAdapter {
    /// Inspects and adapts the specified `URLRequest` in some manner if necessary and returns the result.
    ///
    /// - parameter urlRequest: The URL request to adapt.
    ///
    /// - returns: The adapted `URLRequest`.
    func adapt(_ urlRequest: URLRequest) -> URLRequest
}

// MARK: -

/// A closure executed when the `RequestRetrier` determines whether a `Request` should be retried or not.
public typealias RequestRetryCompletion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

/// A type that determines whether a request should be retried after being executed by the specified session manager
/// and encountering an error.
public protocol RequestRetrier {
    /// Determines whether the `Request` should be retried by calling the `completion` closure.
    ///
    /// This operation is fully asychronous. Any amount of time can be taken to determine whether the request needs
    /// to be retried. The one requirement is that the completion closure is called to ensure the request is properly
    /// cleaned up after.
    ///
    /// - parameter manager:    The session manager the request was executed on.
    /// - parameter request:    The request that failed due to the encountered error.
    /// - parameter error:      The error encountered when executing the request.
    /// - parameter completion: The completion closure to be executed when retry decision has been determined.
    func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: RequestRetryCompletion)
}

// MARK: -

protocol TaskConvertible {
    func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) -> URLSessionTask
}

// MARK: -

/// Responsible for sending a request and receiving the response and associated data from the server, as well as
/// managing its underlying `URLSessionTask`.
open class Request {

    // MARK: Properties

    /// The delegate for the underlying task.
    open internal(set) var delegate: TaskDelegate {
        get {
            taskDelegateLock.lock() ; defer { taskDelegateLock.unlock() }
            return taskDelegate
        }
        set {
            taskDelegateLock.lock() ; defer { taskDelegateLock.unlock() }
            taskDelegate = newValue
        }
    }

    /// The underlying task.
    open var task: URLSessionTask { return delegate.task }

    /// The session belonging to the underlying task.
    open let session: URLSession

    /// The request sent or to be sent to the server.
    open var request: URLRequest? { return task.originalRequest }

    /// The response received from the server, if any.
    open var response: HTTPURLResponse? { return task.response as? HTTPURLResponse }

    /// The progress of the request lifecycle.
    open var progress: Progress { return delegate.progress }

    let originalTask: TaskConvertible?

    var startTime: CFAbsoluteTime?
    var endTime: CFAbsoluteTime?

    var validations: [() -> Void] = []

    private var taskDelegate: TaskDelegate
    private var taskDelegateLock = NSLock()

    // MARK: Lifecycle

    init(session: URLSession, task: URLSessionTask, originalTask: TaskConvertible?) {
        self.session = session
        self.originalTask = originalTask

        switch task {
        case is URLSessionUploadTask:
            taskDelegate = UploadTaskDelegate(task: task)
        case is URLSessionDataTask:
            taskDelegate = DataTaskDelegate(task: task)
        case is URLSessionDownloadTask:
            taskDelegate = DownloadTaskDelegate(task: task)
        default:
            taskDelegate = TaskDelegate(task: task)
        }

        delegate.queue.addOperation { self.endTime = CFAbsoluteTimeGetCurrent() }
    }

    // MARK: Authentication

    /// Associates an HTTP Basic credential with the request.
    ///
    /// - parameter user:        The user.
    /// - parameter password:    The password.
    /// - parameter persistence: The URL credential persistence. `.ForSession` by default.
    ///
    /// - returns: The request.
    @discardableResult
    open func authenticate(
        user: String,
        password: String,
        persistence: URLCredential.Persistence = .forSession)
        -> Self
    {
        let credential = URLCredential(user: user, password: password, persistence: persistence)
        return authenticate(usingCredential: credential)
    }

    /// Associates a specified credential with the request.
    ///
    /// - parameter credential: The credential.
    ///
    /// - returns: The request.
    @discardableResult
    open func authenticate(usingCredential credential: URLCredential) -> Self {
        delegate.credential = credential
        return self
    }

    /// Returns a base64 encoded basic authentication credential as an authorization header tuple.
    ///
    /// - parameter user:     The user.
    /// - parameter password: The password.
    ///
    /// - returns: A tuple with Authorization header and credential value if encoding succeeds, `nil` otherwise.
    open static func authorizationHeaderFrom(user: String, password: String) -> (key: String, value: String)? {
        guard let data = "\(user):\(password)".data(using: .utf8) else { return nil }

        let credential = data.base64EncodedString(options: [])

        return (key: "Authorization", value: "Basic \(credential)")
    }

    // MARK: Progress

    /// Sets a closure to be called periodically during the lifecycle of the request as data is written to or read
    /// from the server.
    ///
    /// - For uploads, the progress closure returns the bytes written, total bytes written, and total bytes expected
    ///   to write.
    /// - For downloads and data tasks, the progress closure returns the bytes read, total bytes read, and total bytes
    ///   expected to read.
    ///
    /// - parameter closure: The code to be executed periodically during the lifecycle of the request.
    ///
    /// - returns: The request.
    @discardableResult
    open func progress(closure: ((Int64, Int64, Int64) -> Void)? = nil) -> Self {
        if let uploadDelegate = delegate as? UploadTaskDelegate {
            uploadDelegate.uploadProgress = closure
        } else if let dataDelegate = delegate as? DataTaskDelegate {
            dataDelegate.dataProgress = closure
        } else if let downloadDelegate = delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadProgress = closure
        }

        return self
    }

    // MARK: State

    /// Resumes the request.
    open func resume() {
        if startTime == nil { startTime = CFAbsoluteTimeGetCurrent() }

        task.resume()

        NotificationCenter.default.post(
            name: Notification.Name.Task.DidResume,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }

    /// Suspends the request.
    open func suspend() {
        task.suspend()

        NotificationCenter.default.post(
            name: Notification.Name.Task.DidSuspend,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }

    /// Cancels the request.
    open func cancel() {
        task.cancel()

        NotificationCenter.default.post(
            name: Notification.Name.Task.DidCancel,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }
}

// MARK: - CustomStringConvertible

extension Request: CustomStringConvertible {
    /// The textual representation used when written to an output stream, which includes the HTTP method and URL, as
    /// well as the response status code if a response has been received.
    open var description: String {
        var components: [String] = []

        if let HTTPMethod = request?.httpMethod {
            components.append(HTTPMethod)
        }

        if let urlString = request?.url?.absoluteString {
            components.append(urlString)
        }

        if let response = response {
            components.append("(\(response.statusCode))")
        }

        return components.joined(separator: " ")
    }
}

// MARK: - CustomDebugStringConvertible

extension Request: CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, in the form of a cURL command.
    open var debugDescription: String {
        return cURLRepresentation()
    }

    func cURLRepresentation() -> String {
        var components = ["$ curl -i"]

        guard let request = self.request,
              let url = request.url,
              let host = url.host
        else {
            return "$ curl command could not be created"
        }

        if let httpMethod = request.httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }

        if let credentialStorage = self.session.configuration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: url.port ?? 0,
                protocol: url.scheme,
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
            if
                let cookieStorage = session.configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty
            {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value);" }
                components.append("-b \"\(string.substring(to: string.characters.index(before: string.endIndex)))\"")
            }
        }

        var headers: [AnyHashable: Any] = [:]

        if let additionalHeaders = session.configuration.httpAdditionalHeaders {
            for (field, value) in additionalHeaders where field != AnyHashable("Cookie") {
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

        if
            let httpBodyData = request.httpBody,
            let httpBody = String(data: httpBodyData, encoding: String.Encoding.utf8)
        {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")

            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(url.absoluteString)\"")

        return components.joined(separator: " \\\n\t")
    }
}

// MARK: -

/// Specific type of `Request` that manages an underlying `URLSessionDataTask`.
open class DataRequest: Request {
    enum Requestable: TaskConvertible {
        case request(URLRequest)

        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) -> URLSessionTask {
            var task: URLSessionTask!

            switch self {
            case let .request(urlRequest):
                let urlRequest = urlRequest.adapt(using: adapter)
                queue.sync { task = session.dataTask(with: urlRequest) }
            }

            return task
        }
    }

    var dataDelegate: DataTaskDelegate { return delegate as! DataTaskDelegate }

    /// Sets a closure to be called periodically during the lifecycle of the request as data is read from the server.
    ///
    /// This closure returns the bytes most recently received from the server, not including data from previous calls.
    /// If this closure is set, data will only be available within this closure, and will not be saved elsewhere. It is
    /// also important to note that the server data in any `Response` object will be `nil`.
    ///
    /// - parameter closure: The code to be executed periodically during the lifecycle of the request.
    ///
    /// - returns: The request.
    @discardableResult
    open func stream(closure: ((Data) -> Void)? = nil) -> Self {
        dataDelegate.dataStream = closure
        return self
    }
}

// MARK: -

/// Specific type of `Request` that manages an underlying `URLSessionDownloadTask`.
open class DownloadRequest: Request {
    /// A closure executed once a request has successfully completed in order to determine where to move the temporary
    /// file written to during the download process. The closure takes two arguments: the temporary file URL and the URL
    /// response, and returns a single argument: the file URL where the temporary file should be moved.
    public typealias DownloadFileDestination = (URL, HTTPURLResponse) -> URL

    enum Downloadable: TaskConvertible {
        case request(URLRequest)
        case resumeData(Data)

        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) -> URLSessionTask {
            var task: URLSessionTask!

            switch self {
            case let .request(urlRequest):
                let urlRequest = urlRequest.adapt(using: adapter)
                queue.sync { task = session.downloadTask(with: urlRequest) }
            case let .resumeData(resumeData):
                queue.sync { task = session.downloadTask(withResumeData: resumeData) }
            }

            return task
        }
    }

    /// The resume data of the underlying download task if available after a failure.
    open var resumeData: Data? { return downloadDelegate.resumeData }

    var downloadDelegate: DownloadTaskDelegate { return delegate as! DownloadTaskDelegate }

    /// Cancels the request.
    open override func cancel() {
        downloadDelegate.downloadTask.cancel { self.downloadDelegate.resumeData = $0 }

        NotificationCenter.default.post(
            name: Notification.Name.Task.DidCancel,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }

    /// Creates a download file destination closure which uses the default file manager to move the temporary file to a
    /// file URL in the first available directory with the specified search path directory and search path domain mask.
    ///
    /// - parameter directory: The search path directory. `.DocumentDirectory` by default.
    /// - parameter domain:    The search path domain mask. `.UserDomainMask` by default.
    ///
    /// - returns: A download file destination closure.
    open class func suggestedDownloadDestination(
        for directory: FileManager.SearchPathDirectory = .documentDirectory,
        in domain: FileManager.SearchPathDomainMask = .userDomainMask)
        -> DownloadFileDestination
    {
        return { temporaryURL, response -> URL in
            let directoryURLs = FileManager.default.urls(for: directory, in: domain)

            if !directoryURLs.isEmpty {
                return directoryURLs[0].appendingPathComponent(response.suggestedFilename!)
            }

            return temporaryURL
        }
    }
}

// MARK: -

/// Specific type of `Request` that manages an underlying `URLSessionUploadTask`.
open class UploadRequest: DataRequest {
    enum Uploadable: TaskConvertible {
        case data(Data, URLRequest)
        case file(URL, URLRequest)
        case stream(InputStream, URLRequest)

        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) -> URLSessionTask {
            var task: URLSessionTask!

            switch self {
            case let .data(data, urlRequest):
                let urlRequest = urlRequest.adapt(using: adapter)
                queue.sync { task = session.uploadTask(with: urlRequest, from: data) }
            case let .file(url, urlRequest):
                let urlRequest = urlRequest.adapt(using: adapter)
                queue.sync { task = session.uploadTask(with: urlRequest, fromFile: url) }
            case let .stream(_, urlRequest):
                let urlRequest = urlRequest.adapt(using: adapter)
                queue.sync { task = session.uploadTask(withStreamedRequest: urlRequest) }
            }

            return task
        }
    }

    var uploadDelegate: UploadTaskDelegate { return delegate as! UploadTaskDelegate }
}

// MARK: -

#if !os(watchOS)

/// Specific type of `Request` that manages an underlying `URLSessionStreamTask`.
open class StreamRequest: Request {
    enum Streamable: TaskConvertible {
        case stream(String, Int)
        case netService(NetService)

        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) -> URLSessionTask {
            var task: URLSessionTask!

            switch self {
            case let .stream(hostName, port):
                queue.sync { task = session.streamTask(withHostName: hostName, port: port) }
            case let .netService(netService):
                queue.sync { task = session.streamTask(with: netService) }
            }
            
            return task
        }
    }
}
    
#endif
