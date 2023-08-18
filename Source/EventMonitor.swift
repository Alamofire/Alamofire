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
    /// The `DispatchQueue` onto which Alamofire's root `CompositeEventMonitor` will dispatch events. `.main` by default.
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
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask)

    // MARK: URLSessionDataDelegate Events

    /// Event called during `URLSessionDataDelegate`'s `urlSession(_:dataTask:didReceive:completionHandler:)` method.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse)

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

    /// Event called when a `URLRequest` is first created for a `Request`. If a `RequestAdapter` is active, the
    /// `URLRequest` will be adapted before being issued.
    func request(_ request: Request, didCreateInitialURLRequest urlRequest: URLRequest)

    /// Event called when the attempt to create a `URLRequest` from a `Request`'s original `URLRequestConvertible` value fails.
    func request(_ request: Request, didFailToCreateURLRequestWithError error: AFError)

    /// Event called when a `RequestAdapter` adapts the `Request`'s initial `URLRequest`.
    func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest)

    /// Event called when a `RequestAdapter` fails to adapt the `Request`'s initial `URLRequest`.
    func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: AFError)

    /// Event called when a final `URLRequest` is created for a `Request`.
    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest)

    /// Event called when a `URLSessionTask` subclass instance is created for a `Request`.
    func request(_ request: Request, didCreateTask task: URLSessionTask)

    /// Event called when a `Request` receives a `URLSessionTaskMetrics` value.
    func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics)

    /// Event called when a `Request` fails due to an error created by Alamofire. e.g. When certificate pinning fails.
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError)

    /// Event called when a `Request`'s task completes, possibly with an error. A `Request` may receive this event
    /// multiple times if it is retried.
    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?)

    /// Event called when a `Request` is about to be retried.
    func requestIsRetrying(_ request: Request)

    /// Event called when a `Request` finishes and response serializers are being called.
    func requestDidFinish(_ request: Request)

    /// Event called when a `Request` receives a `resume` call.
    func requestDidResume(_ request: Request)

    /// Event called when a `Request`'s associated `URLSessionTask` is resumed.
    func request(_ request: Request, didResumeTask task: URLSessionTask)

    /// Event called when a `Request` receives a `suspend` call.
    func requestDidSuspend(_ request: Request)

    /// Event called when a `Request`'s associated `URLSessionTask` is suspended.
    func request(_ request: Request, didSuspendTask task: URLSessionTask)

    /// Event called when a `Request` receives a `cancel` call.
    func requestDidCancel(_ request: Request)

    /// Event called when a `Request`'s associated `URLSessionTask` is cancelled.
    func request(_ request: Request, didCancelTask task: URLSessionTask)

    // MARK: DataRequest Events

    /// Event called when a `DataRequest` calls a `Validation`.
    func request(_ request: DataRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 data: Data?,
                 withResult result: Request.ValidationResult)

    /// Event called when a `DataRequest` creates a `DataResponse<Data?>` value without calling a `ResponseSerializer`.
    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>)

    /// Event called when a `DataRequest` calls a `ResponseSerializer` and creates a generic `DataResponse<Value, AFError>`.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>)

    // MARK: DataStreamRequest Events

    /// Event called when a `DataStreamRequest` calls a `Validation` closure.
    ///
    /// - Parameters:
    ///   - request:    `DataStreamRequest` which is calling the `Validation`.
    ///   - urlRequest: `URLRequest` of the request being validated.
    ///   - response:   `HTTPURLResponse` of the request being validated.
    ///   - result:      Produced `ValidationResult`.
    func request(_ request: DataStreamRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 withResult result: Request.ValidationResult)

    /// Event called when a `DataStreamSerializer` produces a value from streamed `Data`.
    ///
    /// - Parameters:
    ///   - request: `DataStreamRequest` for which the value was serialized.
    ///   - result:  `Result` of the serialization attempt.
    func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>)

    // MARK: UploadRequest Events

    /// Event called when an `UploadRequest` creates its `Uploadable` value, indicating the type of upload it represents.
    func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable)

    /// Event called when an `UploadRequest` failed to create its `Uploadable` value due to an error.
    func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: AFError)

    /// Event called when an `UploadRequest` provides the `InputStream` from its `Uploadable` value. This only occurs if
    /// the `InputStream` does not wrap a `Data` value or file `URL`.
    func request(_ request: UploadRequest, didProvideInputStream stream: InputStream)

    // MARK: DownloadRequest Events

    /// Event called when a `DownloadRequest`'s `URLSessionDownloadTask` finishes and the temporary file has been moved.
    func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: Result<URL, AFError>)

    /// Event called when a `DownloadRequest`'s `Destination` closure is called and creates the destination URL the
    /// downloaded file will be moved to.
    func request(_ request: DownloadRequest, didCreateDestinationURL url: URL)

    /// Event called when a `DownloadRequest` calls a `Validation`.
    func request(_ request: DownloadRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 fileURL: URL?,
                 withResult result: Request.ValidationResult)

    /// Event called when a `DownloadRequest` creates a `DownloadResponse<URL?, AFError>` without calling a `ResponseSerializer`.
    func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>)

    /// Event called when a `DownloadRequest` calls a `DownloadResponseSerializer` and creates a generic `DownloadResponse<Value, AFError>`
    func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>)
}

