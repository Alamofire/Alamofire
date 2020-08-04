//
//  LeaksTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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
                print("Process terminated: \(process.terminationReason): \(process.terminationStatus)")
                exit(255)
            }
            if process.terminationStatus == 1 {
                print("================")
                print("Leaks Detected!!!")
                leaksTo("/dev/tty")
            }
            exit(process.terminationStatus)
        }
    }
}
#endif
