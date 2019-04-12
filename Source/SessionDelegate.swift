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

protocol SessionStateProvider: AnyObject {
    var serverTrustManager: ServerTrustManager? { get }
    var redirectHandler: RedirectHandler? { get }
    var cachedResponseHandler: CachedResponseHandler? { get }

    func request(for task: URLSessionTask) -> Request?
    func didCompleteTask(_ task: URLSessionTask)
    func credential(for task: URLSessionTask, in protectionSpace: URLProtectionSpace) -> URLCredential?
    func cancelRequestsForSessionInvalidation(with error: Error?)
}

open class SessionDelegate: NSObject {
    private let fileManager: FileManager

    weak var stateProvider: SessionStateProvider?
    var eventMonitor: EventMonitor?

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
}

extension SessionDelegate: URLSessionDelegate {
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        eventMonitor?.urlSession(session, didBecomeInvalidWithError: error)

        stateProvider?.cancelRequestsForSessionInvalidation(with: error)
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
            stateProvider?.request(for: task)?.didFailTask(task, earlyWithError: error)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    func attemptServerTrustAuthentication(with challenge: URLAuthenticationChallenge) -> ChallengeEvaluation {
        let host = challenge.protectionSpace.host

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
            else {
                return (.performDefaultHandling, nil, nil)
        }

        do {
            guard let evaluator = try stateProvider?.serverTrustManager?.serverTrustEvaluator(forHost: host) else {
                return (.performDefaultHandling, nil, nil)
            }

            try evaluator.evaluate(trust, forHost: host)

            return (.useCredential, URLCredential(trust: trust), nil)
        } catch {
            return (.cancelAuthenticationChallenge, nil, error)
        }
    }

    func attemptHTTPAuthentication(for challenge: URLAuthenticationChallenge,
                                   belongingTo task: URLSessionTask) -> ChallengeEvaluation {
        guard challenge.previousFailureCount == 0 else {
            return (.rejectProtectionSpace, nil, nil)
        }

        guard let credential = stateProvider?.credential(for: task, in: challenge.protectionSpace) else {
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

        stateProvider?.request(for: task)?.updateUploadProgress(totalBytesSent: totalBytesSent,
                                                   totalBytesExpectedToSend: totalBytesExpectedToSend)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        eventMonitor?.urlSession(session, taskNeedsNewBodyStream: task)

        guard let request = stateProvider?.request(for: task) as? UploadRequest else {
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

        if let redirectHandler = stateProvider?.request(for: task)?.redirectHandler ?? stateProvider?.redirectHandler {
            redirectHandler.task(task, willBeRedirectedTo: request, for: response, completion: completionHandler)
        } else {
            completionHandler(request)
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        eventMonitor?.urlSession(session, task: task, didFinishCollecting: metrics)

        stateProvider?.request(for: task)?.didGatherMetrics(metrics)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        eventMonitor?.urlSession(session, task: task, didCompleteWithError: error)

        stateProvider?.request(for: task)?.didCompleteTask(task, with: error)

        stateProvider?.didCompleteTask(task)
    }

    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        eventMonitor?.urlSession(session, taskIsWaitingForConnectivity: task)
    }
}

extension SessionDelegate: URLSessionDataDelegate {
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: data)

        guard let request = stateProvider?.request(for: dataTask) as? DataRequest else {
            fatalError("dataTask received data for incorrect Request subclass: \(String(describing: stateProvider?.request(for: dataTask)))")
        }

        request.didReceive(data: data)
    }

    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         willCacheResponse proposedResponse: CachedURLResponse,
                         completionHandler: @escaping (CachedURLResponse?) -> Void) {
        eventMonitor?.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse)

        if let handler = stateProvider?.request(for: dataTask)?.cachedResponseHandler ?? stateProvider?.cachedResponseHandler {
            handler.dataTask(dataTask, willCacheResponse: proposedResponse, completion: completionHandler)
        } else {
            completionHandler(proposedResponse)
        }
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

        guard let downloadRequest = stateProvider?.request(for: downloadTask) as? DownloadRequest else {
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

        guard let downloadRequest = stateProvider?.request(for: downloadTask) as? DownloadRequest else {
            fatalError("No DownloadRequest found for downloadTask: \(downloadTask)")
        }

        downloadRequest.updateDownloadProgress(bytesWritten: bytesWritten,
                                               totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        eventMonitor?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)

        guard let request = stateProvider?.request(for: downloadTask) as? DownloadRequest else {
            fatalError("Download finished but either no request found or request wasn't DownloadRequest")
        }

        guard let response = request.response else {
            fatalError("URLSessionDownloadTask finished downloading with no response.")
        }

        let (destination, options) = (request.destination ?? DownloadRequest.defaultDestination)(location, response)

        eventMonitor?.request(request, didCreateDestinationURL: destination)

        do {
            if options.contains(.removePreviousFile), fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destination.deletingLastPathComponent()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try fileManager.moveItem(at: location, to: destination)

            request.didFinishDownloading(using: downloadTask, with: .success(destination))
        } catch {
            request.didFinishDownloading(using: downloadTask, with: .failure(error))
        }
    }
}
