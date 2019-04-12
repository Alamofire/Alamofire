//
//  NSLoggingEventMonitor.swift
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

import Alamofire
import Foundation

public final class NSLoggingEventMonitor: EventMonitor {
    public let queue = DispatchQueue(label: "org.alamofire.nsLoggingEventMonitorQueue", qos: .background)

    public init() { }

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

    public func request(_ request: Request, didResumeTask task: URLSessionTask) {
        NSLog("Request: \(request) didResumeTask: \(task)")
    }

    public func requestDidSuspend(_ request: Request) {
        NSLog("Request: \(request) didSuspend")
    }

    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        NSLog("Request: \(request) didSuspendTask: \(task)")
    }

    public func requestDidCancel(_ request: Request) {
        NSLog("Request: \(request) didCancel")
    }

    public func request(_ request: Request, didCancelTask task: URLSessionTask) {
        NSLog("Request: \(request) didCancelTask: \(task)")
    }

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?>) {
        NSLog("Request: \(request), didParseResponse: \(response)")
    }

    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value>) {
        NSLog("Request: \(request), didParseResponse: \(response)")
    }

    public func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Data?>) {
        NSLog("Request: \(request), didParseResponse: \(response)")
    }

    public func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value>) {
        NSLog("Request: \(request), didParseResponse: \(response)")
    }

    public func requestIsRetrying(_ request: Request) {
        NSLog("Request: \(request), isRetrying")
    }

    public func request(_ request: DataRequest, didValidateRequest urlRequest: URLRequest?, response: HTTPURLResponse, data: Data?, withResult result: Request.ValidationResult) {
        NSLog("Request: \(request), didValidateRequestWithResult: \(result)")
    }

    public func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        NSLog("Request: \(request), didCreateUploadable: \(uploadable)")
    }

    public func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: Error) {
        NSLog("Request: \(request), didFailToCreateUploadableWithError: \(error)")
    }

    public func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        NSLog("Request: \(request), didProvideInputStream: \(stream)")
    }

    public func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: AFResult<URL>) {
        NSLog("Request: \(request), didFinishDownloadingUsing: \(task), withResult: \(result)")
    }

    public func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        NSLog("Request: \(request), didCreateDestinationURL: \(url)")
    }

    public func request(_ request: DownloadRequest, didValidateRequest urlRequest: URLRequest?, response: HTTPURLResponse, temporaryURL: URL?, destinationURL: URL?, withResult result: Request.ValidationResult) {
        NSLog("Request: \(request), didValidateRequestWithResult: \(result)")
    }
}
