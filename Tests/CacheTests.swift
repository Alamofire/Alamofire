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

    var URLCache: NSURLCache!
    var manager: Manager!

    let URLString = "https://httpbin.org/response-headers"
    let requestTimeout: NSTimeInterval = 30

    var requests: [String: NSURLRequest] = [:]
    var timestamps: [String: String] = [:]

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        URLCache = {
            let capacity = 50 * 1024 * 1024 // MBs
            let URLCache = NSURLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: nil)

            return URLCache
        }()

        manager = {
            let configuration: NSURLSessionConfiguration = {
                let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
                configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
                configuration.requestCachePolicy = .UseProtocolCachePolicy
                configuration.URLCache = URLCache

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
        let dispatchGroup = dispatch_group_create()
        let serialQueue = dispatch_queue_create("com.alamofire.cache-tests", DISPATCH_QUEUE_SERIAL)

        for cacheControl in CacheControl.allValues {
            dispatch_group_enter(dispatchGroup)

            let request = startRequest(
                cacheControl: cacheControl,
                queue: serialQueue,
                completion: { _, response in
                    let timestamp = response!.allHeaderFields["Date"] as! String
                    self.timestamps[cacheControl] = timestamp

                    dispatch_group_leave(dispatchGroup)
                }
            )

            requests[cacheControl] = request
        }

        // Wait for all requests to complete
        dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, Int64(30.0 * Float(NSEC_PER_SEC))))

        // Pause for 2 additional seconds to ensure all timestamps will be different
        dispatch_group_enter(dispatchGroup)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Float(NSEC_PER_SEC))), serialQueue) {
            dispatch_group_leave(dispatchGroup)
        }

        // Wait for our 2 second pause to complete
        dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, Int64(10.0 * Float(NSEC_PER_SEC))))
    }

    // MARK: - Request Helper Methods

    func URLRequest(cacheControl cacheControl: String, cachePolicy: NSURLRequestCachePolicy) -> NSURLRequest {
        let parameters = ["Cache-Control": cacheControl]
        let URL = NSURL(string: URLString)!
        let URLRequest = NSMutableURLRequest(URL: URL, cachePolicy: cachePolicy, timeoutInterval: requestTimeout)
        URLRequest.HTTPMethod = Method.GET.rawValue

        return ParameterEncoding.URL.encode(URLRequest, parameters: parameters).0
    }

    func startRequest(
        cacheControl cacheControl: String,
        cachePolicy: NSURLRequestCachePolicy = .UseProtocolCachePolicy,
        queue: dispatch_queue_t = dispatch_get_main_queue(),
        completion: (NSURLRequest?, NSHTTPURLResponse?) -> Void)
        -> NSURLRequest
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
        cachePolicy cachePolicy: NSURLRequestCachePolicy,
        cacheControl: String,
        shouldReturnCachedResponse: Bool)
    {
        // Given
        let expectation = expectationWithDescription("GET request to httpbin")
        var response: NSHTTPURLResponse?

        // When
        startRequest(cacheControl: cacheControl, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        verifyResponse(response, forCacheControl: cacheControl, isCachedResponse: shouldReturnCachedResponse)
    }

    func verifyResponse(response: NSHTTPURLResponse?, forCacheControl cacheControl: String, isCachedResponse: Bool) {
        guard let cachedResponseTimestamp = timestamps[cacheControl] else {
            XCTFail("cached response timestamp should not be nil")
            return
        }

        if let
            response = response,
            timestamp = response.allHeaderFields["Date"] as? String
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
        let publicRequest = requests[CacheControl.Public]!
        let privateRequest = requests[CacheControl.Private]!
        let maxAgeNonExpiredRequest = requests[CacheControl.MaxAgeNonExpired]!
        let maxAgeExpiredRequest = requests[CacheControl.MaxAgeExpired]!
        let noCacheRequest = requests[CacheControl.NoCache]!
        let noStoreRequest = requests[CacheControl.NoStore]!

        // When
        let publicResponse = URLCache.cachedResponseForRequest(publicRequest)
        let privateResponse = URLCache.cachedResponseForRequest(privateRequest)
        let maxAgeNonExpiredResponse = URLCache.cachedResponseForRequest(maxAgeNonExpiredRequest)
        let maxAgeExpiredResponse = URLCache.cachedResponseForRequest(maxAgeExpiredRequest)
        let noCacheResponse = URLCache.cachedResponseForRequest(noCacheRequest)
        let noStoreResponse = URLCache.cachedResponseForRequest(noStoreRequest)

        // Then
        XCTAssertNotNil(publicResponse, "\(CacheControl.Public) response should not be nil")
        XCTAssertNotNil(privateResponse, "\(CacheControl.Private) response should not be nil")
        XCTAssertNotNil(maxAgeNonExpiredResponse, "\(CacheControl.MaxAgeNonExpired) response should not be nil")
        XCTAssertNotNil(maxAgeExpiredResponse, "\(CacheControl.MaxAgeExpired) response should not be nil")
        XCTAssertNotNil(noCacheResponse, "\(CacheControl.NoCache) response should not be nil")

        if isCachedResponseForNoStoreHeaderExpected() {
            XCTAssertNotNil(noStoreResponse, "\(CacheControl.NoStore) response should not be nil")
        } else {
            XCTAssertNil(noStoreResponse, "\(CacheControl.NoStore) response should be nil")
        }
    }

    func testDefaultCachePolicy() {
        let cachePolicy: NSURLRequestCachePolicy = .UseProtocolCachePolicy

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: false)
    }

    func testIgnoreLocalCacheDataPolicy() {
        let cachePolicy: NSURLRequestCachePolicy = .ReloadIgnoringLocalCacheData

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: false)
    }

    func testUseLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() {
        let cachePolicy: NSURLRequestCachePolicy = .ReturnCacheDataElseLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: true)

        if isCachedResponseForNoStoreHeaderExpected() {
            executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: true)
        } else {
            executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: false)
        }
    }

    func testUseLocalCacheDataAndDontLoadFromNetworkPolicy() {
        let cachePolicy: NSURLRequestCachePolicy = .ReturnCacheDataDontLoad

        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Public, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.Private, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.MaxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoCache, shouldReturnCachedResponse: true)

        if isCachedResponseForNoStoreHeaderExpected() {
            executeTest(cachePolicy: cachePolicy, cacheControl: CacheControl.NoStore, shouldReturnCachedResponse: true)
        } else {
            // Given
            let expectation = expectationWithDescription("GET request to httpbin")
            var response: NSHTTPURLResponse?

            // When
            startRequest(cacheControl: CacheControl.NoStore, cachePolicy: cachePolicy) { _, responseResponse in
                response = responseResponse
                expectation.fulfill()
            }

            waitForExpectationsWithTimeout(timeout, handler: nil)

            // Then
            XCTAssertNil(response, "response should be nil")
        }
    }
}
