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
import Testing

@Suite(.storesInstances)
struct RequestResponseTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestResponse() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.get.url
        let expectation = Completion("GET request should succeed: \(url)")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(url, parameters: ["foo": "bar"])
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestReceivesInitialResponse() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.get.url
        let initialResponse = Capture<HTTPURLResponse?>()
        let didReceiveResponse = Completion("didReceiveResponse")
        let didComplete = Completion("GET request should succeed: \(url)")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(url, parameters: ["foo": "bar"])
            .onHTTPResponse { response in
                initialResponse.value = response
                didReceiveResponse.complete()
            }
            .response { resp in
                response.value = resp
                didComplete.complete()
            }

        await wait(for: [didReceiveResponse, didComplete], enforceOrder: true)

        // Then
        #expect(initialResponse.value == response.response)
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestOnHTTPResponseCanAllow() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.get.url
        let initialResponse = Capture<HTTPURLResponse?>()
        let didReceiveResponse = Completion("didReceiveResponse")
        let didComplete = Completion("GET request should succeed: \(url)")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(url, parameters: ["foo": "bar"])
            .onHTTPResponse { response, completionHandler in
                initialResponse.value = response
                didReceiveResponse.complete()
                completionHandler(.allow)
            }
            .response { resp in
                response.value = resp
                didComplete.complete()
            }

        await wait(for: [didReceiveResponse, didComplete], enforceOrder: true)

        // Then
        #expect(initialResponse.value == response.response)
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestOnHTTPResponseCanCancel() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.get.url
        let initialResponse = Capture<HTTPURLResponse?>()
        let didReceiveResponse = Completion("didReceiveResponse")
        let didComplete = Completion("GET request should succeed: \(url)")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.request(url, parameters: ["foo": "bar"])
            .onHTTPResponse { response, completionHandler in
                initialResponse.value = response
                didReceiveResponse.complete()
                completionHandler(.cancel)
            }
            .response { resp in
                response.value = resp
                didComplete.complete()
            }

        await wait(for: [didReceiveResponse, didComplete], enforceOrder: true)

        // Then
        #expect(initialResponse.value == response.response)
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data == nil)
        #expect(request.isCancelled, "onHTTPResponse cancelled request should have isCancelled == true")
        #expect(response.error?.isExplicitlyCancelledError == true, "onHTTPResponse cancelled request should be explicitly cancelled")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestResponseWithProgress() async {
        // Given
        let session = stored(Session.independent())
        let byteCount = 1024
        let url = Endpoint.bytes(byteCount).url

        let expectation = Completion("Bytes download progress should be reported: \(url)")

        let progressValues = Capture<[(fraction: Double, total: Int64)]>([])
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(url)
            .downloadProgress(queue: session.rootQueue) { progress in
                progressValues.write { $0.append((fraction: progress.fractionCompleted, total: progress.totalUnitCount)) }
            }
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.error == nil)

        var previousProgress: (fraction: Double, total: Int64) = progressValues.first ?? (fraction: 0, total: 0)

        for progress in progressValues.value {
            #expect(progress.fraction >= previousProgress.fraction, """
            previous fraction \(progress.fraction) is not >= \(previousProgress.fraction)
            """)
            previousProgress = progress
        }

        if let lastProgressValue = progressValues.last {
            #expect(lastProgressValue.fraction == 1.0)
        } else {
            Issue.record("last item in progressValues should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func pOSTRequestWithUnicodeParameters() async {
        // Given
        let session = stored(Session.independent())
        let parameters = ["french": "français",
                          "japanese": "日本語",
                          "arabic": "العربية",
                          "emoji": "😃"]

        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.method(.post), parameters: parameters)
            .responseDecodable(of: TestResponse.self) { closureResponse in
                response.value = closureResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)

        if let form = response.result?.success?.form {
            #expect(form["french"] == parameters["french"])
            #expect(form["japanese"] == parameters["japanese"])
            #expect(form["arabic"] == parameters["arabic"])
            #expect(form["emoji"] == parameters["emoji"])
        } else {
            Issue.record("form parameter in JSON should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func pOSTRequestWithBase64EncodedImages() async {
        // Given
        let session = stored(Session.independent())
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

        let expectation = Completion("request should succeed")

        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(Endpoint.method(.post), method: .post, parameters: parameters)
            .responseDecodable(of: TestResponse.self) { closureResponse in
                response.value = closureResponse
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.data != nil)
        #expect(response.result?.isSuccess == true)

        if let form = response.result?.success?.form {
            #expect(form["email"] == parameters["email"])
            #expect(form["png_image"] == parameters["png_image"])
            #expect(form["jpeg_image"] == parameters["jpeg_image"])
        } else {
            Issue.record("form parameter in JSON should not be nil")
        }
    }

    // MARK: Queues

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func responseSerializationWorksWithSerializationQueue() async {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let manager = stored(Session.independent(serializationQueue: queue))
        let expectation = Completion("request should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        manager.request(.get).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestsWorksWithRequestAndSerializationQueues() async {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue")
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue")
        let manager = stored(Session.independent(requestQueue: requestQueue, serializationQueue: serializationQueue))
        let expectation = Completion("request should complete")
        let response = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        manager.request(.get).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestsWorksWithConcurrentRequestAndSerializationQueues() async {
        // Given
        let requestQueue = DispatchQueue(label: "org.alamofire.testRequestQueue", attributes: .concurrent)
        let serializationQueue = DispatchQueue(label: "org.alamofire.testSerializationQueue", attributes: .concurrent)
        let session = stored(Session.independent(requestQueue: requestQueue, serializationQueue: serializationQueue))
        let count = 10
        let expectation = Completion("request should complete", expectedCount: count)
        let responses = Capture<[DataResponse<TestResponse, AFError>]>([])

        // When
        DispatchQueue.concurrentPerform(iterations: count) { _ in
            session.request(.default).responseDecodable(of: TestResponse.self) { resp in
                responses.write { $0.append(resp) }
                expectation.complete()
            }
        }

        await expectation.wait()

        // Then
        #expect(responses.count == count)
        // #expect treats a key path passed to rethrowing allSatisfy as a throwing call.
        // swiftformat:disable:next preferKeyPath
        #expect(responses.value.allSatisfy { $0.result.isSuccess })
    }

    // MARK: Encodable Parameters

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestsCanPassEncodableParametersAsJSONBodyData() async {
        // Given
        let session = stored(Session.independent())
        let parameters = TestParameters(property: "one")
        let expect = Completion("request should complete")
        let receivedResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.method(.post), parameters: parameters, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: TestResponse.self) { response in
                receivedResponse.value = response
                expect.complete()
            }

        await expect.wait()

        // Then
        #expect(receivedResponse.result?.success?.data == "{\"property\":\"one\"}")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestsCanPassEncodableParametersAsAURLQuery() async {
        // Given
        let session = stored(Session.independent())
        let parameters = TestParameters(property: "one")
        let expect = Completion("request should complete")
        let receivedResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.method(.get), parameters: parameters)
            .responseDecodable(of: TestResponse.self) { response in
                receivedResponse.value = response
                expect.complete()
            }

        await expect.wait()

        // Then
        #expect(receivedResponse.result?.success?.args == ["property": "one"])
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestsCanPassEncodableParametersAsURLEncodedBodyData() async {
        // Given
        let session = stored(Session.independent())
        let parameters = TestParameters(property: "one")
        let expect = Completion("request should complete")
        let receivedResponse = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        session.request(.method(.post), parameters: parameters)
            .responseDecodable(of: TestResponse.self) { response in
                receivedResponse.value = response
                expect.complete()
            }

        await expect.wait()

        // Then
        #expect(receivedResponse.result?.success?.form == ["property": "one"])
    }

    // MARK: Lifetime Events

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func automaticallyResumedRequestReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 4)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default).response { _ in expect.complete() }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func instanceAutomaticallyResumedRequestReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 4)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default, shouldAutomaticallyResume: true).response { _ in expect.complete() }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func automaticallyAndManuallyResumedRequestReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 4)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default).response { _ in expect.complete() }
        for _ in 0..<100 {
            request.resume()
        }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func manuallyResumedRequestReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 3)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default)
        for _ in 0..<100 {
            request.resume()
        }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func instanceManuallyResumedRequestReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 3)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default, shouldAutomaticallyResume: false)
        for _ in 0..<100 {
            request.resume()
        }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestManuallyResumedManyTimesOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 4)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default).response { _ in expect.complete() }
        for _ in 0..<100 {
            request.resume()
        }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestInstanceManuallyResumedManyTimesOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 4)

        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidFinish = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default, shouldAutomaticallyResume: false).response { _ in expect.complete() }
        for _ in 0..<100 {
            request.resume()
        }

        await expect.wait()

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestManuallySuspendedManyTimesAfterAutomaticResumeOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 2)

        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default)
        for _ in 0..<100 {
            request.suspend()
        }

        await expect.wait()

        // Then
        #expect(request.state == .suspended)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestManuallySuspendedManyTimesOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 2)

        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }

        // When
        let request = session.request(.default)
        for _ in 0..<100 {
            request.suspend()
        }

        await expect.wait()

        // Then
        #expect(request.state == .suspended)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestManuallyCancelledManyTimesAfterAutomaticResumeOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.testQueue")
        let eventMonitor = ClosureEventMonitor(queue: queue)
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let didFinish = Completion("request should finish")
        let events = Completion("request should receive appropriate lifetime events", expectedCount: 2)

        eventMonitor.requestDidCancelTask = { _, _ in events.complete() }
        eventMonitor.requestDidCancel = { _ in events.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in events.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in events.complete() }

        // When
        eventMonitor.requestDidCreateTask = { request, _ in
            for _ in 0..<100 {
                request.cancel()
            }
        }
        let request = session.request(.default)
        request.response { _ in
            didFinish.complete()
        }

        await wait(for: [didFinish, events])

        // Then
        #expect(request.state == .cancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestManuallyCancelledManyTimesOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, requestSetup: .eager, eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 2)

        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }

        // When
        eventMonitor.requestDidCreateTask = { request, _ in
            for _ in 0..<100 {
                request.cancel()
            }
        }
        let request = session.request(.default)

        await expect.wait()

        // Then
        #expect(request.state == .cancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestManuallyCancelledManyTimesOnManyQueuesOnlyReceivesAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let expect = Completion("request should receive appropriate lifetime events", expectedCount: 6)

        eventMonitor.requestDidCancelTask = { _, _ in expect.complete() }
        eventMonitor.requestDidCancel = { _ in expect.complete() }
        eventMonitor.requestDidResume = { _ in expect.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in expect.complete() }
        // Fulfill other events that would exceed the expected count. Inverted expectations require the full timeout.
        eventMonitor.requestDidSuspend = { _ in expect.complete() }
        eventMonitor.requestDidSuspendTask = { _, _ in expect.complete() }

        // When
        eventMonitor.requestDidCreateTask = { request, _ in
            DispatchQueue.concurrentPerform(iterations: 100) { i in
                request.cancel()

                if i == 99 { expect.complete() }
            }
        }
        let request = session.request(.delay(5)).response { _ in expect.complete() }

        await expect.wait()

        // Then
        #expect(request.state == .cancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestTriggersAllAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        // Disable event test until Firewalk support HTTPS.
        //  let didReceiveChallenge = Completion("didReceiveChallenge should fire")
        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didReceiveData = Completion("didReceiveData should fire")
        let willCacheResponse = Completion("willCacheResponse should fire")
        let didCreateURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateTask = Completion("didCreateTask should fire")
        let didGatherMetrics = Completion("didGatherMetrics should fire")
        let didComplete = Completion("didComplete should fire")
        let didFinish = Completion("didFinish should fire")
        let didResume = Completion("didResume should fire")
        let didResumeTask = Completion("didResumeTask should fire")
        let didParseResponse = Completion("didParseResponse should fire")
        let responseHandler = Completion("responseHandler should fire")

        let dataReceived = Capture(false)

        // Disable event test until Firewalk supports HTTPS.
        //  eventMonitor.taskDidReceiveChallenge = { _, _, _ in didReceiveChallenge.complete() }
        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.complete() }
        eventMonitor.dataTaskDidReceiveData = { _, _, _ in
            guard !dataReceived.value else { return }
            // Data may be received many times, fulfill only once.
            dataReceived.value = true
            didReceiveData.complete()
        }
        eventMonitor.dataTaskWillCacheResponse = { _, _, _ in willCacheResponse.complete() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.complete() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.complete() }

        // When
        let request = session.request(.default).response { _ in
            responseHandler.complete()
        }

        await wait(for: [taskDidFinishCollecting, didReceiveData, willCacheResponse, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didFinish, didResume, didResumeTask, didParseResponse, responseHandler])

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledRequestTriggersAllAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [eventMonitor]))

        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didCreateURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateTask = Completion("didCreateTask should fire")
        let didGatherMetrics = Completion("didGatherMetrics should fire")
        let didComplete = Completion("didComplete should fire")
        let didFinish = Completion("didFinish should fire")
        let didResume = Completion("didResume should fire")
        let didResumeTask = Completion("didResumeTask should fire")
        let didParseResponse = Completion("didParseResponse should fire")
        let didCancel = Completion("didCancel should fire")
        let didCancelTask = Completion("didCancelTask should fire")
        let responseHandler = Completion("responseHandler should fire")

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.complete() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidParseResponse = { _, _ in didParseResponse.complete() }
        eventMonitor.requestDidCancel = { _ in didCancel.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in didCancelTask.complete() }

        // When
        let request = session.request(.delay(5)).response { _ in
            responseHandler.complete()
        }

        eventMonitor.requestDidResumeTask = { [unowned request] _, _ in
            request.cancel()
            didResumeTask.complete()
        }

        request.resume()

        await wait(for: [taskDidFinishCollecting, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didFinish, didResume, didResumeTask, didParseResponse, didCancel, didCancelTask, responseHandler])

        // Then
        #expect(request.state == .cancelled)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func appendingResponseSerializerToCancelledRequestCallsCompletion() async {
        // Given
        let session = stored(Session.independent())

        let response1 = Capture<DataResponse<TestResponse, AFError>?>()
        let response2 = Capture<DataResponse<TestResponse, AFError>?>()

        let expect = Completion("both response serializer completions should be called", expectedCount: 2)

        // When
        let request = session.request(.delay(1))

        request.responseDecodable(of: TestResponse.self) { resp in
            response1.value = resp
            expect.complete()

            request.responseDecodable(of: TestResponse.self) { resp in
                response2.value = resp
                expect.complete()
            }
        }

        request.cancel()

        await expect.wait()

        // Then
        #expect(response1.error?.isExplicitlyCancelledError == true)
        #expect(response2.error?.isExplicitlyCancelledError == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func appendingResponseSerializerToCompletedRequestInsideCompletionResumesRequest() async {
        // Given
        let session = stored(Session.independent())

        let response1 = Capture<DataResponse<TestResponse, AFError>?>()
        let response2 = Capture<DataResponse<TestResponse, AFError>?>()
        let response3 = Capture<DataResponse<TestResponse, AFError>?>()

        let expect = Completion("all response serializer completions should be called", expectedCount: 3)

        // When
        let request = session.request(.default)

        request.responseDecodable(of: TestResponse.self) { resp in
            response1.value = resp
            expect.complete()

            request.responseDecodable(of: TestResponse.self) { resp in
                response2.value = resp
                expect.complete()

                request.responseDecodable(of: TestResponse.self) { resp in
                    response3.value = resp
                    expect.complete()
                }
            }
        }

        await expect.wait()

        // Then
        #expect(response1.value?.value != nil)
        #expect(response2.value?.value != nil)
        #expect(response3.value?.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func appendingResponseSerializerToCompletedRequestOutsideCompletionResumesRequest() async {
        // Given
        let session = stored(Session.independent())
        let request = session.request(.default)

        let response1 = Capture<DataResponse<TestResponse, AFError>?>()
        let response2 = Capture<DataResponse<TestResponse, AFError>?>()
        let response3 = Capture<DataResponse<TestResponse, AFError>?>()

        // When
        let expect1 = Completion("response serializer 1 completion should be called")
        request.responseDecodable(of: TestResponse.self) { response1.value = $0; expect1.complete() }
        await expect1.wait()

        let expect2 = Completion("response serializer 2 completion should be called")
        request.responseDecodable(of: TestResponse.self) { response2.value = $0; expect2.complete() }
        await expect2.wait()

        let expect3 = Completion("response serializer 3 completion should be called")
        request.responseDecodable(of: TestResponse.self) { response3.value = $0; expect3.complete() }
        await expect3.wait()

        // Then
        #expect(response1.value?.value != nil)
        #expect(response2.value?.value != nil)
        #expect(response3.value?.value != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct RequestDescriptionTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestDescription() async {
        // Given
        let url = Endpoint().url
        let manager = stored(Session.independent(startRequestsImmediately: false))
        let request = manager.request(url)

        let expectation = Completion("Request description should update: \(url)")

        let response = Capture<HTTPURLResponse?>()

        // When
        request.response { resp in
            response.value = resp.response

            expectation.complete()
        }.resume()

        await expectation.wait()

        // Then
        #expect(request.description == "GET \(url) (\(response.statusCode ?? -1))")
    }
}

// MARK: -

@Suite(.storesInstances)
struct RequestCURLDescriptionTestCase {
    // MARK: Properties

    let session: Session = stored(Session.independent(requestSetup: .eager))

    let sessionWithAcceptLanguageHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Accept-Language"] = "en-US"

        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers

        return stored(Session.independent(configuration: configuration, requestSetup: .eager))
    }()

    let sessionWithContentTypeHeader: Session = {
        var headers = HTTPHeaders.default
        headers["Content-Type"] = "application/json"

        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers

        return stored(Session.independent(configuration: configuration, requestSetup: .eager))
    }()

    func sessionWithCookie(_ cookie: HTTPCookie) -> Session {
        let configuration = URLSessionConfiguration.af.default.withIndependentStorage()
        configuration.httpCookieStorage?.setCookie(cookie)

        return Session.independent(configuration: configuration, requestSetup: .eager)
    }

    let sessionDisallowingCookies: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = false

        return stored(Session.independent(configuration: configuration, requestSetup: .eager))
    }()

    // MARK: Tests

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func gETRequestCURLDescription() async {
        // Given
        let url = Endpoint().url
        let expectation = Completion("request should complete")
        let components = Capture<[String]?>()

        // When
        session.request(url).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            expectation.complete()
        }
        // requires eager perform

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?.contains("-X") == true)
        #expect(components.last == "\"\(url)\"")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func gETRequestCURLDescriptionOnMainQueue() async {
        // Given
        let url = Endpoint().url
        let expectation = Completion("request should complete")
        let isMainThread = Capture(false)
        let components = Capture<[String]?>()

        // When
        session.request(url).cURLDescription(on: .main) {
            components.value = cURLCommandComponents(from: $0)
            isMainThread.value = Thread.isMainThread
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(isMainThread.value)
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?.contains("-X") == true)
        #expect(components.last == "\"\(url)\"")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func gETRequestCURLDescriptionSynchronous() async {
        // Given
        let url = Endpoint().url
        let expectation = Completion("request should complete")
        let components = Capture<[String]?>()
        let syncComponents = Capture<[String]?>()

        // When
        let request = session.request(url)
        request.cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            syncComponents.value = cURLCommandComponents(from: request.cURLDescription())
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?.contains("-X") == true)
        #expect(components.last == "\"\(url)\"")
        #expect(components.value?.sorted() == syncComponents.value?.sorted())
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func gETRequestCURLDescriptionCanBeRequestedManyTimes() async {
        // Given
        let url = Endpoint().url
        let expectation = Completion("request should complete")
        let components = Capture<[String]?>()
        let secondComponents = Capture<[String]?>()

        // When
        let request = session.request(url)
        request.cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            request.cURLDescription {
                secondComponents.value = cURLCommandComponents(from: $0)
                expectation.complete()
            }
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?.contains("-X") == true)
        #expect(components.last == "\"\(url)\"")
        #expect(components.value?.sorted() == secondComponents.value?.sorted())
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func gETRequestWithCustomHeaderCURLDescription() async {
        // Given
        let url = Endpoint().url
        let expectation = Completion("request should complete")
        let cURLDescription = Capture<String?>()

        // When
        let headers: HTTPHeaders = ["X-Custom-Header": "{\"key\": \"value\"}"]
        session.request(url, headers: headers).cURLDescription {
            cURLDescription.value = $0
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(cURLDescription.value?.range(of: "-H \"X-Custom-Header: {\\\"key\\\": \\\"value\\\"}\"") != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func gETRequestWithDuplicateHeadersDebugDescription() async {
        // Given
        let url = Endpoint().url
        let expectation = Completion("request should complete")
        let cURLDescription = Capture<String?>()
        let components = Capture<[String]?>()

        // When
        let headers: HTTPHeaders = ["Accept-Language": "en-GB"]
        sessionWithAcceptLanguageHeader.request(url, headers: headers).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            cURLDescription.value = $0
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?.contains("-X") == true)
        #expect(components.last == "\"\(url)\"")

        let acceptLanguageCount = components.value?.count(where: { $0.contains("Accept-Language") })
        #expect(acceptLanguageCount == 1, "command should contain a single Accept-Language header")

        #expect(cURLDescription.value?.range(of: "-H \"Accept-Language: en-GB\"") != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func pOSTRequestCURLDescription() async {
        // Given
        let url = Endpoint.method(.post).url
        let expectation = Completion("request should complete")
        let components = Capture<[String]?>()

        // When
        session.request(url, method: .post).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?[3..<5] == ["-X", "POST"])
        #expect(components.last == "\"\(url)\"")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func pOSTRequestWithJSONParametersCURLDescription() async {
        // Given
        let url = Endpoint.method(.post).url
        let expectation = Completion("request should complete")
        let cURLDescription = Capture<String?>()
        let components = Capture<[String]?>()

        let parameters = ["foo": "bar",
                          "fo\"o": "b\"ar",
                          "f'oo": "ba'r"]

        // When
        session.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            cURLDescription.value = $0
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?[3..<5] == ["-X", "POST"])

        #expect(cURLDescription.value?.range(of: "-H \"Content-Type: application/json\"") != nil)
        #expect(cURLDescription.value?.range(of: "-d \"{") != nil)
        #expect(cURLDescription.value?.range(of: "\\\"f'oo\\\":\\\"ba'r\\\"") != nil)
        #expect(cURLDescription.value?.range(of: "\\\"fo\\\\\\\"o\\\":\\\"b\\\\\\\"ar\\\"") != nil)
        #expect(cURLDescription.value?.range(of: "\\\"foo\\\":\\\"bar\\") != nil)

        #expect(components.last == "\"\(url)\"")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func pOSTRequestWithCookieCURLDescription() async {
        // Given
        let url = Endpoint.method(.post).url

        let cookie = HTTPCookie(properties: [.domain: url.host as Any,
                                             .path: url.path,
                                             .name: "foo",
                                             .value: "bar"])!
        let cookieManager = stored(sessionWithCookie(cookie))
        let expectation = Completion("request should complete")
        let components = Capture<[String]?>()

        // When
        cookieManager.request(url, method: .post).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?[3..<5] == ["-X", "POST"])
        #expect(components.last == "\"\(url)\"")
        #expect(components.value?[5..<6] == ["-b"])
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func pOSTRequestWithCookiesDisabledCURLDescriptionHasNoCookies() async {
        // Given
        let url = Endpoint.method(.post).url

        let cookie = HTTPCookie(properties: [.domain: url.host as Any,
                                             .path: url.path,
                                             .name: "foo",
                                             .value: "bar"])!
        sessionDisallowingCookies.session.configuration.httpCookieStorage?.setCookie(cookie)
        let expectation = Completion("request should complete")
        let components = Capture<[String]?>()

        // When
        sessionDisallowingCookies.request(url, method: .post).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            expectation.complete()
        }

        await expectation.wait()

        // Then
        let cookieComponents = components.value?.filter { $0 == "-b" }
        #expect(cookieComponents?.isEmpty == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipartFormDataRequestWithDuplicateHeadersCURLDescriptionHasOneContentTypeHeader() async {
        // Given
        let url = Endpoint.method(.post).url
        let japaneseData = Data("日本語".utf8)
        let expectation = Completion("multipart form data encoding should succeed")
        let cURLDescription = Capture<String?>()
        let components = Capture<[String]?>()

        // When
        sessionWithContentTypeHeader.upload(multipartFormData: { data in
            data.append(japaneseData, withName: "japanese")
        }, to: url).cURLDescription {
            components.value = cURLCommandComponents(from: $0)
            cURLDescription.value = $0
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(components.value?[0..<3] == ["$", "curl", "-v"])
        #expect(components.value?.contains("-X") == true)
        #expect(components.last == "\"\(url)\"")

        let contentTypeCount = components.value?.count(where: { $0.contains("Content-Type") })
        #expect(contentTypeCount == 1, "command should contain a single Content-Type header")

        #expect(cURLDescription.value?.range(of: "-H \"Content-Type: multipart/form-data;") != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestWithInvalidURLDebugDescription() async {
        // Given
        let urlString = "invalid_url"
        let expectation = Completion("request should complete")
        let cURLDescription = Capture<String?>()

        // When
        session.request(urlString).cURLDescription {
            cURLDescription.value = $0
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(cURLDescription.value != nil, "debugDescription should not crash")
    }

    // MARK: Test Helper Methods

    private func cURLCommandComponents(from cURLString: String) -> [String] {
        cURLString.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0 != "" && $0 != "\\" }
    }
}

@Suite(.storesInstances)
struct RequestLifetimeTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestProvidesURLRequestWhenCreated() async {
        // Given
        let session = stored(Session.independent())
        let didReceiveRequest = Completion("did receive task")
        let didComplete = Completion("request did complete")
        let request = Capture<URLRequest?>()

        // When
        session.request(.default)
            .onURLRequestCreation { request.value = $0; didReceiveRequest.complete() }
            .responseDecodable(of: TestResponse.self) { _ in didComplete.complete() }

        await wait(for: [didReceiveRequest, didComplete], enforceOrder: true)

        // Then
        #expect(request.value != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestProvidesTaskWhenCreated() async {
        // Given
        let session = stored(Session.independent())
        let didReceiveTask = Completion("did receive task")
        let didComplete = Completion("request did complete")
        let task = Capture<URLSessionTask?>()

        // When
        session.request(.default)
            .onURLSessionTaskCreation { task.value = $0; didReceiveTask.complete() }
            .responseDecodable(of: TestResponse.self) { _ in didComplete.complete() }

        await wait(for: [didReceiveTask, didComplete], enforceOrder: true)

        // Then
        #expect(task.value != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct RequestInvalidURLTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestWithFileURLThrowsError() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = url(forResource: "valid_data", withExtension: "json")
        let expectation = Completion("Request should succeed.")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(fileURL)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestWithFileURLThrowsError() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = url(forResource: "valid_data", withExtension: "json")
        let expectation = Completion("Request should succeed.")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(fileURL)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.result?.isSuccess == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestWithFileURLThrowsError() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = url(forResource: "valid_data", withExtension: "json")
        let expectation = Completion("Request should succeed.")
        let response = Capture<DataStreamRequest.Completion?>()

        // When
        session.streamRequest(fileURL)
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response.value = completion
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.response == nil)
    }
}

@Suite(.storesInstances)
struct RequestInstanceInterceptorTests {
    @Test
    func instanceAdapterIsCalled() async {
        // Given
        let session = stored(Session.independent())
        let adapter = InspectorInterceptor(.adapter { @Sendable request, _, completion in completion(.success(request)) })

        // When
        let response = await session
            .request(.get)
            .adapt(using: adapter)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(adapter.adaptations.count == 1)
    }

    @Test
    func instanceAdaptersAreCalledInAddedOrder() async {
        // Given
        let session = stored(Session.independent())
        let firstAdapter = InspectorInterceptor(.adapter { @Sendable request, _, completion in completion(.success(request)) })
        let secondAdapter = InspectorInterceptor(.adapter { @Sendable request, _, completion in completion(.success(request)) })

        // When
        let response = await session
            .request(.get)
            .adapt(using: firstAdapter)
            .adapt(using: secondAdapter)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(firstAdapter.adaptations.count == 1)
        #expect(secondAdapter.adaptations.count == 1)
        #expect(firstAdapter.adaptations[0].date < secondAdapter.adaptations[0].date)
    }

    @Test
    func sessionAdapterIsCalledBeforeInstanceAdapter() async {
        // Given
        let sessionInterceptor = InspectorInterceptor(.adapter { @Sendable request, _, completion in
            var request = request
            request.headers["session"] = "\(Date.now.timeIntervalSince1970)"
            completion(.success(request))
        })
        let session = stored(Session.independent(interceptor: sessionInterceptor))
        let instanceInterceptor = InspectorInterceptor(.adapter { @Sendable request, _, completion in
            var request = request
            request.headers["instance"] = "\(Date.now.timeIntervalSince1970)"
            completion(.success(request))
        })

        // When
        let response = await session
            .request(.get)
            .adapt(using: instanceInterceptor)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        if let sessionTime = response.request?.headers["session"].flatMap(Double.init),
           let instanceTime = response.request?.headers["instance"].flatMap(Double.init) {
            #expect(sessionTime < instanceTime)
        }
        #expect(sessionInterceptor.adaptations.count == 1)
        #expect(instanceInterceptor.adaptations.count == 1)
        #expect(sessionInterceptor.adaptations[0].date < instanceInterceptor.adaptations[0].date)
    }

    @Test
    func instanceInterceptorIsCalled() async {
        // Given
        let session = stored(Session.independent())
        let interceptor = InspectorInterceptor(
            .interceptor { @Sendable request, _, completion in
                completion(.success(request))
            } retrier: { @Sendable _, _, _, completion in
                completion(.retry)
            }
        )

        // When
        let response = await session
            .request(.endpoints(.delay(1).modifying(\.timeout, to: 0.0001), .get))
            .interceptor(interceptor)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(interceptor.adaptations.count == 2)
        #expect(interceptor.retries.count == 1)
    }

    @Test
    func multipleInstanceInterceptorsAreCalledInAddedOrder() async {
        // Given
        let session = stored(Session.independent())
        let firstInterceptor = InspectorInterceptor(
            .interceptor { @Sendable request, _, completion in
                completion(.success(request))
            } retrier: { @Sendable _, _, _, completion in
                completion(.doNotRetry)
            }
        )
        let secondInterceptor = InspectorInterceptor(
            .interceptor { @Sendable request, _, completion in
                completion(.success(request))
            } retrier: { @Sendable _, _, _, completion in
                completion(.retry)
            }
        )

        // When
        let response = await session
            .request(.endpoints(.delay(1).modifying(\.timeout, to: 0.0001), .get))
            .interceptor(firstInterceptor)
            .interceptor(secondInterceptor)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(firstInterceptor.adaptations.count == 2)
        #expect(firstInterceptor.retries.count == 1)
        #expect(secondInterceptor.adaptations.count == 2)
        #expect(secondInterceptor.retries.count == 1)
        #expect(firstInterceptor.adaptations[0].date < secondInterceptor.adaptations[0].date)
        #expect(firstInterceptor.adaptations[1].date < secondInterceptor.adaptations[1].date)
        #expect(firstInterceptor.retries[0].date < secondInterceptor.retries[0].date)
    }

    @Test
    func instanceRetrierIsCalled() async {
        // Given
        let session = stored(Session.independent())
        let interceptor = InspectorInterceptor(.retrier { @Sendable _, _, _, completion in completion(.retry) })

        // When
        let response = await session
            .request(.endpoints(.delay(1).modifying(\.timeout, to: 0.0001), .get))
            .retry(using: interceptor)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(interceptor.retries.count == 1)
    }

    @Test
    func multipleInstanceRetriersAreCalledInAddedOrder() async {
        // Given
        let session = stored(Session.independent())
        let firstRetrier = InspectorInterceptor(.retrier { @Sendable _, _, _, completion in completion(.doNotRetry) })
        let secondRetrier = InspectorInterceptor(.retrier { @Sendable _, _, _, completion in completion(.retry) })

        // When
        let response = await session
            .request(.endpoints(.delay(1).modifying(\.timeout, to: 0.0001), .get))
            .retry(using: firstRetrier)
            .retry(using: secondRetrier)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(firstRetrier.retries.count == 1)
        #expect(secondRetrier.retries.count == 1)
        #expect(firstRetrier.retries[0].date < secondRetrier.retries[0].date)
    }

    @Test
    func sessionRetrierIsCalledBeforeInstanceRetrier() async {
        // Given
        let sessionRetrier = InspectorInterceptor(.retrier { @Sendable _, _, _, completion in completion(.doNotRetry) })
        let session = stored(Session.independent(interceptor: sessionRetrier))
        let instanceRetrier = InspectorInterceptor(.retrier { @Sendable _, _, _, completion in completion(.retry) })

        // When
        let response = await session
            .request(.endpoints(.delay(1).modifying(\.timeout, to: 0.0001), .get))
            .retry(using: instanceRetrier)
            .serializingDecodable(TestResponse.self).response

        #expect(response.result.isSuccess)
        #expect(instanceRetrier.retries.count == 1)
        #expect(sessionRetrier.retries.count == 1)
        #expect(sessionRetrier.retries[0].date < instanceRetrier.retries[0].date)
    }

    @Test
    func instanceEventMonitorIsCalled() async {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.\(#function)")
        let monitor = InspectorEventMonitor(queue: queue)
        let session = stored(Session.independent(eventMonitors: []))

        // When
        let response = await session
            .request(.get)
            .eventMonitor(monitor)
            .serializingDecodable(TestResponse.self)
            .response
        await monitor.pendingEvents()

        // Then

        #expect(response.result.isSuccess)
        let expected = ["requestDidResume(_:)",
                        "request(_:didCreateInitialURLRequest:)",
                        "request(_:didCreateURLRequest:)",
                        "request(_:didCreateTask:)",
                        "request(_:didResumeTask:)",
                        "request(_:didGatherMetrics:)",
                        "requestDidFinish(_:)",
                        "request(_:didParseResponse:)"]
        #expect(monitor.events == expected, "Events didn't match, actual events: \(monitor.events)")
    }

    @Test
    func multipleInstanceEventMonitorsAreCalledInAddedOrder() async {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.\(#function)")
        let firstMonitor = InspectorEventMonitor(queue: queue)
        let secondMonitor = InspectorEventMonitor(queue: queue)
        let session = stored(Session.independent(eventMonitors: []))

        // When
        let response = await session
            .request(.get)
            .eventMonitor(firstMonitor)
            .eventMonitor(secondMonitor)
            .serializingDecodable(TestResponse.self)
            .response
        await firstMonitor.pendingEvents()

        // Then

        #expect(response.result.isSuccess)
        let expected = ["requestDidResume(_:)",
                        "request(_:didCreateInitialURLRequest:)",
                        "request(_:didCreateURLRequest:)",
                        "request(_:didCreateTask:)",
                        "request(_:didResumeTask:)",
                        "request(_:didGatherMetrics:)",
                        "requestDidFinish(_:)",
                        "request(_:didParseResponse:)"]
        #expect(firstMonitor.events == expected, "firstMonitor events didn't match, actual events: \(firstMonitor.events)")
        #expect(secondMonitor.events == expected, "secondMonitor events didn't match, actual events: \(firstMonitor.events)")
        for timelines in zip(firstMonitor.timeline, secondMonitor.timeline) {
            #expect(timelines.0.date <= timelines.1.date)
        }
    }

    @Test
    func instanceAndSessionEventMonitorsAreCalledInCorrectOrder() async {
        // Given
        let queue = DispatchQueue(label: "org.alamofire.\(#function)")
        let sessionMonitor = InspectorEventMonitor(label: "session", queue: queue)
        let instanceMonitor = InspectorEventMonitor(label: "instance", queue: queue)
        let session = stored(Session.independent(eventMonitors: [sessionMonitor]))

        // When
        let response = await session
            .request(.get)
            .eventMonitor(instanceMonitor)
            .serializingDecodable(TestResponse.self)
            .response
        await sessionMonitor.pendingEvents()
        await instanceMonitor.pendingEvents()

        // Then

        #expect(response.result.isSuccess)
        let expectedInstanceEvents = ["requestDidResume(_:)",
                                      "request(_:didCreateInitialURLRequest:)",
                                      "request(_:didCreateURLRequest:)",
                                      "request(_:didCreateTask:)",
                                      "request(_:didResumeTask:)",
                                      "request(_:didGatherMetrics:)",
                                      "requestDidFinish(_:)",
                                      "request(_:didParseResponse:)"]
        let expectedSessionEvents = ["requestDidResume(_:)",
                                     "request(_:didCreateInitialURLRequest:)",
                                     "request(_:didCreateURLRequest:)",
                                     "request(_:didCreateTask:)",
                                     "request(_:didResumeTask:)",
                                     "urlSession(_:dataTask:didReceive:)",
                                     "urlSession(_:dataTask:willCacheResponse:)",
                                     "urlSession(_:task:didFinishCollecting:)",
                                     "request(_:didGatherMetrics:)",
                                     "urlSession(_:task:didCompleteWithError:)",
                                     "requestDidFinish(_:)",
                                     "request(_:didParseResponse:)"]
        #expect(sessionMonitor.events == expectedSessionEvents, "Session events didn't match, actual events: \(sessionMonitor.events)")
        #expect(instanceMonitor.events == expectedInstanceEvents, "Instance events didn't match, actual events: \(instanceMonitor.events)")
        let instanceEvents = instanceMonitor.timeline
        var sessionEvents = sessionMonitor.timeline
        sessionEvents = sessionEvents.filter { session in instanceEvents.contains { $0.event == session.event } }
        #expect(instanceEvents.count == sessionEvents.count)
        for combinedEvent in zip(sessionEvents, instanceEvents) {
            #expect(combinedEvent.0.event == combinedEvent.1.event)
            #expect(combinedEvent.0.date <= combinedEvent.1.date, "session event wasn't before instance event")
        }
    }
}

#if canImport(zlib) && !os(Android) // Same condition as `DeflateRequestCompressor`.
@Suite(.storesInstances)
struct RequestCompressionTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func thatRequestsCanBeCompressed() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await session.request(url,
                                           method: .post,
                                           parameters: parameters,
                                           encoder: .json,
                                           interceptor: .deflateCompressor)
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        #expect(result.isSuccess)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func thatDeflateCompressorThrowsErrorByDefaultWhenRequestAlreadyHasHeader() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await session.request(url,
                                           method: .post,
                                           parameters: parameters,
                                           encoder: .json,
                                           headers: [.contentEncoding("value")],
                                           interceptor: .deflateCompressor)
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        #expect(result.isFailure)
        #expect(result.failure?.underlyingError as? DeflateRequestCompressor.DuplicateHeaderError != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func thatDeflateCompressorThrowsErrorWhenConfigured() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await session.request(url,
                                           method: .post,
                                           parameters: parameters,
                                           encoder: .json,
                                           headers: [.contentEncoding("value")],
                                           interceptor: .deflateCompressor(duplicateHeaderBehavior: .error))
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        #expect(result.isFailure)
        #expect(result.failure?.underlyingError as? DeflateRequestCompressor.DuplicateHeaderError != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func thatDeflateCompressorReplacesHeaderWhenConfigured() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await session.request(url,
                                           method: .post,
                                           parameters: parameters,
                                           encoder: .json,
                                           headers: [.contentEncoding("value")],
                                           interceptor: .deflateCompressor(duplicateHeaderBehavior: .replace))
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        #expect(result.isSuccess)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func thatDeflateCompressorSkipsCompressionWhenConfigured() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await session.request(url,
                                           method: .post,
                                           parameters: parameters,
                                           encoder: .json,
                                           headers: [.contentEncoding("gzip")],
                                           interceptor: .deflateCompressor(duplicateHeaderBehavior: .skip))
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        // Request fails as the server expects gzip compression.
        #expect(result.isFailure)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func thatDeflateCompressorDoesNotCompressDataWhenClosureReturnsFalse() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.method(.post).url
        let parameters = TestParameters(property: "compressed")

        // When
        let result = await session.request(url,
                                           method: .post,
                                           parameters: parameters,
                                           encoder: .json,
                                           interceptor: .deflateCompressor { _ in false })
            .serializingDecodable(TestResponse.self)
            .result

        // Then
        #expect(result.isSuccess)
        // With no compression, request headers reflected from server should have no Content-Encoding.
        #expect(result.success?.headers["Content-Encoding"] == nil)
    }
}
#endif
