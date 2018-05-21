//
//  SessionDelegate.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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

open class SessionDelegate: NSObject {
    // TODO: Investigate queueing active tasks?
    private(set) var requestTaskMap = RequestTaskMap()

    // TODO: Better way to connect delegate to manager, including queue?
    private weak var manager: SessionManager?
    private var eventMonitor: EventMonitor?
    private var queue: DispatchQueue? { return manager?.rootQueue }

    let startRequestsImmediately: Bool

    public init(startRequestsImmediately: Bool = true) {
        self.startRequestsImmediately = startRequestsImmediately
    }

    func didCreateSessionManager(_ manager: SessionManager, withEventMonitor eventMonitor: EventMonitor) {
        self.manager = manager
        self.eventMonitor = eventMonitor
    }

    func didCreateURLRequest(_ urlRequest: URLRequest, for request: Request) {
        guard let manager = manager else { fatalError("Received didCreateURLRequest but there is no manager.") }

        guard !request.isCancelled else { return }

        let task = request.task(for: urlRequest, using: manager.session)
        requestTaskMap[request] = task
        request.didCreateTask(task)

        resumeOrSuspendTask(task, ifNecessaryForRequest: request)
    }

    func didReceiveResumeData(_ data: Data, for request: DownloadRequest) {
        guard let manager = manager else { fatalError("Received didReceiveResumeData but there is no manager.") }

        guard !request.isCancelled else { return }

        let task = request.task(forResumeData: data, using: manager.session)
        requestTaskMap[request] = task
        request.didCreateTask(task)

        resumeOrSuspendTask(task, ifNecessaryForRequest: request)
    }

    func resumeOrSuspendTask(_ task: URLSessionTask, ifNecessaryForRequest request: Request) {
        if startRequestsImmediately || request.isResumed {
            task.resume()
            request.didResume()
        }

        if request.isSuspended {
            task.suspend()
            request.didSuspend()
        }
    }
}

extension SessionDelegate: RequestDelegate {
    func isRetryingRequest(_ request: Request, ifNecessaryWithError error: Error) -> Bool {
        guard let manager = manager, let retrier = manager.retrier else { return false }

        retrier.should(manager, retry: request, with: error) { (shouldRetry, retryInterval) in
            guard !request.isCancelled else { return }

            self.queue?.async {
                guard shouldRetry else {
                    request.finish()
                    return
                }

                self.queue?.after(retryInterval) {
                    guard !request.isCancelled else { return }

                    self.manager?.perform(request)
                }
            }
        }

        return true
    }

    func cancelRequest(_ request: Request) {
        queue?.async {

            guard let task = self.requestTaskMap[request] else {
                request.didCancel()
                request.finish()
                return
            }

            request.didCancel()
            task.cancel()
        }
    }

    func cancelDownloadRequest(_ request: DownloadRequest, byProducingResumeData: @escaping (Data?) -> Void) {
        queue?.async {
            guard let downloadTask = self.requestTaskMap[request] as? URLSessionDownloadTask else {
                request.didCancel()
                request.finish()
                return
            }

            downloadTask.cancel { (data) in
                self.queue?.async {
                    byProducingResumeData(data)
                    request.didCancel()
                }
            }
        }
    }

    func suspendRequest(_ request: Request) {
        queue?.async {
            defer { request.didSuspend() }

            guard !request.isCancelled, let task = self.requestTaskMap[request] else { return }

            task.suspend()
        }
    }

    func resumeRequest(_ request: Request) {
        queue?.async {
            defer { request.didResume() }

            guard !request.isCancelled, let task = self.requestTaskMap[request] else { return }

            task.resume()
        }
    }
}

extension SessionDelegate: URLSessionDelegate {
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        eventMonitor?.urlSession(session, didBecomeInvalidWithError: error)
    }
}

