//
//  ResumeDataTests.swift
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

// MARK: - ResumeData Initialization Tests

final class ResumeDataInitializationTests: BaseTestCase {

    func testResumeDataInitializationWithValidData() {
        // Given
        let validResumeData = MockResumeDataGenerator.validResumeData()

        // When
        do {
            let resumeData = try ResumeData(from: validResumeData)

            // Then
            XCTAssertNotNil(resumeData)
            XCTAssertEqual(resumeData.data, validResumeData)
        } catch {
            XCTFail("ResumeData initialization should succeed with valid data: \(error)")
        }
    }

    func testResumeDataInitializationWithInvalidData() {
        // Given
        let invalidData = "invalid data".data(using: .utf8)!

        // When/Then
        XCTAssertThrowsError(try ResumeData(from: invalidData)) { error in
            guard case ResumeData.ResumeDataError.invalidFormat = error else {
                XCTFail("Expected invalidFormat error, got: \(error)")
                return
            }
        }
    }

    func testResumeDataInitializationWithEmptyData() {
        // Given
        let emptyData = Data()

        // When/Then
        XCTAssertThrowsError(try ResumeData(from: emptyData)) { error in
            guard case ResumeData.ResumeDataError.invalidFormat = error else {
                XCTFail("Expected invalidFormat error, got: \(error)")
                return
            }
        }
    }
}

// MARK: - ResumeData URL Detection Tests

final class ResumeDataURLDetectionTests: BaseTestCase {

    func testURLDetectionWithSingleURL() throws {
        // Given
        let testURL = "https://example.com/file.zip"
        let resumeData = try MockResumeDataGenerator.resumeDataWithURL(testURL)

        // When
        let detectedURLs = resumeData.detectedURLs

        // Then
        XCTAssertEqual(detectedURLs.count, 1)
        XCTAssertTrue(detectedURLs.contains(testURL))
    }

    func testURLDetectionWithMultipleURLs() throws {
        // Given
        let testURLs = [
            "https://example.com/file.zip",
            "https://cdn.example.com/file.zip"
        ]
        let resumeData = try MockResumeDataGenerator.resumeDataWithURLs(testURLs)

        // When
        let detectedURLs = resumeData.detectedURLs

        // Then
        XCTAssertEqual(detectedURLs.count, testURLs.count)
        for url in testURLs {
            XCTAssertTrue(detectedURLs.contains(url))
        }
    }

    func testURLDetectionWithNoURLs() throws {
        // Given
        let resumeData = try MockResumeDataGenerator.resumeDataWithoutURLs()

        // When
        let detectedURLs = resumeData.detectedURLs

        // Then
        XCTAssertTrue(detectedURLs.isEmpty)
    }
}

// MARK: - ResumeData URL Modification Tests

final class ResumeDataURLModificationTests: BaseTestCase {

    func testURLModificationWithSpecificURL() throws {
        // Given
        let oldURL = "https://old-server.com/file.zip"
        let newURL = "https://new-server.com/file.zip"
        let resumeData = try MockResumeDataGenerator.resumeDataWithURL(oldURL)

        // When
        let modifiedResumeData = try resumeData.modifyingURL(from: oldURL, to: newURL)

        // Then
        XCTAssertNotEqual(modifiedResumeData.data, resumeData.data)
        XCTAssertTrue(modifiedResumeData.detectedURLs.contains(newURL))
        XCTAssertFalse(modifiedResumeData.detectedURLs.contains(oldURL))
    }

    func testURLModificationWithAllURLs() throws {
        // Given
        let oldURLs = [
            "https://old-server.com/file.zip",
            "https://old-cdn.com/file.zip"
        ]
        let newURL = "https://new-server.com/file.zip"
        let resumeData = try MockResumeDataGenerator.resumeDataWithURLs(oldURLs)

        // When
        let modifiedResumeData = try resumeData.modifyingURL(from: nil, to: newURL)

        // Then
        XCTAssertNotEqual(modifiedResumeData.data, resumeData.data)
        XCTAssertEqual(modifiedResumeData.detectedURLs.count, oldURLs.count)
        for _ in oldURLs {
            XCTAssertTrue(modifiedResumeData.detectedURLs.contains(newURL))
        }
        for oldURL in oldURLs {
            XCTAssertFalse(modifiedResumeData.detectedURLs.contains(oldURL))
        }
    }

