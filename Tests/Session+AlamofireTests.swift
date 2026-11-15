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
        var eventMonitors = eventMonitors
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *), let monitor = NetworkFailureMonitor.current {
            eventMonitors.append(monitor)
        }

        return Session(configuration: configuration.withIndependentStorage(),
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

// MARK: - External Services

/// Records whether a request failed because of the network rather than the server or TLS, for `ExternalServiceTrait`.
final class NetworkFailureMonitor: EventMonitor, @unchecked Sendable {
    /// URL errors that come from network trouble. TLS failures, such as `.secureConnectionFailed`, aren't included.
    private static let networkErrorCodes: Set<URLError.Code> = [.timedOut,
                                                                .cannotConnectToHost,
                                                                .networkConnectionLost,
                                                                .notConnectedToInternet,
                                                                .dataNotAllowed]

    let queue = DispatchQueue(label: "org.alamofire.tests.networkFailureMonitor")

    private let lock = NSLock()
    private var sawNetworkFailure = false

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error = error as? URLError, Self.networkErrorCodes.contains(error.code) else { return }

        markNetworkFailure()
    }

    /// Whether `issue` could come from the network: a request in the test failed with a network error, or a wait timed
    /// out, which a request that never gets a response causes. Issues after either are excused too, since they follow
    /// from the missing response.
    func excuses(_ issue: Issue) -> Bool {
        if issue.description.contains("Timed out after") {
            markNetworkFailure()
        }

        // Alamofire queues events for monitors before it finishes the request, so this sees every completed request.
        queue.sync {}

        lock.lock()
        defer { lock.unlock() }

        return sawNetworkFailure
    }

    private func markNetworkFailure() {
        lock.lock()
        defer { lock.unlock() }

        sawNetworkFailure = true
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension NetworkFailureMonitor {
    /// The monitor for the running test, added to every `Session.independent` it creates.
    @TaskLocal static var current: NetworkFailureMonitor?
}

/// In CI, treats failures caused by the network in tests of an external service, such as badssl.com, as known issues.
/// Any other failure, including a TLS error, still fails the test. Outside CI, the tests run normally.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct ExternalServiceTrait: TestTrait, SuiteTrait, TestScoping {
    /// GitHub Actions sets `CI`. Set it for `xcodebuild` as `TEST_RUNNER_CI`.
    static let isEnabled = ProcessInfo.processInfo.environment["CI"] == "true"

    let service: String

    var isRecursive: Bool { true }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        Self.isEnabled && testCase != nil ? self : nil
    }

    func provideScope(for test: Test,
                      testCase: Test.Case?,
                      performing function: @Sendable () async throws -> Void) async throws {
        let monitor = NetworkFailureMonitor()
        try await withKnownIssue("\(service) wasn't reachable", isIntermittent: true) {
            try await NetworkFailureMonitor.$current.withValue(monitor) {
                try await function()
            }
        } matching: { issue in
            monitor.excuses(issue)
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Trait where Self == ExternalServiceTrait {
    /// Excuses network failures reaching `service` in CI. See `ExternalServiceTrait`.
    static func dependsOnExternalService(_ service: String) -> Self { Self(service: service) }
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

@Suite(.storesInstances)
struct ExternalServiceTraitTests {
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @Test
    func requestFailingFromTheNetworkIsExcused() async throws {
        try await runInTrait {
            // Given
            // Nothing listens on port 1, so the connection is refused.
            let session = stored(Session.independent())

            // When
            let response = await session.request("http://127.0.0.1:1/").serializingData().response

            // Then
            #expect(response.error == nil)
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @Test
    func issuesAfterATimeoutAreExcused() async throws {
        try await runInTrait {
            // Given
            let completion = Completion("never completes", timeout: 0.1)

            // When
            await completion.wait()

            // Then
            Issue.record("Follows from the missing response.")
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @Test
    func tlsFailureIsNotExcused() async {
        await withKnownIssue {
            try await runInTrait {
                // When
                completeTask(with: URLError(.secureConnectionFailed))

                // Then
                Issue.record("TLS failures still fail the test.")
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @Test
    func failureWithoutANetworkErrorIsNotExcused() async {
        await withKnownIssue {
            try await runInTrait {
                Issue.record("Other failures still fail the test.")
            }
        }
    }

    /// Runs `body` in the trait's scope, as Swift Testing would in CI.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func runInTrait(_ body: @Sendable () async throws -> Void) async throws {
        let test = try #require(Test.current)
        try await ExternalServiceTrait(service: "test").provideScope(for: test, testCase: Test.Case.current, performing: body)
    }

    /// Reports a task completing with `error` to the running test's `NetworkFailureMonitor`.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    private func completeTask(with error: URLError) {
        let task = URLSession.shared.dataTask(with: Endpoint().url)
        NetworkFailureMonitor.current?.urlSession(.shared, task: task, didCompleteWithError: error)
    }
}
