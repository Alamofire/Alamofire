//
//  NetworkReachabilityManagerTests.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
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

@testable import Alamofire
import Foundation
import SystemConfiguration
import XCTest

class NetworkReachabilityManagerTestCase: BaseTestCase {

    // MARK: - Tests - Initialization

    func testThatManagerCanBeInitializedFromHost() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        XCTAssertNotNil(manager)
    }

    func testThatManagerCanBeInitializedFromAddress() {
        // Given, When
        let manager = NetworkReachabilityManager()

        // Then
        XCTAssertNotNil(manager)
    }

    func testThatHostManagerIsReachableOnWiFi() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        XCTAssertEqual(manager?.networkReachabilityStatus, .reachable(.ethernetOrWiFi))
        XCTAssertEqual(manager?.isReachable, true)
        XCTAssertEqual(manager?.isReachableOnWWAN, false)
        XCTAssertEqual(manager?.isReachableOnEthernetOrWiFi, true)
    }

    func testThatHostManagerStartsWithReachableStatus() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        XCTAssertEqual(manager?.networkReachabilityStatus, .reachable(.ethernetOrWiFi))
        XCTAssertEqual(manager?.isReachable, true)
        XCTAssertEqual(manager?.isReachableOnWWAN, false)
        XCTAssertEqual(manager?.isReachableOnEthernetOrWiFi, true)
    }

    func testThatAddressManagerStartsWithReachableStatus() {
        // Given, When
        let manager = NetworkReachabilityManager()

        // Then
        XCTAssertEqual(manager?.networkReachabilityStatus, .reachable(.ethernetOrWiFi))
        XCTAssertEqual(manager?.isReachable, true)
        XCTAssertEqual(manager?.isReachableOnWWAN, false)
        XCTAssertEqual(manager?.isReachableOnEthernetOrWiFi, true)
    }

    func testThatHostManagerCanBeDeinitialized() {
        // Given
        var manager: NetworkReachabilityManager? = NetworkReachabilityManager(host: "localhost")

        // When
        manager = nil

        // Then
        XCTAssertNil(manager)
    }

    func testThatAddressManagerCanBeDeinitialized() {
        // Given
        var manager: NetworkReachabilityManager? = NetworkReachabilityManager()

        // When
        manager = nil

        // Then
        XCTAssertNil(manager)
    }

    // MARK: - Tests - Listener

    func testThatHostManagerIsNotifiedWhenStartListeningIsCalled() {
        // Given
        guard let manager = NetworkReachabilityManager(host: "store.apple.com") else {
            XCTFail("manager should NOT be nil")
            return
        }

        let expectation = self.expectation(description: "listener closure should be executed")
        var networkReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus?

        manager.listener = { status in
            guard networkReachabilityStatus == nil else { return }
            networkReachabilityStatus = status
            expectation.fulfill()
        }

        // When
        manager.startListening()
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .reachable(.ethernetOrWiFi))
    }

    func testThatAddressManagerIsNotifiedWhenStartListeningIsCalled() {
        // Given
        let manager = NetworkReachabilityManager()
        let expectation = self.expectation(description: "listener closure should be executed")

        var networkReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus?

        manager?.listener = { status in
            networkReachabilityStatus = status
            expectation.fulfill()
        }

        // When
        manager?.startListening()
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .reachable(.ethernetOrWiFi))
    }

    // MARK: - Tests - Network Reachability Status

    func testThatManagerReturnsNotReachableStatusWhenReachableFlagIsAbsent() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.connectionOnDemand]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .notReachable)
    }

    func testThatManagerReturnsNotReachableStatusWhenConnectionIsRequired() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .notReachable)
    }

    func testThatManagerReturnsNotReachableStatusWhenInterventionIsRequired() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .interventionRequired]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .notReachable)
    }

    func testThatManagerReturnsReachableOnWiFiStatusWhenConnectionIsNotRequired() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .reachable(.ethernetOrWiFi))
    }

    func testThatManagerReturnsReachableOnWiFiStatusWhenConnectionIsOnDemand() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .connectionOnDemand]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .reachable(.ethernetOrWiFi))
    }

    func testThatManagerReturnsReachableOnWiFiStatusWhenConnectionIsOnTraffic() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .connectionOnTraffic]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .reachable(.ethernetOrWiFi))
    }

#if os(iOS)
    func testThatManagerReturnsReachableOnWWANStatusWhenIsWWAN() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable, .isWWAN]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .reachable(.wwan))
    }

    func testThatManagerReturnsNotReachableOnWWANStatusWhenIsWWANAndConnectionIsRequired() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.reachable, .isWWAN, .connectionRequired]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .notReachable)
    }
#endif
}
