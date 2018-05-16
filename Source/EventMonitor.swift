//
//  EventMonitor.swift
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

public protocol URLSessionEventMonitor {
    var queue: DispatchQueue { get }

    // Session
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?)

    // URLSessionTask
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge)
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask)
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest)
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse)

    // Downloads
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
}

public extension URLSessionEventMonitor {
    var queue: DispatchQueue { return .main }
}

public protocol RequestEventMonitor {
    var queue: DispatchQueue { get }

    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest)
    func request(_ request: Request, didFailToCreateURLRequestWithError error: Error)
    func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest)
    func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: Error)
    func request(_ request: Request, didCreateTask task: URLSessionTask)

    func requestDidResume(_ request: Request)
    func requestDidSuspend(_ request: Request)
    func requestDidCancel(_ request: Request)

    func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics)
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: Error)
    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?)

    func requestDidFinish(_ request: Request)
}

public extension RequestEventMonitor {
    var queue: DispatchQueue { return .main }
}

public protocol EventMonitor: URLSessionEventMonitor & RequestEventMonitor { }

public extension EventMonitor {
    var queue: DispatchQueue { return .main }
}

public final class CompositeEventMonitor: EventMonitor {
    // TODO: Give composite its own queue?
    let monitors: [EventMonitor]

    init(monitors: [EventMonitor]) {
        self.monitors = monitors
    }

    func performEvent(_ event: @escaping (EventMonitor) -> Void) {
        for monitor in monitors {
            monitor.queue.async { event(monitor) }
        }
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        performEvent { $0.urlSession(session, didBecomeInvalidWithError: error) }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        performEvent { $0.urlSession(session, task: task, didReceive: challenge) }
    }

    public func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        performEvent {
            $0.urlSession(session,
                          task: task,
                          didSendBodyData: bytesSent,
                          totalBytesSent: totalBytesSent,
                          totalBytesExpectedToSend: totalBytesExpectedToSend)
        }
    }

    public func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        performEvent {
            $0.urlSession(session, taskNeedsNewBodyStream: task)
        }
    }

    public func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) {
        performEvent {
            $0.urlSession(session,
                          task: task,
                          willPerformHTTPRedirection: response,
                          newRequest: request)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        performEvent { $0.urlSession(session, task: task, didFinishCollecting: metrics) }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        performEvent { $0.urlSession(session, task: task, didCompleteWithError: error) }
    }

    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        performEvent { $0.urlSession(session, taskIsWaitingForConnectivity: task) }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        performEvent { $0.urlSession(session, dataTask: dataTask, didReceive: data) }
    }

    public func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse) {
        performEvent { $0.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse) }
    }

    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        performEvent {
            $0.urlSession(session,
                          downloadTask: downloadTask,
                          didResumeAtOffset: fileOffset,
                          expectedTotalBytes: expectedTotalBytes)
        }
    }

    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        performEvent {
            $0.urlSession(session,
                          downloadTask: downloadTask,
                          didWriteData: bytesWritten,
                          totalBytesWritten: totalBytesWritten,
                          totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }

    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        performEvent { $0.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location) }
    }

    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        performEvent { $0.request(request, didCreateURLRequest: urlRequest) }
    }

    public func request(_ request: Request, didFailToCreateURLRequestWithError error: Error) {
        performEvent { $0.request(request, didFailToCreateURLRequestWithError: error) }
    }

    public func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        performEvent { $0.request(request, didAdaptInitialRequest: initialRequest, to: adaptedRequest) }
    }

    public func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: Error) {
        performEvent { $0.request(request, didFailToAdaptURLRequest: initialRequest, withError: error) }
    }

    public func request(_ request: Request, didCreateTask task: URLSessionTask) {
        performEvent { $0.request(request, didCreateTask: task) }
    }

    public func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        performEvent { $0.request(request, didGatherMetrics: metrics) }
    }

    public func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: Error) {
        performEvent { $0.request(request, didFailTask: task, earlyWithError: error) }
    }

    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        performEvent { $0.request(request, didCompleteTask: task, with: error) }
    }

    public func requestDidFinish(_ request: Request) {
        performEvent { $0.requestDidFinish(request) }
    }

    public func requestDidResume(_ request: Request) {
        performEvent { $0.requestDidResume(request) }
    }

    public func requestDidSuspend(_ request: Request) {
        performEvent { $0.requestDidSuspend(request) }
    }

    public func requestDidCancel(_ request: Request) {
        performEvent { $0.requestDidCancel(request) }
    }
}

