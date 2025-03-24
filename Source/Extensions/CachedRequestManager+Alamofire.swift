//
//  CachedRequestManager+Alamofire.swift

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

import Alamofire

/// Manages caching of failed network requests and automatically retries them when the network is available.
class CachedRequestManager {
    
    static let shared = CachedRequestManager()
    
    /// Stores URLs of failed requests for retrying later.
    private var cachedRequests: [String] = []
    
    /// Alamofire's Network Reachability Manager to detect network status changes.
    private let reachabilityManager = NetworkReachabilityManager()
    
    /// Private initializer to ensure only a single instance exists.
    private init() {
        startListeningForNetworkChanges()
    }
    
    /// Caches a failed network request's URL for later retry.
    ///
    /// - Parameter url: The URL of the failed request.
    func cacheFailedRequest(_ url: String) {
        if !cachedRequests.contains(url) {
            cachedRequests.append(url)
        }
    }
    
    /// Removes a successfully retried request from the cache.
    ///
    /// - Parameter url: The URL of the request to remove.
    func removeCachedRequest(_ url: String) {
        cachedRequests.removeAll { $0 == url }
    }
    
    /// Retries all cached requests when the network becomes reachable.
    private func retryCachedRequests() {
        for url in cachedRequests {
            AF.request(url).response { response in
                if response.error == nil {
                    self.removeCachedRequest(url)
                    print("Request retried successfully: \(url)")
                }
            }
        }
    }
    
    /// Starts listening for network changes and retries cached requests when the network is available.
    private func startListeningForNetworkChanges() {
        reachabilityManager?.startListening { status in
            switch status {
            case .reachable(_):
                print("Network is back, retrying cached requests...")
                self.retryCachedRequests()
            case .notReachable, .unknown:
                print("Network unavailable, caching failed requests")
            }
        }
    }
}

/// Extension for Alamofire's `DataRequest` to enable automatic caching and retrying of failed requests.
extension DataRequest {
    
    /// Enables caching and automatic retrying of failed network requests.
    ///
    /// When a request fails due to network issues, its URL is cached and automatically retried
    /// once the network is available again.
    ///
    /// - Returns: The `DataRequest` instance, allowing method chaining.
    func cacheAndRetry() -> Self {
        return self.response { response in
            if let error = response.error, let url = response.request?.url?.absoluteString {
                print("Request failed: \(url), caching for retry. Error: \(error)")
                CachedRequestManager.shared.cacheFailedRequest(url)
            }
        }
    }
}
