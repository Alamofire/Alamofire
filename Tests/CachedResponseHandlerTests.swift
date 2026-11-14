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
import Testing

@Suite(.storesInstances)
struct CachedResponseHandlerTestCase {
    // MARK: Tests - Per Request

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestCachedResponseHandlerCanCacheResponse() async {
        // Given
        let session = session()

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.cache).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(session.cachedResponseExists(for: request))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestCachedResponseHandlerCanNotCacheResponse() async {
        // Given
        let session = session()

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should not cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(!session.cachedResponseExists(for: request))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestCachedResponseHandlerCanModifyCacheResponse() async {
        // Given
        let session = session()

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should cache response")

        // When
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        let request = session.request(.default).cacheResponse(using: cacher).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(session.cachedResponseExists(for: request))
        #expect(session.cachedResponse(for: request)?.userInfo?["key"] as? String == "value")
    }

    // MARK: Tests - Per Session

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCachedResponseHandlerCanCacheResponse() async {
        // Given
        let session = session(using: ResponseCacher.cache)

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should cache response")

        // When
        let request = session.request(.default).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(session.cachedResponseExists(for: request))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCachedResponseHandlerCanNotCacheResponse() async {
        // Given
        let session = session(using: ResponseCacher.doNotCache)

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should not cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(!session.cachedResponseExists(for: request))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionCachedResponseHandlerCanModifyCacheResponse() async {
        // Given
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        let session = session(using: cacher)

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: cacher).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(session.cachedResponseExists(for: request))
        #expect(session.cachedResponse(for: request)?.userInfo?["key"] as? String == "value")
    }

    // MARK: Tests - Per Request Prioritization

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestCachedResponseHandlerIsPrioritizedOverSessionCachedResponseHandler() async {
        // Given
        let session = session(using: ResponseCacher.cache)

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
        #expect(!session.cachedResponseExists(for: request))
    }

    // MARK: Private - Test Helpers

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func session(using handler: (any CachedResponseHandler)? = nil) -> Session {
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

        // Independent keeps the provided cache and replaces only the shared cookie and credential storage.
        return stored(Session.independent(configuration: configuration, cachedResponseHandler: handler))
    }
}

@Suite
struct StaticCachedResponseHandlerTests {
    func takeCachedResponseHandler(_ handler: any CachedResponseHandler) {
        _ = handler
    }

    @Test
    func cacheResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.cache)
    }

    @Test
    func doNotCacheResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.doNotCache)
    }

    @Test
    func modifyResponseCacherCanBeCreatedStaticallyFromProtocol() {
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