extension EventMonitor {
    /// The default queue on which `CompositeEventMonitor`s will call the `EventMonitor` methods. `.main` by default.
    public var queue: DispatchQueue { .main }

    // MARK: Default Implementations

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {}
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge) {}
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didSendBodyData bytesSent: Int64,
                           totalBytesSent: Int64,
                           totalBytesExpectedToSend: Int64) {}
    public func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {}
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest) {}
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didFinishCollecting metrics: URLSessionTaskMetrics) {}
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {}
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {}
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {}
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {}
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           willCacheResponse proposedResponse: CachedURLResponse) {}
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didResumeAtOffset fileOffset: Int64,
                           expectedTotalBytes: Int64) {}
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {}
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {}
    public func request(_ request: Request, didCreateInitialURLRequest urlRequest: URLRequest) {}
    public func request(_ request: Request, didFailToCreateURLRequestWithError error: AFError) {}
    public func request(_ request: Request,
                        didAdaptInitialRequest initialRequest: URLRequest,
                        to adaptedRequest: URLRequest) {}
    public func request(_ request: Request,
                        didFailToAdaptURLRequest initialRequest: URLRequest,
                        withError error: AFError) {}
    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {}
    public func request(_ request: Request, didCreateTask task: URLSessionTask) {}
    public func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {}
    public func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError) {}
    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {}
    public func requestIsRetrying(_ request: Request) {}
    public func requestDidFinish(_ request: Request) {}
    public func requestDidResume(_ request: Request) {}
    public func request(_ request: Request, didResumeTask task: URLSessionTask) {}
    public func requestDidSuspend(_ request: Request) {}
    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {}
    public func requestDidCancel(_ request: Request) {}
    public func request(_ request: Request, didCancelTask task: URLSessionTask) {}
    public func request(_ request: DataRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        data: Data?,
                        withResult result: Request.ValidationResult) {}
    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {}
    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {}
    public func request(_ request: DataStreamRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        withResult result: Request.ValidationResult) {}
    public func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>) {}
    public func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {}
    public func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: AFError) {}
    public func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {}
    public func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: Result<URL, AFError>) {}
    public func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {}
    public func request(_ request: DownloadRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        fileURL: URL?,
                        withResult result: Request.ValidationResult) {}
    public func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>) {}
    public func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>) {}
}

/// An `EventMonitor` which can contain multiple `EventMonitor`s and calls their methods on their queues.
public final class CompositeEventMonitor: EventMonitor {
    public let queue = DispatchQueue(label: "org.alamofire.compositeEventMonitor", qos: .utility)

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

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        performEvent { $0.urlSession(session, dataTask: dataTask, didReceive: response) }
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

    public func request(_ request: Request, didCreateInitialURLRequest urlRequest: URLRequest) {
        performEvent { $0.request(request, didCreateInitialURLRequest: urlRequest) }
    }

    public func request(_ request: Request, didFailToCreateURLRequestWithError error: AFError) {
        performEvent { $0.request(request, didFailToCreateURLRequestWithError: error) }
    }

