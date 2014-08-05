// Alamofire.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
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

public struct Alamofire {

    // HTTP Method Definitions; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html
    public enum Method: String {
        case OPTIONS = "OPTIONS"
        case GET = "GET"
        case HEAD = "HEAD"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
        case TRACE = "TRACE"
        case CONNECT = "CONNECT"
    }

    public enum ParameterEncoding {
        case URL
        case JSON(options: NSJSONWritingOptions)
        case PropertyList(format: NSPropertyListFormat, options: NSPropertyListWriteOptions)

        func encode(request: NSURLRequest, parameters: [String: AnyObject]?) -> (NSURLRequest, NSError?) {
            if parameters == nil {
                return (request, nil)
            }

            var mutableRequest: NSMutableURLRequest! = request.mutableCopy() as NSMutableURLRequest
            var error: NSError? = nil

            switch self {
            case .URL:
                func query(parameters: [String: AnyObject]) -> String! {
                    func queryComponents(key: String, value: AnyObject) -> [(String, String)] {
                        func dictionaryQueryComponents(key: String, dictionary: [String: AnyObject]) -> [(String, String)] {
                            var components: [(String, String)] = []
                            for (nestedKey, value) in dictionary {
                                components += queryComponents("\(key)[\(nestedKey)]", value)
                            }

                            return components
                        }

                        func arrayQueryComponents(key: String, array: [AnyObject]) -> [(String, String)] {
                            var components: [(String, String)] = []
                            for value in array {
                                components += queryComponents("\(key)[]", value)
                            }

                            return components
                        }

                        var components: [(String, String)] = []
                        if let dictionary = value as? [String: AnyObject] {
                            components += dictionaryQueryComponents(key, dictionary)
                        } else if let array = value as? [AnyObject] {
                            components += arrayQueryComponents(key, array)
                        } else {
                            components.append(key, "\(value)")
                        }

                        return components
                    }

                    var components: [(String, String)] = []
                    for key in sorted(Array(parameters.keys), <) {
                        let value: AnyObject! = parameters[key]
                        components += queryComponents(key, value)
                    }

                    return join("&", components.map{"\($0)=\($1)"} as [String])
                }

                func encodesParametersInURL(method: Method) -> Bool {
                    switch method {
                    case .GET, .HEAD, .DELETE:
                        return true
                    default:
                        return false
                    }
                }

                if encodesParametersInURL(Method.fromRaw(request.HTTPMethod)!) {
                    let URLComponents = NSURLComponents(URL: mutableRequest.URL, resolvingAgainstBaseURL: false)
                    URLComponents.query = (URLComponents.query ? URLComponents.query + "&" : "") + query(parameters!)
                    mutableRequest.URL = URLComponents.URL
                } else {
                    if !mutableRequest.valueForHTTPHeaderField("Content-Type") {
                        mutableRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    }

                    mutableRequest.HTTPBody = query(parameters!).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                }

            case .JSON(let options):
                let data = NSJSONSerialization.dataWithJSONObject(parameters, options: options, error: &error)

                if data {
                    let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
                    mutableRequest.setValue("application/json; charset=\(charset)", forHTTPHeaderField: "Content-Type")
                    mutableRequest.HTTPBody = data
                }
            case .PropertyList(let (format, options)):
                let data = NSPropertyListSerialization.dataWithPropertyList(parameters, format: format, options: options, error: &error)

                if data {
                    let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
                    mutableRequest.setValue("application/x-plist; charset=\(charset)", forHTTPHeaderField: "Content-Type")
                    mutableRequest.HTTPBody = data
                }
            }

            return (mutableRequest, error)
        }
    }

    // MARK: -

    class Manager {
        class var sharedInstance: Manager {
            struct Singleton {
                static let instance = Manager()
            }

            return Singleton.instance
        }

        let delegate: SessionDelegate
        let session: NSURLSession!
        let operationQueue: NSOperationQueue = NSOperationQueue()

        var automaticallyStartsRequests: Bool = true

