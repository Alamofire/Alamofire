//
//  SessionTaskStateOperator.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
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

//MARK: SessionTaskStateContract

protocol SessionTaskStateContract {
    func resume()
    func suspend()
    func cancel()
}

//MARK: SessionTaskStateOperator

class SessionTaskStateOperator: SessionTaskStateContract {
    fileprivate var request: Request
    fileprivate var task: URLSessionTask? { return request.delegate.task }

    init(request: Request) {
        self.request = request
    }
    
    /// Resume the request.
    func resume() {
        guard let task = task else { request.delegate.queue.isSuspended = false ; return }
        
        if request.startTime == nil { request.startTime = CFAbsoluteTimeGetCurrent() }
        
        task.resume()
        
        NotificationCenter.default.post(
            name: Notification.Name.Task.DidResume,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }
    
    /// Suspends the request.
    func suspend() {
        guard let task = task else { return }
        
        task.suspend()
        
        NotificationCenter.default.post(
            name: Notification.Name.Task.DidSuspend,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }
    
    /// Cancels the request.
    func cancel() {
        guard let task = task else { return }
        
        task.cancel()
        
        NotificationCenter.default.post(
            name: Notification.Name.Task.DidCancel,
            object: self,
            userInfo: [Notification.Key.Task: task]
        )
    }
}

//MARK: SessionTaskStateOperator

class SessionDownloadTaskStateOperator: SessionTaskStateOperator {
    
    init(downloadRequest: DownloadRequest) {
        super.init(request: downloadRequest)
    }
    
    private var downloadRequest: DownloadRequest {
        return request as! DownloadRequest
    }

    /// Cancels the download request.
    override func cancel() {
        downloadRequest.downloadDelegate.downloadTask.cancel { self.downloadRequest.downloadDelegate.resumeData = $0 }
        
        NotificationCenter.default.post(
            name: Notification.Name.Task.DidCancel,
            object: self,
            userInfo: [Notification.Key.Task: task as Any]
        )
    }
}

//MARK: OperationQueueStateDecorator

class OperationQueueStateDecorator: SessionTaskStateContract {
    private let contract: SessionTaskStateContract
    
    init(contract: SessionTaskStateContract) {
        self.contract = contract
    }
    
    func resume() {
        contract.resume()
    }
    
    func cancel() {
        contract.cancel()
    }
    
    func suspend() {
        contract.suspend()
    }
}

//MARK: CancelRetriedRequestStateDecorator

final class CancelRetriedRequestStateDecorator: OperationQueueStateDecorator {
    private let retryWorkItem: DispatchWorkItem
    
    init(retryWorkItem: DispatchWorkItem, contract: SessionTaskStateContract) {
        self.retryWorkItem = retryWorkItem
        super.init(contract: contract)
    }
    
    override func cancel() {
        super.cancel()
        /// if workItem not perform, first cancel, then perform immediately, notify one time
        
        let isCancelled = retryWorkItem.isCancelled
        retryWorkItem.cancel()
        if !isCancelled {
            retryWorkItem.perform()
        }
    }
    
}