    func testURLModificationWithNonExistentURL() throws {
        // Given
        let existingURL = "https://example.com/file.zip"
        let nonExistentURL = "https://nonexistent.com/file.zip"
        let newURL = "https://new-server.com/file.zip"
        let resumeData = try MockResumeDataGenerator.resumeDataWithURL(existingURL)

        // When/Then
        XCTAssertThrowsError(try resumeData.modifyingURL(from: nonExistentURL, to: newURL)) { error in
            guard case ResumeData.ResumeDataError.urlModificationFailed(let reason) = error else {
                XCTFail("Expected urlModificationFailed error, got: \(error)")
                return
            }
            XCTAssertTrue(reason.contains("not found"))
        }
    }

    func testURLModificationPreservesOriginalData() throws {
        // Given
        let originalURL = "https://example.com/file.zip"
        let newURL = "https://new-server.com/file.zip"
        let originalResumeData = try MockResumeDataGenerator.resumeDataWithURL(originalURL)
        let originalDataCopy = originalResumeData.data

        // When
        _ = try originalResumeData.modifyingURL(from: originalURL, to: newURL)

        // Then - Original data should be unchanged
        XCTAssertEqual(originalResumeData.data, originalDataCopy)
        XCTAssertTrue(originalResumeData.detectedURLs.contains(originalURL))
        XCTAssertFalse(originalResumeData.detectedURLs.contains(newURL))
    }
}

// MARK: - DownloadRequest Structured Cancel Tests

final class DownloadRequestStructuredCancelTests: BaseTestCase {

    @MainActor
    func testCancelWithStructuredResumeDataSuccess() {
        // Given
        let endpoint = Endpoint.download(1000) // Large enough file to allow cancellation
        let expectation = expectation(description: "Cancel should produce structured resume data")
        var result: Result<ResumeData?, ResumeData.ResumeDataError>?

        // When
        let request = AF.download(endpoint)

        // Allow request to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            request.cancel(byProducingStructuredResumeData: { cancelResult in
                result = cancelResult
                expectation.fulfill()
            })
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(result)
        switch result! {
        case .success(let resumeData):
            if let resumeData = resumeData {
                XCTAssertGreaterThan(resumeData.data.count, 0)
                // Should contain original URL
                XCTAssertTrue(resumeData.detectedURLs.contains { url in
                    url.contains("download")
                })
            } else {
                // nil resume data is acceptable if request completed before cancellation
                XCTAssertNil(resumeData)
            }
        case .failure(let error):
            XCTFail("Cancel should not fail with error: \(error)")
        }
    }

    @MainActor
    func testCancelWithStructuredResumeDataOnCompletedRequest() {
        // Given
        let endpoint = Endpoint.download(10) // Small file that completes quickly
        let downloadExpectation = expectation(description: "Download should complete")
        let cancelExpectation = expectation(description: "Cancel should handle completed request")
        var downloadResult: DownloadResponse<URL?, AFError>?
        var cancelResult: Result<ResumeData?, ResumeData.ResumeDataError>?

        // When
        let request = AF.download(endpoint)
            .response { response in
                downloadResult = response
                downloadExpectation.fulfill()
            }

        // Wait for download to complete, then try to cancel
        wait(for: [downloadExpectation], timeout: timeout)

        request.cancel(byProducingStructuredResumeData: { result in
            cancelResult = result
            cancelExpectation.fulfill()
        })

        wait(for: [cancelExpectation], timeout: timeout)

        // Then
        XCTAssertNotNil(downloadResult)
        XCTAssertNil(downloadResult?.error) // Download should succeed
        XCTAssertNotNil(cancelResult)

        switch cancelResult! {
        case .success(let resumeData):
            XCTAssertNil(resumeData) // No resume data for completed download
        case .failure:
            XCTFail("Cancel should not fail for completed request")
        }
    }
}

// MARK: - Integration Tests

final class ResumeDataIntegrationTests: BaseTestCase {