        lazy var defaultHeaders: [String: String] = {
            // Accept-Encoding HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.3
            let acceptEncoding: String = "gzip;q=1.0,compress;q=0.5"

            // Accept-Language HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
            let acceptLanguage: String = {
                var components: [String] = []
                for (index, languageCode) in enumerate(NSLocale.preferredLanguages() as [String]) {
                    let q = 1.0 - (Double(index) * 0.1)
                    components.append("\(languageCode);q=\(q)")
                    if q <= 0.5 {
                        break
                    }
                }

                return components.reduce("", {$0 == "" ? $1 : "\($0),\($1)"})
            }()

            // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
            let userAgent: String = {
                if let info = NSBundle.mainBundle().infoDictionary {
                    let executable: AnyObject? = info[kCFBundleExecutableKey]
                    let bundle: AnyObject? = info[kCFBundleIdentifierKey]
                    let version: AnyObject? = info[kCFBundleVersionKey]
                    let os: AnyObject? = NSProcessInfo.processInfo()?.operatingSystemVersionString

                    var mutableUserAgent = NSMutableString(string: "\(executable!)/\(bundle!) (\(version!); OS \(os!))") as CFMutableString
                    let transform = NSString(string: "Any-Latin; Latin-ASCII; [:^ASCII:] Remove") as CFString
                    if CFStringTransform(mutableUserAgent, nil, transform, 0) == 1 {
                        return mutableUserAgent as NSString
                    }
                }

                return "Alamofire"
            }()

            return ["Accept-Encoding": acceptEncoding,
                    "Accept-Language": acceptLanguage,
                    "User-Agent": userAgent]
        }()

        required init(configuration: NSURLSessionConfiguration! = nil) {
            self.delegate = SessionDelegate()
            self.session = NSURLSession(configuration: configuration, delegate: self.delegate, delegateQueue: self.operationQueue)
        }

        deinit {
            self.session.invalidateAndCancel()
        }

        // MARK: -

        func request(request: NSURLRequest) -> Request {
            var mutableRequest: NSMutableURLRequest! = request.mutableCopy() as NSMutableURLRequest

            for (field, value) in self.defaultHeaders {
                if !mutableRequest.valueForHTTPHeaderField(field){
                    mutableRequest.setValue(value, forHTTPHeaderField: field)
                }
            }

            var dataTask: NSURLSessionDataTask?
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                dataTask = self.session.dataTaskWithRequest(mutableRequest)
            }

            let request = Request(session: self.session, task: dataTask!)
            self.delegate[request.delegate.task] = request.delegate
            request.resume()

            return request
        }

        class SessionDelegate: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate {
            private var subdelegates: [Int: Request.TaskDelegate]
            private subscript(task: NSURLSessionTask) -> Request.TaskDelegate? {
                get {
                    return self.subdelegates[task.taskIdentifier]
                }

                set(newValue) {
                    self.subdelegates[task.taskIdentifier] = newValue
                }
            }

            var sessionDidBecomeInvalidWithError: ((NSURLSession!, NSError!) -> Void)?
            var sessionDidFinishEventsForBackgroundURLSession: ((NSURLSession!) -> Void)?
            var sessionDidReceiveChallenge: ((NSURLSession!, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential!))?

            var taskWillPerformHTTPRedirection: ((NSURLSession!, NSURLSessionTask!, NSHTTPURLResponse!, NSURLRequest!) -> (NSURLRequest!))?
            var taskDidReceiveChallenge: ((NSURLSession!, NSURLSessionTask!, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential?))?
            var taskDidSendBodyData: ((NSURLSession!, NSURLSessionTask!, Int64, Int64, Int64) -> Void)?
            var taskNeedNewBodyStream: ((NSURLSession!, NSURLSessionTask!) -> (NSInputStream!))?

            var dataTaskDidReceiveResponse: ((NSURLSession!, NSURLSessionDataTask!, NSURLResponse!) -> (NSURLSessionResponseDisposition))?
            var dataTaskDidBecomeDownloadTask: ((NSURLSession!, NSURLSessionDataTask!) -> Void)?
            var dataTaskDidReceiveData: ((NSURLSession!, NSURLSessionDataTask!, NSData!) -> Void)?
            var dataTaskWillCacheResponse: ((NSURLSession!, NSURLSessionDataTask!, NSCachedURLResponse!) -> (NSCachedURLResponse))?

