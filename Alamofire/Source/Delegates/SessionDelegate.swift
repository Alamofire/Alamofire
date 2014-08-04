// SessionDelegate.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

public class SessionDelegate: NSObject {
    
    private var subdelegates: [Int: TaskDelegate]
    internal subscript(task: NSURLSessionTask) -> TaskDelegate? {
        get {
            return self.subdelegates[task.taskIdentifier]
        }
        
        set(newValue) {
            self.subdelegates[task.taskIdentifier] = newValue
        }
    }
    
    public var sessionDidBecomeInvalidWithError: ((NSURLSession!, NSError!) -> Void)?
    public var sessionDidFinishEventsForBackgroundURLSession: ((NSURLSession!) -> Void)?
    public var sessionDidReceiveChallenge: ((NSURLSession!, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential!))?
    
    public var taskWillPerformHTTPRedirection: ((NSURLSession!, NSURLSessionTask!, NSHTTPURLResponse!, NSURLRequest!) -> (NSURLRequest!))?
    public var taskDidReceiveChallenge: ((NSURLSession!, NSURLSessionTask!, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential?))?
    public var taskDidSendBodyData: ((NSURLSession!, NSURLSessionTask!, Int64, Int64, Int64) -> Void)?
    public var taskNeedNewBodyStream: ((NSURLSession!, NSURLSessionTask!) -> (NSInputStream!))?
    
    public var dataTaskDidReceiveResponse: ((NSURLSession!, NSURLSessionDataTask!, NSURLResponse!) -> (NSURLSessionResponseDisposition))?
    public var dataTaskDidBecomeDownloadTask: ((NSURLSession!, NSURLSessionDataTask!) -> Void)?
    public var dataTaskDidReceiveData: ((NSURLSession!, NSURLSessionDataTask!, NSData!) -> Void)?
    public var dataTaskWillCacheResponse: ((NSURLSession!, NSURLSessionDataTask!, NSCachedURLResponse!) -> (NSCachedURLResponse))?
    
    public var downloadTaskDidFinishDownloadingToURL: ((NSURLSession!, NSURLSessionDownloadTask!, NSURL) -> (NSURL))?
    public var downloadTaskDidWriteData: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64, Int64) -> Void)?
    public var downloadTaskDidResumeAtOffset: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64) -> Void)?
    
    internal override init() {
        self.subdelegates = Dictionary()
        super.init()
    }
    
    // MARK: NSObject
    
    override public func respondsToSelector(selector: Selector) -> Bool {
        switch selector {
        case "URLSession:didBecomeInvalidWithError:":
            return self.sessionDidBecomeInvalidWithError != nil
        case "URLSession:didReceiveChallenge:completionHandler:":
            return self.sessionDidReceiveChallenge != nil
        case "URLSessionDidFinishEventsForBackgroundURLSession:":
            return self.sessionDidFinishEventsForBackgroundURLSession != nil
        case "URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:":
            return self.taskWillPerformHTTPRedirection != nil
        case "URLSession:dataTask:didReceiveResponse:completionHandler:":
            return self.dataTaskDidReceiveResponse != nil
        case "URLSession:dataTask:willCacheResponse:completionHandler:":
            return self.dataTaskWillCacheResponse != nil
        default:
            return self.dynamicType.instancesRespondToSelector(selector)
        }
    }

}

// MARK: NSURLSessionDelegate

extension SessionDelegate: NSURLSessionDelegate {

    public func URLSession(session: NSURLSession!, didBecomeInvalidWithError error: NSError!) {
        self.sessionDidBecomeInvalidWithError?(session, error)
    }
    
    public func URLSession(session: NSURLSession!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
        if self.sessionDidReceiveChallenge != nil {
            completionHandler(self.sessionDidReceiveChallenge!(session, challenge))
        } else {
            completionHandler(.PerformDefaultHandling, nil)
        }
    }
    
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession!) {
        self.sessionDidFinishEventsForBackgroundURLSession?(session)
    }
    
}

// MARK: NSURLSessionTaskDelegate

extension SessionDelegate: NSURLSessionTaskDelegate {
    
    public func URLSession(session: NSURLSession!, task: NSURLSessionTask!, willPerformHTTPRedirection response: NSHTTPURLResponse!, newRequest request: NSURLRequest!, completionHandler: ((NSURLRequest!) -> Void)!) {
        var redirectRequest = request
        if self.taskWillPerformHTTPRedirection != nil {
            redirectRequest = self.taskWillPerformHTTPRedirection!(session, task, response, request)
        }
        
        completionHandler(redirectRequest)
    }
    
    public func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
        if let delegate = self[task] {
            delegate.URLSession(session, task: task, didReceiveChallenge: challenge, completionHandler: completionHandler)
        } else {
            self.URLSession(session, didReceiveChallenge: challenge, completionHandler: completionHandler)
        }
    }
    
    public func URLSession(session: NSURLSession!, task: NSURLSessionTask!, needNewBodyStream completionHandler: ((NSInputStream!) -> Void)!) {
        if let delegate = self[task] {
            delegate.URLSession(session, task: task, needNewBodyStream: completionHandler)
        }
    }
    
    public func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let delegate = self[task] as? UploadTaskDelegate {
            delegate.URLSession(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        }
    }
    
    public func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didCompleteWithError error: NSError!) {
        if let delegate = self[task] {
            delegate.URLSession(session, task: task, didCompleteWithError: error)
        }
    }
    
}

// MARK: NSURLSessionDataDelegate

extension SessionDelegate: NSURLSessionDataDelegate {

    public func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveResponse response: NSURLResponse!, completionHandler: ((NSURLSessionResponseDisposition) -> Void)!) {
        var disposition: NSURLSessionResponseDisposition = .Allow
        
        if self.dataTaskDidReceiveResponse != nil {
            disposition = self.dataTaskDidReceiveResponse!(session, dataTask, response)
        }
        
        completionHandler(disposition)
    }
    
    public func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask!) {
        let downloadDelegate = DownloadTaskDelegate(task: downloadTask)
        self[downloadTask] = downloadDelegate
    }
    
    public func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {
        if let delegate = self[dataTask] as? DataTaskDelegate {
            delegate.URLSession(session, dataTask: dataTask, didReceiveData: data)
        }
        
        self.dataTaskDidReceiveData?(session, dataTask, data)
    }
    
    public func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, willCacheResponse proposedResponse: NSCachedURLResponse!, completionHandler: ((NSCachedURLResponse!) -> Void)!) {
        var cachedResponse = proposedResponse
        
        if self.dataTaskWillCacheResponse != nil {
            cachedResponse = self.dataTaskWillCacheResponse!(session, dataTask, proposedResponse)
        }
        
        completionHandler(cachedResponse)
    }
    
}

// MARK: NSURLSessionDownloadDelegate

extension SessionDelegate: NSURLSessionDownloadDelegate {
    
    public func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
        if let delegate = self[downloadTask] as? DownloadTaskDelegate {
            delegate.URLSession(session, downloadTask: downloadTask, didFinishDownloadingToURL: location)
        }
        
        self.downloadTaskDidFinishDownloadingToURL?(session, downloadTask, location)
    }
    
    public func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let delegate = self[downloadTask] as? DownloadTaskDelegate {
            delegate.URLSession(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
        
        self.downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
    
    public func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        if let delegate = self[downloadTask] as? DownloadTaskDelegate {
            delegate.URLSession(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        }
        
        self.downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
    }
    
}
