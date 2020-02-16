//
//  DataStreamTests.swift
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

final class DataStreamTests: BaseTestCase {
    func testThatDataCanBeStreamed() {
        // Given
        let expectedSize = 1000
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var sawError = false
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/\(expectedSize)")).responseStream { output in
            switch output {
            case let .value(data): accumulatedData.append(data)
            case .error: sawError = true
            case let .complete(_, resp, _):
                response = resp
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(accumulatedData.count, expectedSize)
        XCTAssertFalse(sawError)
    }

    func testThatDataCanBeStreamedManyTimes() {
        // Given
        let expectedSize = 1000
        var firstAccumulatedData = Data()
        var firstResponse: HTTPURLResponse?
        var firstSawError = false
        let firstExpectation = expectation(description: "first stream should complete")
        var secondAccumulatedData = Data()
        var secondResponse: HTTPURLResponse?
        var secondSawError = false
        let secondExpectation = expectation(description: "second stream should complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "bytes/\(expectedSize)"))
            .responseStream { output in
                switch output {
                case let .value(data): firstAccumulatedData.append(data)
                case .error: firstSawError = true
                case let .complete(_, resp, _):
                    firstResponse = resp
                    firstExpectation.fulfill()
                }
            }
            .responseStream { output in
                switch output {
                case let .value(data): secondAccumulatedData.append(data)
                case .error: secondSawError = true
                case let .complete(_, resp, _):
                    secondResponse = resp
                    secondExpectation.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(firstResponse?.statusCode, 200)
        XCTAssertEqual(firstAccumulatedData.count, expectedSize)
        XCTAssertFalse(firstSawError)
        XCTAssertEqual(secondResponse?.statusCode, 200)
        XCTAssertEqual(secondAccumulatedData.count, expectedSize)
        XCTAssertFalse(secondSawError)
    }

    func testThatDataStreamCanFailValidation() {
        // Given
        let request = URLRequest.makeHTTPBinRequest(path: "status/401")
        var dataSeen = false
        var sawError = false
        var error: AFError?
        let expect = expectation(description: "stream should complete")

        // When
        AF.streamRequest(request).validate().responseStream { output in
            switch output {
            case .value: dataSeen = true
            case .error: sawError = true
            case let .complete(_, _, err):
                error = err
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        NSLog(error?.localizedDescription ?? "No error description.")
        XCTAssertNotNil(error, "error should not be nil")
        XCTAssertTrue(error?.isResponseValidationError == true, "error should be response validation error")
        XCTAssertFalse(dataSeen, "no data should be seen")
        XCTAssertFalse(sawError, "no stream error should be seen")
    }

    func testThatDataStreamsCanBeRetried() {
        // Given
        final class GoodRetry: RequestInterceptor {
            var hasRetried = false

            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
                if hasRetried {
                    completion(.success(URLRequest.makeHTTPBinRequest(path: "bytes/1000")))
                } else {
                    completion(.success(urlRequest))
                }
            }

            func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
                hasRetried = true
                completion(.retry)
            }
        }
        let session = Session(interceptor: GoodRetry())
        var accumulatedData = Data()
        var response: HTTPURLResponse?
        var sawError = false
        let expect = expectation(description: "stream should complete")

        // When
        session.streamRequest(URLRequest.makeHTTPBinRequest(path: "status/401"))
            .validate()
            .responseStream { output in
                switch output {
                case let .value(data): accumulatedData.append(data)
                case .error: sawError = true
                case let .complete(_, resp, _):
                    response = resp
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(accumulatedData.count, 1000)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertFalse(sawError)
    }

    func testThatDataStreamsCanBeDecoded() {
        // Given
        // Only 1 right now, as multiple responses return invalid JSON from httpbin.org.
        let count = 1
        var responses: [HTTPBinResponse] = []
        var response: HTTPURLResponse?
        var sawError = false
        let expect = expectation(description: "stream complete")

        // When
        AF.streamRequest(URLRequest.makeHTTPBinRequest(path: "stream/\(count)"))
            .responseStreamDecodable(of: HTTPBinResponse.self) { output in
                switch output {
                case let .value(value):
                    responses.append(value)
                case .error:
                    sawError = true
                case let .complete(_, resp, _):
                    response = resp
                    expect.fulfill()
                }
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(responses.count, count)
        XCTAssertFalse(sawError)
        XCTAssertEqual(response?.statusCode, 200)
    }
}
