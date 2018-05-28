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

/// Protocol outlining the lifetime events inside Alamofire. It includes both events received from the various
/// `URLSession` delegate protocols as well as various events from the lifetime of `Request` and its subclasses.
public protocol EventMonitor {
    /// The `DispatchQueue` onto which Alamofire's root `CompositeEventMonitor` will dispatch events. Defaults to `.main`.
    var queue: DispatchQueue { get }

    // MARK: - URLSession Events

    // MARK: URLSessionDelegate Events

    /// Event called during `URLSessionDelegate`'s `urlSession(_:didBecomeInvalidWithError:)` method.
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?)

    // MARK: URLSessionTaskDelegate Events

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:task:didReceive:completionHandler:)` method.
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge)

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)` method.
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64)

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:task:needNewBodyStream:)` method.
    func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask)

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)` method.
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest)

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:task:didFinishCollecting:)` method.
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics)

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:task:didCompleteWithError:)` method.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)

    /// Event called during `URLSessionTaskDelegate`'s `urlSession(_:taskIsWaitingForConnectivity:)` method.
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask)

    // MARK: URLSessionDataDelegate Events

    /// Event called during `URLSessionDataDelegate`'s `urlSession(_:dataTask:didReceive:)` method.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)

    /// Event called during `URLSessionDataDelegate`'s `urlSession(_:dataTask:willCacheResponse:completionHandler:)` method.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse)

    // MARK: URLSessionDownloadDelegate Events

    /// Event called during `URLSessionDownloadDelegate`'s `urlSession(_:downloadTask:didResumeAtOffset:expectedTotalBytes:)` method.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64)

    /// Event called during `URLSessionDownloadDelegate`'s `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` method.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64)

    /// Event called during `URLSessionDownloadDelegate`'s `urlSession(_:downloadTask:didFinishDownloadingTo:)` method.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)

    // MARK: - Request Events

    /// Event called when a `URLRequest` is first created for a `Request`.
    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest)

    /// Event called when the attempt to create a `URLRequest` from a `Request`'s original `URLRequestConvertible` value fails.
    func request(_ request: Request, didFailToCreateURLRequestWithError error: Error)

    /// Event called when a `RequestAdapter` adapts the `Request`'s initial `URLRequest`.
    func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest)

    /// Event called when a `RequestAdapter` fails to adapt the `Request`'s initial `URLRequest`.
    func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: Error)

    /// Event called when a `URLSessionTask` subclass instance is created for a `Request`.
    func request(_ request: Request, didCreateTask task: URLSessionTask)

    /// Event called when a `Request` receives a `URLSessionTaskMetrics` value.
    func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics)

    /// Event called when a `Request` fails due to an error created by Alamofire. e.g. When certificat pinning fails.
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: Error)

    /// Event called when a `Request`'s task completes, possibly with an error. A `Request` may recieve this event
    /// multiple times if it is retried.
    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?)

    /// Event called when a `Request` is about to be retried.
    func requestIsRetrying(_ request: Request)

    /// Event called when a `Request` finishes and response serializers are being called.
    func requestDidFinish(_ request: Request)

    /// Event called when a `Request` receives a `resume` call.
    func requestDidResume(_ request: Request)

    /// Event called when a `Request` receives a `suspend` call.
    func requestDidSuspend(_ request: Request)

    /// Event called when a `Request` receives a `cancel` call.
    func requestDidCancel(_ request: Request)

    // MARK: DataRequest Events

    /// Event called when a `DataRequest` calls a `Validation`.
    func request(_ request: DataRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 data: Data?,
                 withResult result: Request.ValidationResult)

    /// Event called when a `DataRequest` creates a `DataResponse<Data?>` value without calling a `ResponseSerializer`.
    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?>)

    /// Event called when a `DataRequest` calls a `ResponseSerializer` and creates a generic `DataResponse<Value>`.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value>)

    // MARK: UploadRequest Events

    /// Event called when an `UploadRequest` creates its `Uploadable` value, indicating the type of upload it represents.
    func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable)

    /// Event called when an `UploadRequest` failes to create its `Uploadable` value due to an error.
    func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: Error)

    /// Event called when an `UploadRequest` provides the `InputStream` from its `Uploadable` value. This only occurs if
    /// the `InputStream` does not wrap a `Data` value.
    func request(_ request: UploadRequest, didProvideInputStream stream: InputStream)

    // MARK: DownloadRequest Events

    /// Event called when a `DownloadRequest`'s `URLSessionDownloadTask` finishes with a temporary URL.
    func request(_ request: DownloadRequest, didCompleteTask task: URLSessionTask, with url: URL)

    /// Event called when a `DownloadRequest`'s `Destination` closure is called and creates the destination URL the
    /// downloaded file will be moved to.
    func request(_ request: DownloadRequest, didCreateDestinationURL url: URL)

    /// Event called when a `DownloadRequest` calls a `Validation`.
    func request(_ request: DownloadRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 temporaryURL: URL?,
                 destinationURL: URL?,
                 withResult result: Request.ValidationResult)

    /// Event called when a `DownloadRequest` creates a `DownloadResponse<URL?>` without calling a `ResponseSerializer`.
    func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?>)

    /// Event called when a `DownloadRequest` calls a `DownloadResponseSerializer` and creates a generic `DownloadResponse<Value>`
    func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value>)
}

