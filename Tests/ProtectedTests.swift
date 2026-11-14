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
import Foundation
import Testing

@Suite
struct ProtectedTests {
    @Test
    func protectedValuesAreAccessedSafely() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.read { $0 }
            protected.write("\(i)")
        }

        // Then
        #expect(protected.read { $0 } != initialValue)
    }

    @Test
    func protectedAPIIsSafe() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.read { $0 }
            protected.write("\(i)")
        }

        // Then
        #expect(protected.read { $0 } != initialValue)
    }
}

@Suite
struct ProtectedWrapperTests {
    let value = Protected("value")

    @Test
    func wrappedValuesAreAccessedSafely() {
        // Given
        let initialValue = value.read { $0 }

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = value.read { $0 }
            value.write("\(i)")
        }

        // Then
        #expect(value.read { $0 } != initialValue)
    }
}

@Suite(.storesInstances)
struct ProtectedHighContentionTests {
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

    let stringContainer = Protected(StringContainer())
    let stringContainerWrite = Protected(StringContainerWriteState())
    let stringContainerRead = Protected(StringContainerReadState())

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func concurrentReadWriteBlocks() async {
        // Given
        let totalWrites = 4000
        let totalReads = 10_000

        let writeExpectation = Completion("all parallel writes should complete before timeout")
        let readExpectation = Completion("all parallel reads should complete before timeout")

        let writerQueueResults = Capture<[Int]>([])
        let completedWritesCount = Capture(0)

        let readerQueueResults1 = Capture<[Int]>([])
        let readerQueueResults2 = Capture<[Int]>([])

        // When
        executeWriteOperationsInParallel(totalOperationsToExecute: totalWrites) { results, completedOperationCount in
            writerQueueResults.value = results
            completedWritesCount.value = completedOperationCount
            writeExpectation.complete()
        }

        executeReadOperationsInParallel(totalOperationsToExecute: totalReads) { results1, results2 in
            readerQueueResults1.value = results1
            readerQueueResults2.value = results2
            readExpectation.complete()
        }

        await wait(for: [writeExpectation, readExpectation])

        // Then
        #expect(readerQueueResults1.count == totalReads)
        #expect(readerQueueResults2.count == totalReads)
        #expect(writerQueueResults.count == totalWrites)
        #expect(completedWritesCount.value == totalWrites)

        readerQueueResults1.value.forEach { #expect($0 == 10) }
        readerQueueResults2.value.forEach { #expect($0 == 10) }
        writerQueueResults.value.forEach { #expect($0 == 10) }
    }

    private func executeWriteOperationsInParallel(totalOperationsToExecute totalOperations: Int,
                                                  completion: @escaping @Sendable ([Int], Int) -> Void) {
        let queue1 = DispatchQueue(label: "com.alamofire.testWriterQueue1")
        let queue2 = DispatchQueue(label: "com.alamofire.testWriterQueue2")

        for _ in 1...totalOperations {
            queue1.async {
                // Moves the last string element to the beginning of the string array
                let result: Int = stringContainer.write { stringContainer in
                    let lastElement = stringContainer.stringArray.removeLast()
                    stringContainer.totalStrings = stringContainer.stringArray.count

                    stringContainer.stringArray.insert(lastElement, at: 0)
                    stringContainer.totalStrings = stringContainer.stringArray.count

                    return stringContainer.totalStrings
                }

                stringContainerWrite.write { mutableState in
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
                stringContainer.write { stringContainer in
                    let firstElement = stringContainer.stringArray.remove(at: 0)
                    stringContainer.totalStrings = stringContainer.stringArray.count

                    stringContainer.stringArray.append(firstElement)
                    stringContainer.totalStrings = stringContainer.stringArray.count
                }

                stringContainerWrite.write { mutableState in
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
                                                 completion: @escaping @Sendable ([Int], [Int]) -> Void) {
        let queue1 = DispatchQueue(label: "com.alamofire.testReaderQueue1")
        let queue2 = DispatchQueue(label: "com.alamofire.testReaderQueue1")

        for _ in 1...totalOperations {
            queue1.async {
                let result = stringContainer.read(\.totalStrings)

                stringContainerRead.write {
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
                let result = stringContainer.read(\.totalStrings)

                stringContainerRead.write {
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
