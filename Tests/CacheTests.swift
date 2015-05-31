// CacheTests.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
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

import Alamofire
import Foundation
import XCTest

/**
    The cache test cases test various NSURLRequestCachePolicy types against different combinations of
    Cache-Control headers. These tests use the response timestamp to verify whether the cached response
    data was returned. This requires each test to have a 1 second delay built into the second request
    which is not ideal.
*/
class CacheTestCase: BaseTestCase {

    // MARK: Properties

    let URLString = "http://httpbin.org/response-headers"
    var manager: Manager!
    var URLCache: NSURLCache { return self.manager.session.configuration.URLCache! }
    var requestCachePolicy: NSURLRequestCachePolicy { return self.manager.session.configuration.requestCachePolicy }

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        // No-op
    }

    override func tearDown() {
        super.tearDown()
        self.URLCache.removeAllCachedResponses()
    }

    // MARK: Test Setup Methods

    func setUpManagerWithRequestCachePolicy(requestCachePolicy: NSURLRequestCachePolicy) {
        self.manager = {
            let configuration: NSURLSessionConfiguration = {
                let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
                configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
                configuration.requestCachePolicy = requestCachePolicy

                let capacity = 50 * 1024 * 1024 // MBs
                configuration.URLCache = NSURLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: nil)

                return configuration
            }()

            let manager = Manager(configuration: configuration)

            return manager
        }()
    }

    // MARK: Test Execution Methods

    func executeCacheControlHeaderTestWithValue(
        value: String,
        cachedResponsesExist: Bool,
        responseTimestampsAreEqual: Bool)
    {
        // Given
        let parameters = ["Cache-Control": value]
        var request1: NSURLRequest?
        var request2: NSURLRequest?
        var response1: NSHTTPURLResponse?
        var response2: NSHTTPURLResponse?

        // When
        let expectation1 = expectationWithDescription("GET request1 to httpbin")
        startRequestWithParameters(parameters) { request, response in
            request1 = request
            response1 = response
            expectation1.fulfill()
        }
        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        let expectation2 = expectationWithDescription("GET request2 to httpbin")
        startRequestWithParameters(parameters, delay: 1.0) { request, response in
            request2 = request
            response2 = response
            expectation2.fulfill()
        }
        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        verifyCachedResponses(forRequest1: request1, andRequest2: request2, exist: cachedResponsesExist)
        verifyResponseTimestamps(forResponse1: response1, andResponse2: response2, areEqual: responseTimestampsAreEqual)
    }

    // MARK: Private - Start Request Methods

    private func startRequestWithParameters(
        parameters: [String: AnyObject],
        delay: Float = 0.0,
        completion: (NSURLRequest, NSHTTPURLResponse?) -> Void)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Float(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            let request = self.manager.request(.GET, self.URLString, parameters: parameters)
            request.response { _, response, _, _ in
                completion(request.request, response)
            }
        }
    }

    // MARK: Private - Test Verification Methods

    private func verifyCachedResponses(
        forRequest1 request1: NSURLRequest?,
        andRequest2 request2: NSURLRequest?,
        exist: Bool)
    {
        if let
            request1 = request1,
            request2 = request2
        {
            let cachedResponse1 = self.URLCache.cachedResponseForRequest(request1)
            let cachedResponse2 = self.URLCache.cachedResponseForRequest(request2)

            if exist {
                XCTAssertNotNil(cachedResponse1, "cached response 1 should not be nil")
                XCTAssertNotNil(cachedResponse2, "cached response 2 should not be nil")
            } else {
                XCTAssertNil(cachedResponse1, "cached response 1 should be nil")
                XCTAssertNil(cachedResponse2, "cached response 2 should be nil")
            }
        } else {
            XCTFail("requests should not be nil")
        }
    }

    private func verifyResponseTimestamps(
        forResponse1 response1: NSHTTPURLResponse?,
        andResponse2 response2: NSHTTPURLResponse?,
        areEqual equal: Bool)
    {
        if let
            response1 = response1,
            response2 = response2
        {
            if let
                timestamp1 = response1.allHeaderFields["Date"] as? String,
                timestamp2 = response2.allHeaderFields["Date"] as? String
            {
                if equal {
                    XCTAssertEqual(timestamp1, timestamp2, "timestamps should be equal")
                } else {
                    XCTAssertNotEqual(timestamp1, timestamp2, "timestamps should not be equal")
                }
            } else {
                XCTFail("response timestamps should not be nil")
            }
        } else {
            XCTFail("responses should not be nil")
        }
    }
}