    public func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        performEvent { $0.request(request, didAdaptInitialRequest: initialRequest, to: adaptedRequest) }
    }

    public func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: AFError) {
        performEvent { $0.request(request, didFailToAdaptURLRequest: initialRequest, withError: error) }
    }

    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        performEvent { $0.request(request, didCreateURLRequest: urlRequest) }
    }

    public func request(_ request: Request, didCreateTask task: URLSessionTask) {
        performEvent { $0.request(request, didCreateTask: task) }
    }

    public func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        performEvent { $0.request(request, didGatherMetrics: metrics) }
    }

    public func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError) {
        performEvent { $0.request(request, didFailTask: task, earlyWithError: error) }
    }

    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
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

    public func request(_ request: Request, didResumeTask task: URLSessionTask) {
        performEvent { $0.request(request, didResumeTask: task) }
    }

    public func requestDidSuspend(_ request: Request) {
        performEvent { $0.requestDidSuspend(request) }
    }

    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        performEvent { $0.request(request, didSuspendTask: task) }
    }

    public func requestDidCancel(_ request: Request) {
        performEvent { $0.requestDidCancel(request) }
    }

    public func request(_ request: Request, didCancelTask task: URLSessionTask) {
        performEvent { $0.request(request, didCancelTask: task) }
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

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }

    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }

    public func request(_ request: DataStreamRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        withResult result: Request.ValidationResult) {
        performEvent { $0.request(request,
                                  didValidateRequest: urlRequest,
                                  response: response,
                                  withResult: result)
        }
    }

    public func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>) {
        performEvent { $0.request(request, didParseStream: result) }
    }

    public func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        performEvent { $0.request(request, didCreateUploadable: uploadable) }
    }

    public func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: AFError) {
        performEvent { $0.request(request, didFailToCreateUploadableWithError: error) }
    }

    public func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        performEvent { $0.request(request, didProvideInputStream: stream) }
    }

    public func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: Result<URL, AFError>) {
        performEvent { $0.request(request, didFinishDownloadingUsing: task, with: result) }
    }

    public func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        performEvent { $0.request(request, didCreateDestinationURL: url) }
    }

    public func request(_ request: DownloadRequest,
                        didValidateRequest urlRequest: URLRequest?,
                        response: HTTPURLResponse,
                        fileURL: URL?,
                        withResult result: Request.ValidationResult) {
        performEvent { $0.request(request,
                                  didValidateRequest: urlRequest,
                                  response: response,
                                  fileURL: fileURL,
                                  withResult: result) }
    }

    public func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }

    public func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>) {
        performEvent { $0.request(request, didParseResponse: response) }
    }
}

