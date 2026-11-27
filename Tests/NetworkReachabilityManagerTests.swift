//
//  NetworkReachabilityManagerTests.swift
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

#if canImport(SystemConfiguration)

@testable import Alamofire
import Foundation
import SystemConfiguration
import Testing

// NetworkReachabilityManager is deprecated on current platforms. Suites can't be deprecated, so each test is.
@Suite(.storesInstances)
struct NetworkReachabilityManagerTestCase {
    // MARK: - Tests - Initialization

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func managerCanBeInitializedFromHost() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        #expect(manager != nil)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func managerCanBeInitializedFromAddress() {
        // Given, When
        let manager = NetworkReachabilityManager()

        // Then
        #expect(manager != nil)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func hostManagerIsReachableOnWiFi() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        #expect(manager?.status == .reachable(.ethernetOrWiFi))
        #expect(manager?.isReachable == true)
        #expect(manager?.isReachableOnCellular == false)
        #expect(manager?.isReachableOnEthernetOrWiFi == true)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func hostManagerStartsWithReachableStatus() {
        // Given, When
        let manager = NetworkReachabilityManager(host: "localhost")

        // Then
        #expect(manager?.status == .reachable(.ethernetOrWiFi))
        #expect(manager?.isReachable == true)
        #expect(manager?.isReachableOnCellular == false)
        #expect(manager?.isReachableOnEthernetOrWiFi == true)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func addressManagerStartsWithReachableStatus() {
        // Given, When
        let manager = NetworkReachabilityManager()

        // Then
        #expect(manager?.status == .reachable(.ethernetOrWiFi))
        #expect(manager?.isReachable == true)
        #expect(manager?.isReachableOnCellular == false)
        #expect(manager?.isReachableOnEthernetOrWiFi == true)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func zeroManagerCanBeProperlyRestarted() async {
        // Given
        let manager = NetworkReachabilityManager()
        let first = Completion("first listener notified")
        let second = Completion("second listener notified")

        // When
        manager?.startListening { _ in
            first.complete()
        }
        await wait(for: [first])

        manager?.stopListening()

        manager?.startListening { _ in
            second.complete()
        }
        await wait(for: [second])

        // Then
        #expect(manager?.status == .reachable(.ethernetOrWiFi))
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func hostManagerCanBeProperlyRestarted() async {
        // Given
        let manager = NetworkReachabilityManager(host: "localhost")
        let first = Completion("first listener notified")
        let second = Completion("second listener notified")

        // When
        manager?.startListening { _ in
            first.complete()
        }
        await wait(for: [first])

        manager?.stopListening()

        manager?.startListening { _ in
            second.complete()
        }
        await wait(for: [second])

        // Then
        #expect(manager?.status == .reachable(.ethernetOrWiFi))
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func hostManagerCanBeDeinitialized() async {
        // Given
        let expect = Completion("reachability queue should clear")
        var manager: NetworkReachabilityManager? = NetworkReachabilityManager(host: "localhost")
        #if compiler(>=6.2.3) // Started emitting a diagnostic in 6.2.2, so lets conditionally use it.
        weak let weakManager = manager
        #else
        weak var weakManager = manager
        #endif

        // When
        manager?.startListening(onUpdatePerforming: { _ in })
        manager?.stopListening()
        manager?.reachabilityQueue.async { expect.complete() }
        manager = nil

        await expect.wait()

        // Then
        #expect(manager == nil, "strong reference should be nil")
        #expect(weakManager == nil, "weak reference should be nil")
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func addressManagerCanBeDeinitialized() async {
        // Given
        let expect = Completion("reachability queue should clear")
        var manager: NetworkReachabilityManager? = NetworkReachabilityManager()
        #if compiler(>=6.2.3) // Started emitting a diagnostic in 6.2.2, so lets conditionally use it.
        weak let weakManager = manager
        #else
        weak var weakManager = manager
        #endif

        // When
        manager?.startListening(onUpdatePerforming: { _ in })
        manager?.stopListening()
        manager?.reachabilityQueue.async { expect.complete() }
        manager = nil

        await expect.wait()

        // Then
        #expect(manager == nil, "strong reference should be nil")
        #expect(weakManager == nil, "weak reference should be nil")
    }

    // MARK: - Listener

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func hostManagerIsNotifiedWhenStartListeningIsCalled() async {
        // Given
        guard let manager = NetworkReachabilityManager(host: "store.apple.com") else {
            Issue.record("manager should NOT be nil")
            return
        }

        let expectation = Completion("listener closure should be executed")
        let networkReachabilityStatus = Capture<NetworkReachabilityManager.NetworkReachabilityStatus?>()

        // When
        manager.startListening { status in
            guard networkReachabilityStatus.value == nil else { return }
            networkReachabilityStatus.value = status
            expectation.complete()
        }
        await expectation.wait()

        // Then
        #expect(networkReachabilityStatus.value == .reachable(.ethernetOrWiFi))
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func addressManagerIsNotifiedWhenStartListeningIsCalled() async {
        // Given
        let manager = NetworkReachabilityManager()
        let expectation = Completion("listener closure should be executed")

        let networkReachabilityStatus = Capture<NetworkReachabilityManager.NetworkReachabilityStatus?>()

        // When
        manager?.startListening { status in
            networkReachabilityStatus.value = status
            expectation.complete()
        }
        await expectation.wait()

        // Then
        #expect(networkReachabilityStatus.value == .reachable(.ethernetOrWiFi))
    }

    // MARK: - NetworkReachabilityStatus

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsNotReachableStatusWhenReachableFlagIsAbsent() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.connectionOnDemand]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .notReachable)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsNotReachableStatusWhenConnectionIsRequired() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .notReachable)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsNotReachableStatusWhenInterventionIsRequired() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .interventionRequired]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .notReachable)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsReachableOnWiFiStatusWhenConnectionIsNotRequired() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .reachable(.ethernetOrWiFi))
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsReachableOnWiFiStatusWhenConnectionIsOnDemand() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .connectionOnDemand]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .reachable(.ethernetOrWiFi))
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsReachableOnWiFiStatusWhenConnectionIsOnTraffic() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable, .connectionRequired, .connectionOnTraffic]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .reachable(.ethernetOrWiFi))
    }

    #if os(iOS) || os(tvOS)
    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsReachableOnCellularStatusWhenIsWWAN() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable, .isWWAN]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .reachable(.cellular))
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func statusIsNotReachableOnCellularStatusWhenIsWWANAndConnectionIsRequired() {
        // Given
        let flags: SCNetworkReachabilityFlags = [.reachable, .isWWAN, .connectionRequired]

        // When
        let status = NetworkReachabilityManager.NetworkReachabilityStatus(flags)

        // Then
        #expect(status == .notReachable)
    }
    #endif
}

#endif