            var downloadTaskDidFinishDownloadingToURL: ((NSURLSession!, NSURLSessionDownloadTask!, NSURL) -> (NSURL))?
            var downloadTaskDidWriteData: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64, Int64) -> Void)?
            var downloadTaskDidResumeAtOffset: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64) -> Void)?

            required override init() {
                self.subdelegates = Dictionary()
                super.init()
            }

            // MARK: NSURLSessionDelegate

            func URLSession(session: NSURLSession!, didBecomeInvalidWithError error: NSError!) {
                self.sessionDidBecomeInvalidWithError?(session, error)
            }

            func URLSession(session: NSURLSession!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
                if self.sessionDidReceiveChallenge != nil {
                    completionHandler(self.sessionDidReceiveChallenge!(session, challenge))
                } else {
                    completionHandler(.PerformDefaultHandling, nil)
                }
            }

            func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession!) {
                self.sessionDidFinishEventsForBackgroundURLSession?(session)
            }

            // MARK: NSURLSessionTaskDelegate

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, willPerformHTTPRedirection response: NSHTTPURLResponse!, newRequest request: NSURLRequest!, completionHandler: ((NSURLRequest!) -> Void)!) {
                var redirectRequest = request
                if self.taskWillPerformHTTPRedirection != nil {
                    redirectRequest = self.taskWillPerformHTTPRedirection!(session, task, response, request)
                }

                completionHandler(redirectRequest)
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
                if let delegate = self[task] {
                    delegate.URLSession(session, task: task, didReceiveChallenge: challenge, completionHandler: completionHandler)
                } else {
                    self.URLSession(session, didReceiveChallenge: challenge, completionHandler: completionHandler)
                }
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, needNewBodyStream completionHandler: ((NSInputStream!) -> Void)!) {
                if let delegate = self[task] {
                    delegate.URLSession(session, task: task, needNewBodyStream: completionHandler)
                }
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
                if let delegate = self[task] as? Request.UploadTaskDelegate {
                    delegate.URLSession(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
                }
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didCompleteWithError error: NSError!) {
                if let delegate = self[task] {
                    delegate.URLSession(session, task: task, didCompleteWithError: error)
                }
            }

            // MARK: NSURLSessionDataDelegate

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveResponse response: NSURLResponse!, completionHandler: ((NSURLSessionResponseDisposition) -> Void)!) {
                var disposition: NSURLSessionResponseDisposition = .Allow

                if self.dataTaskDidReceiveResponse != nil {
                    disposition = self.dataTaskDidReceiveResponse!(session, dataTask, response)
                }

                completionHandler(disposition)
            }

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask!) {
                let downloadDelegate = Request.DownloadTaskDelegate(task: downloadTask)
                self[downloadTask] = downloadDelegate
            }

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {
                if let delegate = self[dataTask] as? Request.DataTaskDelegate {
                    delegate.URLSession(session, dataTask: dataTask, didReceiveData: data)
                }

                self.dataTaskDidReceiveData?(session, dataTask, data)
            }

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, willCacheResponse proposedResponse: NSCachedURLResponse!, completionHandler: ((NSCachedURLResponse!) -> Void)!) {
                var cachedResponse = proposedResponse

                if self.dataTaskWillCacheResponse != nil {
                    cachedResponse = self.dataTaskWillCacheResponse!(session, dataTask, proposedResponse)
                }

                completionHandler(cachedResponse)
            }

            // MARK: NSURLSessionDownloadDelegate

            func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
                if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                    delegate.URLSession(session, downloadTask: downloadTask, didFinishDownloadingToURL: location)
                }

                self.downloadTaskDidFinishDownloadingToURL?(session, downloadTask, location)
            }

            func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
                if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                    delegate.URLSession(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                }

                self.downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
            }

            func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
                if let delegate = self[downloadTask] as? Request.DownloadTaskDelegate {
                    delegate.URLSession(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
                }

                self.downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
            }

            // MARK: NSObject

            override func respondsToSelector(selector: Selector) -> Bool {
                switch selector {
                case "URLSession:didBecomeInvalidWithError:":
                    return (self.sessionDidBecomeInvalidWithError != nil)
                case "URLSession:didReceiveChallenge:completionHandler:":
                    return (self.sessionDidReceiveChallenge != nil)
                case "URLSessionDidFinishEventsForBackgroundURLSession:":
                    return (self.sessionDidFinishEventsForBackgroundURLSession != nil)
                case "URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:":
                    return (self.taskWillPerformHTTPRedirection != nil)
                case "URLSession:dataTask:didReceiveResponse:completionHandler:":
                    return (self.dataTaskDidReceiveResponse != nil)
                case "URLSession:dataTask:willCacheResponse:completionHandler:":
                    return (self.dataTaskWillCacheResponse != nil)
                default:
                    return self.dynamicType.instancesRespondToSelector(selector)
                }
            }
        }
    }

    // MARK: -

    class Request {
        private let delegate: TaskDelegate

        private var session: NSURLSession
        private var task: NSURLSessionTask { return self.delegate.task }

        var request: NSURLRequest! { return self.task.originalRequest }
        var response: NSHTTPURLResponse! { return self.task.response as? NSHTTPURLResponse }
        var progress: NSProgress? { return self.delegate.progress }

        private init(session: NSURLSession, task: NSURLSessionTask) {
            self.session = session

            if task is NSURLSessionUploadTask {
                self.delegate = UploadTaskDelegate(task: task)
            } else if task is NSURLSessionDownloadTask {
                self.delegate = DownloadTaskDelegate(task: task)
            } else if task is NSURLSessionDataTask {
                self.delegate = DataTaskDelegate(task: task)
            } else {
                self.delegate = TaskDelegate(task: task)
            }
        }

        // MARK: Authentication

        func authenticate(HTTPBasic user: String, password: String) -> Self {
            let credential = NSURLCredential(user: user, password: password, persistence: .ForSession)
            let protectionSpace = NSURLProtectionSpace(host: self.request.URL.host, port: 0, `protocol`: self.request.URL.scheme, realm: nil, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)

            return authenticate(usingCredential: credential, forProtectionSpace: protectionSpace)
        }

        func authenticate(usingCredential credential: NSURLCredential, forProtectionSpace protectionSpace: NSURLProtectionSpace) -> Self {
            self.session.configuration.URLCredentialStorage.setCredential(credential, forProtectionSpace: protectionSpace)

            return self
        }

        // MARK: Progress

        func progress(closure: ((Int64, Int64, Int64) -> Void)? = nil) -> Self {
            if let uploadDelegate = self.delegate as? UploadTaskDelegate {
                uploadDelegate.uploadProgress = closure
            } else if let downloadDelegate = self.delegate as? DownloadTaskDelegate {
                downloadDelegate.downloadProgress = closure
            }

            return self
        }

        // MARK: Response

        func response(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
            return response({ (request, response, data, error) in
                                return (data, error)
                            }, completionHandler: completionHandler)
        }

        func response(priority: Int = DISPATCH_QUEUE_PRIORITY_DEFAULT, queue: dispatch_queue_t? = nil, serializer: (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?), completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {

            dispatch_async(self.delegate.queue, {
                dispatch_async(dispatch_get_global_queue(priority, 0), {
                    let (responseObject: AnyObject?, error: NSError?) = serializer(self.request, self.response, self.delegate.data, self.delegate.error)

                    dispatch_async(queue ?? dispatch_get_main_queue(), {
                        completionHandler(self.request, self.response, responseObject, error)
                    })
                })
            })

            return self
        }

        func suspend() {
            self.task.suspend()
        }

        func resume() {
            self.task.resume()
        }

        func cancel() {
            if let downloadDelegate = self.delegate as? DownloadTaskDelegate {
                downloadDelegate.downloadTask.cancelByProducingResumeData { (data) in
                    downloadDelegate.resumeData = data
                }
            } else {
                self.task.cancel()
            }
        }

        private class TaskDelegate: NSObject, NSURLSessionTaskDelegate {
            let task: NSURLSessionTask
            let queue: dispatch_queue_t?
            let progress: NSProgress

            var data: NSData! { return nil }
            private(set) var error: NSError?

            var taskWillPerformHTTPRedirection: ((NSURLSession!, NSURLSessionTask!, NSHTTPURLResponse!, NSURLRequest!) -> (NSURLRequest!))?
            var taskDidReceiveChallenge: ((NSURLSession!, NSURLSessionTask!, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential?))?
            var taskDidSendBodyData: ((NSURLSession!, NSURLSessionTask!, Int64, Int64, Int64) -> Void)?
            var taskNeedNewBodyStream: ((NSURLSession!, NSURLSessionTask!) -> (NSInputStream!))?

            init(task: NSURLSessionTask) {
                self.task = task
                self.progress = NSProgress(totalUnitCount: 0)

                let label: String = "com.alamofire.task-\(task.taskIdentifier)"
                let queue = dispatch_queue_create((label as NSString).UTF8String, DISPATCH_QUEUE_SERIAL)
                dispatch_suspend(queue)
                self.queue = queue
            }

            // MARK: NSURLSessionTaskDelegate

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, willPerformHTTPRedirection response: NSHTTPURLResponse!, newRequest request: NSURLRequest!, completionHandler: ((NSURLRequest!) -> Void)!) {
                var redirectRequest = request
                if self.taskWillPerformHTTPRedirection != nil {
                    redirectRequest = self.taskWillPerformHTTPRedirection!(session, task, response, request)
                }

                completionHandler(redirectRequest)
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
                var disposition: NSURLSessionAuthChallengeDisposition = .PerformDefaultHandling
                var credential: NSURLCredential?

                if self.taskDidReceiveChallenge != nil {
                    (disposition, credential) = self.taskDidReceiveChallenge!(session, task, challenge)
                } else {
                    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                        // TODO: Incorporate Trust Evaluation & TLS Chain Validation

                        credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust)
                        disposition = .UseCredential
                    }
                }

                completionHandler(disposition, credential)
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, needNewBodyStream completionHandler: ((NSInputStream!) -> Void)!) {
                var bodyStream: NSInputStream?
                if self.taskNeedNewBodyStream != nil {
                    bodyStream = self.taskNeedNewBodyStream!(session, task)
                }

                completionHandler(bodyStream)
            }

            func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didCompleteWithError error: NSError!) {
                self.error = error
                dispatch_resume(self.queue)
            }
        }

        private class DataTaskDelegate: TaskDelegate, NSURLSessionDataDelegate {
            var dataTask: NSURLSessionDataTask! { return self.task as NSURLSessionDataTask }

            private var mutableData: NSMutableData
            override var data: NSData! {
                return self.mutableData
            }

            var dataTaskDidReceiveResponse: ((NSURLSession!, NSURLSessionDataTask!, NSURLResponse!) -> (NSURLSessionResponseDisposition))?
            var dataTaskDidBecomeDownloadTask: ((NSURLSession!, NSURLSessionDataTask!) -> Void)?
            var dataTaskDidReceiveData: ((NSURLSession!, NSURLSessionDataTask!, NSData!) -> Void)?
            var dataTaskWillCacheResponse: ((NSURLSession!, NSURLSessionDataTask!, NSCachedURLResponse!) -> (NSCachedURLResponse))?

            override init(task: NSURLSessionTask) {
                self.mutableData = NSMutableData()
                super.init(task: task)
            }

            // MARK: NSURLSessionDataDelegate

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveResponse response: NSURLResponse!, completionHandler: ((NSURLSessionResponseDisposition) -> Void)!) {
                var disposition: NSURLSessionResponseDisposition = .Allow

                if self.dataTaskDidReceiveResponse != nil {
                    disposition = self.dataTaskDidReceiveResponse!(session, dataTask, response)
                }

                completionHandler(disposition)
            }

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask!) {
                self.dataTaskDidBecomeDownloadTask?(session, dataTask)
            }

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {
                self.dataTaskDidReceiveData?(session, dataTask, data)

                self.mutableData.appendData(data)
            }

            func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, willCacheResponse proposedResponse: NSCachedURLResponse!, completionHandler: ((NSCachedURLResponse!) -> Void)!) {
                var cachedResponse = proposedResponse

                if self.dataTaskWillCacheResponse != nil {
                    cachedResponse = self.dataTaskWillCacheResponse!(session, dataTask, proposedResponse)
                }

                completionHandler(cachedResponse)
            }
        }
    }
}

