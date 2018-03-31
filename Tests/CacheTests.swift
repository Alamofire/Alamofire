//
//  CacheTests.swift
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
import Foundation
import XCTest

/// This test case tests all implemented cache policies against various `Cache-Control` header values. These tests
/// are meant to cover the main cases of `Cache-Control` header usage, but are by no means exhaustive.
///
/// These tests work as follows:
///
/// - Set up an `URLCache`
/// - Set up an `Alamofire.SessionManager`
/// - Execute requests for all `Cache-Control` header values to prime the `NSURLCache` with cached responses
/// - Start up a new test
/// - Execute another round of the same requests with a given `URLRequestCachePolicy`
/// - Verify whether the response came from the cache or from the network
///     - This is determined by whether the cached response timestamp matches the new response timestamp
///
/// An important thing to note is the difference in behavior between iOS and macOS. On iOS, a response with
/// a `Cache-Control` header value of `no-store` is still written into the `NSURLCache` where on macOS, it is not.
/// The different tests below reflect and demonstrate this behavior.
///
/// For information about `Cache-Control` HTTP headers, please refer to RFC 2616 - Section 14.9.
class CacheTestCase: BaseTestCase {

    // MARK: -

    struct CacheControl {
        static let publicControl = "public"
        static let privateControl = "private"
        static let maxAgeNonExpired = "max-age=3600"
        static let maxAgeExpired = "max-age=0"
        static let noCache = "no-cache"
        static let noStore = "no-store"

        static var allValues: [String] {
            return [
                CacheControl.publicControl,
                CacheControl.privateControl,
                CacheControl.maxAgeNonExpired,
                CacheControl.maxAgeExpired,
                CacheControl.noCache,
                CacheControl.noStore
            ]
        }
    }

    // MARK: - Properties

    var urlCache: URLCache!
    var manager: SessionManager!

    let urlString = "https://httpbin.org/response-headers"
    let requestTimeout: TimeInterval = 30

    var requests: [String: URLRequest] = [:]
    var timestamps: [String: String] = [:]

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        urlCache = {
            let capacity = 50 * 1024 * 1024 // MBs
            let urlCache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: nil)

