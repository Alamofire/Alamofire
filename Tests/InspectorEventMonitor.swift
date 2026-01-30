//
//  InspectorEventMonitor.swift
//
//  Copyright (c) 2025 Alamofire Software Foundation (http://alamofire.org/)
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

@testable import Alamofire
import Foundation

final class InspectorEventMonitor: EventMonitor {
    let label: String
    let queue: DispatchQueue

    struct TimelineEvent {
        var date: Date
        var event: String
        var label: String
    }

    var events: [String] {
        _timeline.read { $0.map(\.event) }
    }

    var timeline: [TimelineEvent] {
        _timeline.read(\.self)
    }

    private let _timeline = Protected<[TimelineEvent]>([])

    init(label: String = "InspectorEventMonitor", queue: DispatchQueue = DispatchQueue(label: "org.alamofire.inspectorEventMonitor")) {
        self.label = label
        self.queue = queue
    }

    func pendingEvents() async {
        await queue.pendingWork()
    }

    private func append(_ event: String) {
        _timeline.write { $0.append(TimelineEvent(date: .now, event: event, label: label)) }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        append("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        append("\(#function)")
    }

    func request(_ request: Request, didCreateInitialURLRequest urlRequest: URLRequest) {
        append("\(#function)")
    }

    func request(_ request: Request, didFailToCreateURLRequestWithError error: any Error) {
        append("\(#function)")
    }

    func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        append("\(#function)")
    }

    func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: any Error) {
        append("\(#function)")
    }

    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        append("\(#function)")
    }

    func request(_ request: Request, didCreateTask task: URLSessionTask) {
        append("\(#function)")
    }

    func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        append("\(#function)")
    }

    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: any Error) {
        append("\(#function)")
    }

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: (any Error)?) {
        append("\(#function)")
    }

    func requestDidFinish(_ request: Request) {
        append("\(#function)")
    }

    func requestDidResume(_ request: Request) {
        append("\(#function)")
    }

    func request(_ request: Request, didResumeTask task: URLSessionTask) {
        append("\(#function)")
    }

    func requestDidSuspend(_ request: Request) {
        append("\(#function)")
    }

    func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        append("\(#function)")
    }

    func requestDidCancel(_ request: Request) {
        append("\(#function)")
    }

    func request(_ request: Request, didCancelTask task: URLSessionTask) {
        append("\(#function)")
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        append("\(#function)")
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        append("\(#function)")
    }

    func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>) {
        append("\(#function)")
    }

    func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Data?, AFError>) {
        append("\(#function)")
    }

    func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>) {
        append("\(#function)")
    }

    func requestIsRetrying(_ request: Request) {
        append("\(#function)")
    }

    func request(_ request: DataRequest, didValidateRequest urlRequest: URLRequest?, response: HTTPURLResponse, data: Data?, withResult result: Request.ValidationResult) {
        append("\(#function)")
    }

    func request(_ request: DataStreamRequest, didValidateRequest urlRequest: URLRequest?, response: HTTPURLResponse, withResult result: Request.ValidationResult) {
        append("\(#function)")
    }

    func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>) {
        append("\(#function)")
    }

    func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        append("\(#function)")
    }

    func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: any Error) {
        append("\(#function)")
    }

    func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        append("\(#function)")
    }

    func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: Result<URL, any Error>) {
        append("\(#function)")
    }

    func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        append("\(#function)")
    }

    func request(_ request: DownloadRequest, didValidateRequest urlRequest: URLRequest?, response: HTTPURLResponse, temporaryURL: URL?, destinationURL: URL?, withResult result: Request.ValidationResult) {
        append("\(#function)")
    }
}
