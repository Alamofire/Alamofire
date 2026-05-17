//
//  InstantTests.swift
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

@testable import Alamofire
import Testing

@Suite
struct InstantTests {
    @Test
    func incrementsMonotonically() {
        let instants = [Instant(), Instant(), Instant(), Instant(), Instant()]
        let sortedInstants = instants.sorted { $0.value < $1.value }

        #expect(instants == sortedInstants)
    }

    @Test
    func canComputeRealtimeDifference() {
        // Given: two incrementing instances.
        let start = Instant()
        let finish = Instant()

        // When: difference is calculated.
        let elapsed = finish - start

        // Difference is greater than 0.
        #expect(elapsed > 0)
    }

    @Test
    func canComputeManualDifference() {
        // Given: two incrementing instances.
        let start = Instant(1)
        let finish = Instant(2)

        // When: difference is calculated.
        let elapsed = finish - start

        // Difference is exactly 1.
        #expect(elapsed == 1)
    }
}
