//
//  DownloadTests.swift
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
struct DownloadInitializationTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadClassMethodWithMethodURLAndDestination() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.get
        let expectation = Completion("download should complete")

        // When
        let request = session.download(endpoint).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil)
        #expect(request.request?.httpMethod == "GET")
        #expect(request.request?.url == endpoint.url)
        #expect(request.response != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadClassMethodWithMethodURLHeadersAndDestination() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.get
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let expectation = Completion("download should complete")

        // When
        let request = session.download(endpoint, headers: headers).response { _ in
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(request.request != nil)
        #expect(request.request?.httpMethod == "GET")
        #expect(request.request?.url == endpoint.url)
        #expect(request.request?.headers["Authorization"] == "123456")
        #expect(request.response != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct DownloadResponseTests {
    private let directory = TemporaryDirectory()
    private var testDirectoryURL: URL { directory.url }

    private var randomCachesFileURL: URL {
        testDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequest() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = randomCachesFileURL
        let numberOfLines = 100
        let endpoint = Endpoint.stream(numberOfLines)
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = Completion("Download request should download data to file: \(endpoint.url.absoluteString)")
        let response = Capture<DownloadResponse<URL, AFError>?>()

        // When
        session.download(endpoint, to: destination)
            .validate()
            .responseURL { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)

        if let destinationURL = response.fileURL {
            #expect(FileManager.default.fileExists(atPath: destinationURL.path))

            if let data = try? Data(contentsOf: destinationURL) {
                #expect(!data.isEmpty)
            } else {
                Issue.record("data should exist for contents of destinationURL")
            }
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestResponseURLProducesURL() async throws {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("Download request should download data")
        let response = Capture<DownloadResponse<URL, AFError>?>()

        // When
        session.download(.get)
            .responseURL { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)

        let url = try #require(response.value?.value)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadRequest() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = randomCachesFileURL
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = Completion("Cancelled download request should not download data to file")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(.infinite, to: destination)
            .response { resp in
                response.value = resp
                expectation.complete()
            }
            .cancel()

        await expectation.wait()

        // Then
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.error != nil)
        #expect(response.error?.isExplicitlyCancelledError == true)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestWithProgress() async {
        // Given
        let session = stored(Session.independent())
        let randomBytes = 1024
        let endpoint = Endpoint.bytes(randomBytes)

        let expectation = Completion("Bytes download progress should be reported: \(endpoint.url)")

        let progressValues = Capture<[Double]>([])
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(endpoint)
            .downloadProgress(queue: session.rootQueue) { progress in
                progressValues.write { $0.append(progress.fractionCompleted) }
            }
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)

        var previousProgress: Double = progressValues.first ?? 0.0

        for progress in progressValues.value {
            #expect(progress >= previousProgress)
            previousProgress = progress
        }

        if let lastProgressValue = progressValues.last {
            #expect(lastProgressValue == 1.0)
        } else {
            Issue.record("last item in progressValues should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestWithParameters() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = randomCachesFileURL
        let parameters = ["foo": "bar"]
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = Completion("Download request should download data to file")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(Endpoint.get, parameters: parameters, to: destination)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)

        if
            let data = try? Data(contentsOf: fileURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
            let json = jsonObject as? [String: Any],
            let args = json["args"] as? [String: String] {
            #expect(args["foo"] == "bar")
        } else {
            Issue.record("args parameter in JSON should not be nil")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestWithHeaders() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = randomCachesFileURL
        let endpoint = Endpoint.get
        let headers: HTTPHeaders = ["Authorization": "123456"]
        let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }

        let expectation = Completion("Download request should download data to file: \(endpoint.url)")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(endpoint, headers: headers, to: destination)
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)

        guard let data = try? Data(contentsOf: fileURL),
              let response = try? JSONDecoder().decode(TestResponse.self, from: data) else {
            Issue.record("headers parameter in JSON should not be nil")
            return
        }

        #expect(response.headers["Authorization"] == "123456")
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadingFileAndMovingToDirectoryThatDoesNotExistThrowsError() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = testDirectoryURL.appendingPathComponent("some/random/folder/test_output.json")

        let expectation = Completion("Download request should download data but fail to move file")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(.get, to: { _, _ in (fileURL, []) })
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect((response.error?.underlyingError as? CocoaError)?.code == .fileNoSuchFile)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadOptionsCanCreateIntermediateDirectoriesPriorToMovingFile() async {
        // Given
        let session = stored(Session.independent())
        let fileURL = testDirectoryURL.appendingPathComponent("some/random/folder/test_output.json")

        let expectation = Completion("Download request should download data to file: \(fileURL)")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(.get, to: { _, _ in (fileURL, [.createIntermediateDirectories]) })
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadingFileAndMovingToDestinationThatIsOccupiedThrowsError() async throws {
        // Given
        let session = stored(Session.independent())
        let directoryURL = testDirectoryURL.appendingPathComponent("some/random/folder")
        let directoryCreated = FileManager.createDirectory(at: directoryURL)

        let fileURL = directoryURL.appendingPathComponent("test_output.json")
        try "random_data".write(to: fileURL, atomically: true, encoding: .utf8)

        let expectation = Completion("Download should complete but fail to move file")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(.get, to: { _, _ in (fileURL, []) })
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(directoryCreated)

        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect((response.error?.underlyingError as? CocoaError)?.code == .fileWriteFileExists)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadOptionsCanRemovePreviousFilePriorToMovingFile() async {
        // Given
        let session = stored(Session.independent())
        let directoryURL = testDirectoryURL.appendingPathComponent("some/random/folder")
        let directoryCreated = FileManager.createDirectory(at: directoryURL)

        let fileURL = directoryURL.appendingPathComponent("test_output.json")

        let expectation = Completion("Download should complete and move file to URL: \(fileURL)")
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        session.download(.get,
                         to: { _, _ in (fileURL, [.removePreviousFile, .createIntermediateDirectories]) })
            .response { resp in
                response.value = resp
                expectation.complete()
            }

        await expectation.wait()

        // Then
        #expect(directoryCreated)

        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct DownloadRequestEventsTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestTriggersAllAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(eventMonitors: [eventMonitor]))

        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didCreateInitialURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateURLRequest = Completion("didCreateURLRequest should fire")
        let didCreateTask = Completion("didCreateTask should fire")
        let didGatherMetrics = Completion("didGatherMetrics should fire")
        let didComplete = Completion("didComplete should fire")
        let didWriteData = Completion("didWriteData should fire")
        let didFinishDownloading = Completion("didFinishDownloading should fire")
        let didFinishWithResult = Completion("didFinishWithResult should fire")
        let didCreate = Completion("didCreate should fire")
        let didFinish = Completion("didFinish should fire")
        let didResume = Completion("didResume should fire")
        let didResumeTask = Completion("didResumeTask should fire")
        let didParseResponse = Completion("didParseResponse should fire")
        let responseHandler = Completion("responseHandler should fire")

        let wroteData = Capture(false)

        eventMonitor.taskDidFinishCollectingMetrics = { _, _, _ in taskDidFinishCollecting.complete() }
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateInitialURLRequest.complete() }
        eventMonitor.requestDidCreateURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.downloadTaskDidWriteData = { _, _, _, _, _ in
            guard !wroteData.value else { return }

            wroteData.value = true
            didWriteData.complete()
        }
        eventMonitor.downloadTaskDidFinishDownloadingToURL = { _, _, _ in didFinishDownloading.complete() }
        eventMonitor.requestDidFinishDownloadingUsingTaskWithResult = { _, _, _ in didFinishWithResult.complete() }
        eventMonitor.requestDidCreateDestinationURL = { _, _ in didCreate.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidResumeTask = { _, _ in didResumeTask.complete() }
        eventMonitor.requestDidParseDownloadResponse = { _, _ in didParseResponse.complete() }

        // When
        let request = session.download(.get).response { _ in
            responseHandler.complete()
        }

        await wait(for: [taskDidFinishCollecting, didCreateInitialURLRequest, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didWriteData, didFinishDownloading, didFinishWithResult, didCreate, didFinish, didResume, didResumeTask, didParseResponse, responseHandler])

        // Then
        #expect(request.state == .finished)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadRequestTriggersAllAppropriateLifetimeEvents() async {
        // Given
        let eventMonitor = ClosureEventMonitor()
        let session = stored(Session.independent(startRequestsImmediately: false, eventMonitors: [eventMonitor]))

        let taskDidFinishCollecting = Completion("taskDidFinishCollecting should fire")
        let didCreateInitialURLRequest = Completion("didCreateInitialURLRequest should fire")
        let didCreateURLRequest = Completion("didCreateURLRequest should fire")
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
        eventMonitor.requestDidCreateInitialURLRequest = { _, _ in didCreateInitialURLRequest.complete() }
        eventMonitor.requestDidCreateURLRequest = { _, _ in didCreateURLRequest.complete() }
        eventMonitor.requestDidCreateTask = { _, _ in didCreateTask.complete() }
        eventMonitor.requestDidGatherMetrics = { _, _ in didGatherMetrics.complete() }
        eventMonitor.requestDidCompleteTaskWithError = { _, _, _ in didComplete.complete() }
        eventMonitor.requestDidFinish = { _ in didFinish.complete() }
        eventMonitor.requestDidResume = { _ in didResume.complete() }
        eventMonitor.requestDidParseDownloadResponse = { _, _ in didParseResponse.complete() }
        eventMonitor.requestDidCancel = { _ in didCancel.complete() }
        eventMonitor.requestDidCancelTask = { _, _ in didCancelTask.complete() }

        // When
        let request = session.download(.delay(5)).response { _ in
            responseHandler.complete()
        }

        eventMonitor.requestDidResumeTask = { [unowned request] _, _ in
            request.cancel()
            didResumeTask.complete()
        }

        request.resume()

        await wait(for: [taskDidFinishCollecting, didCreateInitialURLRequest, didCreateURLRequest, didCreateTask, didGatherMetrics, didComplete, didFinish, didResume, didResumeTask, didParseResponse, didCancel, didCancelTask, responseHandler])

        // Then
        #expect(request.state == .cancelled)
    }
}

// MARK: -

@Suite(.storesInstances)
struct DownloadResumeDataTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadRequestDoesNotProduceResumeData() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("Download should be cancelled")
        let cancelled = Capture(false)

        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        let download = session.download(.download(10_000_000))
        download.downloadProgress(queue: session.rootQueue) { [unowned download] progress in
            guard !cancelled.value else { return }

            if progress.fractionCompleted > 0 {
                download.cancel()
                cancelled.value = true
            }
        }
        download.response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.error != nil)

        #expect(response.resumeData == nil)
        #expect(download.resumeData == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestProducesResumeDataOnError() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("download complete")

        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        let download = session.download(.download(produceError: true))
        download.response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.error != nil)

        #expect(response.resumeData != nil)
        #expect(download.resumeData != nil)
        #if !canImport(FoundationNetworking) // If we not using swift-corelibs-foundation.
        #expect(download.error?.downloadResumeData != nil)
        #expect(download.error?.downloadResumeData == response.resumeData)
        #endif
        #expect(response.resumeData == download.resumeData)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadResponseDataMatchesResumeData() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("Download should be cancelled")
        let cancelled = Capture(false)

        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        let download = session.download(.download(10_000_000))
        download.downloadProgress(queue: session.rootQueue) { [unowned download] progress in
            guard !cancelled.value else { return }

            if progress.fractionCompleted > 0 {
                download.cancel(producingResumeData: true)
                cancelled.value = true
            }
        }
        download.response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.error != nil)

        #expect(response.resumeData != nil)
        #expect(download.resumeData != nil)

        #expect(response.resumeData == download.resumeData)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadResumeDataIsAvailableWithDecodableResponseSerializer() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("Download should be cancelled")
        let cancelled = Capture(false)

        let response = Capture<DownloadResponse<TestResponse, AFError>?>()

        // When
        let download = session.download(.download(10_000_000))
        download.downloadProgress(queue: session.rootQueue) { [unowned download] progress in
            guard !cancelled.value else { return }

            if progress.fractionCompleted > 0 {
                download.cancel(producingResumeData: true)
                cancelled.value = true
            }
        }
        download.responseDecodable(of: TestResponse.self) { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.result?.isFailure == true)
        #expect(response.result?.failure != nil)

        #expect(response.resumeData != nil)
        #expect(download.resumeData != nil)

        #expect(response.resumeData == download.resumeData)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadCanBeResumedWithResumeData() async {
        // Given
        let session = stored(Session.independent())
        let expectation1 = Completion("Download should be cancelled")
        let cancelled = Capture(false)

        let response1 = Capture<DownloadResponse<Data, AFError>?>()

        // When
        let download = session.download(.download(10_000_000))
        download.downloadProgress(queue: session.rootQueue) { [unowned download] progress in
            guard !cancelled.value else { return }

            if progress.fractionCompleted > 0 {
                download.cancel(producingResumeData: true)
                cancelled.value = true
            }
        }
        download.responseData { resp in
            response1.value = resp
            expectation1.complete()
        }

        await expectation1.wait()

        guard let resumeData = download.resumeData else {
            Issue.record("resumeData should not be nil")
            return
        }

        let expectation2 = Completion("Download should complete")

        let progressValues = Capture<[Double]>([])
        let response2 = Capture<DownloadResponse<Data, AFError>?>()

        session.download(resumingWith: resumeData)
            .downloadProgress(queue: session.rootQueue) { progress in
                progressValues.write { $0.append(progress.fractionCompleted) }
            }
            .responseData { resp in
                response2.value = resp
                expectation2.complete()
            }

        await expectation2.wait()

        // Then
        #expect(response1.request != nil)
        #expect(response1.response != nil)
        #expect(response1.fileURL == nil)
        #expect(response1.result?.isFailure == true)
        #expect(response1.result?.failure != nil)

        #expect(response2.response != nil)
        #expect(response2.fileURL != nil)
        #expect(response2.result?.isSuccess == true)
        #expect(response2.result?.failure == nil)

        progressValues.value.forEach { #expect($0 > 0) }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func cancelledDownloadProducesMatchingResumeData() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("Download should be cancelled")
        let cancelled = Capture(false)
        let receivedResumeData = Capture<Data?>()
        let response = Capture<DownloadResponse<URL?, AFError>?>()

        // When
        let download = session.download(.download(10_000_000))
        download.downloadProgress(queue: session.rootQueue) { [unowned download] progress in
            guard !cancelled.value else { return }

            if progress.fractionCompleted > 0 {
                download.cancel { receivedResumeData.value = $0 }
                cancelled.value = true
            }
        }
        download.response { resp in
            response.value = resp
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL == nil)
        #expect(response.error != nil)

        #expect(response.resumeData != nil)
        #expect(download.resumeData != nil)

        #expect(response.resumeData == download.resumeData)
        #expect(response.resumeData == receivedResumeData.value)
        #expect(download.resumeData == receivedResumeData.value)
    }
}

