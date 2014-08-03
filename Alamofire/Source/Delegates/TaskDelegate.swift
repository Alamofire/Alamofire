// TaskDelegate.swift
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

internal class TaskDelegate: NSObject {
    
    let task: NSURLSessionTask
    let queue: dispatch_queue_t?
    let progress: NSProgress
    
    var data: NSData! { return nil }
    private(set) var error: NSError?
    
    var taskWillPerformHTTPRedirection: ((NSURLSession!, NSURLSessionTask!, NSHTTPURLResponse!, NSURLRequest!) -> (NSURLRequest!))?
    var taskDidReceiveChallenge: ((NSURLSession!, NSURLSessionTask!, NSURLAuthenticationChallenge) -> (NSURLSessionAuthChallengeDisposition, NSURLCredential?))?
    var taskDidSendBodyData: ((NSURLSession!, NSURLSessionTask!, Int64, Int64, Int64) -> Void)?
    var taskNeedNewBodyStream: ((NSURLSession!, NSURLSessionTask!) -> (NSInputStream!))?
    
    required init(task: NSURLSessionTask) {
        self.task = task
        self.progress = NSProgress(totalUnitCount: 0)
        
        let label: String = "com.alamofire.task-\(task.taskIdentifier)"
        let queue = dispatch_queue_create(label.bridgeToObjectiveC().UTF8String, DISPATCH_QUEUE_SERIAL)
        dispatch_suspend(queue)
        self.queue = queue
    }
    
}

// MARK: NSURLSessionTaskDelegate

extension TaskDelegate: NSURLSessionTaskDelegate {

    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, willPerformHTTPRedirection response: NSHTTPURLResponse!, newRequest request: NSURLRequest!, completionHandler: ((NSURLRequest!) -> Void)!) {
        var redirectRequest = request
        if self.taskWillPerformHTTPRedirection {
            redirectRequest = self.taskWillPerformHTTPRedirection!(session, task, response, request)
        }
        
        completionHandler(redirectRequest)
    }
    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
        var disposition: NSURLSessionAuthChallengeDisposition = .PerformDefaultHandling
        var credential: NSURLCredential?
        
        if self.taskDidReceiveChallenge {
            (disposition, credential) = self.taskDidReceiveChallenge!(session, task, challenge)
        } else {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                // TODO: Incorporate Trust Evaluation & TLS Chain Validation
                
                credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust)
                disposition = .UseCredential
            }
        }
        
        completionHandler(disposition, credential)
    }
    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, needNewBodyStream completionHandler: ((NSInputStream!) -> Void)!) {
        var bodyStream: NSInputStream?
        if self.taskNeedNewBodyStream {
            bodyStream = self.taskNeedNewBodyStream!(session, task)
        }
        
        completionHandler(bodyStream)
    }
    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didCompleteWithError error: NSError!) {
        dispatch_resume(self.queue)
    }
}
