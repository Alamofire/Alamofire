//
//  Session+AlamofireTests.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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

extension Session {
    /// Creates a `Session` whose cache, cookie, and credential storage aren't shared with any other `Session` or the
    /// process-wide `.shared` instances, so tests using it can run in parallel without affecting each other.
    ///
    /// Takes the same parameters as `Session.init(configuration:...)`. Any storage on `configuration` that's the `.shared`
    /// instance is replaced with an independent one, while storage the caller provides, such as a credential storage from
    /// `URLCredentialStorage.independent()`, is kept. `configuration` itself isn't modified.
    static func independent(configuration: URLSessionConfiguration = URLSessionConfiguration.af.default,
                            delegate: SessionDelegate = SessionDelegate(),
                            rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.session.rootQueue"),
                            startRequestsImmediately: Bool = true,
                            requestSetup: RequestSetup = .lazy,
                            requestQueue: DispatchQueue? = nil,
                            serializationQueue: DispatchQueue? = nil,
                            interceptor: (any RequestInterceptor)? = nil,
                            serverTrustManager: ServerTrustManager? = nil,
                            redirectHandler: (any RedirectHandler)? = nil,
                            cachedResponseHandler: (any CachedResponseHandler)? = nil,
                            eventMonitors: [any EventMonitor] = [AlamofireNotifications()]) -> Session {
        Session(configuration: configuration.withIndependentStorage(),
                delegate: delegate,
                rootQueue: rootQueue,
                startRequestsImmediately: startRequestsImmediately,
                requestSetup: requestSetup,
                requestQueue: requestQueue,
                serializationQueue: serializationQueue,
                interceptor: interceptor,
                serverTrustManager: serverTrustManager,
                redirectHandler: redirectHandler,
                cachedResponseHandler: cachedResponseHandler,
                eventMonitors: eventMonitors)
    }
}

extension URLSessionConfiguration {
    /// A copy of the configuration with each `.shared` cache, cookie, and credential storage replaced by an independent
    /// one. Storage that isn't `.shared`, or is `nil`, is kept as is.
    func withIndependentStorage() -> URLSessionConfiguration {
        let configuration = copy() as! URLSessionConfiguration
        if configuration.urlCache === URLCache.shared {
            configuration.urlCache = .independent()
        }
        if configuration.httpCookieStorage === HTTPCookieStorage.shared {
            configuration.httpCookieStorage = .independent()
        }
        if configuration.urlCredentialStorage === URLCredentialStorage.shared {
            configuration.urlCredentialStorage = .independent()
        }

        return configuration
    }
}

// `URLCredentialStorage()` and `HTTPCookieStorage()` create instances that don't store anything, so these use the
// private, in-memory storage each new ephemeral configuration creates, which nothing else shares.

extension URLCache {
    /// A new in-memory cache shared with nothing else.
    static func independent() -> URLCache {
        URLSessionConfiguration.ephemeral.urlCache!
    }
}

extension HTTPCookieStorage {
    /// A new in-memory cookie storage shared with nothing else.
    static func independent() -> HTTPCookieStorage {
        URLSessionConfiguration.ephemeral.httpCookieStorage!
    }
}

extension URLCredentialStorage {
    /// A new in-memory credential storage shared with nothing else.
    static func independent() -> URLCredentialStorage {
        URLSessionConfiguration.ephemeral.urlCredentialStorage!
    }
}

// MARK: - Tests

@Suite
struct IndependentSessionTests {
    @Test
    func independentSessionsShareNoStorage() throws {
        // Given
        let first = Session.independent()
        let second = Session.independent()

        // When
        let firstConfiguration = first.sessionConfiguration
        let secondConfiguration = second.sessionConfiguration

        // Then
        let firstCache = try #require(firstConfiguration.urlCache)
        let firstCookies = try #require(firstConfiguration.httpCookieStorage)
        let firstCredentials = try #require(firstConfiguration.urlCredentialStorage)
        #expect(firstCache !== secondConfiguration.urlCache)
        #expect(firstCookies !== secondConfiguration.httpCookieStorage)
        #expect(firstCredentials !== secondConfiguration.urlCredentialStorage)
        #expect(firstCache !== URLCache.shared)
        #expect(firstCookies !== HTTPCookieStorage.shared)
        #expect(firstCredentials !== URLCredentialStorage.shared)
    }

    @Test
    func independentSessionKeepsConfigurationSettings() {
        // Given
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 3

        // When
        let session = Session.independent(configuration: configuration)

        // Then
        #expect(session.sessionConfiguration.timeoutIntervalForRequest == 3)
        #expect(session.sessionConfiguration.headers.dictionary == HTTPHeaders.default.dictionary)
        #expect(configuration.urlCredentialStorage === URLCredentialStorage.shared)
    }

    @Test
    func independentSessionKeepsProvidedStorage() {
        // Given
        let credentialStorage = URLCredentialStorage.independent()
        let configuration = URLSessionConfiguration.af.default
        configuration.urlCredentialStorage = credentialStorage

        // When
        let session = Session.independent(configuration: configuration)

        // Then
        #expect(session.sessionConfiguration.urlCredentialStorage === credentialStorage)
        #expect(session.sessionConfiguration.httpCookieStorage !== HTTPCookieStorage.shared)
        #expect(session.sessionConfiguration.urlCache !== URLCache.shared)
    }

    @Test
    func independentStorageStoresValues() {
        // Given
        let credentialStorage = URLCredentialStorage.independent()
        let protectionSpace = URLProtectionSpace(host: "example.com",
                                                 port: 80,
                                                 protocol: "http",
                                                 realm: "example.com",
                                                 authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        let credential = URLCredential(user: "user", password: "password", persistence: .forSession)

        // When
        credentialStorage.setDefaultCredential(credential, for: protectionSpace)

        // Then
        #expect(credentialStorage.defaultCredential(for: protectionSpace)?.user == "user")
        #expect(URLCredentialStorage.independent().defaultCredential(for: protectionSpace) == nil)
        #expect(URLCredentialStorage.shared.defaultCredential(for: protectionSpace) == nil)
    }
}