extension EventMonitor {
    /// The default queue on which `CompositeEventMonitor`s will call the `EventMonitor` methods. Defaults to `.main`.
    public var queue: DispatchQueue { return .main }
}

/// An `EventMonitor` which can contain multiple `EventMonitor`s and calls their methods on their queues.
public final class CompositeEventMonitor: EventMonitor {
    public let queue = DispatchQueue(label: "org.alamofire.componsiteEventMonitor", qos: .background)

    let monitors: [EventMonitor]

    init(monitors: [EventMonitor]) {
        self.monitors = monitors
    }

    func performEvent(_ event: @escaping (EventMonitor) -> Void) {
        queue.async {
            for monitor in self.monitors {
                monitor.queue.async { event(monitor) }
            }
        }
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        performEvent { $0.urlSession(session, didBecomeInvalidWithError: error) }
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge) {
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

    public func requestIsRetrying(_ request: Request) {
        performEvent { $0.requestIsRetrying(request) }
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

    public func request(_ request: DataRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        data: Data?,
                        withResult result: Request.ValidationResult) {
        performEvent { $0.request(request,
                                  didValidateRequest: urlRequest,
                                  response: response,
                                  data: data,
                                  withResult: result)
        }
    }

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }

    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }

    public func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        performEvent { $0.request(request, didCreateUploadable: uploadable) }
    }

    public func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: Error) {
        performEvent { $0.request(request, didFailToCreateUploadableWithError: error) }
    }

    public func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        performEvent { $0.request(request, didProvideInputStream: stream) }
    }

    public func request(_ request: DownloadRequest, didCompleteTask task: URLSessionTask, with url: URL) {
        performEvent { $0.request(request, didCompleteTask: task, with: url) }
    }

    public func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        performEvent { $0.request(request, didCreateDestinationURL: url) }
    }

    public func request(_ request: DownloadRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        temporaryURL: URL?,
                        destinationURL: URL?,
                        withResult result: Request.ValidationResult) {
        performEvent { $0.request(request,
                                  didValidateRequest: urlRequest,
                                  response: response,
                                  temporaryURL: temporaryURL,
                                  destinationURL: destinationURL,
                                  withResult: result) }
    }

    public func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }

    public func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }
}

