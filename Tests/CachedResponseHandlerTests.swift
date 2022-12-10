//
//  CachedResponseHandlerTests.swift
//
//  Copyright (c) 2019 Alamofire Software Foundation (http://alamofire.org/)
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

final class CachedResponseHandlerTestCase: BaseTestCase {
    // MARK: Tests - Per Request

    func testThatRequestCachedResponseHandlerCanCacheResponse() {
        // Given
        let session = session()

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.cache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
    }

    func testThatRequestCachedResponseHandlerCanNotCacheResponse() {
        // Given
        let session = session()

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should not cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    func testThatRequestCachedResponseHandlerCanModifyCacheResponse() {
        // Given
        let session = session()

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        let request = session.request(.default).cacheResponse(using: cacher).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
        XCTAssertEqual(session.cachedResponse(for: request)?.userInfo?["key"] as? String, "value")
    }

    // MARK: Tests - Per Session

    func testThatSessionCachedResponseHandlerCanCacheResponse() {
        // Given
        let session = session(using: ResponseCacher.cache)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let request = session.request(.default).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
    }

    func testThatSessionCachedResponseHandlerCanNotCacheResponse() {
        // Given
        let session = session(using: ResponseCacher.doNotCache)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should not cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    func testThatSessionCachedResponseHandlerCanModifyCacheResponse() {
        // Given
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        let session = session(using: cacher)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: cacher).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
        XCTAssertEqual(session.cachedResponse(for: request)?.userInfo?["key"] as? String, "value")
    }

    // MARK: Tests - Per Request Prioritization

    func testThatRequestCachedResponseHandlerIsPrioritizedOverSessionCachedResponseHandler() {
        // Given
        let session = session(using: ResponseCacher.cache)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    // MARK: Private - Test Helpers

    private func session(using handler: CachedResponseHandler? = nil) -> Session {
        let configuration = URLSessionConfiguration.af.default
        let capacity = 100_000_000
        let cache: URLCache
        #if targetEnvironment(macCatalyst)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, directory: directory)
        #else
        let directory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: directory)
        #endif
        configuration.urlCache = cache

        return Session(configuration: configuration, cachedResponseHandler: handler)
    }
}

final class StaticCachedResponseHandlerTests: BaseTestCase {
    func takeCachedResponseHandler(_ handler: CachedResponseHandler) {
        _ = handler
    }

    func testThatCacheResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.cache)
    }

    func testThatDoNotCacheResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.doNotCache)
    }

    func testThatModifyResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.modify { _, _ in nil })
    }
}

// MARK: -

extension Session {
    fileprivate func cachedResponse(for request: Request) -> CachedURLResponse? {
        guard let urlRequest = request.request else { return nil }
        return session.configuration.urlCache?.cachedResponse(for: urlRequest)
    }

    fileprivate func cachedResponseExists(for request: Request) -> Bool {
        cachedResponse(for: request) != nil
    }
}