// MARK: - Upload

extension Alamofire.Manager {
    private enum Uploadable {
        case Data(NSURLRequest, NSData)
        case File(NSURLRequest, NSURL)
        case Stream(NSURLRequest, NSInputStream)
    }

    private func upload(uploadable: Uploadable) -> Alamofire.Request {
        var uploadTask: NSURLSessionUploadTask!
        var stream: NSInputStream?

        switch uploadable {
        case .Data(let request, let data):
            uploadTask = self.session.uploadTaskWithRequest(request, fromData: data)
        case .File(let request, let fileURL):
            uploadTask = self.session.uploadTaskWithRequest(request, fromFile: fileURL)
        case .Stream(let request, var stream):
            uploadTask = self.session.uploadTaskWithStreamedRequest(request)
        }

        let request = Alamofire.Request(session: self.session, task: uploadTask)
        if stream != nil {
            request.delegate.taskNeedNewBodyStream = { _, _ in
                return stream
            }
        }
        self.delegate[request.delegate.task] = request.delegate

        if self.automaticallyStartsRequests {
            request.resume()
        }

        return request
    }

    // MARK: File

    func upload(request: NSURLRequest, file: NSURL) -> Alamofire.Request {
        return upload(.File(request, file))
    }

    // MARK: Data

    func upload(request: NSURLRequest, data: NSData) -> Alamofire.Request {
        return upload(.Data(request, data))
    }

