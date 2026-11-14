//
//  RedirectHandlerTests.swift
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
struct RedirectHandlerTestCase {
    // MARK: - Properties

    private var redirectEndpoint: Endpoint { .get }
    private var endpoint: Endpoint { .redirectTo(redirectEndpoint) }

    // MARK: - Tests - Per Request

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestRedirectHandlerCanFollowRedirects() async {
        // Given
        let session = stored(Session.independent())

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should redirect to /get")

        // When
        session.request(endpoint).redirect(using: Redirector.follow).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        #expect(response.response?.url == redirectEndpoint.url)
        #expect(response.response?.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestRedirectHandlerCanNotFollowRedirects() async {
        // Given
        let session = stored(Session.independent())

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should NOT redirect to /get")

        // When
        session.request(endpoint).redirect(using: Redirector.doNotFollow).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data == nil)
        #expect(response.error == nil)

        #expect(response.response?.url == endpoint.url)
        #expect(response.response?.statusCode == 302)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestRedirectHandlerCanModifyRedirects() async {
        // Given
        let session = stored(Session.independent())
        let customRedirectEndpoint = Endpoint.method(.patch)

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should redirect to /patch")

        // When
        let redirector = Redirector(behavior: .modify { _, _, _ in customRedirectEndpoint.urlRequest })

        session.request(endpoint).redirect(using: redirector).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        #expect(response.response?.url == customRedirectEndpoint.url)
        #expect(response.response?.statusCode == 200)
    }

    // MARK: - Tests - Per Session

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionRedirectHandlerCanFollowRedirects() async {
        // Given
        let session = stored(Session.independent(redirectHandler: Redirector.follow))

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should redirect to /get")

        // When
        session.request(endpoint).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        #expect(response.response?.url == redirectEndpoint.url)
        #expect(response.response?.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionRedirectHandlerCanNotFollowRedirects() async {
        // Given
        let session = stored(Session.independent(redirectHandler: Redirector.doNotFollow))

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should NOT redirect to /get")

        // When
        session.request(endpoint).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data == nil)
        #expect(response.error == nil)

        #expect(response.response?.url == endpoint.url)
        #expect(response.response?.statusCode == 302)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func sessionRedirectHandlerCanModifyRedirects() async {
        // Given
        let customRedirectEndpoint = Endpoint.method(.patch)

        let redirector = Redirector(behavior: .modify { _, _, _ in customRedirectEndpoint.urlRequest })
        let session = stored(Session.independent(redirectHandler: redirector))

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should redirect to /patch")

        // When
        session.request(endpoint).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        #expect(response.response?.url == customRedirectEndpoint.url)
        #expect(response.response?.statusCode == 200)
    }

    // MARK: - Tests - Per Request Prioritization

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestRedirectHandlerIsPrioritizedOverSessionRedirectHandler() async {
        // Given
        let session = stored(Session.independent(redirectHandler: Redirector.doNotFollow))

        let response = Capture<DataResponse<Data?, AFError>?>()
        let expectation = Completion("Request should redirect to /get")

        // When
        session.request(endpoint).redirect(using: Redirector.follow).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        #expect(response.response?.url == redirectEndpoint.url)
        #expect(response.response?.statusCode == 200)
    }
}

@Suite
struct StaticRedirectHandlerTests {
    func takeRedirectHandler(_ handler: any RedirectHandler) {
        _ = handler
    }

    @Test
    func followRedirectorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeRedirectHandler(.follow)
    }

    @Test
    func doNotFollowRedirectorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeRedirectHandler(.doNotFollow)
    }

    @Test
    func modifyRedirectorCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeRedirectHandler(.modify { _, _, _ in nil })
    }
}
