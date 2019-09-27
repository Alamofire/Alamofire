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
    // MARK: Properties

    private let urlString = "https://httpbin.org/get"

    // MARK: Tests - Per Request

    func testThatRequestCachedResponseHandlerCanCacheResponse() {
        // Given
        let session = self.session()

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should cache response")

        // When
        let request = session.request(urlString).cacheResponse(using: ResponseCacher.cache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
    }

    func testThatRequestCachedResponseHandlerCanNotCacheResponse() {
        // Given
        let session = self.session()

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should not cache response")

        // When
        let request = session.request(urlString).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    func testThatRequestCachedResponseHandlerCanModifyCacheResponse() {
        // Given
        let session = self.session()

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should cache response")

        // When
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        let request = session.request(urlString).cacheResponse(using: cacher).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
        XCTAssertEqual(session.cachedResponse(for: request)?.userInfo?["key"] as? String, "value")
    }

    // MARK: Tests - Per Session

    func testThatSessionCachedResponseHandlerCanCacheResponse() {
        // Given
        let session = self.session(using: ResponseCacher.cache)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should cache response")

        // When
        let request = session.request(urlString).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
    }

    func testThatSessionCachedResponseHandlerCanNotCacheResponse() {
        // Given
        let session = self.session(using: ResponseCacher.doNotCache)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should not cache response")

        // When
        let request = session.request(urlString).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

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

        let session = self.session(using: cacher)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should cache response")

        // When
        let request = session.request(urlString).cacheResponse(using: cacher).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
        XCTAssertEqual(session.cachedResponse(for: request)?.userInfo?["key"] as? String, "value")
    }

    // MARK: Tests - Per Request Prioritization

    func testThatRequestCachedResponseHandlerIsPrioritizedOverSessionCachedResponseHandler() {
        // Given
        let session = self.session(using: ResponseCacher.cache)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should cache response")

        // When
        let request = session.request(urlString).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    // MARK: Private - Test Helpers

    private func session(using handler: CachedResponseHandler? = nil) -> Session {
        let configuration = URLSessionConfiguration.af.default
        let capacity = 100_000_000
        let cache: URLCache
        // swiftformat:disable indent
        #if swift(>=5.1)
        if #available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, directory: directory)
        } else {
            cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: UUID().uuidString)
        }
        #else
        cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: UUID().uuidString)
        #endif
        // swiftformat:enable indent
        configuration.urlCache = cache

        return Session(configuration: configuration, cachedResponseHandler: handler)
    }
}

// MARK: -

extension Session {
    fileprivate func cachedResponse(for request: Request) -> CachedURLResponse? {
        guard let urlRequest = request.request else { return nil }
        return session.configuration.urlCache?.cachedResponse(for: urlRequest)
    }

    fileprivate func cachedResponseExists(for request: Request) -> Bool {
        return cachedResponse(for: request) != nil
    }
}