    @MainActor
    func testEndToEndURLModificationWorkflow() {
        // Given
        let originalEndpoint = Endpoint.download(5000)
        let newURL = "https://httpbin.org/download/2500" // Different size to verify URL change

        let cancelExpectation = expectation(description: "Original download should be cancelled")
        let resumeExpectation = expectation(description: "Modified download should complete")

        var originalCancelResult: Result<ResumeData?, ResumeData.ResumeDataError>?
        var resumeDownloadResult: DownloadResponse<URL?, AFError>?

        // When
        // 1. Start original download
        let originalRequest = AF.download(originalEndpoint)

        // 2. Cancel and get structured resume data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            originalRequest.cancel(byProducingStructuredResumeData: { result in
                originalCancelResult = result
                cancelExpectation.fulfill()
            })
        }

        wait(for: [cancelExpectation], timeout: timeout)

        // 3. Modify URL and resume download
        guard case .success(let resumeData?) = originalCancelResult else {
            XCTFail("Should have valid resume data")
            return
        }

        do {
            let modifiedResumeData = try resumeData.modifyingURL(from: nil, to: newURL)

            AF.download(resumingWith: modifiedResumeData.data)
                .response { response in
                    resumeDownloadResult = response
                    resumeExpectation.fulfill()
                }

        } catch {
            XCTFail("URL modification should succeed: \(error)")
            return
        }

        wait(for: [resumeExpectation], timeout: timeout)

        // Then
        XCTAssertNotNil(resumeDownloadResult)
        XCTAssertNil(resumeDownloadResult?.error)
        XCTAssertNotNil(resumeDownloadResult?.fileURL)

        // Verify URL was actually changed by checking the resumed request URL
        if let resumedURL = resumeDownloadResult?.request?.url?.absoluteString {
            XCTAssertTrue(resumedURL.contains("2500"), "URL should reflect the modified endpoint")
        }
    }
}

// MARK: - Mock Data Generator

struct MockResumeDataGenerator {

    static func validResumeData() -> Data {
        let plistDict: [String: Any] = [
            "$version": 100000,
            "$archiver": "NSKeyedArchiver",
            "$top": ["root": NSKeyedArchiver.ArchivedObject._object(0)],
            "$objects": [
                "$null",
                "https://example.com/file.zip",
                NSNumber(value: 1024),
                "test-resume-data"
            ]
        ]

        return try! PropertyListSerialization.data(fromPropertyList: plistDict,
                                                   format: .xml,
                                                   options: 0)
    }

    static func resumeDataWithURL(_ url: String) throws -> ResumeData {
        let plistDict: [String: Any] = [
            "$version": 100000,
            "$archiver": "NSKeyedArchiver",
            "$top": ["root": NSKeyedArchiver.ArchivedObject._object(0)],
            "$objects": [
                "$null",
                url,
                NSNumber(value: 2048),
                "resume-data-with-url"
            ]
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plistDict,
                                                      format: .xml,
                                                      options: 0)
        return try ResumeData(from: data)
    }

    static func resumeDataWithURLs(_ urls: [String]) throws -> ResumeData {
        var objects: [Any] = ["$null"]
        objects.append(contentsOf: urls)
        objects.append(NSNumber(value: 4096))
        objects.append("resume-data-with-multiple-urls")

        let plistDict: [String: Any] = [
            "$version": 100000,
            "$archiver": "NSKeyedArchiver",
            "$top": ["root": NSKeyedArchiver.ArchivedObject._object(0)],
            "$objects": objects
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plistDict,
                                                      format: .xml,
                                                      options: 0)
        return try ResumeData(from: data)
    }

    static func resumeDataWithoutURLs() throws -> ResumeData {
        let plistDict: [String: Any] = [
            "$version": 100000,
            "$archiver": "NSKeyedArchiver",
            "$top": ["root": NSKeyedArchiver.ArchivedObject._object(0)],
            "$objects": [
                "$null",
                NSNumber(value: 512),
                "resume-data-without-urls",
                ["key": "value"]
            ]
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plistDict,
                                                      format: .xml,
                                                      options: 0)
        return try ResumeData(from: data)
    }
}

// MARK: - Performance Tests

final class ResumeDataPerformanceTests: BaseTestCase {

    func testResumeDataParsingPerformance() {
        // Given
        let resumeDataSamples = (0..<1000).map { _ in MockResumeDataGenerator.validResumeData() }

        // When/Then
        measure {
            for data in resumeDataSamples {
                _ = try? ResumeData(from: data)
            }
        }
    }

    func testURLModificationPerformance() throws {
        // Given
        let resumeData = try MockResumeDataGenerator.resumeDataWithURL("https://example.com/file.zip")

        // When/Then
        measure {
            for i in 0..<100 {
                _ = try? resumeData.modifyingURL(from: nil, to: "https://server\(i).com/file.zip")
            }
        }
    }
}
