//
//  RequestTests.swift
//
//  Copyright (c) 2014-2020 Alamofire Software Foundation (http://alamofire.org/)
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
        let url = Endpoint.get.url
        let expectation = expectation(description: "GET request should succeed: \(url)")
        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(url, parameters: ["foo": "bar"])
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func testRequestResponseWithProgress() {
        // Given
        let byteCount = 50 * 1024
        let url = Endpoint.bytes(byteCount).url

        let expectation = expectation(description: "Bytes download progress should be reported: \(url)")

        var progressValues: [Double] = []
        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(url)
            .downloadProgress { progress in
                progressValues.append(progress.fractionCompleted)
            }
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

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
        let parameters = ["french": "français",
                          "japanese": "日本語",
                          "arabic": "العربية",
                          "emoji": "😃"]

        let expectation = expectation(description: "request should succeed")

        var response: DataResponse<TestResponse, AFError>?

        // When
        AF.request(.method(.post), parameters: parameters)
            .responseDecodable(of: TestResponse.self) { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)

        if let form = response?.result.success?.form {
            XCTAssertEqual(form["french"], parameters["french"])
            XCTAssertEqual(form["japanese"], parameters["japanese"])
            XCTAssertEqual(form["arabic"], parameters["arabic"])
            XCTAssertEqual(form["emoji"], parameters["emoji"])
        } else {
            XCTFail("form parameter in JSON should not be nil")
        }
    }

    func testPOSTRequestWithBase64EncodedImages() {
        // Given
        let pngBase64EncodedString: String = {
            let fileURL = url(forResource: "unicorn", withExtension: "png")
            let data = try! Data(contentsOf: fileURL)

            return data.base64EncodedString(options: .lineLength64Characters)
        }()

        let jpegBase64EncodedString: String = {
            let fileURL = url(forResource: "rainbow", withExtension: "jpg")
            let data = try! Data(contentsOf: fileURL)

            return data.base64EncodedString(options: .lineLength64Characters)
        }()

        let parameters = ["email": "user@alamofire.org",
                          "png_image": pngBase64EncodedString,
                          "jpeg_image": jpegBase64EncodedString]

        let expectation = expectation(description: "request should succeed")

        var response: DataResponse<TestResponse, AFError>?

        // When
        AF.request(Endpoint.method(.post), method: .post, parameters: parameters)
            .responseDecodable(of: TestResponse.self) { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if let form = response?.result.success?.form {
            XCTAssertEqual(form["email"], parameters["email"])
            XCTAssertEqual(form["png_image"], parameters["png_image"])
            XCTAssertEqual(form["jpeg_image"], parameters["jpeg_image"])
        } else {
            XCTFail("form parameter in JSON should not be nil")
        }
    }

    // MARK: Queues

    func testThatResponseSerializationWorksWithSerializationQueue() {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let manager = Session(serializationQueue: queue)
        let expectation = expectation(description: "request should complete")
        var response: DataResponse<TestResponse, AFError>?

        // When
        manager.request(.get).responseDecodable(of: TestResponse.self) { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatRequestsWorksWithRequestAndSerializationQueues() {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue")
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let manager = Session(requestQueue: requestQueue, serializationQueue: serializationQueue)
        let expectation = expectation(description: "request should complete")
        var response: DataResponse<TestResponse, AFError>?

        // When
        manager.request(.get).responseDecodable(of: TestResponse.self) { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatRequestsWorksWithConcurrentRequestAndSerializationQueues() {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue", attributes: .concurrent)
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue", attributes: .concurrent)
        let session = Session(requestQueue: requestQueue, serializationQueue: serializationQueue)
        let count = 10
        let expectation = expectation(description: "request should complete")
        expectation.expectedFulfillmentCount = count
        var responses: [DataResponse<TestResponse, AFError>] = []

        // When
        DispatchQueue.concurrentPerform(iterations: count) { _ in
            session.request(.default).responseDecodable(of: TestResponse.self) { resp in
                responses.append(resp)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(responses.count, count)
        XCTAssertTrue(responses.allSatisfy(\.result.isSuccess))
    }

    // MARK: Encodable Parameters

    func testThatRequestsCanPassEncodableParametersAsJSONBodyData() {
        // Given
        let parameters = TestParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<TestResponse, AFError>?

        // When
        AF.request(.method(.post), parameters: parameters, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: TestResponse.self) { response in
                receivedResponse = response
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(receivedResponse?.result.success?.data, "{\"property\":\"one\"}")
    }

    func testThatRequestsCanPassEncodableParametersAsAURLQuery() {
        // Given
        let parameters = TestParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<TestResponse, AFError>?

        // When
        AF.request(.method(.get), parameters: parameters)
            .responseDecodable(of: TestResponse.self) { response in
                receivedResponse = response
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(receivedResponse?.result.success?.args, ["property": "one"])
    }

    func testThatRequestsCanPassEncodableParametersAsURLEncodedBodyData() {
        // Given
        let parameters = TestParameters(property: "one")
        let expect = expectation(description: "request should complete")
        var receivedResponse: DataResponse<TestResponse, AFError>?

        // When
        AF.request(.method(.post), parameters: parameters)
            .responseDecodable(of: TestResponse.self) { response in
                receivedResponse = response
                expect.fulfill()
            }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default).response { _ in expect.fulfill() }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default).response { _ in expect.fulfill() }
        for _ in 0..<100 {
            request.resume()
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default)
        for _ in 0..<100 {
            request.resume()
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default).response { _ in expect.fulfill() }
        for _ in 0..<100 {
            request.resume()
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default)
        for _ in 0..<100 {
            request.suspend()
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default)
        for _ in 0..<100 {
            request.suspend()
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default)
        // Cancellation stops task creation, so don't cancel the request until the task has been created.
        eventMonitor.requestDidCreateTask = { [unowned request] _, _ in
            for _ in 0..<100 {
                request.cancel()
            }
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.default)
        // Cancellation stops task creation, so don't cancel the request until the task has been created.
        eventMonitor.requestDidCreateTask = { [unowned request] _, _ in
            for _ in 0..<100 {
                request.cancel()
            }
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.delay(5)).response { _ in expect.fulfill() }
        // Cancellation stops task creation, so don't cancel the request until the task has been created.
        eventMonitor.requestDidCreateTask = { [unowned request] _, _ in
            DispatchQueue.concurrentPerform(iterations: 100) { i in
                request.cancel()

                if i == 99 { expect.fulfill() }
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }

    func testThatRequestTriggersAllAppropriateLifetimeEvents() {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = Session(eventMonitors: [eventMonitor])

        // Disable event test until Firewalk support HTTPS.
        //  let didReceiveChallenge = expectation(description: "didReceiveChallenge should fire")
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

        // Disable event test until Firewalk supports HTTPS.
        //  eventMonitor.taskDidReceiveChallenge = { _, _, _ in didReceiveChallenge.fulfill() }
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
        let request = session.request(.default).response { _ in
            responseHandler.fulfill()
        }

        waitForExpectations(timeout: timeout)

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
        let request = session.request(.delay(5)).response { _ in
            responseHandler.fulfill()
        }

        eventMonitor.requestDidResumeTask = { [unowned request] _, _ in
            request.cancel()
            didResumeTask.fulfill()
        }

        request.resume()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request.state, .cancelled)
    }

    func testThatAppendingResponseSerializerToCancelledRequestCallsCompletion() {
        // Given
        let session = Session()

        var response1: DataResponse<TestResponse, AFError>?
        var response2: DataResponse<TestResponse, AFError>?

        let expect = expectation(description: "both response serializer completions should be called")
        expect.expectedFulfillmentCount = 2

        // When
        let request = session.request(.default)

        request.responseDecodable(of: TestResponse.self) { resp in
            response1 = resp
            expect.fulfill()

            request.responseDecodable(of: TestResponse.self) { resp in
                response2 = resp
                expect.fulfill()
            }
        }

        request.cancel()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response1?.error?.isExplicitlyCancelledError, true)
        XCTAssertEqual(response2?.error?.isExplicitlyCancelledError, true)
    }

    func testThatAppendingResponseSerializerToCompletedRequestInsideCompletionResumesRequest() {
        // Given
        let session = Session()

        var response1: DataResponse<TestResponse, AFError>?
        var response2: DataResponse<TestResponse, AFError>?
        var response3: DataResponse<TestResponse, AFError>?

        let expect = expectation(description: "all response serializer completions should be called")
        expect.expectedFulfillmentCount = 3

        // When
        let request = session.request(.default)

        request.responseDecodable(of: TestResponse.self) { resp in
            response1 = resp
            expect.fulfill()

            request.responseDecodable(of: TestResponse.self) { resp in
                response2 = resp
                expect.fulfill()

                request.responseDecodable(of: TestResponse.self) { resp in
                    response3 = resp
                    expect.fulfill()
                }
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response1?.value)
        XCTAssertNotNil(response2?.value)
        XCTAssertNotNil(response3?.value)
    }

    func testThatAppendingResponseSerializerToCompletedRequestOutsideCompletionResumesRequest() {
        // Given
        let session = Session()
        let request = session.request(.default)

        var response1: DataResponse<TestResponse, AFError>?
        var response2: DataResponse<TestResponse, AFError>?
        var response3: DataResponse<TestResponse, AFError>?

        // When
        let expect1 = expectation(description: "response serializer 1 completion should be called")
        request.responseDecodable(of: TestResponse.self) { response1 = $0; expect1.fulfill() }
        waitForExpectations(timeout: timeout)

        let expect2 = expectation(description: "response serializer 2 completion should be called")
        request.responseDecodable(of: TestResponse.self) { response2 = $0; expect2.fulfill() }
        waitForExpectations(timeout: timeout)

        let expect3 = expectation(description: "response serializer 3 completion should be called")
        request.responseDecodable(of: TestResponse.self) { response3 = $0; expect3.fulfill() }
        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response1?.value)
        XCTAssertNotNil(response2?.value)
        XCTAssertNotNil(response3?.value)
    }
}

// MARK: -

final class RequestDescriptionTestCase: BaseTestCase {
    func testRequestDescription() {
        // Given
        let url = Endpoint().url
        let manager = Session(startRequestsImmediately: false)
        let request = manager.request(url)

        let expectation = expectation(description: "Request description should update: \(url)")

        var response: HTTPURLResponse?

        // When
        request.response { resp in
            response = resp.response

            expectation.fulfill()
        }.resume()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(request.description, "GET \(url) (\(response?.statusCode ?? -1))")
    }
}

// MARK: -

final class RequestCURLDescriptionTestCase: BaseTestCase {
    // MARK: Properties

    let session: Session = {
        let manager = Session()

        return manager
    }()

    let sessionWithAcceptLanguageHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Accept-Language"] = "en-US"

        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers

        let manager = Session(configuration: configuration)

        return manager
    }()

    let sessionWithContentTypeHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Content-Type"] = "application/json"

        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers

        let manager = Session(configuration: configuration)

        return manager
    }()

    func sessionWithCookie(_ cookie: HTTPCookie) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpCookieStorage?.setCookie(cookie)

        return Session(configuration: configuration)
    }

    let sessionDisallowingCookies: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = false

        let manager = Session(configuration: configuration)

        return manager
    }()

    // MARK: Tests

    func testGETRequestCURLDescription() {
        // Given
        let url = Endpoint().url
        let expectation = expectation(description: "request should complete")
        var components: [String]?

        // When
        session.request(url).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(url)\"")
    }

    func testGETRequestCURLDescriptionOnMainQueue() {
        // Given
        let url = Endpoint().url
        let expectation = expectation(description: "request should complete")
        var isMainThread = false
        var components: [String]?

        // When
        session.request(url).cURLDescription(on: .main) {
            components = self.cURLCommandComponents(from: $0)
            isMainThread = Thread.isMainThread
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(isMainThread)
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(url)\"")
    }

    func testGETRequestCURLDescriptionSynchronous() {
        // Given
        let url = Endpoint().url
        let expectation = expectation(description: "request should complete")
        var components: [String]?
        var syncComponents: [String]?

        // When
        let request = session.request(url)
        request.cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            syncComponents = self.cURLCommandComponents(from: request.cURLDescription())
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(url)\"")
        XCTAssertEqual(components?.sorted(), syncComponents?.sorted())
    }

    func testGETRequestCURLDescriptionCanBeRequestedManyTimes() {
        // Given
        let url = Endpoint().url
        let expectation = expectation(description: "request should complete")
        var components: [String]?
        var secondComponents: [String]?

        // When
        let request = session.request(url)
        request.cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            request.cURLDescription {
                secondComponents = self.cURLCommandComponents(from: $0)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(url)\"")
        XCTAssertEqual(components?.sorted(), secondComponents?.sorted())
    }

    func testGETRequestWithCustomHeaderCURLDescription() {
        // Given
        let url = Endpoint().url
        let expectation = expectation(description: "request should complete")
        var cURLDescription: String?

        // When
        let headers: HTTPHeaders = ["X-Custom-Header": "{\"key\": \"value\"}"]
        session.request(url, headers: headers).cURLDescription {
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(cURLDescription?.range(of: "-H \"X-Custom-Header: {\\\"key\\\": \\\"value\\\"}\""))
    }

    func testGETRequestWithDuplicateHeadersDebugDescription() {
        // Given
        let url = Endpoint().url
        let expectation = expectation(description: "request should complete")
        var cURLDescription: String?
        var components: [String]?

        // When
        let headers: HTTPHeaders = ["Accept-Language": "en-GB"]
        sessionWithAcceptLanguageHeader.request(url, headers: headers).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(url)\"")

        let acceptLanguageCount = components?.filter { $0.contains("Accept-Language") }.count
        XCTAssertEqual(acceptLanguageCount, 1, "command should contain a single Accept-Language header")

        XCTAssertNotNil(cURLDescription?.range(of: "-H \"Accept-Language: en-GB\""))
    }

    func testPOSTRequestCURLDescription() {
        // Given
        let url = Endpoint.method(.post).url
        let expectation = expectation(description: "request should complete")
        var components: [String]?

        // When
        session.request(url, method: .post).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components?[3..<5], ["-X", "POST"])
        XCTAssertEqual(components?.last, "\"\(url)\"")
    }

    func testPOSTRequestWithJSONParametersCURLDescription() {
        // Given
        let url = Endpoint.method(.post).url
        let expectation = expectation(description: "request should complete")
        var cURLDescription: String?
        var components: [String]?

        let parameters = ["foo": "bar",
                          "fo\"o": "b\"ar",
                          "f'oo": "ba'r"]

        // When
        session.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components?[3..<5], ["-X", "POST"])

        XCTAssertNotNil(cURLDescription?.range(of: "-H \"Content-Type: application/json\""))
        XCTAssertNotNil(cURLDescription?.range(of: "-d \"{"))
        XCTAssertNotNil(cURLDescription?.range(of: "\\\"f'oo\\\":\\\"ba'r\\\""))
        XCTAssertNotNil(cURLDescription?.range(of: "\\\"fo\\\\\\\"o\\\":\\\"b\\\\\\\"ar\\\""))
        XCTAssertNotNil(cURLDescription?.range(of: "\\\"foo\\\":\\\"bar\\"))

        XCTAssertEqual(components?.last, "\"\(url)\"")
    }

    func testPOSTRequestWithCookieCURLDescription() {
        // Given
        let url = Endpoint.method(.post).url

        let cookie = HTTPCookie(properties: [.domain: url.host as Any,
                                             .path: url.path,
                                             .name: "foo",
                                             .value: "bar"])!
        let cookieManager = sessionWithCookie(cookie)
        let expectation = expectation(description: "request should complete")
        var components: [String]?

        // When
        cookieManager.request(url, method: .post).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertEqual(components?[3..<5], ["-X", "POST"])
        XCTAssertEqual(components?.last, "\"\(url)\"")
        XCTAssertEqual(components?[5..<6], ["-b"])
    }

    func testPOSTRequestWithCookiesDisabledCURLDescriptionHasNoCookies() {
        // Given
        let url = Endpoint.method(.post).url

        let cookie = HTTPCookie(properties: [.domain: url.host as Any,
                                             .path: url.path,
                                             .name: "foo",
                                             .value: "bar"])!
        sessionDisallowingCookies.session.configuration.httpCookieStorage?.setCookie(cookie)
        let expectation = expectation(description: "request should complete")
        var components: [String]?

        // When
        sessionDisallowingCookies.request(url, method: .post).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        let cookieComponents = components?.filter { $0 == "-b" }
        XCTAssertTrue(cookieComponents?.isEmpty == true)
    }

    func testMultipartFormDataRequestWithDuplicateHeadersCURLDescriptionHasOneContentTypeHeader() {
        // Given
        let url = Endpoint.method(.post).url
        let japaneseData = Data("日本語".utf8)
        let expectation = expectation(description: "multipart form data encoding should succeed")
        var cURLDescription: String?
        var components: [String]?

        // When
        sessionWithContentTypeHeader.upload(multipartFormData: { data in
            data.append(japaneseData, withName: "japanese")
        }, to: url).cURLDescription {
            components = self.cURLCommandComponents(from: $0)
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(components?[0..<3], ["$", "curl", "-v"])
        XCTAssertTrue(components?.contains("-X") == true)
        XCTAssertEqual(components?.last, "\"\(url)\"")

        let contentTypeCount = components?.filter { $0.contains("Content-Type") }.count
        XCTAssertEqual(contentTypeCount, 1, "command should contain a single Content-Type header")

        XCTAssertNotNil(cURLDescription?.range(of: "-H \"Content-Type: multipart/form-data;"))
    }

    func testThatRequestWithInvalidURLDebugDescription() {
        // Given
        let urlString = "invalid_url"
        let expectation = expectation(description: "request should complete")
        var cURLDescription: String?

        // When
        session.request(urlString).cURLDescription {
            cURLDescription = $0
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(cURLDescription, "debugDescription should not crash")
    }

    // MARK: Test Helper Methods

    private func cURLCommandComponents(from cURLString: String) -> [String] {
        cURLString.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0 != "" && $0 != "\\" }
    }
}

