//
//  RequestModifierTests.swift
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

import Alamofire
import XCTest

final class RequestModifierTests: BaseTestCase {
    // MARK: - DataRequest

    func testThatRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let url = URL.makeHTTPBinURL(path: "delay/1")
        let expect = expectation(description: "request completed")
        var response: AFDataResponse<Data?>?

        // When
        AF.request(url) {
            $0.timeoutInterval = 0.01
        }
        .response { response = $0; expect.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }
}