/// `EventMonitor` that allows optional closures to be set to receive events.
open class ClosureEventMonitor: EventMonitor {
    /// Closure that recieves the `urlSession(_:didBecomeInvalidWithError:)` event.
    open var sessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)?

    /// Closure that receives the `urlSession(_:task:didReceive:completionHandler:)`.
    open var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> Void)?

    /// Closure that receives `urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)` event.
    open var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?

    /// Closure that receives the `urlSession(_:task:needNewBodyStream:)` event.
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

    open var requestIsRetrying: ((Request) -> Void)?

    open var requestDidFinish: ((Request) -> Void)?

    open var requestDidResume: ((Request) -> Void)?
    open var requestDidSuspend: ((Request) -> Void)?
    open var requestDidCancel: ((Request) -> Void)?

    open var requestDidValidateRequestResponseDataWithResult: ((DataRequest, URLRequest?, HTTPURLResponse, Data?, Request.ValidationResult) -> Void)?
    open var requestDidParseResponse: ((DataRequest, DataResponse<Data?>) -> Void)?
    open var requestDidParseAnyResponse: ((DataRequest, DataResponse<Any>) -> Void)?

    open var requestDidCreateUploadable: ((UploadRequest, UploadRequest.Uploadable) -> Void)?
    open var requestDidFailToCreateUploadableWithError: ((UploadRequest, Error) -> Void)?
    open var requestDidProvideInputStream: ((UploadRequest, InputStream) -> Void)?

    open var requestDidCompleteTaskWithURL: ((DownloadRequest, URLSessionTask, URL) -> Void)?
    open var requestDidCreateDestinationURL: ((DownloadRequest, URL) -> Void)?
    open var requestDidValidateRequestResponseTemporaryURLDestinationURLWithResult: ((DownloadRequest, URLRequest?, HTTPURLResponse, URL?, URL?, Request.ValidationResult) -> Void)?
    open var requestDidParseDownloadResponse: ((DownloadRequest, DownloadResponse<URL?>) -> Void)?

    public let queue: DispatchQueue

    public init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        sessionDidBecomeInvalidWithError?(session, error)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        taskDidReceiveChallenge?(session, task, challenge)
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didSendBodyData bytesSent: Int64,
                           totalBytesSent: Int64,
                           totalBytesExpectedToSend: Int64) {
        taskDidSendBodyData?(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }

    public func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        taskNeedNewBodyStream?(session, task)
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest) {
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

    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didResumeAtOffset fileOffset: Int64,
                           expectedTotalBytes: Int64) {
        downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
    }

    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloadTaskDidFinishDownloadingToURL?(session, downloadTask, location)
    }

    // MARK: Request Events

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

    public func requestIsRetrying(_ request: Request) {
        requestIsRetrying?(request)
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

    public func request(_ request: DataRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        data: Data?,
                        withResult result: Request.ValidationResult) {
        requestDidValidateRequestResponseDataWithResult?(request, urlRequest, response, data, result)
    }

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?>) {
        requestDidParseResponse?(request, response)
    }

    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value>) {
        // TODO: Make all methods optional so this isn't required.
        requestDidParseAnyResponse?(request, response as! DataResponse<Any>)
    }

    public func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        requestDidCreateUploadable?(request, uploadable)
    }

    public func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: Error) {
        requestDidFailToCreateUploadableWithError?(request, error)
    }

    public func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        requestDidProvideInputStream?(request, stream)
    }

    public func request(_ request: DownloadRequest, didCompleteTask task: URLSessionTask, with url: URL) {
        requestDidCompleteTaskWithURL?(request, task, url)
    }

    public func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        requestDidCreateDestinationURL?(request, url)
    }

    public func request(_ request: DownloadRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        temporaryURL: URL?,
                        destinationURL: URL?,
                        withResult result: Request.ValidationResult) {
        requestDidValidateRequestResponseTemporaryURLDestinationURLWithResult?(request,
                                                                               urlRequest,
                                                                               response,
                                                                               temporaryURL,
                                                                               destinationURL,
                                                                               result)
    }

    public func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?>) {
        requestDidParseDownloadResponse?(request, response)
    }

    public func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value>) {
        // TODO: Make all methods optional so this isn't required.
    }
}