    // MARK: Stream

    func upload(request: NSURLRequest, stream: NSInputStream) -> Alamofire.Request {
        return upload(.Stream(request, stream))
    }
}

extension Alamofire.Request {
    private class UploadTaskDelegate: DataTaskDelegate {
        var uploadTask: NSURLSessionUploadTask! { return self.task as NSURLSessionUploadTask }
        var uploadProgress: ((Int64, Int64, Int64) -> Void)!

        // MARK: NSURLSessionTaskDelegate

        func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            if self.uploadProgress {
                self.uploadProgress(bytesSent, totalBytesSent, totalBytesExpectedToSend)
            }

            self.progress.totalUnitCount = totalBytesExpectedToSend
            self.progress.completedUnitCount = totalBytesSent
        }
    }
}

// MARK: - Download

extension Alamofire.Manager {
    private enum Downloadable {
        case Request(NSURLRequest)
        case ResumeData(NSData)
    }

    private func download(downloadable: Downloadable, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Alamofire.Request {
        var downloadTask: NSURLSessionDownloadTask!

        switch downloadable {
        case .Request(let request):
            downloadTask = self.session.downloadTaskWithRequest(request)
        case .ResumeData(let resumeData):
            downloadTask = self.session.downloadTaskWithResumeData(resumeData)
        }

        let request = Alamofire.Request(session: self.session, task: downloadTask)
        if let downloadDelegate = request.delegate as? Alamofire.Request.DownloadTaskDelegate {
            downloadDelegate.downloadTaskDidFinishDownloadingToURL = { (session, downloadTask, URL) in
                return destination(URL, downloadTask.response as NSHTTPURLResponse)
            }
        }
        self.delegate[request.delegate.task] = request.delegate

        if self.automaticallyStartsRequests {
            request.resume()
        }

        return request
    }

    // MARK: Request

    func download(request: NSURLRequest, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Alamofire.Request {
        return download(.Request(request), destination: destination)
    }

    // MARK: Resume Data

    func download(resumeData: NSData, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Alamofire.Request {
        return download(.ResumeData(resumeData), destination: destination)
    }
}

extension Alamofire.Request {
    class func suggestedDownloadDestination(directory: NSSearchPathDirectory = .DocumentDirectory, domain: NSSearchPathDomainMask = .UserDomainMask) -> (NSURL, NSHTTPURLResponse) -> (NSURL) {

        return { (temporaryURL, response) -> (NSURL) in
            if let directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as? NSURL {
                return directoryURL.URLByAppendingPathComponent(response.suggestedFilename)
            }

            return temporaryURL
        }
    }

    private class DownloadTaskDelegate: TaskDelegate, NSURLSessionDownloadDelegate {
        var downloadTask: NSURLSessionDownloadTask! { return self.task as NSURLSessionDownloadTask }
        var downloadProgress: ((Int64, Int64, Int64) -> Void)?

        var resumeData: NSData!
        override var data: NSData! { return self.resumeData }

        var downloadTaskDidFinishDownloadingToURL: ((NSURLSession!, NSURLSessionDownloadTask!, NSURL) -> (NSURL))?
        var downloadTaskDidWriteData: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64, Int64) -> Void)?
        var downloadTaskDidResumeAtOffset: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64) -> Void)?

