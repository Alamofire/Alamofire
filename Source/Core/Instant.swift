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
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    #if canImport(Darwin) || canImport(Glibc)
    init() {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC_RAW, &time)
        value = Double(time.tv_sec) + (Double(time.tv_nsec) / 1_000_000_000)
    } // swiftformat:disable:next blankLinesBetweenScopes
    #elseif canImport(FoundationEssentials)
    init() {
        value = Date.now.timeIntervalSinceReferenceDate
    }
    #endif

    static func -(lhs: Instant, rhs: Instant) -> Double {
        lhs.value - rhs.value
    }
}

extension Instant: Hashable {}
extension Instant: CustomStringConvertible {
    var description: String {
        value.description
    }
}
