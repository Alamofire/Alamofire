//
//  SessionDelegateTests.swift
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

@testable import Alamofire
import Foundation
import Testing

@Suite(.storesInstances)
struct SessionDelegateTestCase {
    // MARK: - Tests - Redirects

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestWillPerformHTTPRedirectionByDefault() async {
        // Given
        let session = stored(Session.independent(configuration: .ephemeral))
        let redirectURLString = Endpoint().url.absoluteString

        let expectation = Completion("Request should redirect to \(redirectURLString)")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(.redirectTo(redirectURLString))
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

        #expect(response.response?.url?.absoluteString == redirectURLString)
        #expect(response.response?.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestWillPerformRedirectionMultipleTimesByDefault() async {
        // Given
        let session = stored(Session.independent(configuration: .ephemeral))

        let expectation = Completion("Request should redirect")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(.redirect(5))
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
        #expect(response.response?.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestWillPerformRedirectionFor307Response() async {
        // Given
        let session = stored(Session.independent(configuration: .ephemeral))
        let redirectURLString = Endpoint().url.absoluteString

        let expectation = Completion("Request should redirect to \(redirectURLString)")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(.redirectTo(redirectURLString, code: 307))
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

        #expect(response.response?.url?.absoluteString == redirectURLString)
        #expect(response.response?.statusCode == 200)
    }

    // MARK: - Tests - Notification

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func appropriateNotificationsAreCalledWithRequestForDataRequest() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))
        let resumedRequest = Protected<Request?>(nil)
        let resumedTaskRequest = Protected<Request?>(nil)
        let completedTaskRequest = Protected<Request?>(nil)
        let completedRequest = Protected<Request?>(nil)
        let requestResponse = Capture<DataResponse<Data?, AFError>?>()
        let expect = Completion("request should complete")

        // When
        let request = session.request(.default).response { response in
            requestResponse.value = response
            expect.complete()
        }
        let didResume = Completion.notification(Request.didResumeNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedRequest.write(notification.request)
            return true
        }
        let didResumeTask = Completion.notification(Request.didResumeTaskNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedTaskRequest.write(notification.request)
            return true
        }
        let didCompleteTask = Completion.notification(Request.didCompleteTaskNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedTaskRequest.write(notification.request)
            return true
        }
        let didFinish = Completion.notification(Request.didFinishNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedRequest.write(notification.request)
            return true
        }

        request.resume()

        await wait(for: [expect, didResume, didResumeTask, didCompleteTask, didFinish])

        // Then
        #expect(resumedRequest.read { $0 } != nil)
        #expect(resumedTaskRequest.read { $0 } != nil)
        #expect(completedTaskRequest.read { $0 } != nil)
        #expect(completedRequest.read { $0 } != nil)
        #expect(resumedRequest == completedRequest)
        #expect(resumedTaskRequest == completedTaskRequest)
        #expect(requestResponse.response?.statusCode == 200)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func didCompleteNotificationIsCalledWithRequestForDownloadRequests() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))
        let resumedRequest = Protected<Request?>(nil)
        let resumedTaskRequest = Protected<Request?>(nil)
        let completedTaskRequest = Protected<Request?>(nil)
        let completedRequest = Protected<Request?>(nil)
        let requestResponse = Capture<DownloadResponse<URL?, AFError>?>()
        let expect = Completion("request should complete")

        // When
        let request = session.download(.default).response { response in
            requestResponse.value = response
            expect.complete()
        }
        let didResume = Completion.notification(Request.didResumeNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedRequest.write(notification.request)
            return true
        }
        let didResumeTask = Completion.notification(Request.didResumeTaskNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedTaskRequest.write(notification.request)
            return true
        }
        let didCompleteTask = Completion.notification(Request.didCompleteTaskNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedTaskRequest.write(notification.request)
            return true
        }
        let didFinish = Completion.notification(Request.didFinishNotification) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedRequest.write(notification.request)
            return true
        }

        request.resume()

        await wait(for: [didResume, didResumeTask, didCompleteTask, didFinish], enforceOrder: true)
        await expect.wait()

        // Then
        #expect(resumedRequest.read { $0 } != nil)
        #expect(resumedTaskRequest.read { $0 } != nil)
        #expect(completedTaskRequest.read { $0 } != nil)
        #expect(completedRequest.read { $0 } != nil)
        #expect(resumedRequest == completedRequest)
        #expect(resumedTaskRequest == completedTaskRequest)
        #expect(requestResponse.response?.statusCode == 200)
    }
}