        // MARK: NSURLSessionDownloadDelegate

        func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
            if self.downloadTaskDidFinishDownloadingToURL != nil {
                let destination = self.downloadTaskDidFinishDownloadingToURL!(session, downloadTask, location)
                var fileManagerError: NSError?

                NSFileManager.defaultManager().moveItemAtURL(location, toURL: destination, error: &fileManagerError)
                // TODO: NSNotification on failure
            }
        }

        func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            self.downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)

            self.downloadProgress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)

            self.progress.totalUnitCount = totalBytesExpectedToWrite
            self.progress.completedUnitCount = totalBytesWritten
        }

        func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
            self.downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)

            self.progress.totalUnitCount = expectedTotalBytes
            self.progress.completedUnitCount = fileOffset
        }
    }
}

// MARK: - Printable

extension Alamofire.Request: Printable {
    var description: String {
        var description = "\(self.request.HTTPMethod) \(self.request.URL)"
        if self.response {
            description += " (\(self.response?.statusCode))"
        }

        return description
    }
}

extension Alamofire.Request: DebugPrintable {
    func cURLRepresentation() -> String {
        var components: [String] = ["$ curl -i"]

        let URL = self.request.URL!

        if self.request.HTTPMethod != "GET" {
            components.append("-X \(self.request.HTTPMethod)")
        }

        if let credentialStorage = self.session.configuration.URLCredentialStorage {
            let protectionSpace = NSURLProtectionSpace(host: URL.host, port: URL.port ? URL.port : 0, `protocol`: URL.scheme, realm: URL.host, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
            if let credentials = credentialStorage.credentialsForProtectionSpace(protectionSpace)?.values.array {
                if !credentials.isEmpty {
                    if let credential = credentials[0] as? NSURLCredential {
                        components.append("-u \(credential.user):\(credential.password)")
                    }
                }
            }
        }

        if let cookieStorage = self.session.configuration.HTTPCookieStorage {
            if let cookies = cookieStorage.cookiesForURL(URL) as? [NSHTTPCookie] {
                if !cookies.isEmpty {
                    let string = cookies.reduce(""){ $0 + "\($1.name)=\($1.value);" }
                    components.append("-b \"\(string.substringToIndex(string.endIndex.predecessor()))\"")
                }
            }
        }

        for (field, value) in self.request.allHTTPHeaderFields {
            switch field {
            case "Cookie":
                continue
            default:
                components.append("-H \"\(field): \(value)\"")
            }
        }

        if let HTTPBody = self.request.HTTPBody {
            components.append("-d \"\(NSString(data: HTTPBody, encoding: NSUTF8StringEncoding))\"")
        }

        // TODO: -T arguments for files

        components.append("\"\(URL.absoluteString)\"")

        return join(" \\\n\t", components)
    }

    var debugDescription: String {
        return self.cURLRepresentation()
    }
}

// MARK: - Response Serializers

// MARK: String

extension Alamofire.Request {
    class func stringResponseSerializer(encoding: NSStringEncoding = NSUTF8StringEncoding) -> (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?) {
        return { (_, _, data, error) in
            let string = NSString(data: data, encoding: encoding)
            return (string, error)
        }
    }

