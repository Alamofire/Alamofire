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
    public var sessionConfiguration: URLSessionConfiguration {
        guard let manager = manager else { fatalError("Attempted to access sessionConfiguration without a manager.") }

        return manager.session.configuration
    }

    public func willRetryRequest(_ request: Request) -> Bool {
        return (manager?.retrier != nil)
    }

    public func retryRequest(_ request: Request, ifNecessaryWithError error: Error) {
        guard let manager = manager, let retrier = manager.retrier else { return }

        retrier.should(manager, retry: request, with: error) { (shouldRetry, retryInterval) in
            guard !request.isCancelled else { return }

            manager.rootQueue.async {
                guard shouldRetry else { request.finish(); return }

                manager.rootQueue.after(retryInterval) {
                    guard !request.isCancelled else { return }

                    request.requestIsRetrying()
                    manager.perform(request)
                }
            }
        }
    }

    public func cancelRequest(_ request: Request) {
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

    public func cancelDownloadRequest(_ request: DownloadRequest, byProducingResumeData: @escaping (Data?) -> Void) {
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

    public func suspendRequest(_ request: Request) {
        queue?.async {
            guard !request.isCancelled, let task = self.requestTaskMap[request] else { return }

            task.suspend()
            request.didSuspend()
        }
    }

    public func resumeRequest(_ request: Request) {
        queue?.async {
            guard !request.isCancelled, let task = self.requestTaskMap[request] else { return }

            task.resume()
            request.didResume()
        }
    }
}

extension SessionDelegate: URLSessionDelegate {
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        eventMonitor?.urlSession(session, didBecomeInvalidWithError: error)
    }
}

extension SessionDelegate: URLSessionTaskDelegate {
    /// Result of a `URLAuthenticationChallenge` evaluation.
    typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: Error?)

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        eventMonitor?.urlSession(session, task: task, didReceive: challenge)

        let evaluation: ChallengeEvaluation
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            evaluation = attemptServerTrustAuthentication(with: challenge)
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
            evaluation = attemptHTTPAuthentication(for: challenge, belongingTo: task)
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

    func attemptHTTPAuthentication(for challenge: URLAuthenticationChallenge,
                                   belongingTo task: URLSessionTask) -> ChallengeEvaluation {
        guard challenge.previousFailureCount == 0 else {
            return (.rejectProtectionSpace, nil, nil)
        }

        guard let credential = requestTaskMap[task]?.credential ??
            manager?.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace) else {
            return (.performDefaultHandling, nil, nil)
        }

        return (.useCredential, credential, nil)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didSendBodyData bytesSent: Int64,
                         totalBytesSent: Int64,
                         totalBytesExpectedToSend: Int64) {
        eventMonitor?.urlSession(session,
                                 task: task,
                                 didSendBodyData: bytesSent,
                                 totalBytesSent: totalBytesSent,
                                 totalBytesExpectedToSend: totalBytesExpectedToSend)

        requestTaskMap[task]?.updateUploadProgress(totalBytesSent: totalBytesSent,
                                                   totalBytesExpectedToSend: totalBytesExpectedToSend)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        eventMonitor?.urlSession(session, taskNeedsNewBodyStream: task)

        guard let request = requestTaskMap[task] as? UploadRequest else {
            fatalError("needNewBodyStream for request that isn't UploadRequest.")
        }

        completionHandler(request.inputStream())
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {
        eventMonitor?.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request)

        completionHandler(request)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        eventMonitor?.urlSession(session, task: task, didFinishCollecting: metrics)

        requestTaskMap[task]?.didGatherMetrics(metrics)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        eventMonitor?.urlSession(session, task: task, didCompleteWithError: error)

        requestTaskMap[task]?.didCompleteTask(task, with: error)

        requestTaskMap[task] = nil
    }

    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        eventMonitor?.urlSession(session, taskIsWaitingForConnectivity: task)
    }
}

extension SessionDelegate: URLSessionDataDelegate {
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: data)

        guard let request = requestTaskMap[dataTask] as? DataRequest else {
            fatalError("dataTask received data for incorrect Request subclass: \(String(describing: requestTaskMap[dataTask]))")
        }

        request.didReceive(data: data)
    }

    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         willCacheResponse proposedResponse: CachedURLResponse,
                         completionHandler: @escaping (CachedURLResponse?) -> Void) {
        eventMonitor?.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse)

        completionHandler(proposedResponse)
    }
}

extension SessionDelegate: URLSessionDownloadDelegate {
    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didResumeAtOffset fileOffset: Int64,
                         expectedTotalBytes: Int64) {
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

    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
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

    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        eventMonitor?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)

        guard let request = requestTaskMap[downloadTask] as? DownloadRequest else {
            fatalError("Download finished but either no request found or request wasn't DownloadRequest")
        }

        guard let response = request.response else {
            fatalError("URLSessionDownloadTask finished downloading with no response.")
        }

        let (destination, options) = (request.destination ?? DownloadRequest.defaultDestination)(location, response)

        eventMonitor?.request(request, didCreateDestinationURL: destination)

        do {
            if options.contains(.removePreviousFile), FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try FileManager.default.moveItem(at: location, to: destination)

            request.didFinishDownloading(using: downloadTask, with: .success(destination))
        } catch {
            request.didFinishDownloading(using: downloadTask, with: .failure(error))
        }
    }
}
