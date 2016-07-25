//
//  CacheTests.swift
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

import Alamofire
import Foundation
import XCTest

/**
    This test case tests all implemented cache policies against various `Cache-Control` header values. These tests
    are meant to cover the main cases of `Cache-Control` header usage, but are by no means exhaustive.

    These tests work as follows:

    - Set up an `NSURLCache`
    - Set up an `Alamofire.Manager`
    - Execute requests for all `Cache-Control` header values to prime the `NSURLCache` with cached responses
    - Start up a new test
    - Execute another round of the same requests with a given `NSURLRequestCachePolicy`
    - Verify whether the response came from the cache or from the network
        - This is determined by whether the cached response timestamp matches the new response timestamp

    An important thing to note is the difference in behavior between iOS and OS X. On iOS, a response with
    a `Cache-Control` header value of `no-store` is still written into the `NSURLCache` where on OS X, it is not.
    The different tests below reflect and demonstrate this behavior.

    For information about `Cache-Control` HTTP headers, please refer to RFC 2616 - Section 14.9.
*/
class CacheTestCase: BaseTestCase {

    // MARK: -

    struct CacheControl {
        static let Public = "public"
        static let Private = "private"
        static let MaxAgeNonExpired = "max-age=3600"
        static let MaxAgeExpired = "max-age=0"
        static let NoCache = "no-cache"
        static let NoStore = "no-store"

        static var allValues: [String] {
            return [
                CacheControl.Public,
                CacheControl.Private,
                CacheControl.MaxAgeNonExpired,
                CacheControl.MaxAgeExpired,
                CacheControl.NoCache,
                CacheControl.NoStore
            ]
        }
    }

    // MARK: - Properties

    var URLCache: Foundation.URLCache!
    var manager: Manager!

    let URLString = "https://httpbin.org/response-headers"
    let requestTimeout: TimeInterval = 30

    var requests: [String: Foundation.URLRequest] = [:]
    var timestamps: [String: String] = [:]

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        URLCache = {
            let capacity = 50 * 1024 * 1024 // MBs
            let URLCache = Foundation.URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: nil)

            return URLCache
        }()

        manager = {
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
                configuration.requestCachePolicy = .useProtocolCachePolicy
                configuration.urlCache = URLCache

                return configuration
            }()

            let manager = Manager(configuration: configuration)

            return manager
        }()

        primeCachedResponses()
    }

    override func tearDown() {
        super.tearDown()

        requests.removeAll()
        timestamps.removeAll()

        URLCache.removeAllCachedResponses()
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
        let serialQueue = DispatchQueue(label: "com.alamofire.cache-tests", attributes: DispatchQueueAttributes.serial)

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
        serialQueue.after(when: DispatchTime.now() + Double(Int64(2.0 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            dispatchGroup.leave()
        }

        // Wait for our 2 second pause to complete
        _ = dispatchGroup.wait(timeout: DispatchTime.now() + Double(Int64(10.0 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC))
    }

    // MARK: - Request Helper Methods

    func URLRequest(cacheControl: String, cachePolicy: NSURLRequest.CachePolicy) -> Foundation.URLRequest {
        let parameters = ["Cache-Control": cacheControl]
        let URL = Foundation.URL(string: URLString)!
        var urlRequest = Foundation.URLRequest(url: URL, cachePolicy: cachePolicy, timeoutInterval: requestTimeout)
        urlRequest.httpMethod = Method.GET.rawValue

        return ParameterEncoding.url.encode(urlRequest, parameters: parameters).0
    }

    @discardableResult
    func startRequest(
        cacheControl: String,
        cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy,
        queue: DispatchQueue = DispatchQueue.main,
        completion: (Foundation.URLRequest?, HTTPURLResponse?) -> Void)
        -> Foundation.URLRequest
    {
        let urlRequest = URLRequest(cacheControl: cacheControl, cachePolicy: cachePolicy)
        let request = manager.request(urlRequest)

        request.response(
            queue: queue,
            completionHandler: { _, response, data, _ in
                completion(request.request, response)
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

        if let response = response,
           let timestamp = response.allHeaderFields["Date"] as? String
        {
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
        let publicRequest = requests[CacheControl.Public]!
        let privateRequest = requests[CacheControl.Private]!
        let maxAgeNonExpiredRequest = requests[CacheControl.MaxAgeNonExpired]!
        let maxAgeExpiredRequest = requests[CacheControl.MaxAgeExpired]!
        let noCacheRequest = requests[CacheControl.NoCache]!
        let noStoreRequest = requests[CacheControl.NoStore]!

        // When
        let publicResponse = URLCache.cachedResponse(for: publicRequest)
        let privateResponse = URLCache.cachedResponse(for: privateRequest)
        let maxAgeNonExpiredResponse = URLCache.cachedResponse(for: maxAgeNonExpiredRequest)
        let maxAgeExpiredResponse = URLCache.cachedResponse(for: maxAgeExpiredRequest)
        let noCacheResponse = URLCache.cachedResponse(for: noCacheRequest)
        let noStoreResponse = URLCache.cachedResponse(for: noStoreRequest)

        // Then
        XCTAssertNotNil(publicResponse, "\(CacheControl.Public) response should not be nil")
        XCTAssertNotNil(privateResponse, "\(CacheControl.Private) response should not be nil")
        XCTAssertNotNil(maxAgeNonExpiredResponse, "\(CacheControl.MaxAgeNonExpired) response should not be nil")
        XCTAssertNotNil(maxAgeExpiredResponse, "\(CacheControl.MaxAgeExpired) response should not be nil")
        XCTAssertNotNil(noCacheResponse, "\(CacheControl.NoCache) response should not be nil")
        XCTAssertNil(noStoreResponse, "\(CacheControl.NoStore) response should be nil")
    }

    func testDefaultCachePolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: false)
    }

    func testIgnoreLocalCacheDataPolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .reloadIgnoringLocalCacheData

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: false)
    }

    func testUseLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataElseLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: false)
    }

    func testUseLocalCacheDataAndDontLoadFromNetworkPolicy() {
        let cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataDontLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: true)

        // Given
        let expectation = self.expectation(description: "GET request to httpbin")
        var response: HTTPURLResponse?

        // When
        startRequest(cacheControl: CacheControl.NoStore, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(response, "response should be nil")
    }
}
