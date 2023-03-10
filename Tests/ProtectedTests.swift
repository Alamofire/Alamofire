//
//  ProtectedTests.swift
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

@testable
import Alamofire

import XCTest

final class ProtectedTests: BaseTestCase {
    func testThatProtectedValuesAreAccessedSafely() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.wrappedValue
            protected.wrappedValue = "\(i)"
        }

        // Then
        XCTAssertNotEqual(protected.wrappedValue, initialValue)
    }

    func testThatProtectedAPIIsSafe() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.read { $0 }
            protected.write { $0 = "\(i)" }
        }

        // Then
        XCTAssertNotEqual(protected.wrappedValue, initialValue)
    }
}

final class ProtectedWrapperTests: BaseTestCase {
    @Protected var value = "value"

    override func setUp() {
        super.setUp()

        value = "value"
    }

    func testThatWrappedValuesAreAccessedSafely() {
        // Given
        let initialValue = value

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = value
            value = "\(i)"
        }

        // Then
        XCTAssertNotEqual(value, initialValue)
    }

    func testThatProjectedAPIIsAccessedSafely() {
        // Given
        let initialValue = value

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = $value.read { $0 }
            $value.write { $0 = "\(i)" }
        }

        // Then
        XCTAssertNotEqual(value, initialValue)
    }

    func testThatDynamicMembersAreAccessedSafely() {
        // Given
        let count = Protected<Int>(0)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
            count.wrappedValue = value.count
        }

        // Then
        XCTAssertEqual(count.wrappedValue, 5)
    }

    func testThatDynamicMemberPropertiesAreAccessedSafely() {
        // Given
        let string = Protected<String>("test")
        let count = Protected<Int>(0)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
            count.wrappedValue = string.wrappedValue.count
        }

        // Then
        XCTAssertEqual(string.wrappedValue.count, count.wrappedValue)
    }

    func testThatLocalWrapperInstanceWorkCorrectly() {
        // Given
        @Protected var string = "test"
        @Protected var count = 0

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
            count = string.count
        }

        // Then
        XCTAssertEqual(string.count, count)
    }

    func testThatDynamicMembersAreSetSafely() {
        // Given
        struct Mutable { var value = "value" }
        let mutable = Protected<Mutable>(.init())

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            mutable.value = "\(i)"
        }

        // Then
        XCTAssertNotEqual(mutable.wrappedValue.value, "value")
    }
}

final class ProtectedHighContentionTests: BaseTestCase {
    final class StringContainer {
        var totalStrings: Int = 10
        var stringArray = ["this", "is", "a", "simple", "set", "of", "test", "strings", "to", "use"]
    }

    struct StringContainerWriteState {
        var results: [Int] = []
        var completedWrites = 0

        var queue1Complete = false
        var queue2Complete = false
    }

    struct StringContainerReadState {
        var results1: [Int] = []
        var results2: [Int] = []

        var queue1Complete = false
        var queue2Complete = false
    }

    // MARK: - Properties

    @Protected var stringContainer = StringContainer()
    @Protected var stringContainerWrite = StringContainerWriteState()
    @Protected var stringContainerRead = StringContainerReadState()

    func testConcurrentReadWriteBlocks() {
        // Given
        let totalWrites = 4000
        let totalReads = 10_000

        let writeExpectation = expectation(description: "all parallel writes should complete before timeout")
        let readExpectation = expectation(description: "all parallel reads should complete before timeout")

        var writerQueueResults: [Int] = []
        var completedWritesCount = 0

        var readerQueueResults1: [Int] = []
        var readerQueueResults2: [Int] = []

        // When
        executeWriteOperationsInParallel(totalOperationsToExecute: totalWrites) { results, completedOperationCount in
            writerQueueResults = results
            completedWritesCount = completedOperationCount
            writeExpectation.fulfill()
        }

        executeReadOperationsInParallel(totalOperationsToExecute: totalReads) { results1, results2 in
            readerQueueResults1 = results1
            readerQueueResults2 = results2
            readExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(readerQueueResults1.count, totalReads)
        XCTAssertEqual(readerQueueResults2.count, totalReads)
        XCTAssertEqual(writerQueueResults.count, totalWrites)
        XCTAssertEqual(completedWritesCount, totalWrites)

        readerQueueResults1.forEach { XCTAssertEqual($0, 10) }
        readerQueueResults2.forEach { XCTAssertEqual($0, 10) }
        writerQueueResults.forEach { XCTAssertEqual($0, 10) }
    }

    private func executeWriteOperationsInParallel(totalOperationsToExecute totalOperations: Int,
                                                  completion: @escaping ([Int], Int) -> Void) {
        let queue1 = DispatchQueue(label: "com.alamofire.testWriterQueue1")
        let queue2 = DispatchQueue(label: "com.alamofire.testWriterQueue2")

        for _ in 1...totalOperations {
            queue1.async {
                // Moves the last string element to the beginning of the string array
                let result: Int = self.$stringContainer.write { stringContainer in
                    let lastElement = stringContainer.stringArray.removeLast()
                    stringContainer.totalStrings = stringContainer.stringArray.count

                    stringContainer.stringArray.insert(lastElement, at: 0)
                    stringContainer.totalStrings = stringContainer.stringArray.count

                    return stringContainer.totalStrings
                }

                self.$stringContainerWrite.write { mutableState in
                    mutableState.results.append(result)

                    if mutableState.results.count == totalOperations {
                        mutableState.queue1Complete = true

                        if mutableState.queue2Complete {
                            completion(mutableState.results, mutableState.completedWrites)
                        }
                    }
                }
            }

            queue2.async {
                // Moves the first string element to the end of the string array
                self.$stringContainer.write { stringContainer in
                    let firstElement = stringContainer.stringArray.remove(at: 0)
                    stringContainer.totalStrings = stringContainer.stringArray.count

                    stringContainer.stringArray.append(firstElement)
                    stringContainer.totalStrings = stringContainer.stringArray.count
                }

                self.$stringContainerWrite.write { mutableState in
                    mutableState.completedWrites += 1

                    if mutableState.completedWrites == totalOperations {
                        mutableState.queue2Complete = true

                        if mutableState.queue1Complete {
                            completion(mutableState.results, mutableState.completedWrites)
                        }
                    }
                }
            }
        }
    }

    private func executeReadOperationsInParallel(totalOperationsToExecute totalOperations: Int,
                                                 completion: @escaping ([Int], [Int]) -> Void) {
        let queue1 = DispatchQueue(label: "com.alamofire.testReaderQueue1")
        let queue2 = DispatchQueue(label: "com.alamofire.testReaderQueue1")

        for _ in 1...totalOperations {
            queue1.async {
                // Reads the total string count in the string array
                // Using the wrapped value (no $) instead of the wrapper itself triggers the thread sanitizer.
                let result = self.$stringContainer.totalStrings

                self.$stringContainerRead.write {
                    $0.results1.append(result)

                    if $0.results1.count == totalOperations {
                        $0.queue1Complete = true

                        if $0.queue2Complete {
                            completion($0.results1, $0.results2)
                        }
                    }
                }
            }

            queue2.async {
                // Reads the total string count in the string array
                let result = self.$stringContainer.read { $0.totalStrings }

                self.$stringContainerRead.write {
                    $0.results2.append(result)

                    if $0.results2.count == totalOperations {
                        $0.queue2Complete = true

                        if $0.queue1Complete {
                            completion($0.results1, $0.results2)
                        }
                    }
                }
            }
        }
    }
}
