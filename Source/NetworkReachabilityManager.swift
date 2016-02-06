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

public let NetworkReachabilityStatusDidChangeNotification = "com.alamofire.network.reachability.status.did.change"

public enum NetworkReachabilityStatus: Int {
    case Unknown         = -1
    case NotReachable    = 0
    case ReachableOnWWAN = 1
    case ReachableOnWiFi = 2
}

public class NetworkReachabilityManager {
    public typealias Listener = NetworkReachabilityStatus -> Void

    // MARK: - Properties

    public var isReachable: Bool { return isReachableOnWWAN || isReachableOnWiFi }
    public var isReachableOnWWAN: Bool { return networkReachabilityStatus == .ReachableOnWWAN }
    public var isReachableOnWiFi: Bool { return networkReachabilityStatus == .ReachableOnWiFi }

    public var networkReachabilityStatus: NetworkReachabilityStatus {
        guard let flags = self.flags else { return .Unknown }
        return networkReachabilityStatusForFlags(flags)
    }

    public var listenerQueue: dispatch_queue_t = dispatch_get_main_queue()
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

    public convenience init?(host: String) {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else { return nil }
        self.init(reachability: reachability)
    }

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