extension SessionDelegate: URLSessionTaskDelegate {
    // Auth challenge, will be received always since the URLSessionDelegate method isn't implemented.
    typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: Error?)
    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        eventMonitor?.urlSession(session, task: task, didReceive: challenge)

        let evaluation: ChallengeEvaluation
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            evaluation = attemptServerTrustAuthentication(with: challenge)
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
            evaluation = attemptHTTPAuthentication(for: challenge, belongingTo: task)
            // TODO: Error explaining AF doesn't support client certificates?
        // case NSURLAuthenticationMethodClientCertificate:
        default:
            evaluation = (.performDefaultHandling, nil, nil)
        }

        if let error = evaluation.error {
            requestTaskMap[task]?.didFailTask(task, earlyWithError: error)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    func attemptServerTrustAuthentication(with challenge: URLAuthenticationChallenge) -> ChallengeEvaluation {
        let host = challenge.protectionSpace.host

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let evaluator = manager?.serverTrustManager?.serverTrustEvaluators(forHost: host),
            let serverTrust = challenge.protectionSpace.serverTrust
            else {
                return (.performDefaultHandling, nil, nil)
        }

        guard evaluator.evaluate(serverTrust, forHost: host) else {
            let error = AFError.certificatePinningFailed

            return (.cancelAuthenticationChallenge, nil, error)
        }

        return (.useCredential, URLCredential(trust: serverTrust), nil)
    }

    func attemptHTTPAuthentication(for challenge: URLAuthenticationChallenge, belongingTo task: URLSessionTask) -> ChallengeEvaluation {
        // TODO: Consider custom error, depending on error we get from session.
        guard challenge.previousFailureCount == 0 else {
            return (.rejectProtectionSpace, nil, nil)
        }

        // TODO: Get credential from session's configuration's defaultCredential too.
        guard let credential = requestTaskMap[task]?.credential else {
            return (.performDefaultHandling, nil, nil)
        }

        return (.useCredential, credential, nil)
    }

    // Progress of sending the body data.
    open func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        eventMonitor?.urlSession(session,
                                 task: task,
                                 didSendBodyData: bytesSent,
                                 totalBytesSent: totalBytesSent,
                                 totalBytesExpectedToSend: totalBytesExpectedToSend)

        requestTaskMap[task]?.updateUploadProgress(totalBytesSent: totalBytesSent,
                                                   totalBytesExpectedToSend: totalBytesExpectedToSend)

//        if #available(iOS 11.0, macOS 10.13, watchOS 4.0, tvOS 11.0, *) {
//            NSLog("URLSession: \(session), task: \(task), progress: \(task.progress)")
//        }
    }

    // This delegate method is called under two circumstances:
    // To provide the initial request body stream if the task was created with uploadTaskWithStreamedRequest:
    //To provide a replacement request body stream if the task needs to resend a request that has a body stream because of an authentication challenge or other recoverable server error.
    // You do not need to implement this if your code provides the request body using a file URL or an NSData object.
    // Don't enable if streamed bodies aren't supported.
    open func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        eventMonitor?.urlSession(session, taskNeedsNewBodyStream: task)

        guard let request = requestTaskMap[task] as? UploadRequest else {
            fatalError("needNewBodyStream for request that isn't UploadRequest.")
        }

        completionHandler(request.inputStream())
    }

    // This method is called only for tasks in default and ephemeral sessions. Tasks in background sessions automatically follow redirects.
    // Only code should be customization closure?
    open func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        eventMonitor?.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request)
        completionHandler(request)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        eventMonitor?.urlSession(session, task: task, didFinishCollecting: metrics)

        requestTaskMap[task]?.didGatherMetrics(metrics)
    }

    // Task finished transferring data or had a client error.
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        eventMonitor?.urlSession(session, task: task, didCompleteWithError: error)

        requestTaskMap[task]?.didCompleteTask(task, with: error)

        requestTaskMap[task] = nil
    }

    // Only used when background sessions are resuming a delayed task.
    //    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
    //
    //    }

    // This method is called if the waitsForConnectivity property of URLSessionConfiguration is true, and sufficient
    // connectivity is unavailable. The delegate can use this opportunity to update the user interface; for example, by
    // presenting an offline mode or a cellular-only mode.
    //
    // This method is called, at most, once per task, and only if connectivity is initially unavailable. It is never
    // called for background sessions because waitsForConnectivity is ignored for those sessions.
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        eventMonitor?.urlSession(session, taskIsWaitingForConnectivity: task)

        // Post Notification?
        // Update Request state?
        // Only once? How to know when it's done waiting and resumes the task?
    }
}

