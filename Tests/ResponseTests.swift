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
import Testing

@Suite(.storesInstances)
struct ResponseTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseReturnsSuccessResultWithValidData() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseReturnsFailureResultWithOptionalDataAndError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with invalid URL error")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(urlString, parameters: ["foo": "bar"]).response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.error != nil)
        #expect(response.error?.isSessionTaskError == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct ResponseDataTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseDataReturnsSuccessResultWithValidData() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Data, AFError>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseData { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseDataReturnsFailureResultWithOptionalDataAndError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with invalid URL error")

        let response = Capture<DataResponse<Data, AFError>?>()

        // When
        session.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isSessionTaskError == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct ResponseStringTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseStringReturnsSuccessResultWithValidString() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<String, AFError>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseString { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseStringReturnsFailureResultWithOptionalDataAndError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with invalid URL error")

        let response = Capture<DataResponse<String, AFError>?>()

        // When
        session.request(urlString, parameters: ["foo": "bar"]).responseString { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isSessionTaskError == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct ResponseJSONTestCase {
    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseJSONReturnsSuccessResultWithValidJSON() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Any, AFError>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseJSON { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseStringReturnsFailureResultWithOptionalDataAndError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail")

        let response = Capture<DataResponse<Any, AFError>?>()

        // When
        session.request(urlString, parameters: ["foo": "bar"]).responseJSON { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isSessionTaskError == true)
        #expect(response.metrics != nil)
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseJSONReturnsSuccessResultForGETRequest() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Any, AFError>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseJSON { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)

        if
            let responseDictionary = response.result?.success as? [String: Any],
            let args = responseDictionary["args"] as? [String: String] {
            #expect(args == ["foo": "bar"], "args should match parameters")
        } else {
            Issue.record("args should not be nil")
        }
    }

    @Test
    @available(*, deprecated)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseJSONReturnsSuccessResultForPOSTRequest() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Any, AFError>?>()

        // When
        session.request(.method(.post), parameters: ["foo": "bar"]).responseJSON { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)

        if
            let responseDictionary = response.result?.success as? [String: Any],
            let form = responseDictionary["form"] as? [String: String] {
            #expect(form == ["foo": "bar"], "form should match parameters")
        } else {
            Issue.record("form should not be nil")
        }
    }
}

@Suite(.storesInstances)
struct ResponseJSONDecodableTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseDecodableReturnsSuccessResultWithValidJSON() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint().url
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(url, parameters: [:]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.result?.success?.url == url.absoluteString)
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseDecodableWithPassedTypeReturnsSuccessResultWithValidJSON() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint().url
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(url, parameters: [:]).responseDecodable(of: TestResponse.self) {
            response.value = $0
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.result?.success?.url == url.absoluteString)
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseStringReturnsFailureResultWithOptionalDataAndError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail")

        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(urlString, parameters: [:]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isSessionTaskError == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct ResponseMapTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapTransformsSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<String, AFError>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.map { response in
                response.args["foo"] ?? "invalid"
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.result?.success == "bar")
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapPreservesFailureError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with invalid URL error")

        let response = Capture<DataResponse<String, AFError>?>()

        // When
        session.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response.value = resp.map { _ in "ignored" }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.error?.isSessionTaskError == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct ResponseTryMapTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapTransformsSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<String, any Error>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.tryMap { response in
                response.args["foo"] ?? "invalid"
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.result?.success == "bar")
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapCatchesTransformationError() async {
        // Given
        let session = stored(Session.independent())
        struct TransformError: Error {}

        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<String, any Error>?>()

        // When
        session.request(.default, parameters: ["foo": "bar"]).responseData { resp in
            response.value = resp.tryMap { _ in
                throw TransformError()
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isFailure == true)

        if let error = response.result?.failure {
            #expect(error is TransformError)
        } else {
            Issue.record("tryMap should catch the transformation error")
        }

        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapPreservesFailureError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with invalid URL error")

        let response = Capture<DataResponse<String, any Error>?>()

        // When
        session.request(urlString, parameters: ["foo": "bar"]).responseData { resp in
            response.value = resp.tryMap { _ in "ignored" }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.error?.asAFError?.isSessionTaskError == true)
        #expect(response.metrics != nil)
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

@Suite(.storesInstances)
struct ResponseMapErrorTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapErrorTransformsFailureValue() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should not succeed")

        let response = Capture<DataResponse<TestResponse, TestError>?>()

        // When
        session.request(urlString).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.mapError { error in
                TestError.error(error: error)
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        guard let error = response.error, case .error = error else { Issue.record(); return }

        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapErrorPreservesSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Data, TestError>?>()

        // When
        session.request(.default).responseData { resp in
            response.value = resp.mapError { TestError.error(error: $0) }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct ResponseTryMapErrorTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapErrorPreservesSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<Data, any Error>?>()

        // When
        session.request(.default).responseData { resp in
            response.value = resp.tryMapError { TestError.error(error: $0) }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapErrorCatchesTransformationError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail")

        let response = Capture<DataResponse<Data, any Error>?>()

        // When
        session.request(urlString).responseData { resp in
            response.value = resp.tryMapError { _ in try TransformationError.error.alwaysFails() }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)

        if let error = response.result?.failure {
            #expect(error is TransformationError)
        } else {
            Issue.record("tryMapError should catch the transformation error")
        }

        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapErrorTransformsError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail")

        let response = Capture<DataResponse<Data, any Error>?>()

        // When
        session.request(urlString).responseData { resp in
            response.value = resp.tryMapError { TestError.error(error: $0) }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.data == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.metrics != nil)
    }
}
