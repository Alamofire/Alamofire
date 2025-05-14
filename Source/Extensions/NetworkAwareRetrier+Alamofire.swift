//
//  NetworkAwareRetrier+Alamofire.swift

//  Copyright © 2025 Alamofire. All rights reserved.
//
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
import Network

@available(iOSApplicationExtension 12.0, *)
final class NetworkAwareRetrier: RequestRetrier, @unchecked Sendable {
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue", qos: .background)
    
    /// Thread-safe properties using a concurrent queue with barrier writes.
    private let syncQueue = DispatchQueue(label: "NetworkAwareRetrier.syncQueue", attributes: .concurrent)
    
    /// Tracks network availability.
    private var _isNetworkAvailable = false
    private var isNetworkAvailable: Bool {
        get { syncQueue.sync { _isNetworkAvailable } }
        set { syncQueue.async(flags: .barrier) { self._isNetworkAvailable = newValue } }
    }
    
    /// Stores pending retry completions.
    private var _pendingCompletions: [(RetryResult) -> Void] = []
    private var pendingCompletions: [(RetryResult) -> Void] {
        get { syncQueue.sync { _pendingCompletions } }
        set { syncQueue.async(flags: .barrier) { self._pendingCompletions = newValue } }
    }
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.isNetworkAvailable = (path.status == .satisfied)
            
            // Retry all pending requests if network is back
            if self.isNetworkAvailable {
                self.flushPendingRetries()
            }
        }
        monitor.start(queue: queue)
    }
    
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: any Error,
        completion: @escaping @Sendable (RetryResult) -> Void
    ) {
        guard let afError = error.asAFError, afError.isSessionTaskError else {
            completion(.doNotRetry)
            return
        }
        
        if isNetworkAvailable {
            completion(.retryWithDelay(1.0)) // Retry after 1 sec if online
        } else {
            addToPendingRetries(completion)
        }
    }
    
    /// Adds a completion handler to the pending list.
    private func addToPendingRetries(
        _ completion: @Sendable @escaping (RetryResult) -> Void
    ) {
        syncQueue.async(flags: .barrier) {
            self._pendingCompletions.append(completion)
        }
    }
    
    /// Retries all pending requests when the network is back.
    private func flushPendingRetries() {
        syncQueue.async(flags: .barrier) {
            self._pendingCompletions.forEach { $0(.retry) }
            self._pendingCompletions.removeAll()
        }
    }
}
