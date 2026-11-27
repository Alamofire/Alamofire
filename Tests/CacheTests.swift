//
//  CacheTests.swift
//
//  Copyright (c) 2022 Alamofire Software Foundation (http://alamofire.org/)
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
import Testing

/// This test case tests all implemented cache policies against various `Cache-Control` header values. These tests
/// are meant to cover the main cases of `Cache-Control` header usage, but are by no means exhaustive.
///
/// These tests work as follows:
///
/// - Set up an `URLCache`
/// - Set up an `Alamofire.Session`
/// - Execute requests for all `Cache-Control` header values to prime the `URLCache` with cached responses
/// - Start up a new test
/// - Execute another round of the same requests with a given `URLRequestCachePolicy`
/// - Verify whether the response came from the cache or from the network
///     - This is determined by whether the cached response timestamp matches the new response timestamp
///
/// For information about `Cache-Control` HTTP headers, please refer to RFC 2616 - Section 14.9.
@Suite(.storesInstances)
final class CacheTestCase {
    // MARK: -

    enum CacheControl: String, CaseIterable {
        case publicControl = "public"
        case privateControl = "private"
        case maxAgeNonExpired = "max-age=3600"
        case maxAgeExpired = "max-age=0"
        case noCache = "no-cache"
        case noStore = "no-store"
    }

    // MARK: - Properties

    let urlCache: URLCache
    let manager: Session

    let requests: [CacheControl: URLRequest]
    let timestamps: [CacheControl: String]

    /// Makes this instance's `Cache-Control` values unique. Firewalk ages the first response for each `Cache-Control`
    /// value it sees and toggles that state with every request, so tests running in parallel need their own values.
    let testID = UUID().uuidString

    // MARK: - Setup and Teardown

