// NetworkReachabilityManagerTests.swift
//
// Copyright (c) 2014–2016 Alamofire Software Foundation (http://alamofire.org/)
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
        XCTAssertEqual(manager?.networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
        XCTAssertEqual(manager?.isReachable, true)
        XCTAssertEqual(manager?.isReachableOnWWAN, false)
        XCTAssertEqual(manager?.isReachableOnEthernetOrWiFi, true)
    }

    func testThatHostManagerStartsWithReachableStatus() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        XCTAssertEqual(manager?.networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
        XCTAssertEqual(manager?.isReachable, true)
        XCTAssertEqual(manager?.isReachableOnWWAN, false)
        XCTAssertEqual(manager?.isReachableOnEthernetOrWiFi, true)
    }

    func testThatAddressManagerStartsWithReachableStatus() {
        // Given, When
        let manager = NetworkReachabilityManager()

        // Then
        XCTAssertEqual(manager?.networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
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
        let manager = NetworkReachabilityManager(host: "localhost")
        let expectation = expectationWithDescription("listener closure should be executed")

        var networkReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus?

        manager?.listener = { status in
            networkReachabilityStatus = status
            expectation.fulfill()
        }

        // When
        manager?.startListening()
        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
    }

    func testThatAddressManagerIsNotifiedWhenStartListeningIsCalled() {
        // Given
        let manager = NetworkReachabilityManager()
        let expectation = expectationWithDescription("listener closure should be executed")

        var networkReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus?

        manager?.listener = { status in
            networkReachabilityStatus = status
            expectation.fulfill()
        }

        // When
        manager?.startListening()
        waitForExpectationsWithTimeout(timeout, handler: nil)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
    }

    // MARK: - Tests - Network Reachability Status

    func testThatManagerReturnsNotReachableStatusWhenReachableFlagIsAbsent() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.ConnectionOnDemand]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .NotReachable)
    }

    func testThatManagerReturnsNotReachableStatusWhenInterventionIsRequired() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.Reachable, .ConnectionRequired, .ConnectionOnDemand, .InterventionRequired]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .NotReachable)
    }

    func testThatManagerReturnsReachableOnWiFiStatusWhenConnectionIsNotRequired() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.Reachable]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
    }

    func testThatManagerReturnsReachableOnWiFiStatusWhenConnectionIsOnDemand() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.Reachable, .ConnectionRequired, .ConnectionOnDemand]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
    }

    func testThatManagerReturnsReachableOnWiFiStatusWhenConnectionIsOnTraffic() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.Reachable, .ConnectionRequired, .ConnectionOnTraffic]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .Reachable(.EthernetOrWiFi))
    }

#if os(iOS)
    func testThatManagerReturnsReachableOnWWANStatusWhenIsWWAN() {
        // Given
        let manager = NetworkReachabilityManager()
        let flags: SCNetworkReachabilityFlags = [.Reachable, .IsWWAN]

        // When
        let networkReachabilityStatus = manager?.networkReachabilityStatusForFlags(flags)

        // Then
        XCTAssertEqual(networkReachabilityStatus, .Reachable(.WWAN))
    }
#endif
}