public final class NSLoggingEventMonitor: EventMonitor {
    public let queue = DispatchQueue(label: "org.alamofire.nsLoggingEventMonitorQueue", qos: .background)

    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        NSLog("Request: \(request) didCreateURLRequest: \(urlRequest)")
    }

    public func request(_ request: Request, didFailToCreateURLRequestWithError error: Error) {
        NSLog("Request: \(request) didFailToCreateURLRequestWithError: \(error)")
    }

    public func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        NSLog("Request: \(request) didAdaptInitialRequest \(initialRequest) to \(adaptedRequest)")
    }

    public func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: Error) {
        NSLog("Request: \(request) didFailToAdaptURLRequest \(initialRequest) withError \(error)")
    }

    public func request(_ request: Request, didCreateTask task: URLSessionTask) {
        NSLog("Request: \(request) didCreateTask \(task)")
    }

    public func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        NSLog("Request: \(request) didGatherMetrics \(metrics)")
    }

    public func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: Error) {
        NSLog("Request: \(request) didFailTask \(task) earlyWithError \(error)")
    }

    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        NSLog("Request: \(request) didCompleteTask \(task) withError: \(error?.localizedDescription ?? "None")")
    }

    public func requestDidFinish(_ request: Request) {
        NSLog("Request: \(request) didFinish")
    }

    public func requestDidResume(_ request: Request) {
        NSLog("Request: \(request) didResume")
    }

    public func requestDidSuspend(_ request: Request) {
        NSLog("Request: \(request) didSuspend")
    }

    public func requestDidCancel(_ request: Request) {
        NSLog("Request: \(request) didCancel")
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        NSLog("URLSession: \(session), didBecomeInvalidWithError: \(error?.localizedDescription ?? "None")")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        NSLog("URLSession: \(session), task: \(task), didReceiveChallenge: \(challenge)")
    }

    public func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        NSLog("URLSession: \(session), task: \(task), didSendBodyData: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSent: \(totalBytesExpectedToSend)")
    }

    public func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        NSLog("URLSession: \(session), taskNeedsNewBodyStream: \(task)")
    }

    public func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) {
        NSLog("URLSession: \(session), task: \(task), willPerformHTTPRedirection: \(response), newRequest: \(request)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        NSLog("URLSession: \(session), task: \(task), didFinishCollecting: \(metrics)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("URLSession: \(session), task: \(task), didCompleteWithError: \(error?.localizedDescription ?? "None")")
    }

    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        NSLog("URLSession: \(session), taskIsWaitingForConnectivity: \(task)")
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("URLSession: \(session), dataTask: \(dataTask), didReceiveDataOfLength: \(data.count)")
    }

    public func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse) {
        NSLog("URLSession: \(session), dataTask: \(dataTask), willCacheResponse: \(proposedResponse)")
    }

    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didResumeAtOffset: \(fileOffset), expectedTotalBytes: \(expectedTotalBytes)")
    }

    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didWriteData bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
    }

    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didFinishDownloadingTo: \(location)")
    }
}

