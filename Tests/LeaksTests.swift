//
//  LeaksTests.swift
//  Alamofire
//
//  Created by Jon Shier on 5/21/20.
//  Copyright © 2020 Alamofire. All rights reserved.
//

import XCTest

// Only build when built through SPM, as tests run through Xcode don't like this.
// Add LEAKS flag once we figure out a way to automate this.
// Can run by invoking swift test -c debug -Xswiftc -DLEAKS in the Alamofire directory.
// Sample code from the Swift forums: https://forums.swift.org/t/test-for-memory-leaks-in-ci/36526/19
#if SWIFT_PACKAGE && LEAKS && os(macOS)
final class LeaksTests: XCTestCase {
    func testForLeaks() {
        // Sets up an atexit handler that invokes the leaks tool.
        atexit {
            @discardableResult
            func leaksTo(_ file: String) -> Process {
                let out = FileHandle(forWritingAtPath: file)!
                defer {
                    if #available(OSX 10.15, *) {
                        try! out.close()
                    } else {
                        // Fallback on earlier versions
                    }
                }
                let process = Process()
                process.launchPath = "/usr/bin/leaks"
                process.arguments = ["\(getpid())"]
                process.standardOutput = out
                process.standardError = out
                process.launch()
                process.waitUntilExit()
                return process
            }
            let process = leaksTo("/dev/null")
            guard process.terminationReason == .exit && [0, 1].contains(process.terminationStatus) else {
                print("Weird, \(process.terminationReason): \(process.terminationStatus)")
                exit(255)
            }
            if process.terminationStatus == 1 {
                print("================")
                print("Oh no, we leaked")
                leaksTo("/dev/tty")
            }
            exit(process.terminationStatus)
        }
    }
}
#endif
