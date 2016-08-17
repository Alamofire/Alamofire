//
//  Error.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

/// The task delegate is responsible for handling all delegate callbacks for the underlying task as well as
/// executing all operations attached to the serial operation queue upon task completion.
open class TaskDelegate: NSObject {

    // MARK: Properties

    /// The serial operation queue used to execute all operations after the task completes.
    open let queue: OperationQueue

    var task: URLSessionTask
    let progress: Progress

    var data: Data? { return nil }
    var error: NSError?

    var initialResponseTime: CFAbsoluteTime?
    var credential: URLCredential?

    // MARK: Lifecycle

    init(task: URLSessionTask) {
        self.task = task
        self.progress = Progress(totalUnitCount: 0)
        self.queue = {
            let operationQueue = OperationQueue()

            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.isSuspended = true
            operationQueue.qualityOfService = .utility

            return operationQueue
        }()
    }

    // MARK: NSURLSessionTaskDelegate

    var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> URLRequest?)?
    var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    var taskDidCompleteWithError: ((URLSession, URLSessionTask, NSError?) -> Void)?

    @objc(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void)
    {
        var redirectRequest: URLRequest? = request

        if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
            redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
        }

        completionHandler(redirectRequest)
    }

    @objc(URLSession:task:didReceiveChallenge:completionHandler:)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?

        if let taskDidReceiveChallenge = taskDidReceiveChallenge {
            (disposition, credential) = taskDidReceiveChallenge(session, task, challenge)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host

            if let serverTrustPolicy = session.serverTrustPolicyManager?.serverTrustPolicy(forHost: host),
                let serverTrust = challenge.protectionSpace.serverTrust
            {
                if serverTrustPolicy.evaluate(serverTrust, forHost: host) {
                    disposition = .useCredential
                    credential = URLCredential(trust: serverTrust)
                } else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
        } else {
            if challenge.previousFailureCount > 0 {
                disposition = .rejectProtectionSpace
            } else {
                credential = self.credential ?? session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)

                if credential != nil {
                    disposition = .useCredential
                }
            }
        }

        completionHandler(disposition, credential)
    }

    @objc(URLSession:task:needNewBodyStream:)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void)
    {
        var bodyStream: InputStream?

        if let taskNeedNewBodyStream = taskNeedNewBodyStream {
            bodyStream = taskNeedNewBodyStream(session, task)
        }

        completionHandler(bodyStream)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: NSError?) {
        if let taskDidCompleteWithError = taskDidCompleteWithError {
            taskDidCompleteWithError(session, task, error)
        } else {
            if let error = error {
                self.error = error

                if
                    let downloadDelegate = self as? DownloadTaskDelegate,
                    let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                {
                    downloadDelegate.resumeData = resumeData
                }
            }

            queue.isSuspended = false
        }
    }
}

// MARK: -

class DataTaskDelegate: TaskDelegate, URLSessionDataDelegate {

    // MARK: Properties

    var dataTask: URLSessionDataTask? { return task as? URLSessionDataTask }

    override var data: Data? {
        if dataStream != nil {
            return nil
        } else {
            return mutableData as Data
        }
    }

    var dataProgress: ((_ bytesReceived: Int64, _ totalBytesReceived: Int64, _ totalBytesExpectedToReceive: Int64) -> Void)?
    var dataStream: ((_ data: Data) -> Void)?

    private var totalBytesReceived: Int64 = 0
    private var mutableData: Data

    private var expectedContentLength: Int64?

    // MARK: Lifecycle

    override init(task: URLSessionTask) {
        mutableData = Data()
        super.init(task: task)
    }

    // MARK: NSURLSessionDataDelegate

    var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> URLSession.ResponseDisposition)?
    var dataTaskDidBecomeDownloadTask: ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?
    var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: ((URLSession.ResponseDisposition) -> Void))
    {
        var disposition: URLSession.ResponseDisposition = .allow

        expectedContentLength = response.expectedContentLength

        if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
            disposition = dataTaskDidReceiveResponse(session, dataTask, response)
        }

        completionHandler(disposition)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didBecome downloadTask: URLSessionDownloadTask)
    {
        dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }

        if let dataTaskDidReceiveData = dataTaskDidReceiveData {
            dataTaskDidReceiveData(session, dataTask, data)
        } else {
            if let dataStream = dataStream {
                dataStream(data)
            } else {
                mutableData.append(data)
            }

            let bytesReceived = Int64(data.count)
            totalBytesReceived += bytesReceived
            let totalBytesExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown

            progress.totalUnitCount = totalBytesExpected
            progress.completedUnitCount = totalBytesReceived

            dataProgress?(
                bytesReceived,
                totalBytesReceived,
                totalBytesExpected
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse,
        completionHandler: ((CachedURLResponse?) -> Void))
    {
        var cachedResponse: CachedURLResponse? = proposedResponse

        if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
            cachedResponse = dataTaskWillCacheResponse(session, dataTask, proposedResponse)
        }

        completionHandler(cachedResponse)
    }
}

// MARK: -

class DownloadTaskDelegate: TaskDelegate, URLSessionDownloadDelegate {

    // MARK: Properties

    var downloadTask: URLSessionDownloadTask? { return task as? URLSessionDownloadTask }
    var downloadProgress: ((Int64, Int64, Int64) -> Void)?

    var resumeData: Data?
    override var data: Data? { return resumeData }

    // MARK: NSURLSessionDownloadDelegate

    var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> URL)?
    var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
    var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL)
    {
        if let downloadTaskDidFinishDownloadingToURL = downloadTaskDidFinishDownloadingToURL {
            do {
                let destination = downloadTaskDidFinishDownloadingToURL(session, downloadTask, location)
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                self.error = error as NSError
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64)
    {
        if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }

        if let downloadTaskDidWriteData = downloadTaskDidWriteData {
            downloadTaskDidWriteData(
                session,
                downloadTask,
                bytesWritten,
                totalBytesWritten,
                totalBytesExpectedToWrite
            )
        } else {
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten

            downloadProgress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64)
    {
        if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
            downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
        } else {
            progress.totalUnitCount = expectedTotalBytes
            progress.completedUnitCount = fileOffset
        }
    }
}

// MARK: -

class UploadTaskDelegate: DataTaskDelegate {

    // MARK: Properties

    var uploadTask: URLSessionUploadTask? { return task as? URLSessionUploadTask }
    var uploadProgress: ((Int64, Int64, Int64) -> Void)!

    // MARK: NSURLSessionTaskDelegate

    var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?

    func URLSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64)
    {
        if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }

        if let taskDidSendBodyData = taskDidSendBodyData {
            taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
        } else {
            progress.totalUnitCount = totalBytesExpectedToSend
            progress.completedUnitCount = totalBytesSent

            uploadProgress?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
        }
    }
}
