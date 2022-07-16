//
//  BackgroundAssertion.swift
//  Alamofire
//
//  Created by Jon Shier on 6/19/22.
//  Copyright © 2022 Alamofire. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
final class BackgroundAssertion {
    private static let shared = BackgroundAssertion()

    static func start() {
        _ = shared
    }

    @Protected private var isActive = false

    private let group: DispatchGroup

    private init() {
        NSLog("*** BackgroundAssertion.init")
        group = DispatchGroup()
        ProcessInfo().performExpiringActivity(withReason: "org.alamofire.session.backgroundAssertion") { [self] isExpired in
            if isExpired {
                guard isActive else { return }

                group.leave()
            } else {
                isActive = true
                group.enter()
                group.notify(queue: .global()) {
                    NSLog("*** BackgroundAssertion completed.")
                }
                // Block until canceled or expired.
                group.wait()
                isActive = false
            }
        }
    }

    deinit {
        guard isActive else { return }

        group.leave()
    }
}
#endif