extension SessionDelegate: URLSessionDataDelegate {
    // This method is optional unless you need to support the (relatively obscure) multipart/x-mixed-replace content type.
    // With that content type, the server sends a series of parts, each of which is intended to replace the previous part.
    // The session calls this method at the beginning of each part, and you should then display, discard, or otherwise process the previous part, as appropriate.
    // Don't support?
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        NSLog("URLSession: \(session), dataTask: \(dataTask), didReceive: \(response)")
//
//        completionHandler(.allow)
//    }

    // Only called if didReceiveResponse is called.
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
//        NSLog("URLSession: \(session), dataTask: \(dataTask), didBecomeDownloadTask")
//    }

    // Only called if didReceiveResponse is called.
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
//        NSLog("URLSession: \(session), dataTask: \(dataTask), didBecomeStreamTask: \(streamTask)")
//    }

    // Called, possibly more than once, to accumulate the data for a response.
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: data)
        // TODO: UploadRequest will need this too, only works now because it's a subclass.
        guard let request = requestTaskMap[dataTask] as? DataRequest else {
            fatalError("dataTask received data for incorrect Request subclass: \(String(describing: requestTaskMap[dataTask]))")
        }

        request.didRecieve(data: data)
        // Update Request progress?
    }

    //    The session calls this delegate method after the task finishes receiving all of the expected data. If you do not implement this method, the default behavior is to use the caching policy specified in the session’s configuration object. The primary purpose of this method is to prevent caching of specific URLs or to modify the userInfo dictionary associated with the URL response.
    //
    //    This method is called only if the NSURLProtocol handling the request decides to cache the response. As a rule, responses are cached only when all of the following are true:
    //
    //    The request is for an HTTP or HTTPS URL (or your own custom networking protocol that supports caching).
    //
    //    The request was successful (with a status code in the 200–299 range).
    //
    //    The provided response came from the server, rather than out of the cache.
    //
    //    The session configuration’s cache policy allows caching.
    //
    //    The provided NSURLRequest object's cache policy (if applicable) allows caching.
    //
    //    The cache-related headers in the server’s response (if present) allow caching.
    //
    //    The response size is small enough to reasonably fit within the cache. (For example, if you provide a disk cache, the response must be no larger than about 5% of the disk cache size.)
    // Only for customization of caching?
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        eventMonitor?.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse)

        completionHandler(proposedResponse)
    }
}

extension SessionDelegate: URLSessionDownloadDelegate {
    // Indicates resume data was used to start a download task. Use for ?
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        eventMonitor?.urlSession(session,
                                 downloadTask: downloadTask,
                                 didResumeAtOffset: fileOffset,
                                 expectedTotalBytes: expectedTotalBytes)

        guard let downloadRequest = requestTaskMap[downloadTask] as? DownloadRequest else {
            fatalError("No DownloadRequest found for downloadTask: \(downloadTask)")
        }

        downloadRequest.updateDownloadProgress(bytesWritten: fileOffset,
                                               totalBytesExpectedToWrite: expectedTotalBytes)
    }

    // Download progress, as provided by the `Content-Length` header. `totalBytesExpectedToWrite` will be `NSURLSessionTransferSizeUnknown` when there's no header.
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        eventMonitor?.urlSession(session,
                                 downloadTask: downloadTask,
                                 didWriteData: bytesWritten,
                                 totalBytesWritten: totalBytesWritten,
                                 totalBytesExpectedToWrite: totalBytesExpectedToWrite)

        guard let downloadRequest = requestTaskMap[downloadTask] as? DownloadRequest else {
            fatalError("No DownloadRequest found for downloadTask: \(downloadTask)")
        }

        downloadRequest.updateDownloadProgress(bytesWritten: bytesWritten,
                                               totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    // When finished, open for reading or move the file.
    // A file URL for the temporary file. Because the file is temporary, you must either open the file for reading or
    // move it to a permanent location in your app’s sandbox container directory before returning from this delegate
    // method.
    //
    // If you choose to open the file for reading, you should do the actual reading in another thread to avoid blocking
    // the delegate queue.
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        eventMonitor?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)

        guard let request = requestTaskMap[downloadTask] as? DownloadRequest else {
            fatalError("download finished but either no request found or request wasn't DownloadRequest")
        }

        request.didComplete(task: downloadTask, with: location)
    }
}