    /// Sets up a new `URLCache` and `Session` for each test and primes the cache, replacing `setUp()`.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    init() async {
        urlCache = {
            let capacity = 50 * 1024 * 1024 // MBs
            #if targetEnvironment(macCatalyst)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            return URLCache(memoryCapacity: capacity, diskCapacity: capacity, directory: directory)
            #else
            let directory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
            return URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: directory)
            #endif
        }()

        manager = { [urlCache] in
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.headers = HTTPHeaders.default
                configuration.requestCachePolicy = .useProtocolCachePolicy
                configuration.urlCache = urlCache

                return configuration
            }()

            // Independent keeps the provided cache and replaces only the shared cookie and credential storage.
            return stored(Session.independent(configuration: configuration))
        }()

        (requests, timestamps) = await Self.primeCachedResponses(using: manager, testID: testID)
    }

    /// Replaces `tearDown()`.
    deinit {
        urlCache.removeAllCachedResponses()
    }

    // MARK: - Cache Priming Methods

    /// Executes a request for all `Cache-Control` header values to load the response into the `URLCache`.
    ///
    /// - Note: This implementation waits for all the requests to complete. This ensures the cache contains responses
    ///         for all requests, properly aged from Firewalk. This allows the tests to distinguish whether the
    ///         subsequent responses come from the cache or the network based on the timestamp of the response.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private static func primeCachedResponses(using manager: Session,
                                             testID: String) async -> ([CacheControl: URLRequest], [CacheControl: String]) {
        let allRequestsFinished = Completion("all cache priming requests should finish",
                                             expectedCount: CacheControl.allCases.count)
        let serialQueue = DispatchQueue(label: "org.alamofire.cache-tests")
        let timestamps = Capture<[CacheControl: String]>([:])
        var requests: [CacheControl: URLRequest] = [:]

        for cacheControl in CacheControl.allCases {
            let request = startRequest(cacheControl: cacheControl,
                                       using: manager,
                                       testID: testID,
                                       queue: serialQueue,
                                       completion: { _, response in
                                           // A failed priming request has no response. The tests then fail on their
                                           // own assertions, where force unwrapping would crash the whole test run.
                                           let timestamp = response?.headers["Date"]
                                           timestamps.write { $0[cacheControl] = timestamp }

                                           allRequestsFinished.complete()
                                       })

            requests[cacheControl] = request
        }

        // Wait for all requests to complete
        await allRequestsFinished.wait()

        return (requests, timestamps.value)
    }

    // MARK: - Request Helper Methods

    @discardableResult
    private func startRequest(cacheControl: CacheControl,
                              cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                              queue: DispatchQueue = .main,
                              completion: @escaping @Sendable (URLRequest?, HTTPURLResponse?) -> Void)
        -> URLRequest {
        Self.startRequest(cacheControl: cacheControl,
                          cachePolicy: cachePolicy,
                          using: manager,
                          testID: testID,
                          queue: queue,
                          completion: completion)
    }

    @discardableResult
    private static func startRequest(cacheControl: CacheControl,
                                     cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                                     using manager: Session,
                                     testID: String,
                                     queue: DispatchQueue = .main,
                                     completion: @escaping @Sendable (URLRequest?, HTTPURLResponse?) -> Void)
        -> URLRequest {
        let urlRequest = Endpoint(path: .cache,
                                  timeout: 30,
                                  // Caches ignore unknown Cache-Control extensions, so the ID doesn't change caching.
                                  queryItems: [.init(name: "Cache-Control", value: "\(cacheControl.rawValue), x-alamofire-test-id=\(testID)")],
                                  cachePolicy: cachePolicy).urlRequest
        let request = manager.request(urlRequest)

        request.response(queue: queue) { response in
            completion(response.request, response.response)
        }

        return urlRequest
    }

    // MARK: - Test Execution and Verification

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func executeTest(cachePolicy: URLRequest.CachePolicy,
                             cacheControl: CacheControl,
                             shouldReturnCachedResponse: Bool) async {
        // Given
        let requestDidFinish = Completion("cache test request did finish")
        let response = Capture<HTTPURLResponse?>()

        // When
        startRequest(cacheControl: cacheControl, cachePolicy: cachePolicy) { _, responseResponse in
            response.value = responseResponse
            requestDidFinish.complete()
        }

        await requestDidFinish.wait()

        // Then
        verifyResponse(response.value, forCacheControl: cacheControl, isCachedResponse: shouldReturnCachedResponse)
    }

    private func verifyResponse(_ response: HTTPURLResponse?, forCacheControl cacheControl: CacheControl, isCachedResponse: Bool) {
        guard let cachedResponseTimestamp = timestamps[cacheControl] else {
            Issue.record("cached response timestamp should not be nil")
            return
        }

        if let response, let timestamp = response.headers["Date"] {
            if isCachedResponse {
                #expect(timestamp == cachedResponseTimestamp, "timestamps should be equal")
            } else {
                #expect(timestamp != cachedResponseTimestamp, "timestamps should not be equal")
            }
        } else {
            Issue.record("response should not be nil")
        }
    }

    // MARK: - Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func urlCacheContainsCachedResponsesForAllRequests() {
        // Given
        let publicRequest = requests[.publicControl]!
        let privateRequest = requests[.privateControl]!
        let maxAgeNonExpiredRequest = requests[.maxAgeNonExpired]!
        let maxAgeExpiredRequest = requests[.maxAgeExpired]!
        let noCacheRequest = requests[.noCache]!
        let noStoreRequest = requests[.noStore]!

        // When
        let publicResponse = urlCache.cachedResponse(for: publicRequest)
        let privateResponse = urlCache.cachedResponse(for: privateRequest)
        let maxAgeNonExpiredResponse = urlCache.cachedResponse(for: maxAgeNonExpiredRequest)
        let maxAgeExpiredResponse = urlCache.cachedResponse(for: maxAgeExpiredRequest)
        let noCacheResponse = urlCache.cachedResponse(for: noCacheRequest)
        let noStoreResponse = urlCache.cachedResponse(for: noStoreRequest)

        // Then
        #expect(publicResponse != nil, "\(CacheControl.publicControl) response should not be nil")
        #expect(privateResponse != nil, "\(CacheControl.privateControl) response should not be nil")
        #expect(maxAgeNonExpiredResponse != nil, "\(CacheControl.maxAgeNonExpired) response should not be nil")
        #expect(maxAgeExpiredResponse != nil, "\(CacheControl.maxAgeExpired) response should not be nil")
        #expect(noCacheResponse != nil, "\(CacheControl.noCache) response should not be nil")
        #expect(noStoreResponse == nil, "\(CacheControl.noStore) response should be nil")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func defaultCachePolicy() async {
        let cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy

        await executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func ignoreLocalCacheDataPolicy() async {
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData

        await executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func useLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() async {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad

        await executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func useLocalCacheDataAndDontLoadFromNetworkPolicy() async {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataDontLoad

        await executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        await executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)

        // Given
        let requestDidFinish = Completion("don't load from network request finished")
        let response = Capture<HTTPURLResponse?>()

        // When
        startRequest(cacheControl: .noStore, cachePolicy: cachePolicy) { _, responseResponse in
            response.value = responseResponse
            requestDidFinish.complete()
        }

        await requestDidFinish.wait()

        // Then
        #expect(response.value == nil, "response should be nil")
    }
}
