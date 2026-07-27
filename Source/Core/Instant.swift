//
//  Instant.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(FoundationEssentials)
// Platforms that don't have clock_gettime.
import FoundationEssentials
#endif

struct Instant {
    let seconds: Int
    let nanoseconds: Int

    var interval: Double {
        Double(seconds) + Double(nanoseconds) / 1_000_000_000
    }

    /// TESTING ONLY!
    init(seconds: Int, nanoseconds: Int) {
        self.seconds = seconds
        self.nanoseconds = nanoseconds
    }

    #if canImport(Darwin) || canImport(Glibc)
    init() {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC_RAW, &time)
        seconds = time.tv_sec
        nanoseconds = time.tv_nsec
    } // swiftformat:disable:next blankLinesBetweenScopes
    #elseif canImport(FoundationEssentials)
    init() {
        let interval = Date.now.timeIntervalSinceReferenceDate
        seconds = interval.rounded(.towardZero)
        nanoseconds = modf(interval).1
    }
    #endif

    static func -(lhs: Self, rhs: Self) -> Self {
        var seconds = lhs.seconds - rhs.seconds
        var nanoseconds = lhs.nanoseconds - rhs.nanoseconds
        if nanoseconds < 0 {
            seconds -= 1
            nanoseconds += 1_000_000_000
        }
        return Self(seconds: seconds, nanoseconds: nanoseconds)
    }
}

extension Instant: Equatable {}

extension Instant: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(seconds)
        hasher.combine(nanoseconds)
    }
}

extension Instant: CustomStringConvertible {
    var description: String {
        // String(format:) would be simpler, but this is 10x faster, for fun.
        var nanos = nanoseconds
        var trailing = 0
        while trailing < 8 && nanos % 10 == 0 {
            nanos /= 10
            trailing += 1
        }
        let digits = String(nanos)
        let padding = String(repeating: "0", count: 9 - trailing - digits.count)
        return "\(seconds).\(padding)\(digits)"
    }
}