public final class ClosureEventMonitor: EventMonitor {
    /// Overrides default behavior for URLSessionDelegate method `urlSession(_:didBecomeInvalidWithError:)`.
    open var sessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)?

    /// Overrides default behavior for URLSessionTaskDelegate method `urlSession(_:task:didReceive:completionHandler:)`.
    open var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> Void)?

    /// Overrides default behavior for URLSessionTaskDelegate method `urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)`.
    open var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?

    /// Overrides default behavior for URLSessionTaskDelegate method `urlSession(_:task:needNewBodyStream:)`.
    open var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> Void)?

    /// Overrides default behavior for URLSessionTaskDelegate method `urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`.
    open var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> Void)?


    open var taskDidFinishCollectingMetrics: ((URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void)?

    /// Overrides default behavior for URLSessionTaskDelegate method `urlSession(_:task:didCompleteWithError:)`.
    open var taskDidComplete: ((URLSession, URLSessionTask, Error?) -> Void)?

    open var taskIsWaitingForConnectivity: ((URLSession, URLSessionTask) -> Void)?

    /// Overrides default behavior for URLSessionDataDelegate method `urlSession(_:dataTask:didReceive:)`.
    open var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?

    /// Overrides default behavior for URLSessionDataDelegate method `urlSession(_:dataTask:willCacheResponse:completionHandler:)`.
    open var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> Void)?

    // MARK: URLSessionDownloadDelegate Overrides

    /// Overrides default behavior for URLSessionDownloadDelegate method `urlSession(_:downloadTask:didFinishDownloadingTo:)`.
    open var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> Void)?

    /// Overrides default behavior for URLSessionDownloadDelegate method `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)`.
    open var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?

    /// Overrides default behavior for URLSessionDownloadDelegate method `urlSession(_:downloadTask:didResumeAtOffset:expectedTotalBytes:)`.
    open var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?

    open var requestDidCreateURLRequest: ((Request, URLRequest) -> Void)?
    open var requestDidFailToCreateURLRequestWithError: ((Request, Error) -> Void)?
    open var requestDidAdaptInitialRequestToAdaptedRequest: ((Request, URLRequest, URLRequest) -> Void)?
    open var requestDidFailToAdaptURLRequestWithError: ((Request, URLRequest, Error) -> Void)?
    open var requestDidCreateTask: ((Request, URLSessionTask) -> Void)?
    open var requestDidGatherMetrics: ((Request, URLSessionTaskMetrics) -> Void)?
    open var requestDidFailTaskEarlyWithError: ((Request, URLSessionTask, Error) -> Void)?
    open var requestDidCompleteTaskWithError: ((Request, URLSessionTask, Error?) -> Void)?
    open var requestDidResume: ((Request) -> Void)?
    open var requestDidSuspend: ((Request) -> Void)?
    open var requestDidCancel: ((Request) -> Void)?
    open var requestDidFinish: ((Request) -> Void)?

    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        requestDidCreateURLRequest?(request, urlRequest)
    }

    public func request(_ request: Request, didFailToCreateURLRequestWithError error: Error) {
        requestDidFailToCreateURLRequestWithError?(request, error)
    }

    public func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        requestDidAdaptInitialRequestToAdaptedRequest?(request, initialRequest, adaptedRequest)
    }

    public func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: Error) {
        requestDidFailToAdaptURLRequestWithError?(request, initialRequest, error)
    }

    public func request(_ request: Request, didCreateTask task: URLSessionTask) {
        requestDidCreateTask?(request, task)
    }

    public func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        requestDidGatherMetrics?(request, metrics)
    }

    public func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: Error) {
        requestDidFailTaskEarlyWithError?(request, task, error)
    }

    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        requestDidCompleteTaskWithError?(request, task, error)
    }

    public func requestDidFinish(_ request: Request) {
        requestDidFinish?(request)
    }

    public func requestDidResume(_ request: Request) {
        requestDidResume?(request)
    }

    public func requestDidSuspend(_ request: Request) {
        requestDidSuspend?(request)
    }

    public func requestDidCancel(_ request: Request) {
        requestDidCancel?(request)
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        sessionDidBecomeInvalidWithError?(session, error)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        taskDidReceiveChallenge?(session, task, challenge)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        taskDidSendBodyData?(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }

    public func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        taskNeedNewBodyStream?(session, task)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) {
        taskWillPerformHTTPRedirection?(session, task, response, request)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        taskDidFinishCollectingMetrics?(session, task, metrics)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        taskDidComplete?(session, task, error)
    }

    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        taskIsWaitingForConnectivity?(session, task)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataTaskDidReceiveData?(session, dataTask, data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse) {
        dataTaskWillCacheResponse?(session, dataTask, proposedResponse)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloadTaskDidFinishDownloadingToURL?(session, downloadTask, location)
    }
}