    func responseString(completionHandler: (NSURLRequest, NSHTTPURLResponse?, String?, NSError?) -> Void) -> Self {
        return responseString(completionHandler: completionHandler)
    }

    func responseString(encoding: NSStringEncoding = NSUTF8StringEncoding, completionHandler: (NSURLRequest, NSHTTPURLResponse?, String?, NSError?) -> Void) -> Self  {
        return response(serializer: Alamofire.Request.stringResponseSerializer(encoding: encoding), completionHandler: { request, response, string, error in
            completionHandler(request, response, string as? String, error)
        })
    }
}

// MARK: JSON

extension Alamofire.Request {
    class func JSONResponseSerializer(options: NSJSONReadingOptions = .AllowFragments) -> (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?) {
        return { (request, response, data, error) in
            var serializationError: NSError?
            let JSON: AnyObject! = NSJSONSerialization.JSONObjectWithData(data, options: options, error: &serializationError)
            return (JSON, serializationError)
        }
    }

    func responseJSON(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return responseJSON(completionHandler: completionHandler)
    }

    func responseJSON(options: NSJSONReadingOptions = .AllowFragments, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Alamofire.Request.JSONResponseSerializer(options: options), completionHandler: { (request, response, JSON, error) in
            completionHandler(request, response, JSON, error)
        })
    }
}

