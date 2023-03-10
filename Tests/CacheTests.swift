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
import XCTest

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
final class CacheTestCase: BaseTestCase {
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

    var urlCache: URLCache!
    var manager: Session!

    var requests: [CacheControl: URLRequest] = [:]
    var timestamps: [CacheControl: String] = [:]

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

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

        manager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.headers = HTTPHeaders.default
                configuration.requestCachePolicy = .useProtocolCachePolicy
                configuration.urlCache = urlCache

                return configuration
            }()

            let manager = Session(configuration: configuration)

            return manager
        }()

        primeCachedResponses()
    }

    override func tearDown() {
        super.tearDown()

        requests.removeAll()
        timestamps.removeAll()

        urlCache.removeAllCachedResponses()
    }

    // MARK: - Cache Priming Methods

    /// Executes a request for all `Cache-Control` header values to load the response into the `URLCache`.
    ///
    /// - Note: This implementation leverages dispatch groups to execute all the requests. This ensures the cache
    ///         contains responses for all requests, properly aged from Firewalk. This allows the tests to distinguish
    ///         whether the subsequent responses come from the cache or the network based on the timestamp of the
    ///         response.
    private func primeCachedResponses() {
        let dispatchGroup = DispatchGroup()
        let serialQueue = DispatchQueue(label: "org.alamofire.cache-tests")

        for cacheControl in CacheControl.allCases {
            dispatchGroup.enter()

            let request = startRequest(cacheControl: cacheControl,
                                       queue: serialQueue,
                                       completion: { _, response in
                                           let timestamp = response!.headers["Date"]
                                           self.timestamps[cacheControl] = timestamp

                                           dispatchGroup.leave()
                                       })

            requests[cacheControl] = request
        }

        // Wait for all requests to complete
        _ = dispatchGroup.wait(timeout: .now() + timeout)
    }

    // MARK: - Request Helper Methods

    @discardableResult
    private func startRequest(cacheControl: CacheControl,
                              cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                              queue: DispatchQueue = .main,
                              completion: @escaping (URLRequest?, HTTPURLResponse?) -> Void)
        -> URLRequest {
        let urlRequest = Endpoint(path: .cache,
                                  timeout: 30,
                                  queryItems: [.init(name: "Cache-Control", value: cacheControl.rawValue)],
                                  cachePolicy: cachePolicy).urlRequest
        let request = manager.request(urlRequest)

        request.response(queue: queue) { response in
            completion(response.request, response.response)
        }

        return urlRequest
    }

    // MARK: - Test Execution and Verification

    private func executeTest(cachePolicy: URLRequest.CachePolicy,
                             cacheControl: CacheControl,
                             shouldReturnCachedResponse: Bool) {
        // Given
        let requestDidFinish = expectation(description: "cache test request did finish")
        var response: HTTPURLResponse?

        // When
        startRequest(cacheControl: cacheControl, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            requestDidFinish.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        verifyResponse(response, forCacheControl: cacheControl, isCachedResponse: shouldReturnCachedResponse)
    }

    private func verifyResponse(_ response: HTTPURLResponse?, forCacheControl cacheControl: CacheControl, isCachedResponse: Bool) {
        guard let cachedResponseTimestamp = timestamps[cacheControl] else {
            XCTFail("cached response timestamp should not be nil")
            return
        }

        if let response = response, let timestamp = response.headers["Date"] {
            if isCachedResponse {
                XCTAssertEqual(timestamp, cachedResponseTimestamp, "timestamps should be equal")
            } else {
                XCTAssertNotEqual(timestamp, cachedResponseTimestamp, "timestamps should not be equal")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }

    // MARK: - Tests

    func testURLCacheContainsCachedResponsesForAllRequests() {
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
        XCTAssertNotNil(publicResponse, "\(CacheControl.publicControl) response should not be nil")
        XCTAssertNotNil(privateResponse, "\(CacheControl.privateControl) response should not be nil")
        XCTAssertNotNil(maxAgeNonExpiredResponse, "\(CacheControl.maxAgeNonExpired) response should not be nil")
        XCTAssertNotNil(maxAgeExpiredResponse, "\(CacheControl.maxAgeExpired) response should not be nil")
        XCTAssertNotNil(noCacheResponse, "\(CacheControl.noCache) response should not be nil")
        XCTAssertNil(noStoreResponse, "\(CacheControl.noStore) response should be nil")
    }

    func testDefaultCachePolicy() {
        let cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy

        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }

    func testIgnoreLocalCacheDataPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData

        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }

    func testUseLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }

    func testUseLocalCacheDataAndDontLoadFromNetworkPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataDontLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)

        // Given
        let requestDidFinish = expectation(description: "don't load from network request finished")
        var response: HTTPURLResponse?

        // When
        startRequest(cacheControl: .noStore, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            requestDidFinish.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response, "response should be nil")
    }
}
