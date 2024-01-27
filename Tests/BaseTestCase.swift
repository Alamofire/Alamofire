//
//  BaseTestCase.swift
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

class BaseTestCase: XCTestCase {
    enum SkipVersion {
        case twenty
        case none

        var shouldSkip: Bool {
            switch self {
            case .twenty:
                if #available(macOS 11, iOS 14, tvOS 14, watchOS 7, *) {
                    return false
                } else {
                    return true
                }
            case .none:
                return false
            }
        }

        var reason: String {
            switch self {
            case .twenty:
                return "Skipped due to being iOS 13 or below."
            case .none:
                return "This should never skip."
            }
        }
    }

    let timeout: TimeInterval = 3

    var skipVersion: SkipVersion { .none }

    var testDirectoryURL: URL {
        FileManager.temporaryDirectoryURL.appendingPathComponent("org.alamofire.tests")
    }

    var temporaryFileURL: URL {
        testDirectoryURL.appendingPathComponent(UUID().uuidString)
    }

    private var session: Session?

    override func setUp() {
        FileManager.createDirectory(at: testDirectoryURL)

        super.setUp()
    }

    override func setUpWithError() throws {
        try XCTSkipIf(skipVersion.shouldSkip, skipVersion.reason)

        try super.setUpWithError()
    }

    override func tearDown() {
        session = nil
        FileManager.removeAllItemsInsideDirectory(at: testDirectoryURL)
        clearCredentials()
        clearCookies()

        super.tearDown()
    }

    func clearCookies(for storage: HTTPCookieStorage = .shared) {
        storage.cookies?.forEach { storage.deleteCookie($0) }
    }

    func clearCredentials(for storage: URLCredentialStorage = .shared) {
        for (protectionSpace, credentials) in storage.allCredentials {
            for (_, credential) in credentials {
                storage.remove(credential, for: protectionSpace)
            }
        }
    }

    func url(forResource fileName: String, withExtension ext: String) -> URL {
        Bundle.test.url(forResource: fileName, withExtension: ext)!
    }

    func stored(_ session: Session) -> Session {
        self.session = session

        return session
    }

    /// Runs assertions on a particular `DispatchQueue`.
    ///
    /// - Parameters:
    ///   - queue: The `DispatchQueue` on which to run the assertions.
    ///   - assertions: Closure containing assertions to run
    func assert(on queue: DispatchQueue, assertions: @escaping () -> Void) {
        let expect = expectation(description: "all assertions are complete")

        queue.async {
            assertions()
            expect.fulfill()
        }

        waitForExpectations(timeout: timeout)
    }
}
