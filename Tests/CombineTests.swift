//
//  CombineTests.swift
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

#if canImport(Combine)

import Alamofire
import Combine
import XCTest

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
final class CombineTests: BaseTestCase {
    var storage: Set<AnyCancellable> = []

    override func tearDown() {
        storage = []

        super.tearDown()
    }

    func store(_ toStore: () -> AnyCancellable) {
        storage.insert(toStore())
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func testThatDataRequestCanBePublished() {
        // Given
        let responseReceived = expectation(description: "response should be received")
        let completionReceived = expectation(description: "stream should complete")
        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        store {
            AF.request(URLRequest.makeHTTPBinRequest())
                .responsePublisher(of: HTTPBinResponse.self)
                .sink(receiveCompletion: { _ in completionReceived.fulfill() },
                      receiveValue: { response = $0; responseReceived.fulfill() })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertTrue(response?.result.isSuccess == true)
    }
}

#endif