/// `EventMonitor` that allows optional closures to be set to receive events.
open class ClosureEventMonitor: EventMonitor {
    /// Closure called on the `urlSession(_:didBecomeInvalidWithError:)` event.
    open var sessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)?

    /// Closure called on the `urlSession(_:task:didReceive:completionHandler:)`.
    open var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> Void)?

    /// Closure that receives `urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)` event.
    open var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?

    /// Closure called on the `urlSession(_:task:needNewBodyStream:)` event.
    open var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> Void)?

    /// Closure called on the `urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)` event.
    open var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> Void)?

    /// Closure called on the `urlSession(_:task:didFinishCollecting:)` event.
    open var taskDidFinishCollectingMetrics: ((URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void)?

    /// Closure called on the `urlSession(_:task:didCompleteWithError:)` event.
    open var taskDidComplete: ((URLSession, URLSessionTask, Error?) -> Void)?

    /// Closure called on the `urlSession(_:taskIsWaitingForConnectivity:)` event.
    open var taskIsWaitingForConnectivity: ((URLSession, URLSessionTask) -> Void)?

    /// Closure called on the `urlSession(_:dataTask:didReceive:completionHandler:)` event.
    open var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> Void)?

    /// Closure that receives the `urlSession(_:dataTask:didReceive:)` event.
    open var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?

    /// Closure called on the `urlSession(_:dataTask:willCacheResponse:completionHandler:)` event.
    open var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> Void)?

    /// Closure called on the `urlSession(_:downloadTask:didFinishDownloadingTo:)` event.
    open var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> Void)?

    /// Closure called on the `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)`
    /// event.
    open var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?

    /// Closure called on the `urlSession(_:downloadTask:didResumeAtOffset:expectedTotalBytes:)` event.
    open var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?

    // MARK: - Request Events

    /// Closure called on the `request(_:didCreateInitialURLRequest:)` event.
    open var requestDidCreateInitialURLRequest: ((Request, URLRequest) -> Void)?

    /// Closure called on the `request(_:didFailToCreateURLRequestWithError:)` event.
    open var requestDidFailToCreateURLRequestWithError: ((Request, AFError) -> Void)?

    /// Closure called on the `request(_:didAdaptInitialRequest:to:)` event.
    open var requestDidAdaptInitialRequestToAdaptedRequest: ((Request, URLRequest, URLRequest) -> Void)?

    /// Closure called on the `request(_:didFailToAdaptURLRequest:withError:)` event.
    open var requestDidFailToAdaptURLRequestWithError: ((Request, URLRequest, AFError) -> Void)?

    /// Closure called on the `request(_:didCreateURLRequest:)` event.
    open var requestDidCreateURLRequest: ((Request, URLRequest) -> Void)?

    /// Closure called on the `request(_:didCreateTask:)` event.
    open var requestDidCreateTask: ((Request, URLSessionTask) -> Void)?

    /// Closure called on the `request(_:didGatherMetrics:)` event.
    open var requestDidGatherMetrics: ((Request, URLSessionTaskMetrics) -> Void)?

    /// Closure called on the `request(_:didFailTask:earlyWithError:)` event.
    open var requestDidFailTaskEarlyWithError: ((Request, URLSessionTask, AFError) -> Void)?

    /// Closure called on the `request(_:didCompleteTask:with:)` event.
    open var requestDidCompleteTaskWithError: ((Request, URLSessionTask, AFError?) -> Void)?

    /// Closure called on the `requestIsRetrying(_:)` event.
    open var requestIsRetrying: ((Request) -> Void)?

    /// Closure called on the `requestDidFinish(_:)` event.
    open var requestDidFinish: ((Request) -> Void)?

    /// Closure called on the `requestDidResume(_:)` event.
    open var requestDidResume: ((Request) -> Void)?

    /// Closure called on the `request(_:didResumeTask:)` event.
    open var requestDidResumeTask: ((Request, URLSessionTask) -> Void)?

    /// Closure called on the `requestDidSuspend(_:)` event.
    open var requestDidSuspend: ((Request) -> Void)?

    /// Closure called on the `request(_:didSuspendTask:)` event.
    open var requestDidSuspendTask: ((Request, URLSessionTask) -> Void)?

    /// Closure called on the `requestDidCancel(_:)` event.
    open var requestDidCancel: ((Request) -> Void)?

    /// Closure called on the `request(_:didCancelTask:)` event.
    open var requestDidCancelTask: ((Request, URLSessionTask) -> Void)?

    /// Closure called on the `request(_:didValidateRequest:response:data:withResult:)` event.
    open var requestDidValidateRequestResponseDataWithResult: ((DataRequest, URLRequest?, HTTPURLResponse, Data?, Request.ValidationResult) -> Void)?

    /// Closure called on the `request(_:didParseResponse:)` event.
    open var requestDidParseResponse: ((DataRequest, DataResponse<Data?, AFError>) -> Void)?

    /// Closure called on the `request(_:didValidateRequest:response:withResult:)` event.
    open var requestDidValidateRequestResponseWithResult: ((DataStreamRequest, URLRequest?, HTTPURLResponse, Request.ValidationResult) -> Void)?

    /// Closure called on the `request(_:didCreateUploadable:)` event.
    open var requestDidCreateUploadable: ((UploadRequest, UploadRequest.Uploadable) -> Void)?

    /// Closure called on the `request(_:didFailToCreateUploadableWithError:)` event.
    open var requestDidFailToCreateUploadableWithError: ((UploadRequest, AFError) -> Void)?

    /// Closure called on the `request(_:didProvideInputStream:)` event.
    open var requestDidProvideInputStream: ((UploadRequest, InputStream) -> Void)?

    /// Closure called on the `request(_:didFinishDownloadingUsing:with:)` event.
    open var requestDidFinishDownloadingUsingTaskWithResult: ((DownloadRequest, URLSessionTask, Result<URL, AFError>) -> Void)?

    /// Closure called on the `request(_:didCreateDestinationURL:)` event.
    open var requestDidCreateDestinationURL: ((DownloadRequest, URL) -> Void)?

    /// Closure called on the `request(_:didValidateRequest:response:temporaryURL:destinationURL:withResult:)` event.
    open var requestDidValidateRequestResponseFileURLWithResult: ((DownloadRequest, URLRequest?, HTTPURLResponse, URL?, Request.ValidationResult) -> Void)?

    /// Closure called on the `request(_:didParseResponse:)` event.
    open var requestDidParseDownloadResponse: ((DownloadRequest, DownloadResponse<URL?, AFError>) -> Void)?

    public let queue: DispatchQueue

    /// Creates an instance using the provided queue.
    ///
    /// - Parameter queue: `DispatchQueue` on which events will fired. `.main` by default.
    public init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        sessionDidBecomeInvalidWithError?(session, error)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        taskDidReceiveChallenge?(session, task, challenge)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didSendBodyData bytesSent: Int64,
                         totalBytesSent: Int64,
                         totalBytesExpectedToSend: Int64) {
        taskDidSendBodyData?(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }

    open func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        taskNeedNewBodyStream?(session, task)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest) {
        taskWillPerformHTTPRedirection?(session, task, response, request)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        taskDidFinishCollectingMetrics?(session, task, metrics)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        taskDidComplete?(session, task, error)
    }

    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        taskIsWaitingForConnectivity?(session, task)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        dataTaskDidReceiveResponse?(session, dataTask, response)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataTaskDidReceiveData?(session, dataTask, data)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse) {
        dataTaskWillCacheResponse?(session, dataTask, proposedResponse)
    }

    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didResumeAtOffset fileOffset: Int64,
                         expectedTotalBytes: Int64) {
        downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
    }

    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
        downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloadTaskDidFinishDownloadingToURL?(session, downloadTask, location)
    }

    // MARK: Request Events

    open func request(_ request: Request, didCreateInitialURLRequest urlRequest: URLRequest) {
        requestDidCreateInitialURLRequest?(request, urlRequest)
    }

    open func request(_ request: Request, didFailToCreateURLRequestWithError error: AFError) {
        requestDidFailToCreateURLRequestWithError?(request, error)
    }

    open func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        requestDidAdaptInitialRequestToAdaptedRequest?(request, initialRequest, adaptedRequest)
    }

    open func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: AFError) {
        requestDidFailToAdaptURLRequestWithError?(request, initialRequest, error)
    }

    open func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        requestDidCreateURLRequest?(request, urlRequest)
    }

    open func request(_ request: Request, didCreateTask task: URLSessionTask) {
        requestDidCreateTask?(request, task)
    }

    open func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        requestDidGatherMetrics?(request, metrics)
    }

    open func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError) {
        requestDidFailTaskEarlyWithError?(request, task, error)
    }

    open func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
        requestDidCompleteTaskWithError?(request, task, error)
    }

    open func requestIsRetrying(_ request: Request) {
        requestIsRetrying?(request)
    }

    open func requestDidFinish(_ request: Request) {
        requestDidFinish?(request)
    }

    open func requestDidResume(_ request: Request) {
        requestDidResume?(request)
    }

    public func request(_ request: Request, didResumeTask task: URLSessionTask) {
        requestDidResumeTask?(request, task)
    }

    open func requestDidSuspend(_ request: Request) {
        requestDidSuspend?(request)
    }

    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        requestDidSuspendTask?(request, task)
    }

    open func requestDidCancel(_ request: Request) {
        requestDidCancel?(request)
    }

    public func request(_ request: Request, didCancelTask task: URLSessionTask) {
        requestDidCancelTask?(request, task)
    }

    open func request(_ request: DataRequest,
                      didValidateRequest urlRequest: URLRequest?,
                      response: HTTPURLResponse,
                      data: Data?,
                      withResult result: Request.ValidationResult) {
        requestDidValidateRequestResponseDataWithResult?(request, urlRequest, response, data, result)
    }

    open func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        requestDidParseResponse?(request, response)
    }

    public func request(_ request: DataStreamRequest, didValidateRequest urlRequest: URLRequest?, response: HTTPURLResponse, withResult result: Request.ValidationResult) {
        requestDidValidateRequestResponseWithResult?(request, urlRequest, response, result)
    }

    open func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        requestDidCreateUploadable?(request, uploadable)
    }

    open func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: AFError) {
        requestDidFailToCreateUploadableWithError?(request, error)
    }

    open func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        requestDidProvideInputStream?(request, stream)
    }

    open func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: Result<URL, AFError>) {
        requestDidFinishDownloadingUsingTaskWithResult?(request, task, result)
    }

    open func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        requestDidCreateDestinationURL?(request, url)
    }

    open func request(_ request: DownloadRequest,
                      didValidateRequest urlRequest: URLRequest?,
                      response: HTTPURLResponse,
                      fileURL: URL?,
                      withResult result: Request.ValidationResult) {
        requestDidValidateRequestResponseFileURLWithResult?(request,
                                                            urlRequest,
                                                            response,
                                                            fileURL,
                                                            result)
    }

    open func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>) {
        requestDidParseDownloadResponse?(request, response)
    }
}
