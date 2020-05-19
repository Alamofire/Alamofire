//
//  RequestTests.swift
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

final class RequestResponseTestCase: BaseTestCase {
    func testRequestResponse() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "GET request should succeed: \(urlString)")
        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(urlString, parameters: ["foo": "bar"])
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func testRequestResponseWithProgress() {
        // Given
        let randomBytes = 1 * 25 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"

        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")

        var progressValues: [Double] = []
        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(urlString)
            .downloadProgress { progress in
                progressValues.append(progress.fractionCompleted)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        var previousProgress: Double = progressValues.first ?? 0.0

        for progress in progressValues {
            XCTAssertGreaterThanOrEqual(progress, previousProgress)
            previousProgress = progress
        }

        if let lastProgressValue = progressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in progressValues should not be nil")
        }
    }

    func testPOSTRequestWithUnicodeParameters() {
        // Given
        let urlString = "https://httpbin.org/post"
        let parameters = ["french": "français",
                          "japanese": "日本語",
                          "arabic": "العربية",
                          "emoji": "😃"]

        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any, AFError>?

        // When
        AF.request(urlString, method: .post, parameters: parameters)
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)

        if let json = response?.result.success as? [String: Any], let form = json["form"] as? [String: String] {
            XCTAssertEqual(form["french"], parameters["french"])
            XCTAssertEqual(form["japanese"], parameters["japanese"])
            XCTAssertEqual(form["arabic"], parameters["arabic"])
            XCTAssertEqual(form["emoji"], parameters["emoji"])
        } else {
            XCTFail("form parameter in JSON should not be nil")
        }
    }

    #if !SWIFT_PACKAGE
    func testPOSTRequestWithBase64EncodedImages() {
        // Given
        let urlString = "https://httpbin.org/post"

        let pngBase64EncodedString: String = {
            let URL = url(forResource: "unicorn", withExtension: "png")
            let data = try! Data(contentsOf: URL)

            return data.base64EncodedString(options: .lineLength64Characters)
        }()

        let jpegBase64EncodedString: String = {
            let URL = url(forResource: "rainbow", withExtension: "jpg")
            let data = try! Data(contentsOf: URL)

            return data.base64EncodedString(options: .lineLength64Characters)
        }()

        let parameters = ["email": "user@alamofire.org",
                          "png_image": pngBase64EncodedString,
                          "jpeg_image": jpegBase64EncodedString]

        let expectation = self.expectation(description: "request should succeed")

        var response: DataResponse<Any, AFError>?

        // When
        AF.request(urlString, method: .post, parameters: parameters)
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if let json = response?.result.success as? [String: Any], let form = json["form"] as? [String: String] {
            XCTAssertEqual(form["email"], parameters["email"])
            XCTAssertEqual(form["png_image"], parameters["png_image"])
            XCTAssertEqual(form["jpeg_image"], parameters["jpeg_image"])
        } else {
            XCTFail("form parameter in JSON should not be nil")
        }
    }
    #endif

    // MARK: Queues

    func testThatResponseSerializationWorksWithSerializationQueue() {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let manager = Session(serializationQueue: queue)
        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<Any, AFError>?

        // When
        manager.request("https://httpbin.org/get").responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatRequestsWorksWithRequestAndSerializationQueues() {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue")
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let manager = Session(requestQueue: requestQueue, serializationQueue: serializationQueue)
        let expectation = self.expectation(description: "request should complete")
        var response: DataResponse<Any, AFError>?

        // When
        manager.request("https://httpbin.org/get").responseJSON { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatRequestsWorksWithConcurrentRequestAndSerializationQueues() {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue", attributes: .concurrent)
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue", attributes: .concurrent)
        let session = Session(requestQueue: requestQueue, serializationQueue: serializationQueue)
        let count = 10
        let expectation = self.expectation(description: "request should complete")
        expectation.expectedFulfillmentCount = count
        var responses: [DataResponse<Any, AFError>] = []

        // When
        DispatchQueue.concurrentPerform(iterations: count) { _ in
            session.request("https://httpbin.org/get").responseJSON { resp in
                responses.append(resp)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(responses.count, count)
        XCTAssertTrue(responses.allSatisfy { $0.result.isSuccess })
    }

    // MARK: Encodable Parameters

    func testThatRequestsCanPassEncodableParametersAsJSONBodyData() {
        // Given
        let parameters = HTTPBinParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<HTTPBinResponse, AFError>?

        // When
        AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: HTTPBinResponse.self) { response in
                receivedResponse = response
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(receivedResponse?.result.success?.data, "{\"property\":\"one\"}")
    }

    func testThatRequestsCanPassEncodableParametersAsAURLQuery() {
        // Given
        let parameters = HTTPBinParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<HTTPBinResponse, AFError>?

        // When
        AF.request("https://httpbin.org/get", method: .get, parameters: parameters)
            .responseDecodable(of: HTTPBinResponse.self) { response in
                receivedResponse = response
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(receivedResponse?.result.success?.args, ["property": "one"])
    }

    func testThatRequestsCanPassEncodableParametersAsURLEncodedBodyData() {
        // Given
        let parameters = HTTPBinParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<HTTPBinResponse, AFError>?

        // When
        AF.request("https://httpbin.org/post", method: .post, parameters: parameters)
            .responseDecodable(of: HTTPBinResponse.self) { response in
                receivedResponse = response
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(receivedResponse?.result.success?.form, ["property": "one"])
    }

    // MARK: Lifetime Events

    func testThatAutomaticallyResumedRequestReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 4

        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidFinish = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest()).response { _ in expect.fulfill() }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatAutomaticallyAndManuallyResumedRequestReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 4

        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidFinish = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest()).response { _ in expect.fulfill() }
        for _ in 0..<100 {
            request.resume()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatManuallyResumedRequestReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 3

        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidFinish = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())
        for _ in 0..<100 {
            request.resume()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatRequestManuallyResumedManyTimesOnlyReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 4

        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidFinish = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest()).response { _ in expect.fulfill() }
        for _ in 0..<100 {
            request.resume()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatRequestManuallySuspendedManyTimesAfterAutomaticResumeOnlyReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 2

        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())
        for _ in 0..<100 {
            request.suspend()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .suspended)
    }

    func testThatRequestManuallySuspendedManyTimesOnlyReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 2

        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())
        for _ in 0..<100 {
            request.suspend()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .suspended)
    }

    func testThatRequestManuallyCancelledManyTimesAfterAutomaticResumeOnlyReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 2

        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())
        // Cancellation stops task creation, so don't cancel the request until the task has been created.
        eventMonitor.requestDidCreateTask = { [unowned request] _, _ in
            for _ in 0..<100 {
                request.cancel()
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }

    func testThatRequestManuallyCancelledManyTimesOnlyReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 2

        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())
        // Cancellation stops task creation, so don't cancel the request until the task has been created.
        eventMonitor.requestDidCreateTask = { [unowned request] _, _ in
            for _ in 0..<100 {
                request.cancel()
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }

    func testThatRequestManuallyCancelledManyTimesOnManyQueuesOnlyReceivesAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let expect = expectation(description: "request should receive appropriate lifetime events")
        expect.expectedFulfillmentCount = 6

        eventMonitor.requestDidCancelTask = { _, _ in expect.fulfill() }
        eventMonitor.requestDidCancel = { _ in expect.fulfill() }
        eventMonitor.requestDidResume = { _ in expect.fulfill() }
        eventMonitor.requestDidResumeTask = { _, _ in expect.fulfill() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.fulfill() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest(path: "delay/5")).response { _ in expect.fulfill() }
        // Cancellation stops task creation, so don't cancel the request until the task has been created.
        eventMonitor.requestDidCreateTask = { [unowned request] _, _ in
            DispatchQueue.concurrentPerform(iterations: 100) { i in
                request.cancel()

                if i == 99 { expect.fulfill() }
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }

    func testThatRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        let didReceiveChallenge = expectation(description: "didReceiveChallenge should fire")
        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didReceiveData = expectation(description: "didReceiveData should fire")
        let willCacheResponse = expectation(description: "willCacheResponse should fire")
        let didCreateURLRequest = expectation(description: "didCreateInitialURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didParseResponse = expectation(description: "didParseResponse should fire")
        let responseHandler = expectation(description: "responseHandler should fire")

        var dataReceived = false

        eventMonitor.taskDidReceiveChallenge = { _, _, _ in didReceiveChallenge.fulfill() }
        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.fulfill() }
        eventMonitor.dataTaskDidReceiveData = { _, _, _ in
            guard !dataReceived else { return }
            // Data may be received many times, fulfill only once.
            dataReceived = true
            didReceiveData.fulfill()
        }
        eventMonitor.dataTaskWillCacheResponse = { _, _, _ in willCacheResponse.fulfill() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.fulfill() }
        eventMonitor.requestDidFinish = { _ in didFinish.fulfill() }
        eventMonitor.requestDidResume = { _ in didResume.fulfill() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.fulfill() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest()).response { _ in
            responseHandler.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .finished)
    }

    func testThatCancelledRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(startRequestsImmediately: false, eventMonitors: [eventMonitor])

        let taskDidFinishCollecting = expectation(description: "taskDidFinishCollecting should fire")
        let didCreateURLRequest = expectation(description: "didCreateInitialURLRequest should fire")
        let didCreateTask = expectation(description: "didCreateTask should fire")
        let didGatherMetrics = expectation(description: "didGatherMetrics should fire")
        let didComplete = expectation(description: "didComplete should fire")
        let didFinish = expectation(description: "didFinish should fire")
        let didResume = expectation(description: "didResume should fire")
        let didResumeTask = expectation(description: "didResumeTask should fire")
        let didParseResponse = expectation(description: "didParseResponse should fire")
        let didCancel = expectation(description: "didCancel should fire")
        let didCancelTask = expectation(description: "didCancelTask should fire")
        let responseHandler = expectation(description: "responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.fulfill() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateURLRequest.fulfill() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.fulfill() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.fulfill() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.fulfill() }
        eventMonitor.requestDidFinish = { _ in didFinish.fulfill() }
        eventMonitor.requestDidResume = { _ in didResume.fulfill() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.fulfill() }
        eventMonitor.requestDidCancel = { _ in didCancel.fulfill() }
        eventMonitor.requestDidCancelTask = { _, _ in didCancelTask.fulfill() }

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest(path: "delay/5")).response { _ in
            responseHandler.fulfill()
        }

        eventMonitor.requestDidResumeTask = { [unowned request] _, _ in
            request.cancel()
            didResumeTask.fulfill()
        }

        request.resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }

    func testThatAppendingResponseSerializerToCancelledRequestCallsCompletion() {
        // Given
        let session = Session()

        var response1: DataResponse<Any, AFError>?
        var response2: DataResponse<Any, AFError>?

        let expect = expectation(description: "both response serializer completions should be called")
        expect.expectedFulfillmentCount = 2

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())

        request.responseJSON { resp in
            response1 = resp
            expect.fulfill()

            request.responseJSON { resp in
                response2 = resp
                expect.fulfill()
            }
        }

        request.cancel()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response1?.error?.isExplicitlyCancelledError, true)
        XCTAssertEqual(response2?.error?.isExplicitlyCancelledError, true)
    }

    func testThatAppendingResponseSerializerToCompletedRequestInsideCompletionResumesRequest() {
        // Given
        let session = Session()

        var response1: DataResponse<Any, AFError>?
        var response2: DataResponse<Any, AFError>?
        var response3: DataResponse<Any, AFError>?

        let expect = expectation(description: "all response serializer completions should be called")
        expect.expectedFulfillmentCount = 3

        // When
        let request = session.request(URLRequest.makeHTTPBinRequest())

        request.responseJSON { resp in
            response1 = resp
            expect.fulfill()

            request.responseJSON { resp in
                response2 = resp
                expect.fulfill()

                request.responseJSON { resp in
                    response3 = resp
                    expect.fulfill()
                }
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response1?.value)
        XCTAssertNotNil(response2?.value)
        XCTAssertNotNil(response3?.value)
    }

    func testThatAppendingResponseSerializerToCompletedRequestOutsideCompletionResumesRequest() {
        // Given
        let session = Session()
        let request = session.request(URLRequest.makeHTTPBinRequest())

        var response1: DataResponse<Any, AFError>?
        var response2: DataResponse<Any, AFError>?
        var response3: DataResponse<Any, AFError>?

        // When
        let expect1 = expectation(description: "response serializer 1 completion should be called")
        request.responseJSON { response1 = $0; expect1.fulfill() }
        waitForExpectations(timeout: timeout, handler: nil)

        let expect2 = expectation(description: "response serializer 2 completion should be called")
        request.responseJSON { response2 = $0; expect2.fulfill() }
        waitForExpectations(timeout: timeout, handler: nil)

        let expect3 = expectation(description: "response serializer 3 completion should be called")
        request.responseJSON { response3 = $0; expect3.fulfill() }
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response1?.value)
        XCTAssertNotNil(response2?.value)
        XCTAssertNotNil(response3?.value)
    }
}

