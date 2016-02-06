// NetworkReachabilityManager.swift
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

import Foundation
import SystemConfiguration

/// Notification posted when network reachability status changes. The notification `object` contains the update
/// network reachability status as an `NSNumber` which will need to be converted.
public let NetworkReachabilityStatusDidChangeNotification = "com.alamofire.network.reachability.status.did.change"

/**
    Defines the various states of network reachability.

    - Unknown:         It is unknown whether the network is reachable.
    - NotReachable:    The network is not reachable.
    - ReachableOnWWAN: The network is reachable over the WWAN connection.
    - ReachableOnWiFi: The network is reachable over the WiFi connection.
*/
public enum NetworkReachabilityStatus: Int {
    case Unknown         = -1
    case NotReachable    = 0
    case ReachableOnWWAN = 1
    case ReachableOnWiFi = 2
}

/**
    The `NetworkReachabilityManager` class listens for reachability changes of hosts and addresses for both WWAN and
    WiFi network interfaces.

    Reachability can be used to determine background information about why a network operation failed, or to retry
    network requests when a connection is established. It should not be used to prevent a user from initiating a network
    request, as it's possible that an initial request may be required to establish reachability.
*/
public class NetworkReachabilityManager {
    /// A closure executed when the network reachability status changes. The closure takes a single argument: the 
    /// network reachability status.
    public typealias Listener = NetworkReachabilityStatus -> Void

    // MARK: - Properties

    /// Whether the network is currently reachable.
    public var isReachable: Bool { return isReachableOnWWAN || isReachableOnWiFi }

    /// Whether the network is currently reachable over the WWAN interface.
    public var isReachableOnWWAN: Bool { return networkReachabilityStatus == .ReachableOnWWAN }

    /// Whether the network is currently reachable over the WiFi interface.
    public var isReachableOnWiFi: Bool { return networkReachabilityStatus == .ReachableOnWiFi }

    /// The current network reachability status.
    public var networkReachabilityStatus: NetworkReachabilityStatus {
        guard let flags = self.flags else { return .Unknown }
        return networkReachabilityStatusForFlags(flags)
    }

    /// The dispatch queue to execute the `listener` closure on.
    public var listenerQueue: dispatch_queue_t = dispatch_get_main_queue()

    /// A closure executed when the network reachability status changes.
    public var listener: Listener?

    private var flags: SCNetworkReachabilityFlags? {
        var flags = SCNetworkReachabilityFlags()

        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            return flags
        }

        return nil
    }

    private let reachability: SCNetworkReachability
    private var previousFlags: SCNetworkReachabilityFlags

    // MARK: - Initialization

    /**
        Creates a `NetworkReachabilityManager` instance with the specified host.

        - parameter host: The host used to evaluate network reachability.

        - returns: The new `NetworkReachabilityManager` instance.
    */
    public convenience init?(host: String) {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else { return nil }
        self.init(reachability: reachability)
    }

    /**
        Creates a `NetworkReachabilityManager` instance with the default socket address (`sockaddr_in6`).

        - returns: The new `NetworkReachabilityManager` instance.
     */
    public convenience init?() {
        var address = sockaddr_in6()
        address.sin6_len = UInt8(sizeofValue(address))
        address.sin6_family = sa_family_t(AF_INET6)

        guard let reachability = withUnsafePointer(&address, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { return nil }

        self.init(reachability: reachability)
    }

    private init(reachability: SCNetworkReachability) {
        self.reachability = reachability
        self.previousFlags = SCNetworkReachabilityFlags()
    }

    deinit {
        stopListening()
    }

    // MARK: - Listening

    /**
        Starts listening for changes in network reachability status.

        - returns: `true` if listening was started successfully, `false` otherwise.
    */
    public func startListening() -> Bool {
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutablePointer(Unmanaged.passUnretained(self).toOpaque())

        let callbackEnabled = SCNetworkReachabilitySetCallback(
            reachability,
            { (_, flags, info) in
                let reachability = Unmanaged<NetworkReachabilityManager>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
                reachability.notifyListener(flags)
            },
            &context
        )

        let queueEnabled = SCNetworkReachabilitySetDispatchQueue(reachability, listenerQueue)

        dispatch_async(listenerQueue) {
            self.notifyListener(self.flags ?? SCNetworkReachabilityFlags())
        }

        return callbackEnabled && queueEnabled
    }

    /**
        Stops listening for changes in network reachability status.
    */
    public func stopListening() {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }

    // MARK: - Internal - Listener Notification

    func notifyListener(flags: SCNetworkReachabilityFlags) {
        guard previousFlags != flags else { return }
        previousFlags = flags

        let networkReachabilityStatus = networkReachabilityStatusForFlags(flags)

        listener?(networkReachabilityStatus)

        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(
                NetworkReachabilityStatusDidChangeNotification,
                object: networkReachabilityStatus.rawValue
            )
        }
    }

    // MARK: - Internal - Network Reachability Status

    func networkReachabilityStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkReachabilityStatus {
        guard flags.contains(.Reachable) else { return .NotReachable }

        var networkStatus: NetworkReachabilityStatus = .NotReachable

        if !flags.contains(.ConnectionRequired) { networkStatus = .ReachableOnWiFi }

        if flags.contains(.ConnectionOnDemand) || flags.contains(.ConnectionOnTraffic) {
            if !flags.contains(.InterventionRequired) { networkStatus = .ReachableOnWiFi }
        }

        #if os(iOS)
            if flags.contains(.IsWWAN) { networkStatus = .ReachableOnWWAN }
        #endif

        return networkStatus
    }
}
