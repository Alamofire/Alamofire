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
    @Test(arguments: subtractionCases)
    func subtractsCorrectly(_ c: SubtractionCase) {
        let result = c.lhs - c.rhs
        let expected = Instant(seconds: c.expectedSeconds, nanoseconds: c.expectedNanoseconds)
        #expect(result.seconds == c.expectedSeconds)
        #expect(result.nanoseconds == c.expectedNanoseconds)
        #expect(result.interval == expected.interval)
    }

    @Test
    func incrementsMonotonically() {
        let instants = [Instant(), Instant(), Instant(), Instant(), Instant()]
        let sortedInstants = instants.sorted { $0.interval <= $1.interval }

        #expect(instants == sortedInstants)
    }

    @Test(arguments: descriptionCases)
    func descriptionIsExact(_ c: DescriptionCase) {
        #expect(Instant(seconds: c.seconds, nanoseconds: c.nanoseconds).description == c.expected)
    }

    @Test
    func canComputeRealtimeDifference() {
        // Given: two incrementing instances.
        let start = Instant()
        let finish = Instant()

        // When: difference is calculated.
        let elapsed = finish - start

        // Difference is greater than 0.
        #expect(elapsed.nanoseconds > 0)
        #expect(elapsed.seconds == 0)
    }
}

extension InstantTests {
    struct SubtractionCase: CustomTestStringConvertible {
        let lhs: Instant
        let rhs: Instant
        let expectedSeconds: Int
        let expectedNanoseconds: Int
        let testDescription: String
    }

    static let subtractionCases: [SubtractionCase] = [
        // after - before, nanoseconds don't need borrow
        .init(lhs: Instant(seconds: 10, nanoseconds: 800_000_000),
              rhs: Instant(seconds: 3, nanoseconds: 200_000_000),
              expectedSeconds: 7,
              expectedNanoseconds: 600_000_000,
              testDescription: "after minus before, no borrow"),
        // after - before, nanoseconds need borrow
        .init(lhs: Instant(seconds: 10, nanoseconds: 200_000_000),
              rhs: Instant(seconds: 3, nanoseconds: 800_000_000),
              expectedSeconds: 6,
              expectedNanoseconds: 400_000_000,
              testDescription: "after minus before, with borrow"),
        // identical instants
        .init(lhs: Instant(seconds: 5, nanoseconds: 500_000_000),
              rhs: Instant(seconds: 5, nanoseconds: 500_000_000),
              expectedSeconds: 0,
              expectedNanoseconds: 0,
              testDescription: "identical instants yield zero"),
        // before - after, nanoseconds don't need borrow (negative result)
        .init(lhs: Instant(seconds: 3, nanoseconds: 800_000_000),
              rhs: Instant(seconds: 10, nanoseconds: 200_000_000),
              expectedSeconds: -7,
              expectedNanoseconds: 600_000_000,
              testDescription: "before minus after, no borrow"),
        // before - after, nanoseconds need borrow (negative result)
        .init(lhs: Instant(seconds: 3, nanoseconds: 200_000_000),
              rhs: Instant(seconds: 10, nanoseconds: 800_000_000),
              expectedSeconds: -8,
              expectedNanoseconds: 400_000_000,
              testDescription: "before minus after, with borrow"),
        // same seconds, nanoseconds differ only
        .init(lhs: Instant(seconds: 5, nanoseconds: 750_000_000),
              rhs: Instant(seconds: 5, nanoseconds: 250_000_000),
              expectedSeconds: 0,
              expectedNanoseconds: 500_000_000,
              testDescription: "nanoseconds only, same seconds"),
        // borrow across one-second boundary (lhs ns = 0)
        .init(lhs: Instant(seconds: 1, nanoseconds: 0),
              rhs: Instant(seconds: 0, nanoseconds: 500_000_000),
              expectedSeconds: 0,
              expectedNanoseconds: 500_000_000,
              testDescription: "borrow across one-second boundary"),
        // large second values with near-max nanoseconds
        .init(lhs: Instant(seconds: 100_000, nanoseconds: 999_999_999),
              rhs: Instant(seconds: 1, nanoseconds: 1),
              expectedSeconds: 99_999,
              expectedNanoseconds: 999_999_998,
              testDescription: "large second values"),
        // whole seconds only, no nanoseconds
        .init(lhs: Instant(seconds: 42, nanoseconds: 0),
              rhs: Instant(seconds: 7, nanoseconds: 0),
              expectedSeconds: 35,
              expectedNanoseconds: 0,
              testDescription: "whole seconds, zero nanoseconds"),
        // single nanosecond precision
        .init(lhs: Instant(seconds: 0, nanoseconds: 1),
              rhs: Instant(seconds: 0, nanoseconds: 0),
              expectedSeconds: 0,
              expectedNanoseconds: 1,
              testDescription: "single nanosecond positive"),
        // single nanosecond, negative (borrow from zero seconds)
        .init(lhs: Instant(seconds: 0, nanoseconds: 0),
              rhs: Instant(seconds: 0, nanoseconds: 1),
              expectedSeconds: -1,
              expectedNanoseconds: 999_999_999,
              testDescription: "single nanosecond negative"),
        // maximum nanoseconds
        .init(lhs: .init(seconds: 1, nanoseconds: 0),
              rhs: .init(seconds: 0, nanoseconds: 999_999_999),
              expectedSeconds: 0,
              expectedNanoseconds: 1,
              testDescription: "single nanosecond remaining")
    ]
}

extension InstantTests {
    struct DescriptionCase: CustomTestStringConvertible {
        let seconds: Int
        let nanoseconds: Int
        let expected: String
        let testDescription: String
    }

    static let descriptionCases: [DescriptionCase] = [
        // nanoseconds == 0 branch: zero seconds
        .init(seconds: 0, nanoseconds: 0, expected: "0.0",
              testDescription: "zero seconds and zero nanoseconds"),
        // nanoseconds == 0 branch: nonzero seconds
        .init(seconds: 5, nanoseconds: 0, expected: "5.0",
              testDescription: "nonzero seconds with zero nanoseconds"),
        // minimum nanoseconds — eight leading zeros
        .init(seconds: 0, nanoseconds: 1, expected: "0.000000001",
              testDescription: "minimum nanoseconds"),
        // existing: ones
        .init(seconds: 1, nanoseconds: 1, expected: "1.000000001",
              testDescription: "one second and one nanosecond"),
        // maximum nanoseconds — no leading zeros
        .init(seconds: 0, nanoseconds: 999_999_999, expected: "0.999999999",
              testDescription: "maximum nanoseconds"),
        // trailing zeros preserved in general format
        .init(seconds: 1, nanoseconds: 500_000_000, expected: "1.5",
              testDescription: "trailing zeros preserved"),
        // existing: large values, no leading or trailing zeros
        .init(seconds: 123_456_789, nanoseconds: 123_456_789, expected: "123456789.123456789",
              testDescription: "large seconds and nanoseconds")
    ]
}