// MARK: Property List

extension Alamofire.Request {
    class func propertyListResponseSerializer(options: NSPropertyListReadOptions = 0) -> (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?) {
        return { (request, response, data, error) in
            var propertyListSerializationError: NSError?
            let plist: AnyObject! = NSPropertyListSerialization.propertyListWithData(data, options: options, format: nil, error: &propertyListSerializationError)

            return (plist, propertyListSerializationError)
        }
    }

    func responsePropertyList(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return responsePropertyList(completionHandler: completionHandler)
    }

    func responsePropertyList(options: NSPropertyListReadOptions = 0, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Alamofire.Request.propertyListResponseSerializer(options: options), completionHandler: { (request, response, plist, error) in
            completionHandler(request, response, plist, error)
        })
    }
}

// MARK: - Convenience

extension Alamofire {
    private static func URLRequest(method: Method, _ URL: String) -> NSURLRequest {
        let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URL))
        mutableURLRequest.HTTPMethod = method.toRaw()

        return mutableURLRequest
    }

    // MARK: Request

    static func request(method: Method, _ URL: String, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL) -> Request {
        return Manager.sharedInstance.request(encoding.encode(URLRequest(method, URL), parameters: parameters).0)
    }

    // MARK: Upload

    static func upload(method: Method, _ URL: String, file: NSURL) -> Alamofire.Request {
        return Manager.sharedInstance.upload(URLRequest(method, URL), file: file)
    }

    static func upload(method: Method, _ URL: String, data: NSData) -> Alamofire.Request {
        return Manager.sharedInstance.upload(URLRequest(method, URL), data: data)
    }

    static func upload(method: Method, _ URL: String, stream: NSInputStream) -> Alamofire.Request {
        return Manager.sharedInstance.upload(URLRequest(method, URL), stream: stream)
    }

    // MARK: Download

    static func download(method: Method, _ URL: String, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Alamofire.Request {
        return Manager.sharedInstance.download(URLRequest(method, URL), destination: destination)
    }

    static func download(resumeData data: NSData, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Alamofire.Request {
        return Manager.sharedInstance.download(data, destination: destination)
    }
}

typealias AF = Alamofire