            return urlCache
        }()

        manager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
                configuration.requestCachePolicy = .useProtocolCachePolicy
                configuration.urlCache = urlCache

                return configuration
            }()

            let manager = SessionManager(configuration: configuration)

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

    /**
        Executes a request for all `Cache-Control` header values to load the response into the `URLCache`.

        This implementation leverages dispatch groups to execute all the requests as well as wait an additional
        second before returning. This ensures the cache contains responses for all requests that are at least
        one second old. This allows the tests to distinguish whether the subsequent responses come from the cache
        or the network based on the timestamp of the response.
    */
    func primeCachedResponses() {
        let dispatchGroup = DispatchGroup()
        let serialQueue = DispatchQueue(label: "org.alamofire.cache-tests")

        for cacheControl in CacheControl.allValues {
            dispatchGroup.enter()

            let request = startRequest(
                cacheControl: cacheControl,
                queue: serialQueue,
                completion: { _, response in
                    let timestamp = response!.allHeaderFields["Date"] as! String
                    self.timestamps[cacheControl] = timestamp

                    dispatchGroup.leave()
                }
            )

            requests[cacheControl] = request
        }

        // Wait for all requests to complete
        _ = dispatchGroup.wait(timeout: DispatchTime.now() + Double(Int64(30.0 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC))

        // Pause for 2 additional seconds to ensure all timestamps will be different
        dispatchGroup.enter()
        serialQueue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2.0 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            dispatchGroup.leave()
        }

        // Wait for our 2 second pause to complete
        _ = dispatchGroup.wait(timeout: DispatchTime.now() + Double(Int64(10.0 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC))
    }

    // MARK: - Request Helper Methods

    func urlRequest(cacheControl: String, cachePolicy: NSURLRequest.CachePolicy) -> URLRequest {
        let parameters = ["Cache-Control": cacheControl]
        let url = URL(string: urlString)!

        var urlRequest = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: requestTimeout)
        urlRequest.httpMethod = HTTPMethod.get.rawValue

        do {
            return try URLEncoding.default.encode(urlRequest, with: parameters)
        } catch {
            return urlRequest
        }
    }

    @discardableResult
    func startRequest(
        cacheControl: String,
        cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy,
        queue: DispatchQueue = DispatchQueue.main,
        completion: @escaping (URLRequest?, HTTPURLResponse?) -> Void)
        -> URLRequest
    {
        let urlRequest = self.urlRequest(cacheControl: cacheControl, cachePolicy: cachePolicy)
        let request = manager.request(urlRequest)

        request.response(
            queue: queue,
            completionHandler: { response in
                completion(response.request, response.response)
            }
        )

        return urlRequest
    }

    // MARK: - Test Execution and Verification

    func executeTest(
        cachePolicy: NSURLRequest.CachePolicy,
        cacheControl: String,
        shouldReturnCachedResponse: Bool)
    {
        // Given
        let expectation = self.expectation(description: "GET request to httpbin")
        var response: HTTPURLResponse?

        // When
        startRequest(cacheControl: cacheControl, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        verifyResponse(response, forCacheControl: cacheControl, isCachedResponse: shouldReturnCachedResponse)
    }

    func verifyResponse(_ response: HTTPURLResponse?, forCacheControl cacheControl: String, isCachedResponse: Bool) {
        guard let cachedResponseTimestamp = timestamps[cacheControl] else {
            XCTFail("cached response timestamp should not be nil")
            return
        }

        if let response = response, let timestamp = response.allHeaderFields["Date"] as? String {
            if isCachedResponse {
                XCTAssertEqual(timestamp, cachedResponseTimestamp, "timestamps should be equal")
            } else {
                XCTAssertNotEqual(timestamp, cachedResponseTimestamp, "timestamps should not be equal")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }

    // MARK: - Cache Helper Methods

    private func isCachedResponseForNoStoreHeaderExpected() -> Bool {
    #if os(iOS)
        if #available(iOS 8.3, *) {
            return false
        } else {
            return true
        }
    #else
        return false
    #endif
    }

    // MARK: - Tests

    func testURLCacheContainsCachedResponsesForAllRequests() {
        // Given
        let publicRequest = requests[CacheControl.publicControl]!
        let privateRequest = requests[CacheControl.privateControl]!
        let maxAgeNonExpiredRequest = requests[CacheControl.maxAgeNonExpired]!
        let maxAgeExpiredRequest = requests[CacheControl.maxAgeExpired]!
        let noCacheRequest = requests[CacheControl.noCache]!
        let noStoreRequest = requests[CacheControl.noStore]!

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

        if isCachedResponseForNoStoreHeaderExpected() {
            XCTAssertNotNil(noStoreResponse, "\(CacheControl.noStore) response should not be nil")
        } else {
            XCTAssertNil(noStoreResponse, "\(CacheControl.noStore) response should be nil")
        }
    }

    func testDefaultCachePolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noStore, shouldReturnCachedResponse: false)
    }

    func testIgnoreLocalCacheDataPolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .reloadIgnoringLocalCacheData

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeNonExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noStore, shouldReturnCachedResponse: false)
    }

    func testUseLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataElseLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noCache, shouldReturnCachedResponse: true)

        if isCachedResponseForNoStoreHeaderExpected() {
            executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noStore, shouldReturnCachedResponse: true)
        } else {
            executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noStore, shouldReturnCachedResponse: false)
        }
    }

    func testUseLocalCacheDataAndDontLoadFromNetworkPolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataDontLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noCache, shouldReturnCachedResponse: true)

        if isCachedResponseForNoStoreHeaderExpected() {
            executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.noStore, shouldReturnCachedResponse: true)
        } else {
            // Given
            let expectation = self.expectation(description: "GET request to httpbin")
            var response: HTTPURLResponse?

            // When
            startRequest(cacheControl: CacheControl.noStore, cachePolicy: cachePolicy) { _, responseResponse in
                response = responseResponse
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertNil(response, "response should be nil")
        }
    }
}