// MARK: -

class DefaultCacheBehaviorTestCase: CacheTestCase {

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        setUpManagerWithRequestCachePolicy(.UseProtocolCachePolicy)
    }

    override func tearDown() {
        super.tearDown()
        // No-op
    }

    // MARK: Tests

    func testCacheControlHeaderWithNoCacheValue() {
        executeCacheControlHeaderTestWithValue("no-cache", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithNoStoreValue() {
        executeCacheControlHeaderTestWithValue("no-store", cachedResponsesExist: false, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithPublicValue() {
        executeCacheControlHeaderTestWithValue("public", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithPrivateValue() {
        executeCacheControlHeaderTestWithValue("private", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithNonExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=3600", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=0", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }
}

// MARK: -

class IgnoreLocalCacheDataTestCase: CacheTestCase {

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        setUpManagerWithRequestCachePolicy(.ReloadIgnoringLocalCacheData)
    }

    override func tearDown() {
        super.tearDown()
        // No-op
    }

    // MARK: Tests

    func testCacheControlHeaderWithNoCacheValue() {
        executeCacheControlHeaderTestWithValue("no-cache", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithNoStoreValue() {
        executeCacheControlHeaderTestWithValue("no-store", cachedResponsesExist: false, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithPublicValue() {
        executeCacheControlHeaderTestWithValue("public", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithPrivateValue() {
        executeCacheControlHeaderTestWithValue("private", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithNonExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=3600", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=0", cachedResponsesExist: true, responseTimestampsAreEqual: false)
    }
}

// MARK: -

class UseLocalCacheDataIfExistsOtherwiseLoadFromNetworkTestCase: CacheTestCase {

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        setUpManagerWithRequestCachePolicy(.ReturnCacheDataElseLoad)
    }

    override func tearDown() {
        super.tearDown()
        // No-op
    }

    // MARK: Tests

    func testCacheControlHeaderWithNoCacheValue() {
        executeCacheControlHeaderTestWithValue("no-cache", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithNoStoreValue() {
        executeCacheControlHeaderTestWithValue("no-store", cachedResponsesExist: false, responseTimestampsAreEqual: false)
    }

    func testCacheControlHeaderWithPublicValue() {
        executeCacheControlHeaderTestWithValue("public", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithPrivateValue() {
        executeCacheControlHeaderTestWithValue("private", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithNonExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=3600", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=0", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }
}

// MARK: -

class UseLocalCacheDataAndDontLoadFromNetworkTestCase: CacheTestCase {

    // MARK: Properties

    var defaultManager: Manager!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()
        setUpManagerWithRequestCachePolicy(.ReturnCacheDataDontLoad)

        self.defaultManager = {
            let configuration: NSURLSessionConfiguration = {
                let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
                configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
                configuration.requestCachePolicy = .UseProtocolCachePolicy
                configuration.URLCache = self.URLCache

                return configuration
            }()

            let manager = Manager(configuration: configuration)

            return manager
        }()
    }

    override func tearDown() {
        super.tearDown()
        // No-op
    }

    // MARK: Tests

    func testRequestWithoutCachedResponseFailsWithResourceUnavailable() {
        // Given
        let expectation = expectationWithDescription("GET request to httpbin")
        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        self.manager.request(.GET, "http://httpbin.org/get")
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNil(response, "response should be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNotNil(error, "error should not be nil")

        if let
            data = data as? NSData,
            actualData = NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        {
            XCTAssertEqual(actualData, "", "data values should be equal")
        }

        if let error = error {
            XCTAssertEqual(error.code, NSURLErrorResourceUnavailable, "error code should be equal")
        }
    }

    func testCacheControlHeaderWithNoCacheValue() {
        executeCacheControlHeaderTestWithValue("no-cache", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithNoStoreValue() {
        // Given
        let parameters = ["Cache-Control": "no-store"]
        var request1: NSURLRequest?
        var request2: NSURLRequest?
        var response1: NSHTTPURLResponse?
        var response2: NSHTTPURLResponse?
        var data1: AnyObject?
        var data2: AnyObject?
        var error1: NSError?
        var error2: NSError?

        // When
        let expectation1 = expectationWithDescription("GET request1 to httpbin")
        self.defaultManager.request(.GET, self.URLString, parameters: parameters)
            .response { responseRequest, responseResponse, responseData, responseError in
                request1 = responseRequest
                response1 = responseResponse
                data1 = responseData
                error1 = responseError
                expectation1.fulfill()
        }
        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        let expectation2 = expectationWithDescription("GET request2 to httpbin")
        self.manager.request(.GET, self.URLString, parameters: parameters)
            .response { responseRequest, responseResponse, responseData, responseError in
                request2 = responseRequest
                response2 = responseResponse
                data2 = responseData
                error2 = responseError
                expectation2.fulfill()
        }
        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request1, "request1 should not be nil")
        XCTAssertNotNil(response1, "response1 should not be nil")
        XCTAssertNotNil(data1, "data1 should not be nil")
        XCTAssertNil(error1, "error1 should be nil")

        XCTAssertNotNil(request2, "request2 should not be nil")
        XCTAssertNil(response2, "response2 should be nil")
        XCTAssertNotNil(data2, "data2 should not be nil")
        XCTAssertNotNil(error2, "error2 should not be nil")

        if let
            data = data2 as? NSData,
            actualData = NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        {
            XCTAssertEqual(actualData, "", "data values should be equal")
        }

        if let error = error2 {
            XCTAssertEqual(error.code, NSURLErrorResourceUnavailable, "error code should be equal")
        }
    }

    func testCacheControlHeaderWithPublicValue() {
        executeCacheControlHeaderTestWithValue("public", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithPrivateValue() {
        executeCacheControlHeaderTestWithValue("private", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithNonExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=3600", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    func testCacheControlHeaderWithExpiredMaxAgeValue() {
        executeCacheControlHeaderTestWithValue("max-age=0", cachedResponsesExist: true, responseTimestampsAreEqual: true)
    }

    // MARK: Overridden Test Execution Methods

    override func executeCacheControlHeaderTestWithValue(
        value: String,
        cachedResponsesExist: Bool,
        responseTimestampsAreEqual: Bool)
    {
        // Given
        let parameters = ["Cache-Control": value]
        var request1: NSURLRequest?
        var request2: NSURLRequest?
        var response1: NSHTTPURLResponse?
        var response2: NSHTTPURLResponse?

        // When
        let expectation1 = expectationWithDescription("GET request1 to httpbin")
        self.defaultManager.request(.GET, self.URLString, parameters: parameters)
            .response { request, response, _, _ in
                request1 = request
                response1 = response
                expectation1.fulfill()
        }
        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        let expectation2 = expectationWithDescription("GET request2 to httpbin")
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Float(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.manager.request(.GET, self.URLString, parameters: parameters)
                .response { request, response, _, _ in
                    request2 = request
                    response2 = response
                    expectation2.fulfill()
            }
        }
        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        verifyCachedResponses(forRequest1: request1, andRequest2: request2, exist: cachedResponsesExist)
        verifyResponseTimestamps(forResponse1: response1, andResponse2: response2, areEqual: responseTimestampsAreEqual)
    }
}