// MARK: -

class RequestDescriptionTestCase: BaseTestCase {
    func testRequestDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let manager = Session(startRequestsImmediately: false)
        let request = manager.request(urlString)

        let expectation = self.expectation(description: "Request description should update: \(urlString)")

        var response: HTTPURLResponse?

        // When
        request.response { resp in
            response = resp.response

            expectation.fulfill()
        }.resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request.description, "GET https://httpbin.org/get (\(response?.statusCode ?? -1))")
    }
}

// MARK: -

final class RequestCURLDescriptionTestCase: BaseTestCase {
    // MARK: Properties

    let manager: Session = {
        let manager = Session()

        return manager
    }()

    let managerWithAcceptLanguageHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Accept-Language"] = "en-US"

        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers

        let manager = Session(configuration: configuration)

        return manager
    }()

    let managerWithContentTypeHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Content-Type"] = "application/json"

        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers

        let manager = Session(configuration: configuration)

        return manager
    }()

    func managerWithCookie(_ cookie: HTTPCookie) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpCookieStorage?.setCookie(cookie)

        return Session(configuration: configuration)
    }

    let managerDisallowingCookies: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = false

        let manager = Session(configuration: configuration)

        return manager
    }()

    // MARK: Tests

    func testGETRequestCURLDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")
        var components: [String]?

        // When
        manager.request(urlString).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(urlString)\"")
    }

    func testGETRequestCURLDescriptionSynchronous() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")
        var components: [String]?
        var syncComponents: [String]?

        // When
        let request = manager.request(urlString)
        request.cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            syncComponents = self.cURLCommandComponents(from: request.cURLDescription())
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(urlString)\"")
        XCTAssertEqual(components?.sorted(), syncComponents?.sorted())
    }

    func testGETRequestCURLDescriptionCanBeRequestedManyTimes() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")
        var components: [String]?
        var secondComponents: [String]?

        // When
        let request = manager.request(urlString)
        request.cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            request.cURLDescription {
                secondComponents = self.cURLCommandComponents(from: $0)
                expectation.fulfill()
            }
        }
        // Trigger the overwrite behavior.
        request.cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            request.cURLDescription {
                secondComponents = self.cURLCommandComponents(from: $0)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(urlString)\"")
        XCTAssertEqual(components?.sorted(), secondComponents?.sorted())
    }

    func testGETRequestWithCustomHeaderCURLDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")
        var cURLDescription: String?

        // When
        let headers: HTTPHeaders = ["X-Custom-Header": "{\"key\": \"value\"}"]
        manager.request(urlString, headers: headers).cURLDescription {
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(cURLDescription?.range(of: "-H \"X-Custom-Header: {\\\"key\\\": \\\"value\\\"}\""))
    }

    func testGETRequestWithDuplicateHeadersDebugDescription() {
        // Given
        let urlString = "https://httpbin.org/get"
        let expectation = self.expectation(description: "request should complete")
        var cURLDescription: String?
        var components: [String]?

        // When
        let headers: HTTPHeaders = ["Accept-Language": "en-GB"]
        managerWithAcceptLanguageHeader.request(urlString, headers: headers).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(urlString)\"")

        let acceptLanguageCount = components?.filter { $0.contains("Accept-Language") }.count
        XCTAssertEqual(acceptLanguageCount, 1, "command should contain a single Accept-Language header")

        XCTAssertNotNil(cURLDescription?.range(of: "-H \"Accept-Language: en-GB\""))
    }

    func testPOSTRequestCURLDescription() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "request should complete")
        var components: [String]?

        // When
        manager.request(urlString, method: .post).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components?[3..<5], ["-X", "POST"])
        XCTAssertEqual(components?.last, "\"\(urlString)\"")
    }

    func testPOSTRequestWithJSONParametersCURLDescription() {
        // Given
        let urlString = "https://httpbin.org/post"
        let expectation = self.expectation(description: "request should complete")
        var cURLDescription: String?
        var components: [String]?

        let parameters = ["foo": "bar",
                          "fo\"o": "b\"ar",
                          "f'oo": "ba'r"]

        // When
        manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components?[3..<5], ["-X", "POST"])

        XCTAssertNotNil(cURLDescription?.range(of: "-H \"Content-Type: application/json\""))
        XCTAssertNotNil(cURLDescription?.range(of: "-d \"{"))
        XCTAssertNotNil(cURLDescription?.range(of: "\\\"f'oo\\\":\\\"ba'r\\\""))
        XCTAssertNotNil(cURLDescription?.range(of: "\\\"fo\\\\\\\"o\\\":\\\"b\\\\\\\"ar\\\""))
        XCTAssertNotNil(cURLDescription?.range(of: "\\\"foo\\\":\\\"bar\\"))

        XCTAssertEqual(components?.last, "\"\(urlString)\"")
    }

    func testPOSTRequestWithCookieCURLDescription() {
        // Given
        let urlString = "https://httpbin.org/post"

        let properties = [HTTPCookiePropertyKey.domain: "httpbin.org",
                          HTTPCookiePropertyKey.path: "/post",
                          HTTPCookiePropertyKey.name: "foo",
                          HTTPCookiePropertyKey.value: "bar"]

        let cookie = HTTPCookie(properties: properties)!
        let cookieManager = managerWithCookie(cookie)
        let expectation = self.expectation(description: "request should complete")
        var components: [String]?

        // When
        cookieManager.request(urlString, method: .post).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components?[3..<5], ["-X", "POST"])
        XCTAssertEqual(components?.last, "\"\(urlString)\"")
        XCTAssertEqual(components?[5..<6], ["-b"])
    }

    func testPOSTRequestWithCookiesDisabledCURLDescriptionHasNoCookies() {
        // Given
        let urlString = "https://httpbin.org/post"

        let properties = [HTTPCookiePropertyKey.domain: "httpbin.org",
                          HTTPCookiePropertyKey.path: "/post",
                          HTTPCookiePropertyKey.name: "foo",
                          HTTPCookiePropertyKey.value: "bar"]

        let cookie = HTTPCookie(properties: properties)!
        managerDisallowingCookies.session.configuration.httpCookieStorage?.setCookie(cookie)
        let expectation = self.expectation(description: "request should complete")
        var components: [String]?

        // When
        managerDisallowingCookies.request(urlString, method: .post).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        let cookieComponents = components?.filter { $0 == "-b" }
        XCTAssertTrue(cookieComponents?.isEmpty == true)
    }

    func testMultipartFormDataRequestWithDuplicateHeadersCURLDescriptionHasOneContentTypeHeader() {
        // Given
        let urlString = "https://httpbin.org/post"
        let japaneseData = Data("日本語".utf8)
        let expectation = self.expectation(description: "multipart form data encoding should succeed")
        var cURLDescription: String?
        var components: [String]?

        // When
        managerWithContentTypeHeader.upload(multipartFormData: { data in
            data.append(japaneseData, withName: "japanese")
        }, to: urlString).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(urlString)\"")

        let contentTypeCount = components?.filter { $0.contains("Content-Type") }.count
        XCTAssertEqual(contentTypeCount, 1, "command should contain a single Content-Type header")

        XCTAssertNotNil(cURLDescription?.range(of: "-H \"Content-Type: multipart/form-data;"))
    }

    func testThatRequestWithInvalidURLDebugDescription() {
        // Given
        let urlString = "invalid_url"
        let expectation = self.expectation(description: "request should complete")
        var cURLDescription: String?

        // When
        manager.request(urlString).cURLDescription {
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(cURLDescription, "debugDescription should not crash")
    }

    // MARK: Test Helper Methods

    private func cURLCommandComponents(from cURLString: String) -> [String] {
        cURLString.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0 != "" && $0 != "\\" }
    }
}
