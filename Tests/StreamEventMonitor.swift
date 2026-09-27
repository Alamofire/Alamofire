//
//  StreamEventMonitor.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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

struct StreamEventMonitor: EventMonitor {
    let stream: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .unbounded)
        self.stream = stream
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, taskNeedsNewBodyStream task: URLSessionTask) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        continuation.yield("\(#function)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        continuation.yield("\(#function)")
    }

    #if canImport(Darwin) && !canImport(FoundationNetworking)
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        continuation.yield("\(#function)")
    }
    #endif

    func request(_ request: Request, didCreateInitialURLRequest urlRequest: URLRequest) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didFailToCreateURLRequestWithError error: any Error) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didAdaptInitialRequest initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didFailToAdaptURLRequest initialRequest: URLRequest, withError error: any Error) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didCreateTask task: URLSessionTask) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: any Error) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: (any Error)?) {
        continuation.yield("\(#function)")
    }

    func requestIsRetrying(_ request: Request) {
        continuation.yield("\(#function)")
    }

    func requestDidFinish(_ request: Request) {
        continuation.yield("\(#function)")
    }

    func requestDidResume(_ request: Request) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didResumeTask task: URLSessionTask) {
        continuation.yield("\(#function)")
    }

    func requestDidSuspend(_ request: Request) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        continuation.yield("\(#function)")
    }

    func requestDidCancel(_ request: Request) {
        continuation.yield("\(#function)")
    }

    func request(_ request: Request, didCancelTask task: URLSessionTask) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DataRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 data: Data?,
                 withResult result: Request.ValidationResult) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        continuation.yield("\(#function)")
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DataStreamRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 withResult result: Request.ValidationResult) {
        continuation.yield("\(#function)")
    }

    func request<Value>(_ request: DataStreamRequest, didParseStream result: Result<Value, AFError>) {
        continuation.yield("\(#function)")
    }

    func request(_ request: UploadRequest, didCreateUploadable uploadable: UploadRequest.Uploadable) {
        continuation.yield("\(#function)")
    }

    func request(_ request: UploadRequest, didFailToCreateUploadableWithError error: any Error) {
        continuation.yield("\(#function)")
    }

    func request(_ request: UploadRequest, didProvideInputStream stream: InputStream) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DownloadRequest, didFinishDownloadingUsing task: URLSessionTask, with result: Result<URL, any Error>) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DownloadRequest, didCreateDestinationURL url: URL) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DownloadRequest,
                 didValidateRequest urlRequest: URLRequest?,
                 response: HTTPURLResponse,
                 fileURL: URL?,
                 withResult result: Request.ValidationResult) {
        continuation.yield("\(#function)")
    }

    func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>) {
        continuation.yield("\(#function)")
    }

    func request<Value>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>) {
        continuation.yield("\(#function)")
    }

    #if canImport(Darwin) && !canImport(FoundationNetworking)
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request(_ request: WebSocketRequest, didConnectWithProtocol protocol: String?) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request(_ request: WebSocketRequest, didDisconnectWithCloseCode closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request(_ request: WebSocketRequest, didCloseWithCloseCode closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request(_ request: WebSocketRequest, didReceiveMessage message: URLSessionWebSocketTask.Message) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request<Success: Sendable, Failure: Error>(_ request: WebSocketRequest, didReceiveEvent event: WebSocketRequest.Event<Success, Failure>) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request(_ request: WebSocketRequest, didSendMessage message: URLSessionWebSocketTask.Message) {
        continuation.yield("\(#function)")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func request<Value: Sendable, Failure: Error>(_ request: WebSocketRequest,
                                                  didFailToSendMessage value: Value,
                                                  dueToError error: WebSocketRequest.SendError<Failure>) {
        continuation.yield("\(#function)")
    }
    #endif
}
