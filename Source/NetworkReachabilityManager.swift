//
//  NetworkReachabilityManager.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

#if !os(watchOS)

import Foundation
import SystemConfiguration

/**
    The `NetworkReachabilityManager` class listens for reachability changes of hosts and addresses for both WWAN and
    WiFi network interfaces.

    Reachability can be used to determine background information about why a network operation failed, or to retry
    network requests when a connection is established. It should not be used to prevent a user from initiating a network
    request, as it's possible that an initial request may be required to establish reachability.
*/
public class NetworkReachabilityManager {
    /**
        Defines the various states of network reachability.

        - Unknown:         It is unknown whether the network is reachable.
        - NotReachable:    The network is not reachable.
        - ReachableOnWWAN: The network is reachable over the WWAN connection.
        - ReachableOnWiFi: The network is reachable over the WiFi connection.
    */
    public enum NetworkReachabilityStatus {
        case Unknown
        case NotReachable
        case Reachable(ConnectionType)
    }

    /**
        Defines the various connection types detected by reachability flags.

        - EthernetOrWiFi: The connection type is either over Ethernet or WiFi.
        - WWAN:           The connection type is a WWAN connection.
    */
    public enum ConnectionType {
        case EthernetOrWiFi
        case WWAN
    }

    /// A closure executed when the network reachability status changes. The closure takes a single argument: the
    /// network reachability status.
    public typealias Listener = NetworkReachabilityStatus -> Void

    // MARK: - Properties

    /// Whether the network is currently reachable.
    public var isReachable: Bool { return isReachableOnWWAN || isReachableOnEthernetOrWiFi }

    /// Whether the network is currently reachable over the WWAN interface.
    public var isReachableOnWWAN: Bool { return networkReachabilityStatus == .Reachable(.WWAN) }

    /// Whether the network is currently reachable over Ethernet or WiFi interface.
    public var isReachableOnEthernetOrWiFi: Bool { return networkReachabilityStatus == .Reachable(.EthernetOrWiFi) }

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
        Creates a `NetworkReachabilityManager` instance that monitors the address 0.0.0.0.

        Reachability treats the 0.0.0.0 address as a special token that causes it to monitor the general routing
        status of the device, both IPv4 and IPv6.

        - returns: The new `NetworkReachabilityManager` instance.
    */
    public convenience init?() {
        var address = sockaddr_in()
        address.sin_len = UInt8(sizeofValue(address))
        address.sin_family = sa_family_t(AF_INET)

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
            self.previousFlags = SCNetworkReachabilityFlags()
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

        listener?(networkReachabilityStatusForFlags(flags))
    }

    // MARK: - Internal - Network Reachability Status

    func networkReachabilityStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkReachabilityStatus {
        guard flags.contains(.Reachable) else { return .NotReachable }

        var networkStatus: NetworkReachabilityStatus = .NotReachable

        if !flags.contains(.ConnectionRequired) { networkStatus = .Reachable(.EthernetOrWiFi) }

        if flags.contains(.ConnectionOnDemand) || flags.contains(.ConnectionOnTraffic) {
            if !flags.contains(.InterventionRequired) { networkStatus = .Reachable(.EthernetOrWiFi) }
        }

        #if os(iOS)
            if flags.contains(.IsWWAN) { networkStatus = .Reachable(.WWAN) }
        #endif

        return networkStatus
    }
}

// MARK: -

extension NetworkReachabilityManager.NetworkReachabilityStatus: Equatable {}

/**
    Returns whether the two network reachability status values are equal.

    - parameter lhs: The left-hand side value to compare.
    - parameter rhs: The right-hand side value to compare.

    - returns: `true` if the two values are equal, `false` otherwise.
*/
public func ==(
    lhs: NetworkReachabilityManager.NetworkReachabilityStatus,
    rhs: NetworkReachabilityManager.NetworkReachabilityStatus)
    -> Bool
{
    switch (lhs, rhs) {
    case (.Unknown, .Unknown):
        return true
    case (.NotReachable, .NotReachable):
        return true
    case let (.Reachable(lhsConnectionType), .Reachable(rhsConnectionType)):
        return lhsConnectionType == rhsConnectionType
    default:
        return false
    }
}

#endif