final class RequestLifetimeTests: BaseTestCase {
    func testThatRequestProvidesURLRequestWhenCreated() {
        // Given
        let didReceiveRequest = expectation(description: "did receive task")
        let didComplete = expectation(description: "request did complete")
        var request: URLRequest?

        // When
        AF.request(.default)
            .onURLRequestCreation { request = $0; didReceiveRequest.fulfill() }
            .responseDecodable(of: TestResponse.self) { _ in didComplete.fulfill() }

        wait(for: [didReceiveRequest, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNotNil(request)
    }

    func testThatRequestProvidesTaskWhenCreated() {
        // Given
        let didReceiveTask = expectation(description: "did receive task")
        let didComplete = expectation(description: "request did complete")
        var task: URLSessionTask?

        // When
        AF.request(.default)
            .onURLSessionTaskCreation { task = $0; didReceiveTask.fulfill() }
            .responseDecodable(of: TestResponse.self) { _ in didComplete.fulfill() }

        wait(for: [didReceiveTask, didComplete], timeout: timeout, enforceOrder: true)

        // Then
        XCTAssertNotNil(task)
    }
}

// MARK: -

final class RequestInvalidURLTestCase: BaseTestCase {
    func testThatDataRequestWithFileURLThrowsError() {
        // Given
        let fileURL = url(forResource: "valid_data", withExtension: "json")
        let expectation = expectation(description: "Request should succeed.")
        var response: DataResponse<Data?, AFError>?

        // When
        AF.request(fileURL)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatDownloadRequestWithFileURLThrowsError() {
        // Given
        let fileURL = url(forResource: "valid_data", withExtension: "json")
        let expectation = expectation(description: "Request should succeed.")
        var response: DownloadResponse<URL?, AFError>?

        // When
        AF.download(fileURL)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
    }

    func testThatDataStreamRequestWithFileURLThrowsError() {
        // Given
        let fileURL = url(forResource: "valid_data", withExtension: "json")
        let expectation = expectation(description: "Request should succeed.")
        var response: DataStreamRequest.Completion?

        // When
        AF.streamRequest(fileURL)
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response = completion
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNil(response?.response)
    }
}

#if canImport(zlib) && swift(>=5.6) // Same condition as `DeflateRequestCompressor`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class RequestCompressionTests: BaseTestCase {
    func testThatRequestsCanBeCompressed() async {
        // Given
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await AF.request(url,
                                      method: .post,
                                      parameters: parameters,
                                      encoder: .json,
                                      interceptor: .deflateCompressor)
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        XCTAssertTrue(result.isSuccess)
    }

    func testThatDeflateCompressorThrowsErrorByDefaultWhenRequestAlreadyHasHeader() async {
        // Given
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await AF.request(url,
                                      method: .post,
                                      parameters: parameters,
                                      encoder: .json,
                                      headers: [.contentEncoding("value")],
                                      interceptor: .deflateCompressor)
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        XCTAssertFalse(result.isSuccess)
        XCTAssertNotNil(result.failure?.underlyingError as? DeflateRequestCompressor.DuplicateHeaderError)
    }

    func testThatDeflateCompressorThrowsErrorWhenConfigured() async {
        // Given
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await AF.request(url,
                                      method: .post,
                                      parameters: parameters,
                                      encoder: .json,
                                      headers: [.contentEncoding("value")],
                                      interceptor: .deflateCompressor(duplicateHeaderBehavior: .error))
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        XCTAssertFalse(result.isSuccess)
        XCTAssertNotNil(result.failure?.underlyingError as? DeflateRequestCompressor.DuplicateHeaderError)
    }

    func testThatDeflateCompressorReplacesHeaderWhenConfigured() async {
        // Given
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await AF.request(url,
                                      method: .post,
                                      parameters: parameters,
                                      encoder: .json,
                                      headers: [.contentEncoding("value")],
                                      interceptor: .deflateCompressor(duplicateHeaderBehavior: .replace))
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        XCTAssertTrue(result.isSuccess)
    }

    func testThatDeflateCompressorSkipsCompressionWhenConfigured() async {
        // Given
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await AF.request(url,
                                      method: .post,
                                      parameters: parameters,
                                      encoder: .json,
                                      headers: [.contentEncoding("gzip")],
                                      interceptor: .deflateCompressor(duplicateHeaderBehavior: .skip))
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        // Request fails as the server expects gzip compression.
        XCTAssertFalse(result.isSuccess)
    }

    func testThatDeflateCompressorDoesNotCompressDataWhenClosureReturnsFalse() async {
        // Given
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await AF.request(url,
                                      method: .post,
                                      parameters: parameters,
                                      encoder: .json,
                                      interceptor: .deflateCompressor { _ in false })
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        XCTAssertTrue(result.isSuccess)
        // With no compression, request headers reflected from server should have no Content-Encoding.
        XCTAssertNil(result.success?.headers["Content-Encoding"])
    }
}
#endif
