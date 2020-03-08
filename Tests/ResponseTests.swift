//
//  ResponseTests.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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
import Foundation
import XCTest

final class ResponseTestCase: BaseTestCase {
    func testThatResponseReturnsSuccessResultWithValidData() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with invalid hostname error")

        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

final class ResponseDataTestCase: BaseTestCase {
    func testThatResponseDataReturnsSuccessResultWithValidData() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseDataReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<Data, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

final class ResponseStringTestCase: BaseTestCase {
    func testThatResponseStringReturnsSuccessResultWithValidString() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

final class ResponseJSONTestCase: BaseTestCase {
    func testThatResponseJSONReturnsSuccessResultWithValidJSON() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<Any, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseJSONReturnsSuccessResultForGETRequest() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif

        if
            let responseDictionary = response?.result.success as? [String: Any],
            let args = responseDictionary["args"] as? [String: String] {
            XCTAssertEqual(args, ["foo": "bar"], "args should match parameters")
        } else {
            XCTFail("args should not be nil")
        }
    }

    func testThatResponseJSONReturnsSuccessResultForPOSTRequest() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any, AFError>?

        // When
        AF.request(urlString, method: .post, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif

        if
            let responseDictionary = response?.result.success as? [String: Any],
            let form = responseDictionary["form"] as? [String: String] {
            XCTAssertEqual(form, ["foo": "bar"], "form should match parameters")
        } else {
            XCTFail("form should not be nil")
        }
    }
}

final class ResponseJSONDecodableTestCase: BaseTestCase {
    func testThatResponseDecodableReturnsSuccessResultWithValidJSON() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        AF.request(urlString, parameters: [:]).responseDecodable(of: HTTPBinResponse.self) { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.success?.url, "https://httpbin.org/get")
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseDecodableWithPassedTypeReturnsSuccessResultWithValidJSON() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        AF.request(urlString, parameters: [:]).responseDecodable(of: HTTPBinResponse.self) {
            response = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.success?.url, "https://httpbin.org/get")
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatResponseStringReturnsFailureResultWithOptionalDataAndError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<HTTPBinResponse, AFError>?

        // When
        AF.request(urlString, parameters: [:]).responseDecodable(of: HTTPBinResponse.self) { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

final class ResponseMapTestCase: BaseTestCase {
    func testThatMapTransformsSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.map { json in
                // json["args"]["foo"] is "bar": use this invariant to test the map function
                ((json as? [String: Any])?["args"] as? [String: Any])?["foo"] as? String ?? "invalid"
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.success, "bar")
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.map { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

final class ResponseTryMapTestCase: BaseTestCase {
    func testThatTryMapTransformsSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String, Error>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response = resp.tryMap { json in
                // json["args"]["foo"] is "bar": use this invariant to test the tryMap function
                ((json as? [String: Any])?["args"] as? [String: Any])?["foo"] as? String ?? "invalid"
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertEqual(response?.result.success, "bar")
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatTryMapCatchesTransformationError() {
        // Given
        struct TransformError: Error {}

        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<String, Error>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.tryMap { _ in
                throw TransformError()
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if let error = response?.result.failure {
            XCTAssertTrue(error is TransformError)
        } else {
            XCTFail("tryMap should catch the transformation error")
        }

        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatTryMapPreservesFailureError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail with 404")

        var response: DataResponse<String, Error>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response = resp.tryMap { _ in "ignored" }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        XCTAssertEqual(response?.error?.asAFError?.isSessionTaskError, true)
        XCTAssertEqual(response?.error?.asAFError?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

enum TestError: Error {
    case error(error: AFError)
}

enum TransformationError: Error {
    case error

    func alwaysFails() throws -> TestError {
        throw TransformationError.error
    }
}

final class ResponseMapErrorTestCase: BaseTestCase {
    func testThatMapErrorTransformsFailureValue() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should not succeed")

        var response: DataResponse<Any, TestError>?

        // When
        AF.request(urlString).responseJSON { resp in
            response = resp.mapError { error in
                TestError.error(error: error)
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)
        guard let error = response?.error, case .error = error else { XCTFail(); return }

        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatMapErrorPreservesSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data, TestError>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.mapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}

// MARK: -

final class ResponseTryMapErrorTestCase: BaseTestCase {
    func testThatTryMapErrorPreservesSuccessValue() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Data, Error>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.tryMapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatTryMapErrorCatchesTransformationError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<Data, Error>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.tryMapError { _ in try TransformationError.error.alwaysFails() }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        if let error = response?.result.failure {
            XCTAssertTrue(error is TransformationError)
        } else {
            XCTFail("tryMapError should catch the transformation error")
        }

        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }

    func testThatTryMapErrorTransformsError() {
        // Given
        let urlString = "https://invalid-url-here.org/this/does/not/exist"
        let expectation = self.expectation(description: "request should fail")

        var response: DataResponse<Data, Error>?

        // When
        AF.request(urlString).responseData { resp in
            response = resp.tryMapError { TestError.error(error: $0) }
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertEqual(response?.result.isFailure, true)

        guard let error = response?.error as? TestError,
            case let .error(underlyingError) = error
        else { XCTFail(); return }

        XCTAssertEqual(underlyingError.asAFError?.isSessionTaskError, true)
        XCTAssertEqual(underlyingError.asAFError?.isHostURLError, true)
        
        #if !os(Linux)
        XCTAssertNotNil(response?.metrics)
        #endif
    }
}