// MARK: -

@Suite(.storesInstances)
struct DownloadResponseMapTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapTransformsSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DownloadResponse<String, AFError>?>()

        // When
        session.download(.get, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.map { response in
                response.args["foo"] ?? "invalid"
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)
        #expect(response.result?.success == "bar")
        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapPreservesFailureError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with invalid URL")

        let response = Capture<DownloadResponse<String, AFError>?>()

        // When
        session.download(urlString, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.map { _ in "ignored" }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect(response.result?.isFailure == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct DownloadResponseTryMapTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapTransformsSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DownloadResponse<String, any Error>?>()

        // When
        session.download(.get, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.tryMap { response in
                response.args["foo"] ?? "invalid"
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)
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

        let response = Capture<DownloadResponse<String, any Error>?>()

        // When
        session.download(.get, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.tryMap { _ in
                throw TransformError()
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        if let error = response.result?.failure {
            #expect(error is TransformError)
        } else {
            Issue.record("flatMap should catch the transformation error")
        }

        #expect(response.metrics != nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapPreservesFailureError() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should fail with 404")

        let response = Capture<DownloadResponse<String, any Error>?>()

        // When
        session.download(urlString, parameters: ["foo": "bar"]).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.tryMap { _ in "ignored" }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect(response.result?.isFailure == true)
        #expect(response.metrics != nil)
    }
}

@Suite(.storesInstances)
struct DownloadResponseMapErrorTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func mapErrorTransformsFailureValue() async {
        // Given
        let session = stored(Session.independent())
        let urlString = String.invalidURL
        let expectation = Completion("request should not succeed")

        let response = Capture<DownloadResponse<TestResponse, TestError>?>()

        // When
        session.download(urlString).responseDecodable(of: TestResponse.self) { resp in
            response.value = resp.mapError { error in
                TestError.error(error: error)
            }

            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
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

        let response = Capture<DownloadResponse<Data, TestError>?>()

        // When
        session.download(.get).responseData { resp in
            response.value = resp.mapError { TestError.error(error: $0) }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.result?.isSuccess == true)
        #expect(response.metrics != nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct DownloadResponseTryMapErrorTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func tryMapErrorPreservesSuccessValue() async {
        // Given
        let session = stored(Session.independent())
        let expectation = Completion("request should succeed")

        let response = Capture<DownloadResponse<Data, any Error>?>()

        // When
        session.download(.get).responseData { resp in
            response.value = resp.tryMapError { TestError.error(error: $0) }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.fileURL != nil)
        #expect(response.resumeData == nil)
        #expect(response.error == nil)
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

        let response = Capture<DownloadResponse<Data, any Error>?>()

        // When
        session.download(urlString).responseData { resp in
            response.value = resp.tryMapError { _ in try TransformationError.error.alwaysFails() }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect(response.result?.isFailure == true)

        if let error = response.result?.failure {
            #expect(error is TransformationError)
        } else {
            Issue.record("flatMapError should catch the transformation error")
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

        let response = Capture<DownloadResponse<Data, any Error>?>()

        // When
        session.download(urlString).responseData { resp in
            response.value = resp.tryMapError { TestError.error(error: $0) }
            expectation.complete()
        }

        await expectation.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response == nil)
        #expect(response.fileURL == nil)
        #expect(response.resumeData == nil)
        #expect(response.error != nil)
        #expect(response.result?.isFailure == true)
        guard let error = response.error, case TestError.error = error else { Issue.record(); return }

        #expect(response.metrics != nil)
    }
}
