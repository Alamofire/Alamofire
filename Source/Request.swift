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

/// Responsible for sending a request and receiving the response and associated data from the server, as well as
/// managing its underlying `URLSessionTask`.
open class Request {
    /// A closure executed once a request has successfully completed in order to determine where to move the temporary
    /// file written to during the download process. The closure takes two arguments: the temporary file URL and the URL
    /// response, and returns a single argument: the file URL where the temporary file should be moved.
    public typealias DownloadFileDestination = (URL, HTTPURLResponse) -> URL

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

    /// The resume data of the underlying download task if available after a failure.
    open var resumeData: Data? {
        var data: Data?

        if let delegate = delegate as? DownloadTaskDelegate {
            data = delegate.resumeData
        }

        return data
    }

    var startTime: CFAbsoluteTime?
    var endTime: CFAbsoluteTime?

    private var taskDelegate: TaskDelegate
    private var taskDelegateLock = NSLock()

    // MARK: Lifecycle

    init(session: URLSession, task: URLSessionTask) {
        self.session = session

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

    /// Returns a base64 encoded basic authentication credential as an authorization header dictionary.
    ///
    /// - parameter user:     The user.
    /// - parameter password: The password.
    ///
    /// - returns: A dictionary with Authorization key and credential value or empty dictionary if encoding fails.
    open static func authorizationHeaderFrom(user: String, password: String) -> [String: String] {
        guard let data = "\(user):\(password)".data(using: String.Encoding.utf8) else { return [:] }

        let credential = data.base64EncodedString(options: [])

        return ["Authorization": "Basic \(credential)"]
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

    /// Sets a closure to be called periodically during the lifecycle of the request as data is read from the server.
    ///
    /// This closure returns the bytes most recently received from the server, not including data from previous calls.
    /// If this closure is set, data will only be available within this closure, and will not be saved elsewhere. It is
    /// also important to note that the `response` closure will be called with nil `responseData`.
    ///
    /// - parameter closure: The code to be executed periodically during the lifecycle of the request.
    ///
    /// - returns: The request.
    @discardableResult
    open func stream(closure: ((Data) -> Void)? = nil) -> Self {
        if let dataDelegate = delegate as? DataTaskDelegate {
            dataDelegate.dataStream = closure
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
        if let downloadDelegate = delegate as? DownloadTaskDelegate, let downloadTask = downloadDelegate.downloadTask {
            downloadTask.cancel { data in
                downloadDelegate.resumeData = data
            }
        } else {
            task.cancel()
        }

        NotificationCenter.default.post(
            name: Notification.Name.Task.DidCancel,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }

    // MARK: Download Destination

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
            if
                let cookieStorage = session.configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: URL), !cookies.isEmpty
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

        components.append("\"\(URL.absoluteString)\"")

        return components.joined(separator: " \\\n\t")
    }
}
